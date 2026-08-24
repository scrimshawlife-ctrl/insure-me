-- T811: read-only, active-agency policy inspection administration.

-- Policy tables are not directly exposed. Checked RPCs derive one eligible
-- MFA-backed workforce scope and return exact versioned configuration only.
revoke all on table public.data_use_policy_rules from anon, authenticated;
revoke all on table public.retention_policies from anon, authenticated;

create or replace function private.policy_inspection_context(p_policy_kind text)
returns table (tenant_id uuid, agency_id uuid)
language plpgsql stable security definer
set search_path = public, private
as $$
declare
  v_count integer;
  v_tenant uuid;
  v_agency uuid;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;

  select count(*), (array_agg(w.tenant_id))[1], (array_agg(w.agency_id))[1]
    into v_count, v_tenant, v_agency
  from private.get_current_workforce_context_impl() w
  where (p_policy_kind = 'DATA_USE' and 'POLICY_ADMIN' = any(w.permissions))
     or (p_policy_kind = 'RETENTION' and (
       'POLICY_ADMIN' = any(w.permissions) or 'PRIVACY_ADMIN' = any(w.permissions)
     ));

  if p_policy_kind not in ('DATA_USE', 'RETENTION') or v_count <> 1 then
    raise exception using errcode = 'P0002', message = 'POLICY_INSPECTION_SCOPE_NOT_FOUND';
  end if;
  return query select v_tenant, v_agency;
end
$$;
revoke all on function private.policy_inspection_context(text) from public;
grant execute on function private.policy_inspection_context(text) to authenticated;

create or replace function private.list_data_use_policy_rules_impl()
returns table (
  data_use_policy_rule_id uuid, policy_version text, observation_type text,
  collection_allowed boolean, agent_display_allowed boolean,
  underwriting_allowed boolean, rating_submission_allowed boolean,
  carrier_only boolean, prohibited boolean, effective_at timestamptz,
  retired_at timestamptz, created_at timestamptz
)
language sql stable security definer
set search_path = public, private
as $$
  select r.data_use_policy_rule_id, r.policy_version, r.observation_type,
    r.collection_allowed, r.agent_display_allowed, r.underwriting_allowed,
    r.rating_submission_allowed, r.carrier_only, r.prohibited,
    r.effective_at, r.retired_at, r.created_at
  from public.data_use_policy_rules r
  join private.policy_inspection_context('DATA_USE') c
    on c.tenant_id = r.tenant_id and c.agency_id = r.agency_id
  order by r.policy_version desc, r.observation_type, r.data_use_policy_rule_id
  limit 1000
$$;
revoke all on function private.list_data_use_policy_rules_impl() from public;
grant execute on function private.list_data_use_policy_rules_impl() to authenticated;

create or replace function public.list_data_use_policy_rules()
returns table (
  data_use_policy_rule_id uuid, policy_version text, observation_type text,
  collection_allowed boolean, agent_display_allowed boolean,
  underwriting_allowed boolean, rating_submission_allowed boolean,
  carrier_only boolean, prohibited boolean, effective_at timestamptz,
  retired_at timestamptz, created_at timestamptz
)
language sql stable security invoker
set search_path = public, private
as $$ select * from private.list_data_use_policy_rules_impl() $$;
revoke all on function public.list_data_use_policy_rules() from public, anon, authenticated;
grant execute on function public.list_data_use_policy_rules() to authenticated;

create or replace function private.list_retention_policies_impl()
returns table (
  retention_policy_id uuid, policy_set_id text, version integer,
  data_class text, jurisdiction text, provider_contract_ref text,
  carrier_program_ref text, tenant_role text, retention_interval text,
  disposition public.retention_disposition,
  legal_hold_blocks_destructive_disposition boolean,
  certification_state public.retention_policy_certification_state,
  legal_authority_refs text[], contract_authority_refs text[],
  effective_at timestamptz, retired_at timestamptz, created_at timestamptz
)
language sql stable security definer
set search_path = public, private
as $$
  select r.retention_policy_id, r.policy_set_id, r.version, r.data_class,
    r.jurisdiction, r.provider_contract_ref, r.carrier_program_ref, r.tenant_role,
    r.retention_interval::text, r.disposition,
    r.legal_hold_blocks_destructive_disposition, r.certification_state,
    r.legal_authority_refs, r.contract_authority_refs,
    r.effective_at, r.retired_at, r.created_at
  from public.retention_policies r
  join private.policy_inspection_context('RETENTION') c
    on c.tenant_id = r.tenant_id and c.agency_id = r.agency_id
  order by r.policy_set_id, r.data_class, r.version desc, r.retention_policy_id
  limit 1000
$$;
revoke all on function private.list_retention_policies_impl() from public;
grant execute on function private.list_retention_policies_impl() to authenticated;

create or replace function public.list_retention_policies()
returns table (
  retention_policy_id uuid, policy_set_id text, version integer,
  data_class text, jurisdiction text, provider_contract_ref text,
  carrier_program_ref text, tenant_role text, retention_interval text,
  disposition public.retention_disposition,
  legal_hold_blocks_destructive_disposition boolean,
  certification_state public.retention_policy_certification_state,
  legal_authority_refs text[], contract_authority_refs text[],
  effective_at timestamptz, retired_at timestamptz, created_at timestamptz
)
language sql stable security invoker
set search_path = public, private
as $$ select * from private.list_retention_policies_impl() $$;
revoke all on function public.list_retention_policies() from public, anon, authenticated;
grant execute on function public.list_retention_policies() to authenticated;
