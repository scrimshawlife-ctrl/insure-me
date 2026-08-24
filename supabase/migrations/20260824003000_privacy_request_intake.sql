-- T800: existence-safe privacy request intake and requester-safe status lookup.

alter table public.privacy_requests
  add constraint privacy_requests_tenant_agency_id_unique
  unique (tenant_id, agency_id, privacy_request_id);

create table public.privacy_request_intake_evidence (
  privacy_request_id uuid primary key,
  tenant_id uuid not null,
  agency_id uuid not null,
  encrypted_requester_payload bytea not null,
  encryption_algorithm text not null check (encryption_algorithm = 'AES-256-GCM'),
  key_version text not null,
  email_lookup_hash text not null check (length(email_lookup_hash) = 64),
  phone_lookup_hash text check (phone_lookup_hash is null or length(phone_lookup_hash) = 64),
  request_hash text not null check (length(request_hash) = 64),
  status_token_hash text not null check (length(status_token_hash) = 64),
  created_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id, privacy_request_id)
    references public.privacy_requests(tenant_id, agency_id, privacy_request_id) on delete cascade,
  unique (tenant_id, status_token_hash)
);

create index privacy_request_intake_email_idx
  on public.privacy_request_intake_evidence (tenant_id, agency_id, email_lookup_hash);

alter table public.privacy_request_intake_evidence enable row level security;
revoke all on public.privacy_request_intake_evidence from anon, authenticated;

create or replace function private.create_privacy_request_impl(
  p_hostname text,
  p_request_type public.privacy_request_type,
  p_jurisdiction text,
  p_intake_channel text,
  p_encrypted_requester_payload bytea,
  p_key_version text,
  p_email_lookup_hash text,
  p_phone_lookup_hash text,
  p_request_hash text,
  p_status_token_hash text,
  p_idempotency_key uuid
)
returns table (
  public_reference uuid,
  state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state
)
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_host public.tenant_hosts;
  v_config public.tenant_configurations;
  v_existing public.idempotency_keys;
  v_request public.privacy_requests;
  v_integrity_hash text;
begin
  if p_request_type is null
     or p_encrypted_requester_payload is null
     or p_key_version is null
     or p_email_lookup_hash is null
     or p_request_hash is null
     or p_status_token_hash is null
     or p_jurisdiction <> 'CA'
     or p_intake_channel <> 'WEB'
     or octet_length(p_encrypted_requester_payload) not between 30 and 16384
     or char_length(trim(p_key_version)) not between 1 and 64
     or p_email_lookup_hash !~ '^[0-9a-f]{64}$'
     or (p_phone_lookup_hash is not null and p_phone_lookup_hash !~ '^[0-9a-f]{64}$')
     or p_request_hash !~ '^[0-9a-f]{64}$'
     or p_status_token_hash !~ '^[0-9a-f]{64}$'
     or p_idempotency_key is null then
    raise exception using errcode = '22023', message = 'PRIVACY_REQUEST_INPUT_INVALID';
  end if;

  select * into v_host
  from public.tenant_hosts
  where hostname = lower(split_part(trim(p_hostname), ':', 1))
    and status = 'ACTIVE';

  if not found then
    raise exception using errcode = '22023', message = 'TENANT_HOST_NOT_CONFIGURED';
  end if;

  select * into v_config
  from public.tenant_configurations
  where tenant_configuration_id = v_host.tenant_configuration_id
    and tenant_id = v_host.tenant_id
    and agency_id = v_host.agency_id
    and version = v_host.tenant_configuration_version
    and status = 'ACTIVE';

  if not found or not p_jurisdiction = any(v_config.enabled_jurisdictions) then
    raise exception using errcode = '22023', message = 'PRIVACY_INTAKE_NOT_CONFIGURED';
  end if;

  insert into public.idempotency_keys (
    tenant_id, scope, idempotency_key, request_hash, resource_type, status
  ) values (
    v_host.tenant_id, 'privacy-request-intake', p_idempotency_key::text,
    p_request_hash, 'PrivacyRequest', 'CLAIMED'
  )
  on conflict (tenant_id, scope, idempotency_key) do nothing;

  if not found then
    select * into v_existing
    from public.idempotency_keys
    where tenant_id = v_host.tenant_id
      and scope = 'privacy-request-intake'
      and idempotency_key = p_idempotency_key::text
    for update;

    if v_existing.request_hash <> p_request_hash then
      raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUEST_MISMATCH';
    end if;

    if v_existing.status <> 'SUCCEEDED' or v_existing.resource_id is null then
      raise exception using errcode = '55000', message = 'PRIVACY_REQUEST_IDEMPOTENCY_INCOMPLETE';
    end if;

    select * into v_request
    from public.privacy_requests
    where privacy_request_id = v_existing.resource_id
      and tenant_id = v_host.tenant_id;

    if not found then
      raise exception using errcode = '55000', message = 'PRIVACY_REQUEST_IDEMPOTENCY_INVALID';
    end if;

    if not exists (
      select 1 from public.privacy_request_intake_evidence
      where privacy_request_id = v_request.privacy_request_id
        and tenant_id = v_host.tenant_id
        and status_token_hash = p_status_token_hash
    ) then
      raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUEST_MISMATCH';
    end if;

    return query select
      v_request.public_reference,
      v_request.state,
      v_request.identity_verification_state;
    return;
  end if;

  insert into public.privacy_requests (
    tenant_id, agency_id, request_type, state, identity_verification_state,
    jurisdiction, intake_channel
  ) values (
    v_host.tenant_id, v_host.agency_id, p_request_type,
    'IDENTITY_VERIFICATION_PENDING', 'PENDING', p_jurisdiction,
    p_intake_channel
  ) returning * into v_request;

  insert into public.privacy_request_intake_evidence (
    privacy_request_id, tenant_id, agency_id, encrypted_requester_payload,
    encryption_algorithm, key_version, email_lookup_hash, phone_lookup_hash,
    request_hash, status_token_hash
  ) values (
    v_request.privacy_request_id, v_host.tenant_id, v_host.agency_id,
    p_encrypted_requester_payload, 'AES-256-GCM', trim(p_key_version),
    p_email_lookup_hash, p_phone_lookup_hash, p_request_hash, p_status_token_hash
  );

  update public.idempotency_keys
  set resource_id = v_request.privacy_request_id,
      status = 'SUCCEEDED',
      completed_at = now()
  where tenant_id = v_host.tenant_id
    and scope = 'privacy-request-intake'
    and idempotency_key = p_idempotency_key::text;

  v_integrity_hash := encode(digest(concat_ws('|',
    v_host.tenant_id::text,
    v_request.privacy_request_id::text,
    v_request.public_reference::text,
    p_request_type::text,
    'PRIVACY_REQUEST_RECEIVED',
    clock_timestamp()::text
  ), 'sha256'), 'hex');

  insert into public.audit_events (
    tenant_id, agency_id, event_type, subject_ref, configuration_version_ref,
    outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_host.tenant_id, v_host.agency_id, 'PRIVACY_REQUEST_RECEIVED',
    'privacy-request:' || v_request.public_reference::text,
    v_host.tenant_configuration_version::text, 'SUCCEEDED', '{}',
    v_integrity_hash,
    jsonb_build_object('request_type', p_request_type::text, 'intake_channel', p_intake_channel)
  );

  return query select
    v_request.public_reference,
    v_request.state,
    v_request.identity_verification_state;
end
$$;

revoke all on function private.create_privacy_request_impl(
  text, public.privacy_request_type, text, text, bytea, text, text, text,
  text, text, uuid
) from public;
grant execute on function private.create_privacy_request_impl(
  text, public.privacy_request_type, text, text, bytea, text, text, text,
  text, text, uuid
) to service_role;

create or replace function public.create_privacy_request(
  p_hostname text,
  p_request_type public.privacy_request_type,
  p_jurisdiction text,
  p_intake_channel text,
  p_encrypted_requester_payload bytea,
  p_key_version text,
  p_email_lookup_hash text,
  p_phone_lookup_hash text,
  p_request_hash text,
  p_status_token_hash text,
  p_idempotency_key uuid
)
returns table (
  public_reference uuid,
  state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state
)
language sql
security invoker
set search_path = public, private
as $$
  select * from private.create_privacy_request_impl(
    p_hostname, p_request_type, p_jurisdiction, p_intake_channel,
    p_encrypted_requester_payload, p_key_version, p_email_lookup_hash,
    p_phone_lookup_hash, p_request_hash, p_status_token_hash, p_idempotency_key
  )
$$;

revoke all on function public.create_privacy_request(
  text, public.privacy_request_type, text, text, bytea, text, text, text,
  text, text, uuid
) from public, anon, authenticated;
grant execute on function public.create_privacy_request(
  text, public.privacy_request_type, text, text, bytea, text, text, text,
  text, text, uuid
) to service_role;

create or replace function private.get_privacy_request_status_impl(
  p_hostname text,
  p_public_reference uuid,
  p_status_token_hash text
)
returns table (
  public_reference uuid,
  state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state
)
language sql
stable
security definer
set search_path = public, private
as $$
  select pr.public_reference, pr.state, pr.identity_verification_state
  from public.tenant_hosts th
  join public.privacy_requests pr
    on pr.tenant_id = th.tenant_id and pr.agency_id = th.agency_id
  join public.privacy_request_intake_evidence pie
    on pie.tenant_id = pr.tenant_id
   and pie.agency_id = pr.agency_id
   and pie.privacy_request_id = pr.privacy_request_id
  where th.hostname = lower(split_part(trim(p_hostname), ':', 1))
    and th.status = 'ACTIVE'
    and pr.public_reference = p_public_reference
    and pie.status_token_hash = p_status_token_hash
$$;

revoke all on function private.get_privacy_request_status_impl(text, uuid, text) from public;
grant execute on function private.get_privacy_request_status_impl(text, uuid, text) to service_role;

create or replace function public.get_privacy_request_status(
  p_hostname text,
  p_public_reference uuid,
  p_status_token_hash text
)
returns table (
  public_reference uuid,
  state public.privacy_request_state,
  identity_verification_state public.privacy_identity_state
)
language sql
stable
security invoker
set search_path = public, private
as $$
  select * from private.get_privacy_request_status_impl(
    p_hostname, p_public_reference, p_status_token_hash
  )
$$;

revoke all on function public.get_privacy_request_status(text, uuid, text)
from public, anon, authenticated;
grant execute on function public.get_privacy_request_status(text, uuid, text)
to service_role;
