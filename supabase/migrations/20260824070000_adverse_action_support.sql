-- T807: ownership-configurable adverse-action support and handoff evidence.
-- A responsible party supplies the determination. The platform does not infer
-- an adverse action from readiness, report contents, or carrier status.

create type public.adverse_action_owner_type as enum ('AGENCY', 'CARRIER', 'OTHER');
create type public.adverse_action_case_status as enum ('NOTICE_INPUTS_READY', 'HANDED_OFF');
create type public.adverse_action_event_type as enum ('DETERMINATION_RECORDED', 'HANDOFF_RECORDED');

create table public.adverse_action_cases (
  adverse_action_case_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  quote_case_id uuid not null references public.quote_cases(quote_case_id),
  carrier_decision_id uuid not null references public.carrier_decisions(carrier_decision_id),
  carrier_program_id uuid not null references public.carrier_programs(carrier_program_id),
  owner_type public.adverse_action_owner_type not null,
  owner_ref text not null check (char_length(trim(owner_ref)) between 3 and 500),
  ownership_policy_version text not null check (char_length(trim(ownership_policy_version)) between 3 and 200),
  determination_authority_ref text not null check (char_length(trim(determination_authority_ref)) between 3 and 500),
  determination_evidence_ref text not null check (char_length(trim(determination_evidence_ref)) between 3 and 500),
  determination_reason_codes text[] not null check (cardinality(determination_reason_codes) > 0),
  status public.adverse_action_case_status not null default 'NOTICE_INPUTS_READY',
  idempotency_key uuid not null,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  determined_by uuid not null,
  determined_at timestamptz not null default now(),
  handoff_recipient_ref text,
  handoff_evidence_ref text,
  handoff_reason_codes text[],
  handoff_idempotency_key uuid,
  handoff_request_hash text,
  handed_off_by uuid,
  handed_off_at timestamptz,
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  unique (tenant_id, agency_id, carrier_decision_id),
  unique (tenant_id, agency_id, idempotency_key),
  unique (tenant_id, agency_id, handoff_idempotency_key),
  check (
    (status = 'NOTICE_INPUTS_READY' and handoff_recipient_ref is null
      and handoff_evidence_ref is null and handoff_reason_codes is null
      and handoff_idempotency_key is null and handoff_request_hash is null
      and handed_off_by is null and handed_off_at is null)
    or
    (status = 'HANDED_OFF' and char_length(trim(handoff_recipient_ref)) between 3 and 500
      and char_length(trim(handoff_evidence_ref)) between 3 and 500
      and cardinality(handoff_reason_codes) > 0 and handoff_idempotency_key is not null
      and handoff_request_hash ~ '^[0-9a-f]{64}$'
      and handed_off_by is not null and handed_off_at is not null)
  )
);

create table public.adverse_action_report_sources (
  adverse_action_report_source_id uuid primary key default gen_random_uuid(),
  adverse_action_case_id uuid not null references public.adverse_action_cases(adverse_action_case_id),
  tenant_id uuid not null,
  agency_id uuid not null,
  external_report_id uuid not null references public.external_reports(external_report_id),
  external_request_id uuid not null references public.external_requests(external_request_id),
  provider_binding_id uuid not null references public.provider_bindings(provider_binding_id),
  cra_identity_ref text not null check (char_length(trim(cra_identity_ref)) between 3 and 500),
  dispute_route_ref text not null check (char_length(trim(dispute_route_ref)) between 3 and 500),
  contribution_basis_code text not null check (char_length(trim(contribution_basis_code)) between 3 and 100),
  created_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  unique (adverse_action_case_id, external_report_id)
);

create table public.adverse_action_events (
  adverse_action_event_id uuid primary key default gen_random_uuid(),
  adverse_action_case_id uuid not null references public.adverse_action_cases(adverse_action_case_id),
  tenant_id uuid not null,
  agency_id uuid not null,
  event_type public.adverse_action_event_type not null,
  actor_id uuid not null,
  evidence_ref text not null check (char_length(trim(evidence_ref)) between 3 and 500),
  reason_codes text[] not null check (cardinality(reason_codes) > 0),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  occurred_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id)
);

create index adverse_action_cases_queue_idx
  on public.adverse_action_cases (tenant_id, agency_id, status, determined_at);
create index adverse_action_report_sources_case_idx
  on public.adverse_action_report_sources (adverse_action_case_id, external_report_id);
create index adverse_action_events_case_idx
  on public.adverse_action_events (adverse_action_case_id, occurred_at);

alter table public.adverse_action_cases enable row level security;
alter table public.adverse_action_report_sources enable row level security;
alter table public.adverse_action_events enable row level security;

create policy adverse_action_cases_admin_select on public.adverse_action_cases
for select to authenticated using (
  (select private.has_permission(tenant_id, agency_id, 'POLICY_ADMIN'))
);
create policy adverse_action_sources_admin_select on public.adverse_action_report_sources
for select to authenticated using (
  (select private.has_permission(tenant_id, agency_id, 'POLICY_ADMIN'))
);
create policy adverse_action_events_admin_select on public.adverse_action_events
for select to authenticated using (
  (select private.has_permission(tenant_id, agency_id, 'POLICY_ADMIN'))
);

revoke all on public.adverse_action_cases, public.adverse_action_report_sources,
  public.adverse_action_events from anon, authenticated;
grant select on public.adverse_action_cases, public.adverse_action_report_sources,
  public.adverse_action_events to authenticated;

create or replace function private.prevent_adverse_action_evidence_mutation()
returns trigger language plpgsql security definer set search_path = public, private as $$
begin
  raise exception using errcode = '22023', message = 'ADVERSE_ACTION_EVIDENCE_IMMUTABLE';
end
$$;
revoke all on function private.prevent_adverse_action_evidence_mutation() from public;
create trigger adverse_action_source_immutable before update or delete
on public.adverse_action_report_sources for each row
execute function private.prevent_adverse_action_evidence_mutation();
create trigger adverse_action_event_immutable before update or delete
on public.adverse_action_events for each row
execute function private.prevent_adverse_action_evidence_mutation();

create or replace function private.enforce_adverse_action_case_update()
returns trigger language plpgsql security definer set search_path = public, private as $$
begin
  if new.tenant_id is distinct from old.tenant_id
    or new.agency_id is distinct from old.agency_id
    or new.quote_case_id is distinct from old.quote_case_id
    or new.carrier_decision_id is distinct from old.carrier_decision_id
    or new.carrier_program_id is distinct from old.carrier_program_id
    or new.owner_type is distinct from old.owner_type
    or new.owner_ref is distinct from old.owner_ref
    or new.ownership_policy_version is distinct from old.ownership_policy_version
    or new.determination_authority_ref is distinct from old.determination_authority_ref
    or new.determination_evidence_ref is distinct from old.determination_evidence_ref
    or new.determination_reason_codes is distinct from old.determination_reason_codes
    or new.idempotency_key is distinct from old.idempotency_key
    or new.request_hash is distinct from old.request_hash
    or new.determined_by is distinct from old.determined_by
    or new.determined_at is distinct from old.determined_at
    or old.status = 'HANDED_OFF' or new.status <> 'HANDED_OFF' then
    raise exception using errcode = '22023', message = 'ADVERSE_ACTION_LIFECYCLE_INVALID';
  end if;
  return new;
end
$$;
revoke all on function private.enforce_adverse_action_case_update() from public;
create trigger adverse_action_case_update_guard before update on public.adverse_action_cases
for each row execute function private.enforce_adverse_action_case_update();
create trigger adverse_action_case_delete_guard before delete on public.adverse_action_cases
for each row execute function private.prevent_adverse_action_evidence_mutation();

create or replace function private.create_adverse_action_case_impl(
  p_quote_case_id uuid, p_carrier_decision_id uuid,
  p_owner_type public.adverse_action_owner_type, p_owner_ref text,
  p_determination_authority_ref text, p_determination_evidence_ref text,
  p_reason_codes text[], p_report_sources jsonb,
  p_idempotency_key uuid, p_request_hash text
)
returns public.adverse_action_cases language plpgsql security definer
set search_path = public, private, extensions as $$
declare
  v_actor uuid := auth.uid(); v_case public.quote_cases;
  v_decision public.carrier_decisions; v_program public.carrier_programs;
  v_adverse public.adverse_action_cases; v_source jsonb; v_report record; v_hash text;
begin
  if v_actor is null then raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED'; end if;
  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id;
  if not found then raise exception using errcode = 'P0002', message = 'QUOTE_CASE_NOT_FOUND'; end if;
  if not private.has_permission(v_case.tenant_id, v_case.agency_id, 'POLICY_ADMIN') then
    raise exception using errcode = '42501', message = 'ADVERSE_ACTION_ADMIN_NOT_PERMITTED';
  end if;
  select * into v_decision from public.carrier_decisions
  where carrier_decision_id = p_carrier_decision_id
    and tenant_id = v_case.tenant_id and agency_id = v_case.agency_id;
  if not found then raise exception using errcode = 'P0002', message = 'CARRIER_DECISION_NOT_FOUND'; end if;
  if not exists (select 1 from public.carrier_submissions s
    where s.carrier_submission_id = v_decision.carrier_submission_id
      and s.quote_case_id = p_quote_case_id) then
    raise exception using errcode = '22023', message = 'CARRIER_DECISION_CASE_MISMATCH';
  end if;
  select * into v_program from public.carrier_programs
  where carrier_program_id = v_decision.carrier_program_id;
  if jsonb_typeof(p_report_sources) <> 'array' or jsonb_array_length(p_report_sources) = 0 then
    raise exception using errcode = '22023', message = 'CONTRIBUTING_REPORT_REQUIRED';
  end if;
  select * into v_adverse from public.adverse_action_cases a
  where a.tenant_id = v_case.tenant_id and a.agency_id = v_case.agency_id
    and a.idempotency_key = p_idempotency_key for update;
  if found then
    if v_adverse.request_hash <> p_request_hash then
      raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUEST_MISMATCH';
    end if;
    return v_adverse;
  end if;
  insert into public.adverse_action_cases (
    tenant_id, agency_id, quote_case_id, carrier_decision_id, carrier_program_id,
    owner_type, owner_ref, ownership_policy_version, determination_authority_ref,
    determination_evidence_ref, determination_reason_codes, idempotency_key,
    request_hash, determined_by
  ) values (
    v_case.tenant_id, v_case.agency_id, p_quote_case_id, p_carrier_decision_id,
    v_decision.carrier_program_id, p_owner_type, trim(p_owner_ref),
    v_program.notice_ownership_policy_version, trim(p_determination_authority_ref),
    trim(p_determination_evidence_ref), p_reason_codes, p_idempotency_key,
    p_request_hash, v_actor
  ) returning * into v_adverse;
  for v_source in select value from jsonb_array_elements(p_report_sources)
  loop
    if nullif(v_source->>'craIdentityRef','') is null
      or nullif(v_source->>'disputeRouteRef','') is null
      or nullif(v_source->>'contributionBasisCode','') is null then
      raise exception using errcode = '22023', message = 'CONTRIBUTING_REPORT_INPUT_INVALID';
    end if;
    select r.external_report_id, r.external_request_id, q.provider_binding_id
      into v_report
    from public.external_reports r join public.external_requests q
      on q.external_request_id = r.external_request_id
    where r.external_report_id = (v_source->>'externalReportId')::uuid
      and r.quote_case_id = p_quote_case_id and r.tenant_id = v_case.tenant_id
      and r.agency_id = v_case.agency_id and r.status in ('SUCCESS','PARTIAL','STALE');
    if not found then raise exception using errcode = 'P0002', message = 'CONTRIBUTING_REPORT_NOT_FOUND'; end if;
    insert into public.adverse_action_report_sources (
      adverse_action_case_id, tenant_id, agency_id, external_report_id,
      external_request_id, provider_binding_id, cra_identity_ref,
      dispute_route_ref, contribution_basis_code
    ) values (
      v_adverse.adverse_action_case_id, v_case.tenant_id, v_case.agency_id,
      v_report.external_report_id, v_report.external_request_id, v_report.provider_binding_id,
      trim(v_source->>'craIdentityRef'), trim(v_source->>'disputeRouteRef'),
      trim(v_source->>'contributionBasisCode')
    );
  end loop;
  insert into public.adverse_action_events (
    adverse_action_case_id, tenant_id, agency_id, event_type, actor_id,
    evidence_ref, reason_codes, request_hash
  ) values (v_adverse.adverse_action_case_id, v_case.tenant_id, v_case.agency_id,
    'DETERMINATION_RECORDED', v_actor, v_adverse.determination_evidence_ref,
    p_reason_codes, p_request_hash);
  v_hash := encode(digest(concat_ws('|', v_adverse.adverse_action_case_id::text,
    p_request_hash, 'DETERMINATION_RECORDED'), 'sha256'), 'hex');
  insert into public.audit_events (tenant_id, agency_id, quote_case_id, event_type,
    actor_id, subject_ref, configuration_version_ref, outcome, reason_codes,
    integrity_hash, metadata)
  values (v_case.tenant_id, v_case.agency_id, p_quote_case_id,
    'ADVERSE_ACTION_DETERMINATION_RECORDED', v_actor,
    'adverse-action:' || v_adverse.adverse_action_case_id::text,
    v_case.tenant_configuration_version::text, 'SUCCEEDED', p_reason_codes, v_hash,
    jsonb_build_object('owner_type', p_owner_type, 'carrier_program_id', v_decision.carrier_program_id,
      'ownership_policy_version', v_program.notice_ownership_policy_version,
      'contributing_report_count', jsonb_array_length(p_report_sources)));
  return v_adverse;
end
$$;
revoke all on function private.create_adverse_action_case_impl(uuid, uuid, public.adverse_action_owner_type, text, text, text, text[], jsonb, uuid, text) from public;
grant execute on function private.create_adverse_action_case_impl(uuid, uuid, public.adverse_action_owner_type, text, text, text, text[], jsonb, uuid, text) to authenticated;

create or replace function private.record_adverse_action_handoff_impl(
  p_adverse_action_case_id uuid, p_recipient_ref text, p_evidence_ref text,
  p_reason_codes text[], p_idempotency_key uuid, p_request_hash text
)
returns public.adverse_action_cases language plpgsql security definer
set search_path = public, private, extensions as $$
declare v_actor uuid := auth.uid(); v_case public.adverse_action_cases; v_hash text;
begin
  if v_actor is null then raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED'; end if;
  select * into v_case from public.adverse_action_cases
  where adverse_action_case_id = p_adverse_action_case_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'ADVERSE_ACTION_CASE_NOT_FOUND'; end if;
  if not private.has_permission(v_case.tenant_id, v_case.agency_id, 'POLICY_ADMIN') then
    raise exception using errcode = '42501', message = 'ADVERSE_ACTION_ADMIN_NOT_PERMITTED';
  end if;
  if v_case.status = 'HANDED_OFF' then
    if v_case.handoff_idempotency_key <> p_idempotency_key
      or v_case.handoff_request_hash <> p_request_hash then
      raise exception using errcode = '22023', message = 'ADVERSE_ACTION_ALREADY_HANDED_OFF';
    end if;
    return v_case;
  end if;
  update public.adverse_action_cases set status = 'HANDED_OFF',
    handoff_recipient_ref = trim(p_recipient_ref), handoff_evidence_ref = trim(p_evidence_ref),
    handoff_reason_codes = p_reason_codes, handoff_idempotency_key = p_idempotency_key,
    handoff_request_hash = p_request_hash, handed_off_by = v_actor, handed_off_at = now()
  where adverse_action_case_id = p_adverse_action_case_id returning * into v_case;
  insert into public.adverse_action_events (
    adverse_action_case_id, tenant_id, agency_id, event_type, actor_id,
    evidence_ref, reason_codes, request_hash
  ) values (v_case.adverse_action_case_id, v_case.tenant_id, v_case.agency_id,
    'HANDOFF_RECORDED', v_actor, v_case.handoff_evidence_ref, p_reason_codes, p_request_hash);
  v_hash := encode(digest(concat_ws('|', v_case.adverse_action_case_id::text,
    p_request_hash, 'HANDOFF_RECORDED'), 'sha256'), 'hex');
  insert into public.audit_events (tenant_id, agency_id, quote_case_id, event_type,
    actor_id, subject_ref, outcome, reason_codes, integrity_hash, metadata)
  values (v_case.tenant_id, v_case.agency_id, v_case.quote_case_id,
    'ADVERSE_ACTION_HANDOFF_RECORDED', v_actor,
    'adverse-action:' || v_case.adverse_action_case_id::text, 'SUCCEEDED',
    p_reason_codes, v_hash, jsonb_build_object('owner_type', v_case.owner_type,
      'ownership_policy_version', v_case.ownership_policy_version));
  return v_case;
end
$$;
revoke all on function private.record_adverse_action_handoff_impl(uuid, text, text, text[], uuid, text) from public;
grant execute on function private.record_adverse_action_handoff_impl(uuid, text, text, text[], uuid, text) to authenticated;

create or replace function public.create_adverse_action_case(
  p_quote_case_id uuid, p_carrier_decision_id uuid,
  p_owner_type public.adverse_action_owner_type, p_owner_ref text,
  p_determination_authority_ref text, p_determination_evidence_ref text,
  p_reason_codes text[], p_report_sources jsonb,
  p_idempotency_key uuid, p_request_hash text
)
returns public.adverse_action_cases language sql security invoker set search_path = public, private as $$
  select private.create_adverse_action_case_impl(p_quote_case_id, p_carrier_decision_id,
    p_owner_type, p_owner_ref, p_determination_authority_ref,
    p_determination_evidence_ref, p_reason_codes, p_report_sources,
    p_idempotency_key, p_request_hash)
$$;
create or replace function public.record_adverse_action_handoff(
  p_adverse_action_case_id uuid, p_recipient_ref text, p_evidence_ref text,
  p_reason_codes text[], p_idempotency_key uuid, p_request_hash text
)
returns public.adverse_action_cases language sql security invoker set search_path = public, private as $$
  select private.record_adverse_action_handoff_impl(p_adverse_action_case_id,
    p_recipient_ref, p_evidence_ref, p_reason_codes, p_idempotency_key, p_request_hash)
$$;
revoke all on function public.create_adverse_action_case(uuid, uuid, public.adverse_action_owner_type, text, text, text, text[], jsonb, uuid, text) from public, anon, authenticated;
revoke all on function public.record_adverse_action_handoff(uuid, text, text, text[], uuid, text) from public, anon, authenticated;
grant execute on function public.create_adverse_action_case(uuid, uuid, public.adverse_action_owner_type, text, text, text, text[], jsonb, uuid, text) to authenticated;
grant execute on function public.record_adverse_action_handoff(uuid, text, text, text[], uuid, text) to authenticated;
