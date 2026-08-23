begin;
select plan(12);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values ('e1000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','Case Actions','Case Actions');
insert into public.tenant_configurations (tenant_configuration_id,tenant_id,agency_id,version,status)
values ('e2000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001',1,'ACTIVE');
insert into public.agency_users (agency_user_id,tenant_id,agency_id,workforce_identity_id,status)
values ('e3000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','e9000000-0000-0000-0000-000000000009','ACTIVE');
insert into public.roles (role_id,tenant_id,agency_id,name,permissions)
values ('e4000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','case-worker',array['CASE_READ','CASE_WRITE','AUDIT_READ']::public.permission_code[]);
insert into public.agency_user_roles (agency_user_id,role_id)
values ('e3000000-0000-0000-0000-000000000001','e4000000-0000-0000-0000-000000000001');
insert into public.prospects (prospect_id,tenant_id,agency_id)
values ('e5000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001');
insert into public.quote_cases (quote_case_id,tenant_id,agency_id,tenant_configuration_id,tenant_configuration_version,jurisdiction,product_line,source_channel,state,prospect_id)
values ('e6000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001',1,'CA','PRIVATE_PASSENGER_AUTO','TEST','REVIEW_REQUIRED','e5000000-0000-0000-0000-000000000001');
insert into public.readiness_issues (readiness_issue_id,tenant_id,agency_id,quote_case_id,issue_type,severity,blocking,reason_code)
values
 ('e7000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','e6000000-0000-0000-0000-000000000001','PARTIAL_PROVIDER_RESULT','WARNING',false,'PARTIAL_MVR_RESULT'),
 ('e7000000-0000-0000-0000-000000000002','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','e6000000-0000-0000-0000-000000000001','MISSING_DATA','BLOCKING',true,'MISSING_DRIVER');

set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub','e9000000-0000-0000-0000-000000000009','role','authenticated','app_metadata',json_build_object('active_tenant_id','e0000000-0000-0000-0000-000000000001'),'aal','aal2')::text,true);

select lives_ok($$select public.resolve_workforce_readiness_issue('e6000000-0000-0000-0000-000000000001','e7000000-0000-0000-0000-000000000001','REVIEWED_NON_BLOCKING','Agent reviewed the partial result')$$,'non-blocking issue can be closed with evidence');
select is((select resolution_state from public.readiness_issues where readiness_issue_id='e7000000-0000-0000-0000-000000000001'),'RESOLVED','resolution is persisted');
select throws_ok($$select public.resolve_workforce_readiness_issue('e6000000-0000-0000-0000-000000000001','e7000000-0000-0000-0000-000000000002','REVIEWED_NON_BLOCKING','attempted waiver')$$,'55000','BLOCKING_ISSUE_REQUIRES_SOURCE_CORRECTION','blocking issue cannot be manually waived');
select lives_ok($$select public.create_workforce_consumer_follow_up('e6000000-0000-0000-0000-000000000001','e7000000-0000-0000-0000-000000000002','MISSING_INFORMATION','Please provide driver details.')$$,'follow-up can be requested for an open issue');
select is((select status from public.consumer_follow_up_requests limit 1),'PENDING','request does not claim delivery');
select is((select state::text from public.quote_cases where quote_case_id='e6000000-0000-0000-0000-000000000001'),'FOLLOW_UP','case enters follow-up state');
select is((select count(*)::int from public.audit_events where quote_case_id='e6000000-0000-0000-0000-000000000001' and event_type in ('READINESS_ISSUE_RESOLVED','CONSUMER_FOLLOW_UP_REQUESTED')),2,'both actions emit audit evidence');
select is((public.get_workforce_case_activity('e6000000-0000-0000-0000-000000000001')->>'canWrite')::boolean,true,'case activity reports write capability');
select is((public.get_workforce_case_activity('e6000000-0000-0000-0000-000000000001')->>'canViewAudit')::boolean,true,'audit capability is explicit');
select is(jsonb_array_length(public.get_workforce_case_activity('e6000000-0000-0000-0000-000000000001')->'followUps'),1,'follow-up projection is case scoped');
select ok(not (public.get_workforce_case_activity('e6000000-0000-0000-0000-000000000001')->'timeline'->0 ? 'metadata'),'timeline omits unrestricted audit metadata');

reset role;
update public.roles set permissions=array['CASE_READ']::public.permission_code[] where role_id='e4000000-0000-0000-0000-000000000001';
set local role authenticated;
select is(jsonb_array_length(public.get_workforce_case_activity('e6000000-0000-0000-0000-000000000001')->'timeline'),0,'timeline is hidden without AUDIT_READ');

select * from finish();
rollback;
