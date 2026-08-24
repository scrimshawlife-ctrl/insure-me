-- T801: provider-neutral privacy identity verification settlement.

create type public.privacy_identity_verification_outcome as enum (
  'VERIFIED',
  'FAILED'
);

create or replace function private.privacy_reason_codes_valid(p_codes text[])
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select p_codes is not null
    and cardinality(p_codes) between 1 and 12
    and not exists (
      select 1
      from unnest(p_codes) as code
      where code !~ '^[A-Z0-9_:-]{1,120}$'
    )
$$;

revoke all on function private.privacy_reason_codes_valid(text[]) from public;
grant execute on function private.privacy_reason_codes_valid(text[]) to service_role;

create table public.privacy_identity_verification_attempts (
  privacy_identity_verification_attempt_id uuid primary key default gen_random_uuid(),
  privacy_request_id uuid not null,
  tenant_id uuid not null,
  agency_id uuid not null,
  idempotency_key uuid not null,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  attempt_number integer not null check (attempt_number between 1 and 5),
  outcome public.privacy_identity_verification_outcome not null,
  adapter_id text not null check (adapter_id ~ '^[A-Za-z0-9_.:-]{3,100}$'),
  adapter_version text not null check (adapter_version ~ '^[A-Za-z0-9_.:-]{1,100}$'),
  policy_version text not null check (policy_version ~ '^[A-Za-z0-9_.:-]{3,100}$'),
  evidence_ref text not null check (evidence_ref ~ '^[A-Za-z0-9_.:-]{3,200}$'),
  reason_codes text[] not null default '{}',
  attempted_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id, privacy_request_id)
    references public.privacy_requests(tenant_id, agency_id, privacy_request_id),
  unique (privacy_request_id, idempotency_key),
  unique (privacy_request_id, attempt_number),
  check (private.privacy_reason_codes_valid(reason_codes))
);

create index privacy_identity_attempts_tenant_idx
  on public.privacy_identity_verification_attempts (
    tenant_id, agency_id, privacy_request_id, attempted_at desc
  );

alter table public.privacy_identity_verification_attempts enable row level security;

create policy privacy_identity_attempts_admin_select
on public.privacy_identity_verification_attempts
for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
);

revoke all on public.privacy_identity_verification_attempts from anon, authenticated;
grant select on public.privacy_identity_verification_attempts to authenticated;

create or replace function private.prevent_privacy_identity_attempt_mutation()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  raise exception using errcode = '22023', message = 'PRIVACY_IDENTITY_ATTEMPT_IMMUTABLE';
  return null;
end
$$;

revoke all on function private.prevent_privacy_identity_attempt_mutation() from public;

create trigger privacy_identity_attempt_immutable
before update or delete on public.privacy_identity_verification_attempts
for each row execute function private.prevent_privacy_identity_attempt_mutation();

create or replace function private.settle_privacy_identity_verification_impl(
  p_hostname text,
  p_public_reference uuid,
  p_status_token_hash text,
  p_idempotency_key uuid,
  p_request_hash text,
  p_outcome public.privacy_identity_verification_outcome,
  p_adapter_id text,
  p_adapter_version text,
  p_policy_version text,
  p_evidence_ref text,
  p_reason_codes text[]
)
returns table (
  public_reference uuid,
  state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state,
  verification_outcome public.privacy_identity_verification_outcome
)
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_host public.tenant_hosts;
  v_request public.privacy_requests;
  v_existing public.privacy_identity_verification_attempts;
  v_attempt_number integer;
  v_reason_codes text[];
  v_event_type text;
  v_integrity_hash text;
begin
  if p_public_reference is null
     or p_idempotency_key is null
     or p_outcome is null
     or p_status_token_hash is null
     or p_status_token_hash !~ '^[0-9a-f]{64}$'
     or p_request_hash is null
     or p_request_hash !~ '^[0-9a-f]{64}$'
     or p_adapter_id is null
     or p_adapter_id !~ '^[A-Za-z0-9_.:-]{3,100}$'
     or p_adapter_version is null
     or p_adapter_version !~ '^[A-Za-z0-9_.:-]{1,100}$'
     or p_policy_version is null
     or p_policy_version !~ '^[A-Za-z0-9_.:-]{3,100}$'
     or p_evidence_ref is null
     or p_evidence_ref !~ '^[A-Za-z0-9_.:-]{3,200}$'
     or p_reason_codes is null
     or cardinality(p_reason_codes) < 1
     or cardinality(p_reason_codes) > (case
       when p_outcome = 'FAILED' then 11
       else 12
     end)
     or exists (
       select 1 from unnest(p_reason_codes) code
       where code !~ '^[A-Z0-9_:-]{1,120}$'
     ) then
    raise exception using errcode = '22023', message = 'PRIVACY_IDENTITY_VERIFICATION_INPUT_INVALID';
  end if;

  select * into v_host
  from public.tenant_hosts
  where hostname = lower(split_part(trim(p_hostname), ':', 1))
    and status = 'ACTIVE';

  if not found then
    raise exception using errcode = 'P0002', message = 'PRIVACY_REQUEST_NOT_FOUND';
  end if;

  select pr.* into v_request
  from public.privacy_requests pr
  join public.privacy_request_intake_evidence pie
    on pie.tenant_id = pr.tenant_id
   and pie.agency_id = pr.agency_id
   and pie.privacy_request_id = pr.privacy_request_id
  where pr.tenant_id = v_host.tenant_id
    and pr.agency_id = v_host.agency_id
    and pr.public_reference = p_public_reference
    and pie.status_token_hash = p_status_token_hash
  for update of pr;

  if not found then
    raise exception using errcode = 'P0002', message = 'PRIVACY_REQUEST_NOT_FOUND';
  end if;

  select * into v_existing
  from public.privacy_identity_verification_attempts
  where privacy_request_id = v_request.privacy_request_id
    and idempotency_key = p_idempotency_key;

  if found then
    if v_existing.request_hash <> p_request_hash
       or v_existing.adapter_id <> p_adapter_id
       or v_existing.adapter_version <> p_adapter_version
       or v_existing.policy_version <> p_policy_version
       or v_existing.outcome <> p_outcome then
      raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUEST_MISMATCH';
    end if;

    return query select
      v_request.public_reference,
      v_request.state,
      v_request.identity_verification_state,
      v_existing.outcome;
    return;
  end if;

  if v_request.identity_verification_state = 'VERIFIED' then
    raise exception using errcode = '55000', message = 'PRIVACY_IDENTITY_ALREADY_VERIFIED';
  end if;

  if v_request.identity_verification_state in ('FAILED', 'EXPIRED') then
    raise exception using errcode = '55000', message = 'PRIVACY_IDENTITY_VERIFICATION_LOCKED';
  end if;

  if v_request.state <> 'IDENTITY_VERIFICATION_PENDING'
     or v_request.identity_verification_state <> 'PENDING' then
    raise exception using errcode = '55000', message = 'PRIVACY_IDENTITY_VERIFICATION_STATE_INVALID';
  end if;

  select count(*)::integer + 1 into v_attempt_number
  from public.privacy_identity_verification_attempts
  where privacy_request_id = v_request.privacy_request_id;

  if v_attempt_number > 5 then
    raise exception using errcode = '55000', message = 'PRIVACY_IDENTITY_VERIFICATION_LOCKED';
  end if;

  v_reason_codes := p_reason_codes;
  if p_outcome = 'FAILED' and v_attempt_number = 5 then
    v_reason_codes := array_append(v_reason_codes, 'MAX_ATTEMPTS_EXCEEDED');
  end if;

  insert into public.privacy_identity_verification_attempts (
    privacy_request_id, tenant_id, agency_id, idempotency_key, request_hash,
    attempt_number, outcome, adapter_id, adapter_version, policy_version,
    evidence_ref, reason_codes
  ) values (
    v_request.privacy_request_id, v_request.tenant_id, v_request.agency_id,
    p_idempotency_key, p_request_hash, v_attempt_number, p_outcome,
    p_adapter_id, p_adapter_version, p_policy_version, p_evidence_ref,
    v_reason_codes
  );

  if p_outcome = 'VERIFIED' then
    update public.privacy_requests
    set state = 'IDENTITY_VERIFIED',
        identity_verification_state = 'VERIFIED',
        identity_verified_at = now(),
        identity_evidence_ref = p_evidence_ref,
        updated_at = now()
    where privacy_request_id = v_request.privacy_request_id
    returning * into v_request;
    v_event_type := 'PRIVACY_IDENTITY_VERIFIED';
  else
    update public.privacy_requests as pr
    set identity_verification_state = case
          when v_attempt_number = 5 then 'FAILED'::public.privacy_identity_state
          else pr.identity_verification_state
        end,
        updated_at = now()
    where pr.privacy_request_id = v_request.privacy_request_id
    returning pr.* into v_request;
    v_event_type := 'PRIVACY_IDENTITY_VERIFICATION_FAILED';
  end if;

  v_integrity_hash := encode(digest(concat_ws('|',
    v_request.tenant_id::text,
    v_request.privacy_request_id::text,
    p_idempotency_key::text,
    p_outcome::text,
    p_adapter_id,
    p_adapter_version,
    p_policy_version,
    v_attempt_number::text,
    clock_timestamp()::text
  ), 'sha256'), 'hex');

  insert into public.audit_events (
    tenant_id, agency_id, event_type, subject_ref, configuration_version_ref,
    policy_version_refs, outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_request.tenant_id, v_request.agency_id, v_event_type,
    'privacy-request:' || v_request.public_reference::text,
    v_host.tenant_configuration_version::text, array[p_policy_version],
    p_outcome::text, v_reason_codes, v_integrity_hash,
    jsonb_build_object(
      'adapter_id', p_adapter_id,
      'adapter_version', p_adapter_version,
      'attempt_number', v_attempt_number
    )
  );

  return query select
    v_request.public_reference,
    v_request.state,
    v_request.identity_verification_state,
    p_outcome;
end
$$;

revoke all on function private.settle_privacy_identity_verification_impl(
  text, uuid, text, uuid, text, public.privacy_identity_verification_outcome,
  text, text, text, text, text[]
) from public;
grant execute on function private.settle_privacy_identity_verification_impl(
  text, uuid, text, uuid, text, public.privacy_identity_verification_outcome,
  text, text, text, text, text[]
) to service_role;

create or replace function public.settle_privacy_identity_verification(
  p_hostname text,
  p_public_reference uuid,
  p_status_token_hash text,
  p_idempotency_key uuid,
  p_request_hash text,
  p_outcome public.privacy_identity_verification_outcome,
  p_adapter_id text,
  p_adapter_version text,
  p_policy_version text,
  p_evidence_ref text,
  p_reason_codes text[]
)
returns table (
  public_reference uuid,
  state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state,
  verification_outcome public.privacy_identity_verification_outcome
)
language sql
security invoker
set search_path = public, private
as $$
  select * from private.settle_privacy_identity_verification_impl(
    p_hostname, p_public_reference, p_status_token_hash, p_idempotency_key,
    p_request_hash, p_outcome, p_adapter_id, p_adapter_version,
    p_policy_version, p_evidence_ref, p_reason_codes
  )
$$;

revoke all on function public.settle_privacy_identity_verification(
  text, uuid, text, uuid, text, public.privacy_identity_verification_outcome,
  text, text, text, text, text[]
) from public, anon, authenticated;
grant execute on function public.settle_privacy_identity_verification(
  text, uuid, text, uuid, text, public.privacy_identity_verification_outcome,
  text, text, text, text, text[]
) to service_role;
