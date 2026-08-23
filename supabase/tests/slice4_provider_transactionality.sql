begin;

select plan(15);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values ('a1000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','Synthetic Provider Agency','Provider Agency');

insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status
) values ('a2000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',1,'ACTIVE');

insert into public.prospects (prospect_id, tenant_id, agency_id)
values ('a3000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001');

insert into public.quote_cases (
 quote_case_id, tenant_id, agency_id, tenant_configuration_id, tenant_configuration_version,
 jurisdiction, product_line, source_channel, state, prospect_id
) values (
 'a4000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',
 'a2000000-0000-0000-0000-000000000001',1,'CA','PRIVATE_PASSENGER_AUTO','TEST','DATA_ENRICHMENT','a3000000-0000-0000-0000-000000000001'
);

insert into public.permissible_purpose_decisions (
 decision_id, tenant_id, quote_case_id, tenant_configuration_version, jurisdiction,
 capability, purpose_code, outcome, policy_version
) values (
 'a5000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001',1,
 'CA','MVR','INSURANCE_UNDERWRITING','ALLOW','synthetic-policy-v1'
);

insert into public.provider_bindings (
 provider_binding_id, tenant_id, agency_id, capability, adapter_id, adapter_version,
 jurisdiction, product_line, status, requires_report_authorization, purpose_code
) values (
 'a6000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',
 'MVR','synthetic-mvr','synthetic-provider-v1','CA','PRIVATE_PASSENGER_AUTO','ACTIVE',true,'INSURANCE_UNDERWRITING'
);

insert into public.external_requests (
 external_request_id, tenant_id, agency_id, quote_case_id, tenant_configuration_version,
 provider_binding_id, capability, permissible_purpose_decision_id, idempotency_key,
 request_hash, status
) values
 ('a7000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001',1,'a6000000-0000-0000-0000-000000000001','MVR','a5000000-0000-0000-0000-000000000001','idem-success','hash-success','PENDING'),
 ('a7000000-0000-0000-0000-000000000002','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001',1,'a6000000-0000-0000-0000-000000000001','MVR','a5000000-0000-0000-0000-000000000001','idem-nohit','hash-nohit','PENDING'),
 ('a7000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001',1,'a6000000-0000-0000-0000-000000000001','MVR','a5000000-0000-0000-0000-000000000001','idem-stale','hash-stale','PENDING'),
 ('a7000000-0000-0000-0000-000000000004','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001',1,'a6000000-0000-0000-0000-000000000001','MVR','a5000000-0000-0000-0000-000000000001','idem-retry','hash-retry','PENDING');

select lives_ok($$select public.claim_provider_request('a7000000-0000-0000-0000-000000000001','worker-1')$$,'pending request can be claimed');
select is((select attempt_count from public.external_requests where external_request_id='a7000000-0000-0000-0000-000000000001'),1,'claim increments attempt count');
select throws_ok($$select public.claim_provider_request('a7000000-0000-0000-0000-000000000001','worker-2')$$,'55000','PROVIDER_REQUEST_NOT_CLAIMABLE','running request cannot be double claimed');

select lives_ok($$select public.settle_provider_result(
 'a7000000-0000-0000-0000-000000000001','synthetic','MVR','synthetic-report-success','SUCCESS',
 '2026-08-23T00:00:00Z', '2026-08-24T00:00:00Z',
 '{"facts":{"licenseStatus":"VALID"}}'::jsonb,'synthetic-provider-v1','{}'::text[],
 '[{"sourceType":"PROVIDER","sourceId":"synthetic-report-success","normalizedFactKey":"licenseStatus","sourceField":"facts.licenseStatus","sourceTimestamp":"2026-08-23T00:00:00Z","transformationVersion":"synthetic-provider-v1","confidence":1}]'::jsonb,
 '[{"observationType":"LICENSE_STATUS","normalizedValue":"VALID","freshnessState":"CURRENT"}]'::jsonb
)$$,'running request settles atomically');
select is((select status::text from public.external_requests where external_request_id='a7000000-0000-0000-0000-000000000001'),'SUCCEEDED','successful result closes request');
select is((select count(*) from public.external_reports where external_request_id='a7000000-0000-0000-0000-000000000001'),1::bigint,'one external report is created');
select is((select count(*) from public.underwriting_observations where quote_case_id='a4000000-0000-0000-0000-000000000001' and observation_type='LICENSE_STATUS'),1::bigint,'observation is created through settlement');
select lives_ok($$select public.settle_provider_result(
 'a7000000-0000-0000-0000-000000000001','synthetic','MVR','synthetic-report-success','SUCCESS',
 '2026-08-23T00:00:00Z', '2026-08-24T00:00:00Z',
 '{"facts":{"licenseStatus":"VALID"}}'::jsonb,'synthetic-provider-v1','{}'::text[],'[]'::jsonb,'[]'::jsonb
)$$,'replayed settlement is idempotent');
select is((select count(*) from public.external_reports where external_request_id='a7000000-0000-0000-0000-000000000001'),1::bigint,'idempotent replay does not duplicate report');

select public.claim_provider_request('a7000000-0000-0000-0000-000000000002','worker-1');
select public.settle_provider_result(
 'a7000000-0000-0000-0000-000000000002','synthetic','MVR','synthetic-report-nohit','NO_HIT',
 '2026-08-23T00:00:00Z', '2026-08-24T00:00:00Z',null,'synthetic-provider-v1','{}'::text[],'[]'::jsonb,
 '[{"observationType":"SHOULD_NOT_EXIST","normalizedValue":true}]'::jsonb
);
select is((select count(*) from public.underwriting_observations where observation_type='SHOULD_NOT_EXIST'),0::bigint,'NO_HIT cannot create invented observations');

select public.claim_provider_request('a7000000-0000-0000-0000-000000000003','worker-1');
select public.settle_provider_result(
 'a7000000-0000-0000-0000-000000000003','synthetic','MVR','synthetic-report-stale','STALE',
 '2026-08-20T00:00:00Z', '2026-08-21T00:00:00Z','{"facts":{"licenseStatus":"VALID"}}'::jsonb,
 'synthetic-provider-v1','{}'::text[],'[]'::jsonb,
 '[{"observationType":"STALE_LICENSE_STATUS","normalizedValue":"VALID","freshnessState":"STALE"}]'::jsonb
);
select is((select freshness_state from public.underwriting_observations where observation_type='STALE_LICENSE_STATUS'),'STALE','stale result stays stale in observation layer');

select public.claim_provider_request('a7000000-0000-0000-0000-000000000004','worker-1');
select lives_ok($$select public.mark_provider_request_retry('a7000000-0000-0000-0000-000000000004','SYNTHETIC_TRANSIENT',0)$$,'running request can be returned to retry queue');
select is((select status::text from public.external_requests where external_request_id='a7000000-0000-0000-0000-000000000004'),'PENDING','retryable failure returns to pending');
select is((select attempt_count from public.external_requests where external_request_id='a7000000-0000-0000-0000-000000000004'),1,'retry preserves attempt count for bounded retries');

select is((select count(*) from public.audit_events where event_type='PROVIDER_RESULT_SETTLED' and quote_case_id='a4000000-0000-0000-0000-000000000001'),3::bigint,'each settled request creates exactly one audit settlement event');

select * from finish();
rollback;
