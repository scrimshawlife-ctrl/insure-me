-- T806: formal legal-hold lifecycle and administration model.
-- Authority and evidence are opaque references. Their legal sufficiency remains
-- a production certification concern; missing references fail closed.

create type public.legal_hold_scope_type as enum (
  'PERSON', 'QUOTE_CASE', 'PRIVACY_REQUEST'
);
create type public.legal_hold_status as enum ('ACTIVE', 'RELEASED');
create type public.legal_hold_event_type as enum ('PLACED', 'RELEASED');

create table public.legal_holds (
  legal_hold_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  scope_type public.legal_hold_scope_type not null,
  scope_ref uuid not null,
  status public.legal_hold_status not null default 'ACTIVE',
  authority_ref text not null check (char_length(trim(authority_ref)) between 3 and 500),
  evidence_ref text not null check (char_length(trim(evidence_ref)) between 3 and 500),
  reason_codes text[] not null check (cardinality(reason_codes) > 0),
  placement_idempotency_key uuid not null,
  placement_request_hash text not null check (placement_request_hash ~ '^[0-9a-f]{64}$'),
  placed_at timestamptz not null default now(),
  placed_by uuid not null,
  release_authority_ref text,
  release_evidence_ref text,
  release_reason_codes text[],
  release_idempotency_key uuid,
  release_request_hash text,
  released_at timestamptz,
  released_by uuid,
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  unique (tenant_id, agency_id, placement_idempotency_key),
  unique (tenant_id, agency_id, release_idempotency_key),
  check (
    (status = 'ACTIVE' and release_authority_ref is null and release_evidence_ref is null
      and release_reason_codes is null and release_idempotency_key is null
      and release_request_hash is null and released_at is null and released_by is null)
    or
    (status = 'RELEASED' and char_length(trim(release_authority_ref)) between 3 and 500
      and char_length(trim(release_evidence_ref)) between 3 and 500
      and cardinality(release_reason_codes) > 0 and release_idempotency_key is not null
      and release_request_hash ~ '^[0-9a-f]{64}$' and released_at is not null
      and released_by is not null)
  )
);

create table public.legal_hold_events (
  legal_hold_event_id uuid primary key default gen_random_uuid(),
  legal_hold_id uuid not null references public.legal_holds(legal_hold_id),
  tenant_id uuid not null,
  agency_id uuid not null,
  event_type public.legal_hold_event_type not null,
  actor_id uuid not null,
  authority_ref text not null check (char_length(trim(authority_ref)) between 3 and 500),
  evidence_ref text not null check (char_length(trim(evidence_ref)) between 3 and 500),
  reason_codes text[] not null check (cardinality(reason_codes) > 0),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  occurred_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id)
);

create index legal_holds_active_scope_idx
  on public.legal_holds (tenant_id, agency_id, scope_type, scope_ref)
  where status = 'ACTIVE';
create index legal_hold_events_hold_idx
  on public.legal_hold_events (legal_hold_id, occurred_at);

alter table public.legal_holds enable row level security;
alter table public.legal_hold_events enable row level security;

create policy legal_holds_admin_select on public.legal_holds
for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
  or private.has_permission(tenant_id, agency_id, 'POLICY_ADMIN')
);
create policy legal_hold_events_admin_select on public.legal_hold_events
for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
  or private.has_permission(tenant_id, agency_id, 'POLICY_ADMIN')
);

revoke all on public.legal_holds, public.legal_hold_events from anon, authenticated;
grant select on public.legal_holds, public.legal_hold_events to authenticated;

create or replace function private.prevent_legal_hold_event_mutation()
returns trigger language plpgsql security definer set search_path = public, private as $$
begin
  raise exception using errcode = '22023', message = 'LEGAL_HOLD_EVENT_IMMUTABLE';
end
$$;
revoke all on function private.prevent_legal_hold_event_mutation() from public;
create trigger legal_hold_event_immutable before update or delete on public.legal_hold_events
for each row execute function private.prevent_legal_hold_event_mutation();

create or replace function private.enforce_legal_hold_update()
returns trigger language plpgsql security definer set search_path = public, private as $$
begin
  if new.tenant_id is distinct from old.tenant_id
     or new.agency_id is distinct from old.agency_id
     or new.scope_type is distinct from old.scope_type
     or new.scope_ref is distinct from old.scope_ref
     or new.authority_ref is distinct from old.authority_ref
     or new.evidence_ref is distinct from old.evidence_ref
     or new.reason_codes is distinct from old.reason_codes
     or new.placement_idempotency_key is distinct from old.placement_idempotency_key
     or new.placement_request_hash is distinct from old.placement_request_hash
     or new.placed_at is distinct from old.placed_at
     or new.placed_by is distinct from old.placed_by
     or old.status = 'RELEASED'
     or new.status <> 'RELEASED' then
    raise exception using errcode = '22023', message = 'LEGAL_HOLD_LIFECYCLE_INVALID';
  end if;
  return new;
end
$$;
revoke all on function private.enforce_legal_hold_update() from public;
create trigger legal_hold_update_guard before update on public.legal_holds
for each row execute function private.enforce_legal_hold_update();
create trigger legal_hold_delete_guard before delete on public.legal_holds
for each row execute function private.prevent_legal_hold_event_mutation();

create or replace function private.validate_legal_hold_scope(
  p_tenant_id uuid, p_agency_id uuid,
  p_scope_type public.legal_hold_scope_type, p_scope_ref uuid
)
returns boolean language sql stable security definer set search_path = public, private as $$
  select case p_scope_type
    when 'PERSON' then exists (
      select 1 from public.people p where p.person_id = p_scope_ref
        and p.tenant_id = p_tenant_id and p.agency_id = p_agency_id
    )
    when 'QUOTE_CASE' then exists (
      select 1 from public.quote_cases q where q.quote_case_id = p_scope_ref
        and q.tenant_id = p_tenant_id and q.agency_id = p_agency_id
    )
    when 'PRIVACY_REQUEST' then exists (
      select 1 from public.privacy_requests r where r.privacy_request_id = p_scope_ref
        and r.tenant_id = p_tenant_id and r.agency_id = p_agency_id
    ) else false end
$$;
revoke all on function private.validate_legal_hold_scope(uuid, uuid, public.legal_hold_scope_type, uuid) from public;

create or replace function private.hold_matches_person(
  p_hold public.legal_holds, p_person_id uuid
)
returns boolean language sql stable security definer set search_path = public, private as $$
  select case p_hold.scope_type
    when 'PERSON' then p_hold.scope_ref = p_person_id
    when 'QUOTE_CASE' then exists (
      select 1 from public.quote_cases q
      join public.prospects p on p.prospect_id = q.prospect_id
      where q.quote_case_id = p_hold.scope_ref and p.person_id = p_person_id
    )
    when 'PRIVACY_REQUEST' then exists (
      select 1 from public.privacy_requests r
      where r.privacy_request_id = p_hold.scope_ref and r.matched_person_id = p_person_id
    ) else false end
$$;
revoke all on function private.hold_matches_person(public.legal_holds, uuid) from public;

-- Preserve T805's legacy QuoteCase signal while adding formal active holds.
create or replace function private.has_retention_hold_signal(
  p_tenant_id uuid, p_agency_id uuid, p_person_id uuid
)
returns boolean language sql stable security definer set search_path = public, private as $$
  select exists (
    select 1 from public.legal_holds h
    where h.tenant_id = p_tenant_id and h.agency_id = p_agency_id
      and h.status = 'ACTIVE' and private.hold_matches_person(h, p_person_id)
  ) or exists (
    select 1 from public.quote_cases q
    join public.prospects p on p.prospect_id = q.prospect_id
    where q.tenant_id = p_tenant_id and q.agency_id = p_agency_id
      and p.person_id = p_person_id and q.state = 'RETENTION_HOLD'
  )
$$;
revoke all on function private.has_retention_hold_signal(uuid, uuid, uuid) from public;

create or replace function private.place_legal_hold_impl(
  p_tenant_id uuid, p_agency_id uuid,
  p_scope_type public.legal_hold_scope_type, p_scope_ref uuid,
  p_authority_ref text, p_evidence_ref text, p_reason_codes text[],
  p_idempotency_key uuid, p_request_hash text
)
returns public.legal_holds language plpgsql security definer
set search_path = public, private, extensions as $$
declare v_actor uuid := auth.uid(); v_hold public.legal_holds; v_hash text;
begin
  if v_actor is null then raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED'; end if;
  if not (private.has_permission(p_tenant_id, p_agency_id, 'PRIVACY_ADMIN')
      or private.has_permission(p_tenant_id, p_agency_id, 'POLICY_ADMIN')) then
    raise exception using errcode = '42501', message = 'LEGAL_HOLD_ADMIN_NOT_PERMITTED';
  end if;
  if not private.validate_legal_hold_scope(p_tenant_id, p_agency_id, p_scope_type, p_scope_ref) then
    raise exception using errcode = 'P0002', message = 'LEGAL_HOLD_SCOPE_NOT_FOUND';
  end if;
  select * into v_hold from public.legal_holds h
  where h.tenant_id = p_tenant_id and h.agency_id = p_agency_id
    and h.placement_idempotency_key = p_idempotency_key for update;
  if found then
    if v_hold.placement_request_hash <> p_request_hash then
      raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUEST_MISMATCH';
    end if;
    return v_hold;
  end if;
  insert into public.legal_holds (
    tenant_id, agency_id, scope_type, scope_ref, authority_ref, evidence_ref,
    reason_codes, placement_idempotency_key, placement_request_hash, placed_by
  ) values (
    p_tenant_id, p_agency_id, p_scope_type, p_scope_ref, trim(p_authority_ref),
    trim(p_evidence_ref), p_reason_codes, p_idempotency_key, p_request_hash, v_actor
  ) returning * into v_hold;
  insert into public.legal_hold_events (
    legal_hold_id, tenant_id, agency_id, event_type, actor_id, authority_ref,
    evidence_ref, reason_codes, request_hash
  ) values (
    v_hold.legal_hold_id, p_tenant_id, p_agency_id, 'PLACED', v_actor,
    v_hold.authority_ref, v_hold.evidence_ref, v_hold.reason_codes, p_request_hash
  );
  update public.retention_disposition_items item set
    status = 'BLOCKED',
    reason_codes = array(select distinct x from unnest(item.reason_codes || array['LEGAL_HOLD_ACTIVE']) x),
    updated_at = now()
  from public.privacy_requests request
  where request.privacy_request_id = item.privacy_request_id
    and item.tenant_id = p_tenant_id and item.agency_id = p_agency_id
    and item.status in ('SCHEDULED', 'BLOCKED', 'FAILED')
    and private.hold_matches_person(v_hold, request.matched_person_id);
  v_hash := encode(digest(concat_ws('|', v_hold.legal_hold_id::text, p_request_hash, 'PLACED'), 'sha256'), 'hex');
  insert into public.audit_events (tenant_id, agency_id, event_type, actor_id,
    subject_ref, outcome, reason_codes, integrity_hash, metadata)
  values (p_tenant_id, p_agency_id, 'LEGAL_HOLD_PLACED', v_actor,
    'legal-hold:' || v_hold.legal_hold_id::text, 'SUCCEEDED', p_reason_codes,
    v_hash, jsonb_build_object('scope_type', p_scope_type, 'scope_ref', p_scope_ref));
  return v_hold;
end
$$;
revoke all on function private.place_legal_hold_impl(uuid, uuid, public.legal_hold_scope_type, uuid, text, text, text[], uuid, text) from public;
grant execute on function private.place_legal_hold_impl(uuid, uuid, public.legal_hold_scope_type, uuid, text, text, text[], uuid, text) to authenticated;

create or replace function private.release_legal_hold_impl(
  p_legal_hold_id uuid, p_authority_ref text, p_evidence_ref text,
  p_reason_codes text[], p_idempotency_key uuid, p_request_hash text
)
returns public.legal_holds language plpgsql security definer
set search_path = public, private, extensions as $$
declare v_actor uuid := auth.uid(); v_hold public.legal_holds; v_hash text;
begin
  if v_actor is null then raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED'; end if;
  select * into v_hold from public.legal_holds where legal_hold_id = p_legal_hold_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'LEGAL_HOLD_NOT_FOUND'; end if;
  if not (private.has_permission(v_hold.tenant_id, v_hold.agency_id, 'PRIVACY_ADMIN')
      or private.has_permission(v_hold.tenant_id, v_hold.agency_id, 'POLICY_ADMIN')) then
    raise exception using errcode = '42501', message = 'LEGAL_HOLD_ADMIN_NOT_PERMITTED';
  end if;
  if v_hold.status = 'RELEASED' then
    if v_hold.release_idempotency_key <> p_idempotency_key
       or v_hold.release_request_hash <> p_request_hash then
      raise exception using errcode = '22023', message = 'LEGAL_HOLD_ALREADY_RELEASED';
    end if;
    return v_hold;
  end if;
  update public.legal_holds set status = 'RELEASED', release_authority_ref = trim(p_authority_ref),
    release_evidence_ref = trim(p_evidence_ref), release_reason_codes = p_reason_codes,
    release_idempotency_key = p_idempotency_key, release_request_hash = p_request_hash,
    released_at = now(), released_by = v_actor
  where legal_hold_id = p_legal_hold_id returning * into v_hold;
  insert into public.legal_hold_events (
    legal_hold_id, tenant_id, agency_id, event_type, actor_id, authority_ref,
    evidence_ref, reason_codes, request_hash
  ) values (v_hold.legal_hold_id, v_hold.tenant_id, v_hold.agency_id, 'RELEASED',
    v_actor, v_hold.release_authority_ref, v_hold.release_evidence_ref,
    v_hold.release_reason_codes, p_request_hash);
  update public.retention_disposition_items item set
    reason_codes = array(select distinct x from unnest(item.reason_codes || array['LEGAL_HOLD_RELEASED_REEVALUATION_REQUIRED']) x),
    updated_at = now()
  from public.privacy_requests request
  where request.privacy_request_id = item.privacy_request_id
    and item.tenant_id = v_hold.tenant_id and item.agency_id = v_hold.agency_id
    and item.status = 'BLOCKED' and private.hold_matches_person(v_hold, request.matched_person_id);
  v_hash := encode(digest(concat_ws('|', v_hold.legal_hold_id::text, p_request_hash, 'RELEASED'), 'sha256'), 'hex');
  insert into public.audit_events (tenant_id, agency_id, event_type, actor_id,
    subject_ref, outcome, reason_codes, integrity_hash, metadata)
  values (v_hold.tenant_id, v_hold.agency_id, 'LEGAL_HOLD_RELEASED', v_actor,
    'legal-hold:' || v_hold.legal_hold_id::text, 'SUCCEEDED', p_reason_codes,
    v_hash, jsonb_build_object('scope_type', v_hold.scope_type, 'scope_ref', v_hold.scope_ref,
      'resumption', 'REEVALUATION_REQUIRED'));
  return v_hold;
end
$$;
revoke all on function private.release_legal_hold_impl(uuid, text, text, text[], uuid, text) from public;
grant execute on function private.release_legal_hold_impl(uuid, text, text, text[], uuid, text) to authenticated;

create or replace function public.place_legal_hold(
  p_tenant_id uuid, p_agency_id uuid,
  p_scope_type public.legal_hold_scope_type, p_scope_ref uuid,
  p_authority_ref text, p_evidence_ref text, p_reason_codes text[],
  p_idempotency_key uuid, p_request_hash text
)
returns public.legal_holds language sql security invoker set search_path = public, private as $$
  select private.place_legal_hold_impl(p_tenant_id, p_agency_id, p_scope_type,
    p_scope_ref, p_authority_ref, p_evidence_ref, p_reason_codes,
    p_idempotency_key, p_request_hash)
$$;
create or replace function public.release_legal_hold(
  p_legal_hold_id uuid, p_authority_ref text, p_evidence_ref text,
  p_reason_codes text[], p_idempotency_key uuid, p_request_hash text
)
returns public.legal_holds language sql security invoker set search_path = public, private as $$
  select private.release_legal_hold_impl(p_legal_hold_id, p_authority_ref,
    p_evidence_ref, p_reason_codes, p_idempotency_key, p_request_hash)
$$;
revoke all on function public.place_legal_hold(uuid, uuid, public.legal_hold_scope_type, uuid, text, text, text[], uuid, text) from public, anon, authenticated;
revoke all on function public.release_legal_hold(uuid, text, text, text[], uuid, text) from public, anon, authenticated;
grant execute on function public.place_legal_hold(uuid, uuid, public.legal_hold_scope_type, uuid, text, text, text[], uuid, text) to authenticated;
grant execute on function public.release_legal_hold(uuid, text, text, text[], uuid, text) to authenticated;
