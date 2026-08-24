begin;
select plan(26);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name) values
('a1100000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','Evidence Export Agency','Evidence Export');
insert into public.agency_users (agency_user_id,tenant_id,agency_id,workforce_identity_id,status) values
('a1200000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001','a1900000-0000-0000-0000-000000000009','ACTIVE'),
('a1200000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001','a1900000-0000-0000-0000-000000000008','ACTIVE');
insert into public.roles (role_id,tenant_id,agency_id,name,permissions) values
('a1300000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001','evidence-exporter',array['AUDIT_READ','EXPORT_DATA']::public.permission_code[]),
('a1300000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001','audit-reader',array['AUDIT_READ']::public.permission_code[]);
insert into public.agency_user_roles values
('a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-000000000001'),
('a1200000-0000-0000-0000-000000000002','a1300000-0000-0000-0000-000000000002');
insert into public.tenant_configurations (tenant_configuration_id,tenant_id,agency_id,version,status,effective_at) values
('a1400000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001',7,'ACTIVE',now());
insert into public.person_private_profiles (person_id,tenant_id,agency_id,encrypted_payload,encryption_algorithm,key_version) values
('a1410000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001',decode('00','hex'),'AES-256-GCM','synthetic-key');
insert into public.prospects (prospect_id,tenant_id,agency_id,person_id,source_classification) values
('a1420000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001','a1410000-0000-0000-0000-000000000001','SYNTHETIC');
insert into public.quote_cases (quote_case_id,tenant_id,agency_id,tenant_configuration_id,tenant_configuration_version,jurisdiction,product_line,source_channel,state,prospect_id) values
('a1430000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001','a1400000-0000-0000-0000-000000000001',7,'CA','PRIVATE_PASSENGER_AUTO','WEB','FOLLOW_UP','a1420000-0000-0000-0000-000000000001');
insert into public.notice_definitions (notice_definition_id,tenant_id,agency_id,notice_key,version,status,category,jurisdiction,product_line,title,body_markdown,content_hash,effective_at) values
('a1440000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001','synthetic-authorization',3,'SYNTHETIC','REPORT_AUTHORIZATION','CA','PRIVATE_PASSENGER_AUTO','Synthetic authorization','must-not-appear-in-export',repeat('a',64),now());
insert into public.consent_records (consent_record_id,tenant_id,agency_id,quote_case_id,consumer_identity_id,subject_ref,notice_definition_id,notice_version,notice_content_hash,action_type,presented_at,acted_at,channel,evidence_ref,idempotency_key) values
('a1450000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001','a1430000-0000-0000-0000-000000000001','a1910000-0000-0000-0000-000000000001','consumer:opaque','a1440000-0000-0000-0000-000000000001',3,repeat('a',64),'AUTHORIZE',now(),now(),'WEB','evidence:consent','consent-key');
insert into public.permissible_purpose_decisions (decision_id,tenant_id,quote_case_id,tenant_configuration_version,jurisdiction,capability,purpose_code,policy_version,outcome,reason_codes) values
('a1460000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a1430000-0000-0000-0000-000000000001',7,'CA','MVR','INSURANCE_UNDERWRITING','purpose-v7','ALLOW',array['SYNTHETIC']);
insert into public.audit_events (audit_event_id,tenant_id,agency_id,quote_case_id,event_type,actor_id,subject_ref,configuration_version_ref,policy_version_refs,outcome,reason_codes,integrity_hash,metadata) values
('a1470000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001','a1430000-0000-0000-0000-000000000001','SYNTHETIC_REGULATED_ACTION','a1900000-0000-0000-0000-000000000009','case:opaque','7',array['purpose-v7'],'SUCCEEDED',array['SYNTHETIC'],repeat('b',64),'[{"rawSensitive":"must-not-export"}]');

select has_table('public','compliance_evidence_exports','compliance export table exists');
select is((select relrowsecurity from pg_class where oid='public.compliance_evidence_exports'::regclass),true,'export artifact table has RLS');
select is(has_table_privilege('anon','public.compliance_evidence_exports','SELECT'),false,'anonymous cannot read export artifacts');
select is(has_table_privilege('authenticated','public.compliance_evidence_exports','SELECT'),false,'authenticated cannot directly read export artifacts');
select is(has_table_privilege('authenticated','public.compliance_evidence_exports','INSERT'),false,'authenticated cannot directly create artifacts');
select is(has_function_privilege('authenticated','public.create_compliance_evidence_export(uuid,timestamptz,text,text[],uuid,text)','EXECUTE'),true,'authenticated may call checked create RPC');
select is(has_function_privilege('anon','public.get_compliance_evidence_export(uuid)','EXECUTE'),false,'anonymous cannot download exports');

set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub','a1900000-0000-0000-0000-000000000009','role','authenticated','app_metadata',json_build_object('active_tenant_id','a1000000-0000-0000-0000-000000000001'),'aal','aal2')::text,true);
create temporary table created_export as select * from public.create_compliance_evidence_export(
  'a1430000-0000-0000-0000-000000000001',now(),'audit:synthetic-rehearsal',array['SYNTHETIC_REHEARSAL'],
  'a1480000-0000-4000-8000-000000000001',repeat('c',64));
select is((select schema_version from created_export),'compliance-evidence-bundle-v1','schema version is explicit');
select is((select quote_case_id from created_export),'a1430000-0000-0000-0000-000000000001'::uuid,'export is case scoped');
select is((select length(manifest_hash) from created_export),64,'summary returns manifest integrity hash');
select is((select evidence_record_count from created_export),3,'bounded evidence count is recorded');
select is((select count(*) from public.create_compliance_evidence_export('a1430000-0000-0000-0000-000000000001',now(),'audit:synthetic-rehearsal',array['SYNTHETIC_REHEARSAL'],'a1480000-0000-4000-8000-000000000001',repeat('c',64))),1::bigint,'create replay is idempotent');
select throws_ok($$select public.create_compliance_evidence_export('a1430000-0000-0000-0000-000000000001',now(),'audit:synthetic-rehearsal',array['SYNTHETIC_REHEARSAL'],'a1480000-0000-4000-8000-000000000001',repeat('d',64))$$,'22023','COMPLIANCE_EXPORT_IDEMPOTENCY_MISMATCH','replay cannot change request evidence');
select throws_ok($$select public.create_compliance_evidence_export('a1430000-0000-0000-0000-000000000001',now() + interval '1 minute','audit:synthetic-rehearsal',array['SYNTHETIC_REHEARSAL'],'a1480000-0000-4000-8000-000000000002',repeat('e',64))$$,'22023','COMPLIANCE_EXPORT_INPUT_INVALID','future cutoff fails closed');
create temporary table downloaded_export as select * from public.get_compliance_evidence_export((select compliance_evidence_export_id from created_export));
select is((select manifest->>'schemaVersion' from downloaded_export),'compliance-evidence-bundle-v1','download returns versioned manifest');
select is((select jsonb_array_length(manifest->'auditTimeline') from downloaded_export),1,'snapshot has exact as-of audit timeline');
select is((select jsonb_array_length(manifest->'noticeAndConsentEvidence') from downloaded_export),1,'consent provenance is included');
select is((select jsonb_array_length(manifest->'purposeEvidence') from downloaded_export),1,'purpose provenance is included');
select is((select position('must-not-export' in manifest::text) from downloaded_export),0,'notice body and arbitrary audit metadata are excluded');
reset role;
select is((select manifest_hash from public.compliance_evidence_exports),encode(extensions.digest((select manifest::text from public.compliance_evidence_exports),'sha256'),'hex'),'stored manifest hash verifies');
select is((select count(*) from public.audit_events where event_type='COMPLIANCE_EVIDENCE_EXPORT_CREATED'),1::bigint,'creation is audited once');
select is((select count(*) from public.audit_events where event_type='COMPLIANCE_EVIDENCE_EXPORT_DOWNLOADED'),1::bigint,'download is separately audited');
select throws_ok($$update public.compliance_evidence_exports set purpose_ref='forged'$$,'22023','COMPLIANCE_EVIDENCE_EXPORT_IMMUTABLE','artifact cannot be rewritten');
select throws_ok($$delete from public.compliance_evidence_exports$$,'22023','COMPLIANCE_EVIDENCE_EXPORT_IMMUTABLE','artifact cannot be deleted');

set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub','a1900000-0000-0000-0000-000000000008','role','authenticated','app_metadata',json_build_object('active_tenant_id','a1000000-0000-0000-0000-000000000001'),'aal','aal2')::text,true);
select throws_ok($$select public.create_compliance_evidence_export('a1430000-0000-0000-0000-000000000001',now(),'audit:unauthorized',array['UNAUTHORIZED'],'a1480000-0000-4000-8000-000000000003',repeat('f',64))$$,'P0002','COMPLIANCE_EXPORT_SCOPE_NOT_FOUND','audit-only user cannot create export');
select throws_ok($$select public.get_compliance_evidence_export((select compliance_evidence_export_id from created_export))$$,'P0002','COMPLIANCE_EXPORT_NOT_FOUND','audit-only user cannot download export');

select * from finish();
rollback;
