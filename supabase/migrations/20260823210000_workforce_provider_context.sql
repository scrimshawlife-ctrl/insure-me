-- Agent-safe provider/report/observation projection.
-- Raw normalized snapshots and non-displayable observations never leave SQL.

create or replace function private.get_workforce_case_provider_context_impl(p_quote_case_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private
as $$
declare
  v_case public.quote_cases;
  v_can_refresh boolean;
begin
  select * into v_case
  from public.quote_cases
  where quote_case_id = p_quote_case_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'QUOTE_CASE_NOT_FOUND';
  end if;

  if not private.has_permission(v_case.tenant_id, v_case.agency_id, 'CASE_READ') then
    raise exception using errcode = '42501', message = 'CASE_READ_NOT_PERMITTED';
  end if;

  v_can_refresh := private.has_permission(v_case.tenant_id, v_case.agency_id, 'REPORT_RETRIEVE');

  return jsonb_build_object(
    'canRefreshProviders', v_can_refresh,
    'reports', coalesce((
      select jsonb_agg(jsonb_build_object(
        'providerBindingId', b.provider_binding_id,
        'capability', b.capability,
        'adapterId', b.adapter_id,
        'adapterVersion', b.adapter_version,
        'requiredForReadiness', b.required_for_readiness,
        'externalRequestId', req.external_request_id,
        'requestStatus', req.status,
        'requestedAt', req.requested_at,
        'completedAt', req.completed_at,
        'subjectIds', coalesce(req.subject_ids, '{}'::uuid[]),
        'externalReportId', rep.external_report_id,
        'reportStatus', rep.status,
        'retrievedAt', rep.retrieved_at,
        'freshUntil', rep.fresh_until,
        'warnings', coalesce(rep.warnings, '{}'::text[]),
        'canRefresh', (
          v_can_refresh
          and req.external_request_id is not null
          and cardinality(coalesce(req.subject_ids, '{}'::uuid[])) > 0
        )
      ) order by b.capability, b.provider_binding_id)
      from public.provider_bindings b
      left join lateral (
        select r.*
        from public.external_requests r
        where r.quote_case_id = p_quote_case_id
          and r.provider_binding_id = b.provider_binding_id
        order by r.requested_at desc, r.external_request_id desc
        limit 1
      ) req on true
      left join lateral (
        select er.*
        from public.external_reports er
        where er.external_request_id = req.external_request_id
        order by er.retrieved_at desc, er.external_report_id desc
        limit 1
      ) rep on true
      where b.tenant_id = v_case.tenant_id
        and b.agency_id = v_case.agency_id
        and b.jurisdiction = v_case.jurisdiction
        and b.product_line = v_case.product_line
        and b.status = 'ACTIVE'
    ), '[]'::jsonb),
    'observations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'observationId', o.observation_id,
        'observationType', o.observation_type,
        'subjectId', o.subject_id,
        'normalizedValue', o.normalized_value,
        'dataUseClassification', o.data_use_classification,
        'dataUsePolicyVersion', o.data_use_policy_version,
        'freshnessState', o.freshness_state,
        'conflictState', o.conflict_state,
        'createdAt', o.created_at,
        'provenance', coalesce((
          select jsonb_agg(jsonb_build_object(
            'provenanceEntryId', p.provenance_entry_id,
            'externalReportId', p.external_report_id,
            'sourceType', p.source_type,
            'sourceId', p.source_id,
            'factKey', p.fact_key,
            'sourcePath', p.source_path,
            'sourceTimestamp', p.source_timestamp,
            'transformationVersion', p.transformation_version,
            'confidenceState', p.confidence_state,
            'confirmationState', p.confirmation_state
          ) order by p.created_at, p.provenance_entry_id)
          from public.provenance_entries p
          where p.quote_case_id = p_quote_case_id
            and p.provenance_entry_id = any(o.provenance_entry_ids)
        ), '[]'::jsonb)
      ) order by o.created_at, o.observation_id)
      from public.underwriting_observations o
      join public.data_use_policy_rules rule
        on rule.tenant_id = o.tenant_id
       and rule.policy_version = o.data_use_policy_version
       and rule.observation_type = o.observation_type
       and rule.agent_display_allowed
       and not rule.prohibited
       and rule.retired_at is null
      where o.quote_case_id = p_quote_case_id
    ), '[]'::jsonb)
  );
end
$$;

revoke all on function private.get_workforce_case_provider_context_impl(uuid) from public;
grant execute on function private.get_workforce_case_provider_context_impl(uuid) to authenticated;

create or replace function public.get_workforce_case_provider_context(p_quote_case_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = public, private
as $$
  select private.get_workforce_case_provider_context_impl(p_quote_case_id)
$$;

revoke all on function public.get_workforce_case_provider_context(uuid) from public, anon;
grant execute on function public.get_workforce_case_provider_context(uuid) to authenticated;
