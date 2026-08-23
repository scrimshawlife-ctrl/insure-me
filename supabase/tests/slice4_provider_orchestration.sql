begin;

select plan(11);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values
 ('a1000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','Provider Agency A','Provider A'),
 ('b1000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','Provider Agency B','Provider B');

insert into public.tenant_configurations (tenant_configuration_id,tenant_id,agency_id,version,status)
values
 ('a2000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',1,'ACTIVE'),
 ('b2000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001',1,'ACTIVE');

insert into public.agency_users (agency_user_id,tenant_id,agency_id,workforce_identity_id,status)
values
 ('a3000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a9000000-0000-0000-0000-000000000009','ACTIVE'),
 ('b3000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','a9000000-0000-0000-0000-000000000009','ACTIVE');

insert into public.prospects (prospect_id,tenant_id,agency_id)
values
 ('a4000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001'),
 ('b4000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001');

insert into public.quote_cases (quote_case_id,tenant_id,agency_id,tenant_configuration_id,tenant_configuration_version,jurisdiction,product_line,source_channel,state,prospect_id)
values
 ('a5000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001',1,'CA','PRIVATE_PASSENGER_AUTO','TEST','DATA_ENRICHMENT','a4000000-0000-0000-0000-000000000001'),
 ('b5000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001',1,'CA','PRIVATE_PASSENGER_AUTO','TEST','DATA_ENRICHMENT','b4000000-0000-0000-0000-000000000001');

insert into public.provider_bindings (provider_binding_id,tenant_id,agency_id,capability,adapter_id,adapter_version,jurisdiction,product_line,requires_report_authorization,purpose_code)
values
 ('a6000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','MVR','synthetic-mvr','synthetic-provider-v1','CA','PRIVATE_PASSENGER_AUTO',true,'INSURANCE_UNDERWRITING'),
 ('b6000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','MVR','synthetic-mvr','synthetic-provider-v1','CA','PRIVATE_PASSENGER_AUTO',true,'INSURANCE_UNDERWRITING');

insert into public.permissible_purpose_decisions (decision_id,tenant_id,quote_case_id,tenant_configuration_version,actor_id,jurisdiction,capability,purpose_code,outcome,policy_version)
values ('a7000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001',1,'a9000000-0000-0000-0000-000000000009','CA','MVR','INSURANCE_UNDERWRITING','ALLOW','synthetic-policy-v1');

insert into public.external_requests (external_request_id,tenant_id,agency_id,quote_case_id,tenant_configuration_version,provider_binding_id,capability,subject_ids,permissible_purpose_decision_id,idempotency_key,request_hash,status)
values ('a8000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001',1,'a6000000-0000-0000-0000-000000000001','MVR','{}','a7000000-0000-0000-0000-000000000001','idem-1','hash-1','PENDING');

insert into public.external_reports (external_report_id,tenant_id,agency_id,quote_case_id,external_request_id,provider_id,provider_product_id,status,retrieved_at,normalized_snapshot,normalized_version)
values ('a8100000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001','a8000000-0000-0000-0000-000000000001','synthetic','mvr','SUCCESS',now(),'{"licenseStatus":"VALID"}','synthetic-provider-v1');

insert into public.provenance_entries (provenance_entry_id,tenant_id,agency_id,quote_case_id,external_report_id,source_type,source_id,fact_key,transformation_version)
values ('a8200000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001','a8100000-0000-0000-0000-000000000001','PROVIDER','synthetic-report:mvr:success','licenseStatus','synthetic-provider-v1');

insert into public.underwriting_observations (observation_id,tenant_id,agency_id,quote_case_id,observation_type,normalized_value,provenance_entry_ids)
values ('a8300000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001','LICENSE_STATUS','"VALID"','{a8200000-0000-0000-0000-000000000001}');

set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub','a9000000-0000-0000-0000-000000000009','role','authenticated','app_metadata',json_build_object('active_tenant_id','a0000000-0000-0000-0000-000000000001'),'aal','aal2')::text,true);

select is((select count(*) from public.provider_bindings),1::bigint,'active workforce tenant sees one provider binding');
select is((select count(*) from public.external_requests),1::bigint,'active workforce tenant sees its external request');
select is((select count(*) from public.external_reports),1::bigint,'active workforce tenant sees its external report');
select is((select count(*) from public.provenance_entries),1::bigint,'active workforce tenant sees its provenance entry');
select is((select count(*) from public.underwriting_observations),1::bigint,'active workforce tenant sees its observation');

select throws_ok($$insert into public.external_requests (tenant_id,agency_id,quote_case_id,tenant_configuration_version,provider_binding_id,capability,permissible_purpose_decision_id,idempotency_key,request_hash) values ('a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001',1,'a6000000-0000-0000-0000-000000000001','MVR','a7000000-0000-0000-0000-000000000001','forbidden','hash')$$,'42501',null,'workforce cannot directly insert external requests');

select set_config('request.jwt.claims',json_build_object('sub','a9000000-0000-0000-0000-000000000009','role','authenticated','app_metadata',json_build_object('active_tenant_id','b0000000-0000-0000-0000-000000000001'),'aal','aal2')::text,true);
select is((select count(*) from public.external_requests),0::bigint,'switching active tenant hides tenant A external requests');
select is((select count(*) from public.external_reports),0::bigint,'switching active tenant hides tenant A reports');
select is((select count(*) from public.provenance_entries),0::bigint,'switching active tenant hides tenant A provenance');
select is((select count(*) from public.underwriting_observations),0::bigint,'switching active tenant hides tenant A observations');
select is((select count(*) from public.provider_bindings),1::bigint,'active tenant B sees only its own binding');

select * from finish();
rollback;
