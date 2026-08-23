-- Slice 6/7 boundary: carrier-neutral program registry and explicit RatingInput projection.

create type public.carrier_mode as enum ('STUB','API','DEEPLINK','AMS_BRIDGE','STRUCTURED_EXPORT','MANUAL');
create type public.carrier_certification_state as enum ('SYNTHETIC','SANDBOX','CERTIFIED','SUSPENDED','RETIRED');
create type public.carrier_submission_status as enum ('PENDING','RUNNING','SUCCEEDED','FAILED','BLOCKED');

create table public.carriers (
  carrier_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  legal_name text not null,
  display_name text not null,
  status public.record_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  unique (tenant_id, carrier_id)
);

create table public.carrier_programs (
  carrier_program_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  carrier_id uuid not null references public.carriers(carrier_id),
  program_code text not null,
  version integer not null,
  jurisdictions text[] not null,
  product_lines text[] not null,
  adapter_id text not null,
  adapter_version text not null,
  handoff_mode public.carrier_mode not null,
  required_field_policy_version text not null,
  rating_input_policy_version text not null,
  response_mapping_version text not null,
  notice_ownership_policy_version text not null,
  certification_state public.carrier_certification_state not null default 'SYNTHETIC',
  kill_switch_enabled boolean not null default false,
  effective_at timestamptz not null default now(),
  retired_at timestamptz,
  created_at timestamptz not null default now(),
  unique (tenant_id, carrier_program_id),
  unique (tenant_id, carrier_id, program_code, version)
);

alter table public.quote_cases
  add constraint quote_cases_selected_carrier_program_fk
  foreign key (selected_carrier_program_id) references public.carrier_programs(carrier_program_id);

create table public.carrier_program_rating_rules (
  carrier_program_rating_rule_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  carrier_program_id uuid not null references public.carrier_programs(carrier_program_id) on delete cascade,
  carrier_program_version integer not null,
  mapping_version text not null,
  source_observation_type text not null,
  input_key text not null,
  required boolean not null default true,
  created_at timestamptz not null default now(),
  unique (carrier_program_id, carrier_program_version, mapping_version, input_key)
);

create table public.rating_inputs (
  rating_input_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  quote_case_id uuid not null references public.quote_cases(quote_case_id) on delete cascade,
  carrier_program_id uuid not null references public.carrier_programs(carrier_program_id),
  carrier_program_version integer not null,
  source_observation_or_field_refs uuid[] not null,
  input_key text not null,
  approved_value jsonb not null,
  data_use_policy_version text not null,
  mapping_version text not null,
  created_at timestamptz not null default now(),
  unique (quote_case_id, carrier_program_id, carrier_program_version, input_key, source_observation_or_field_refs)
);

create table public.carrier_submissions (
  carrier_submission_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  quote_case_id uuid not null references public.quote_cases(quote_case_id) on delete cascade,
  tenant_configuration_version integer not null,
  carrier_id uuid not null references public.carriers(carrier_id),
  carrier_program_id uuid not null references public.carrier_programs(carrier_program_id),
  carrier_program_version integer not null,
  adapter_id text not null,
  handoff_mode public.carrier_mode not null,
  mapping_version text not null,
  rating_input_ids uuid[] not null,
  idempotency_key text not null,
  request_hash text not null,
  status public.carrier_submission_status not null default 'PENDING',
  external_reference text,
  submitted_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (tenant_id, carrier_program_id, idempotency_key)
);

create table public.carrier_decisions (
  carrier_decision_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  carrier_submission_id uuid not null references public.carrier_submissions(carrier_submission_id) on delete cascade,
  carrier_program_id uuid not null references public.carrier_programs(carrier_program_id),
  decision_status text not null,
  premium jsonb,
  reason_codes text[] not null default '{}',
  external_reference text,
  response_mapping_version text not null,
  received_at timestamptz not null,
  created_at timestamptz not null default now()
);

alter table public.carriers enable row level security;
alter table public.carrier_programs enable row level security;
alter table public.carrier_program_rating_rules enable row level security;
alter table public.rating_inputs enable row level security;
alter table public.carrier_submissions enable row level security;
alter table public.carrier_decisions enable row level security;

create policy carriers_workforce_select on public.carriers
for select to authenticated using (private.has_tenant_membership(tenant_id));
create policy carrier_programs_workforce_select on public.carrier_programs
for select to authenticated using (private.has_tenant_membership(tenant_id));
create policy carrier_rating_rules_workforce_select on public.carrier_program_rating_rules
for select to authenticated using (private.has_tenant_membership(tenant_id));
create policy rating_inputs_workforce_select on public.rating_inputs
for select to authenticated using (private.has_tenant_membership(tenant_id));
create policy carrier_submissions_workforce_select on public.carrier_submissions
for select to authenticated using (private.has_tenant_membership(tenant_id));
create policy carrier_decisions_workforce_select on public.carrier_decisions
for select to authenticated using (private.has_tenant_membership(tenant_id));

revoke insert, update, delete on public.carriers, public.carrier_programs,
  public.carrier_program_rating_rules, public.rating_inputs,
  public.carrier_submissions, public.carrier_decisions from anon, authenticated;

create or replace function private.project_rating_inputs(
  p_quote_case_id uuid,
  p_carrier_program_id uuid
) returns integer
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_case public.quote_cases;
  v_program public.carrier_programs;
  v_rule public.carrier_program_rating_rules;
  v_observation public.underwriting_observations;
  v_inserted integer := 0;
begin
  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id;
  if v_case.quote_case_id is null then
    raise exception 'QUOTE_CASE_NOT_FOUND' using errcode = 'P0002';
  end if;

  select * into v_program from public.carrier_programs
  where carrier_program_id = p_carrier_program_id
    and tenant_id = v_case.tenant_id
    and agency_id = v_case.agency_id
    and v_case.jurisdiction = any(jurisdictions)
    and v_case.product_line = any(product_lines)
    and retired_at is null;

  if v_program.carrier_program_id is null then
    raise exception 'CARRIER_PROGRAM_NOT_CONFIGURED' using errcode = '42501';
  end if;
  if v_program.kill_switch_enabled then
    raise exception 'CARRIER_KILL_SWITCHED' using errcode = '42501';
  end if;
  if v_program.certification_state not in ('SYNTHETIC','SANDBOX','CERTIFIED') then
    raise exception 'CARRIER_NOT_CERTIFIED' using errcode = '42501';
  end if;

  for v_rule in
    select * from public.carrier_program_rating_rules
    where carrier_program_id = p_carrier_program_id
      and carrier_program_version = v_program.version
      and mapping_version = v_program.rating_input_policy_version
  loop
    select * into v_observation
    from public.underwriting_observations
    where quote_case_id = p_quote_case_id
      and observation_type = v_rule.source_observation_type
      and data_use_classification = 'RATING_SUBMISSION_ALLOWED'
      and freshness_state = 'CURRENT'
      and conflict_state = 'NONE'
    order by created_at desc
    limit 1;

    if v_observation.observation_id is not null then
      insert into public.rating_inputs (
        tenant_id, agency_id, quote_case_id, carrier_program_id,
        carrier_program_version, source_observation_or_field_refs,
        input_key, approved_value, data_use_policy_version,
        mapping_version
      ) values (
        v_case.tenant_id, v_case.agency_id, p_quote_case_id,
        v_program.carrier_program_id, v_program.version,
        array[v_observation.observation_id], v_rule.input_key,
        v_observation.normalized_value,
        coalesce(v_observation.data_use_policy_version, 'UNVERSIONED'),
        v_rule.mapping_version
      ) on conflict do nothing;
      if found then v_inserted := v_inserted + 1; end if;
    end if;
  end loop;

  return v_inserted;
end;
$$;

create or replace function public.project_rating_inputs(
  p_quote_case_id uuid,
  p_carrier_program_id uuid
) returns integer
language sql
security definer
set search_path = public, private, extensions
as $$
  select private.project_rating_inputs(p_quote_case_id, p_carrier_program_id);
$$;

revoke all on function public.project_rating_inputs(uuid,uuid) from public, anon, authenticated;
grant execute on function public.project_rating_inputs(uuid,uuid) to service_role;
