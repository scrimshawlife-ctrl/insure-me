-- T808: version-bound adverse-action notice delivery evidence.
-- Provider acceptance is not represented as confirmed delivery.

create type public.notice_delivery_channel as enum ('EMAIL', 'POSTAL_MAIL', 'SECURE_PORTAL');
create type public.notice_delivery_status as enum ('PREPARED', 'DISPATCHED', 'DELIVERED', 'FAILED');
create type public.notice_delivery_outcome as enum (
  'ACCEPTED', 'DELIVERED', 'RETRYABLE_FAILURE', 'PERMANENT_FAILURE'
);
create type public.notice_delivery_certification_state as enum ('SYNTHETIC', 'CERTIFIED');

create table public.adverse_action_notice_deliveries (
  adverse_action_notice_delivery_id uuid primary key default gen_random_uuid(),
  adverse_action_case_id uuid not null references public.adverse_action_cases(adverse_action_case_id),
  tenant_id uuid not null,
  agency_id uuid not null,
  quote_case_id uuid not null references public.quote_cases(quote_case_id),
  owner_type public.adverse_action_owner_type not null,
  owner_ref text not null check (char_length(trim(owner_ref)) between 3 and 500),
  ownership_policy_version text not null check (char_length(trim(ownership_policy_version)) between 3 and 200),
  notice_definition_id uuid not null references public.notice_definitions(notice_definition_id),
  notice_version integer not null check (notice_version > 0),
  notice_content_hash text not null check (notice_content_hash ~ '^[0-9a-f]{64}$'),
  channel public.notice_delivery_channel not null,
  recipient_ref text not null check (char_length(trim(recipient_ref)) between 3 and 500),
  adapter_id text not null check (char_length(trim(adapter_id)) between 3 and 100),
  adapter_version text not null check (char_length(trim(adapter_version)) between 1 and 100),
  delivery_policy_version text not null check (char_length(trim(delivery_policy_version)) between 3 and 200),
  certification_state public.notice_delivery_certification_state not null,
  status public.notice_delivery_status not null default 'PREPARED',
  idempotency_key uuid not null,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  prepared_by uuid not null,
  prepared_at timestamptz not null default now(),
  dispatched_at timestamptz,
  delivered_at timestamptz,
  failed_at timestamptz,
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  unique (tenant_id, agency_id, idempotency_key),
  check (
    (status = 'PREPARED' and dispatched_at is null and delivered_at is null and failed_at is null)
    or (status = 'DISPATCHED' and dispatched_at is not null and delivered_at is null and failed_at is null)
    or (status = 'DELIVERED' and dispatched_at is not null and delivered_at is not null and failed_at is null)
    or (status = 'FAILED' and delivered_at is null and failed_at is not null)
  )
);

create index adverse_action_notice_deliveries_case_idx
  on public.adverse_action_notice_deliveries (tenant_id, agency_id, adverse_action_case_id, prepared_at desc);

create table public.adverse_action_notice_delivery_attempts (
  adverse_action_notice_delivery_attempt_id uuid primary key default gen_random_uuid(),
  adverse_action_notice_delivery_id uuid not null
    references public.adverse_action_notice_deliveries(adverse_action_notice_delivery_id),
  tenant_id uuid not null,
  agency_id uuid not null,
  outcome public.notice_delivery_outcome not null,
  adapter_id text not null,
  adapter_version text not null,
  delivery_policy_version text not null,
  evidence_ref text not null check (char_length(trim(evidence_ref)) between 3 and 500),
  reason_codes text[] not null check (cardinality(reason_codes) > 0),
  idempotency_key uuid not null,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  attempted_by uuid not null,
  attempted_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  unique (adverse_action_notice_delivery_id, idempotency_key)
);

create index adverse_action_notice_delivery_attempts_delivery_idx
  on public.adverse_action_notice_delivery_attempts
    (adverse_action_notice_delivery_id, attempted_at desc);

create or replace function private.enforce_adverse_action_notice_evidence_immutability()
returns trigger language plpgsql security definer set search_path = public, private as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = '22023', message = 'NOTICE_DELIVERY_EVIDENCE_IMMUTABLE';
  end if;
  if tg_table_name = 'adverse_action_notice_delivery_attempts' then
    raise exception using errcode = '22023', message = 'NOTICE_DELIVERY_EVIDENCE_IMMUTABLE';
  end if;
  if new.adverse_action_case_id is distinct from old.adverse_action_case_id
    or new.tenant_id is distinct from old.tenant_id
    or new.agency_id is distinct from old.agency_id
    or new.quote_case_id is distinct from old.quote_case_id
    or new.owner_type is distinct from old.owner_type
    or new.owner_ref is distinct from old.owner_ref
    or new.ownership_policy_version is distinct from old.ownership_policy_version
    or new.notice_definition_id is distinct from old.notice_definition_id
    or new.notice_version is distinct from old.notice_version
    or new.notice_content_hash is distinct from old.notice_content_hash
    or new.channel is distinct from old.channel
    or new.recipient_ref is distinct from old.recipient_ref
    or new.adapter_id is distinct from old.adapter_id
    or new.adapter_version is distinct from old.adapter_version
    or new.delivery_policy_version is distinct from old.delivery_policy_version
    or new.certification_state is distinct from old.certification_state
    or new.idempotency_key is distinct from old.idempotency_key
    or new.request_hash is distinct from old.request_hash
    or new.prepared_by is distinct from old.prepared_by
    or new.prepared_at is distinct from old.prepared_at then
    raise exception using errcode = '22023', message = 'NOTICE_DELIVERY_EVIDENCE_IMMUTABLE';
  end if;
  return new;
end
$$;
revoke all on function private.enforce_adverse_action_notice_evidence_immutability() from public;

create trigger adverse_action_notice_deliveries_immutable
before update or delete on public.adverse_action_notice_deliveries
for each row execute function private.enforce_adverse_action_notice_evidence_immutability();
create trigger adverse_action_notice_delivery_attempts_immutable
before update or delete on public.adverse_action_notice_delivery_attempts
for each row execute function private.enforce_adverse_action_notice_evidence_immutability();

create or replace function private.prepare_adverse_action_notice_delivery_impl(
  p_adverse_action_case_id uuid,
  p_notice_definition_id uuid,
  p_notice_content_hash text,
  p_channel public.notice_delivery_channel,
  p_recipient_ref text,
  p_adapter_id text,
  p_adapter_version text,
  p_delivery_policy_version text,
  p_certification_state public.notice_delivery_certification_state,
  p_idempotency_key uuid,
  p_request_hash text
)
returns public.adverse_action_notice_deliveries
language plpgsql security definer set search_path = public, private, extensions as $$
declare
  v_actor uuid := auth.uid();
  v_case public.adverse_action_cases;
  v_quote public.quote_cases;
  v_notice public.notice_definitions;
  v_existing public.adverse_action_notice_deliveries;
  v_delivery public.adverse_action_notice_deliveries;
  v_hash text;
begin
  if v_actor is null then raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED'; end if;
  select * into v_case from public.adverse_action_cases
    where adverse_action_case_id = p_adverse_action_case_id;
  if not found then raise exception using errcode = 'P0002', message = 'ADVERSE_ACTION_CASE_NOT_FOUND'; end if;
  if not private.has_permission(v_case.tenant_id, v_case.agency_id, 'POLICY_ADMIN') then
    raise exception using errcode = '42501', message = 'ADVERSE_ACTION_ADMIN_NOT_PERMITTED';
  end if;
  if v_case.status <> 'HANDED_OFF' then
    raise exception using errcode = '22023', message = 'ADVERSE_ACTION_HANDOFF_REQUIRED';
  end if;
  if char_length(trim(p_recipient_ref)) not between 3 and 500
    or char_length(trim(p_adapter_id)) not between 3 and 100
    or char_length(trim(p_adapter_version)) not between 1 and 100
    or char_length(trim(p_delivery_policy_version)) not between 3 and 200
    or p_request_hash !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'NOTICE_DELIVERY_INPUT_INVALID';
  end if;
  select * into v_existing from public.adverse_action_notice_deliveries
    where tenant_id = v_case.tenant_id and agency_id = v_case.agency_id
      and idempotency_key = p_idempotency_key;
  if found then
    if v_existing.request_hash <> p_request_hash then
      raise exception using errcode = '22023', message = 'NOTICE_DELIVERY_IDEMPOTENCY_MISMATCH';
    end if;
    return v_existing;
  end if;
  select * into v_quote from public.quote_cases where quote_case_id = v_case.quote_case_id;
  select * into v_notice from public.notice_definitions
    where notice_definition_id = p_notice_definition_id
      and tenant_id = v_case.tenant_id and agency_id = v_case.agency_id
      and jurisdiction = v_quote.jurisdiction and product_line = v_quote.product_line
      and category = 'ADVERSE_ACTION'
      and content_hash = p_notice_content_hash
      and ((p_certification_state = 'SYNTHETIC' and status = 'SYNTHETIC')
        or (p_certification_state = 'CERTIFIED' and status = 'APPROVED'))
      and (effective_at is null or effective_at <= now())
      and (retired_at is null or retired_at > now());
  if not found then
    raise exception using errcode = '22023', message = 'ADVERSE_ACTION_NOTICE_NOT_AVAILABLE';
  end if;
  insert into public.adverse_action_notice_deliveries (
    adverse_action_case_id, tenant_id, agency_id, quote_case_id,
    owner_type, owner_ref, ownership_policy_version, notice_definition_id,
    notice_version, notice_content_hash, channel, recipient_ref, adapter_id,
    adapter_version, delivery_policy_version, certification_state,
    idempotency_key, request_hash, prepared_by
  ) values (
    v_case.adverse_action_case_id, v_case.tenant_id, v_case.agency_id, v_case.quote_case_id,
    v_case.owner_type, v_case.owner_ref, v_case.ownership_policy_version,
    v_notice.notice_definition_id, v_notice.version, v_notice.content_hash,
    p_channel, trim(p_recipient_ref), trim(p_adapter_id), trim(p_adapter_version),
    trim(p_delivery_policy_version), p_certification_state,
    p_idempotency_key, p_request_hash, v_actor
  ) returning * into v_delivery;
  v_hash := encode(digest(concat_ws('|', v_delivery.adverse_action_notice_delivery_id::text,
    v_delivery.notice_definition_id::text, v_delivery.notice_version::text,
    v_delivery.notice_content_hash, v_delivery.request_hash, 'PREPARED'), 'sha256'), 'hex');
  insert into public.audit_events (tenant_id, agency_id, quote_case_id, event_type,
    actor_id, subject_ref, configuration_version_ref, outcome, reason_codes,
    integrity_hash, metadata)
  values (v_case.tenant_id, v_case.agency_id, v_case.quote_case_id,
    'ADVERSE_ACTION_NOTICE_PREPARED', v_actor,
    'notice-delivery:' || v_delivery.adverse_action_notice_delivery_id::text,
    v_quote.tenant_configuration_version::text, 'SUCCEEDED', array['NOTICE_VERSION_BOUND'],
    v_hash, jsonb_build_object('adverse_action_case_id', v_case.adverse_action_case_id,
      'notice_definition_id', v_notice.notice_definition_id, 'notice_version', v_notice.version,
      'notice_content_hash', v_notice.content_hash, 'channel', p_channel,
      'adapter_id', p_adapter_id, 'adapter_version', p_adapter_version,
      'delivery_policy_version', p_delivery_policy_version,
      'certification_state', p_certification_state));
  return v_delivery;
end
$$;

create or replace function private.settle_adverse_action_notice_delivery_impl(
  p_adverse_action_notice_delivery_id uuid,
  p_outcome public.notice_delivery_outcome,
  p_adapter_id text,
  p_adapter_version text,
  p_delivery_policy_version text,
  p_evidence_ref text,
  p_reason_codes text[],
  p_idempotency_key uuid,
  p_request_hash text
)
returns public.adverse_action_notice_deliveries
language plpgsql security definer set search_path = public, private, extensions as $$
declare
  v_actor uuid := auth.uid();
  v_delivery public.adverse_action_notice_deliveries;
  v_attempt public.adverse_action_notice_delivery_attempts;
  v_now timestamptz := now();
  v_hash text;
begin
  if v_actor is null then raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED'; end if;
  select * into v_delivery from public.adverse_action_notice_deliveries
    where adverse_action_notice_delivery_id = p_adverse_action_notice_delivery_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'NOTICE_DELIVERY_NOT_FOUND'; end if;
  if not private.has_permission(v_delivery.tenant_id, v_delivery.agency_id, 'POLICY_ADMIN') then
    raise exception using errcode = '42501', message = 'ADVERSE_ACTION_ADMIN_NOT_PERMITTED';
  end if;
  if p_adapter_id <> v_delivery.adapter_id or p_adapter_version <> v_delivery.adapter_version
    or p_delivery_policy_version <> v_delivery.delivery_policy_version then
    raise exception using errcode = '22023', message = 'NOTICE_DELIVERY_ADAPTER_MISMATCH';
  end if;
  if char_length(trim(p_evidence_ref)) not between 3 and 500
    or coalesce(cardinality(p_reason_codes), 0) = 0
    or p_request_hash !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'NOTICE_DELIVERY_EVIDENCE_INVALID';
  end if;
  select * into v_attempt from public.adverse_action_notice_delivery_attempts
    where adverse_action_notice_delivery_id = p_adverse_action_notice_delivery_id
      and idempotency_key = p_idempotency_key;
  if found then
    if v_attempt.request_hash <> p_request_hash then
      raise exception using errcode = '22023', message = 'NOTICE_DELIVERY_SETTLEMENT_IDEMPOTENCY_MISMATCH';
    end if;
    return v_delivery;
  end if;
  if v_delivery.status = 'DELIVERED' then
    raise exception using errcode = '22023', message = 'NOTICE_DELIVERY_ALREADY_COMPLETED';
  end if;
  insert into public.adverse_action_notice_delivery_attempts (
    adverse_action_notice_delivery_id, tenant_id, agency_id, outcome,
    adapter_id, adapter_version, delivery_policy_version, evidence_ref,
    reason_codes, idempotency_key, request_hash, attempted_by
  ) values (
    v_delivery.adverse_action_notice_delivery_id, v_delivery.tenant_id, v_delivery.agency_id,
    p_outcome, p_adapter_id, p_adapter_version, p_delivery_policy_version,
    trim(p_evidence_ref), p_reason_codes, p_idempotency_key, p_request_hash, v_actor
  );
  update public.adverse_action_notice_deliveries set
    status = case p_outcome when 'ACCEPTED' then 'DISPATCHED'::public.notice_delivery_status
      when 'DELIVERED' then 'DELIVERED'::public.notice_delivery_status
      else 'FAILED'::public.notice_delivery_status end,
    dispatched_at = case when p_outcome in ('ACCEPTED','DELIVERED')
      then coalesce(dispatched_at, v_now) else dispatched_at end,
    delivered_at = case when p_outcome = 'DELIVERED' then v_now else null end,
    failed_at = case when p_outcome in ('RETRYABLE_FAILURE','PERMANENT_FAILURE') then v_now else null end
  where adverse_action_notice_delivery_id = p_adverse_action_notice_delivery_id
  returning * into v_delivery;
  v_hash := encode(digest(concat_ws('|', v_delivery.adverse_action_notice_delivery_id::text,
    p_outcome::text, p_evidence_ref, p_request_hash), 'sha256'), 'hex');
  insert into public.audit_events (tenant_id, agency_id, quote_case_id, event_type,
    actor_id, subject_ref, outcome, reason_codes, integrity_hash, metadata)
  values (v_delivery.tenant_id, v_delivery.agency_id, v_delivery.quote_case_id,
    'ADVERSE_ACTION_NOTICE_DELIVERY_ATTEMPTED', v_actor,
    'notice-delivery:' || v_delivery.adverse_action_notice_delivery_id::text,
    case when p_outcome = 'DELIVERED' then 'SUCCEEDED' else p_outcome::text end,
    p_reason_codes, v_hash, jsonb_build_object('delivery_outcome', p_outcome,
      'notice_definition_id', v_delivery.notice_definition_id,
      'notice_version', v_delivery.notice_version,
      'notice_content_hash', v_delivery.notice_content_hash,
      'channel', v_delivery.channel, 'adapter_id', p_adapter_id,
      'adapter_version', p_adapter_version,
      'delivery_policy_version', p_delivery_policy_version));
  return v_delivery;
end
$$;

revoke all on function private.prepare_adverse_action_notice_delivery_impl(uuid,uuid,text,public.notice_delivery_channel,text,text,text,text,public.notice_delivery_certification_state,uuid,text) from public;
revoke all on function private.settle_adverse_action_notice_delivery_impl(uuid,public.notice_delivery_outcome,text,text,text,text,text[],uuid,text) from public;
grant execute on function private.prepare_adverse_action_notice_delivery_impl(uuid,uuid,text,public.notice_delivery_channel,text,text,text,text,public.notice_delivery_certification_state,uuid,text) to authenticated;
grant execute on function private.settle_adverse_action_notice_delivery_impl(uuid,public.notice_delivery_outcome,text,text,text,text,text[],uuid,text) to authenticated;

create or replace function public.prepare_adverse_action_notice_delivery(
  p_adverse_action_case_id uuid, p_notice_definition_id uuid, p_notice_content_hash text,
  p_channel public.notice_delivery_channel, p_recipient_ref text, p_adapter_id text,
  p_adapter_version text, p_delivery_policy_version text,
  p_certification_state public.notice_delivery_certification_state,
  p_idempotency_key uuid, p_request_hash text
)
returns public.adverse_action_notice_deliveries language sql security invoker
set search_path = public, private as $$
  select private.prepare_adverse_action_notice_delivery_impl(p_adverse_action_case_id,
    p_notice_definition_id, p_notice_content_hash, p_channel, p_recipient_ref,
    p_adapter_id, p_adapter_version, p_delivery_policy_version,
    p_certification_state, p_idempotency_key, p_request_hash)
$$;
create or replace function public.settle_adverse_action_notice_delivery(
  p_adverse_action_notice_delivery_id uuid, p_outcome public.notice_delivery_outcome,
  p_adapter_id text, p_adapter_version text, p_delivery_policy_version text,
  p_evidence_ref text, p_reason_codes text[], p_idempotency_key uuid, p_request_hash text
)
returns public.adverse_action_notice_deliveries language sql security invoker
set search_path = public, private as $$
  select private.settle_adverse_action_notice_delivery_impl(
    p_adverse_action_notice_delivery_id, p_outcome, p_adapter_id, p_adapter_version,
    p_delivery_policy_version, p_evidence_ref, p_reason_codes,
    p_idempotency_key, p_request_hash)
$$;

revoke all on function public.prepare_adverse_action_notice_delivery(uuid,uuid,text,public.notice_delivery_channel,text,text,text,text,public.notice_delivery_certification_state,uuid,text) from public, anon, authenticated;
revoke all on function public.settle_adverse_action_notice_delivery(uuid,public.notice_delivery_outcome,text,text,text,text,text[],uuid,text) from public, anon, authenticated;
grant execute on function public.prepare_adverse_action_notice_delivery(uuid,uuid,text,public.notice_delivery_channel,text,text,text,text,public.notice_delivery_certification_state,uuid,text) to authenticated;
grant execute on function public.settle_adverse_action_notice_delivery(uuid,public.notice_delivery_outcome,text,text,text,text,text[],uuid,text) to authenticated;

alter table public.adverse_action_notice_deliveries enable row level security;
alter table public.adverse_action_notice_delivery_attempts enable row level security;
create policy adverse_action_notice_deliveries_workforce_select
  on public.adverse_action_notice_deliveries for select to authenticated
  using (private.has_tenant_membership(tenant_id));
create policy adverse_action_notice_delivery_attempts_workforce_select
  on public.adverse_action_notice_delivery_attempts for select to authenticated
  using (private.has_tenant_membership(tenant_id));
revoke all on public.adverse_action_notice_deliveries from anon, authenticated;
revoke all on public.adverse_action_notice_delivery_attempts from anon, authenticated;
grant select on public.adverse_action_notice_deliveries to authenticated;
grant select on public.adverse_action_notice_delivery_attempts to authenticated;
