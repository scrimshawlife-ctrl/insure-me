begin;

select plan(14);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values ('a1000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','Identifier Test Agency','Identifier Test');

insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status
) values ('a2000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',1,'ACTIVE');

insert into public.prospects (prospect_id, tenant_id, agency_id)
values ('a3000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001');

insert into public.quote_cases (
 quote_case_id, tenant_id, agency_id, tenant_configuration_id, tenant_configuration_version,
 jurisdiction, product_line, source_channel, state, prospect_id
) values (
 'a4000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001',1,
 'CA','PRIVATE_PASSENGER_AUTO','TEST','CONSUMER_INPUT','a3000000-0000-0000-0000-000000000001'
);

insert into public.consumer_quote_access (
 tenant_id, agency_id, quote_case_id, consumer_identity_id, status, expires_at
) values ('a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001','a9000000-0000-0000-0000-000000000009','ACTIVE',now()+interval '1 hour');

create temporary table preservation_probe (
  driver_id uuid,
  vehicle_id uuid,
  driver_cipher text,
  driver_hash text,
  vehicle_cipher text,
  vehicle_hash text
);

select ok(not has_function_privilege('authenticated','private.replace_consumer_drivers_impl(uuid,jsonb)','EXECUTE'), 'authenticated cannot execute private driver mutation');
select ok(not has_function_privilege('authenticated','private.replace_consumer_vehicles_impl(uuid,jsonb)','EXECUTE'), 'authenticated cannot execute private vehicle mutation');

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','a9000000-0000-0000-0000-000000000009','role','authenticated','aal','aal1')::text, true);

select lives_ok($$select * from public.replace_consumer_drivers(
 'a4000000-0000-0000-0000-000000000001',
 '[{"relationshipRole":"NAMED_INSURED","firstName":"Alex","lastName":"Preserve","dateOfBirth":"1990-01-01","licenseJurisdiction":"CA","licenseCiphertextHex":"01020304","licenseKeyVersion":"synthetic-v1","licenseLookupHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","licenseLast4":"1234","yearsLicensed":10,"confirmationState":"CONFIRMED"}]'::jsonb
)$$, 'initial protected driver write succeeds');

select lives_ok($$select * from public.replace_consumer_vehicles(
 'a4000000-0000-0000-0000-000000000001',
 '[{"vinCiphertextHex":"05060708","vinKeyVersion":"synthetic-v1","vinLookupHash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","vinLast4":"5678","modelYear":2024,"make":"Synthetic","model":"Roadster","usage":"COMMUTE","annualMileage":9000,"confirmationState":"CONFIRMED"}]'::jsonb
)$$, 'initial protected vehicle write succeeds');

select ok(not (to_jsonb(d) ? 'license_identifier_ciphertext') and not (to_jsonb(d) ? 'license_identifier_lookup_hash'), 'driver mutation returns safe projection only')
from public.replace_consumer_drivers(
 'a4000000-0000-0000-0000-000000000001',
 '[{"driverId":null,"relationshipRole":"NAMED_INSURED","firstName":"Taylor","lastName":"Safe","dateOfBirth":"1991-02-02","licenseJurisdiction":"CA","yearsLicensed":9,"confirmationState":"CONFIRMED"}]'::jsonb
) d limit 1;

-- Restore a protected driver after the projection-shape probe above replaced the collection.
select * from public.replace_consumer_drivers(
 'a4000000-0000-0000-0000-000000000001',
 '[{"relationshipRole":"NAMED_INSURED","firstName":"Alex","lastName":"Preserve","dateOfBirth":"1990-01-01","licenseJurisdiction":"CA","licenseCiphertextHex":"01020304","licenseKeyVersion":"synthetic-v1","licenseLookupHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","licenseLast4":"1234","yearsLicensed":10,"confirmationState":"CONFIRMED"}]'::jsonb
);

select ok(not (to_jsonb(v) ? 'vin_ciphertext') and not (to_jsonb(v) ? 'vin_lookup_hash'), 'vehicle mutation returns safe projection only')
from public.replace_consumer_vehicles(
 'a4000000-0000-0000-0000-000000000001',
 '[{"vehicleId":null,"modelYear":2023,"make":"Synthetic","model":"Safe","usage":"PLEASURE","confirmationState":"CONFIRMED"}]'::jsonb
) v limit 1;

-- Restore a protected vehicle after the projection-shape probe above replaced the collection.
select * from public.replace_consumer_vehicles(
 'a4000000-0000-0000-0000-000000000001',
 '[{"vinCiphertextHex":"05060708","vinKeyVersion":"synthetic-v1","vinLookupHash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","vinLast4":"5678","modelYear":2024,"make":"Synthetic","model":"Roadster","usage":"COMMUTE","annualMileage":9000,"confirmationState":"CONFIRMED"}]'::jsonb
);

reset role;

insert into preservation_probe (driver_id, vehicle_id, driver_cipher, driver_hash, vehicle_cipher, vehicle_hash)
select d.driver_id, v.vehicle_id, encode(d.license_identifier_ciphertext,'hex'), d.license_identifier_lookup_hash,
       encode(v.vin_ciphertext,'hex'), v.vin_lookup_hash
from public.drivers d
cross join public.vehicles v
where d.quote_case_id='a4000000-0000-0000-0000-000000000001'
  and d.source_type='CONSUMER'
  and v.quote_case_id='a4000000-0000-0000-0000-000000000001'
  and v.source_type='CONSUMER';

select is((select driver_cipher from preservation_probe),'01020304','driver ciphertext persisted before masked edit');
select is((select vehicle_cipher from preservation_probe),'05060708','vehicle ciphertext persisted before masked edit');

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','a9000000-0000-0000-0000-000000000009','role','authenticated','aal','aal1')::text, true);

select lives_ok(format($sql$select * from public.replace_consumer_drivers(
 'a4000000-0000-0000-0000-000000000001',
 '[{"driverId":"%s","relationshipRole":"NAMED_INSURED","firstName":"Alexandra","lastName":"Preserve","dateOfBirth":"1990-01-01","licenseJurisdiction":"CA","yearsLicensed":11,"confirmationState":"CORRECTED"}]'::jsonb
)$sql$, (select driver_id from preservation_probe)), 'masked driver edit succeeds without resupplying license');

select lives_ok(format($sql$select * from public.replace_consumer_vehicles(
 'a4000000-0000-0000-0000-000000000001',
 '[{"vehicleId":"%s","modelYear":2024,"make":"Synthetic","model":"Roadster Plus","usage":"COMMUTE","annualMileage":9500,"confirmationState":"CORRECTED"}]'::jsonb
)$sql$, (select vehicle_id from preservation_probe)), 'masked vehicle edit succeeds without resupplying VIN');

reset role;

select is((select encode(license_identifier_ciphertext,'hex') from public.drivers where driver_id=(select driver_id from preservation_probe)), (select driver_cipher from preservation_probe), 'masked driver edit preserves ciphertext');
select is((select license_identifier_lookup_hash from public.drivers where driver_id=(select driver_id from preservation_probe)), (select driver_hash from preservation_probe), 'masked driver edit preserves lookup hash');
select is((select license_last4 from public.drivers where driver_id=(select driver_id from preservation_probe)), '1234', 'masked driver edit preserves display-safe last4');
select is((select encode(vin_ciphertext,'hex') from public.vehicles where vehicle_id=(select vehicle_id from preservation_probe)), (select vehicle_cipher from preservation_probe), 'masked vehicle edit preserves ciphertext');
select is((select vin_lookup_hash from public.vehicles where vehicle_id=(select vehicle_id from preservation_probe)), (select vehicle_hash from preservation_probe), 'masked vehicle edit preserves lookup hash');
select is((select vin_last4 from public.vehicles where vehicle_id=(select vehicle_id from preservation_probe)), '5678', 'masked vehicle edit preserves display-safe last4');

select * from finish();
rollback;
