begin;

select plan(6);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values ('b1000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','Mutation Projection Agency','Mutation Projection');

insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status
) values ('b2000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001',1,'ACTIVE');

insert into public.prospects (prospect_id, tenant_id, agency_id)
values ('b3000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001');

insert into public.quote_cases (
 quote_case_id, tenant_id, agency_id, tenant_configuration_id, tenant_configuration_version,
 jurisdiction, product_line, source_channel, state, prospect_id
) values (
 'b4000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001',1,
 'CA','PRIVATE_PASSENGER_AUTO','TEST','CONSUMER_INPUT','b3000000-0000-0000-0000-000000000001'
);

insert into public.consumer_quote_access (
 tenant_id, agency_id, quote_case_id, consumer_identity_id, status, expires_at
) values ('b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','b9000000-0000-0000-0000-000000000009','ACTIVE',now()+interval '1 hour');

select ok(not has_function_privilege('authenticated','private.replace_consumer_drivers_impl(uuid,jsonb)','EXECUTE'), 'authenticated cannot execute private driver mutation');
select ok(not has_function_privilege('authenticated','private.replace_consumer_vehicles_impl(uuid,jsonb)','EXECUTE'), 'authenticated cannot execute private vehicle mutation');

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','b9000000-0000-0000-0000-000000000009','role','authenticated','aal','aal1')::text, true);

select lives_ok($$select * from public.replace_consumer_drivers(
 'b4000000-0000-0000-0000-000000000001',
 '[{"relationshipRole":"NAMED_INSURED","firstName":"Safe","lastName":"Driver","dateOfBirth":"1990-01-01","licenseJurisdiction":"CA","licenseCiphertextHex":"01020304","licenseKeyVersion":"synthetic-v1","licenseLookupHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","licenseLast4":"1234","yearsLicensed":10,"confirmationState":"CONFIRMED"}]'::jsonb
)$$, 'public driver mutation remains executable');

select ok(
  not (to_jsonb(d) ? 'license_identifier_ciphertext')
  and not (to_jsonb(d) ? 'license_identifier_key_version')
  and not (to_jsonb(d) ? 'license_identifier_lookup_hash'),
  'public driver mutation omits protected identifier fields'
)
from public.replace_consumer_drivers(
 'b4000000-0000-0000-0000-000000000001',
 '[{"relationshipRole":"NAMED_INSURED","firstName":"Safe","lastName":"Driver","dateOfBirth":"1990-01-01","licenseJurisdiction":"CA","yearsLicensed":10,"confirmationState":"CONFIRMED"}]'::jsonb
) d limit 1;

select lives_ok($$select * from public.replace_consumer_vehicles(
 'b4000000-0000-0000-0000-000000000001',
 '[{"vinCiphertextHex":"05060708","vinKeyVersion":"synthetic-v1","vinLookupHash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","vinLast4":"5678","modelYear":2024,"make":"Safe","model":"Vehicle","usage":"COMMUTE","confirmationState":"CONFIRMED"}]'::jsonb
)$$, 'public vehicle mutation remains executable');

select ok(
  not (to_jsonb(v) ? 'vin_ciphertext')
  and not (to_jsonb(v) ? 'vin_key_version')
  and not (to_jsonb(v) ? 'vin_lookup_hash'),
  'public vehicle mutation omits protected identifier fields'
)
from public.replace_consumer_vehicles(
 'b4000000-0000-0000-0000-000000000001',
 '[{"modelYear":2024,"make":"Safe","model":"Vehicle","usage":"COMMUTE","confirmationState":"CONFIRMED"}]'::jsonb
) v limit 1;

select * from finish();
rollback;
