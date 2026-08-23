-- Preserve the authenticated workforce actor across the service-principal settlement boundary.

create or replace function private.record_provider_purpose_decision(
  p_quote_case_id uuid,
  p_actor_id uuid,
  p_capability text,
  p_purpose_code text,
  p_policy_version text,
  p_allowed boolean,
  p_reason_codes text[] default '{}'
) returns uuid
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_case public.quote_cases;
  v_decision_id uuid;
  v_integrity text;
begin
  if p_actor_id is null then
    raise exception 'PROVIDER_ACTOR_REQUIRED' using errcode='22023';
  end if;

  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id;
  if v_case.quote_case_id is null then
    raise exception 'QUOTE_CASE_NOT_FOUND' using errcode = 'P0002';
  end if;

  if not exists (
    select 1 from public.agency_users au
    where au.workforce_identity_id=p_actor_id
      and au.tenant_id=v_case.tenant_id
      and au.agency_id=v_case.agency_id
      and au.status='ACTIVE'
  ) then
    raise exception 'PROVIDER_ACTOR_NOT_ACTIVE_FOR_CASE' using errcode='42501';
  end if;

  insert into public.permissible_purpose_decisions (
    tenant_id, quote_case_id, tenant_configuration_version, actor_id,
    jurisdiction, capability, purpose_code, outcome, reason_codes,
    policy_version
  ) values (
    v_case.tenant_id, v_case.quote_case_id, v_case.tenant_configuration_version, p_actor_id,
    v_case.jurisdiction, p_capability, p_purpose_code,
    case when p_allowed then 'ALLOW'::public.purpose_outcome else 'DENY'::public.purpose_outcome end,
    coalesce(p_reason_codes, '{}'), p_policy_version
  ) returning decision_id into v_decision_id;

  v_integrity := encode(extensions.digest(
    concat_ws('|', v_case.tenant_id::text, v_case.quote_case_id::text,
      v_decision_id::text, p_actor_id::text, p_capability, p_purpose_code, p_policy_version,
      case when p_allowed then 'ALLOW' else 'DENY' end), 'sha256'
  ), 'hex');

  insert into public.audit_events (
    tenant_id, agency_id, quote_case_id, event_type, actor_id, subject_ref,
    configuration_version_ref, policy_version_refs, outcome, reason_codes,
    integrity_hash, metadata
  ) values (
    v_case.tenant_id, v_case.agency_id, v_case.quote_case_id,
    'PROVIDER_PURPOSE_EVALUATED', p_actor_id, v_decision_id::text,
    v_case.tenant_configuration_version::text, array[p_policy_version],
    case when p_allowed then 'ALLOW' else 'DENY' end,
    coalesce(p_reason_codes, '{}'), v_integrity,
    jsonb_build_object('capability', p_capability, 'purposeCode', p_purpose_code)
  );

  return v_decision_id;
end;
$$;

-- Replace the old public signature so callers cannot omit actor provenance.
drop function if exists public.record_provider_purpose_decision(uuid,text,text,text,boolean,text[]);

create or replace function public.record_provider_purpose_decision(
  p_quote_case_id uuid,
  p_actor_id uuid,
  p_capability text,
  p_purpose_code text,
  p_policy_version text,
  p_allowed boolean,
  p_reason_codes text[] default '{}'
) returns uuid
language sql
security definer
set search_path = public, private, extensions
as $$
  select private.record_provider_purpose_decision(
    p_quote_case_id, p_actor_id, p_capability, p_purpose_code, p_policy_version,
    p_allowed, p_reason_codes
  );
$$;

revoke all on function public.record_provider_purpose_decision(uuid,uuid,text,text,text,boolean,text[]) from public, anon, authenticated;
grant execute on function public.record_provider_purpose_decision(uuid,uuid,text,text,text,boolean,text[]) to service_role;
