-- Slice 3: provider-neutral consumer driver, vehicle, and coverage intake.

create type public.confirmation_state as enum ('UNCONFIRMED','CONFIRMED','CORRECTED');
create type public.input_source_type as enum ('CONSUMER','AGENT','PREFILL','PROVIDER');

create table public.drivers (
  driver_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  quote_case_id uuid not null,
  person_id uuid,
  relationship_role text not null,
  first_name text not null,
  last_name text not null,
  date_of_birth date not null,
  license_jurisdiction text not null,
  license_identifier_ciphertext bytea,
  license_identifier_key_version text,
  license_identifier_lookup_hash text,
  license_last4 text,
  license_status text,
  years_licensed integer check (years_licensed is null or years_licensed >= 0),
  confirmation_state public.confirmation_state not null default 'UNCONFIRMED',
  source_type public.input_source_type not null default 'CONSUMER',
  source_ref text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  foreign key (tenant_id, quote_case_id) references public.quote_cases(tenant_id, quote_case_id),
  foreign key (person_id) references public.people(person_id),
  check (
    (license_identifier_ciphertext is null and license_identifier_key_version is null and license_identifier_lookup_hash is null)
    or
    (license_identifier_ciphertext is not null and license_identifier_key_version is not null and license_identifier_lookup_hash is not null)
  )
);

create index drivers_quote_case_idx on public.drivers (tenant_id, quote_case_id, created_at);
create index drivers_license_lookup_idx on public.drivers (tenant_id, license_identifier_lookup_hash)
  where license_identifier_lookup_hash is not null;

create table public.vehicles (
  vehicle_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  quote_case_id uuid not null,
  vin_ciphertext bytea,
  vin_key_version text,
  vin_lookup_hash text,
  vin_last4 text,
  model_year integer not null check (model_year between 1900 and 2100),
  make text not null,
  model text not null,
  trim text,
  ownership_state text,
  garaging_postal_code text,
  usage text not null,
  annual_mileage integer check (annual_mileage is null or annual_mileage >= 0),
  confirmation_state public.confirmation_state not null default 'UNCONFIRMED',
  source_type public.input_source_type not null default 'CONSUMER',
  source_ref text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  foreign key (tenant_id, quote_case_id) references public.quote_cases(tenant_id, quote_case_id),
  check (
    (vin_ciphertext is null and vin_key_version is null and vin_lookup_hash is null)
    or
    (vin_ciphertext is not null and vin_key_version is not null and vin_lookup_hash is not null)
  )
);

create index vehicles_quote_case_idx on public.vehicles (tenant_id, quote_case_id, created_at);
create index vehicles_vin_lookup_idx on public.vehicles (tenant_id, vin_lookup_hash)
  where vin_lookup_hash is not null;

create table public.coverage_requests (
  coverage_request_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  quote_case_id uuid not null,
  schema_version integer not null default 1 check (schema_version > 0),
  requested_limits jsonb not null default '{}'::jsonb,
  preferences jsonb not null default '{}'::jsonb,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, quote_case_id),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  foreign key (tenant_id, quote_case_id) references public.quote_cases(tenant_id, quote_case_id)
);

alter table public.drivers enable row level security;
alter table public.vehicles enable row level security;
alter table public.coverage_requests enable row level security;

create policy drivers_consumer_select on public.drivers
for select to authenticated
using (private.has_consumer_quote_access(quote_case_id));

create policy vehicles_consumer_select on public.vehicles
for select to authenticated
using (private.has_consumer_quote_access(quote_case_id));

create policy coverage_requests_consumer_select on public.coverage_requests
for select to authenticated
using (private.has_consumer_quote_access(quote_case_id));

revoke all on public.drivers from anon, authenticated;
revoke all on public.vehicles from anon, authenticated;
revoke all on public.coverage_requests from anon, authenticated;
grant select on public.drivers to authenticated;
grant select on public.vehicles to authenticated;
grant select on public.coverage_requests to authenticated;

create or replace function private.replace_consumer_drivers_impl(
  p_quote_case_id uuid,
  p_drivers jsonb
)
returns setof public.drivers
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_case public.quote_cases;
  v_item jsonb;
  v_driver public.drivers;
  v_hash text;
begin
  if not private.has_consumer_quote_access(p_quote_case_id) then
    raise exception using errcode = '42501', message = 'CONSUMER_QUOTE_ACCESS_DENIED';
  end if;

  if jsonb_typeof(p_drivers) <> 'array' or jsonb_array_length(p_drivers) > 12 then
    raise exception using errcode = '22023', message = 'DRIVER_COLLECTION_INVALID';
  end if;

  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'QUOTE_CASE_NOT_FOUND';
  end if;

  delete from public.drivers where quote_case_id = p_quote_case_id and source_type = 'CONSUMER';

  for v_item in select value from jsonb_array_elements(p_drivers)
  loop
    insert into public.drivers (
      tenant_id, agency_id, quote_case_id, relationship_role,
      first_name, last_name, date_of_birth, license_jurisdiction,
      license_identifier_ciphertext, license_identifier_key_version,
      license_identifier_lookup_hash, license_last4, years_licensed,
      confirmation_state, source_type
    ) values (
      v_case.tenant_id,
      v_case.agency_id,
      p_quote_case_id,
      v_item->>'relationshipRole',
      v_item->>'firstName',
      v_item->>'lastName',
      (v_item->>'dateOfBirth')::date,
      v_item->>'licenseJurisdiction',
      case when nullif(v_item->>'licenseCiphertextHex','') is null then null else decode(v_item->>'licenseCiphertextHex','hex') end,
      nullif(v_item->>'licenseKeyVersion',''),
      nullif(v_item->>'licenseLookupHash',''),
      nullif(v_item->>'licenseLast4',''),
      case when v_item ? 'yearsLicensed' and (v_item->>'yearsLicensed') <> '' then (v_item->>'yearsLicensed')::integer else null end,
      coalesce((v_item->>'confirmationState')::public.confirmation_state, 'CONFIRMED'),
      'CONSUMER'
    ) returning * into v_driver;
  end loop;

  v_hash := encode(extensions.digest(concat_ws('|', v_case.tenant_id::text, p_quote_case_id::text, 'CONSUMER_DRIVERS_REPLACED', clock_timestamp()::text),'sha256'),'hex');
  insert into public.audit_events (
    tenant_id, agency_id, quote_case_id, event_type, actor_id, subject_ref,
    configuration_version_ref, outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_case.tenant_id, v_case.agency_id, p_quote_case_id, 'CONSUMER_DRIVERS_REPLACED', auth.uid(),
    'consumer:' || auth.uid()::text, v_case.tenant_configuration_version::text,
    'SUCCEEDED', '{}', v_hash, jsonb_build_object('count', jsonb_array_length(p_drivers))
  );

  return query select * from public.drivers d where d.quote_case_id = p_quote_case_id order by d.created_at, d.driver_id;
end
$$;

create or replace function private.replace_consumer_vehicles_impl(
  p_quote_case_id uuid,
  p_vehicles jsonb
)
returns setof public.vehicles
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_case public.quote_cases;
  v_item jsonb;
  v_vehicle public.vehicles;
  v_hash text;
begin
  if not private.has_consumer_quote_access(p_quote_case_id) then
    raise exception using errcode = '42501', message = 'CONSUMER_QUOTE_ACCESS_DENIED';
  end if;

  if jsonb_typeof(p_vehicles) <> 'array' or jsonb_array_length(p_vehicles) > 12 then
    raise exception using errcode = '22023', message = 'VEHICLE_COLLECTION_INVALID';
  end if;

  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'QUOTE_CASE_NOT_FOUND';
  end if;

  delete from public.vehicles where quote_case_id = p_quote_case_id and source_type = 'CONSUMER';

  for v_item in select value from jsonb_array_elements(p_vehicles)
  loop
    insert into public.vehicles (
      tenant_id, agency_id, quote_case_id,
      vin_ciphertext, vin_key_version, vin_lookup_hash, vin_last4,
      model_year, make, model, trim, ownership_state, garaging_postal_code,
      usage, annual_mileage, confirmation_state, source_type
    ) values (
      v_case.tenant_id,
      v_case.agency_id,
      p_quote_case_id,
      case when nullif(v_item->>'vinCiphertextHex','') is null then null else decode(v_item->>'vinCiphertextHex','hex') end,
      nullif(v_item->>'vinKeyVersion',''),
      nullif(v_item->>'vinLookupHash',''),
      nullif(v_item->>'vinLast4',''),
      (v_item->>'modelYear')::integer,
      v_item->>'make',
      v_item->>'model',
      nullif(v_item->>'trim',''),
      nullif(v_item->>'ownershipState',''),
      nullif(v_item->>'garagingPostalCode',''),
      v_item->>'usage',
      case when v_item ? 'annualMileage' and (v_item->>'annualMileage') <> '' then (v_item->>'annualMileage')::integer else null end,
      coalesce((v_item->>'confirmationState')::public.confirmation_state, 'CONFIRMED'),
      'CONSUMER'
    ) returning * into v_vehicle;
  end loop;

  v_hash := encode(extensions.digest(concat_ws('|', v_case.tenant_id::text, p_quote_case_id::text, 'CONSUMER_VEHICLES_REPLACED', clock_timestamp()::text),'sha256'),'hex');
  insert into public.audit_events (
    tenant_id, agency_id, quote_case_id, event_type, actor_id, subject_ref,
    configuration_version_ref, outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_case.tenant_id, v_case.agency_id, p_quote_case_id, 'CONSUMER_VEHICLES_REPLACED', auth.uid(),
    'consumer:' || auth.uid()::text, v_case.tenant_configuration_version::text,
    'SUCCEEDED', '{}', v_hash, jsonb_build_object('count', jsonb_array_length(p_vehicles))
  );

  return query select * from public.vehicles v where v.quote_case_id = p_quote_case_id order by v.created_at, v.vehicle_id;
end
$$;

create or replace function private.upsert_consumer_coverage_request_impl(
  p_quote_case_id uuid,
  p_schema_version integer,
  p_requested_limits jsonb,
  p_preferences jsonb,
  p_notes text
)
returns public.coverage_requests
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_case public.quote_cases;
  v_created public.coverage_requests;
  v_hash text;
begin
  if not private.has_consumer_quote_access(p_quote_case_id) then
    raise exception using errcode = '42501', message = 'CONSUMER_QUOTE_ACCESS_DENIED';
  end if;

  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'QUOTE_CASE_NOT_FOUND';
  end if;

  insert into public.coverage_requests (
    tenant_id, agency_id, quote_case_id, schema_version, requested_limits, preferences, notes
  ) values (
    v_case.tenant_id, v_case.agency_id, p_quote_case_id, p_schema_version,
    coalesce(p_requested_limits, '{}'::jsonb), coalesce(p_preferences, '{}'::jsonb), p_notes
  )
  on conflict (tenant_id, quote_case_id) do update set
    schema_version = excluded.schema_version,
    requested_limits = excluded.requested_limits,
    preferences = excluded.preferences,
    notes = excluded.notes,
    updated_at = now()
  returning * into v_created;

  v_hash := encode(extensions.digest(concat_ws('|', v_case.tenant_id::text, p_quote_case_id::text, 'CONSUMER_COVERAGE_REQUEST_SAVED', clock_timestamp()::text),'sha256'),'hex');
  insert into public.audit_events (
    tenant_id, agency_id, quote_case_id, event_type, actor_id, subject_ref,
    configuration_version_ref, outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_case.tenant_id, v_case.agency_id, p_quote_case_id, 'CONSUMER_COVERAGE_REQUEST_SAVED', auth.uid(),
    'consumer:' || auth.uid()::text, v_case.tenant_configuration_version::text,
    'SUCCEEDED', '{}', v_hash, jsonb_build_object('schema_version', p_schema_version)
  );

  return v_created;
end
$$;

alter function private.replace_consumer_drivers_impl(uuid, jsonb)
  set search_path = public, private, extensions;
alter function private.replace_consumer_vehicles_impl(uuid, jsonb)
  set search_path = public, private, extensions;

revoke all on function private.replace_consumer_drivers_impl(uuid, jsonb) from public;
revoke all on function private.replace_consumer_vehicles_impl(uuid, jsonb) from public;
revoke all on function private.upsert_consumer_coverage_request_impl(uuid, integer, jsonb, jsonb, text) from public;
grant execute on function private.replace_consumer_drivers_impl(uuid, jsonb) to authenticated;
grant execute on function private.replace_consumer_vehicles_impl(uuid, jsonb) to authenticated;
grant execute on function private.upsert_consumer_coverage_request_impl(uuid, integer, jsonb, jsonb, text) to authenticated;

create or replace function public.replace_consumer_drivers(p_quote_case_id uuid, p_drivers jsonb)
returns setof public.drivers
language sql
security invoker
set search_path = public, private
as $$ select * from private.replace_consumer_drivers_impl(p_quote_case_id, p_drivers) $$;

create or replace function public.replace_consumer_vehicles(p_quote_case_id uuid, p_vehicles jsonb)
returns setof public.vehicles
language sql
security invoker
set search_path = public, private
as $$ select * from private.replace_consumer_vehicles_impl(p_quote_case_id, p_vehicles) $$;

create or replace function public.upsert_consumer_coverage_request(
  p_quote_case_id uuid,
  p_schema_version integer,
  p_requested_limits jsonb,
  p_preferences jsonb,
  p_notes text
)
returns public.coverage_requests
language sql
security invoker
set search_path = public, private
as $$
  select private.upsert_consumer_coverage_request_impl(
    p_quote_case_id, p_schema_version, p_requested_limits, p_preferences, p_notes
  )
$$;

revoke all on function public.replace_consumer_drivers(uuid, jsonb) from public, anon;
revoke all on function public.replace_consumer_vehicles(uuid, jsonb) from public, anon;
revoke all on function public.upsert_consumer_coverage_request(uuid, integer, jsonb, jsonb, text) from public, anon;
grant execute on function public.replace_consumer_drivers(uuid, jsonb) to authenticated;
grant execute on function public.replace_consumer_vehicles(uuid, jsonb) to authenticated;
grant execute on function public.upsert_consumer_coverage_request(uuid, integer, jsonb, jsonb, text) to authenticated;
