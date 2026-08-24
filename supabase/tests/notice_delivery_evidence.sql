begin;
select plan(28);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name) values
('f1000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','Notice Delivery Agency','Notice Delivery');
insert into public.agency_users (agency_user_id,tenant_id,agency_id,workforce_identity_id,status) values
('f2000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f9000000-0000-0000-0000-000000000009','ACTIVE');
insert into public.roles (role_id,tenant_id,agency_id,name,permissions) values
('f3000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','policy-admin',array['POLICY_ADMIN']::public.permission_code[]);
insert into public.agency_user_roles values ('f2000000-0000-0000-0000-000000000001','f3000000-0000-0000-0000-000000000001');
insert into public.tenant_configurations (tenant_configuration_id,tenant_id,agency_id,version,status,effective_at) values
('f4000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001',1,'ACTIVE',now());
insert into public.person_private_profiles (person_id,tenant_id,agency_id,encrypted_payload,encryption_algorithm,key_version) values
('f4100000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001',decode('00','hex'),'AES-256-GCM','synthetic-key');
insert into public.prospects (prospect_id,tenant_id,agency_id,person_id,source_classification) values
('f4200000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f4100000-0000-0000-0000-000000000001','SYNTHETIC');
insert into public.quote_cases (quote_case_id,tenant_id,agency_id,tenant_configuration_id,tenant_configuration_version,jurisdiction,product_line,source_channel,state,prospect_id) values
('f4300000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f4000000-0000-0000-0000-000000000001',1,'CA','PRIVATE_PASSENGER_AUTO','WEB','CARRIER_RESPONSE','f4200000-0000-0000-0000-000000000001');
insert into public.provider_bindings (provider_binding_id,tenant_id,agency_id,capability,adapter_id,adapter_version,jurisdiction,product_line,purpose_code) values
('f4400000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','MVR','stub-mvr','1','CA','PRIVATE_PASSENGER_AUTO','INSURANCE_UNDERWRITING');
insert into public.permissible_purpose_decisions (decision_id,tenant_id,quote_case_id,tenant_configuration_version,jurisdiction,capability,purpose_code,policy_version,outcome,reason_codes) values
('f4500000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f4300000-0000-0000-0000-000000000001',1,'CA','MVR','INSURANCE_UNDERWRITING','synthetic-purpose-v1','ALLOW',array['SYNTHETIC']);
insert into public.external_requests (external_request_id,tenant_id,agency_id,quote_case_id,tenant_configuration_version,provider_binding_id,capability,permissible_purpose_decision_id,idempotency_key,request_hash,status,completed_at) values
('f4600000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f4300000-0000-0000-0000-000000000001',1,'f4400000-0000-0000-0000-000000000001','MVR','f4500000-0000-0000-0000-000000000001','provider-key',repeat('1',64),'SUCCEEDED',now());
insert into public.external_reports (external_report_id,tenant_id,agency_id,quote_case_id,external_request_id,provider_id,provider_product_id,status,retrieved_at,normalized_version) values
('f4700000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f4300000-0000-0000-0000-000000000001','f4600000-0000-0000-0000-000000000001','synthetic-cra','synthetic-mvr','SUCCESS',now(),'v1');
insert into public.carriers (carrier_id,tenant_id,agency_id,legal_name,display_name) values
('f4800000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','Synthetic Carrier','Synthetic Carrier');
insert into public.carrier_programs (carrier_program_id,tenant_id,agency_id,carrier_id,program_code,version,jurisdictions,product_lines,adapter_id,adapter_version,handoff_mode,required_field_policy_version,rating_input_policy_version,response_mapping_version,notice_ownership_policy_version,certification_state) values
('f4900000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f4800000-0000-0000-0000-000000000001','SYNTH-ND',1,array['CA'],array['PRIVATE_PASSENGER_AUTO'],'stub-carrier','1','STUB','required-v1','rating-v1','response-v1','ownership-v1','SYNTHETIC');
insert into public.carrier_submissions (carrier_submission_id,tenant_id,agency_id,quote_case_id,tenant_configuration_version,carrier_id,carrier_program_id,carrier_program_version,adapter_id,handoff_mode,mapping_version,rating_input_ids,idempotency_key,request_hash,status,completed_at) values
('f5000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f4300000-0000-0000-0000-000000000001',1,'f4800000-0000-0000-0000-000000000001','f4900000-0000-0000-0000-000000000001',1,'stub-carrier','STUB','mapping-v1','{}','carrier-key',repeat('2',64),'SUCCEEDED',now());
insert into public.carrier_decisions (carrier_decision_id,tenant_id,agency_id,carrier_submission_id,carrier_program_id,decision_status,reason_codes,response_mapping_version,received_at) values
('f5100000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f5000000-0000-0000-0000-000000000001','f4900000-0000-0000-0000-000000000001','DECLINED',array['SYNTHETIC_UNFAVORABLE'],'response-v1',now());
insert into public.notice_definitions (notice_definition_id,tenant_id,agency_id,notice_key,version,status,category,jurisdiction,product_line,title,body_markdown,content_hash,effective_at) values
('f5200000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','adverse-action',1,'SYNTHETIC','ADVERSE_ACTION','CA','PRIVATE_PASSENGER_AUTO','Synthetic adverse action notice','Synthetic only.',repeat('a',64),now());

select has_table('public','adverse_action_notice_deliveries','delivery envelope exists');
select has_table('public','adverse_action_notice_delivery_attempts','append-only attempts exist');
select col_type_is('public','adverse_action_notice_deliveries','channel','notice_delivery_channel','channel is closed');
select col_type_is('public','adverse_action_notice_deliveries','status','notice_delivery_status','status is closed');
select is(has_table_privilege('anon','public.adverse_action_notice_deliveries','SELECT'),false,'anonymous cannot enumerate deliveries');
select is(has_table_privilege('authenticated','public.adverse_action_notice_deliveries','INSERT'),false,'authenticated cannot directly insert delivery');
select is(has_table_privilege('authenticated','public.adverse_action_notice_delivery_attempts','UPDATE'),false,'attempts cannot be rewritten directly');
select is(has_function_privilege('authenticated','public.prepare_adverse_action_notice_delivery(uuid,uuid,text,public.notice_delivery_channel,text,text,text,text,public.notice_delivery_certification_state,uuid,text)','EXECUTE'),true,'authenticated may call checked preparation RPC');
select is(has_function_privilege('anon','public.settle_adverse_action_notice_delivery(uuid,public.notice_delivery_outcome,text,text,text,text,text[],uuid,text)','EXECUTE'),false,'anonymous cannot settle delivery');
select ok((select position('has_permission' in qual) > 0 from pg_policies where schemaname='public' and tablename='adverse_action_notice_deliveries' and policyname='adverse_action_notice_deliveries_workforce_select'),'delivery reads require agency-scoped policy administration');

set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub','f9000000-0000-0000-0000-000000000009','role','authenticated','app_metadata',json_build_object('active_tenant_id','f0000000-0000-0000-0000-000000000001'),'aal','aal2')::text,true);
create temporary table notice_case as select (public.create_adverse_action_case(
  'f4300000-0000-0000-0000-000000000001','f5100000-0000-0000-0000-000000000001','CARRIER','carrier-owner:synthetic',
  'authority:responsible-party','evidence:determination',array['RESPONSIBLE_PARTY_DETERMINED'],
  '[{"externalReportId":"f4700000-0000-0000-0000-000000000001","craIdentityRef":"cra:synthetic","disputeRouteRef":"dispute:synthetic","contributionBasisCode":"CONTRIBUTED_PARTLY"}]'::jsonb,
  'f5300000-0000-4000-8000-000000000001',repeat('b',64))).*;
select throws_ok($$select public.prepare_adverse_action_notice_delivery((select adverse_action_case_id from notice_case),'f5200000-0000-0000-0000-000000000001',repeat('a',64),'EMAIL','consumer:opaque','synthetic-notice-delivery-v1','1.0.0','synthetic-notice-delivery-policy-v1','SYNTHETIC','f5400000-0000-4000-8000-000000000001',repeat('c',64))$$,'22023','ADVERSE_ACTION_HANDOFF_REQUIRED','delivery requires explicit handoff');
create temporary table notice_handoff as select (public.record_adverse_action_handoff((select adverse_action_case_id from notice_case),'carrier-desk:synthetic','evidence:handoff',array['OWNER_ACKNOWLEDGED'],'f5500000-0000-4000-8000-000000000001',repeat('d',64))).*;
select throws_ok($$select public.prepare_adverse_action_notice_delivery((select adverse_action_case_id from notice_case),'f5200000-0000-0000-0000-000000000001',repeat('e',64),'EMAIL','consumer:opaque','synthetic-notice-delivery-v1','1.0.0','synthetic-notice-delivery-policy-v1','SYNTHETIC','f5400000-0000-4000-8000-000000000001',repeat('c',64))$$,'22023','ADVERSE_ACTION_NOTICE_NOT_AVAILABLE','content hash mismatch fails closed');
create temporary table prepared_delivery as select (public.prepare_adverse_action_notice_delivery(
  (select adverse_action_case_id from notice_case),'f5200000-0000-0000-0000-000000000001',repeat('a',64),'EMAIL','consumer:opaque',
  'synthetic-notice-delivery-v1','1.0.0','synthetic-notice-delivery-policy-v1','SYNTHETIC',
  'f5400000-0000-4000-8000-000000000001',repeat('c',64))).*;
select is((select status::text from prepared_delivery),'PREPARED','exact notice is prepared');
select is((select notice_version from prepared_delivery),1,'notice version is snapshotted');
select is((select notice_content_hash from prepared_delivery),repeat('a',64),'notice hash is snapshotted');
select is((select owner_type::text from prepared_delivery),'CARRIER','configured owner is snapshotted');
select is((select ownership_policy_version from prepared_delivery),'ownership-v1','ownership policy is snapshotted');
select is((select (public.prepare_adverse_action_notice_delivery((select adverse_action_case_id from notice_case),'f5200000-0000-0000-0000-000000000001',repeat('a',64),'EMAIL','consumer:opaque','synthetic-notice-delivery-v1','1.0.0','synthetic-notice-delivery-policy-v1','SYNTHETIC','f5400000-0000-4000-8000-000000000001',repeat('c',64))).adverse_action_notice_delivery_id),(select adverse_action_notice_delivery_id from prepared_delivery),'preparation replay is idempotent');
select throws_ok($$select public.prepare_adverse_action_notice_delivery((select adverse_action_case_id from notice_case),'f5200000-0000-0000-0000-000000000001',repeat('a',64),'EMAIL','consumer:opaque','synthetic-notice-delivery-v1','1.0.0','synthetic-notice-delivery-policy-v1','SYNTHETIC','f5400000-0000-4000-8000-000000000001',repeat('f',64))$$,'22023','NOTICE_DELIVERY_IDEMPOTENCY_MISMATCH','preparation replay cannot change request');
create temporary table delivered_notice as select (public.settle_adverse_action_notice_delivery(
  (select adverse_action_notice_delivery_id from prepared_delivery),'DELIVERED','synthetic-notice-delivery-v1','1.0.0','synthetic-notice-delivery-policy-v1','evidence:delivered',array['SYNTHETIC_DELIVERY_CONFIRMED'],'f5600000-0000-4000-8000-000000000001',repeat('1',64))).*;
select is((select status::text from delivered_notice),'DELIVERED','confirmed evidence marks delivered');
select isnt((select delivered_at from delivered_notice),null::timestamptz,'confirmed delivery has timestamp');
select is((select count(*) from public.adverse_action_notice_delivery_attempts),1::bigint,'attempt evidence is appended');
select is((select (public.settle_adverse_action_notice_delivery((select adverse_action_notice_delivery_id from prepared_delivery),'DELIVERED','synthetic-notice-delivery-v1','1.0.0','synthetic-notice-delivery-policy-v1','evidence:delivered',array['SYNTHETIC_DELIVERY_CONFIRMED'],'f5600000-0000-4000-8000-000000000001',repeat('1',64))).status::text),'DELIVERED','settlement replay is idempotent');
select throws_ok($$select public.settle_adverse_action_notice_delivery((select adverse_action_notice_delivery_id from prepared_delivery),'DELIVERED','invented-adapter','1.0.0','synthetic-notice-delivery-policy-v1','evidence:forged',array['FORGED'],'f5700000-0000-4000-8000-000000000001',repeat('2',64))$$,'22023','NOTICE_DELIVERY_ADAPTER_MISMATCH','adapter mismatch fails closed');
reset role;
select is((select count(*) from public.audit_events where event_type='ADVERSE_ACTION_NOTICE_PREPARED'),1::bigint,'preparation is audited');
select is((select count(*) from public.audit_events where event_type='ADVERSE_ACTION_NOTICE_DELIVERY_ATTEMPTED'),1::bigint,'attempt is audited');
select throws_ok($$update public.adverse_action_notice_delivery_attempts set evidence_ref='forged'$$,'22023','NOTICE_DELIVERY_EVIDENCE_IMMUTABLE','attempt evidence is immutable');
select throws_ok($$delete from public.adverse_action_notice_deliveries$$,'22023','NOTICE_DELIVERY_EVIDENCE_IMMUTABLE','delivery evidence cannot be deleted');

select * from finish();
rollback;
