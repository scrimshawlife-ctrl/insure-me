-- Slice 7: carrier program selection, idempotent submission, and immutable carrier decision settlement.

create or replace function private.select_carrier_program(
  p_quote_case_id uuid,
  p_carrier_program_id uuid
) returns void
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_case public.quote_cases;
  v_program public.carrier_programs;
  v_integrity text;
begin
  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id;
  if v_case.quote_case_id is null then
    raise exception 'QUOTE_CASE_NOT_FOUND' using errcode = 'P0002';
  end if;

  select * into v_program from public.carrier_programs
  where carrier_program_id = p_carrier_program_id
    and tenant_id = v_case.tenant_id
    and agency_id = v_case.agency_id
    and v_case.jurisdiction = any(jurisdictions)
    and v_case.product_line = any(product_lines)
    and retired_at is null;
  if v_program.carrier_program_id is null then
    raise exception 'CARRIER_PROGRAM_NOT_CONFIGURED' using errcode = '42501';
  end if;
  if v_program.kill_switch_enabled then
    raise exception 'CARRIER_KILL_SWITCHED' using errcode = '42501';
  end if;
  if v_program.certification_state not in ('SYNTHETIC','SANDBOX','CERTIFIED') then
    raise exception 'CARRIER_NOT_CERTIFIED' using errcode = '42501';
  end if;

  update public.quote_cases
  set selected_carrier_program_id = v_program.carrier_program_id,
      selected_carrier_program_version = v_program.version,
      updated_at = now()
  where quote_case_id = p_quote_case_id;

  v_integrity := encode(extensions.digest(
    concat_ws('|',v_case.tenant_id::text,p_quote_case_id::text,v_program.carrier_program_id::text,v_program.version::text),
    'sha256'
  ),'hex');

  insert into public.audit_events (
    tenant_id, agency_id, quote_case_id, event_type, subject_ref,
    configuration_version_ref, outcome, integrity_hash, metadata
  ) values (
    v_case.tenant_id,v_case.agency_id,p_quote_case_id,'CARRIER_PROGRAM_SELECTED',
    v_program.carrier_program_id::text,v_case.tenant_configuration_version::text,
    'SELECTED',v_integrity,jsonb_build_object('programVersion',v_program.version)
  );
end;
$$;

create or replace function public.select_carrier_program(
  p_quote_case_id uuid,
  p_carrier_program_id uuid
) returns void
language sql
security definer
set search_path = public, private, extensions
as $$ select private.select_carrier_program(p_quote_case_id,p_carrier_program_id); $$;
revoke all on function public.select_carrier_program(uuid,uuid) from public,anon,authenticated;
grant execute on function public.select_carrier_program(uuid,uuid) to service_role;

create or replace function private.create_carrier_submission(
  p_quote_case_id uuid,
  p_carrier_program_id uuid,
  p_idempotency_key text,
  p_request_hash text
) returns table (carrier_submission_id uuid, reused boolean)
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_case public.quote_cases;
  v_program public.carrier_programs;
  v_carrier public.carriers;
  v_existing public.carrier_submissions;
  v_rating_input_ids uuid[];
  v_required_count integer;
  v_present_count integer;
  v_new_id uuid;
begin
  select * into v_case from public.quote_cases where quote_case_id=p_quote_case_id;
  if v_case.quote_case_id is null then raise exception 'QUOTE_CASE_NOT_FOUND' using errcode='P0002'; end if;

  select * into v_program from public.carrier_programs
  where carrier_program_id=p_carrier_program_id
    and tenant_id=v_case.tenant_id and agency_id=v_case.agency_id
    and v_case.jurisdiction=any(jurisdictions) and v_case.product_line=any(product_lines)
    and retired_at is null;
  if v_program.carrier_program_id is null then raise exception 'CARRIER_PROGRAM_NOT_CONFIGURED' using errcode='42501'; end if;
  if v_program.kill_switch_enabled then raise exception 'CARRIER_KILL_SWITCHED' using errcode='42501'; end if;
  if v_program.certification_state not in ('SYNTHETIC','SANDBOX','CERTIFIED') then raise exception 'CARRIER_NOT_CERTIFIED' using errcode='42501'; end if;

  if exists(select 1 from public.readiness_issues where quote_case_id=p_quote_case_id and blocking and resolution_state='OPEN' and carrier_program_id is null) then
    raise exception 'CARRIER_HANDOFF_BLOCKED:READINESS' using errcode='42501';
  end if;

  select count(*) into v_required_count
  from public.carrier_program_rating_rules
  where carrier_program_id=p_carrier_program_id
    and carrier_program_version=v_program.version
    and mapping_version=v_program.rating_input_policy_version
    and required;

  select count(distinct r.input_key) into v_present_count
  from public.carrier_program_rating_rules r
  join public.rating_inputs i
    on i.quote_case_id=p_quote_case_id
   and i.carrier_program_id=p_carrier_program_id
   and i.carrier_program_version=v_program.version
   and i.input_key=r.input_key
  where r.carrier_program_id=p_carrier_program_id
    and r.carrier_program_version=v_program.version
    and r.mapping_version=v_program.rating_input_policy_version
    and r.required;

  if v_present_count < v_required_count then
    raise exception 'CARRIER_HANDOFF_BLOCKED:MISSING_RATING_INPUT' using errcode='42501';
  end if;

  if exists(
    select 1
    from public.rating_inputs i
    cross join lateral unnest(i.source_observation_or_field_refs) ref
    join public.underwriting_observations o on o.observation_id=ref
    where i.quote_case_id=p_quote_case_id
      and i.carrier_program_id=p_carrier_program_id
      and (o.data_use_classification<>'RATING_SUBMISSION_ALLOWED' or o.freshness_state<>'CURRENT' or o.conflict_state<>'NONE')
  ) then
    raise exception 'CARRIER_HANDOFF_BLOCKED:INVALID_RATING_INPUT_SOURCE' using errcode='42501';
  end if;

  select * into v_existing from public.carrier_submissions
  where tenant_id=v_case.tenant_id and carrier_program_id=p_carrier_program_id and idempotency_key=p_idempotency_key;
  if v_existing.carrier_submission_id is not null then
    if v_existing.request_hash<>p_request_hash then
      raise exception 'IDEMPOTENCY_KEY_REUSE_WITH_DIFFERENT_REQUEST' using errcode='23505';
    end if;
    carrier_submission_id:=v_existing.carrier_submission_id;
    reused:=true;
    return next; return;
  end if;

  select array_agg(rating_input_id order by input_key) into v_rating_input_ids
  from public.rating_inputs
  where quote_case_id=p_quote_case_id and carrier_program_id=p_carrier_program_id and carrier_program_version=v_program.version;

  select * into v_carrier from public.carriers where carrier_id=v_program.carrier_id;

  insert into public.carrier_submissions (
    tenant_id,agency_id,quote_case_id,tenant_configuration_version,
    carrier_id,carrier_program_id,carrier_program_version,adapter_id,handoff_mode,
    mapping_version,rating_input_ids,idempotency_key,request_hash,status
  ) values (
    v_case.tenant_id,v_case.agency_id,p_quote_case_id,v_case.tenant_configuration_version,
    v_program.carrier_id,v_program.carrier_program_id,v_program.version,v_program.adapter_id,v_program.handoff_mode,
    v_program.rating_input_policy_version,coalesce(v_rating_input_ids,'{}'),p_idempotency_key,p_request_hash,'PENDING'
  ) returning public.carrier_submissions.carrier_submission_id into v_new_id;

  carrier_submission_id:=v_new_id; reused:=false; return next;
end;
$$;

create or replace function public.create_carrier_submission(
  p_quote_case_id uuid,p_carrier_program_id uuid,p_idempotency_key text,p_request_hash text
) returns table(carrier_submission_id uuid,reused boolean)
language sql security definer set search_path=public,private,extensions
as $$ select * from private.create_carrier_submission(p_quote_case_id,p_carrier_program_id,p_idempotency_key,p_request_hash); $$;
revoke all on function public.create_carrier_submission(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.create_carrier_submission(uuid,uuid,text,text) to service_role;

create or replace function private.claim_carrier_submission(
  p_carrier_submission_id uuid
) returns public.carrier_submissions
language plpgsql security definer set search_path=public,private,extensions
as $$
declare v_submission public.carrier_submissions;
begin
  update public.carrier_submissions set status='RUNNING'
  where carrier_submission_id=p_carrier_submission_id and status='PENDING'
  returning * into v_submission;
  if v_submission.carrier_submission_id is null then raise exception 'CARRIER_SUBMISSION_NOT_CLAIMABLE' using errcode='55000'; end if;
  return v_submission;
end; $$;

create or replace function public.claim_carrier_submission(p_carrier_submission_id uuid)
returns public.carrier_submissions language sql security definer set search_path=public,private,extensions
as $$ select private.claim_carrier_submission(p_carrier_submission_id); $$;
revoke all on function public.claim_carrier_submission(uuid) from public,anon,authenticated;
grant execute on function public.claim_carrier_submission(uuid) to service_role;

create or replace function private.settle_carrier_submission(
  p_carrier_submission_id uuid,
  p_decision_status text,
  p_premium jsonb,
  p_reason_codes text[],
  p_external_reference text,
  p_received_at timestamptz
) returns uuid
language plpgsql security definer set search_path=public,private,extensions
as $$
declare
  v_submission public.carrier_submissions;
  v_program public.carrier_programs;
  v_decision_id uuid;
  v_integrity text;
begin
  select * into v_submission from public.carrier_submissions where carrier_submission_id=p_carrier_submission_id for update;
  if v_submission.carrier_submission_id is null then raise exception 'CARRIER_SUBMISSION_NOT_FOUND' using errcode='P0002'; end if;

  if v_submission.status='SUCCEEDED' then
    select carrier_decision_id into v_decision_id from public.carrier_decisions
    where carrier_submission_id=p_carrier_submission_id order by created_at desc limit 1;
    return v_decision_id;
  end if;
  if v_submission.status<>'RUNNING' then raise exception 'CARRIER_SUBMISSION_NOT_RUNNING' using errcode='55000'; end if;

  select * into v_program from public.carrier_programs where carrier_program_id=v_submission.carrier_program_id;

  insert into public.carrier_decisions (
    tenant_id,agency_id,carrier_submission_id,carrier_program_id,decision_status,
    premium,reason_codes,external_reference,response_mapping_version,received_at
  ) values (
    v_submission.tenant_id,v_submission.agency_id,v_submission.carrier_submission_id,v_submission.carrier_program_id,
    p_decision_status,p_premium,coalesce(p_reason_codes,'{}'),p_external_reference,v_program.response_mapping_version,p_received_at
  ) returning carrier_decision_id into v_decision_id;

  update public.carrier_submissions
  set status=case when p_decision_status='ERROR' then 'FAILED'::public.carrier_submission_status else 'SUCCEEDED'::public.carrier_submission_status end,
      external_reference=p_external_reference,completed_at=now()
  where carrier_submission_id=p_carrier_submission_id;

  v_integrity:=encode(extensions.digest(concat_ws('|',v_submission.tenant_id::text,v_submission.quote_case_id::text,
    v_submission.carrier_submission_id::text,v_decision_id::text,p_decision_status,coalesce(p_external_reference,'')),'sha256'),'hex');

  insert into public.audit_events (
    tenant_id,agency_id,quote_case_id,event_type,subject_ref,configuration_version_ref,
    outcome,reason_codes,integrity_hash,metadata
  ) values (
    v_submission.tenant_id,v_submission.agency_id,v_submission.quote_case_id,'CARRIER_DECISION_SETTLED',
    v_decision_id::text,v_submission.tenant_configuration_version::text,p_decision_status,
    coalesce(p_reason_codes,'{}'),v_integrity,jsonb_build_object('carrierSubmissionId',v_submission.carrier_submission_id,'carrierProgramId',v_submission.carrier_program_id)
  );

  return v_decision_id;
end; $$;

create or replace function public.settle_carrier_submission(
  p_carrier_submission_id uuid,p_decision_status text,p_premium jsonb,p_reason_codes text[],p_external_reference text,p_received_at timestamptz
) returns uuid language sql security definer set search_path=public,private,extensions
as $$ select private.settle_carrier_submission(p_carrier_submission_id,p_decision_status,p_premium,p_reason_codes,p_external_reference,p_received_at); $$;
revoke all on function public.settle_carrier_submission(uuid,text,jsonb,text[],text,timestamptz) from public,anon,authenticated;
grant execute on function public.settle_carrier_submission(uuid,text,jsonb,text[],text,timestamptz) to service_role;

create or replace function public.get_carrier_submission_result(p_carrier_submission_id uuid)
returns table(
  submission_status public.carrier_submission_status,
  decision_status text,
  premium jsonb,
  reason_codes text[],
  external_reference text,
  received_at timestamptz
)
language sql security definer set search_path=public,private,extensions
as $$
  select cs.status,cd.decision_status,cd.premium,cd.reason_codes,coalesce(cd.external_reference,cs.external_reference),cd.received_at
  from public.carrier_submissions cs
  left join lateral (
    select * from public.carrier_decisions x where x.carrier_submission_id=cs.carrier_submission_id order by x.created_at desc limit 1
  ) cd on true
  where cs.carrier_submission_id=p_carrier_submission_id;
$$;
revoke all on function public.get_carrier_submission_result(uuid) from public,anon,authenticated;
grant execute on function public.get_carrier_submission_result(uuid) to service_role;
