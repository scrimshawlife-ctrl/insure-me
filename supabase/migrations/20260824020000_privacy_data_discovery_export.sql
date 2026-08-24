-- T802: verified, tenant-scoped privacy discovery and encrypted access export.

create type public.privacy_discovery_outcome as enum (
  'MATCHED',
  'NO_MATCH',
  'AMBIGUOUS'
);

create type public.privacy_discovery_status as enum (
  'PREPARED',
  'COMPLETED'
);

create table public.privacy_discovery_runs (
  privacy_discovery_run_id uuid primary key default gen_random_uuid(),
  privacy_request_id uuid not null,
  tenant_id uuid not null,
  agency_id uuid not null,
  idempotency_key uuid not null,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  status public.privacy_discovery_status not null default 'PREPARED',
  outcome public.privacy_discovery_outcome not null,
  matched_person_id uuid,
  configuration_version_ref text not null,
  disclosure_policy_version text not null check (disclosure_policy_version ~ '^[A-Za-z0-9_.:-]{3,100}$'),
  export_schema_version text not null check (export_schema_version ~ '^[A-Za-z0-9_.:-]{3,100}$'),
  record_counts jsonb not null default '{}'::jsonb,
  record_count integer not null default 0 check (record_count >= 0),
  package_digest text check (package_digest is null or package_digest ~ '^[0-9a-f]{64}$'),
  discovered_at timestamptz not null default now(),
  completed_at timestamptz,
  foreign key (tenant_id, agency_id, privacy_request_id)
    references public.privacy_requests(tenant_id, agency_id, privacy_request_id),
  foreign key (tenant_id, agency_id, matched_person_id)
    references public.people(tenant_id, agency_id, person_id),
  unique (privacy_request_id, idempotency_key),
  unique (tenant_id, agency_id, privacy_request_id, privacy_discovery_run_id),
  check ((outcome = 'MATCHED') = (matched_person_id is not null)),
  check ((status = 'COMPLETED') = (completed_at is not null))
);

create table public.privacy_export_artifacts (
  privacy_discovery_run_id uuid primary key,
  privacy_request_id uuid not null,
  tenant_id uuid not null,
  agency_id uuid not null,
  encrypted_export bytea not null check (octet_length(encrypted_export) between 30 and 1048576),
  encryption_algorithm text not null check (encryption_algorithm = 'AES-256-GCM'),
  key_version text not null check (char_length(key_version) between 1 and 64),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  record_count integer not null check (record_count > 0),
  created_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id, privacy_request_id, privacy_discovery_run_id)
    references public.privacy_discovery_runs(
      tenant_id, agency_id, privacy_request_id, privacy_discovery_run_id
    ),
  foreign key (tenant_id, agency_id, privacy_request_id)
    references public.privacy_requests(tenant_id, agency_id, privacy_request_id)
);

create index privacy_discovery_runs_request_idx
  on public.privacy_discovery_runs (tenant_id, agency_id, privacy_request_id, discovered_at desc);

alter table public.privacy_discovery_runs enable row level security;
alter table public.privacy_export_artifacts enable row level security;

create policy privacy_discovery_runs_admin_select
on public.privacy_discovery_runs
for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
);

revoke all on public.privacy_discovery_runs, public.privacy_export_artifacts
from anon, authenticated;
grant select on public.privacy_discovery_runs to authenticated;

create or replace function private.prevent_privacy_export_artifact_mutation()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  raise exception using errcode = '22023', message = 'PRIVACY_EXPORT_ARTIFACT_IMMUTABLE';
  return null;
end
$$;

revoke all on function private.prevent_privacy_export_artifact_mutation() from public;

create trigger privacy_export_artifact_immutable
before update or delete on public.privacy_export_artifacts
for each row execute function private.prevent_privacy_export_artifact_mutation();

create or replace function private.build_privacy_export_source(
  p_tenant_id uuid,
  p_agency_id uuid,
  p_person_id uuid,
  p_public_reference uuid,
  p_policy_version text,
  p_schema_version text,
  p_generated_at timestamptz
)
returns jsonb
language sql
stable
security invoker
set search_path = public, private
as $$
  with person_context as (
    select pp.person_id, encode(pp.encrypted_payload, 'hex') as ciphertext_hex,
           pp.key_version, pp.payload_version, pp.created_at, pp.updated_at
    from public.person_private_profiles pp
    where pp.tenant_id = p_tenant_id
      and pp.agency_id = p_agency_id
      and pp.person_id = p_person_id
  ), case_context as (
    select qc.*
    from public.quote_cases qc
    join public.prospects p on p.prospect_id = qc.prospect_id
    where qc.tenant_id = p_tenant_id
      and qc.agency_id = p_agency_id
      and p.person_id = p_person_id
  )
  select jsonb_build_object(
    'metadata', jsonb_build_object(
      'schemaVersion', p_schema_version,
      'privacyRequestId', p_public_reference,
      'policyVersion', p_policy_version,
      'generatedAt', p_generated_at
    ),
    'person', (
      select jsonb_build_object(
        'ciphertextHex', pc.ciphertext_hex,
        'keyVersion', pc.key_version,
        'payloadVersion', pc.payload_version,
        'createdAt', pc.created_at,
        'updatedAt', pc.updated_at
      ) from person_context pc
    ),
    'quoteCases', coalesce((
      select jsonb_agg(jsonb_build_object(
        'quoteCaseId', cc.quote_case_id,
        'jurisdiction', cc.jurisdiction,
        'productLine', cc.product_line,
        'sourceChannel', cc.source_channel,
        'state', cc.state,
        'createdAt', cc.created_at,
        'updatedAt', cc.updated_at,
        'closedAt', cc.closed_at
      ) order by cc.created_at, cc.quote_case_id) from case_context cc
    ), '[]'::jsonb),
    'drivers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'driverId', d.driver_id,
        'quoteCaseId', d.quote_case_id,
        'relationshipRole', d.relationship_role,
        'firstName', d.first_name,
        'lastName', d.last_name,
        'dateOfBirth', d.date_of_birth,
        'licenseJurisdiction', d.license_jurisdiction,
        'licenseCiphertextHex', case when d.license_identifier_ciphertext is null then null else encode(d.license_identifier_ciphertext, 'hex') end,
        'licenseKeyVersion', d.license_identifier_key_version,
        'licenseStatus', d.license_status,
        'yearsLicensed', d.years_licensed,
        'confirmationState', d.confirmation_state,
        'sourceType', d.source_type,
        'createdAt', d.created_at,
        'updatedAt', d.updated_at
      ) order by d.created_at, d.driver_id)
      from public.drivers d
      where d.tenant_id = p_tenant_id and d.agency_id = p_agency_id
        and d.quote_case_id in (select quote_case_id from case_context)
    ), '[]'::jsonb),
    'vehicles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'vehicleId', v.vehicle_id,
        'quoteCaseId', v.quote_case_id,
        'vinCiphertextHex', case when v.vin_ciphertext is null then null else encode(v.vin_ciphertext, 'hex') end,
        'vinKeyVersion', v.vin_key_version,
        'modelYear', v.model_year,
        'make', v.make,
        'model', v.model,
        'trim', v.trim,
        'ownershipState', v.ownership_state,
        'garagingPostalCode', v.garaging_postal_code,
        'usage', v.usage,
        'annualMileage', v.annual_mileage,
        'confirmationState', v.confirmation_state,
        'sourceType', v.source_type,
        'createdAt', v.created_at,
        'updatedAt', v.updated_at
      ) order by v.created_at, v.vehicle_id)
      from public.vehicles v
      where v.tenant_id = p_tenant_id and v.agency_id = p_agency_id
        and v.quote_case_id in (select quote_case_id from case_context)
    ), '[]'::jsonb),
    'coverageRequests', coalesce((
      select jsonb_agg(jsonb_build_object(
        'coverageRequestId', cr.coverage_request_id,
        'quoteCaseId', cr.quote_case_id,
        'schemaVersion', cr.schema_version,
        'requestedLimits', cr.requested_limits,
        'preferences', cr.preferences,
        'notes', cr.notes,
        'createdAt', cr.created_at,
        'updatedAt', cr.updated_at
      ) order by cr.created_at, cr.coverage_request_id)
      from public.coverage_requests cr
      where cr.tenant_id = p_tenant_id and cr.agency_id = p_agency_id
        and cr.quote_case_id in (select quote_case_id from case_context)
    ), '[]'::jsonb),
    'consents', coalesce((
      select jsonb_agg(jsonb_build_object(
        'consentRecordId', c.consent_record_id,
        'quoteCaseId', c.quote_case_id,
        'noticeDefinitionId', c.notice_definition_id,
        'noticeVersion', c.notice_version,
        'actionType', c.action_type,
        'presentedAt', c.presented_at,
        'actedAt', c.acted_at,
        'channel', c.channel,
        'evidenceRef', c.evidence_ref
      ) order by c.acted_at, c.consent_record_id)
      from public.consent_records c
      where c.tenant_id = p_tenant_id and c.agency_id = p_agency_id
        and c.quote_case_id in (select quote_case_id from case_context)
    ), '[]'::jsonb),
    'externalReports', coalesce((
      select jsonb_agg(jsonb_build_object(
        'externalReportId', er.external_report_id,
        'quoteCaseId', er.quote_case_id,
        'providerId', er.provider_id,
        'providerProductId', er.provider_product_id,
        'status', er.status,
        'retrievedAt', er.retrieved_at,
        'freshUntil', er.fresh_until,
        'normalizedSnapshot', er.normalized_snapshot,
        'normalizedVersion', er.normalized_version,
        'warnings', er.warnings
      ) order by er.retrieved_at, er.external_report_id)
      from public.external_reports er
      where er.tenant_id = p_tenant_id and er.agency_id = p_agency_id
        and er.quote_case_id in (select quote_case_id from case_context)
    ), '[]'::jsonb),
    'underwritingObservations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'observationId', uo.observation_id,
        'quoteCaseId', uo.quote_case_id,
        'observationType', uo.observation_type,
        'normalizedValue', uo.normalized_value,
        'dataUseClassification', uo.data_use_classification,
        'dataUsePolicyVersion', uo.data_use_policy_version,
        'freshnessState', uo.freshness_state,
        'conflictState', uo.conflict_state,
        'createdAt', uo.created_at
      ) order by uo.created_at, uo.observation_id)
      from public.underwriting_observations uo
      where uo.tenant_id = p_tenant_id and uo.agency_id = p_agency_id
        and uo.quote_case_id in (select quote_case_id from case_context)
    ), '[]'::jsonb),
    'carrierDecisions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'carrierDecisionId', cd.carrier_decision_id,
        'quoteCaseId', cs.quote_case_id,
        'decisionStatus', cd.decision_status,
        'premium', cd.premium,
        'reasonCodes', cd.reason_codes,
        'receivedAt', cd.received_at
      ) order by cd.received_at, cd.carrier_decision_id)
      from public.carrier_decisions cd
      join public.carrier_submissions cs
        on cs.carrier_submission_id = cd.carrier_submission_id
       and cs.tenant_id = cd.tenant_id and cs.agency_id = cd.agency_id
      where cd.tenant_id = p_tenant_id and cd.agency_id = p_agency_id
        and cs.quote_case_id in (select quote_case_id from case_context)
    ), '[]'::jsonb)
  )
$$;

revoke all on function private.build_privacy_export_source(
  uuid, uuid, uuid, uuid, text, text, timestamptz
) from public;

create or replace function private.privacy_export_record_counts(p_source jsonb)
returns jsonb
language sql
immutable
set search_path = pg_catalog
as $$
  select jsonb_build_object(
    'people', case when p_source->'person' is null or p_source->'person' = 'null'::jsonb then 0 else 1 end,
    'quoteCases', jsonb_array_length(coalesce(p_source->'quoteCases', '[]'::jsonb)),
    'drivers', jsonb_array_length(coalesce(p_source->'drivers', '[]'::jsonb)),
    'vehicles', jsonb_array_length(coalesce(p_source->'vehicles', '[]'::jsonb)),
    'coverageRequests', jsonb_array_length(coalesce(p_source->'coverageRequests', '[]'::jsonb)),
    'consents', jsonb_array_length(coalesce(p_source->'consents', '[]'::jsonb)),
    'externalReports', jsonb_array_length(coalesce(p_source->'externalReports', '[]'::jsonb)),
    'underwritingObservations', jsonb_array_length(coalesce(p_source->'underwritingObservations', '[]'::jsonb)),
    'carrierDecisions', jsonb_array_length(coalesce(p_source->'carrierDecisions', '[]'::jsonb))
  )
$$;

revoke all on function private.privacy_export_record_counts(jsonb) from public;

create or replace function private.privacy_export_record_count(p_counts jsonb)
returns integer
language sql
immutable
set search_path = pg_catalog
as $$
  select coalesce(sum(value::integer), 0)::integer
  from jsonb_each_text(p_counts)
$$;

revoke all on function private.privacy_export_record_count(jsonb) from public;

create or replace function private.prepare_privacy_discovery_impl(
  p_hostname text,
  p_public_reference uuid,
  p_status_token_hash text,
  p_idempotency_key uuid,
  p_request_hash text,
  p_disclosure_policy_version text,
  p_export_schema_version text
)
returns table (
  privacy_discovery_run_id uuid,
  discovery_status public.privacy_discovery_status,
  request_type public.privacy_request_type,
  public_reference uuid,
  state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state,
  discovery_outcome public.privacy_discovery_outcome,
  source_payload jsonb,
  record_count integer
)
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_host public.tenant_hosts;
  v_request public.privacy_requests;
  v_evidence public.privacy_request_intake_evidence;
  v_existing public.privacy_discovery_runs;
  v_run public.privacy_discovery_runs;
  v_match_count integer;
  v_person_ids uuid[];
  v_person_id uuid;
  v_source jsonb;
  v_counts jsonb := '{}'::jsonb;
  v_record_count integer := 0;
  v_outcome public.privacy_discovery_outcome;
  v_integrity_hash text;
begin
  if p_public_reference is null or p_idempotency_key is null
     or p_status_token_hash is null or p_status_token_hash !~ '^[0-9a-f]{64}$'
     or p_request_hash is null or p_request_hash !~ '^[0-9a-f]{64}$'
     or p_disclosure_policy_version is null
     or p_disclosure_policy_version !~ '^[A-Za-z0-9_.:-]{3,100}$'
     or p_export_schema_version is null
     or p_export_schema_version !~ '^[A-Za-z0-9_.:-]{3,100}$' then
    raise exception using errcode = '22023', message = 'PRIVACY_DISCOVERY_INPUT_INVALID';
  end if;

  select * into v_host from public.tenant_hosts
  where hostname = lower(split_part(trim(p_hostname), ':', 1)) and status = 'ACTIVE';
  if not found then
    raise exception using errcode = 'P0002', message = 'PRIVACY_REQUEST_NOT_FOUND';
  end if;

  select pr.* into v_request
  from public.privacy_requests pr
  join public.privacy_request_intake_evidence pie
    on pie.tenant_id = pr.tenant_id and pie.agency_id = pr.agency_id
   and pie.privacy_request_id = pr.privacy_request_id
  where pr.tenant_id = v_host.tenant_id and pr.agency_id = v_host.agency_id
    and pr.public_reference = p_public_reference
    and pie.status_token_hash = p_status_token_hash
  for update of pr;
  if not found then
    raise exception using errcode = 'P0002', message = 'PRIVACY_REQUEST_NOT_FOUND';
  end if;
  select * into v_evidence from public.privacy_request_intake_evidence
  where privacy_request_id = v_request.privacy_request_id;

  select * into v_existing from public.privacy_discovery_runs
  where privacy_request_id = v_request.privacy_request_id
    and idempotency_key = p_idempotency_key;
  if found then
    if v_existing.request_hash <> p_request_hash
       or v_existing.disclosure_policy_version <> p_disclosure_policy_version
       or v_existing.export_schema_version <> p_export_schema_version then
      raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUEST_MISMATCH';
    end if;
    if v_existing.outcome = 'MATCHED'
       and v_request.request_type = 'ACCESS'
       and v_existing.status = 'PREPARED' then
      v_source := private.build_privacy_export_source(
        v_existing.tenant_id, v_existing.agency_id, v_existing.matched_person_id,
        v_request.public_reference, v_existing.disclosure_policy_version,
        v_existing.export_schema_version, v_existing.discovered_at
      );
    end if;
    return query select v_existing.privacy_discovery_run_id, v_existing.status,
      v_request.request_type,
      v_request.public_reference, v_request.state, v_request.identity_verification_state,
      v_existing.outcome, v_source, v_existing.record_count;
    return;
  end if;

  if v_request.identity_verification_state <> 'VERIFIED'
     or v_request.state <> 'IDENTITY_VERIFIED' then
    raise exception using errcode = '55000', message = 'PRIVACY_DISCOVERY_STATE_INVALID';
  end if;

  select count(*)::integer, array_agg(pp.person_id order by pp.person_id)
  into v_match_count, v_person_ids
  from public.person_private_profiles pp
  where pp.tenant_id = v_request.tenant_id and pp.agency_id = v_request.agency_id
    and pp.email_lookup_hash = v_evidence.email_lookup_hash
    and (v_evidence.phone_lookup_hash is null or pp.phone_lookup_hash = v_evidence.phone_lookup_hash);

  if v_match_count = 1 then
    v_outcome := 'MATCHED';
    v_person_id := v_person_ids[1];
    v_source := private.build_privacy_export_source(
      v_request.tenant_id, v_request.agency_id, v_person_id,
      v_request.public_reference, p_disclosure_policy_version,
      p_export_schema_version, now()
    );
    v_counts := private.privacy_export_record_counts(v_source);
    v_record_count := private.privacy_export_record_count(v_counts);
  elsif v_match_count = 0 then
    v_outcome := 'NO_MATCH';
    v_person_id := null;
  else
    v_outcome := 'AMBIGUOUS';
    v_person_id := null;
  end if;

  insert into public.privacy_discovery_runs (
    privacy_request_id, tenant_id, agency_id, idempotency_key, request_hash,
    outcome, matched_person_id, configuration_version_ref, disclosure_policy_version,
    export_schema_version, record_counts, record_count
  ) values (
    v_request.privacy_request_id, v_request.tenant_id, v_request.agency_id,
    p_idempotency_key, p_request_hash, v_outcome, v_person_id,
    v_host.tenant_configuration_version::text,
    p_disclosure_policy_version, p_export_schema_version, v_counts, v_record_count
  ) returning * into v_run;

  if v_outcome = 'MATCHED' then
    update public.privacy_requests
    set matched_person_id = v_person_id, updated_at = now()
    where privacy_request_id = v_request.privacy_request_id
    returning * into v_request;
    -- Rebuild with the persisted discovery timestamp for deterministic replay.
    v_source := private.build_privacy_export_source(
      v_request.tenant_id, v_request.agency_id, v_person_id,
      v_request.public_reference, p_disclosure_policy_version,
      p_export_schema_version, v_run.discovered_at
    );
  end if;

  v_integrity_hash := encode(digest(concat_ws('|',
    v_request.tenant_id::text, v_request.privacy_request_id::text,
    v_run.privacy_discovery_run_id::text, v_outcome::text,
    p_disclosure_policy_version, clock_timestamp()::text
  ), 'sha256'), 'hex');
  insert into public.audit_events (
    tenant_id, agency_id, event_type, subject_ref, configuration_version_ref,
    policy_version_refs, outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_request.tenant_id, v_request.agency_id, 'PRIVACY_DISCOVERY_PREPARED',
    'privacy-request:' || v_request.public_reference::text,
    v_host.tenant_configuration_version::text, array[p_disclosure_policy_version],
    v_outcome::text, array[v_outcome::text], v_integrity_hash,
    jsonb_build_object('discovery_run_id', v_run.privacy_discovery_run_id,
      'record_counts', case when v_outcome = 'MATCHED' then v_counts else '{}'::jsonb end)
  );

  return query select v_run.privacy_discovery_run_id, v_run.status,
    v_request.request_type,
    v_request.public_reference, v_request.state, v_request.identity_verification_state,
    v_outcome, v_source, v_record_count;
end
$$;

revoke all on function private.prepare_privacy_discovery_impl(
  text, uuid, text, uuid, text, text, text
) from public;
grant execute on function private.prepare_privacy_discovery_impl(
  text, uuid, text, uuid, text, text, text
) to service_role;

create or replace function public.prepare_privacy_discovery(
  p_hostname text, p_public_reference uuid, p_status_token_hash text,
  p_idempotency_key uuid, p_request_hash text,
  p_disclosure_policy_version text, p_export_schema_version text
)
returns table (
  privacy_discovery_run_id uuid,
  discovery_status public.privacy_discovery_status,
  request_type public.privacy_request_type,
  public_reference uuid, state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state,
  discovery_outcome public.privacy_discovery_outcome,
  source_payload jsonb, record_count integer
)
language sql
security invoker
set search_path = public, private
as $$
  select * from private.prepare_privacy_discovery_impl(
    p_hostname, p_public_reference, p_status_token_hash, p_idempotency_key,
    p_request_hash, p_disclosure_policy_version, p_export_schema_version
  )
$$;

revoke all on function public.prepare_privacy_discovery(
  text, uuid, text, uuid, text, text, text
) from public, anon, authenticated;
grant execute on function public.prepare_privacy_discovery(
  text, uuid, text, uuid, text, text, text
) to service_role;

create or replace function private.settle_privacy_discovery_impl(
  p_privacy_discovery_run_id uuid,
  p_export_ciphertext bytea,
  p_key_version text,
  p_content_hash text,
  p_record_count integer
)
returns table (
  public_reference uuid,
  state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state,
  discovery_outcome public.privacy_discovery_outcome,
  export_available boolean
)
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_run public.privacy_discovery_runs;
  v_request public.privacy_requests;
  v_artifact public.privacy_export_artifacts;
  v_requires_export boolean;
  v_reason text;
  v_integrity_hash text;
begin
  select * into v_run from public.privacy_discovery_runs
  where privacy_discovery_run_id = p_privacy_discovery_run_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'PRIVACY_DISCOVERY_NOT_FOUND';
  end if;
  select * into v_request from public.privacy_requests
  where privacy_request_id = v_run.privacy_request_id for update;
  v_requires_export := v_run.outcome = 'MATCHED' and v_request.request_type = 'ACCESS';

  if v_run.status = 'COMPLETED' then
    select * into v_artifact from public.privacy_export_artifacts
    where privacy_discovery_run_id = v_run.privacy_discovery_run_id;
    if v_requires_export and (
      not found or p_content_hash is null or p_key_version is null
      or p_record_count is null or v_artifact.content_hash <> p_content_hash
      or v_artifact.key_version <> p_key_version
      or v_artifact.record_count <> p_record_count
    ) then
      raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUEST_MISMATCH';
    end if;
    return query select v_request.public_reference, v_request.state,
      v_request.identity_verification_state, v_run.outcome, v_requires_export;
    return;
  end if;

  if v_requires_export then
    if p_export_ciphertext is null or octet_length(p_export_ciphertext) not between 30 and 1048576
       or p_key_version is null or char_length(p_key_version) not between 1 and 64
       or p_content_hash is null or p_content_hash !~ '^[0-9a-f]{64}$'
       or p_record_count is null or p_record_count <> v_run.record_count or p_record_count < 1 then
      raise exception using errcode = '22023', message = 'PRIVACY_EXPORT_INPUT_INVALID';
    end if;
    insert into public.privacy_export_artifacts (
      privacy_discovery_run_id, privacy_request_id, tenant_id, agency_id,
      encrypted_export, encryption_algorithm, key_version, content_hash, record_count
    ) values (
      v_run.privacy_discovery_run_id, v_run.privacy_request_id,
      v_run.tenant_id, v_run.agency_id, p_export_ciphertext,
      'AES-256-GCM', p_key_version, p_content_hash, p_record_count
    );
  elsif p_export_ciphertext is not null or p_key_version is not null
     or p_content_hash is not null or p_record_count is not null then
    raise exception using errcode = '22023', message = 'PRIVACY_EXPORT_NOT_APPLICABLE';
  end if;

  v_reason := case v_run.outcome
    when 'MATCHED' then 'RECORD_MATCH_CONFIRMED'
    when 'NO_MATCH' then 'NO_RECORD_MATCH'
    else 'MULTIPLE_RECORD_MATCHES'
  end;
  update public.privacy_discovery_runs
  set status = 'COMPLETED', package_digest = case when v_requires_export then p_content_hash else null end,
      completed_at = now()
  where privacy_discovery_run_id = v_run.privacy_discovery_run_id
  returning * into v_run;
  update public.privacy_requests
  set state = 'APPLICABILITY_REVIEW', applicability_reason_codes = array[v_reason],
      policy_version_refs = case
        when v_run.disclosure_policy_version = any(policy_version_refs) then policy_version_refs
        else array_append(policy_version_refs, v_run.disclosure_policy_version)
      end,
      updated_at = now()
  where privacy_request_id = v_run.privacy_request_id
  returning * into v_request;

  v_integrity_hash := encode(digest(concat_ws('|',
    v_run.tenant_id::text, v_run.privacy_request_id::text,
    v_run.privacy_discovery_run_id::text, v_run.outcome::text,
    coalesce(p_content_hash, 'NO_EXPORT'), clock_timestamp()::text
  ), 'sha256'), 'hex');
  insert into public.audit_events (
    tenant_id, agency_id, event_type, subject_ref, configuration_version_ref,
    policy_version_refs,
    outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_run.tenant_id, v_run.agency_id, 'PRIVACY_DISCOVERY_COMPLETED',
    'privacy-request:' || v_request.public_reference::text,
    v_run.configuration_version_ref,
    array[v_run.disclosure_policy_version], v_run.outcome::text, array[v_reason],
    v_integrity_hash, jsonb_build_object(
      'discovery_run_id', v_run.privacy_discovery_run_id,
      'export_created', v_requires_export,
      'record_count', case when v_requires_export then v_run.record_count else 0 end
    )
  );

  return query select v_request.public_reference, v_request.state,
    v_request.identity_verification_state, v_run.outcome, v_requires_export;
end
$$;

revoke all on function private.settle_privacy_discovery_impl(
  uuid, bytea, text, text, integer
) from public;
grant execute on function private.settle_privacy_discovery_impl(
  uuid, bytea, text, text, integer
) to service_role;

create or replace function public.settle_privacy_discovery(
  p_privacy_discovery_run_id uuid, p_export_ciphertext bytea,
  p_key_version text, p_content_hash text, p_record_count integer
)
returns table (
  public_reference uuid, state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state,
  discovery_outcome public.privacy_discovery_outcome, export_available boolean
)
language sql
security invoker
set search_path = public, private
as $$
  select * from private.settle_privacy_discovery_impl(
    p_privacy_discovery_run_id, p_export_ciphertext, p_key_version,
    p_content_hash, p_record_count
  )
$$;

revoke all on function public.settle_privacy_discovery(
  uuid, bytea, text, text, integer
) from public, anon, authenticated;
grant execute on function public.settle_privacy_discovery(
  uuid, bytea, text, text, integer
) to service_role;

create or replace function private.get_privacy_export_artifact_impl(
  p_hostname text, p_public_reference uuid, p_status_token_hash text
)
returns table (
  public_reference uuid, export_ciphertext_hex text,
  key_version text, content_hash text, record_count integer
)
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_host public.tenant_hosts;
  v_request public.privacy_requests;
  v_run public.privacy_discovery_runs;
  v_artifact public.privacy_export_artifacts;
  v_integrity_hash text;
begin
  select * into v_host from public.tenant_hosts
  where hostname = lower(split_part(trim(p_hostname), ':', 1)) and status = 'ACTIVE';
  if not found then return; end if;
  select pr.* into v_request
  from public.privacy_requests pr
  join public.privacy_request_intake_evidence pie
    on pie.tenant_id = pr.tenant_id and pie.agency_id = pr.agency_id
   and pie.privacy_request_id = pr.privacy_request_id
  where pr.tenant_id = v_host.tenant_id and pr.agency_id = v_host.agency_id
    and pr.public_reference = p_public_reference
    and pie.status_token_hash = p_status_token_hash
    and pr.request_type = 'ACCESS';
  if not found then return; end if;
  select * into v_run from public.privacy_discovery_runs
  where privacy_request_id = v_request.privacy_request_id
    and status = 'COMPLETED' and outcome = 'MATCHED'
  order by completed_at desc limit 1;
  if not found then return; end if;
  select * into v_artifact from public.privacy_export_artifacts
  where privacy_discovery_run_id = v_run.privacy_discovery_run_id;
  if not found then return; end if;

  v_integrity_hash := encode(digest(concat_ws('|',
    v_request.tenant_id::text, v_request.privacy_request_id::text,
    v_run.privacy_discovery_run_id::text, 'PRIVACY_EXPORT_DOWNLOADED',
    clock_timestamp()::text
  ), 'sha256'), 'hex');
  insert into public.audit_events (
    tenant_id, agency_id, event_type, subject_ref, configuration_version_ref,
    policy_version_refs,
    outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_request.tenant_id, v_request.agency_id, 'PRIVACY_EXPORT_DOWNLOADED',
    'privacy-request:' || v_request.public_reference::text,
    v_run.configuration_version_ref,
    array[v_run.disclosure_policy_version], 'SUCCEEDED', '{}', v_integrity_hash,
    jsonb_build_object('discovery_run_id', v_run.privacy_discovery_run_id,
      'record_count', v_artifact.record_count)
  );

  return query select v_request.public_reference,
    encode(v_artifact.encrypted_export, 'hex'), v_artifact.key_version,
    v_artifact.content_hash, v_artifact.record_count;
end
$$;

revoke all on function private.get_privacy_export_artifact_impl(text, uuid, text) from public;
grant execute on function private.get_privacy_export_artifact_impl(text, uuid, text) to service_role;

create or replace function public.get_privacy_export_artifact(
  p_hostname text, p_public_reference uuid, p_status_token_hash text
)
returns table (
  public_reference uuid, export_ciphertext_hex text,
  key_version text, content_hash text, record_count integer
)
language sql
security invoker
set search_path = public, private
as $$
  select * from private.get_privacy_export_artifact_impl(
    p_hostname, p_public_reference, p_status_token_hash
  )
$$;

revoke all on function public.get_privacy_export_artifact(text, uuid, text)
from public, anon, authenticated;
grant execute on function public.get_privacy_export_artifact(text, uuid, text)
to service_role;
