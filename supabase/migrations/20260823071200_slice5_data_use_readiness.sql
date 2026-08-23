-- Slice 5: explicit data-use classification and completeness-only readiness.

alter table public.provider_bindings
  add column if not exists required_for_readiness boolean not null default false;

create table public.data_use_policy_rules (
  data_use_policy_rule_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  policy_version text not null,
  observation_type text not null,
  collection_allowed boolean not null default false,
  agent_display_allowed boolean not null default false,
  underwriting_allowed boolean not null default false,
  rating_submission_allowed boolean not null default false,
  carrier_only boolean not null default false,
  prohibited boolean not null default false,
  effective_at timestamptz not null default now(),
  retired_at timestamptz,
  created_at timestamptz not null default now(),
  unique (tenant_id, policy_version, observation_type),
  check (not (prohibited and (collection_allowed or agent_display_allowed or underwriting_allowed or rating_submission_allowed)))
);

create table public.readiness_issues (
  readiness_issue_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  quote_case_id uuid not null references public.quote_cases(quote_case_id) on delete cascade,
  carrier_program_id uuid,
  issue_type text not null,
  severity text not null check (severity in ('INFO','WARNING','BLOCKING')),
  blocking boolean not null,
  subject_ref text,
  reason_code text not null,
  resolution_state text not null default 'OPEN' check (resolution_state in ('OPEN','RESOLVED','SUPERSEDED')),
  resolution_evidence jsonb,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index readiness_issues_case_idx
  on public.readiness_issues (tenant_id, quote_case_id, resolution_state, blocking);

alter table public.data_use_policy_rules enable row level security;
alter table public.readiness_issues enable row level security;

create policy data_use_policy_workforce_select on public.data_use_policy_rules
for select to authenticated using (private.has_tenant_membership(tenant_id));
create policy readiness_issues_workforce_select on public.readiness_issues
for select to authenticated using (private.has_tenant_membership(tenant_id));

revoke insert, update, delete on public.data_use_policy_rules, public.readiness_issues from anon, authenticated;

create or replace function private.apply_data_use_policy(
  p_quote_case_id uuid,
  p_policy_version text
) returns integer
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_case public.quote_cases;
  v_updated integer;
begin
  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id;
  if v_case.quote_case_id is null then
    raise exception 'QUOTE_CASE_NOT_FOUND' using errcode = 'P0002';
  end if;

  update public.underwriting_observations o
  set data_use_classification = case
        when r.prohibited then 'PROHIBITED'
        when r.carrier_only then 'CARRIER_ONLY'
        when r.rating_submission_allowed then 'RATING_SUBMISSION_ALLOWED'
        when r.underwriting_allowed then 'UNDERWRITING_ALLOWED'
        when r.agent_display_allowed then 'DISPLAY_ALLOWED'
        when r.collection_allowed then 'COLLECTION_ONLY'
        else 'UNCLASSIFIED'
      end,
      data_use_policy_version = r.policy_version
  from public.data_use_policy_rules r
  where o.quote_case_id = p_quote_case_id
    and r.tenant_id = v_case.tenant_id
    and r.policy_version = p_policy_version
    and r.observation_type = o.observation_type
    and r.retired_at is null;

  get diagnostics v_updated = row_count;
  return v_updated;
end;
$$;

create or replace function public.apply_data_use_policy(
  p_quote_case_id uuid,
  p_policy_version text
) returns integer
language sql
security definer
set search_path = public, private, extensions
as $$
  select private.apply_data_use_policy(p_quote_case_id, p_policy_version);
$$;

revoke all on function public.apply_data_use_policy(uuid,text) from public, anon, authenticated;
grant execute on function public.apply_data_use_policy(uuid,text) to service_role;

create or replace function private.recalculate_quote_readiness(
  p_quote_case_id uuid
) returns integer
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_case public.quote_cases;
  v_binding public.provider_bindings;
  v_report_status public.external_report_status;
  v_issue_count integer;
begin
  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id;
  if v_case.quote_case_id is null then
    raise exception 'QUOTE_CASE_NOT_FOUND' using errcode = 'P0002';
  end if;

  update public.readiness_issues
  set resolution_state = 'SUPERSEDED', resolved_at = now()
  where quote_case_id = p_quote_case_id and resolution_state = 'OPEN' and carrier_program_id is null;

  if not exists (select 1 from public.drivers where quote_case_id = p_quote_case_id) then
    insert into public.readiness_issues (tenant_id, agency_id, quote_case_id, issue_type, severity, blocking, reason_code)
    values (v_case.tenant_id, v_case.agency_id, p_quote_case_id, 'MISSING_DATA', 'BLOCKING', true, 'MISSING_DRIVER');
  end if;

  if not exists (select 1 from public.vehicles where quote_case_id = p_quote_case_id) then
    insert into public.readiness_issues (tenant_id, agency_id, quote_case_id, issue_type, severity, blocking, reason_code)
    values (v_case.tenant_id, v_case.agency_id, p_quote_case_id, 'MISSING_DATA', 'BLOCKING', true, 'MISSING_VEHICLE');
  end if;

  if not exists (select 1 from public.coverage_requests where quote_case_id = p_quote_case_id) then
    insert into public.readiness_issues (tenant_id, agency_id, quote_case_id, issue_type, severity, blocking, reason_code)
    values (v_case.tenant_id, v_case.agency_id, p_quote_case_id, 'MISSING_DATA', 'BLOCKING', true, 'MISSING_COVERAGE_REQUEST');
  end if;

  for v_binding in
    select * from public.provider_bindings
    where tenant_id = v_case.tenant_id
      and agency_id = v_case.agency_id
      and jurisdiction = v_case.jurisdiction
      and product_line = v_case.product_line
      and status = 'ACTIVE'
      and required_for_readiness
  loop
    select er.status into v_report_status
    from public.external_reports er
    join public.external_requests eq on eq.external_request_id = er.external_request_id
    where er.quote_case_id = p_quote_case_id
      and eq.provider_binding_id = v_binding.provider_binding_id
    order by er.retrieved_at desc
    limit 1;

    if v_report_status is null then
      insert into public.readiness_issues (tenant_id, agency_id, quote_case_id, issue_type, severity, blocking, subject_ref, reason_code)
      values (v_case.tenant_id, v_case.agency_id, p_quote_case_id, 'MISSING_PROVIDER_RESULT', 'BLOCKING', true, v_binding.provider_binding_id::text, 'MISSING_' || v_binding.capability::text || '_RESULT');
    elsif v_report_status = 'STALE' then
      insert into public.readiness_issues (tenant_id, agency_id, quote_case_id, issue_type, severity, blocking, subject_ref, reason_code)
      values (v_case.tenant_id, v_case.agency_id, p_quote_case_id, 'STALE_PROVIDER_RESULT', 'BLOCKING', true, v_binding.provider_binding_id::text, 'STALE_' || v_binding.capability::text || '_RESULT');
    elsif v_report_status = 'ERROR' then
      insert into public.readiness_issues (tenant_id, agency_id, quote_case_id, issue_type, severity, blocking, subject_ref, reason_code)
      values (v_case.tenant_id, v_case.agency_id, p_quote_case_id, 'PROVIDER_ERROR', 'BLOCKING', true, v_binding.provider_binding_id::text, 'ERROR_' || v_binding.capability::text || '_RESULT');
    elsif v_report_status = 'PARTIAL' then
      insert into public.readiness_issues (tenant_id, agency_id, quote_case_id, issue_type, severity, blocking, subject_ref, reason_code)
      values (v_case.tenant_id, v_case.agency_id, p_quote_case_id, 'PARTIAL_PROVIDER_RESULT', 'WARNING', false, v_binding.provider_binding_id::text, 'PARTIAL_' || v_binding.capability::text || '_RESULT');
    end if;
  end loop;

  select count(*) into v_issue_count
  from public.readiness_issues
  where quote_case_id = p_quote_case_id and resolution_state = 'OPEN';

  return v_issue_count;
end;
$$;

create or replace function public.recalculate_quote_readiness(
  p_quote_case_id uuid
) returns integer
language sql
security definer
set search_path = public, private, extensions
as $$
  select private.recalculate_quote_readiness(p_quote_case_id);
$$;

revoke all on function public.recalculate_quote_readiness(uuid) from public, anon, authenticated;
grant execute on function public.recalculate_quote_readiness(uuid) to service_role;
