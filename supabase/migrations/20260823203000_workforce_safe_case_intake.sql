-- Workforce-safe case intake projection for agent review.
-- Protected identifier ciphertext and lookup hashes never leave SQL.

create or replace function private.get_workforce_case_intake_impl(p_quote_case_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private
as $$
declare
  v_case public.quote_cases;
begin
  select * into v_case
  from public.quote_cases
  where quote_case_id = p_quote_case_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'QUOTE_CASE_NOT_FOUND';
  end if;

  if not private.has_permission(v_case.tenant_id, v_case.agency_id, 'CASE_READ') then
    raise exception using errcode = '42501', message = 'CASE_READ_NOT_PERMITTED';
  end if;

  return jsonb_build_object(
    'drivers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'driverId', d.driver_id,
        'relationshipRole', d.relationship_role,
        'firstName', d.first_name,
        'lastName', d.last_name,
        'dateOfBirth', d.date_of_birth,
        'licenseJurisdiction', d.license_jurisdiction,
        'licenseLast4', d.license_last4,
        'licenseStatus', d.license_status,
        'yearsLicensed', d.years_licensed,
        'confirmationState', d.confirmation_state,
        'sourceType', d.source_type,
        'sourceRef', d.source_ref
      ) order by d.created_at, d.driver_id)
      from public.drivers d
      where d.quote_case_id = p_quote_case_id
    ), '[]'::jsonb),
    'vehicles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'vehicleId', v.vehicle_id,
        'vinLast4', v.vin_last4,
        'modelYear', v.model_year,
        'make', v.make,
        'model', v.model,
        'trim', v.trim,
        'ownershipState', v.ownership_state,
        'garagingPostalCode', v.garaging_postal_code,
        'usage', v.usage,
        'annualMileage', v.annual_mileage,
        'confirmationState', v.confirmation_state,
        'sourceType', v.source_type,
        'sourceRef', v.source_ref
      ) order by v.created_at, v.vehicle_id)
      from public.vehicles v
      where v.quote_case_id = p_quote_case_id
    ), '[]'::jsonb),
    'coverageRequest', (
      select jsonb_build_object(
        'coverageRequestId', c.coverage_request_id,
        'schemaVersion', c.schema_version,
        'requestedLimits', c.requested_limits,
        'preferences', c.preferences,
        'notes', c.notes,
        'updatedAt', c.updated_at
      )
      from public.coverage_requests c
      where c.quote_case_id = p_quote_case_id
      limit 1
    )
  );
end
$$;

revoke all on function private.get_workforce_case_intake_impl(uuid) from public;
grant execute on function private.get_workforce_case_intake_impl(uuid) to authenticated;

create or replace function public.get_workforce_case_intake(p_quote_case_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = public, private
as $$
  select private.get_workforce_case_intake_impl(p_quote_case_id)
$$;

revoke all on function public.get_workforce_case_intake(uuid) from public, anon;
grant execute on function public.get_workforce_case_intake(uuid) to authenticated;
