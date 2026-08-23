-- Preserve protected driver license and VIN material when a consumer edits an existing
-- consumer-owned row without re-entering the sensitive identifier.

create or replace function private.replace_consumer_drivers_impl(
  p_quote_case_id uuid,
  p_drivers jsonb
)
returns setof public.drivers
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_case public.quote_cases;
  v_item jsonb;
  v_driver public.drivers;
  v_existing public.drivers;
  v_driver_id uuid;
  v_keep_ids uuid[] := '{}'::uuid[];
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

  for v_item in select value from jsonb_array_elements(p_drivers)
  loop
    if nullif(v_item->>'driverId','') is not null then
      v_driver_id := (v_item->>'driverId')::uuid;
      select * into v_existing
      from public.drivers
      where driver_id = v_driver_id
        and quote_case_id = p_quote_case_id
        and source_type = 'CONSUMER'
      for update;

      if not found then
        raise exception using errcode = '42501', message = 'CONSUMER_DRIVER_EDIT_DENIED';
      end if;

      update public.drivers set
        relationship_role = v_item->>'relationshipRole',
        first_name = v_item->>'firstName',
        last_name = v_item->>'lastName',
        date_of_birth = (v_item->>'dateOfBirth')::date,
        license_jurisdiction = v_item->>'licenseJurisdiction',
        license_identifier_ciphertext = case
          when nullif(v_item->>'licenseCiphertextHex','') is null then v_existing.license_identifier_ciphertext
          else decode(v_item->>'licenseCiphertextHex','hex')
        end,
        license_identifier_key_version = case
          when nullif(v_item->>'licenseCiphertextHex','') is null then v_existing.license_identifier_key_version
          else nullif(v_item->>'licenseKeyVersion','')
        end,
        license_identifier_lookup_hash = case
          when nullif(v_item->>'licenseCiphertextHex','') is null then v_existing.license_identifier_lookup_hash
          else nullif(v_item->>'licenseLookupHash','')
        end,
        license_last4 = case
          when nullif(v_item->>'licenseCiphertextHex','') is null then v_existing.license_last4
          else nullif(v_item->>'licenseLast4','')
        end,
        years_licensed = case when v_item ? 'yearsLicensed' and (v_item->>'yearsLicensed') <> '' then (v_item->>'yearsLicensed')::integer else null end,
        confirmation_state = coalesce((v_item->>'confirmationState')::public.confirmation_state, 'CONFIRMED'),
        updated_at = now()
      where driver_id = v_driver_id
      returning * into v_driver;
    else
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
      v_driver_id := v_driver.driver_id;
    end if;

    v_keep_ids := array_append(v_keep_ids, v_driver_id);
  end loop;

  delete from public.drivers
  where quote_case_id = p_quote_case_id
    and source_type = 'CONSUMER'
    and not (driver_id = any(v_keep_ids));

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
set search_path = public, private, extensions
as $$
declare
  v_case public.quote_cases;
  v_item jsonb;
  v_vehicle public.vehicles;
  v_existing public.vehicles;
  v_vehicle_id uuid;
  v_keep_ids uuid[] := '{}'::uuid[];
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

  for v_item in select value from jsonb_array_elements(p_vehicles)
  loop
    if nullif(v_item->>'vehicleId','') is not null then
      v_vehicle_id := (v_item->>'vehicleId')::uuid;
      select * into v_existing
      from public.vehicles
      where vehicle_id = v_vehicle_id
        and quote_case_id = p_quote_case_id
        and source_type = 'CONSUMER'
      for update;

      if not found then
        raise exception using errcode = '42501', message = 'CONSUMER_VEHICLE_EDIT_DENIED';
      end if;

      update public.vehicles set
        vin_ciphertext = case
          when nullif(v_item->>'vinCiphertextHex','') is null then v_existing.vin_ciphertext
          else decode(v_item->>'vinCiphertextHex','hex')
        end,
        vin_key_version = case
          when nullif(v_item->>'vinCiphertextHex','') is null then v_existing.vin_key_version
          else nullif(v_item->>'vinKeyVersion','')
        end,
        vin_lookup_hash = case
          when nullif(v_item->>'vinCiphertextHex','') is null then v_existing.vin_lookup_hash
          else nullif(v_item->>'vinLookupHash','')
        end,
        vin_last4 = case
          when nullif(v_item->>'vinCiphertextHex','') is null then v_existing.vin_last4
          else nullif(v_item->>'vinLast4','')
        end,
        model_year = (v_item->>'modelYear')::integer,
        make = v_item->>'make',
        model = v_item->>'model',
        trim = nullif(v_item->>'trim',''),
        ownership_state = nullif(v_item->>'ownershipState',''),
        garaging_postal_code = nullif(v_item->>'garagingPostalCode',''),
        usage = v_item->>'usage',
        annual_mileage = case when v_item ? 'annualMileage' and (v_item->>'annualMileage') <> '' then (v_item->>'annualMileage')::integer else null end,
        confirmation_state = coalesce((v_item->>'confirmationState')::public.confirmation_state, 'CONFIRMED'),
        updated_at = now()
      where vehicle_id = v_vehicle_id
      returning * into v_vehicle;
    else
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
      v_vehicle_id := v_vehicle.vehicle_id;
    end if;

    v_keep_ids := array_append(v_keep_ids, v_vehicle_id);
  end loop;

  delete from public.vehicles
  where quote_case_id = p_quote_case_id
    and source_type = 'CONSUMER'
    and not (vehicle_id = any(v_keep_ids));

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
