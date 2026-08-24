-- T803: correction, deletion, restriction, and opt-out execution workflow.
-- Destructive deletion is represented as disposition work for T805 so this
-- boundary cannot silently bypass retention, legal-hold, or evidence duties.

create type public.privacy_rights_execution_status as enum ('PREPARED', 'COMPLETED');
create type public.privacy_rights_execution_outcome as enum (
  'APPLIED', 'PARTIALLY_APPLIED', 'NO_RECORDS'
);
create type public.privacy_rights_action_disposition as enum (
  'CORRECTED', 'RESTRICTED', 'DELETE_QUEUED', 'EXEMPT',
  'PROPAGATION_PENDING', 'NO_RECORDS'
);
create type public.privacy_restriction_scope as enum (
  'ALL_PROCESSING', 'SALE_SHARING', 'TARGETED_MARKETING'
);

create table public.privacy_rights_executions (
  privacy_rights_execution_id uuid primary key default gen_random_uuid(),
  privacy_request_id uuid not null,
  tenant_id uuid not null,
  agency_id uuid not null,
  idempotency_key uuid not null,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  policy_version text not null check (policy_version ~ '^[A-Za-z0-9_.:-]{3,100}$'),
  status public.privacy_rights_execution_status not null default 'PREPARED',
  outcome public.privacy_rights_execution_outcome,
  correction_fields text[] not null default '{}',
  action_summary jsonb not null default '{}'::jsonb,
  prepared_at timestamptz not null default now(),
  completed_at timestamptz,
  foreign key (tenant_id, agency_id, privacy_request_id)
    references public.privacy_requests(tenant_id, agency_id, privacy_request_id),
  unique (privacy_request_id, idempotency_key),
  unique (privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id),
  check ((status = 'COMPLETED') = (outcome is not null and completed_at is not null))
);

create table public.privacy_rights_actions (
  privacy_rights_action_id uuid primary key default gen_random_uuid(),
  privacy_rights_execution_id uuid not null,
  privacy_request_id uuid not null,
  tenant_id uuid not null,
  agency_id uuid not null,
  data_category text not null check (data_category ~ '^[A-Z][A-Z0-9_]{2,99}$'),
  disposition public.privacy_rights_action_disposition not null,
  record_count integer not null default 0 check (record_count >= 0),
  reason_codes text[] not null default '{}',
  created_at timestamptz not null default now(),
  foreign key (privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id)
    references public.privacy_rights_executions(
      privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id
    ),
  unique (privacy_rights_execution_id, data_category, disposition)
);

create table public.privacy_processing_restrictions (
  privacy_processing_restriction_id uuid primary key default gen_random_uuid(),
  privacy_request_id uuid not null,
  tenant_id uuid not null,
  agency_id uuid not null,
  person_id uuid not null,
  scope public.privacy_restriction_scope not null,
  policy_version text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  foreign key (tenant_id, agency_id, privacy_request_id)
    references public.privacy_requests(tenant_id, agency_id, privacy_request_id),
  foreign key (tenant_id, agency_id, person_id)
    references public.people(tenant_id, agency_id, person_id),
  unique (privacy_request_id, scope),
  check ((active and revoked_at is null) or (not active and revoked_at is not null))
);

create index privacy_rights_executions_request_idx
  on public.privacy_rights_executions (tenant_id, agency_id, privacy_request_id, prepared_at);
create index privacy_processing_restrictions_active_idx
  on public.privacy_processing_restrictions (tenant_id, agency_id, person_id, scope)
  where active;

alter table public.privacy_rights_executions enable row level security;
alter table public.privacy_rights_actions enable row level security;
alter table public.privacy_processing_restrictions enable row level security;

create policy privacy_rights_executions_admin_select
on public.privacy_rights_executions for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
);
create policy privacy_rights_actions_admin_select
on public.privacy_rights_actions for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
);
create policy privacy_processing_restrictions_admin_select
on public.privacy_processing_restrictions for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
);

revoke all on public.privacy_rights_executions,
  public.privacy_rights_actions,
  public.privacy_processing_restrictions from anon, authenticated;
grant select on public.privacy_rights_executions,
  public.privacy_rights_actions,
  public.privacy_processing_restrictions to authenticated;

create or replace function private.enforce_privacy_processing_restriction()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_person_id uuid;
  v_subject_ids uuid[] := '{}';
begin
  if tg_table_name = 'external_requests' then
    v_subject_ids := new.subject_ids;
  end if;
  select p.person_id into v_person_id
  from public.quote_cases qc
  join public.prospects p on p.prospect_id = qc.prospect_id
  where qc.tenant_id = new.tenant_id and qc.agency_id = new.agency_id
    and qc.quote_case_id = new.quote_case_id;
  if exists (
    select 1 from public.privacy_processing_restrictions ppr
    where ppr.tenant_id = new.tenant_id and ppr.agency_id = new.agency_id
      and ppr.active and ppr.scope = 'ALL_PROCESSING'
      and (ppr.person_id = v_person_id or ppr.person_id = any(v_subject_ids))
  ) then
    raise exception using errcode = '55000', message = 'RETENTION_RESTRICTION';
  end if;
  return new;
end
$$;
revoke all on function private.enforce_privacy_processing_restriction() from public;
create trigger privacy_restriction_external_requests
before insert or update of status on public.external_requests
for each row execute function private.enforce_privacy_processing_restriction();
create trigger privacy_restriction_carrier_submissions
before insert or update of status on public.carrier_submissions
for each row execute function private.enforce_privacy_processing_restriction();

create or replace function private.prevent_completed_privacy_execution_mutation()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if old.status = 'COMPLETED' then
    raise exception using errcode = '22023', message = 'PRIVACY_RIGHTS_EXECUTION_IMMUTABLE';
  end if;
  return new;
end
$$;
revoke all on function private.prevent_completed_privacy_execution_mutation() from public;
create trigger privacy_rights_execution_completed_immutable
before update or delete on public.privacy_rights_executions
for each row execute function private.prevent_completed_privacy_execution_mutation();

create or replace function private.prevent_privacy_rights_action_mutation()
returns trigger language plpgsql security definer set search_path = public, private as $$
begin
  raise exception using errcode = '22023', message = 'PRIVACY_RIGHTS_ACTION_IMMUTABLE';
  return null;
end
$$;
revoke all on function private.prevent_privacy_rights_action_mutation() from public;
create trigger privacy_rights_action_immutable
before update or delete on public.privacy_rights_actions
for each row execute function private.prevent_privacy_rights_action_mutation();

create or replace function private.prepare_privacy_rights_execution_impl(
  p_hostname text,
  p_public_reference uuid,
  p_status_token_hash text,
  p_idempotency_key uuid,
  p_request_hash text,
  p_policy_version text,
  p_correction_fields text[]
)
returns table (
  privacy_rights_execution_id uuid,
  execution_status public.privacy_rights_execution_status,
  request_type public.privacy_request_type,
  public_reference uuid,
  state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state,
  encrypted_profile_hex text,
  profile_key_version text,
  execution_outcome public.privacy_rights_execution_outcome,
  action_summary jsonb
)
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_host public.tenant_hosts;
  v_request public.privacy_requests;
  v_discovery public.privacy_discovery_runs;
  v_existing public.privacy_rights_executions;
  v_execution public.privacy_rights_executions;
  v_profile public.person_private_profiles;
  v_fields text[] := coalesce(p_correction_fields, '{}');
  v_integrity_hash text;
begin
  if p_public_reference is null or p_idempotency_key is null
     or p_status_token_hash is null or p_status_token_hash !~ '^[0-9a-f]{64}$'
     or p_request_hash is null or p_request_hash !~ '^[0-9a-f]{64}$'
     or p_policy_version is null or p_policy_version !~ '^[A-Za-z0-9_.:-]{3,100}$'
     or exists (select 1 from unnest(v_fields) f
       where f not in ('firstName', 'lastName', 'email', 'phone', 'address')) then
    raise exception using errcode = '22023', message = 'PRIVACY_RIGHTS_EXECUTION_INPUT_INVALID';
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

  select * into v_existing from public.privacy_rights_executions
  where privacy_request_id = v_request.privacy_request_id
    and idempotency_key = p_idempotency_key;
  if found then
    if v_existing.request_hash <> p_request_hash
       or v_existing.policy_version <> p_policy_version
       or v_existing.correction_fields <> v_fields then
      raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUEST_MISMATCH';
    end if;
    if v_existing.status = 'PREPARED' and v_request.request_type = 'CORRECTION' then
      select * into v_profile from public.person_private_profiles
      where tenant_id = v_existing.tenant_id and agency_id = v_existing.agency_id
        and person_id = v_request.matched_person_id;
    end if;
    return query select v_existing.privacy_rights_execution_id, v_existing.status,
      v_request.request_type, v_request.public_reference, v_request.state,
      v_request.identity_verification_state,
      case when v_profile.person_id is null then null else encode(v_profile.encrypted_payload, 'hex') end,
      v_profile.key_version, v_existing.outcome, v_existing.action_summary;
    return;
  end if;

  if v_request.request_type not in ('CORRECTION', 'DELETION', 'RESTRICTION', 'OPT_OUT')
     or v_request.identity_verification_state <> 'VERIFIED'
     or v_request.state <> 'APPLICABILITY_REVIEW' then
    raise exception using errcode = '55000', message = 'PRIVACY_RIGHTS_EXECUTION_STATE_INVALID';
  end if;
  if (v_request.request_type = 'CORRECTION') <> (cardinality(v_fields) > 0) then
    raise exception using errcode = '22023', message = 'PRIVACY_CORRECTION_FIELDS_INVALID';
  end if;

  select * into v_discovery from public.privacy_discovery_runs
  where privacy_request_id = v_request.privacy_request_id and status = 'COMPLETED'
  order by completed_at desc limit 1;
  if not found or v_discovery.outcome = 'AMBIGUOUS' then
    raise exception using errcode = '55000', message = 'PRIVACY_RIGHTS_DISCOVERY_INVALID';
  end if;
  if v_discovery.outcome = 'MATCHED' then
    select * into v_profile from public.person_private_profiles
    where tenant_id = v_request.tenant_id and agency_id = v_request.agency_id
      and person_id = v_request.matched_person_id;
    if not found then
      raise exception using errcode = '55000', message = 'PRIVACY_RIGHTS_PROFILE_INVALID';
    end if;
  end if;

  insert into public.privacy_rights_executions (
    privacy_request_id, tenant_id, agency_id, idempotency_key,
    request_hash, policy_version, correction_fields
  ) values (
    v_request.privacy_request_id, v_request.tenant_id, v_request.agency_id,
    p_idempotency_key, p_request_hash, p_policy_version, v_fields
  ) returning * into v_execution;
  update public.privacy_requests set state = 'IN_PROGRESS', updated_at = now(),
    policy_version_refs = case when p_policy_version = any(policy_version_refs)
      then policy_version_refs else array_append(policy_version_refs, p_policy_version) end
  where privacy_request_id = v_request.privacy_request_id returning * into v_request;

  v_integrity_hash := encode(digest(concat_ws('|', v_request.tenant_id::text,
    v_execution.privacy_rights_execution_id::text, v_request.request_type::text,
    p_policy_version, clock_timestamp()::text), 'sha256'), 'hex');
  insert into public.audit_events (
    tenant_id, agency_id, event_type, subject_ref, configuration_version_ref,
    policy_version_refs, outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_request.tenant_id, v_request.agency_id, 'PRIVACY_RIGHTS_EXECUTION_PREPARED',
    'privacy-request:' || v_request.public_reference::text,
    v_host.tenant_configuration_version::text, array[p_policy_version], 'PREPARED',
    array[v_request.request_type::text], v_integrity_hash,
    jsonb_build_object('execution_id', v_execution.privacy_rights_execution_id,
      'correction_fields', v_fields)
  );

  return query select v_execution.privacy_rights_execution_id, v_execution.status,
    v_request.request_type, v_request.public_reference, v_request.state,
    v_request.identity_verification_state,
    case when v_profile.person_id is null or v_request.request_type <> 'CORRECTION'
      then null else encode(v_profile.encrypted_payload, 'hex') end,
    case when v_request.request_type = 'CORRECTION' then v_profile.key_version else null end,
    v_execution.outcome, v_execution.action_summary;
end
$$;

revoke all on function private.prepare_privacy_rights_execution_impl(
  text, uuid, text, uuid, text, text, text[]
) from public;
grant execute on function private.prepare_privacy_rights_execution_impl(
  text, uuid, text, uuid, text, text, text[]
) to service_role;

create or replace function public.prepare_privacy_rights_execution(
  p_hostname text, p_public_reference uuid, p_status_token_hash text,
  p_idempotency_key uuid, p_request_hash text, p_policy_version text,
  p_correction_fields text[]
)
returns table (
  privacy_rights_execution_id uuid,
  execution_status public.privacy_rights_execution_status,
  request_type public.privacy_request_type,
  public_reference uuid, state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state,
  encrypted_profile_hex text, profile_key_version text,
  execution_outcome public.privacy_rights_execution_outcome,
  action_summary jsonb
)
language sql security invoker set search_path = public, private as $$
  select * from private.prepare_privacy_rights_execution_impl(
    p_hostname, p_public_reference, p_status_token_hash, p_idempotency_key,
    p_request_hash, p_policy_version, p_correction_fields
  )
$$;
revoke all on function public.prepare_privacy_rights_execution(
  text, uuid, text, uuid, text, text, text[]
) from public, anon, authenticated;
grant execute on function public.prepare_privacy_rights_execution(
  text, uuid, text, uuid, text, text, text[]
) to service_role;

create or replace function private.settle_privacy_rights_execution_impl(
  p_privacy_rights_execution_id uuid,
  p_encrypted_profile bytea,
  p_profile_key_version text,
  p_email_lookup_hash text,
  p_phone_lookup_hash text
)
returns table (
  public_reference uuid, state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state,
  execution_outcome public.privacy_rights_execution_outcome,
  action_summary jsonb
)
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_execution public.privacy_rights_executions;
  v_request public.privacy_requests;
  v_profile_count integer := 0;
  v_consumer_count integer := 0;
  v_external_count integer := 0;
  v_external_report_count integer := 0;
  v_audit_count integer := 0;
  v_outcome public.privacy_rights_execution_outcome;
  v_summary jsonb;
  v_final_state public.privacy_request_state;
  v_integrity_hash text;
begin
  select * into v_execution from public.privacy_rights_executions
  where privacy_rights_execution_id = p_privacy_rights_execution_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'PRIVACY_RIGHTS_EXECUTION_NOT_FOUND';
  end if;
  select * into v_request from public.privacy_requests
  where privacy_request_id = v_execution.privacy_request_id for update;
  if v_execution.status = 'COMPLETED' then
    return query select v_request.public_reference, v_request.state,
      v_request.identity_verification_state, v_execution.outcome,
      v_execution.action_summary;
    return;
  end if;

  if v_request.matched_person_id is null then
    if p_encrypted_profile is not null or p_profile_key_version is not null
       or p_email_lookup_hash is not null or p_phone_lookup_hash is not null then
      raise exception using errcode = '22023', message = 'PRIVACY_CORRECTION_NOT_APPLICABLE';
    end if;
    insert into public.privacy_rights_actions (
      privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id,
      data_category, disposition, reason_codes
    ) values (
      v_execution.privacy_rights_execution_id, v_request.privacy_request_id,
      v_request.tenant_id, v_request.agency_id, 'REQUEST', 'NO_RECORDS',
      array['NO_RECORD_MATCH']
    );
    v_outcome := 'NO_RECORDS';
    v_final_state := 'COMPLETED';
    v_summary := jsonb_build_object('NO_RECORDS', 0);
  else
    select count(*)::integer into v_profile_count from public.person_private_profiles
      where tenant_id = v_request.tenant_id and agency_id = v_request.agency_id
        and person_id = v_request.matched_person_id;
    select (
      (select count(*) from public.quote_cases qc join public.prospects p on p.prospect_id = qc.prospect_id
        where qc.tenant_id = v_request.tenant_id and qc.agency_id = v_request.agency_id
          and p.person_id = v_request.matched_person_id)
      + (select count(*) from public.drivers where tenant_id = v_request.tenant_id
          and agency_id = v_request.agency_id and person_id = v_request.matched_person_id)
    )::integer into v_consumer_count;
    select count(*)::integer into v_external_count
      from public.external_requests er join public.quote_cases qc on qc.quote_case_id = er.quote_case_id
      join public.prospects p on p.prospect_id = qc.prospect_id
      where er.tenant_id = v_request.tenant_id and er.agency_id = v_request.agency_id
        and p.person_id = v_request.matched_person_id;
    select count(*)::integer into v_external_report_count
      from public.external_reports er join public.quote_cases qc on qc.quote_case_id = er.quote_case_id
      join public.prospects p on p.prospect_id = qc.prospect_id
      where er.tenant_id = v_request.tenant_id and er.agency_id = v_request.agency_id
        and p.person_id = v_request.matched_person_id;
    select count(*)::integer into v_audit_count from public.audit_events
      where tenant_id = v_request.tenant_id and agency_id = v_request.agency_id
        and subject_ref = 'privacy-request:' || v_request.public_reference::text;

    if v_request.request_type = 'CORRECTION' then
      if p_encrypted_profile is null or octet_length(p_encrypted_profile) not between 30 and 65536
         or p_profile_key_version is null or char_length(p_profile_key_version) not between 1 and 64
         or p_email_lookup_hash is null or p_email_lookup_hash !~ '^[0-9a-f]{64}$'
         or (p_phone_lookup_hash is not null and p_phone_lookup_hash !~ '^[0-9a-f]{64}$') then
        raise exception using errcode = '22023', message = 'PRIVACY_CORRECTION_PROFILE_INVALID';
      end if;
      update public.person_private_profiles set encrypted_payload = p_encrypted_profile,
        encryption_algorithm = 'AES-256-GCM', key_version = p_profile_key_version,
        email_lookup_hash = p_email_lookup_hash, phone_lookup_hash = p_phone_lookup_hash,
        payload_version = payload_version + 1, updated_at = now()
      where tenant_id = v_request.tenant_id and agency_id = v_request.agency_id
        and person_id = v_request.matched_person_id;
      insert into public.privacy_rights_actions (
        privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id,
        data_category, disposition, record_count, reason_codes
      ) values
        (v_execution.privacy_rights_execution_id, v_request.privacy_request_id,
         v_request.tenant_id, v_request.agency_id, 'IDENTITY_PROFILE', 'CORRECTED',
         v_profile_count, array['REQUESTER_MAINTAINED_DATA']),
        (v_execution.privacy_rights_execution_id, v_request.privacy_request_id,
         v_request.tenant_id, v_request.agency_id, 'EXTERNAL_REPORTS', 'EXEMPT',
         v_external_report_count, array['SOURCE_OF_TRUTH_PRESERVED']);
      v_outcome := case when v_external_count > 0 or v_external_report_count > 0
        then 'PARTIALLY_APPLIED' else 'APPLIED' end;
      v_final_state := case when v_external_count > 0 then 'IN_PROGRESS' else 'COMPLETED' end;
    elsif v_request.request_type = 'DELETION' then
      if p_encrypted_profile is not null or p_profile_key_version is not null
         or p_email_lookup_hash is not null or p_phone_lookup_hash is not null then
        raise exception using errcode = '22023', message = 'PRIVACY_CORRECTION_NOT_APPLICABLE';
      end if;
      insert into public.privacy_processing_restrictions (
        privacy_request_id, tenant_id, agency_id, person_id, scope, policy_version
      ) values (
        v_request.privacy_request_id, v_request.tenant_id, v_request.agency_id,
        v_request.matched_person_id, 'ALL_PROCESSING', v_execution.policy_version
      ) on conflict (privacy_request_id, scope) do nothing;
      insert into public.privacy_rights_actions (
        privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id,
        data_category, disposition, record_count, reason_codes
      ) values
        (v_execution.privacy_rights_execution_id, v_request.privacy_request_id,
         v_request.tenant_id, v_request.agency_id, 'IDENTITY_PROFILE', 'DELETE_QUEUED',
         v_profile_count, array['RETENTION_DISPOSITION_REQUIRED']),
        (v_execution.privacy_rights_execution_id, v_request.privacy_request_id,
         v_request.tenant_id, v_request.agency_id, 'CONSUMER_INPUT', 'DELETE_QUEUED',
         v_consumer_count, array['RETENTION_DISPOSITION_REQUIRED']),
        (v_execution.privacy_rights_execution_id, v_request.privacy_request_id,
         v_request.tenant_id, v_request.agency_id, 'EXTERNAL_REPORTS', 'EXEMPT',
         v_external_report_count, array['LEGAL_CONTRACT_REVIEW_REQUIRED']),
        (v_execution.privacy_rights_execution_id, v_request.privacy_request_id,
         v_request.tenant_id, v_request.agency_id, 'AUDIT_EVIDENCE', 'EXEMPT',
         v_audit_count, array['AUDIT_INTEGRITY_PRESERVED']);
      v_outcome := 'PARTIALLY_APPLIED';
      v_final_state := 'IN_PROGRESS';
    else
      if p_encrypted_profile is not null or p_profile_key_version is not null
         or p_email_lookup_hash is not null or p_phone_lookup_hash is not null then
        raise exception using errcode = '22023', message = 'PRIVACY_CORRECTION_NOT_APPLICABLE';
      end if;
      insert into public.privacy_processing_restrictions (
        privacy_request_id, tenant_id, agency_id, person_id, scope, policy_version
      ) values (
        v_request.privacy_request_id, v_request.tenant_id, v_request.agency_id,
        v_request.matched_person_id,
        case when v_request.request_type = 'RESTRICTION'
          then 'ALL_PROCESSING'::public.privacy_restriction_scope
          else 'SALE_SHARING'::public.privacy_restriction_scope end,
        v_execution.policy_version
      ) on conflict (privacy_request_id, scope) do nothing;
      insert into public.privacy_rights_actions (
        privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id,
        data_category, disposition, record_count, reason_codes
      ) values (
        v_execution.privacy_rights_execution_id, v_request.privacy_request_id,
        v_request.tenant_id, v_request.agency_id, 'LOCAL_PROCESSING', 'RESTRICTED',
        v_profile_count + v_consumer_count, array[v_request.request_type::text]
      );
      v_outcome := 'APPLIED';
      v_final_state := 'COMPLETED';
    end if;

    if v_external_count > 0 then
      insert into public.privacy_rights_actions (
        privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id,
        data_category, disposition, record_count, reason_codes
      ) values (
        v_execution.privacy_rights_execution_id, v_request.privacy_request_id,
        v_request.tenant_id, v_request.agency_id, 'DOWNSTREAM_VENDOR',
        'PROPAGATION_PENDING', v_external_count, array['T804_PROPAGATION_REQUIRED']
      );
      v_final_state := 'IN_PROGRESS';
      if v_outcome = 'APPLIED' then v_outcome := 'PARTIALLY_APPLIED'; end if;
    end if;
    select coalesce(jsonb_object_agg(summary.disposition, summary.record_count), '{}'::jsonb)
      into v_summary
    from (
      select disposition::text as disposition, sum(record_count)::integer as record_count
      from public.privacy_rights_actions
      where privacy_rights_execution_id = v_execution.privacy_rights_execution_id
      group by disposition
    ) summary;
  end if;

  update public.privacy_rights_executions set status = 'COMPLETED',
    outcome = v_outcome, action_summary = v_summary, completed_at = now()
  where privacy_rights_execution_id = v_execution.privacy_rights_execution_id
  returning * into v_execution;
  update public.privacy_requests set state = v_final_state,
    applicability_reason_codes = case
      when v_outcome = 'NO_RECORDS' then array['NO_RECORD_MATCH']
      else array[v_request.request_type::text || '_EXECUTED'] end,
    completed_at = case when v_final_state = 'COMPLETED' then now() else null end,
    updated_at = now()
  where privacy_request_id = v_request.privacy_request_id returning * into v_request;

  v_integrity_hash := encode(digest(concat_ws('|', v_request.tenant_id::text,
    v_execution.privacy_rights_execution_id::text, v_outcome::text,
    v_summary::text, clock_timestamp()::text), 'sha256'), 'hex');
  insert into public.audit_events (
    tenant_id, agency_id, event_type, subject_ref, policy_version_refs,
    outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_request.tenant_id, v_request.agency_id, 'PRIVACY_RIGHTS_EXECUTION_COMPLETED',
    'privacy-request:' || v_request.public_reference::text,
    array[v_execution.policy_version], v_outcome::text,
    array[v_request.request_type::text], v_integrity_hash,
    jsonb_build_object('execution_id', v_execution.privacy_rights_execution_id,
      'action_summary', v_summary, 'request_state', v_final_state)
  );
  return query select v_request.public_reference, v_request.state,
    v_request.identity_verification_state, v_outcome, v_summary;
end
$$;

revoke all on function private.settle_privacy_rights_execution_impl(
  uuid, bytea, text, text, text
) from public;
grant execute on function private.settle_privacy_rights_execution_impl(
  uuid, bytea, text, text, text
) to service_role;

create or replace function public.settle_privacy_rights_execution(
  p_privacy_rights_execution_id uuid, p_encrypted_profile bytea,
  p_profile_key_version text, p_email_lookup_hash text, p_phone_lookup_hash text
)
returns table (
  public_reference uuid, state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state,
  execution_outcome public.privacy_rights_execution_outcome,
  action_summary jsonb
)
language sql security invoker set search_path = public, private as $$
  select * from private.settle_privacy_rights_execution_impl(
    p_privacy_rights_execution_id, p_encrypted_profile, p_profile_key_version,
    p_email_lookup_hash, p_phone_lookup_hash
  )
$$;
revoke all on function public.settle_privacy_rights_execution(
  uuid, bytea, text, text, text
) from public, anon, authenticated;
grant execute on function public.settle_privacy_rights_execution(
  uuid, bytea, text, text, text
) to service_role;
