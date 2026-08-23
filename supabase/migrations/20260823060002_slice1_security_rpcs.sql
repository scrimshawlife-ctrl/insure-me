-- Slice 1 completion: trusted tenant context, permissions, atomic quote/audit settlement.
-- Auth claim helpers are defined here because this migration depends on them.

create or replace function public.current_tenant_id()
returns uuid
language sql
stable
as $$
  select nullif(
    coalesce(
      auth.jwt() ->> 'tenant_id',
      auth.jwt() -> 'app_metadata' ->> 'active_tenant_id'
    ),
    ''
  )::uuid
$$;

create or replace function public.workforce_mfa_satisfied()
returns boolean
language sql
stable
as $$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
$$;

create or replace function public.has_tenant_membership(target_tenant uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_tenant_id() = target_tenant
    and exists (
      select 1
      from public.agency_users au
      where au.tenant_id = target_tenant
        and au.workforce_identity_id = auth.uid()
        and au.status = 'ACTIVE'
    )
$$;

create or replace function public.has_permission(
  target_tenant uuid,
  target_agency uuid,
  required_permission public.permission_code
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_tenant_membership(target_tenant)
    and exists (
      select 1
      from public.agency_users au
      join public.agency_user_roles aur on aur.agency_user_id = au.agency_user_id
      join public.roles r on r.role_id = aur.role_id
      where au.tenant_id = target_tenant
        and au.agency_id = target_agency
        and au.workforce_identity_id = auth.uid()
        and au.status = 'ACTIVE'
        and r.tenant_id = target_tenant
        and r.agency_id = target_agency
        and required_permission = any(r.permissions)
    )
$$;

create or replace function public.quote_transition_allowed(
  from_state public.quote_case_state,
  to_state public.quote_case_state
)
returns boolean
language sql
immutable
as $$
  select case from_state
    when 'DRAFT' then to_state = any(array['NOTICE_REQUIRED','ABANDONED']::public.quote_case_state[])
    when 'NOTICE_REQUIRED' then to_state = any(array['CONSUMER_INPUT','ABANDONED']::public.quote_case_state[])
    when 'CONSUMER_INPUT' then to_state = any(array['DATA_ENRICHMENT','REVIEW_REQUIRED','ABANDONED']::public.quote_case_state[])
    when 'DATA_ENRICHMENT' then to_state = any(array['REVIEW_REQUIRED','READY_FOR_CARRIER','ABANDONED']::public.quote_case_state[])
    when 'REVIEW_REQUIRED' then to_state = any(array['CONSUMER_INPUT','DATA_ENRICHMENT','READY_FOR_CARRIER','ABANDONED']::public.quote_case_state[])
    when 'READY_FOR_CARRIER' then to_state = any(array['REVIEW_REQUIRED','SUBMITTED_TO_CARRIER','ABANDONED']::public.quote_case_state[])
    when 'SUBMITTED_TO_CARRIER' then to_state = any(array['CARRIER_RESPONSE','FOLLOW_UP']::public.quote_case_state[])
    when 'CARRIER_RESPONSE' then to_state = any(array['FOLLOW_UP','CLOSED']::public.quote_case_state[])
    when 'FOLLOW_UP' then to_state = any(array['REVIEW_REQUIRED','READY_FOR_CARRIER','CLOSED','ABANDONED']::public.quote_case_state[])
    when 'CLOSED' then to_state = 'RETENTION_HOLD'::public.quote_case_state
    when 'ABANDONED' then to_state = 'RETENTION_HOLD'::public.quote_case_state
    when 'RETENTION_HOLD' then false
    else false
  end
$$;

create or replace function public.transition_quote_case_with_audit(
  p_quote_case_id uuid,
  p_to_state public.quote_case_state,
  p_event_type text,
  p_reason_codes text[] default '{}'
)
returns public.quote_cases
language plpgsql
security definer
set search_path = public
as $$
declare
  v_case public.quote_cases;
  v_actor uuid := auth.uid();
  v_integrity_hash text;
begin
  if v_actor is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;

  select * into v_case
  from public.quote_cases
  where quote_case_id = p_quote_case_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'QUOTE_CASE_NOT_FOUND';
  end if;

  if not public.has_permission(v_case.tenant_id, v_case.agency_id, 'CASE_WRITE') then
    raise exception using errcode = '42501', message = 'CASE_WRITE_NOT_PERMITTED';
  end if;

  if not public.quote_transition_allowed(v_case.state, p_to_state) then
    raise exception using errcode = '22023',
      message = 'QUOTE_CASE_TRANSITION_NOT_ALLOWED:' || v_case.state::text || '->' || p_to_state::text;
  end if;

  update public.quote_cases
  set state = p_to_state,
      updated_at = now(),
      closed_at = case when p_to_state in ('CLOSED','ABANDONED') then now() else closed_at end
  where quote_case_id = p_quote_case_id
  returning * into v_case;

  v_integrity_hash := encode(
    digest(
      concat_ws('|',
        gen_random_uuid()::text,
        v_case.tenant_id::text,
        v_case.quote_case_id::text,
        p_event_type,
        v_case.state::text,
        clock_timestamp()::text
      ),
      'sha256'
    ),
    'hex'
  );

  insert into public.audit_events (
    tenant_id,
    agency_id,
    quote_case_id,
    event_type,
    actor_id,
    configuration_version_ref,
    outcome,
    reason_codes,
    integrity_hash,
    metadata
  ) values (
    v_case.tenant_id,
    v_case.agency_id,
    v_case.quote_case_id,
    p_event_type,
    v_actor,
    v_case.tenant_configuration_version::text,
    'SUCCEEDED',
    coalesce(p_reason_codes, '{}'),
    v_integrity_hash,
    jsonb_build_object('to_state', v_case.state::text)
  );

  return v_case;
end
$$;

create or replace function public.claim_idempotency_key(
  p_scope text,
  p_idempotency_key text,
  p_request_hash text
)
returns public.idempotency_keys
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := public.current_tenant_id();
  v_existing public.idempotency_keys;
begin
  if auth.uid() is null or v_tenant is null then
    raise exception using errcode = '42501', message = 'TRUSTED_TENANT_CONTEXT_REQUIRED';
  end if;

  if not public.has_tenant_membership(v_tenant) then
    raise exception using errcode = '42501', message = 'TENANT_MEMBERSHIP_REQUIRED';
  end if;

  select * into v_existing
  from public.idempotency_keys
  where tenant_id = v_tenant
    and scope = p_scope
    and idempotency_key = p_idempotency_key;

  if found then
    if v_existing.request_hash <> p_request_hash then
      raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUEST_MISMATCH';
    end if;
    return v_existing;
  end if;

  insert into public.idempotency_keys (
    tenant_id, scope, idempotency_key, request_hash, status
  ) values (
    v_tenant, p_scope, p_idempotency_key, p_request_hash, 'CLAIMED'
  )
  returning * into v_existing;

  return v_existing;
end
$$;

revoke all on function public.transition_quote_case_with_audit(uuid, public.quote_case_state, text, text[]) from public;
grant execute on function public.transition_quote_case_with_audit(uuid, public.quote_case_state, text, text[]) to authenticated;

revoke all on function public.claim_idempotency_key(text, text, text) from public;
grant execute on function public.claim_idempotency_key(text, text, text) to authenticated;
