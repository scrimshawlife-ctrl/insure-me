begin;

select plan(9);

insert into public.agencies (agency_id,tenant_id,legal_name,display_name)
values ('d1000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','Readiness Agency','Readiness');

insert into public.tenant_configurations (tenant_configuration_id,tenant_id,agency_id,version,status)
values ('d2000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001',1,'ACTIVE');

insert into public.prospects (prospect_id,tenant_id,agency_id)
values ('d3000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001');

insert into public.quote_cases (
 quote_case_id,tenant_id,agency_id,tenant_configuration_id,tenant_configuration_version,
 jurisdiction,product_line,source_channel,state,prospect_id
) values (
 'd4000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001',
 'd2000000-0000-0000-0000-000000000001',1,'CA','PRIVATE_PASSENGER_AUTO','TEST','DATA_ENRICHMENT','d3000000-0000-0000-0000-000000000001'
);

insert into public.drivers (
 driver_id,tenant_id,agency_id,quote_case_id,relationship_role,first_name,last_name,date_of_birth,
 license_jurisdiction,confirmation_state,source_type
) values (
 'd5000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001',
 'NAMED_INSURED','Ready','Driver','1990-01-01','CA','CONFIRMED','CONSUMER'
);

insert into public.vehicles (
 vehicle_id,tenant_id,agency_id,quote_case_id,model_year,make,model,usage,confirmation_state,source_type
) values (
 'd6000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001',
 2024,'Synthetic','Sedan','COMMUTE','CONFIRMED','CONSUMER'
);

insert into public.coverage_requests (
 coverage_request_id,tenant_id,agency_id,quote_case_id,schema_version,requested_limits,preferences
) values (
 'd7000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001',
 1,'{}'::jsonb,'{}'::jsonb
);

insert into public.provider_bindings (
 provider_binding_id,tenant_id,agency_id,capability,adapter_id,adapter_version,jurisdiction,product_line,
 status,requires_report_authorization,purpose_code,required_for_readiness
) values (
 'd8000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001',
 'MVR','synthetic-mvr','synthetic-provider-v1','CA','PRIVATE_PASSENGER_AUTO','ACTIVE',true,'INSURANCE_UNDERWRITING',true
);

select is(public.recalculate_quote_readiness('d4000000-0000-0000-0000-000000000001'),1,'missing required provider result creates one readiness issue');
select ok(exists(select 1 from public.readiness_issues where quote_case_id='d4000000-0000-0000-0000-000000000001' and reason_code='MISSING_MVR_RESULT' and blocking),'missing MVR is blocking completeness issue');
select is((select count(*) from public.readiness_issues where quote_case_id='d4000000-0000-0000-0000-000000000001' and reason_code like '%RISK%'),0::bigint,'readiness produces no risk-scoring issue');

insert into public.permissible_purpose_decisions (
 decision_id,tenant_id,quote_case_id,tenant_configuration_version,jurisdiction,capability,purpose_code,outcome,policy_version
) values ('d9000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001',1,'CA','MVR','INSURANCE_UNDERWRITING','ALLOW','test-v1');

insert into public.external_requests (
 external_request_id,tenant_id,agency_id,quote_case_id,tenant_configuration_version,provider_binding_id,capability,
 permissible_purpose_decision_id,idempotency_key,request_hash,status
) values ('da000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001',1,'d8000000-0000-0000-0000-000000000001','MVR','d9000000-0000-0000-0000-000000000001','readiness','hash','SUCCEEDED');

insert into public.external_reports (
 external_report_id,tenant_id,agency_id,quote_case_id,external_request_id,provider_id,provider_product_id,status,retrieved_at,normalized_version
) values ('db000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','da000000-0000-0000-0000-000000000001','synthetic','MVR','PARTIAL','2026-08-23T00:00:00Z','v1');

select is(public.recalculate_quote_readiness('d4000000-0000-0000-0000-000000000001'),1,'partial provider result creates one warning');
select ok(exists(select 1 from public.readiness_issues where quote_case_id='d4000000-0000-0000-0000-000000000001' and reason_code='PARTIAL_MVR_RESULT' and not blocking),'partial MVR warns but does not block');

update public.external_reports set status='STALE',retrieved_at='2026-08-23T01:00:00Z' where external_report_id='db000000-0000-0000-0000-000000000001';
select is(public.recalculate_quote_readiness('d4000000-0000-0000-0000-000000000001'),1,'stale provider result creates one issue');
select ok(exists(select 1 from public.readiness_issues where quote_case_id='d4000000-0000-0000-0000-000000000001' and reason_code='STALE_MVR_RESULT' and blocking),'stale MVR blocks completeness');

update public.external_reports set status='SUCCESS',retrieved_at='2026-08-23T02:00:00Z' where external_report_id='db000000-0000-0000-0000-000000000001';
select is(public.recalculate_quote_readiness('d4000000-0000-0000-0000-000000000001'),0,'fresh successful required provider result clears readiness issues');
select is((select count(*) from public.readiness_issues where quote_case_id='d4000000-0000-0000-0000-000000000001' and resolution_state='OPEN'),0::bigint,'no open readiness issues remain after complete fresh data');

select * from finish();
rollback;
