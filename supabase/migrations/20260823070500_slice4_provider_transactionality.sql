-- Slice 4: transactional provider queue, retry, and result settlement.

alter table public.external_requests
  add column if not exists attempt_count integer not null default 0,
  add column if not exists max_attempts integer not null default 3,
  add column if not exists next_attempt_at timestamptz not null default now(),
  add column if not exists locked_at timestamptz,
  add column if not exists worker_id text,
  add column if not exists last_error_code text;

create index if not exists external_requests_queue_idx
  on public.external_requests (status, next_attempt_at, requested_at)
  where status in ('PENDING','FAILED');

create or replace function private.claim_provider_request(
  p_external_request_id uuid,
  p_worker_id text
) returns public.external_requests
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_request public.external_requests;
begin
  if p_worker_id is null or length(trim(p_worker_id)) = 0 then
    raise exception 'WORKER_ID_REQUIRED' using errcode = '22023';
  end if;

  update public.external_requests
  set status = 'RUNNING',
      attempt_count = attempt_count + 1,
      locked_at = now(),
      worker_id = p_worker_id,
      last_error_code = null
  where external_request_id = p_external_request_id
    and status in ('PENDING','FAILED')
    and next_attempt_at <= now()
    and attempt_count < max_attempts
  returning * into v_request;

  if v_request.external_request_id is null then
    raise exception 'PROVIDER_REQUEST_NOT_CLAIMABLE' using errcode = '55000';
  end if;

  return v_request;
end;
$$;

create or replace function public.claim_provider_request(
  p_external_request_id uuid,
  p_worker_id text
) returns public.external_requests
language sql
security definer
set search_path = public, private, extensions
as $$
  select private.claim_provider_request(p_external_request_id, p_worker_id);
$$;

revoke all on function public.claim_provider_request(uuid,text) from public, anon, authenticated;
grant execute on function public.claim_provider_request(uuid,text) to service_role;

create or replace function private.mark_provider_request_retry(
  p_external_request_id uuid,
  p_error_code text,
  p_backoff_seconds integer default 60
) returns public.external_requests
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_request public.external_requests;
begin
  if p_backoff_seconds < 0 then
    raise exception 'INVALID_BACKOFF' using errcode = '22023';
  end if;

  update public.external_requests
  set status = case when attempt_count >= max_attempts then 'FAILED'::public.external_request_status else 'PENDING'::public.external_request_status end,
      next_attempt_at = case when attempt_count >= max_attempts then next_attempt_at else now() + make_interval(secs => p_backoff_seconds) end,
      locked_at = null,
      worker_id = null,
      last_error_code = p_error_code,
      failure_reason_codes = array_remove(array_append(failure_reason_codes, p_error_code), null),
      completed_at = case when attempt_count >= max_attempts then now() else null end
  where external_request_id = p_external_request_id
    and status = 'RUNNING'
  returning * into v_request;

  if v_request.external_request_id is null then
    raise exception 'PROVIDER_REQUEST_NOT_RUNNING' using errcode = '55000';
  end if;

  return v_request;
end;
$$;

create or replace function public.mark_provider_request_retry(
  p_external_request_id uuid,
  p_error_code text,
  p_backoff_seconds integer default 60
) returns public.external_requests
language sql
security definer
set search_path = public, private, extensions
as $$
  select private.mark_provider_request_retry(p_external_request_id, p_error_code, p_backoff_seconds);
$$;

revoke all on function public.mark_provider_request_retry(uuid,text,integer) from public, anon, authenticated;
grant execute on function public.mark_provider_request_retry(uuid,text,integer) to service_role;

create or replace function private.settle_provider_result(
  p_external_request_id uuid,
  p_provider_id text,
  p_provider_product_id text,
  p_provider_report_ref text,
  p_status public.external_report_status,
  p_retrieved_at timestamptz,
  p_fresh_until timestamptz,
  p_normalized_snapshot jsonb,
  p_normalized_version text,
  p_warnings text[],
  p_provenance jsonb,
  p_observations jsonb
) returns uuid
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_request public.external_requests;
  v_report_id uuid;
  v_provenance_item jsonb;
  v_observation_item jsonb;
  v_provenance_ids uuid[] := '{}';
  v_provenance_id uuid;
  v_outcome text;
  v_integrity text;
begin
  select * into v_request
  from public.external_requests
  where external_request_id = p_external_request_id
  for update;

  if v_request.external_request_id is null then
    raise exception 'EXTERNAL_REQUEST_NOT_FOUND' using errcode = 'P0002';
  end if;

  if v_request.status = 'SUCCEEDED' then
    select external_report_id into v_report_id
    from public.external_reports
    where external_request_id = p_external_request_id
    order by created_at desc
    limit 1;
    return v_report_id;
  end if;

  if v_request.status <> 'RUNNING' then
    raise exception 'PROVIDER_REQUEST_NOT_RUNNING' using errcode = '55000';
  end if;

  insert into public.external_reports (
    tenant_id, agency_id, quote_case_id, external_request_id,
    provider_id, provider_product_id, provider_report_ref,
    status, retrieved_at, fresh_until, normalized_snapshot,
    normalized_version, warnings
  ) values (
    v_request.tenant_id, v_request.agency_id, v_request.quote_case_id, v_request.external_request_id,
    p_provider_id, p_provider_product_id, p_provider_report_ref,
    p_status, p_retrieved_at, p_fresh_until, p_normalized_snapshot,
    p_normalized_version, coalesce(p_warnings, '{}')
  ) returning external_report_id into v_report_id;

  if p_provenance is not null then
    for v_provenance_item in select value from jsonb_array_elements(p_provenance)
    loop
      insert into public.provenance_entries (
        tenant_id, agency_id, quote_case_id, external_report_id,
        source_type, source_id, fact_key, source_path, source_timestamp,
        transformation_version, confidence_state, confirmation_state
      ) values (
        v_request.tenant_id,
        v_request.agency_id,
        v_request.quote_case_id,
        v_report_id,
        coalesce(v_provenance_item->>'sourceType','PROVIDER'),
        coalesce(v_provenance_item->>'sourceId', p_provider_report_ref, v_report_id::text),
        v_provenance_item->>'normalizedFactKey',
        v_provenance_item->>'sourceField',
        nullif(v_provenance_item->>'sourceTimestamp','')::timestamptz,
        coalesce(v_provenance_item->>'transformationVersion', p_normalized_version),
        case when v_provenance_item ? 'confidence' then v_provenance_item->>'confidence' else null end,
        null
      ) returning provenance_entry_id into v_provenance_id;
      v_provenance_ids := array_append(v_provenance_ids, v_provenance_id);
    end loop;
  end if;

  if p_observations is not null and p_status <> 'NO_HIT' then
    for v_observation_item in select value from jsonb_array_elements(p_observations)
    loop
      insert into public.underwriting_observations (
        tenant_id, agency_id, quote_case_id, observation_type, subject_id,
        normalized_value, provenance_entry_ids, data_use_classification,
        data_use_policy_version, freshness_state, conflict_state
      ) values (
        v_request.tenant_id,
        v_request.agency_id,
        v_request.quote_case_id,
        v_observation_item->>'observationType',
        nullif(v_observation_item->>'subjectId','')::uuid,
        coalesce(v_observation_item->'normalizedValue','null'::jsonb),
        v_provenance_ids,
        'UNCLASSIFIED',
        null,
        coalesce(v_observation_item->>'freshnessState', case when p_status = 'STALE' then 'STALE' else 'CURRENT' end),
        'NONE'
      );
    end loop;
  end if;

  v_outcome := case when p_status = 'ERROR' then 'FAILED' else 'SUCCEEDED' end;

  update public.external_requests
  set status = case when p_status = 'ERROR' then 'FAILED'::public.external_request_status else 'SUCCEEDED'::public.external_request_status end,
      provider_request_ref = coalesce(provider_request_ref, p_provider_report_ref),
      completed_at = now(),
      locked_at = null,
      worker_id = null,
      last_error_code = case when p_status = 'ERROR' then 'PROVIDER_RESULT_ERROR' else null end
  where external_request_id = p_external_request_id;

  v_integrity := encode(extensions.digest(
    concat_ws('|', v_request.tenant_id::text, v_request.quote_case_id::text, p_external_request_id::text,
      v_report_id::text, p_status::text, p_retrieved_at::text), 'sha256'
  ), 'hex');

  insert into public.audit_events (
    tenant_id, agency_id, quote_case_id, event_type, subject_ref,
    configuration_version_ref, outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_request.tenant_id,
    v_request.agency_id,
    v_request.quote_case_id,
    'PROVIDER_RESULT_SETTLED',
    p_external_request_id::text,
    v_request.tenant_configuration_version::text,
    v_outcome,
    case when p_status = 'ERROR' then array['PROVIDER_RESULT_ERROR'] else '{}'::text[] end,
    v_integrity,
    jsonb_build_object('externalReportId', v_report_id, 'status', p_status, 'providerId', p_provider_id)
  );

  return v_report_id;
end;
$$;

create or replace function public.settle_provider_result(
  p_external_request_id uuid,
  p_provider_id text,
  p_provider_product_id text,
  p_provider_report_ref text,
  p_status public.external_report_status,
  p_retrieved_at timestamptz,
  p_fresh_until timestamptz,
  p_normalized_snapshot jsonb,
  p_normalized_version text,
  p_warnings text[],
  p_provenance jsonb,
  p_observations jsonb
) returns uuid
language sql
security definer
set search_path = public, private, extensions
as $$
  select private.settle_provider_result(
    p_external_request_id, p_provider_id, p_provider_product_id, p_provider_report_ref,
    p_status, p_retrieved_at, p_fresh_until, p_normalized_snapshot, p_normalized_version,
    p_warnings, p_provenance, p_observations
  );
$$;

revoke all on function public.settle_provider_result(uuid,text,text,text,public.external_report_status,timestamptz,timestamptz,jsonb,text,text[],jsonb,jsonb) from public, anon, authenticated;
grant execute on function public.settle_provider_result(uuid,text,text,text,public.external_report_status,timestamptz,timestamptz,jsonb,text,text[],jsonb,jsonb) to service_role;
