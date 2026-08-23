begin;

select plan(14);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values ('91000000-0000-0000-0000-000000000001','90000000-0000-0000-0000-000000000001','Synthetic Intake Agency','Intake Agency');

insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status
) values ('92000000-0000-0000-0000-000000000001','90000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001',1,'ACTIVE');

insert into public.prospects (prospect_id, tenant_id, agency_id)
values
 ('93000000-0000-0000-0000-000000000001','90000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001'),
 ('93000000-0000-0000-0000-000000000002','90000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001');

insert into public.quote_cases (
 quote_case_id, tenant_id, agency_id, tenant_configuration_id, tenant_configuration_version,
 jurisdiction, product_line, source_channel, state, prospect_id
) values
 ('94000000-0000-0000-0000-000000000001','90000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001',1,'CA','PRIVATE_PASSENGER_AUTO','TEST','CONSUMER_INPUT','93000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000002','90000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001',1,'CA','PRIVATE_PASSENGER_AUTO','TEST','CONSUMER_INPUT','93000000-0000-0000-0000-000000000002');

insert into public.consumer_quote_access (
 tenant_id, agency_id, quote_case_id, consumer_identity_id, status, expires_at
) values ('90000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001','99000000-0000-0000-0000-000000000009','ACTIVE',now()+interval '1 hour');

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','99000000-0000-0000-0000-000000000009','role','authenticated','aal','aal1')::text, true);

select lives_ok($$select * from public.replace_consumer_drivers(
 '94000000-0000-0000-0000-000000000001',
 '[{"relationshipRole":"NAMED_INSURED","firstName":"Alex","lastName":"Test","dateOfBirth":"1990-01-01","licenseJurisdiction":"CA","licenseCiphertextHex":"010203","licenseKeyVersion":"synthetic-v1","licenseLookupHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","licenseLast4":"1234","yearsLicensed":12,"confirmationState":"CONFIRMED"}]'::jsonb
)$$, 'consumer can save drivers for owned quote');

select is((select count(*) from public.get_consumer_drivers('94000000-0000-0000-0000-000000000001')),1::bigint,'consumer reads one safe driver projection');
select throws_ok($$select license_identifier_ciphertext from public.drivers$$,'42501',null,'consumer cannot directly read driver protected fields');

select lives_ok($$select * from public.replace_consumer_vehicles(
 '94000000-0000-0000-0000-000000000001',
 '[{"vinCiphertextHex":"010203","vinKeyVersion":"synthetic-v1","vinLookupHash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","vinLast4":"5678","modelYear":2024,"make":"Synthetic","model":"Roadster","usage":"COMMUTE","annualMileage":9000,"confirmationState":"CONFIRMED"}]'::jsonb
)$$, 'consumer can save vehicles for owned quote');

select is((select count(*) from public.get_consumer_vehicles('94000000-0000-0000-0000-000000000001')),1::bigint,'consumer reads one safe vehicle projection');
select throws_ok($$select vin_ciphertext from public.vehicles$$,'42501',null,'consumer cannot directly read VIN ciphertext');

select lives_ok($$select public.upsert_consumer_coverage_request(
 '94000000-0000-0000-0000-000000000001',1,
 '{"bodilyInjury":"100/300","propertyDamage":"100"}'::jsonb,
 '{"collisionDeductible":500}'::jsonb,
 null
)$$,'consumer can save carrier-neutral coverage preferences');

select is((select count(*) from public.get_consumer_coverage_request('94000000-0000-0000-0000-000000000001')),1::bigint,'consumer reads saved coverage request');

select throws_ok($$select * from public.replace_consumer_drivers('94000000-0000-0000-0000-000000000002','[]'::jsonb)$$,'42501','CONSUMER_QUOTE_ACCESS_DENIED','consumer cannot mutate another quote drivers');
select throws_ok($$select * from public.replace_consumer_vehicles('94000000-0000-0000-0000-000000000002','[]'::jsonb)$$,'42501','CONSUMER_QUOTE_ACCESS_DENIED','consumer cannot mutate another quote vehicles');
select throws_ok($$select public.upsert_consumer_coverage_request('94000000-0000-0000-0000-000000000002',1,'{}'::jsonb,'{}'::jsonb,null)$$,'42501','CONSUMER_QUOTE_ACCESS_DENIED','consumer cannot mutate another quote coverage');

select lives_ok($$select * from public.complete_consumer_intake('94000000-0000-0000-0000-000000000001')$$,'consumer can complete intake when canonical minimum is present');
select is((select state::text from public.quote_cases where quote_case_id='94000000-0000-0000-0000-000000000001'),'DATA_ENRICHMENT','intake completion advances exactly to DATA_ENRICHMENT');

reset role;
select is((select count(*) from public.audit_events where quote_case_id='94000000-0000-0000-0000-000000000001' and event_type in ('CONSUMER_DRIVERS_REPLACED','CONSUMER_VEHICLES_REPLACED','CONSUMER_COVERAGE_REQUEST_SAVED','CONSUMER_INTAKE_COMPLETED')),4::bigint,'all intake writes and completion emit audit evidence');

select * from finish();
rollback;
