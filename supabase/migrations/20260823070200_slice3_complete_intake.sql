-- Slice 3: complete consumer intake only when the canonical minimum is present.

create or replace function private.complete_consumer_intake_impl(p_quote_case_id uuid)
returns table (
  quote_case_id uuid,
  state public.quote_case_state,
  next_action text
)
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_case public.quote_cases;
  v_driver_count integer;
  v_vehicle_count integer;
  v_has_coverage boolean;
  v_hash text;
begin
  if not private.has_consumer_quote_access(p_quote_case_id) then
    raise exception using errcode = '42501', message = 'CONSUMER_QUOTE_ACCESS_DENIED';
  end if;

  select * into v_case
  from public.quote_cases
  where public.quote_cases.quote_case_id = p_quote_case_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'QUOTE_CASE_NOT_FOUND';
  end if;

  if v_case.state <> 'CONSUMER_INPUT' then
    raise exception using errcode = '22023', message = 'CONSUMER_INTAKE_STATE_INVALID';
  end if;

  if not private.required_notices_satisfied(p_quote_case_id) then
    raise exception using errcode = '22023', message = 'REQUIRED_NOTICES_INCOMPLETE';
  end if;

  select count(*) into v_driver_count from public.drivers d where d.quote_case_id = p_quote_case_id;
  select count(*) into v_vehicle_count from public.vehicles v where v.quote_case_id = p_quote_case_id;
  select exists(select 1 from public.coverage_requests c where c.quote_case_id = p_quote_case_id) into v_has_coverage;

  if v_driver_count < 1 then
    raise exception using errcode = '22023', message = 'DRIVER_REQUIRED';
  end if;
  if v_vehicle_count < 1 then
    raise exception using errcode = '22023', message = 'VEHICLE_REQUIRED';
  end if;
  if not v_has_coverage then
    raise exception using errcode = '22023', message = 'COVERAGE_REQUEST_REQUIRED';
  end if;

  update public.quote_cases
  set state = 'DATA_ENRICHMENT', updated_at = now()
  where public.quote_cases.quote_case_id = p_quote_case_id;

  v_hash := encode(extensions.digest(concat_ws('|', v_case.tenant_id::text, p_quote_case_id::text, 'CONSUMER_INTAKE_COMPLETED', clock_timestamp()::text),'sha256'),'hex');
  insert into public.audit_events (
    tenant_id, agency_id, quote_case_id, event_type, actor_id, subject_ref,
    configuration_version_ref, outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_case.tenant_id, v_case.agency_id, p_quote_case_id, 'CONSUMER_INTAKE_COMPLETED', auth.uid(),
    'consumer:' || auth.uid()::text, v_case.tenant_configuration_version::text,
    'SUCCEEDED', '{}', v_hash,
    jsonb_build_object('driver_count',v_driver_count,'vehicle_count',v_vehicle_count,'coverage_request',v_has_coverage,'to_state','DATA_ENRICHMENT')
  );

  return query select p_quote_case_id, 'DATA_ENRICHMENT'::public.quote_case_state, 'ENRICHMENT'::text;
end
$$;

revoke all on function private.complete_consumer_intake_impl(uuid) from public;
grant execute on function private.complete_consumer_intake_impl(uuid) to authenticated;

create or replace function public.complete_consumer_intake(p_quote_case_id uuid)
returns table (quote_case_id uuid, state public.quote_case_state, next_action text)
language sql
security invoker
set search_path = public, private
as $$ select * from private.complete_consumer_intake_impl(p_quote_case_id) $$;

revoke all on function public.complete_consumer_intake(uuid) from public, anon;
grant execute on function public.complete_consumer_intake(uuid) to authenticated;
