-- Slice 4: server-only purpose decision and idempotent ExternalRequest creation.

create or replace function private.record_provider_purpose_decision(
  p_quote_case_id uuid,
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
  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id;
  if v_case.quote_case_id is null then
    raise exception 'QUOTE_CASE_NOT_FOUND' using errcode = 'P0002';
  end if;

  insert into public.permissible_purpose_decisions (
    tenant_id, quote_case_id, tenant_configuration_version, actor_id,
    jurisdiction, capability, purpose_code, outcome, reason_codes,
    policy_version
  ) values (
    v_case.tenant_id, v_case.quote_case_id, v_case.tenant_configuration_version, null,
    v_case.jurisdiction, p_capability, p_purpose_code,
    case when p_allowed then 'ALLOW'::public.purpose_outcome else 'DENY'::public.purpose_outcome end,
    coalesce(p_reason_codes, '{}'), p_policy_version
  ) returning decision_id into v_decision_id;

  v_integrity := encode(extensions.digest(
    concat_ws('|', v_case.tenant_id::text, v_case.quote_case_id::text,
      v_decision_id::text, p_capability, p_purpose_code, p_policy_version,
      case when p_allowed then 'ALLOW' else 'DENY' end), 'sha256'
  ), 'hex');

  insert into public.audit_events (
    tenant_id, agency_id, quote_case_id, event_type, subject_ref,
    configuration_version_ref, policy_version_refs, outcome, reason_codes,
    integrity_hash, metadata
  ) values (
    v_case.tenant_id, v_case.agency_id, v_case.quote_case_id,
    'PROVIDER_PURPOSE_EVALUATED', v_decision_id::text,
    v_case.tenant_configuration_version::text, array[p_policy_version],
    case when p_allowed then 'ALLOW' else 'DENY' end,
    coalesce(p_reason_codes, '{}'), v_integrity,
    jsonb_build_object('capability', p_capability, 'purposeCode', p_purpose_code)
  );

  return v_decision_id;
end;
$$;

create or replace function public.record_provider_purpose_decision(
  p_quote_case_id uuid,
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
    p_quote_case_id, p_capability, p_purpose_code, p_policy_version,
    p_allowed, p_reason_codes
  );
$$;

revoke all on function public.record_provider_purpose_decision(uuid,text,text,text,boolean,text[]) from public, anon, authenticated;
grant execute on function public.record_provider_purpose_decision(uuid,text,text,text,boolean,text[]) to service_role;

create or replace function private.create_provider_external_request(
  p_quote_case_id uuid,
  p_provider_binding_id uuid,
  p_capability public.provider_capability,
  p_subject_ids uuid[],
  p_decision_id uuid,
  p_consent_record_ids uuid[],
  p_idempotency_key text,
  p_request_hash text
) returns table (external_request_id uuid, reused boolean)
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_case public.quote_cases;
  v_binding public.provider_bindings;
  v_decision public.permissible_purpose_decisions;
  v_existing public.external_requests;
  v_new_id uuid;
begin
  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id;
  if v_case.quote_case_id is null then
    raise exception 'QUOTE_CASE_NOT_FOUND' using errcode = 'P0002';
  end if;

  select * into v_binding
  from public.provider_bindings
  where provider_binding_id = p_provider_binding_id
    and tenant_id = v_case.tenant_id
    and agency_id = v_case.agency_id
    and capability = p_capability
    and jurisdiction = v_case.jurisdiction
    and product_line = v_case.product_line
    and status = 'ACTIVE';
  if v_binding.provider_binding_id is null then
    raise exception 'PROVIDER_BINDING_NOT_ACTIVE' using errcode = '42501';
  end if;

  select * into v_decision
  from public.permissible_purpose_decisions
  where decision_id = p_decision_id
    and tenant_id = v_case.tenant_id
    and quote_case_id = p_quote_case_id
    and capability = p_capability::text
    and outcome = 'ALLOW';
  if v_decision.decision_id is null then
    raise exception 'PERMISSIBLE_PURPOSE_NOT_ALLOWED' using errcode = '42501';
  end if;

  select * into v_existing
  from public.external_requests
  where tenant_id = v_case.tenant_id
    and provider_binding_id = p_provider_binding_id
    and idempotency_key = p_idempotency_key;

  if v_existing.external_request_id is not null then
    if v_existing.request_hash <> p_request_hash then
      raise exception 'IDEMPOTENCY_KEY_REUSE_WITH_DIFFERENT_REQUEST' using errcode = '23505';
    end if;
    external_request_id := v_existing.external_request_id;
    reused := true;
    return next;
    return;
  end if;

  insert into public.external_requests (
    tenant_id, agency_id, quote_case_id, tenant_configuration_version,
    provider_binding_id, capability, subject_ids, permissible_purpose_decision_id,
    consent_record_ids, idempotency_key, request_hash, status
  ) values (
    v_case.tenant_id, v_case.agency_id, p_quote_case_id, v_case.tenant_configuration_version,
    p_provider_binding_id, p_capability, coalesce(p_subject_ids, '{}'), p_decision_id,
    coalesce(p_consent_record_ids, '{}'), p_idempotency_key, p_request_hash, 'PENDING'
  ) returning public.external_requests.external_request_id into v_new_id;

  external_request_id := v_new_id;
  reused := false;
  return next;
end;
$$;

create or replace function public.create_provider_external_request(
  p_quote_case_id uuid,
  p_provider_binding_id uuid,
  p_capability public.provider_capability,
  p_subject_ids uuid[],
  p_decision_id uuid,
  p_consent_record_ids uuid[],
  p_idempotency_key text,
  p_request_hash text
) returns table (external_request_id uuid, reused boolean)
language sql
security definer
set search_path = public, private, extensions
as $$
  select * from private.create_provider_external_request(
    p_quote_case_id, p_provider_binding_id, p_capability, p_subject_ids,
    p_decision_id, p_consent_record_ids, p_idempotency_key, p_request_hash
  );
$$;

revoke all on function public.create_provider_external_request(uuid,uuid,public.provider_capability,uuid[],uuid,uuid[],text,text) from public, anon, authenticated;
grant execute on function public.create_provider_external_request(uuid,uuid,public.provider_capability,uuid[],uuid,uuid[],text,text) to service_role;
