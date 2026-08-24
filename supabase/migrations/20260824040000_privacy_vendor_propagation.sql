-- T804: provider-neutral downstream privacy propagation tracking.
-- Live bindings remain unconfigured until a certified vendor privacy adapter exists.

create type public.privacy_propagation_binding_state as enum (
  'SYNTHETIC', 'APPROVED', 'SUSPENDED'
);
create type public.privacy_propagation_status as enum (
  'PENDING', 'BLOCKED', 'COMPLETED', 'FAILED'
);
create type public.privacy_propagation_run_status as enum (
  'PREPARED', 'IN_PROGRESS', 'COMPLETED'
);
create type public.privacy_propagation_action as enum (
  'CORRECT', 'DELETE', 'RESTRICT', 'OPT_OUT'
);
create type public.privacy_propagation_outcome as enum (
  'COMPLETED', 'RETRYABLE_FAILURE', 'PERMANENT_FAILURE'
);

alter table public.provider_bindings
  add constraint provider_bindings_tenant_agency_id_unique
  unique (tenant_id, agency_id, provider_binding_id);
alter table public.external_requests
  add constraint external_requests_tenant_agency_id_unique
  unique (tenant_id, agency_id, external_request_id);

create table public.privacy_propagation_bindings (
  privacy_propagation_binding_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  provider_binding_id uuid not null,
  adapter_id text not null check (adapter_id ~ '^[A-Za-z0-9_.:-]{3,100}$'),
  adapter_version text not null check (adapter_version ~ '^[A-Za-z0-9_.:-]{1,100}$'),
  policy_version text not null check (policy_version ~ '^[A-Za-z0-9_.:-]{3,100}$'),
  state public.privacy_propagation_binding_state not null,
  effective_at timestamptz not null default now(),
  retired_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  foreign key (tenant_id, agency_id, provider_binding_id)
    references public.provider_bindings(tenant_id, agency_id, provider_binding_id),
  unique (tenant_id, agency_id, provider_binding_id, adapter_id, adapter_version, policy_version),
  check ((state = 'SUSPENDED') = (retired_at is not null))
);

create table public.privacy_propagation_runs (
  privacy_propagation_run_id uuid primary key default gen_random_uuid(),
  privacy_rights_execution_id uuid not null,
  privacy_request_id uuid not null,
  tenant_id uuid not null,
  agency_id uuid not null,
  idempotency_key uuid not null,
  adapter_id text not null,
  adapter_version text not null,
  policy_version text not null,
  status public.privacy_propagation_run_status not null default 'PREPARED',
  prepared_at timestamptz not null default now(),
  completed_at timestamptz,
  foreign key (privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id)
    references public.privacy_rights_executions(
      privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id
    ),
  unique (privacy_rights_execution_id, idempotency_key),
  check ((status = 'COMPLETED') = (completed_at is not null))
);

create table public.privacy_vendor_propagations (
  privacy_vendor_propagation_id uuid primary key default gen_random_uuid(),
  privacy_rights_execution_id uuid not null,
  privacy_request_id uuid not null,
  tenant_id uuid not null,
  agency_id uuid not null,
  external_request_id uuid not null,
  provider_binding_id uuid not null,
  privacy_propagation_binding_id uuid references public.privacy_propagation_bindings(
    privacy_propagation_binding_id
  ),
  action public.privacy_propagation_action not null,
  status public.privacy_propagation_status not null,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_evidence_ref text,
  reason_codes text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  foreign key (privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id)
    references public.privacy_rights_executions(
      privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id
    ),
  foreign key (tenant_id, agency_id, external_request_id)
    references public.external_requests(tenant_id, agency_id, external_request_id),
  foreign key (tenant_id, agency_id, provider_binding_id)
    references public.provider_bindings(tenant_id, agency_id, provider_binding_id),
  unique (privacy_rights_execution_id, external_request_id),
  unique (privacy_vendor_propagation_id, privacy_rights_execution_id, privacy_request_id),
  check ((status = 'COMPLETED') = (completed_at is not null)),
  check (status <> 'BLOCKED' or privacy_propagation_binding_id is null)
);

create table public.privacy_vendor_propagation_attempts (
  privacy_vendor_propagation_attempt_id uuid primary key default gen_random_uuid(),
  privacy_vendor_propagation_id uuid not null,
  privacy_propagation_run_id uuid not null references public.privacy_propagation_runs(
    privacy_propagation_run_id
  ),
  privacy_rights_execution_id uuid not null,
  privacy_request_id uuid not null,
  tenant_id uuid not null,
  agency_id uuid not null,
  idempotency_key uuid not null,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  outcome public.privacy_propagation_outcome not null,
  adapter_id text not null,
  adapter_version text not null,
  policy_version text not null,
  evidence_ref text not null check (char_length(evidence_ref) between 3 and 500),
  reason_codes text[] not null default '{}',
  attempted_at timestamptz not null default now(),
  foreign key (
    privacy_vendor_propagation_id, privacy_rights_execution_id, privacy_request_id
  ) references public.privacy_vendor_propagations(
    privacy_vendor_propagation_id, privacy_rights_execution_id, privacy_request_id
  ),
  foreign key (tenant_id, agency_id, privacy_request_id)
    references public.privacy_requests(tenant_id, agency_id, privacy_request_id),
  unique (privacy_vendor_propagation_id, idempotency_key)
);

create index privacy_propagation_bindings_lookup_idx on public.privacy_propagation_bindings (
  tenant_id, agency_id, provider_binding_id, state
);
create index privacy_vendor_propagations_request_idx on public.privacy_vendor_propagations (
  tenant_id, agency_id, privacy_request_id, status
);
create index privacy_vendor_propagation_attempts_target_idx
  on public.privacy_vendor_propagation_attempts (
    tenant_id, agency_id, privacy_vendor_propagation_id, attempted_at desc
  );

alter table public.privacy_propagation_bindings enable row level security;
alter table public.privacy_propagation_runs enable row level security;
alter table public.privacy_vendor_propagations enable row level security;
alter table public.privacy_vendor_propagation_attempts enable row level security;

create policy privacy_propagation_bindings_admin_select
on public.privacy_propagation_bindings for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
  or private.has_permission(tenant_id, agency_id, 'POLICY_ADMIN')
);
create policy privacy_propagation_runs_admin_select
on public.privacy_propagation_runs for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
);
create policy privacy_vendor_propagations_admin_select
on public.privacy_vendor_propagations for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
);
create policy privacy_vendor_propagation_attempts_admin_select
on public.privacy_vendor_propagation_attempts for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
);

revoke all on public.privacy_propagation_bindings,
  public.privacy_propagation_runs,
  public.privacy_vendor_propagations,
  public.privacy_vendor_propagation_attempts from anon, authenticated;
grant select on public.privacy_propagation_bindings,
  public.privacy_propagation_runs,
  public.privacy_vendor_propagations,
  public.privacy_vendor_propagation_attempts to authenticated;

create or replace function private.prevent_privacy_propagation_attempt_mutation()
returns trigger language plpgsql security definer set search_path = public, private as $$
begin
  raise exception using errcode = '22023', message = 'PRIVACY_PROPAGATION_ATTEMPT_IMMUTABLE';
  return null;
end
$$;
revoke all on function private.prevent_privacy_propagation_attempt_mutation() from public;
create trigger privacy_vendor_propagation_attempt_immutable
before update or delete on public.privacy_vendor_propagation_attempts
for each row execute function private.prevent_privacy_propagation_attempt_mutation();

create or replace function private.privacy_propagation_status_summary(
  p_privacy_rights_execution_id uuid
)
returns jsonb language sql stable security invoker set search_path = public, private as $$
  select coalesce(jsonb_object_agg(status, target_count), '{}'::jsonb)
  from (
    select status::text as status, count(*)::integer as target_count
    from public.privacy_vendor_propagations
    where privacy_rights_execution_id = p_privacy_rights_execution_id
    group by status
  ) summary
$$;
revoke all on function private.privacy_propagation_status_summary(uuid) from public;

create or replace function private.prepare_privacy_vendor_propagation_impl(
  p_hostname text,
  p_public_reference uuid,
  p_status_token_hash text,
  p_idempotency_key uuid,
  p_adapter_id text,
  p_adapter_version text,
  p_policy_version text
)
returns table (
  privacy_propagation_run_id uuid,
  privacy_vendor_propagation_id uuid,
  target_status public.privacy_propagation_status,
  action public.privacy_propagation_action,
  adapter_id text,
  adapter_version text,
  policy_version text,
  public_reference uuid,
  state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state,
  propagation_complete boolean,
  status_summary jsonb
)
language plpgsql security definer set search_path = public, private, extensions as $$
declare
  v_host public.tenant_hosts;
  v_request public.privacy_requests;
  v_execution public.privacy_rights_executions;
  v_run public.privacy_propagation_runs;
  v_existing public.privacy_propagation_runs;
  v_action public.privacy_propagation_action;
  v_summary jsonb;
  v_complete boolean;
  v_integrity_hash text;
begin
  if p_public_reference is null or p_idempotency_key is null
     or p_status_token_hash is null or p_status_token_hash !~ '^[0-9a-f]{64}$'
     or p_adapter_id is null or p_adapter_id !~ '^[A-Za-z0-9_.:-]{3,100}$'
     or p_adapter_version is null or p_adapter_version !~ '^[A-Za-z0-9_.:-]{1,100}$'
     or p_policy_version is null or p_policy_version !~ '^[A-Za-z0-9_.:-]{3,100}$' then
    raise exception using errcode = '22023', message = 'PRIVACY_PROPAGATION_INPUT_INVALID';
  end if;
  select * into v_host from public.tenant_hosts
  where hostname = lower(split_part(trim(p_hostname), ':', 1)) and status = 'ACTIVE';
  if not found then
    raise exception using errcode = 'P0002', message = 'PRIVACY_REQUEST_NOT_FOUND';
  end if;
  select pr.* into v_request from public.privacy_requests pr
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
  select pre.* into v_execution from public.privacy_rights_executions pre
  where pre.privacy_request_id = v_request.privacy_request_id
    and pre.status = 'COMPLETED'
    and exists (
      select 1 from public.privacy_rights_actions pra
      where pra.privacy_rights_execution_id = pre.privacy_rights_execution_id
        and pra.disposition = 'PROPAGATION_PENDING'
    ) order by pre.completed_at desc limit 1;
  if not found or v_request.state not in ('IN_PROGRESS', 'COMPLETED') then
    raise exception using errcode = '55000', message = 'PRIVACY_PROPAGATION_STATE_INVALID';
  end if;
  v_action := case v_request.request_type
    when 'CORRECTION' then 'CORRECT'::public.privacy_propagation_action
    when 'DELETION' then 'DELETE'::public.privacy_propagation_action
    when 'RESTRICTION' then 'RESTRICT'::public.privacy_propagation_action
    when 'OPT_OUT' then 'OPT_OUT'::public.privacy_propagation_action
    else null end;
  if v_action is null then
    raise exception using errcode = '55000', message = 'PRIVACY_PROPAGATION_STATE_INVALID';
  end if;

  select * into v_existing from public.privacy_propagation_runs
  where privacy_rights_execution_id = v_execution.privacy_rights_execution_id
    and idempotency_key = p_idempotency_key;
  if found then
    if v_existing.adapter_id <> p_adapter_id
       or v_existing.adapter_version <> p_adapter_version
       or v_existing.policy_version <> p_policy_version then
      raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUEST_MISMATCH';
    end if;
    v_run := v_existing;
  else
    insert into public.privacy_propagation_runs (
      privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id,
      idempotency_key, adapter_id, adapter_version, policy_version
    ) values (
      v_execution.privacy_rights_execution_id, v_request.privacy_request_id,
      v_request.tenant_id, v_request.agency_id, p_idempotency_key,
      p_adapter_id, p_adapter_version, p_policy_version
    ) returning * into v_run;

    insert into public.privacy_vendor_propagations (
      privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id,
      external_request_id, provider_binding_id, privacy_propagation_binding_id,
      action, status, reason_codes
    )
    select v_execution.privacy_rights_execution_id, v_request.privacy_request_id,
      v_request.tenant_id, v_request.agency_id, er.external_request_id,
      er.provider_binding_id, ppb.privacy_propagation_binding_id, v_action,
      case when ppb.privacy_propagation_binding_id is null
        then 'BLOCKED'::public.privacy_propagation_status
        else 'PENDING'::public.privacy_propagation_status end,
      case when ppb.privacy_propagation_binding_id is null
        then array['PROPAGATION_BINDING_NOT_CONFIGURED'] else '{}'::text[] end
    from public.external_requests er
    join public.quote_cases qc on qc.quote_case_id = er.quote_case_id
      and qc.tenant_id = er.tenant_id and qc.agency_id = er.agency_id
    join public.prospects p on p.prospect_id = qc.prospect_id
    left join lateral (
      select binding.* from public.privacy_propagation_bindings binding
      where binding.tenant_id = er.tenant_id and binding.agency_id = er.agency_id
        and binding.provider_binding_id = er.provider_binding_id
        and binding.adapter_id = p_adapter_id
        and binding.adapter_version = p_adapter_version
        and binding.policy_version = p_policy_version
        and binding.state in ('SYNTHETIC', 'APPROVED')
      order by binding.effective_at desc limit 1
    ) ppb on true
    where er.tenant_id = v_request.tenant_id and er.agency_id = v_request.agency_id
      and p.person_id = v_request.matched_person_id
    on conflict (privacy_rights_execution_id, external_request_id) do nothing;

    if not exists (
      select 1 from public.privacy_vendor_propagations
      where privacy_rights_execution_id = v_execution.privacy_rights_execution_id
    ) then
      raise exception using errcode = '55000', message = 'PRIVACY_PROPAGATION_TARGETS_NOT_FOUND';
    end if;
    update public.privacy_propagation_runs set status = 'IN_PROGRESS'
    where privacy_propagation_run_id = v_run.privacy_propagation_run_id
    returning * into v_run;
    v_integrity_hash := encode(digest(concat_ws('|', v_request.tenant_id::text,
      v_run.privacy_propagation_run_id::text, p_policy_version,
      clock_timestamp()::text), 'sha256'), 'hex');
    insert into public.audit_events (
      tenant_id, agency_id, event_type, subject_ref, configuration_version_ref,
      policy_version_refs, outcome, reason_codes, integrity_hash, metadata
    ) values (
      v_request.tenant_id, v_request.agency_id, 'PRIVACY_PROPAGATION_PREPARED',
      'privacy-request:' || v_request.public_reference::text,
      v_host.tenant_configuration_version::text, array[p_policy_version],
      'PREPARED', '{}', v_integrity_hash,
      jsonb_build_object('propagation_run_id', v_run.privacy_propagation_run_id,
        'target_count', (select count(*) from public.privacy_vendor_propagations
          where privacy_rights_execution_id = v_execution.privacy_rights_execution_id))
    );
  end if;
  v_summary := private.privacy_propagation_status_summary(
    v_execution.privacy_rights_execution_id
  );
  v_complete := not exists (
    select 1 from public.privacy_vendor_propagations
    where privacy_rights_execution_id = v_execution.privacy_rights_execution_id
      and status <> 'COMPLETED'
  );
  return query select v_run.privacy_propagation_run_id,
    pvp.privacy_vendor_propagation_id, pvp.status, pvp.action,
    ppb.adapter_id, ppb.adapter_version, ppb.policy_version,
    v_request.public_reference, v_request.state, v_request.identity_verification_state,
    v_complete, v_summary
  from public.privacy_vendor_propagations pvp
  left join public.privacy_propagation_bindings ppb
    on ppb.privacy_propagation_binding_id = pvp.privacy_propagation_binding_id
  where pvp.privacy_rights_execution_id = v_execution.privacy_rights_execution_id
  order by pvp.created_at, pvp.privacy_vendor_propagation_id;
end
$$;

revoke all on function private.prepare_privacy_vendor_propagation_impl(
  text, uuid, text, uuid, text, text, text
) from public;
grant execute on function private.prepare_privacy_vendor_propagation_impl(
  text, uuid, text, uuid, text, text, text
) to service_role;

create or replace function public.prepare_privacy_vendor_propagation(
  p_hostname text, p_public_reference uuid, p_status_token_hash text,
  p_idempotency_key uuid, p_adapter_id text, p_adapter_version text,
  p_policy_version text
)
returns table (
  privacy_propagation_run_id uuid, privacy_vendor_propagation_id uuid,
  target_status public.privacy_propagation_status,
  action public.privacy_propagation_action,
  adapter_id text, adapter_version text, policy_version text,
  public_reference uuid, state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state,
  propagation_complete boolean, status_summary jsonb
)
language sql security invoker set search_path = public, private as $$
  select * from private.prepare_privacy_vendor_propagation_impl(
    p_hostname, p_public_reference, p_status_token_hash, p_idempotency_key,
    p_adapter_id, p_adapter_version, p_policy_version
  )
$$;
revoke all on function public.prepare_privacy_vendor_propagation(
  text, uuid, text, uuid, text, text, text
) from public, anon, authenticated;
grant execute on function public.prepare_privacy_vendor_propagation(
  text, uuid, text, uuid, text, text, text
) to service_role;

create or replace function private.settle_privacy_vendor_propagation_impl(
  p_privacy_vendor_propagation_id uuid,
  p_idempotency_key uuid,
  p_request_hash text,
  p_outcome public.privacy_propagation_outcome,
  p_adapter_id text,
  p_adapter_version text,
  p_policy_version text,
  p_evidence_ref text,
  p_reason_codes text[]
)
returns table (
  public_reference uuid, state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state,
  propagation_complete boolean, status_summary jsonb
)
language plpgsql security definer set search_path = public, private, extensions as $$
declare
  v_target public.privacy_vendor_propagations;
  v_execution public.privacy_rights_executions;
  v_request public.privacy_requests;
  v_binding public.privacy_propagation_bindings;
  v_run public.privacy_propagation_runs;
  v_attempt public.privacy_vendor_propagation_attempts;
  v_summary jsonb;
  v_complete boolean;
  v_integrity_hash text;
  v_final_state public.privacy_request_state;
begin
  if p_idempotency_key is null or p_request_hash is null
     or p_request_hash !~ '^[0-9a-f]{64}$' or p_outcome is null
     or p_evidence_ref is null or char_length(p_evidence_ref) not between 3 and 500
     or cardinality(coalesce(p_reason_codes, '{}')) > 20 then
    raise exception using errcode = '22023', message = 'PRIVACY_PROPAGATION_RESULT_INVALID';
  end if;
  select * into v_target from public.privacy_vendor_propagations
  where privacy_vendor_propagation_id = p_privacy_vendor_propagation_id for update;
  if not found or v_target.status = 'BLOCKED' then
    raise exception using errcode = 'P0002', message = 'PRIVACY_PROPAGATION_TARGET_NOT_FOUND';
  end if;
  select * into v_execution from public.privacy_rights_executions
  where privacy_rights_execution_id = v_target.privacy_rights_execution_id;
  select * into v_request from public.privacy_requests
  where privacy_request_id = v_target.privacy_request_id for update;
  select * into v_binding from public.privacy_propagation_bindings
  where privacy_propagation_binding_id = v_target.privacy_propagation_binding_id;
  if not found or v_binding.adapter_id <> p_adapter_id
     or v_binding.adapter_version <> p_adapter_version
     or v_binding.policy_version <> p_policy_version
     or v_binding.state not in ('SYNTHETIC', 'APPROVED') then
    raise exception using errcode = '55000', message = 'PRIVACY_PROPAGATION_BINDING_INVALID';
  end if;
  select * into v_run from public.privacy_propagation_runs
  where privacy_rights_execution_id = v_execution.privacy_rights_execution_id
    and idempotency_key = p_idempotency_key;
  if not found or v_run.adapter_id <> p_adapter_id
     or v_run.adapter_version <> p_adapter_version
     or v_run.policy_version <> p_policy_version then
    raise exception using errcode = '55000', message = 'PRIVACY_PROPAGATION_RUN_INVALID';
  end if;
  select * into v_attempt from public.privacy_vendor_propagation_attempts
  where privacy_vendor_propagation_id = v_target.privacy_vendor_propagation_id
    and idempotency_key = p_idempotency_key;
  if found then
    if v_attempt.request_hash <> p_request_hash
       or v_attempt.outcome <> p_outcome
       or v_attempt.evidence_ref <> p_evidence_ref then
      raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUEST_MISMATCH';
    end if;
  else
    insert into public.privacy_vendor_propagation_attempts (
      privacy_vendor_propagation_id, privacy_propagation_run_id,
      privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id,
      idempotency_key, request_hash, outcome, adapter_id, adapter_version,
      policy_version, evidence_ref, reason_codes
    ) values (
      v_target.privacy_vendor_propagation_id, v_run.privacy_propagation_run_id,
      v_target.privacy_rights_execution_id, v_target.privacy_request_id,
      v_target.tenant_id, v_target.agency_id, p_idempotency_key, p_request_hash,
      p_outcome, p_adapter_id, p_adapter_version, p_policy_version,
      p_evidence_ref, coalesce(p_reason_codes, '{}')
    );
    update public.privacy_vendor_propagations set
      status = case when p_outcome = 'COMPLETED'
        then 'COMPLETED'::public.privacy_propagation_status
        else 'FAILED'::public.privacy_propagation_status end,
      attempt_count = attempt_count + 1,
      last_evidence_ref = p_evidence_ref,
      reason_codes = coalesce(p_reason_codes, '{}'),
      updated_at = now(),
      completed_at = case when p_outcome = 'COMPLETED' then now() else null end
    where privacy_vendor_propagation_id = v_target.privacy_vendor_propagation_id
    returning * into v_target;
    v_integrity_hash := encode(digest(concat_ws('|', v_target.tenant_id::text,
      v_target.privacy_vendor_propagation_id::text, p_outcome::text,
      p_evidence_ref, clock_timestamp()::text), 'sha256'), 'hex');
    insert into public.audit_events (
      tenant_id, agency_id, event_type, subject_ref, policy_version_refs,
      outcome, reason_codes, integrity_hash, metadata
    ) values (
      v_target.tenant_id, v_target.agency_id, 'PRIVACY_PROPAGATION_ATTEMPTED',
      'privacy-request:' || v_request.public_reference::text,
      array[p_policy_version], p_outcome::text, coalesce(p_reason_codes, '{}'),
      v_integrity_hash, jsonb_build_object(
        'propagation_run_id', v_run.privacy_propagation_run_id,
        'propagation_target_id', v_target.privacy_vendor_propagation_id,
        'attempt_count', v_target.attempt_count)
    );
  end if;
  v_complete := not exists (
    select 1 from public.privacy_vendor_propagations
    where privacy_rights_execution_id = v_execution.privacy_rights_execution_id
      and status <> 'COMPLETED'
  );
  v_summary := private.privacy_propagation_status_summary(
    v_execution.privacy_rights_execution_id
  );
  if v_complete then
    update public.privacy_propagation_runs set status = 'COMPLETED', completed_at = now()
    where privacy_propagation_run_id = v_run.privacy_propagation_run_id
      and status <> 'COMPLETED';
    v_final_state := case when exists (
      select 1 from public.privacy_rights_actions
      where privacy_rights_execution_id = v_execution.privacy_rights_execution_id
        and disposition = 'DELETE_QUEUED'
    ) then 'IN_PROGRESS'::public.privacy_request_state
      else 'COMPLETED'::public.privacy_request_state end;
    update public.privacy_requests set state = v_final_state,
      completed_at = case when v_final_state = 'COMPLETED' then now() else null end,
      updated_at = now(),
      applicability_reason_codes = case when v_final_state = 'COMPLETED'
        then array['DOWNSTREAM_PROPAGATION_COMPLETED']
        else array['RETENTION_DISPOSITION_PENDING'] end
    where privacy_request_id = v_request.privacy_request_id returning * into v_request;
  else
    update public.privacy_propagation_runs set status = 'IN_PROGRESS'
    where privacy_propagation_run_id = v_run.privacy_propagation_run_id;
  end if;
  return query select v_request.public_reference, v_request.state,
    v_request.identity_verification_state, v_complete, v_summary;
end
$$;

revoke all on function private.settle_privacy_vendor_propagation_impl(
  uuid, uuid, text, public.privacy_propagation_outcome,
  text, text, text, text, text[]
) from public;
grant execute on function private.settle_privacy_vendor_propagation_impl(
  uuid, uuid, text, public.privacy_propagation_outcome,
  text, text, text, text, text[]
) to service_role;

create or replace function public.settle_privacy_vendor_propagation(
  p_privacy_vendor_propagation_id uuid, p_idempotency_key uuid,
  p_request_hash text, p_outcome public.privacy_propagation_outcome,
  p_adapter_id text, p_adapter_version text, p_policy_version text,
  p_evidence_ref text, p_reason_codes text[]
)
returns table (
  public_reference uuid, state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state,
  propagation_complete boolean, status_summary jsonb
)
language sql security invoker set search_path = public, private as $$
  select * from private.settle_privacy_vendor_propagation_impl(
    p_privacy_vendor_propagation_id, p_idempotency_key, p_request_hash,
    p_outcome, p_adapter_id, p_adapter_version, p_policy_version,
    p_evidence_ref, p_reason_codes
  )
$$;
revoke all on function public.settle_privacy_vendor_propagation(
  uuid, uuid, text, public.privacy_propagation_outcome,
  text, text, text, text, text[]
) from public, anon, authenticated;
grant execute on function public.settle_privacy_vendor_propagation(
  uuid, uuid, text, public.privacy_propagation_outcome,
  text, text, text, text, text[]
) to service_role;
