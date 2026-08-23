-- Slice 3 consumer-safe read projections. Sensitive ciphertext and lookup hashes never leave SQL.

create or replace function private.get_consumer_drivers_impl(p_quote_case_id uuid)
returns table (
  driver_id uuid,
  relationship_role text,
  first_name text,
  last_name text,
  date_of_birth date,
  license_jurisdiction text,
  license_last4 text,
  license_status text,
  years_licensed integer,
  confirmation_state public.confirmation_state,
  source_type public.input_source_type
)
language sql
stable
security definer
set search_path = public, private
as $$
  select d.driver_id, d.relationship_role, d.first_name, d.last_name, d.date_of_birth,
         d.license_jurisdiction, d.license_last4, d.license_status, d.years_licensed,
         d.confirmation_state, d.source_type
  from public.drivers d
  where d.quote_case_id = p_quote_case_id
    and private.has_consumer_quote_access(p_quote_case_id)
  order by d.created_at, d.driver_id
$$;

create or replace function private.get_consumer_vehicles_impl(p_quote_case_id uuid)
returns table (
  vehicle_id uuid,
  vin_last4 text,
  model_year integer,
  make text,
  model text,
  trim text,
  ownership_state text,
  garaging_postal_code text,
  usage text,
  annual_mileage integer,
  confirmation_state public.confirmation_state,
  source_type public.input_source_type
)
language sql
stable
security definer
set search_path = public, private
as $$
  select v.vehicle_id, v.vin_last4, v.model_year, v.make, v.model, v.trim,
         v.ownership_state, v.garaging_postal_code, v.usage, v.annual_mileage,
         v.confirmation_state, v.source_type
  from public.vehicles v
  where v.quote_case_id = p_quote_case_id
    and private.has_consumer_quote_access(p_quote_case_id)
  order by v.created_at, v.vehicle_id
$$;

create or replace function private.get_consumer_coverage_request_impl(p_quote_case_id uuid)
returns table (
  coverage_request_id uuid,
  schema_version integer,
  requested_limits jsonb,
  preferences jsonb,
  notes text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public, private
as $$
  select c.coverage_request_id, c.schema_version, c.requested_limits, c.preferences, c.notes, c.updated_at
  from public.coverage_requests c
  where c.quote_case_id = p_quote_case_id
    and private.has_consumer_quote_access(p_quote_case_id)
$$;

revoke all on function private.get_consumer_drivers_impl(uuid) from public;
revoke all on function private.get_consumer_vehicles_impl(uuid) from public;
revoke all on function private.get_consumer_coverage_request_impl(uuid) from public;
grant execute on function private.get_consumer_drivers_impl(uuid) to authenticated;
grant execute on function private.get_consumer_vehicles_impl(uuid) to authenticated;
grant execute on function private.get_consumer_coverage_request_impl(uuid) to authenticated;

create or replace function public.get_consumer_drivers(p_quote_case_id uuid)
returns table (
  driver_id uuid,
  relationship_role text,
  first_name text,
  last_name text,
  date_of_birth date,
  license_jurisdiction text,
  license_last4 text,
  license_status text,
  years_licensed integer,
  confirmation_state public.confirmation_state,
  source_type public.input_source_type
)
language sql stable security invoker set search_path = public, private
as $$ select * from private.get_consumer_drivers_impl(p_quote_case_id) $$;

create or replace function public.get_consumer_vehicles(p_quote_case_id uuid)
returns table (
  vehicle_id uuid,
  vin_last4 text,
  model_year integer,
  make text,
  model text,
  trim text,
  ownership_state text,
  garaging_postal_code text,
  usage text,
  annual_mileage integer,
  confirmation_state public.confirmation_state,
  source_type public.input_source_type
)
language sql stable security invoker set search_path = public, private
as $$ select * from private.get_consumer_vehicles_impl(p_quote_case_id) $$;

create or replace function public.get_consumer_coverage_request(p_quote_case_id uuid)
returns table (
  coverage_request_id uuid,
  schema_version integer,
  requested_limits jsonb,
  preferences jsonb,
  notes text,
  updated_at timestamptz
)
language sql stable security invoker set search_path = public, private
as $$ select * from private.get_consumer_coverage_request_impl(p_quote_case_id) $$;

revoke all on function public.get_consumer_drivers(uuid) from public, anon;
revoke all on function public.get_consumer_vehicles(uuid) from public, anon;
revoke all on function public.get_consumer_coverage_request(uuid) from public, anon;
grant execute on function public.get_consumer_drivers(uuid) to authenticated;
grant execute on function public.get_consumer_vehicles(uuid) to authenticated;
grant execute on function public.get_consumer_coverage_request(uuid) to authenticated;
