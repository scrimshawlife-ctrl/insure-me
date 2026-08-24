-- T810: checked notice-version administration.

alter table public.notice_definitions
  add column approval_ref text,
  add column approval_reason_codes text[];

create type public.notice_definition_event_type as enum ('CREATED','APPROVED','RETIRED');

create table public.notice_definition_events (
  notice_definition_event_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  notice_definition_id uuid not null references public.notice_definitions(notice_definition_id),
  event_type public.notice_definition_event_type not null,
  authority_ref text,
  evidence_ref text not null,
  reason_codes text[] not null check (cardinality(reason_codes) > 0),
  idempotency_key uuid not null,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  actor_id uuid not null,
  occurred_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  unique (tenant_id, agency_id, idempotency_key)
);
create index notice_definition_events_notice_idx
  on public.notice_definition_events (notice_definition_id, occurred_at);

alter table public.notice_definition_events enable row level security;
revoke all on public.notice_definitions from anon, authenticated;
revoke all on public.notice_definition_events from anon, authenticated;

create or replace function private.enforce_notice_definition_immutability()
returns trigger language plpgsql security definer set search_path = public, private as $$
begin
  if new.tenant_id is distinct from old.tenant_id
    or new.agency_id is distinct from old.agency_id
    or new.notice_key is distinct from old.notice_key
    or new.version is distinct from old.version
    or new.category is distinct from old.category
    or new.jurisdiction is distinct from old.jurisdiction
    or new.product_line is distinct from old.product_line
    or new.title is distinct from old.title
    or new.body_markdown is distinct from old.body_markdown
    or new.content_hash is distinct from old.content_hash
    or new.required_for_quote is distinct from old.required_for_quote
    or new.created_at is distinct from old.created_at
    or new.created_by is distinct from old.created_by then
    raise exception using errcode = '22023', message = 'NOTICE_VERSION_IMMUTABLE';
  end if;
  if old.status = 'DRAFT' and new.status not in ('DRAFT','APPROVED')
    or old.status in ('SYNTHETIC','APPROVED') and new.status not in (old.status,'RETIRED')
    or old.status = 'RETIRED' and new.status <> 'RETIRED' then
    raise exception using errcode = '22023', message = 'NOTICE_STATUS_TRANSITION_INVALID';
  end if;
  if old.status in ('APPROVED','RETIRED') and (
    new.effective_at is distinct from old.effective_at
    or new.approved_at is distinct from old.approved_at
    or new.approved_by is distinct from old.approved_by
    or new.approval_ref is distinct from old.approval_ref
    or new.approval_reason_codes is distinct from old.approval_reason_codes
  ) then
    raise exception using errcode = '22023', message = 'NOTICE_APPROVAL_EVIDENCE_IMMUTABLE';
  end if;
  if new.status = old.status and (
    new.effective_at is distinct from old.effective_at
    or new.retired_at is distinct from old.retired_at
    or new.approved_at is distinct from old.approved_at
    or new.approved_by is distinct from old.approved_by
    or new.approval_ref is distinct from old.approval_ref
    or new.approval_reason_codes is distinct from old.approval_reason_codes
  ) then
    raise exception using errcode = '22023', message = 'NOTICE_LIFECYCLE_EVIDENCE_IMMUTABLE';
  end if;
  if old.status = 'DRAFT' and new.status = 'APPROVED' and (
    new.effective_at is null or new.approved_at is null or new.approved_by is null
    or char_length(trim(new.approval_ref)) < 3
    or coalesce(cardinality(new.approval_reason_codes),0) = 0
  ) then
    raise exception using errcode = '22023', message = 'NOTICE_APPROVAL_EVIDENCE_REQUIRED';
  end if;
  if old.status in ('SYNTHETIC','APPROVED') and new.status = 'RETIRED'
    and new.retired_at is null then
    raise exception using errcode = '22023', message = 'NOTICE_RETIREMENT_EVIDENCE_REQUIRED';
  end if;
  return new;
end
$$;

create or replace function private.prevent_notice_administration_delete()
returns trigger language plpgsql security definer set search_path = public, private as $$
begin
  raise exception using errcode = '22023', message = 'NOTICE_ADMINISTRATION_IMMUTABLE';
end
$$;
revoke all on function private.prevent_notice_administration_delete() from public;
create trigger notice_definition_no_delete before delete on public.notice_definitions
for each row execute function private.prevent_notice_administration_delete();
create trigger notice_definition_event_immutable before update or delete on public.notice_definition_events
for each row execute function private.prevent_notice_administration_delete();

create or replace function private.notice_admin_context()
returns table (tenant_id uuid, agency_id uuid)
language plpgsql stable security definer set search_path = public, private as $$
declare v_count integer; v_tenant uuid; v_agency uuid;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  select count(*), (array_agg(w.tenant_id))[1], (array_agg(w.agency_id))[1]
    into v_count, v_tenant, v_agency
  from private.get_current_workforce_context_impl() w
  where 'POLICY_ADMIN' = any(w.permissions);
  if v_count <> 1 then
    raise exception using errcode = 'P0002', message = 'NOTICE_ADMIN_SCOPE_NOT_FOUND';
  end if;
  return query select v_tenant, v_agency;
end
$$;
revoke all on function private.notice_admin_context() from public;
grant execute on function private.notice_admin_context() to authenticated;

create or replace function private.create_notice_definition_version_impl(
  p_notice_key text, p_category public.notice_category,
  p_title text, p_body_markdown text, p_required_for_quote boolean,
  p_evidence_ref text, p_reason_codes text[], p_idempotency_key uuid
) returns public.notice_definitions
language plpgsql security definer set search_path = public, private, extensions as $$
declare
  v_ctx record; v_actor uuid := auth.uid(); v_notice public.notice_definitions;
  v_event public.notice_definition_events; v_hash text; v_request_hash text; v_version integer;
begin
  select * into v_ctx from private.notice_admin_context();
  if char_length(trim(p_notice_key)) not between 3 and 100
    or char_length(trim(p_title)) not between 3 and 300
    or char_length(p_body_markdown) not between 1 and 100000
    or char_length(trim(p_evidence_ref)) not between 3 and 500
    or coalesce(cardinality(p_reason_codes),0) = 0
    or (p_category = 'MARKETING_OPTIONAL' and p_required_for_quote) then
    raise exception using errcode = '22023', message = 'NOTICE_ADMIN_INPUT_INVALID';
  end if;
  v_hash := encode(extensions.digest(convert_to(p_body_markdown,'UTF8'),'sha256'),'hex');
  v_request_hash := encode(extensions.digest(jsonb_build_array('CREATE_NOTICE_VERSION',
    trim(p_notice_key),p_category,trim(p_title),p_body_markdown,
    p_required_for_quote,trim(p_evidence_ref),to_jsonb(p_reason_codes))::text,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(concat_ws('|',v_ctx.tenant_id,v_ctx.agency_id,p_idempotency_key),0));
  perform pg_advisory_xact_lock(hashtextextended(concat_ws('|',v_ctx.tenant_id,v_ctx.agency_id,trim(p_notice_key)),0));
  select * into v_event from public.notice_definition_events
    where tenant_id=v_ctx.tenant_id and agency_id=v_ctx.agency_id and idempotency_key=p_idempotency_key;
  if found then
    if v_event.event_type <> 'CREATED' or v_event.request_hash <> v_request_hash then
      raise exception using errcode = '22023', message = 'NOTICE_ADMIN_IDEMPOTENCY_MISMATCH';
    end if;
    select * into v_notice from public.notice_definitions where notice_definition_id=v_event.notice_definition_id;
    return v_notice;
  end if;
  select coalesce(max(version),0)+1 into v_version from public.notice_definitions
    where tenant_id=v_ctx.tenant_id and agency_id=v_ctx.agency_id and notice_key=trim(p_notice_key);
  insert into public.notice_definitions (tenant_id,agency_id,notice_key,version,status,category,
    jurisdiction,product_line,title,body_markdown,content_hash,required_for_quote,created_by)
  values (v_ctx.tenant_id,v_ctx.agency_id,trim(p_notice_key),v_version,'DRAFT',p_category,'CA',
    'PRIVATE_PASSENGER_AUTO',trim(p_title),p_body_markdown,v_hash,p_required_for_quote,v_actor)
  returning * into v_notice;
  insert into public.notice_definition_events (tenant_id,agency_id,notice_definition_id,event_type,
    evidence_ref,reason_codes,idempotency_key,request_hash,actor_id)
  values (v_ctx.tenant_id,v_ctx.agency_id,v_notice.notice_definition_id,'CREATED',trim(p_evidence_ref),
    p_reason_codes,p_idempotency_key,v_request_hash,v_actor);
  insert into public.audit_events (tenant_id,agency_id,event_type,actor_id,subject_ref,outcome,
    reason_codes,integrity_hash,metadata)
  values (v_ctx.tenant_id,v_ctx.agency_id,'NOTICE_VERSION_CREATED',v_actor,
    'notice-definition:'||v_notice.notice_definition_id,'SUCCEEDED',p_reason_codes,
    encode(extensions.digest(concat_ws('|',v_notice.notice_definition_id,v_hash,'CREATED'),'sha256'),'hex'),
    jsonb_build_object('notice_key',v_notice.notice_key,'version',v_notice.version,
      'category',v_notice.category,'content_hash',v_notice.content_hash));
  return v_notice;
end
$$;

create or replace function private.approve_notice_definition_version_impl(
  p_notice_definition_id uuid, p_approval_ref text, p_effective_at timestamptz,
  p_reason_codes text[], p_idempotency_key uuid
) returns public.notice_definitions
language plpgsql security definer set search_path = public, private, extensions as $$
declare
  v_notice public.notice_definitions; v_event public.notice_definition_events;
  v_actor uuid:=auth.uid(); v_request_hash text;
begin
  select * into v_notice from public.notice_definitions where notice_definition_id=p_notice_definition_id for update;
  if not found or not private.has_permission(v_notice.tenant_id,v_notice.agency_id,'POLICY_ADMIN') then
    raise exception using errcode='P0002',message='NOTICE_ADMIN_SCOPE_NOT_FOUND';
  end if;
  if char_length(trim(p_approval_ref)) not between 3 and 500 or p_effective_at is null
    or p_effective_at < v_notice.created_at
    or coalesce(cardinality(p_reason_codes),0)=0 then
    raise exception using errcode='22023',message='NOTICE_ADMIN_INPUT_INVALID';
  end if;
  v_request_hash:=encode(extensions.digest(jsonb_build_array('APPROVE_NOTICE_VERSION',
    p_notice_definition_id,trim(p_approval_ref),p_effective_at,to_jsonb(p_reason_codes))::text,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(concat_ws('|',v_notice.tenant_id,v_notice.agency_id,p_idempotency_key),0));
  select * into v_event from public.notice_definition_events where tenant_id=v_notice.tenant_id
    and agency_id=v_notice.agency_id and idempotency_key=p_idempotency_key;
  if found then
    if v_event.event_type<>'APPROVED' or v_event.request_hash<>v_request_hash
      or v_event.notice_definition_id<>p_notice_definition_id then
      raise exception using errcode='22023',message='NOTICE_ADMIN_IDEMPOTENCY_MISMATCH';
    end if;
    return v_notice;
  end if;
  if v_notice.status<>'DRAFT' then
    raise exception using errcode='22023',message='NOTICE_APPROVAL_STATE_INVALID';
  end if;
  update public.notice_definitions set status='APPROVED',effective_at=p_effective_at,
    approved_at=now(),approved_by=v_actor,approval_ref=trim(p_approval_ref),
    approval_reason_codes=p_reason_codes where notice_definition_id=p_notice_definition_id returning * into v_notice;
  insert into public.notice_definition_events (tenant_id,agency_id,notice_definition_id,event_type,
    authority_ref,evidence_ref,reason_codes,idempotency_key,request_hash,actor_id)
  values(v_notice.tenant_id,v_notice.agency_id,v_notice.notice_definition_id,'APPROVED',trim(p_approval_ref),
    trim(p_approval_ref),p_reason_codes,p_idempotency_key,v_request_hash,v_actor);
  insert into public.audit_events (tenant_id,agency_id,event_type,actor_id,subject_ref,outcome,
    reason_codes,integrity_hash,metadata) values(v_notice.tenant_id,v_notice.agency_id,
    'NOTICE_VERSION_APPROVED',v_actor,'notice-definition:'||v_notice.notice_definition_id,'SUCCEEDED',
    p_reason_codes,encode(extensions.digest(concat_ws('|',v_notice.notice_definition_id,
      v_notice.content_hash,p_effective_at,'APPROVED'),'sha256'),'hex'),
    jsonb_build_object('notice_key',v_notice.notice_key,'version',v_notice.version,
      'content_hash',v_notice.content_hash,'effective_at',v_notice.effective_at,'approval_ref',v_notice.approval_ref));
  return v_notice;
end
$$;

create or replace function private.retire_notice_definition_version_impl(
  p_notice_definition_id uuid, p_evidence_ref text, p_reason_codes text[], p_idempotency_key uuid
) returns public.notice_definitions
language plpgsql security definer set search_path = public, private, extensions as $$
declare v_notice public.notice_definitions; v_event public.notice_definition_events;
  v_actor uuid:=auth.uid(); v_request_hash text;
begin
  select * into v_notice from public.notice_definitions where notice_definition_id=p_notice_definition_id for update;
  if not found or not private.has_permission(v_notice.tenant_id,v_notice.agency_id,'POLICY_ADMIN') then
    raise exception using errcode='P0002',message='NOTICE_ADMIN_SCOPE_NOT_FOUND';
  end if;
  if char_length(trim(p_evidence_ref)) not between 3 and 500 or coalesce(cardinality(p_reason_codes),0)=0 then
    raise exception using errcode='22023',message='NOTICE_ADMIN_INPUT_INVALID';
  end if;
  v_request_hash:=encode(extensions.digest(jsonb_build_array('RETIRE_NOTICE_VERSION',
    p_notice_definition_id,trim(p_evidence_ref),to_jsonb(p_reason_codes))::text,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(concat_ws('|',v_notice.tenant_id,v_notice.agency_id,p_idempotency_key),0));
  select * into v_event from public.notice_definition_events where tenant_id=v_notice.tenant_id
    and agency_id=v_notice.agency_id and idempotency_key=p_idempotency_key;
  if found then
    if v_event.event_type<>'RETIRED' or v_event.request_hash<>v_request_hash
      or v_event.notice_definition_id<>p_notice_definition_id then
      raise exception using errcode='22023',message='NOTICE_ADMIN_IDEMPOTENCY_MISMATCH';
    end if;
    return v_notice;
  end if;
  if v_notice.status not in ('APPROVED','SYNTHETIC') then
    raise exception using errcode='22023',message='NOTICE_RETIREMENT_STATE_INVALID';
  end if;
  update public.notice_definitions set status='RETIRED',retired_at=now()
    where notice_definition_id=p_notice_definition_id returning * into v_notice;
  insert into public.notice_definition_events (tenant_id,agency_id,notice_definition_id,event_type,
    evidence_ref,reason_codes,idempotency_key,request_hash,actor_id)
  values(v_notice.tenant_id,v_notice.agency_id,v_notice.notice_definition_id,'RETIRED',trim(p_evidence_ref),
    p_reason_codes,p_idempotency_key,v_request_hash,v_actor);
  insert into public.audit_events (tenant_id,agency_id,event_type,actor_id,subject_ref,outcome,
    reason_codes,integrity_hash,metadata) values(v_notice.tenant_id,v_notice.agency_id,
    'NOTICE_VERSION_RETIRED',v_actor,'notice-definition:'||v_notice.notice_definition_id,'SUCCEEDED',
    p_reason_codes,encode(extensions.digest(concat_ws('|',v_notice.notice_definition_id,
      v_notice.content_hash,v_notice.retired_at,'RETIRED'),'sha256'),'hex'),
    jsonb_build_object('notice_key',v_notice.notice_key,'version',v_notice.version,
      'content_hash',v_notice.content_hash,'retired_at',v_notice.retired_at));
  return v_notice;
end
$$;

create or replace function private.list_notice_definition_versions_impl()
returns setof public.notice_definitions language sql stable security definer
set search_path=public,private as $$
  select n.* from private.notice_admin_context() c
  join public.notice_definitions n on n.tenant_id=c.tenant_id and n.agency_id=c.agency_id
  order by n.notice_key,n.version desc limit 500
$$;

revoke all on function private.create_notice_definition_version_impl(text,public.notice_category,text,text,boolean,text,text[],uuid) from public;
revoke all on function private.approve_notice_definition_version_impl(uuid,text,timestamptz,text[],uuid) from public;
revoke all on function private.retire_notice_definition_version_impl(uuid,text,text[],uuid) from public;
revoke all on function private.list_notice_definition_versions_impl() from public;
grant execute on function private.create_notice_definition_version_impl(text,public.notice_category,text,text,boolean,text,text[],uuid) to authenticated;
grant execute on function private.approve_notice_definition_version_impl(uuid,text,timestamptz,text[],uuid) to authenticated;
grant execute on function private.retire_notice_definition_version_impl(uuid,text,text[],uuid) to authenticated;
grant execute on function private.list_notice_definition_versions_impl() to authenticated;

create or replace function public.create_notice_definition_version(p_notice_key text,
  p_category public.notice_category,p_title text,p_body_markdown text,p_required_for_quote boolean,
  p_evidence_ref text,p_reason_codes text[],p_idempotency_key uuid)
returns public.notice_definitions language sql security invoker set search_path=public,private as $$
  select private.create_notice_definition_version_impl(p_notice_key,p_category,p_title,
    p_body_markdown,p_required_for_quote,p_evidence_ref,p_reason_codes,p_idempotency_key)
$$;
create or replace function public.approve_notice_definition_version(p_notice_definition_id uuid,
  p_approval_ref text,p_effective_at timestamptz,p_reason_codes text[],p_idempotency_key uuid)
returns public.notice_definitions language sql security invoker set search_path=public,private as $$
  select private.approve_notice_definition_version_impl(p_notice_definition_id,p_approval_ref,
    p_effective_at,p_reason_codes,p_idempotency_key)
$$;
create or replace function public.retire_notice_definition_version(p_notice_definition_id uuid,
  p_evidence_ref text,p_reason_codes text[],p_idempotency_key uuid)
returns public.notice_definitions language sql security invoker set search_path=public,private as $$
  select private.retire_notice_definition_version_impl(p_notice_definition_id,p_evidence_ref,
    p_reason_codes,p_idempotency_key)
$$;
create or replace function public.list_notice_definition_versions()
returns setof public.notice_definitions language sql stable security invoker set search_path=public,private as $$
  select * from private.list_notice_definition_versions_impl()
$$;

revoke all on function public.create_notice_definition_version(text,public.notice_category,text,text,boolean,text,text[],uuid) from public,anon,authenticated;
revoke all on function public.approve_notice_definition_version(uuid,text,timestamptz,text[],uuid) from public,anon,authenticated;
revoke all on function public.retire_notice_definition_version(uuid,text,text[],uuid) from public,anon,authenticated;
revoke all on function public.list_notice_definition_versions() from public,anon,authenticated;
grant execute on function public.create_notice_definition_version(text,public.notice_category,text,text,boolean,text,text[],uuid) to authenticated;
grant execute on function public.approve_notice_definition_version(uuid,text,timestamptz,text[],uuid) to authenticated;
grant execute on function public.retire_notice_definition_version(uuid,text,text[],uuid) to authenticated;
grant execute on function public.list_notice_definition_versions() to authenticated;
