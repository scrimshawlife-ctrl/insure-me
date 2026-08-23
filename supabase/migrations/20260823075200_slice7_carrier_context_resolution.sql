-- Server-only carrier discovery/context resolution for verified workforce routes.

create or replace function public.list_carrier_programs_for_case(
  p_quote_case_id uuid,
  p_tenant_id uuid,
  p_agency_id uuid
) returns table(
  carrier_id uuid,
  carrier_program_id uuid,
  carrier_display_name text,
  program_code text,
  program_version integer,
  adapter_id text,
  adapter_version text,
  handoff_mode public.carrier_mode,
  certification_state public.carrier_certification_state,
  kill_switch_enabled boolean,
  rating_input_policy_version text,
  response_mapping_version text
)
language sql
security definer
set search_path=public,private,extensions
as $$
  select
    c.carrier_id,
    cp.carrier_program_id,
    c.display_name,
    cp.program_code,
    cp.version,
    cp.adapter_id,
    cp.adapter_version,
    cp.handoff_mode,
    cp.certification_state,
    cp.kill_switch_enabled,
    cp.rating_input_policy_version,
    cp.response_mapping_version
  from public.quote_cases qc
  join public.carrier_programs cp
    on cp.tenant_id=qc.tenant_id
   and cp.agency_id=qc.agency_id
   and qc.jurisdiction=any(cp.jurisdictions)
   and qc.product_line=any(cp.product_lines)
   and cp.retired_at is null
  join public.carriers c on c.carrier_id=cp.carrier_id and c.status='ACTIVE'
  where qc.quote_case_id=p_quote_case_id
    and qc.tenant_id=p_tenant_id
    and qc.agency_id=p_agency_id
  order by c.display_name,cp.program_code,cp.version desc;
$$;

revoke all on function public.list_carrier_programs_for_case(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.list_carrier_programs_for_case(uuid,uuid,uuid) to service_role;

create or replace function public.resolve_carrier_program_context(
  p_quote_case_id uuid,
  p_tenant_id uuid,
  p_agency_id uuid,
  p_carrier_program_id uuid
) returns table(
  tenant_configuration_version integer,
  jurisdiction text,
  product_line text,
  carrier_id uuid,
  carrier_program_id uuid,
  carrier_program_version integer,
  adapter_id text,
  adapter_version text,
  handoff_mode public.carrier_mode,
  certification_state public.carrier_certification_state,
  kill_switch_enabled boolean,
  rating_input_policy_version text,
  response_mapping_version text
)
language plpgsql
security definer
set search_path=public,private,extensions
as $$
declare
  v_case public.quote_cases;
  v_program public.carrier_programs;
begin
  select * into v_case
  from public.quote_cases qc
  where qc.quote_case_id=p_quote_case_id
    and qc.tenant_id=p_tenant_id
    and qc.agency_id=p_agency_id;
  if v_case.quote_case_id is null then
    raise exception 'QUOTE_CASE_NOT_FOUND' using errcode='P0002';
  end if;

  if v_case.state not in ('REVIEW_REQUIRED','READY_FOR_CARRIER','SUBMITTED_TO_CARRIER') then
    raise exception 'CARRIER_INVALID_CASE_STATE' using errcode='42501';
  end if;

  select * into v_program
  from public.carrier_programs cp
  where cp.carrier_program_id=p_carrier_program_id
    and cp.tenant_id=p_tenant_id
    and cp.agency_id=p_agency_id
    and v_case.jurisdiction=any(cp.jurisdictions)
    and v_case.product_line=any(cp.product_lines)
    and cp.retired_at is null;
  if v_program.carrier_program_id is null then
    raise exception 'CARRIER_PROGRAM_NOT_CONFIGURED' using errcode='42501';
  end if;

  return query select
    v_case.tenant_configuration_version,
    v_case.jurisdiction,
    v_case.product_line,
    v_program.carrier_id,
    v_program.carrier_program_id,
    v_program.version,
    v_program.adapter_id,
    v_program.adapter_version,
    v_program.handoff_mode,
    v_program.certification_state,
    v_program.kill_switch_enabled,
    v_program.rating_input_policy_version,
    v_program.response_mapping_version;
end;
$$;

revoke all on function public.resolve_carrier_program_context(uuid,uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.resolve_carrier_program_context(uuid,uuid,uuid,uuid) to service_role;
