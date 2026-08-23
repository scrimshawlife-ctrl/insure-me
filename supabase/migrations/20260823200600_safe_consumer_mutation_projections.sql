-- Public consumer mutation RPCs must never return protected ciphertext or lookup hashes.
-- Authenticated callers must use the public wrappers, not private mutation implementations.

revoke execute on function private.replace_consumer_drivers_impl(uuid, jsonb) from authenticated;
revoke execute on function private.replace_consumer_vehicles_impl(uuid, jsonb) from authenticated;

drop function public.replace_consumer_drivers(uuid, jsonb);
drop function public.replace_consumer_vehicles(uuid, jsonb);

create function public.replace_consumer_drivers(p_quote_case_id uuid, p_drivers jsonb)
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
language plpgsql
security definer
set search_path = public, private
as $$
begin
  perform 1 from private.replace_consumer_drivers_impl(p_quote_case_id, p_drivers);
  return query select * from private.get_consumer_drivers_impl(p_quote_case_id);
end
$$;

create function public.replace_consumer_vehicles(p_quote_case_id uuid, p_vehicles jsonb)
returns table (
  vehicle_id uuid,
  vin_last4 text,
  model_year integer,
  make text,
  model text,
  "trim" text,
  ownership_state text,
  garaging_postal_code text,
  usage text,
  annual_mileage integer,
  confirmation_state public.confirmation_state,
  source_type public.input_source_type
)
language plpgsql
security definer
set search_path = public, private
as $$
begin
  perform 1 from private.replace_consumer_vehicles_impl(p_quote_case_id, p_vehicles);
  return query select * from private.get_consumer_vehicles_impl(p_quote_case_id);
end
$$;

revoke all on function public.replace_consumer_drivers(uuid, jsonb) from public, anon;
revoke all on function public.replace_consumer_vehicles(uuid, jsonb) from public, anon;
grant execute on function public.replace_consumer_drivers(uuid, jsonb) to authenticated;
grant execute on function public.replace_consumer_vehicles(uuid, jsonb) to authenticated;
