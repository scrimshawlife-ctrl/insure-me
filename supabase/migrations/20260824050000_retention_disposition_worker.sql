-- T805: provider-neutral retention scheduler and disposition worker.
-- Q-007 remains a production blocker: this worker executes only an exact
-- SYNTHETIC or APPROVED policy supplied by the trusted server.

create type public.retention_run_status as enum (
  'PREPARED', 'IN_PROGRESS', 'COMPLETED', 'ATTENTION_REQUIRED'
);
create type public.retention_item_status as enum (
  'SCHEDULED', 'BLOCKED', 'COMPLETED', 'FAILED', 'REVIEW_REQUIRED'
);
create type public.retention_disposition_outcome as enum (
  'DELETED', 'ANONYMIZED', 'REVIEW_REQUIRED', 'FAILED'
);

create table public.retention_disposition_runs (
  retention_disposition_run_id uuid primary key default gen_random_uuid(),
  idempotency_key uuid not null unique,
  expected_certification_state public.retention_policy_certification_state not null,
  as_of timestamptz not null,
  status public.retention_run_status not null default 'PREPARED',
  status_summary jsonb not null default '{}'::jsonb,
  prepared_at timestamptz not null default now(),
  completed_at timestamptz,
  check (expected_certification_state in ('SYNTHETIC', 'APPROVED')),
  check ((status = 'COMPLETED') = (completed_at is not null))
);

create table public.retention_disposition_items (
  retention_disposition_item_id uuid primary key default gen_random_uuid(),
  current_run_id uuid not null references public.retention_disposition_runs(retention_disposition_run_id),
  privacy_rights_action_id uuid not null unique references public.privacy_rights_actions(privacy_rights_action_id),
  privacy_request_id uuid not null,
  tenant_id uuid not null,
  agency_id uuid not null,
  data_class text not null,
  retention_policy_id uuid references public.retention_policies(retention_policy_id),
  policy_set_id text,
  policy_version integer,
  disposition public.retention_disposition,
  eligible_at timestamptz,
  status public.retention_item_status not null,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  evidence_ref text,
  reason_codes text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  foreign key (tenant_id, agency_id, privacy_request_id)
    references public.privacy_requests(tenant_id, agency_id, privacy_request_id),
  check (
    (retention_policy_id is null and policy_set_id is null and policy_version is null
      and disposition is null and eligible_at is null)
    or
    (retention_policy_id is not null and policy_set_id is not null and policy_version is not null
      and disposition is not null and eligible_at is not null)
  ),
  check ((status = 'COMPLETED') = (completed_at is not null)),
  check (evidence_ref is null or char_length(evidence_ref) between 3 and 500)
);

create table public.retention_disposition_attempts (
  retention_disposition_attempt_id uuid primary key default gen_random_uuid(),
  retention_disposition_item_id uuid not null references public.retention_disposition_items(retention_disposition_item_id),
  retention_disposition_run_id uuid not null references public.retention_disposition_runs(retention_disposition_run_id),
  privacy_request_id uuid not null,
  tenant_id uuid not null,
  agency_id uuid not null,
  attempt_number integer not null check (attempt_number > 0),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  outcome public.retention_disposition_outcome not null,
  policy_set_id text not null,
  policy_version integer not null,
  evidence_ref text not null check (char_length(evidence_ref) between 3 and 500),
  reason_codes text[] not null default '{}',
  attempted_at timestamptz not null default now(),
  unique (retention_disposition_item_id, attempt_number)
);

create index retention_disposition_items_work_idx
  on public.retention_disposition_items (status, eligible_at, tenant_id, agency_id);
create index retention_disposition_attempts_item_idx
  on public.retention_disposition_attempts (retention_disposition_item_id, attempted_at);

alter table public.retention_disposition_runs enable row level security;
alter table public.retention_disposition_items enable row level security;
alter table public.retention_disposition_attempts enable row level security;

create policy retention_disposition_items_admin_select
on public.retention_disposition_items for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
  or private.has_permission(tenant_id, agency_id, 'POLICY_ADMIN')
);
create policy retention_disposition_attempts_admin_select
on public.retention_disposition_attempts for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
  or private.has_permission(tenant_id, agency_id, 'POLICY_ADMIN')
);

revoke all on public.retention_disposition_runs,
  public.retention_disposition_items,
  public.retention_disposition_attempts from anon, authenticated;
grant select on public.retention_disposition_items,
  public.retention_disposition_attempts to authenticated;

create or replace function private.prevent_retention_attempt_mutation()
returns trigger language plpgsql security definer set search_path = public, private as $$
begin
  raise exception using errcode = '22023', message = 'RETENTION_ATTEMPT_IMMUTABLE';
  return null;
end
$$;
revoke all on function private.prevent_retention_attempt_mutation() from public;
create trigger retention_disposition_attempt_immutable
before update or delete on public.retention_disposition_attempts
for each row execute function private.prevent_retention_attempt_mutation();

create or replace function private.retention_run_summary(p_run_id uuid)
returns jsonb language sql stable security definer set search_path = public, private as $$
  select coalesce(jsonb_object_agg(summary.status, summary.item_count), '{}'::jsonb)
  from (
    select item.status::text as status, count(*)::integer as item_count
    from public.retention_disposition_items item
    where item.current_run_id = p_run_id
    group by item.status
  ) summary
$$;
revoke all on function private.retention_run_summary(uuid) from public;

create or replace function private.has_retention_hold_signal(
  p_tenant_id uuid, p_agency_id uuid, p_person_id uuid
)
returns boolean language sql stable security definer set search_path = public, private as $$
  select exists (
    select 1
    from public.quote_cases quote_case
    join public.prospects prospect on prospect.prospect_id = quote_case.prospect_id
    where quote_case.tenant_id = p_tenant_id
      and quote_case.agency_id = p_agency_id
      and prospect.person_id = p_person_id
      and quote_case.state = 'RETENTION_HOLD'
  )
$$;
revoke all on function private.has_retention_hold_signal(uuid, uuid, uuid) from public;

create or replace function private.prepare_retention_disposition_run_impl(
  p_idempotency_key uuid,
  p_as_of timestamptz,
  p_limit integer,
  p_expected_certification_state public.retention_policy_certification_state
)
returns table (
  retention_disposition_run_id uuid,
  run_status public.retention_run_status,
  status_summary jsonb
)
language plpgsql security definer set search_path = public, private, extensions as $$
declare
  v_run public.retention_disposition_runs;
  v_action record;
  v_configuration public.tenant_configurations;
  v_policy public.retention_policies;
  v_status public.retention_item_status;
  v_reasons text[];
  v_integrity_hash text;
begin
  if p_idempotency_key is null or p_as_of is null or p_limit not between 1 and 500
     or p_expected_certification_state not in ('SYNTHETIC', 'APPROVED') then
    raise exception using errcode = '22023', message = 'RETENTION_RUN_INPUT_INVALID';
  end if;
  select run.* into v_run from public.retention_disposition_runs run
  where run.idempotency_key = p_idempotency_key for update;
  if found then
    if v_run.as_of <> p_as_of
       or v_run.expected_certification_state <> p_expected_certification_state then
      raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUEST_MISMATCH';
    end if;
    return query select v_run.retention_disposition_run_id, v_run.status,
      v_run.status_summary;
    return;
  end if;
  insert into public.retention_disposition_runs (
    idempotency_key, expected_certification_state, as_of
  ) values (p_idempotency_key, p_expected_certification_state, p_as_of)
  returning * into v_run;

  for v_action in
    select action.*, request.matched_person_id, request.jurisdiction,
      request.public_reference, request.received_at
    from public.privacy_rights_actions action
    join public.privacy_requests request
      on request.privacy_request_id = action.privacy_request_id
    where action.disposition = 'DELETE_QUEUED'
      and request.request_type = 'DELETION'
      and request.state = 'IN_PROGRESS'
      and not exists (
        select 1 from public.retention_disposition_items item
        where item.privacy_rights_action_id = action.privacy_rights_action_id
          and item.status in ('COMPLETED', 'REVIEW_REQUIRED')
      )
    order by action.created_at, action.privacy_rights_action_id
    limit p_limit
    for update of request skip locked
  loop
    v_configuration := null;
    v_policy := null;
    v_reasons := '{}';
    select configuration.* into v_configuration
    from public.tenant_configurations configuration
    where configuration.tenant_id = v_action.tenant_id
      and configuration.agency_id = v_action.agency_id
      and configuration.status = 'ACTIVE'
      and configuration.effective_at <= p_as_of
      and (configuration.retired_at is null or configuration.retired_at > p_as_of)
    order by configuration.version desc limit 1;
    if not found or v_configuration.retention_policy_set_id is null then
      v_status := 'BLOCKED';
      v_reasons := array['RETENTION_POLICY_SET_NOT_CONFIGURED'];
    else
      select policy.* into v_policy from public.retention_policies policy
      where policy.tenant_id = v_action.tenant_id
        and policy.agency_id = v_action.agency_id
        and policy.policy_set_id = v_configuration.retention_policy_set_id
        and policy.data_class = v_action.data_category
        and policy.jurisdiction = v_action.jurisdiction
        and policy.certification_state = p_expected_certification_state
        and policy.effective_at <= p_as_of
        and (policy.retired_at is null or policy.retired_at > p_as_of)
      order by policy.version desc limit 1;
      if not found then
        v_status := 'BLOCKED';
        v_reasons := array['RETENTION_POLICY_NOT_CONFIGURED'];
      elsif v_policy.retention_interval is null then
        v_status := 'BLOCKED';
        v_reasons := array['RETENTION_INTERVAL_NOT_APPROVED'];
      elsif private.has_retention_hold_signal(
        v_action.tenant_id, v_action.agency_id, v_action.matched_person_id
      ) then
        v_status := 'BLOCKED';
        v_reasons := array['LEGAL_HOLD_SIGNAL'];
      else
        v_status := 'SCHEDULED';
        v_reasons := case
          when v_action.created_at + v_policy.retention_interval > p_as_of
          then array['RETENTION_INTERVAL_ACTIVE'] else '{}'::text[] end;
      end if;
    end if;
    insert into public.retention_disposition_items (
      current_run_id, privacy_rights_action_id, privacy_request_id,
      tenant_id, agency_id, data_class, retention_policy_id, policy_set_id,
      policy_version, disposition, eligible_at, status, reason_codes
    ) values (
      v_run.retention_disposition_run_id, v_action.privacy_rights_action_id,
      v_action.privacy_request_id, v_action.tenant_id, v_action.agency_id,
      v_action.data_category, v_policy.retention_policy_id, v_policy.policy_set_id,
      v_policy.version, v_policy.disposition,
      case when v_policy.retention_policy_id is null then null
        else v_action.created_at + v_policy.retention_interval end,
      v_status, v_reasons
    ) on conflict (privacy_rights_action_id) do update set
      current_run_id = excluded.current_run_id,
      retention_policy_id = excluded.retention_policy_id,
      policy_set_id = excluded.policy_set_id,
      policy_version = excluded.policy_version,
      disposition = excluded.disposition,
      eligible_at = excluded.eligible_at,
      status = excluded.status,
      reason_codes = excluded.reason_codes,
      updated_at = now()
    where public.retention_disposition_items.attempt_count = 0
      and public.retention_disposition_items.status in ('SCHEDULED', 'BLOCKED');
  end loop;
  update public.retention_disposition_runs run set
    status = case when exists (
      select 1 from public.retention_disposition_items item
      where item.current_run_id = v_run.retention_disposition_run_id
        and item.status = 'SCHEDULED'
    ) then 'IN_PROGRESS'::public.retention_run_status
      when exists (
        select 1 from public.retention_disposition_items item
        where item.current_run_id = v_run.retention_disposition_run_id
      ) then 'ATTENTION_REQUIRED'::public.retention_run_status
      else 'COMPLETED'::public.retention_run_status end,
    status_summary = private.retention_run_summary(v_run.retention_disposition_run_id),
    completed_at = case when not exists (
      select 1 from public.retention_disposition_items item
      where item.current_run_id = v_run.retention_disposition_run_id
    ) then now() else null end
  where run.retention_disposition_run_id = v_run.retention_disposition_run_id
  returning * into v_run;
  v_integrity_hash := encode(digest(concat_ws('|', v_run.retention_disposition_run_id::text,
    p_as_of::text, v_run.status_summary::text, clock_timestamp()::text), 'sha256'), 'hex');
  insert into public.audit_events (
    tenant_id, agency_id, event_type, subject_ref, outcome,
    reason_codes, integrity_hash, metadata
  )
  select item.tenant_id, item.agency_id, 'RETENTION_DISPOSITION_SCHEDULED',
    'retention-run:' || v_run.retention_disposition_run_id::text,
    v_run.status::text, '{}', v_integrity_hash,
    jsonb_build_object('run_id', v_run.retention_disposition_run_id,
      'status_summary', v_run.status_summary)
  from public.retention_disposition_items item
  where item.current_run_id = v_run.retention_disposition_run_id
  group by item.tenant_id, item.agency_id;
  return query select v_run.retention_disposition_run_id, v_run.status,
    v_run.status_summary;
end
$$;
revoke all on function private.prepare_retention_disposition_run_impl(
  uuid, timestamptz, integer, public.retention_policy_certification_state
) from public;
grant execute on function private.prepare_retention_disposition_run_impl(
  uuid, timestamptz, integer, public.retention_policy_certification_state
) to service_role;

create or replace function public.prepare_retention_disposition_run(
  p_idempotency_key uuid,
  p_as_of timestamptz,
  p_limit integer,
  p_expected_certification_state public.retention_policy_certification_state
)
returns table (
  retention_disposition_run_id uuid,
  run_status public.retention_run_status,
  status_summary jsonb
)
language sql security invoker set search_path = public, private as $$
  select * from private.prepare_retention_disposition_run_impl(
    p_idempotency_key, p_as_of, p_limit, p_expected_certification_state
  )
$$;
revoke all on function public.prepare_retention_disposition_run(
  uuid, timestamptz, integer, public.retention_policy_certification_state
) from public, anon, authenticated;
grant execute on function public.prepare_retention_disposition_run(
  uuid, timestamptz, integer, public.retention_policy_certification_state
) to service_role;

create or replace function private.execute_retention_disposition_run_impl(
  p_run_id uuid,
  p_limit integer
)
returns table (
  retention_disposition_run_id uuid,
  run_status public.retention_run_status,
  status_summary jsonb
)
language plpgsql security definer set search_path = public, private, extensions as $$
declare
  v_run public.retention_disposition_runs;
  v_item public.retention_disposition_items;
  v_policy public.retention_policies;
  v_request public.privacy_requests;
  v_record_count integer;
  v_affected integer;
  v_outcome public.retention_disposition_outcome;
  v_evidence_ref text;
  v_reasons text[];
  v_hash text;
  v_policy_found boolean;
begin
  if p_run_id is null or p_limit not between 1 and 500 then
    raise exception using errcode = '22023', message = 'RETENTION_EXECUTION_INPUT_INVALID';
  end if;
  select run.* into v_run from public.retention_disposition_runs run
  where run.retention_disposition_run_id = p_run_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'RETENTION_RUN_NOT_FOUND';
  end if;
  for v_item in
    select item.* from public.retention_disposition_items item
    where item.current_run_id = p_run_id and item.status = 'SCHEDULED'
      and item.eligible_at <= v_run.as_of
    order by item.eligible_at, item.retention_disposition_item_id
    limit p_limit for update skip locked
  loop
    select policy.* into v_policy from public.retention_policies policy
    where policy.retention_policy_id = v_item.retention_policy_id;
    v_policy_found := found;
    select request.* into v_request from public.privacy_requests request
    where request.privacy_request_id = v_item.privacy_request_id for update;
    v_reasons := '{}';
    v_record_count := 0;
    if not v_policy_found or v_policy.certification_state <> v_run.expected_certification_state
       or v_policy.policy_set_id <> v_item.policy_set_id
       or v_policy.version <> v_item.policy_version
       or v_policy.retired_at is not null and v_policy.retired_at <= v_run.as_of then
      update public.retention_disposition_items item set status = 'BLOCKED',
        reason_codes = array['RETENTION_POLICY_INVALID'], updated_at = now()
      where item.retention_disposition_item_id = v_item.retention_disposition_item_id;
      continue;
    end if;
    if private.has_retention_hold_signal(
      v_item.tenant_id, v_item.agency_id, v_request.matched_person_id
    ) then
      update public.retention_disposition_items item set status = 'BLOCKED',
        reason_codes = array['LEGAL_HOLD_SIGNAL'], updated_at = now()
      where item.retention_disposition_item_id = v_item.retention_disposition_item_id;
      continue;
    end if;
    if v_policy.disposition = 'REVIEW' then
      v_outcome := 'REVIEW_REQUIRED';
      v_reasons := array['HUMAN_REVIEW_REQUIRED'];
    elsif v_item.data_class = 'IDENTITY_PROFILE' then
      update public.person_private_profiles profile set
        encrypted_payload = decode(repeat('00', 30), 'hex'),
        key_version = 'DESTROYED:' || left(v_policy.retention_policy_id::text, 32),
        email_lookup_hash = null, phone_lookup_hash = null,
        payload_version = profile.payload_version + 1, updated_at = now()
      where profile.tenant_id = v_item.tenant_id
        and profile.agency_id = v_item.agency_id
        and profile.person_id = v_request.matched_person_id;
      get diagnostics v_record_count = row_count;
      v_outcome := case when v_policy.disposition = 'DELETE'
        then 'DELETED'::public.retention_disposition_outcome
        else 'ANONYMIZED'::public.retention_disposition_outcome end;
      v_reasons := array['IDENTITY_KEY_MATERIAL_DESTROYED'];
    elsif v_item.data_class = 'CONSUMER_INPUT' and v_policy.disposition = 'ANONYMIZE' then
      update public.drivers driver set
        first_name = 'REDACTED', last_name = 'REDACTED', date_of_birth = date '1900-01-01',
        license_identifier_ciphertext = null, license_identifier_key_version = null,
        license_identifier_lookup_hash = null, license_last4 = null,
        source_ref = null, updated_at = now()
      where driver.tenant_id = v_item.tenant_id and driver.agency_id = v_item.agency_id
        and driver.person_id = v_request.matched_person_id;
      get diagnostics v_record_count = row_count;
      update public.vehicles vehicle set vin_ciphertext = null, vin_key_version = null,
        vin_lookup_hash = null, vin_last4 = null, garaging_postal_code = null,
        source_ref = null, updated_at = now()
      where vehicle.tenant_id = v_item.tenant_id and vehicle.agency_id = v_item.agency_id
        and exists (
          select 1 from public.quote_cases quote_case
          join public.prospects prospect on prospect.prospect_id = quote_case.prospect_id
          where quote_case.quote_case_id = vehicle.quote_case_id
            and prospect.person_id = v_request.matched_person_id
        );
      get diagnostics v_affected = row_count;
      v_record_count := v_record_count + v_affected;
      update public.coverage_requests coverage set notes = null, updated_at = now()
      where coverage.tenant_id = v_item.tenant_id and coverage.agency_id = v_item.agency_id
        and exists (
          select 1 from public.quote_cases quote_case
          join public.prospects prospect on prospect.prospect_id = quote_case.prospect_id
          where quote_case.quote_case_id = coverage.quote_case_id
            and prospect.person_id = v_request.matched_person_id
        );
      get diagnostics v_affected = row_count;
      v_record_count := v_record_count + v_affected;
      v_outcome := 'ANONYMIZED';
      v_reasons := array['CONSUMER_IDENTIFIERS_ANONYMIZED'];
    else
      v_outcome := 'FAILED';
      v_reasons := array['UNSAFE_OR_UNSUPPORTED_DISPOSITION'];
    end if;
    v_evidence_ref := 'retention:' || encode(digest(concat_ws('|',
      v_item.retention_disposition_item_id::text, v_item.attempt_count + 1,
      v_outcome::text, v_policy.retention_policy_id::text, clock_timestamp()::text
    ), 'sha256'), 'hex');
    v_hash := encode(hmac(concat_ws('|', v_item.retention_disposition_item_id::text,
      v_item.current_run_id::text, v_policy.policy_set_id, v_policy.version::text,
      v_policy.disposition::text), v_item.tenant_id::text, 'sha256'), 'hex');
    insert into public.retention_disposition_attempts (
      retention_disposition_item_id, retention_disposition_run_id,
      privacy_request_id, tenant_id, agency_id, attempt_number, request_hash,
      outcome, policy_set_id, policy_version, evidence_ref, reason_codes
    ) values (
      v_item.retention_disposition_item_id, p_run_id, v_item.privacy_request_id,
      v_item.tenant_id, v_item.agency_id, v_item.attempt_count + 1, v_hash,
      v_outcome, v_policy.policy_set_id, v_policy.version, v_evidence_ref, v_reasons
    );
    update public.retention_disposition_items item set
      status = case v_outcome
        when 'REVIEW_REQUIRED' then 'REVIEW_REQUIRED'::public.retention_item_status
        when 'FAILED' then 'FAILED'::public.retention_item_status
        else 'COMPLETED'::public.retention_item_status end,
      attempt_count = item.attempt_count + 1, evidence_ref = v_evidence_ref,
      reason_codes = v_reasons, updated_at = now(),
      completed_at = case when v_outcome in ('DELETED', 'ANONYMIZED') then now() else null end
    where item.retention_disposition_item_id = v_item.retention_disposition_item_id;
    insert into public.audit_events (
      tenant_id, agency_id, event_type, subject_ref, policy_version_refs,
      outcome, reason_codes, integrity_hash, metadata
    ) values (
      v_item.tenant_id, v_item.agency_id, 'RETENTION_DISPOSITION_ATTEMPTED',
      'privacy-request:' || v_request.public_reference::text,
      array[v_policy.policy_set_id || ':' || v_policy.version::text],
      v_outcome::text, v_reasons, encode(digest(v_evidence_ref, 'sha256'), 'hex'),
      jsonb_build_object('retention_item_id', v_item.retention_disposition_item_id,
        'data_class', v_item.data_class, 'record_count', v_record_count,
        'evidence_ref', v_evidence_ref)
    );
  end loop;

  for v_request in
    update public.privacy_requests request set state = 'COMPLETED',
      completed_at = coalesce(request.completed_at, now()), updated_at = now(),
      applicability_reason_codes = array['DELETION_DISPOSITION_COMPLETED']
    where request.request_type = 'DELETION' and request.state = 'IN_PROGRESS'
      and exists (
        select 1 from public.retention_disposition_items item
        where item.privacy_request_id = request.privacy_request_id
          and item.current_run_id = p_run_id
      )
      and not exists (
        select 1 from public.privacy_rights_actions action
        where action.privacy_request_id = request.privacy_request_id
          and action.disposition = 'DELETE_QUEUED'
          and not exists (
            select 1 from public.retention_disposition_items item
            where item.privacy_rights_action_id = action.privacy_rights_action_id
              and item.status = 'COMPLETED'
          )
      )
      and not exists (
        select 1 from public.privacy_rights_actions action
        where action.privacy_request_id = request.privacy_request_id
          and action.disposition = 'PROPAGATION_PENDING'
          and not exists (
            select 1 from public.privacy_vendor_propagations target
            where target.privacy_request_id = request.privacy_request_id
          )
      )
      and not exists (
        select 1 from public.privacy_vendor_propagations target
        where target.privacy_request_id = request.privacy_request_id
          and target.status <> 'COMPLETED'
      )
    returning request.*
  loop
    insert into public.audit_events (
      tenant_id, agency_id, event_type, subject_ref, outcome,
      reason_codes, integrity_hash, metadata
    ) values (
      v_request.tenant_id, v_request.agency_id,
      'RETENTION_DISPOSITION_COMPLETED',
      'privacy-request:' || v_request.public_reference::text,
      'COMPLETED', array['DELETION_DISPOSITION_COMPLETED'],
      encode(digest(concat_ws('|', v_request.privacy_request_id::text,
        p_run_id::text, clock_timestamp()::text), 'sha256'), 'hex'),
      jsonb_build_object('retention_run_id', p_run_id)
    );
  end loop;

  update public.retention_disposition_runs run set
    status_summary = private.retention_run_summary(p_run_id),
    status = case
      when exists (select 1 from public.retention_disposition_items item
        where item.current_run_id = p_run_id
          and item.status in ('BLOCKED', 'FAILED', 'REVIEW_REQUIRED'))
        then 'ATTENTION_REQUIRED'::public.retention_run_status
      when exists (select 1 from public.retention_disposition_items item
        where item.current_run_id = p_run_id and item.status = 'SCHEDULED')
        then 'IN_PROGRESS'::public.retention_run_status
      else 'COMPLETED'::public.retention_run_status end,
    completed_at = case
      when not exists (select 1 from public.retention_disposition_items item
        where item.current_run_id = p_run_id
          and item.status <> 'COMPLETED') then now() else null end
  where run.retention_disposition_run_id = p_run_id returning * into v_run;
  return query select v_run.retention_disposition_run_id, v_run.status,
    v_run.status_summary;
end
$$;
revoke all on function private.execute_retention_disposition_run_impl(uuid, integer) from public;
grant execute on function private.execute_retention_disposition_run_impl(uuid, integer)
  to service_role;

create or replace function public.execute_retention_disposition_run(
  p_run_id uuid, p_limit integer
)
returns table (
  retention_disposition_run_id uuid,
  run_status public.retention_run_status,
  status_summary jsonb
)
language sql security invoker set search_path = public, private as $$
  select * from private.execute_retention_disposition_run_impl(p_run_id, p_limit)
$$;
revoke all on function public.execute_retention_disposition_run(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.execute_retention_disposition_run(uuid, integer)
  to service_role;
