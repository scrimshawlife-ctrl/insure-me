-- Server-only provider context resolution. Tenant/agency values originate from a verified workforce session.

create or replace function public.resolve_provider_request_context(
  p_quote_case_id uuid,
  p_tenant_id uuid,
  p_agency_id uuid,
  p_capability public.provider_capability
) returns table(
  tenant_configuration_version integer,
  jurisdiction text,
  product_line text,
  provider_binding_id uuid,
  adapter_id text,
  adapter_version text,
  purpose_code text,
  requires_report_authorization boolean,
  consent_record_ids uuid[]
)
language plpgsql
security definer
set search_path=public,private,extensions
as $$
declare
  v_case public.quote_cases;
  v_binding public.provider_bindings;
begin
  select * into v_case
  from public.quote_cases qc
  where qc.quote_case_id=p_quote_case_id
    and qc.tenant_id=p_tenant_id
    and qc.agency_id=p_agency_id;

  if v_case.quote_case_id is null then
    raise exception 'QUOTE_CASE_NOT_FOUND' using errcode='P0002';
  end if;

  if v_case.state not in ('DATA_ENRICHMENT','REVIEW_REQUIRED','READY_FOR_CARRIER') then
    raise exception 'PROVIDER_REQUEST_INVALID_CASE_STATE' using errcode='42501';
  end if;

  select * into v_binding
  from public.provider_bindings pb
  where pb.tenant_id=p_tenant_id
    and pb.agency_id=p_agency_id
    and pb.capability=p_capability
    and pb.jurisdiction=v_case.jurisdiction
    and pb.product_line=v_case.product_line
    and pb.status='ACTIVE'
  order by pb.created_at desc
  limit 1;

  if v_binding.provider_binding_id is null then
    raise exception 'PROVIDER_BINDING_NOT_ACTIVE' using errcode='42501';
  end if;

  return query
  select
    v_case.tenant_configuration_version,
    v_case.jurisdiction,
    v_case.product_line,
    v_binding.provider_binding_id,
    v_binding.adapter_id,
    v_binding.adapter_version,
    v_binding.purpose_code,
    v_binding.requires_report_authorization,
    coalesce(array_agg(cr.consent_record_id) filter (where cr.consent_record_id is not null),'{}'::uuid[])
  from public.consent_records cr
  join public.notice_definitions nd on nd.notice_definition_id=cr.notice_definition_id
  where cr.quote_case_id=p_quote_case_id
    and cr.tenant_id=p_tenant_id
    and cr.agency_id=p_agency_id
    and (
      (nd.category='REPORT_AUTHORIZATION' and cr.action_type='AUTHORIZE')
      or (nd.category='CONSUMER_REPORT_DISCLOSURE' and cr.action_type='ACKNOWLEDGE')
    );
end;
$$;

revoke all on function public.resolve_provider_request_context(uuid,uuid,uuid,public.provider_capability) from public,anon,authenticated;
grant execute on function public.resolve_provider_request_context(uuid,uuid,uuid,public.provider_capability) to service_role;

create or replace function public.get_provider_consent_categories(
  p_quote_case_id uuid,
  p_tenant_id uuid,
  p_agency_id uuid,
  p_consent_record_ids uuid[]
) returns table(consent_record_id uuid,category public.notice_category,action_type public.consent_action)
language sql
security definer
set search_path=public,private,extensions
as $$
  select cr.consent_record_id,nd.category,cr.action_type
  from public.consent_records cr
  join public.notice_definitions nd on nd.notice_definition_id=cr.notice_definition_id
  where cr.quote_case_id=p_quote_case_id
    and cr.tenant_id=p_tenant_id
    and cr.agency_id=p_agency_id
    and cr.consent_record_id=any(coalesce(p_consent_record_ids,'{}'::uuid[]));
$$;

revoke all on function public.get_provider_consent_categories(uuid,uuid,uuid,uuid[]) from public,anon,authenticated;
grant execute on function public.get_provider_consent_categories(uuid,uuid,uuid,uuid[]) to service_role;
