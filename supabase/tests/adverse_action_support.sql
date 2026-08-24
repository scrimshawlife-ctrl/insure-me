begin;
select plan(25);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name) values
('e1000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','Adverse Action Agency','Adverse Action');
insert into public.agency_users (agency_user_id,tenant_id,agency_id,workforce_identity_id,status) values
('e2000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','e9000000-0000-0000-0000-000000000009','ACTIVE');
insert into public.roles (role_id,tenant_id,agency_id,name,permissions) values
('e3000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','policy-admin',array['POLICY_ADMIN']::public.permission_code[]);
insert into public.agency_user_roles values ('e2000000-0000-0000-0000-000000000001','e3000000-0000-0000-0000-000000000001');
insert into public.tenant_configurations (tenant_configuration_id,tenant_id,agency_id,version,status,effective_at) values
('e4000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001',1,'ACTIVE',now());
insert into public.person_private_profiles (person_id,tenant_id,agency_id,encrypted_payload,encryption_algorithm,key_version) values
('e4100000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001',decode('00','hex'),'AES-256-GCM','synthetic-key');
insert into public.prospects (prospect_id,tenant_id,agency_id,person_id,source_classification) values
('e4200000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','e4100000-0000-0000-0000-000000000001','SYNTHETIC');
insert into public.quote_cases (quote_case_id,tenant_id,agency_id,tenant_configuration_id,tenant_configuration_version,jurisdiction,product_line,source_channel,state,prospect_id) values
('e4300000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','e4000000-0000-0000-0000-000000000001',1,'CA','PRIVATE_PASSENGER_AUTO','WEB','CARRIER_RESPONSE','e4200000-0000-0000-0000-000000000001');
insert into public.provider_bindings (provider_binding_id,tenant_id,agency_id,capability,adapter_id,adapter_version,jurisdiction,product_line,purpose_code) values
('e4400000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','MVR','stub-mvr','1','CA','PRIVATE_PASSENGER_AUTO','INSURANCE_UNDERWRITING');
insert into public.permissible_purpose_decisions (decision_id,tenant_id,quote_case_id,tenant_configuration_version,jurisdiction,capability,purpose_code,policy_version,outcome,reason_codes) values
('e4500000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e4300000-0000-0000-0000-000000000001',1,'CA','MVR','INSURANCE_UNDERWRITING','synthetic-purpose-v1','ALLOW',array['SYNTHETIC']);
insert into public.external_requests (external_request_id,tenant_id,agency_id,quote_case_id,tenant_configuration_version,provider_binding_id,capability,permissible_purpose_decision_id,idempotency_key,request_hash,status,completed_at) values
('e4600000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','e4300000-0000-0000-0000-000000000001',1,'e4400000-0000-0000-0000-000000000001','MVR','e4500000-0000-0000-0000-000000000001','provider-key',repeat('1',64),'SUCCEEDED',now());
insert into public.external_reports (external_report_id,tenant_id,agency_id,quote_case_id,external_request_id,provider_id,provider_product_id,status,retrieved_at,normalized_version) values
('e4700000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','e4300000-0000-0000-0000-000000000001','e4600000-0000-0000-0000-000000000001','synthetic-cra','synthetic-mvr','SUCCESS',now(),'v1');
insert into public.carriers (carrier_id,tenant_id,agency_id,legal_name,display_name) values
('e4800000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Synthetic Carrier','Synthetic Carrier');
insert into public.carrier_programs (carrier_program_id,tenant_id,agency_id,carrier_id,program_code,version,jurisdictions,product_lines,adapter_id,adapter_version,handoff_mode,required_field_policy_version,rating_input_policy_version,response_mapping_version,notice_ownership_policy_version,certification_state) values
('e4900000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','e4800000-0000-0000-0000-000000000001','SYNTH-AA',1,array['CA'],array['PRIVATE_PASSENGER_AUTO'],'stub-carrier','1','STUB','required-v1','rating-v1','response-v1','ownership-v1','SYNTHETIC');
insert into public.carrier_submissions (carrier_submission_id,tenant_id,agency_id,quote_case_id,tenant_configuration_version,carrier_id,carrier_program_id,carrier_program_version,adapter_id,handoff_mode,mapping_version,rating_input_ids,idempotency_key,request_hash,status,completed_at) values
('e5000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','e4300000-0000-0000-0000-000000000001',1,'e4800000-0000-0000-0000-000000000001','e4900000-0000-0000-0000-000000000001',1,'stub-carrier','STUB','mapping-v1','{}','carrier-key',repeat('2',64),'SUCCEEDED',now());
insert into public.carrier_decisions (carrier_decision_id,tenant_id,agency_id,carrier_submission_id,carrier_program_id,decision_status,reason_codes,response_mapping_version,received_at) values
('e5100000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','e5000000-0000-0000-0000-000000000001','e4900000-0000-0000-0000-000000000001','DECLINED',array['SYNTHETIC_UNFAVORABLE'],'response-v1',now());

select has_table('public','adverse_action_cases','adverse action case table exists');
select has_table('public','adverse_action_report_sources','report source table exists');
select has_table('public','adverse_action_events','event evidence table exists');
select col_type_is('public','adverse_action_cases','owner_type','adverse_action_owner_type','owner type is closed');
select is(has_table_privilege('anon','public.adverse_action_cases','SELECT'),false,'anonymous cannot enumerate cases');
select is(has_table_privilege('authenticated','public.adverse_action_cases','INSERT'),false,'authenticated cannot directly create cases');
select is(has_table_privilege('authenticated','public.adverse_action_events','UPDATE'),false,'authenticated cannot rewrite evidence');
select is(has_function_privilege('authenticated','public.create_adverse_action_case(uuid,uuid,public.adverse_action_owner_type,text,text,text,text[],jsonb,uuid,text)','EXECUTE'),true,'authenticated workforce can call checked RPC');
select is(has_function_privilege('anon','public.record_adverse_action_handoff(uuid,text,text,text[],uuid,text)','EXECUTE'),false,'anonymous cannot record handoff');

set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub','e9000000-0000-0000-0000-000000000009','role','authenticated','app_metadata',json_build_object('active_tenant_id','e0000000-0000-0000-0000-000000000001'),'aal','aal2')::text,true);
create temporary table adverse_created as select (public.create_adverse_action_case(
  'e4300000-0000-0000-0000-000000000001','e5100000-0000-0000-0000-000000000001','CARRIER','carrier-owner:synthetic',
  'authority:responsible-party','evidence:determination',array['RESPONSIBLE_PARTY_DETERMINED'],
  '[{"externalReportId":"e4700000-0000-0000-0000-000000000001","craIdentityRef":"cra:synthetic","disputeRouteRef":"dispute:synthetic","contributionBasisCode":"CONTRIBUTED_PARTLY"}]'::jsonb,
  'e5200000-0000-4000-8000-000000000001',repeat('a',64))).*;
select is((select status::text from adverse_created),'NOTICE_INPUTS_READY','determination prepares notice inputs');
select is((select owner_type::text from adverse_created),'CARRIER','ownership is explicit');
select is((select ownership_policy_version from adverse_created),'ownership-v1','ownership policy version comes from carrier program');
select is((select count(*) from public.adverse_action_report_sources),1::bigint,'exact contributing report is linked');
select is((select cra_identity_ref from public.adverse_action_report_sources),'cra:synthetic','CRA linkage is retained');
select is((select dispute_route_ref from public.adverse_action_report_sources),'dispute:synthetic','dispute route is retained');
select is((select count(*) from public.adverse_action_events where event_type='DETERMINATION_RECORDED'),1::bigint,'determination evidence is appended');
select is((select (public.create_adverse_action_case(
  'e4300000-0000-0000-0000-000000000001','e5100000-0000-0000-0000-000000000001','CARRIER','carrier-owner:synthetic',
  'authority:responsible-party','evidence:determination',array['RESPONSIBLE_PARTY_DETERMINED'],
  '[{"externalReportId":"e4700000-0000-0000-0000-000000000001","craIdentityRef":"cra:synthetic","disputeRouteRef":"dispute:synthetic","contributionBasisCode":"CONTRIBUTED_PARTLY"}]'::jsonb,
  'e5200000-0000-4000-8000-000000000001',repeat('a',64))).adverse_action_case_id),(select adverse_action_case_id from adverse_created),'determination replay is idempotent');
select throws_ok($$select public.create_adverse_action_case('e4300000-0000-0000-0000-000000000001','e5100000-0000-0000-0000-000000000001','CARRIER','carrier-owner:synthetic','authority:responsible-party','evidence:determination',array['RESPONSIBLE_PARTY_DETERMINED'],'[{"externalReportId":"e4700000-0000-0000-0000-000000000001","craIdentityRef":"cra:synthetic","disputeRouteRef":"dispute:synthetic","contributionBasisCode":"CONTRIBUTED_PARTLY"}]'::jsonb,'e5200000-0000-4000-8000-000000000001',repeat('b',64))$$,'22023','IDEMPOTENCY_KEY_REQUEST_MISMATCH','determination replay cannot change evidence');

create temporary table adverse_handoff as select (public.record_adverse_action_handoff((select adverse_action_case_id from adverse_created),'carrier-desk:synthetic','evidence:handoff',array['OWNER_ACKNOWLEDGED'],'e5300000-0000-4000-8000-000000000001',repeat('c',64))).*;
select is((select status::text from adverse_handoff),'HANDED_OFF','handoff advances support workflow');
select is((select count(*) from public.adverse_action_events where event_type='HANDOFF_RECORDED'),1::bigint,'handoff evidence is appended');
select is((select (public.record_adverse_action_handoff((select adverse_action_case_id from adverse_created),'carrier-desk:synthetic','evidence:handoff',array['OWNER_ACKNOWLEDGED'],'e5300000-0000-4000-8000-000000000001',repeat('c',64))).status::text),'HANDED_OFF','handoff replay is idempotent');
reset role;
select is((select count(*) from public.audit_events where event_type like 'ADVERSE_ACTION_%'),2::bigint,'determination and handoff are audited');
select throws_ok($$update public.adverse_action_report_sources set cra_identity_ref='forged'$$,'22023','ADVERSE_ACTION_EVIDENCE_IMMUTABLE','report linkage is immutable');
select throws_ok($$update public.adverse_action_events set evidence_ref='forged'$$,'22023','ADVERSE_ACTION_EVIDENCE_IMMUTABLE','events are immutable');
select throws_ok($$delete from public.adverse_action_cases$$,'22023','ADVERSE_ACTION_EVIDENCE_IMMUTABLE','cases cannot be deleted');

select * from finish();
rollback;
