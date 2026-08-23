begin;

select plan(6);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values
  ('a1000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','Agent Projection A','Projection A'),
  ('b1000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000002','Agent Projection B','Projection B');

insert into public.tenant_configurations (tenant_configuration_id,tenant_id,agency_id,version,status)
values
  ('a2000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',1,'ACTIVE'),
  ('b2000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000002',1,'ACTIVE');

insert into public.agency_users (agency_user_id,tenant_id,agency_id,workforce_identity_id,status)
values
  ('a3000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a9000000-0000-0000-0000-000000000009','ACTIVE'),
  ('b3000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000002','a9000000-0000-0000-0000-000000000009','ACTIVE');

insert into public.roles (role_id,tenant_id,agency_id,name,permissions)
values
  ('a4000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','reader',array['CASE_READ']::public.permission_code[]),
  ('b4000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000002','reader',array['CASE_READ']::public.permission_code[]);

insert into public.agency_user_roles (agency_user_id,role_id)
values
  ('a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001'),
  ('b3000000-0000-0000-0000-000000000002','b4000000-0000-0000-0000-000000000002');

insert into public.prospects (prospect_id,tenant_id,agency_id)
values
  ('a5000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001'),
  ('b5000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000002');

insert into public.quote_cases (
  quote_case_id,tenant_id,agency_id,tenant_configuration_id,tenant_configuration_version,
  jurisdiction,product_line,source_channel,state,prospect_id
) values
  ('a6000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001',1,'CA','PRIVATE_PASSENGER_AUTO','TEST','REVIEW_REQUIRED','a5000000-0000-0000-0000-000000000001'),
  ('b6000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-000000000002',1,'CA','PRIVATE_PASSENGER_AUTO','TEST','REVIEW_REQUIRED','b5000000-0000-0000-0000-000000000002');

insert into public.drivers (
  driver_id,tenant_id,agency_id,quote_case_id,relationship_role,first_name,last_name,date_of_birth,
  license_jurisdiction,license_identifier_ciphertext,license_identifier_key_version,license_identifier_lookup_hash,
  license_last4,confirmation_state,source_type
) values (
  'a7000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000001',
  'NAMED_INSURED','Case','Reader','1990-01-01','CA',decode('010203','hex'),'synthetic-v1',repeat('a',64),'1234','CONFIRMED','CONSUMER'
);

insert into public.vehicles (
  vehicle_id,tenant_id,agency_id,quote_case_id,vin_ciphertext,vin_key_version,vin_lookup_hash,vin_last4,
  model_year,make,model,usage,confirmation_state,source_type
) values (
  'a8000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000001',
  decode('040506','hex'),'synthetic-v1',repeat('b',64),'5678',2025,'Synthetic','Sedan','PERSONAL','CONFIRMED','CONSUMER'
);

insert into public.coverage_requests (
  coverage_request_id,tenant_id,agency_id,quote_case_id,schema_version,requested_limits,preferences
) values (
  'a8500000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000001',1,
  '{"bodilyInjury":"100/300"}'::jsonb,'{"collisionDeductible":500}'::jsonb
);

set local role authenticated;
select set_config('request.jwt.claims',json_build_object(
  'sub','a9000000-0000-0000-0000-000000000009',
  'role','authenticated',
  'app_metadata',json_build_object('active_tenant_id','a0000000-0000-0000-0000-000000000001'),
  'aal','aal2'
)::text,true);

select lives_ok(
  $$select public.get_workforce_case_intake('a6000000-0000-0000-0000-000000000001')$$,
  'AAL2 CASE_READ workforce can load active-tenant case projection'
);

select is(
  (public.get_workforce_case_intake('a6000000-0000-0000-0000-000000000001')->'drivers'->0->>'licenseLast4'),
  '1234',
  'safe projection exposes only driver license last4'
);

select ok(
  not (public.get_workforce_case_intake('a6000000-0000-0000-0000-000000000001')->'drivers'->0 ? 'licenseIdentifierCiphertext'),
  'safe driver projection omits license ciphertext'
);

select ok(
  not (public.get_workforce_case_intake('a6000000-0000-0000-0000-000000000001')->'vehicles'->0 ? 'vinLookupHash'),
  'safe vehicle projection omits VIN lookup hash'
);

select throws_ok(
  $$select public.get_workforce_case_intake('b6000000-0000-0000-0000-000000000002')$$,
  '42501','CASE_READ_NOT_PERMITTED',
  'active tenant A cannot project tenant B case'
);

select set_config('request.jwt.claims',json_build_object(
  'sub','a9000000-0000-0000-0000-000000000009',
  'role','authenticated',
  'app_metadata',json_build_object('active_tenant_id','a0000000-0000-0000-0000-000000000001'),
  'aal','aal1'
)::text,true);

select throws_ok(
  $$select public.get_workforce_case_intake('a6000000-0000-0000-0000-000000000001')$$,
  '42501','CASE_READ_NOT_PERMITTED',
  'AAL1 cannot use workforce case projection'
);

select * from finish();
rollback;
