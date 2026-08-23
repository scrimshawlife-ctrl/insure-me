-- Slice 7: server-only worker helpers for carrier orchestration.

create or replace function public.get_carrier_rating_inputs(
  p_quote_case_id uuid,
  p_carrier_program_id uuid
) returns table(
  rating_input_id uuid,
  input_key text,
  approved_value jsonb,
  data_use_policy_version text,
  mapping_version text
)
language sql security definer set search_path=public,private,extensions
as $$
  select i.rating_input_id,i.input_key,i.approved_value,i.data_use_policy_version,i.mapping_version
  from public.rating_inputs i
  join public.carrier_programs p on p.carrier_program_id=i.carrier_program_id
  where i.quote_case_id=p_quote_case_id
    and i.carrier_program_id=p_carrier_program_id
    and i.carrier_program_version=p.version
  order by i.input_key,i.created_at;
$$;
revoke all on function public.get_carrier_rating_inputs(uuid,uuid) from public,anon,authenticated;
grant execute on function public.get_carrier_rating_inputs(uuid,uuid) to service_role;

create or replace function public.mark_carrier_submission_failed(
  p_carrier_submission_id uuid,
  p_reason_code text
) returns void
language plpgsql security definer set search_path=public,private,extensions
as $$
declare
  v_submission public.carrier_submissions;
  v_integrity text;
begin
  update public.carrier_submissions
  set status='FAILED',completed_at=now()
  where carrier_submission_id=p_carrier_submission_id and status='RUNNING'
  returning * into v_submission;

  if v_submission.carrier_submission_id is null then
    raise exception 'CARRIER_SUBMISSION_NOT_RUNNING' using errcode='55000';
  end if;

  v_integrity:=encode(extensions.digest(concat_ws('|',v_submission.tenant_id::text,v_submission.quote_case_id::text,
    v_submission.carrier_submission_id::text,p_reason_code),'sha256'),'hex');

  insert into public.audit_events(
    tenant_id,agency_id,quote_case_id,event_type,subject_ref,configuration_version_ref,
    outcome,reason_codes,integrity_hash,metadata
  ) values (
    v_submission.tenant_id,v_submission.agency_id,v_submission.quote_case_id,'CARRIER_SUBMISSION_FAILED',
    v_submission.carrier_submission_id::text,v_submission.tenant_configuration_version::text,
    'FAILED',array[p_reason_code],v_integrity,jsonb_build_object('carrierProgramId',v_submission.carrier_program_id)
  );
end;
$$;
revoke all on function public.mark_carrier_submission_failed(uuid,text) from public,anon,authenticated;
grant execute on function public.mark_carrier_submission_failed(uuid,text) to service_role;
