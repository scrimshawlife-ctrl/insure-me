-- T809: immutable, case-scoped compliance evidence export.
-- The manifest contains provenance and integrity metadata, never raw identity,
-- normalized report payloads, notice bodies, premiums, or audit metadata.

create table public.compliance_evidence_exports (
  compliance_evidence_export_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  quote_case_id uuid not null references public.quote_cases(quote_case_id),
  schema_version text not null check (schema_version = 'compliance-evidence-bundle-v1'),
  as_of timestamptz not null,
  purpose_ref text not null check (char_length(trim(purpose_ref)) between 3 and 500),
  reason_codes text[] not null check (cardinality(reason_codes) > 0),
  manifest jsonb not null check (jsonb_typeof(manifest) = 'object'),
  manifest_hash text not null check (manifest_hash ~ '^[0-9a-f]{64}$'),
  evidence_record_count integer not null check (evidence_record_count between 0 and 10000),
  idempotency_key uuid not null,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null,
  created_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  unique (tenant_id, agency_id, idempotency_key)
);

create index compliance_evidence_exports_case_idx
  on public.compliance_evidence_exports
    (tenant_id, agency_id, quote_case_id, created_at desc);

alter table public.compliance_evidence_exports enable row level security;
revoke all on public.compliance_evidence_exports from anon, authenticated;

create or replace function private.prevent_compliance_evidence_export_mutation()
returns trigger language plpgsql security definer set search_path = public, private as $$
begin
  raise exception using errcode = '22023', message = 'COMPLIANCE_EVIDENCE_EXPORT_IMMUTABLE';
end
$$;
revoke all on function private.prevent_compliance_evidence_export_mutation() from public;
create trigger compliance_evidence_export_immutable
before update or delete on public.compliance_evidence_exports
for each row execute function private.prevent_compliance_evidence_export_mutation();

create or replace function private.create_compliance_evidence_export_impl(
  p_quote_case_id uuid,
  p_as_of timestamptz,
  p_purpose_ref text,
  p_reason_codes text[],
  p_idempotency_key uuid
)
returns public.compliance_evidence_exports
language plpgsql security definer
set search_path = public, private, extensions as $$
declare
  v_actor uuid := auth.uid();
  v_case public.quote_cases;
  v_existing public.compliance_evidence_exports;
  v_export public.compliance_evidence_exports;
  v_manifest jsonb;
  v_manifest_hash text;
  v_evidence_count integer;
  v_request_hash text;
  v_audit_hash text;
begin
  if v_actor is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id;
  if not found
    or not private.has_permission(v_case.tenant_id, v_case.agency_id, 'AUDIT_READ')
    or not private.has_permission(v_case.tenant_id, v_case.agency_id, 'EXPORT_DATA') then
    raise exception using errcode = 'P0002', message = 'COMPLIANCE_EXPORT_SCOPE_NOT_FOUND';
  end if;
  if p_as_of is null or p_as_of > now() or p_as_of < v_case.created_at
    or char_length(trim(p_purpose_ref)) not between 3 and 500
    or coalesce(cardinality(p_reason_codes), 0) = 0 then
    raise exception using errcode = '22023', message = 'COMPLIANCE_EXPORT_INPUT_INVALID';
  end if;
  v_request_hash := encode(extensions.digest(jsonb_build_array(
    'CREATE_COMPLIANCE_EVIDENCE_EXPORT', p_quote_case_id, p_as_of,
    trim(p_purpose_ref), to_jsonb(p_reason_codes)
  )::text, 'sha256'), 'hex');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    concat_ws('|', v_case.tenant_id::text, v_case.agency_id::text,
      p_idempotency_key::text), 0));
  select * into v_existing from public.compliance_evidence_exports
    where tenant_id = v_case.tenant_id and agency_id = v_case.agency_id
      and idempotency_key = p_idempotency_key;
  if found then
    if v_existing.request_hash <> v_request_hash
      or v_existing.quote_case_id <> p_quote_case_id
      or v_existing.as_of <> p_as_of
      or v_existing.purpose_ref <> trim(p_purpose_ref)
      or v_existing.reason_codes <> p_reason_codes then
      raise exception using errcode = '22023', message = 'COMPLIANCE_EXPORT_IDEMPOTENCY_MISMATCH';
    end if;
    return v_existing;
  end if;

  select jsonb_build_object(
    'schemaVersion', 'compliance-evidence-bundle-v1',
    'asOf', p_as_of,
    'scope', jsonb_build_object('type', 'QUOTE_CASE', 'quoteCaseId', v_case.quote_case_id),
    'caseContext', jsonb_build_object(
      'tenantConfigurationId', v_case.tenant_configuration_id,
      'tenantConfigurationVersion', v_case.tenant_configuration_version,
      'jurisdiction', v_case.jurisdiction,
      'productLine', v_case.product_line,
      'createdAt', v_case.created_at
    ),
    'noticeAndConsentEvidence', coalesce((select jsonb_agg(jsonb_build_object(
      'consentRecordId', c.consent_record_id, 'noticeDefinitionId', c.notice_definition_id,
      'noticeVersion', c.notice_version, 'noticeContentHash', c.notice_content_hash,
      'actionType', c.action_type, 'presentedAt', c.presented_at,
      'actedAt', c.acted_at, 'channel', c.channel, 'evidenceRef', c.evidence_ref
    ) order by c.acted_at, c.consent_record_id) from public.consent_records c
      where c.tenant_id = v_case.tenant_id and c.quote_case_id = v_case.quote_case_id
        and c.created_at <= p_as_of), '[]'::jsonb),
    'purposeEvidence', coalesce((select jsonb_agg(jsonb_build_object(
      'decisionId', p.decision_id, 'configurationVersion', p.tenant_configuration_version,
      'capability', p.capability, 'purposeCode', p.purpose_code,
      'outcome', p.outcome, 'reasonCodes', p.reason_codes,
      'policyVersion', p.policy_version, 'evaluatedAt', p.evaluated_at
    ) order by p.evaluated_at, p.decision_id) from public.permissible_purpose_decisions p
      where p.tenant_id = v_case.tenant_id and p.quote_case_id = v_case.quote_case_id
        and p.evaluated_at <= p_as_of), '[]'::jsonb),
    'providerRequests', coalesce((select jsonb_agg(jsonb_build_object(
      'externalRequestId', r.external_request_id, 'providerBindingId', r.provider_binding_id,
      'configurationVersion', r.tenant_configuration_version, 'capability', r.capability,
      'permissiblePurposeDecisionId', r.permissible_purpose_decision_id,
      'consentRecordIds', r.consent_record_ids, 'requestHash', r.request_hash,
      'requestedAt', r.requested_at
    ) order by r.requested_at, r.external_request_id) from public.external_requests r
      where r.tenant_id = v_case.tenant_id and r.quote_case_id = v_case.quote_case_id
        and r.requested_at <= p_as_of), '[]'::jsonb),
    'providerBindings', coalesce((select jsonb_agg(jsonb_build_object(
      'providerBindingId', b.provider_binding_id, 'capability', b.capability,
      'adapterId', b.adapter_id, 'adapterVersion', b.adapter_version,
      'jurisdiction', b.jurisdiction, 'productLine', b.product_line,
      'requiresReportAuthorization', b.requires_report_authorization,
      'purposeCode', b.purpose_code,
      'rawPayloadStorageAllowed', b.raw_payload_storage_allowed,
      'createdAt', b.created_at
    ) order by b.provider_binding_id) from public.provider_bindings b
      where b.provider_binding_id in (select r.provider_binding_id
        from public.external_requests r where r.tenant_id = v_case.tenant_id
          and r.quote_case_id = v_case.quote_case_id
          and r.requested_at <= p_as_of)), '[]'::jsonb),
    'providerReports', coalesce((select jsonb_agg(jsonb_build_object(
      'externalReportId', r.external_report_id, 'externalRequestId', r.external_request_id,
      'providerId', r.provider_id, 'providerProductId', r.provider_product_id,
      'providerReportRef', r.provider_report_ref, 'status', r.status,
      'retrievedAt', r.retrieved_at, 'freshUntil', r.fresh_until,
      'normalizedVersion', r.normalized_version, 'warnings', r.warnings
    ) order by r.retrieved_at, r.external_report_id) from public.external_reports r
      where r.tenant_id = v_case.tenant_id and r.quote_case_id = v_case.quote_case_id
        and r.created_at <= p_as_of), '[]'::jsonb),
    'readinessEvidence', coalesce((select jsonb_agg(jsonb_build_object(
      'readinessIssueId', r.readiness_issue_id, 'carrierProgramId', r.carrier_program_id,
      'issueType', r.issue_type, 'severity', r.severity, 'blocking', r.blocking,
      'subjectRef', r.subject_ref, 'reasonCode', r.reason_code, 'createdAt', r.created_at
    ) order by r.created_at, r.readiness_issue_id) from public.readiness_issues r
      where r.tenant_id = v_case.tenant_id and r.quote_case_id = v_case.quote_case_id
        and r.created_at <= p_as_of), '[]'::jsonb),
    'carrierSubmissions', coalesce((select jsonb_agg(jsonb_build_object(
      'carrierSubmissionId', s.carrier_submission_id, 'carrierId', s.carrier_id,
      'carrierProgramId', s.carrier_program_id, 'carrierProgramVersion', s.carrier_program_version,
      'configurationVersion', s.tenant_configuration_version, 'adapterId', s.adapter_id,
      'handoffMode', s.handoff_mode, 'mappingVersion', s.mapping_version,
      'ratingInputIds', s.rating_input_ids, 'requestHash', s.request_hash,
      'submittedAt', s.submitted_at
    ) order by s.submitted_at, s.carrier_submission_id) from public.carrier_submissions s
      where s.tenant_id = v_case.tenant_id and s.quote_case_id = v_case.quote_case_id
        and s.submitted_at <= p_as_of), '[]'::jsonb),
    'carrierDecisions', coalesce((select jsonb_agg(jsonb_build_object(
      'carrierDecisionId', d.carrier_decision_id, 'carrierSubmissionId', d.carrier_submission_id,
      'carrierProgramId', d.carrier_program_id, 'decisionStatus', d.decision_status,
      'reasonCodes', d.reason_codes, 'externalReference', d.external_reference,
      'responseMappingVersion', d.response_mapping_version, 'receivedAt', d.received_at
    ) order by d.received_at, d.carrier_decision_id) from public.carrier_decisions d
      join public.carrier_submissions s on s.carrier_submission_id = d.carrier_submission_id
      where s.tenant_id = v_case.tenant_id and s.quote_case_id = v_case.quote_case_id
        and d.created_at <= p_as_of), '[]'::jsonb),
    'adverseActionCases', coalesce((select jsonb_agg(jsonb_build_object(
      'adverseActionCaseId', a.adverse_action_case_id, 'carrierDecisionId', a.carrier_decision_id,
      'carrierProgramId', a.carrier_program_id, 'ownerType', a.owner_type,
      'ownerRef', a.owner_ref, 'ownershipPolicyVersion', a.ownership_policy_version,
      'determinationAuthorityRef', a.determination_authority_ref,
      'determinationEvidenceRef', a.determination_evidence_ref,
      'determinationReasonCodes', a.determination_reason_codes,
      'requestHash', a.request_hash, 'determinedAt', a.determined_at
    ) order by a.determined_at, a.adverse_action_case_id) from public.adverse_action_cases a
      where a.tenant_id = v_case.tenant_id and a.quote_case_id = v_case.quote_case_id
        and a.determined_at <= p_as_of), '[]'::jsonb),
    'adverseActionReportSources', coalesce((select jsonb_agg(jsonb_build_object(
      'reportSourceId', s.adverse_action_report_source_id,
      'adverseActionCaseId', s.adverse_action_case_id,
      'externalReportId', s.external_report_id, 'externalRequestId', s.external_request_id,
      'providerBindingId', s.provider_binding_id, 'craIdentityRef', s.cra_identity_ref,
      'disputeRouteRef', s.dispute_route_ref,
      'contributionBasisCode', s.contribution_basis_code, 'createdAt', s.created_at
    ) order by s.created_at, s.adverse_action_report_source_id)
      from public.adverse_action_report_sources s join public.adverse_action_cases a
        on a.adverse_action_case_id = s.adverse_action_case_id
      where a.tenant_id = v_case.tenant_id and a.quote_case_id = v_case.quote_case_id
        and s.created_at <= p_as_of), '[]'::jsonb),
    'adverseActionEvents', coalesce((select jsonb_agg(jsonb_build_object(
      'adverseActionEventId', e.adverse_action_event_id,
      'adverseActionCaseId', e.adverse_action_case_id, 'eventType', e.event_type,
      'actorId', e.actor_id, 'evidenceRef', e.evidence_ref,
      'reasonCodes', e.reason_codes, 'requestHash', e.request_hash,
      'occurredAt', e.occurred_at
    ) order by e.occurred_at, e.adverse_action_event_id)
      from public.adverse_action_events e join public.adverse_action_cases a
        on a.adverse_action_case_id = e.adverse_action_case_id
      where a.tenant_id = v_case.tenant_id and a.quote_case_id = v_case.quote_case_id
        and e.occurred_at <= p_as_of), '[]'::jsonb),
    'noticeDeliveries', coalesce((select jsonb_agg(jsonb_build_object(
      'noticeDeliveryId', d.adverse_action_notice_delivery_id,
      'adverseActionCaseId', d.adverse_action_case_id,
      'noticeDefinitionId', d.notice_definition_id, 'noticeVersion', d.notice_version,
      'noticeContentHash', d.notice_content_hash, 'channel', d.channel,
      'recipientRef', d.recipient_ref, 'adapterId', d.adapter_id,
      'adapterVersion', d.adapter_version, 'deliveryPolicyVersion', d.delivery_policy_version,
      'certificationState', d.certification_state,
      'requestHash', d.request_hash, 'preparedAt', d.prepared_at
    ) order by d.prepared_at, d.adverse_action_notice_delivery_id)
      from public.adverse_action_notice_deliveries d
      where d.tenant_id = v_case.tenant_id and d.quote_case_id = v_case.quote_case_id
        and d.prepared_at <= p_as_of), '[]'::jsonb),
    'noticeDeliveryAttempts', coalesce((select jsonb_agg(jsonb_build_object(
      'noticeDeliveryAttemptId', a.adverse_action_notice_delivery_attempt_id,
      'noticeDeliveryId', a.adverse_action_notice_delivery_id, 'outcome', a.outcome,
      'adapterId', a.adapter_id, 'adapterVersion', a.adapter_version,
      'deliveryPolicyVersion', a.delivery_policy_version, 'evidenceRef', a.evidence_ref,
      'reasonCodes', a.reason_codes, 'requestHash', a.request_hash,
      'attemptedAt', a.attempted_at
    ) order by a.attempted_at, a.adverse_action_notice_delivery_attempt_id)
      from public.adverse_action_notice_delivery_attempts a
      join public.adverse_action_notice_deliveries d
        on d.adverse_action_notice_delivery_id = a.adverse_action_notice_delivery_id
      where d.tenant_id = v_case.tenant_id and d.quote_case_id = v_case.quote_case_id
        and a.attempted_at <= p_as_of), '[]'::jsonb),
    'legalHolds', coalesce((select jsonb_agg(jsonb_build_object(
      'legalHoldId', h.legal_hold_id,
      'authorityRef', h.authority_ref, 'evidenceRef', h.evidence_ref,
      'reasonCodes', h.reason_codes, 'placedAt', h.placed_at
    ) order by h.placed_at, h.legal_hold_id) from public.legal_holds h
      where h.tenant_id = v_case.tenant_id and h.agency_id = v_case.agency_id
        and h.scope_type = 'QUOTE_CASE' and h.scope_ref = v_case.quote_case_id
        and h.placed_at <= p_as_of), '[]'::jsonb),
    'legalHoldEvents', coalesce((select jsonb_agg(jsonb_build_object(
      'legalHoldEventId', e.legal_hold_event_id, 'legalHoldId', e.legal_hold_id,
      'eventType', e.event_type, 'actorId', e.actor_id,
      'authorityRef', e.authority_ref, 'evidenceRef', e.evidence_ref,
      'reasonCodes', e.reason_codes, 'requestHash', e.request_hash,
      'occurredAt', e.occurred_at
    ) order by e.occurred_at, e.legal_hold_event_id)
      from public.legal_hold_events e join public.legal_holds h
        on h.legal_hold_id = e.legal_hold_id
      where h.tenant_id = v_case.tenant_id and h.agency_id = v_case.agency_id
        and h.scope_type = 'QUOTE_CASE' and h.scope_ref = v_case.quote_case_id
        and e.occurred_at <= p_as_of), '[]'::jsonb),
    'auditTimeline', coalesce((select jsonb_agg(jsonb_build_object(
      'auditEventId', a.audit_event_id, 'eventType', a.event_type,
      'actorId', a.actor_id, 'subjectRef', a.subject_ref,
      'configurationVersionRef', a.configuration_version_ref,
      'policyVersionRefs', a.policy_version_refs, 'outcome', a.outcome,
      'reasonCodes', a.reason_codes, 'occurredAt', a.occurred_at,
      'integrityHash', a.integrity_hash
    ) order by a.occurred_at, a.audit_event_id) from public.audit_events a
      where a.tenant_id = v_case.tenant_id and a.agency_id = v_case.agency_id
        and a.quote_case_id = v_case.quote_case_id and a.occurred_at <= p_as_of), '[]'::jsonb)
  ) into v_manifest;

  v_evidence_count :=
      jsonb_array_length(v_manifest->'noticeAndConsentEvidence')
    + jsonb_array_length(v_manifest->'purposeEvidence')
    + jsonb_array_length(v_manifest->'providerBindings')
    + jsonb_array_length(v_manifest->'providerRequests')
    + jsonb_array_length(v_manifest->'providerReports')
    + jsonb_array_length(v_manifest->'readinessEvidence')
    + jsonb_array_length(v_manifest->'carrierSubmissions')
    + jsonb_array_length(v_manifest->'carrierDecisions')
    + jsonb_array_length(v_manifest->'adverseActionCases')
    + jsonb_array_length(v_manifest->'adverseActionReportSources')
    + jsonb_array_length(v_manifest->'adverseActionEvents')
    + jsonb_array_length(v_manifest->'noticeDeliveries')
    + jsonb_array_length(v_manifest->'noticeDeliveryAttempts')
    + jsonb_array_length(v_manifest->'legalHolds')
    + jsonb_array_length(v_manifest->'legalHoldEvents')
    + jsonb_array_length(v_manifest->'auditTimeline');
  if v_evidence_count > 10000 then
    raise exception using errcode = '54000', message = 'COMPLIANCE_EXPORT_SCOPE_TOO_LARGE';
  end if;

  v_manifest_hash := encode(extensions.digest(v_manifest::text, 'sha256'), 'hex');
  insert into public.compliance_evidence_exports (
    tenant_id, agency_id, quote_case_id, schema_version, as_of,
    purpose_ref, reason_codes, manifest, manifest_hash, evidence_record_count,
    idempotency_key, request_hash, created_by
  ) values (
    v_case.tenant_id, v_case.agency_id, v_case.quote_case_id,
    'compliance-evidence-bundle-v1', p_as_of, trim(p_purpose_ref), p_reason_codes,
    v_manifest, v_manifest_hash, v_evidence_count, p_idempotency_key,
    v_request_hash, v_actor
  ) returning * into v_export;
  v_audit_hash := encode(extensions.digest(concat_ws('|',
    v_export.compliance_evidence_export_id::text, v_export.manifest_hash,
    v_export.as_of::text, v_export.request_hash), 'sha256'), 'hex');
  insert into public.audit_events (tenant_id, agency_id, quote_case_id, event_type,
    actor_id, subject_ref, configuration_version_ref, outcome, reason_codes,
    integrity_hash, metadata)
  values (v_case.tenant_id, v_case.agency_id, v_case.quote_case_id,
    'COMPLIANCE_EVIDENCE_EXPORT_CREATED', v_actor,
    'compliance-export:' || v_export.compliance_evidence_export_id::text,
    v_case.tenant_configuration_version::text, 'SUCCEEDED', p_reason_codes,
    v_audit_hash, jsonb_build_object('schema_version', v_export.schema_version,
      'as_of', v_export.as_of, 'manifest_hash', v_export.manifest_hash,
      'evidence_record_count', v_export.evidence_record_count,
      'purpose_ref', v_export.purpose_ref));
  return v_export;
end
$$;

create or replace function private.get_compliance_evidence_export_impl(
  p_compliance_evidence_export_id uuid
)
returns public.compliance_evidence_exports
language plpgsql security definer
set search_path = public, private, extensions as $$
declare
  v_actor uuid := auth.uid();
  v_export public.compliance_evidence_exports;
  v_hash text;
begin
  if v_actor is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  select * into v_export from public.compliance_evidence_exports
    where compliance_evidence_export_id = p_compliance_evidence_export_id;
  if not found
    or not private.has_permission(v_export.tenant_id, v_export.agency_id, 'AUDIT_READ')
    or not private.has_permission(v_export.tenant_id, v_export.agency_id, 'EXPORT_DATA') then
    raise exception using errcode = 'P0002', message = 'COMPLIANCE_EXPORT_NOT_FOUND';
  end if;
  if encode(extensions.digest(v_export.manifest::text, 'sha256'), 'hex')
      <> v_export.manifest_hash then
    raise exception using errcode = '22000', message = 'COMPLIANCE_EXPORT_INTEGRITY_FAILED';
  end if;
  v_hash := encode(extensions.digest(concat_ws('|',
    v_export.compliance_evidence_export_id::text, v_export.manifest_hash,
    v_actor::text, 'DOWNLOADED'), 'sha256'), 'hex');
  insert into public.audit_events (tenant_id, agency_id, quote_case_id, event_type,
    actor_id, subject_ref, configuration_version_ref, outcome, reason_codes,
    integrity_hash, metadata)
  values (v_export.tenant_id, v_export.agency_id, v_export.quote_case_id,
    'COMPLIANCE_EVIDENCE_EXPORT_DOWNLOADED', v_actor,
    'compliance-export:' || v_export.compliance_evidence_export_id::text,
    null, 'SUCCEEDED', array['AUTHORIZED_EXPORT_DOWNLOAD'], v_hash,
    jsonb_build_object('schema_version', v_export.schema_version,
      'as_of', v_export.as_of, 'manifest_hash', v_export.manifest_hash));
  return v_export;
end
$$;

revoke all on function private.create_compliance_evidence_export_impl(uuid,timestamptz,text,text[],uuid) from public;
revoke all on function private.get_compliance_evidence_export_impl(uuid) from public;
grant execute on function private.create_compliance_evidence_export_impl(uuid,timestamptz,text,text[],uuid) to authenticated;
grant execute on function private.get_compliance_evidence_export_impl(uuid) to authenticated;

create or replace function public.create_compliance_evidence_export(
  p_quote_case_id uuid, p_as_of timestamptz, p_purpose_ref text,
  p_reason_codes text[], p_idempotency_key uuid
)
returns table (
  compliance_evidence_export_id uuid,
  quote_case_id uuid,
  schema_version text,
  as_of timestamptz,
  manifest_hash text,
  evidence_record_count integer,
  created_at timestamptz
) language sql security invoker
set search_path = public, private as $$
  select e.compliance_evidence_export_id, e.quote_case_id, e.schema_version,
    e.as_of, e.manifest_hash, e.evidence_record_count, e.created_at
  from private.create_compliance_evidence_export_impl(p_quote_case_id, p_as_of,
    p_purpose_ref, p_reason_codes, p_idempotency_key) e
$$;
create or replace function public.get_compliance_evidence_export(
  p_compliance_evidence_export_id uuid
)
returns table (
  compliance_evidence_export_id uuid,
  quote_case_id uuid,
  schema_version text,
  as_of timestamptz,
  manifest jsonb,
  manifest_hash text,
  evidence_record_count integer,
  created_at timestamptz
) language sql security invoker
set search_path = public, private as $$
  select e.compliance_evidence_export_id, e.quote_case_id, e.schema_version,
    e.as_of, e.manifest, e.manifest_hash, e.evidence_record_count, e.created_at
  from private.get_compliance_evidence_export_impl(p_compliance_evidence_export_id) e
$$;
revoke all on function public.create_compliance_evidence_export(uuid,timestamptz,text,text[],uuid) from public, anon, authenticated;
revoke all on function public.get_compliance_evidence_export(uuid) from public, anon, authenticated;
grant execute on function public.create_compliance_evidence_export(uuid,timestamptz,text,text[],uuid) to authenticated;
grant execute on function public.get_compliance_evidence_export(uuid) to authenticated;
