-- Slice 2: protected consumer identity payload + authenticated resume grants.

alter table public.prospects
  add column if not exists person_id uuid;

create table public.person_private_profiles (
  person_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  encrypted_payload bytea not null,
  encryption_algorithm text not null check (encryption_algorithm = 'AES-256-GCM'),
  key_version text not null,
  payload_version integer not null default 1 check (payload_version > 0),
  email_lookup_hash text,
  phone_lookup_hash text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id)
);

create index person_private_profiles_tenant_idx
  on public.person_private_profiles (tenant_id, agency_id, person_id);
create index person_private_profiles_email_hash_idx
  on public.person_private_profiles (tenant_id, email_lookup_hash)
  where email_lookup_hash is not null;
create index person_private_profiles_phone_hash_idx
  on public.person_private_profiles (tenant_id, phone_lookup_hash)
  where phone_lookup_hash is not null;

alter table public.prospects
  add constraint prospects_person_fk
  foreign key (person_id) references public.person_private_profiles(person_id);

create table public.consumer_resume_grants (
  resume_grant_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  quote_case_id uuid not null,
  consumer_identity_id uuid not null,
  status public.consumer_access_status not null default 'ACTIVE',
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at timestamptz,
  revoked_at timestamptz,
  risk_context jsonb not null default '{}'::jsonb,
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  foreign key (tenant_id, quote_case_id) references public.quote_cases(tenant_id, quote_case_id),
  check (expires_at > issued_at)
);

create index consumer_resume_grants_identity_idx
  on public.consumer_resume_grants (consumer_identity_id, status, expires_at desc);
create index consumer_resume_grants_case_idx
  on public.consumer_resume_grants (tenant_id, quote_case_id, status, expires_at desc);

alter table public.person_private_profiles enable row level security;
alter table public.consumer_resume_grants enable row level security;

-- No direct consumer or workforce Data API access to encrypted identity payloads.
-- Access occurs only through narrow checked RPCs/application services.
revoke all on public.person_private_profiles from anon, authenticated;
revoke all on public.consumer_resume_grants from anon, authenticated;

create or replace function private.upsert_consumer_identity_impl(
  p_quote_case_id uuid,
  p_encrypted_payload bytea,
  p_key_version text,
  p_email_lookup_hash text,
  p_phone_lookup_hash text
)
returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_case public.quote_cases;
  v_person_id uuid;
begin
  if auth.uid() is null or not private.has_consumer_quote_access(p_quote_case_id) then
    raise exception using errcode = '42501', message = 'CONSUMER_QUOTE_ACCESS_DENIED';
  end if;

  select * into v_case
  from public.quote_cases
  where quote_case_id = p_quote_case_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'QUOTE_CASE_NOT_FOUND';
  end if;

  select p.person_id into v_person_id
  from public.prospects p
  where p.prospect_id = v_case.prospect_id;

  if v_person_id is null then
    insert into public.person_private_profiles (
      tenant_id, agency_id, encrypted_payload, encryption_algorithm,
      key_version, email_lookup_hash, phone_lookup_hash
    ) values (
      v_case.tenant_id, v_case.agency_id, p_encrypted_payload, 'AES-256-GCM',
      p_key_version, p_email_lookup_hash, p_phone_lookup_hash
    ) returning person_id into v_person_id;

    update public.prospects
    set person_id = v_person_id,
        updated_at = now()
    where prospect_id = v_case.prospect_id;
  else
    update public.person_private_profiles
    set encrypted_payload = p_encrypted_payload,
        key_version = p_key_version,
        email_lookup_hash = p_email_lookup_hash,
        phone_lookup_hash = p_phone_lookup_hash,
        payload_version = payload_version + 1,
        updated_at = now()
    where person_id = v_person_id
      and tenant_id = v_case.tenant_id;
  end if;

  insert into public.audit_events (
    tenant_id, agency_id, quote_case_id, event_type, actor_id, subject_ref,
    configuration_version_ref, outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_case.tenant_id, v_case.agency_id, v_case.quote_case_id,
    'CONSUMER_IDENTITY_UPDATED', auth.uid(), 'person:' || v_person_id::text,
    v_case.tenant_configuration_version::text, 'SUCCEEDED', '{}',
    encode(digest(concat_ws('|', v_case.quote_case_id::text, v_person_id::text, clock_timestamp()::text), 'sha256'), 'hex'),
    jsonb_build_object('payload_version_incremented', true, 'key_version', p_key_version)
  );

  return v_person_id;
end
$$;

revoke all on function private.upsert_consumer_identity_impl(uuid, bytea, text, text, text) from public;
grant execute on function private.upsert_consumer_identity_impl(uuid, bytea, text, text, text) to authenticated;

create or replace function public.upsert_consumer_identity(
  p_quote_case_id uuid,
  p_encrypted_payload bytea,
  p_key_version text,
  p_email_lookup_hash text,
  p_phone_lookup_hash text
)
returns uuid
language sql
security invoker
set search_path = public, private
as $$
  select private.upsert_consumer_identity_impl(
    p_quote_case_id, p_encrypted_payload, p_key_version,
    p_email_lookup_hash, p_phone_lookup_hash
  )
$$;

revoke all on function public.upsert_consumer_identity(uuid, bytea, text, text, text) from public, anon;
grant execute on function public.upsert_consumer_identity(uuid, bytea, text, text, text) to authenticated;

create or replace function private.create_consumer_resume_grant_impl(
  p_quote_case_id uuid,
  p_ttl_minutes integer default 60
)
returns public.consumer_resume_grants
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_case public.quote_cases;
  v_grant public.consumer_resume_grants;
begin
  if auth.uid() is null or not private.has_consumer_quote_access(p_quote_case_id) then
    raise exception using errcode = '42501', message = 'CONSUMER_QUOTE_ACCESS_DENIED';
  end if;

  if p_ttl_minutes < 5 or p_ttl_minutes > 1440 then
    raise exception using errcode = '22023', message = 'RESUME_TTL_OUT_OF_RANGE';
  end if;

  select * into v_case
  from public.quote_cases
  where quote_case_id = p_quote_case_id;

  insert into public.consumer_resume_grants (
    tenant_id, agency_id, quote_case_id, consumer_identity_id, expires_at
  ) values (
    v_case.tenant_id, v_case.agency_id, v_case.quote_case_id, auth.uid(),
    now() + make_interval(mins => p_ttl_minutes)
  ) returning * into v_grant;

  return v_grant;
end
$$;

revoke all on function private.create_consumer_resume_grant_impl(uuid, integer) from public;
grant execute on function private.create_consumer_resume_grant_impl(uuid, integer) to authenticated;

create or replace function public.create_consumer_resume_grant(
  p_quote_case_id uuid,
  p_ttl_minutes integer default 60
)
returns public.consumer_resume_grants
language sql
security invoker
set search_path = public, private
as $$
  select private.create_consumer_resume_grant_impl(p_quote_case_id, p_ttl_minutes)
$$;

revoke all on function public.create_consumer_resume_grant(uuid, integer) from public, anon;
grant execute on function public.create_consumer_resume_grant(uuid, integer) to authenticated;

create or replace function private.consume_consumer_resume_grant_impl(p_resume_grant_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_grant public.consumer_resume_grants;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'CONSUMER_AUTHENTICATION_REQUIRED';
  end if;

  select * into v_grant
  from public.consumer_resume_grants
  where resume_grant_id = p_resume_grant_id
  for update;

  if not found
    or v_grant.consumer_identity_id <> auth.uid()
    or v_grant.status <> 'ACTIVE'
    or v_grant.expires_at <= now()
    or v_grant.used_at is not null
  then
    raise exception using errcode = '42501', message = 'RESUME_GRANT_INVALID';
  end if;

  if not private.has_consumer_quote_access(v_grant.quote_case_id) then
    raise exception using errcode = '42501', message = 'CONSUMER_QUOTE_ACCESS_DENIED';
  end if;

  update public.consumer_resume_grants
  set used_at = now(), status = 'EXPIRED'
  where resume_grant_id = p_resume_grant_id;

  return v_grant.quote_case_id;
end
$$;

revoke all on function private.consume_consumer_resume_grant_impl(uuid) from public;
grant execute on function private.consume_consumer_resume_grant_impl(uuid) to authenticated;

create or replace function public.consume_consumer_resume_grant(p_resume_grant_id uuid)
returns uuid
language sql
security invoker
set search_path = public, private
as $$
  select private.consume_consumer_resume_grant_impl(p_resume_grant_id)
$$;

revoke all on function public.consume_consumer_resume_grant(uuid) from public, anon;
grant execute on function public.consume_consumer_resume_grant(uuid) to authenticated;
