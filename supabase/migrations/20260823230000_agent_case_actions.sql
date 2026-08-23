-- Agent issue resolution, consumer follow-up requests, and safe audit timeline.

create table public.consumer_follow_up_requests (
  consumer_follow_up_request_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  quote_case_id uuid not null references public.quote_cases(quote_case_id) on delete cascade,
  readiness_issue_id uuid references public.readiness_issues(readiness_issue_id),
  requested_by uuid not null,
  request_type text not null check (request_type in ('MISSING_INFORMATION','CORRECTION','DOCUMENTATION')),
  message text not null check (char_length(message) between 1 and 2000),
  status text not null default 'PENDING' check (status in ('PENDING','DISPATCHED','COMPLETED','CANCELLED')),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  foreign key (tenant_id, quote_case_id) references public.quote_cases(tenant_id, quote_case_id)
);

create index consumer_follow_up_case_idx
  on public.consumer_follow_up_requests (tenant_id, quote_case_id, created_at desc);

alter table public.consumer_follow_up_requests enable row level security;
create policy consumer_follow_up_workforce_select on public.consumer_follow_up_requests
for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'CASE_READ')
);
revoke all on public.consumer_follow_up_requests from anon, authenticated;
grant select on public.consumer_follow_up_requests to authenticated;

create or replace function public.resolve_workforce_readiness_issue(
  p_quote_case_id uuid,
  p_readiness_issue_id uuid,
  p_resolution_code text,
  p_evidence text
) returns uuid
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_case public.quote_cases;
  v_issue public.readiness_issues;
  v_hash text;
begin
  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id;
  if not found or not private.has_permission(v_case.tenant_id, v_case.agency_id, 'CASE_WRITE') then
    raise exception using errcode = '42501', message = 'CASE_WRITE_NOT_PERMITTED';
  end if;

  select * into v_issue from public.readiness_issues
  where readiness_issue_id = p_readiness_issue_id
    and quote_case_id = p_quote_case_id
    and tenant_id = v_case.tenant_id
    and resolution_state = 'OPEN'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'READINESS_ISSUE_NOT_FOUND';
  end if;
  if v_issue.blocking then
    raise exception using errcode = '55000', message = 'BLOCKING_ISSUE_REQUIRES_SOURCE_CORRECTION';
  end if;
  if p_resolution_code <> 'REVIEWED_NON_BLOCKING' or length(trim(coalesce(p_evidence, ''))) < 3 then
    raise exception using errcode = '22023', message = 'INVALID_RESOLUTION_EVIDENCE';
  end if;

  update public.readiness_issues
  set resolution_state = 'RESOLVED', resolved_at = now(),
      resolution_evidence = jsonb_build_object('code', p_resolution_code, 'evidence', trim(p_evidence), 'actorId', auth.uid())
  where readiness_issue_id = p_readiness_issue_id;

  v_hash := encode(digest(concat_ws('|', v_case.tenant_id, p_quote_case_id, p_readiness_issue_id, p_resolution_code, trim(p_evidence), auth.uid()), 'sha256'), 'hex');
  insert into public.audit_events (
    tenant_id, agency_id, quote_case_id, event_type, actor_id, subject_ref,
    configuration_version_ref, outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_case.tenant_id, v_case.agency_id, p_quote_case_id, 'READINESS_ISSUE_RESOLVED', auth.uid(),
    p_readiness_issue_id::text, v_case.tenant_configuration_version::text, 'RESOLVED',
    array[p_resolution_code], v_hash, jsonb_build_object('issueType', v_issue.issue_type)
  );
  return p_readiness_issue_id;
end
$$;

create or replace function public.create_workforce_consumer_follow_up(
  p_quote_case_id uuid,
  p_readiness_issue_id uuid,
  p_request_type text,
  p_message text
) returns uuid
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_case public.quote_cases;
  v_request_id uuid;
  v_hash text;
begin
  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id;
  if not found or not private.has_permission(v_case.tenant_id, v_case.agency_id, 'CASE_WRITE') then
    raise exception using errcode = '42501', message = 'CASE_WRITE_NOT_PERMITTED';
  end if;
  if p_request_type not in ('MISSING_INFORMATION','CORRECTION','DOCUMENTATION')
     or length(trim(coalesce(p_message, ''))) not between 1 and 2000 then
    raise exception using errcode = '22023', message = 'INVALID_FOLLOW_UP_REQUEST';
  end if;
  if v_case.state not in ('REVIEW_REQUIRED','CARRIER_RESPONSE','FOLLOW_UP') then
    raise exception using errcode = '55000', message = 'INVALID_CASE_STATE';
  end if;
  if p_readiness_issue_id is not null and not exists (
    select 1 from public.readiness_issues where readiness_issue_id = p_readiness_issue_id
      and quote_case_id = p_quote_case_id and tenant_id = v_case.tenant_id and resolution_state = 'OPEN'
  ) then
    raise exception using errcode = 'P0002', message = 'READINESS_ISSUE_NOT_FOUND';
  end if;

  insert into public.consumer_follow_up_requests (
    tenant_id, agency_id, quote_case_id, readiness_issue_id, requested_by, request_type, message
  ) values (
    v_case.tenant_id, v_case.agency_id, p_quote_case_id, p_readiness_issue_id, auth.uid(), p_request_type, trim(p_message)
  ) returning consumer_follow_up_request_id into v_request_id;

  update public.quote_cases set state = 'FOLLOW_UP', updated_at = now()
  where quote_case_id = p_quote_case_id and state in ('REVIEW_REQUIRED','CARRIER_RESPONSE','FOLLOW_UP');

  v_hash := encode(digest(concat_ws('|', v_case.tenant_id, p_quote_case_id, v_request_id, p_request_type, trim(p_message), auth.uid()), 'sha256'), 'hex');
  insert into public.audit_events (
    tenant_id, agency_id, quote_case_id, event_type, actor_id, subject_ref,
    configuration_version_ref, outcome, reason_codes, integrity_hash, metadata
  ) values (
    v_case.tenant_id, v_case.agency_id, p_quote_case_id, 'CONSUMER_FOLLOW_UP_REQUESTED', auth.uid(),
    v_request_id::text, v_case.tenant_configuration_version::text, 'PENDING',
    array[p_request_type], v_hash, jsonb_build_object('readinessIssueId', p_readiness_issue_id)
  );
  return v_request_id;
end
$$;

create or replace function public.get_workforce_case_activity(p_quote_case_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private
as $$
declare
  v_case public.quote_cases;
  v_can_audit boolean;
begin
  select * into v_case from public.quote_cases where quote_case_id = p_quote_case_id;
  if not found or not private.has_permission(v_case.tenant_id, v_case.agency_id, 'CASE_READ') then
    raise exception using errcode = '42501', message = 'CASE_READ_NOT_PERMITTED';
  end if;
  v_can_audit := private.has_permission(v_case.tenant_id, v_case.agency_id, 'AUDIT_READ');
  return jsonb_build_object(
    'canWrite', private.has_permission(v_case.tenant_id, v_case.agency_id, 'CASE_WRITE'),
    'canViewAudit', v_can_audit,
    'followUps', coalesce((select jsonb_agg(jsonb_build_object(
      'followUpRequestId', f.consumer_follow_up_request_id, 'readinessIssueId', f.readiness_issue_id,
      'requestType', f.request_type, 'message', f.message, 'status', f.status, 'createdAt', f.created_at
    ) order by f.created_at desc) from public.consumer_follow_up_requests f where f.quote_case_id = p_quote_case_id), '[]'::jsonb),
    'timeline', case when v_can_audit then coalesce((select jsonb_agg(jsonb_build_object(
      'auditEventId', a.audit_event_id, 'eventType', a.event_type, 'outcome', a.outcome,
      'reasonCodes', a.reason_codes, 'occurredAt', a.occurred_at
    ) order by a.occurred_at desc, a.audit_event_id desc) from public.audit_events a where a.quote_case_id = p_quote_case_id), '[]'::jsonb) else '[]'::jsonb end
  );
end
$$;

revoke all on function public.resolve_workforce_readiness_issue(uuid,uuid,text,text) from public, anon;
revoke all on function public.create_workforce_consumer_follow_up(uuid,uuid,text,text) from public, anon;
revoke all on function public.get_workforce_case_activity(uuid) from public, anon;
grant execute on function public.resolve_workforce_readiness_issue(uuid,uuid,text,text) to authenticated;
grant execute on function public.create_workforce_consumer_follow_up(uuid,uuid,text,text) to authenticated;
grant execute on function public.get_workforce_case_activity(uuid) to authenticated;
