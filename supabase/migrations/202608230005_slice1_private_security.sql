-- Slice 1 hardening: privileged helpers live in a non-exposed schema.
-- Public RPCs are SECURITY INVOKER wrappers with narrow grants.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create or replace function private.has_tenant_membership(target_tenant uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select public.workforce_mfa_satisfied()
    and public.current_tenant_id() = target_tenant
    and exists (
      select 1
      from public.agency_users au
      where au.tenant_id = target_tenant
        and au.workforce_identity_id = auth.uid()
        and au.status = 'ACTIVE'
    )
$$;

create or replace function private.has_permission(
  target_tenant uuid,
  target_agency uuid,
  required_permission public.permission_code
)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select private.has_tenant_membership(target_tenant)
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

create or replace function private.transition_quote_case_with_audit_impl(
  p_quote_case_id uuid,
  p_to_state public.quote_case_state,
  p_event_type text,
  p_reason_codes text[] default '{}'
)
returns public.quote_cases
language plpgsql
security definer
set search_path = public, private
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

  if not private.has_permission(v_case.tenant_id, v_case.agency_id, 'CASE_WRITE') then
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

create or replace function private.claim_idempotency_key_impl(
  p_scope text,
  p_idempotency_key text,
  p_request_hash text
)
returns public.idempotency_keys
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_tenant uuid := public.current_tenant_id();
  v_existing public.idempotency_keys;
begin
  if auth.uid() is null or v_tenant is null then
    raise exception using errcode = '42501', message = 'TRUSTED_TENANT_CONTEXT_REQUIRED';
  end if;

  if not private.has_tenant_membership(v_tenant) then
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

create or replace function private.get_current_workforce_context_impl()
returns table (
  agency_user_id uuid,
  tenant_id uuid,
  agency_id uuid,
  permissions public.permission_code[]
)
language sql
stable
security definer
set search_path = public, private
as $$
  select
    au.agency_user_id,
    au.tenant_id,
    au.agency_id,
    coalesce(
      array_agg(distinct permission_value) filter (where permission_value is not null),
      '{}'::public.permission_code[]
    ) as permissions
  from public.agency_users au
  left join public.agency_user_roles aur on aur.agency_user_id = au.agency_user_id
  left join public.roles r
    on r.role_id = aur.role_id
   and r.tenant_id = au.tenant_id
   and r.agency_id = au.agency_id
  left join lateral unnest(coalesce(r.permissions, '{}'::public.permission_code[])) as permission_value on true
  where au.workforce_identity_id = auth.uid()
    and au.status = 'ACTIVE'
    and au.tenant_id = public.current_tenant_id()
    and public.workforce_mfa_satisfied()
  group by au.agency_user_id, au.tenant_id, au.agency_id
$$;

revoke all on function private.has_tenant_membership(uuid) from public;
revoke all on function private.has_permission(uuid, uuid, public.permission_code) from public;
revoke all on function private.transition_quote_case_with_audit_impl(uuid, public.quote_case_state, text, text[]) from public;
revoke all on function private.claim_idempotency_key_impl(text, text, text) from public;
revoke all on function private.get_current_workforce_context_impl() from public;

grant execute on function private.has_tenant_membership(uuid) to authenticated;
grant execute on function private.has_permission(uuid, uuid, public.permission_code) to authenticated;
grant execute on function private.transition_quote_case_with_audit_impl(uuid, public.quote_case_state, text, text[]) to authenticated;
grant execute on function private.claim_idempotency_key_impl(text, text, text) to authenticated;
grant execute on function private.get_current_workforce_context_impl() to authenticated;

-- Replace exposed privileged functions with invoker wrappers.
create or replace function public.transition_quote_case_with_audit(
  p_quote_case_id uuid,
  p_to_state public.quote_case_state,
  p_event_type text,
  p_reason_codes text[] default '{}'
)
returns public.quote_cases
language sql
security invoker
set search_path = public, private
as $$
  select private.transition_quote_case_with_audit_impl(
    p_quote_case_id,
    p_to_state,
    p_event_type,
    p_reason_codes
  )
$$;

create or replace function public.claim_idempotency_key(
  p_scope text,
  p_idempotency_key text,
  p_request_hash text
)
returns public.idempotency_keys
language sql
security invoker
set search_path = public, private
as $$
  select private.claim_idempotency_key_impl(
    p_scope,
    p_idempotency_key,
    p_request_hash
  )
$$;

create or replace function public.get_current_workforce_context()
returns table (
  agency_user_id uuid,
  tenant_id uuid,
  agency_id uuid,
  permissions public.permission_code[]
)
language sql
stable
security invoker
set search_path = public, private
as $$
  select * from private.get_current_workforce_context_impl()
$$;

-- Remove obsolete exposed security-definer helpers after policies are replaced below.
drop policy if exists agencies_tenant_select on public.agencies;
drop policy if exists tenant_configurations_tenant_select on public.tenant_configurations;
drop policy if exists roles_tenant_select on public.roles;
drop policy if exists agency_users_tenant_select on public.agency_users;
drop policy if exists prospects_tenant_all on public.prospects;
drop policy if exists quote_cases_tenant_all on public.quote_cases;
drop policy if exists purpose_decisions_tenant_all on public.permissible_purpose_decisions;
drop policy if exists audit_events_tenant_select on public.audit_events;
drop policy if exists idempotency_tenant_all on public.idempotency_keys;

create policy agencies_tenant_select on public.agencies
for select to authenticated
using (private.has_tenant_membership(tenant_id));

create policy tenant_configurations_tenant_select on public.tenant_configurations
for select to authenticated
using (private.has_tenant_membership(tenant_id));

create policy roles_tenant_select on public.roles
for select to authenticated
using (private.has_tenant_membership(tenant_id));

create policy agency_users_tenant_select on public.agency_users
for select to authenticated
using (private.has_tenant_membership(tenant_id));

create policy prospects_tenant_select on public.prospects
for select to authenticated
using (private.has_tenant_membership(tenant_id));

create policy quote_cases_tenant_select on public.quote_cases
for select to authenticated
using (private.has_tenant_membership(tenant_id));

create policy purpose_decisions_tenant_select on public.permissible_purpose_decisions
for select to authenticated
using (private.has_permission(tenant_id, (
  select qc.agency_id from public.quote_cases qc where qc.quote_case_id = permissible_purpose_decisions.quote_case_id
), 'REPORT_RETRIEVE'));

create policy audit_events_tenant_select on public.audit_events
for select to authenticated
using (
  agency_id is not null
  and private.has_permission(tenant_id, agency_id, 'AUDIT_READ')
);

-- Public Data API access is intentionally read-only for the Slice 1 workforce tables.
-- Mutations happen only through checked RPCs or later explicitly specified consumer flows.
revoke all on public.agencies from anon, authenticated;
revoke all on public.tenant_configurations from anon, authenticated;
revoke all on public.roles from anon, authenticated;
revoke all on public.agency_users from anon, authenticated;
revoke all on public.agency_user_roles from anon, authenticated;
revoke all on public.prospects from anon, authenticated;
revoke all on public.quote_cases from anon, authenticated;
revoke all on public.permissible_purpose_decisions from anon, authenticated;
revoke all on public.audit_events from anon, authenticated;
revoke all on public.idempotency_keys from anon, authenticated;

grant select on public.agencies to authenticated;
grant select on public.tenant_configurations to authenticated;
grant select on public.roles to authenticated;
grant select on public.agency_users to authenticated;
grant select on public.prospects to authenticated;
grant select on public.quote_cases to authenticated;
grant select on public.permissible_purpose_decisions to authenticated;
grant select on public.audit_events to authenticated;

revoke all on function public.has_tenant_membership(uuid) from public, anon, authenticated;
revoke all on function public.has_permission(uuid, uuid, public.permission_code) from public, anon, authenticated;
drop function public.has_tenant_membership(uuid);
drop function public.has_permission(uuid, uuid, public.permission_code);

revoke all on function public.transition_quote_case_with_audit(uuid, public.quote_case_state, text, text[]) from public, anon;
grant execute on function public.transition_quote_case_with_audit(uuid, public.quote_case_state, text, text[]) to authenticated;

revoke all on function public.claim_idempotency_key(text, text, text) from public, anon;
grant execute on function public.claim_idempotency_key(text, text, text) to authenticated;

revoke all on function public.get_current_workforce_context() from public, anon;
grant execute on function public.get_current_workforce_context() to authenticated;
