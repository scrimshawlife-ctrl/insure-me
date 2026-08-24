begin;

select plan(35);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values ('e1000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'Privacy Export Agency', 'Privacy Export');

insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status,
  enabled_jurisdictions, enabled_product_lines
) values (
  'e2000000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  1, 'ACTIVE', array['CA'], array['PRIVATE_PASSENGER_AUTO']
);

insert into public.tenant_hosts (
  tenant_host_id, hostname, tenant_id, agency_id,
  tenant_configuration_id, tenant_configuration_version, status
) values (
  'e3000000-0000-0000-0000-000000000001', 'privacy-export.test',
  'e0000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  'e2000000-0000-0000-0000-000000000001', 1, 'ACTIVE'
);

insert into public.person_private_profiles (
  person_id, tenant_id, agency_id, encrypted_payload, encryption_algorithm,
  key_version, email_lookup_hash, phone_lookup_hash
) values (
  'e4000000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  decode(repeat('ab', 40), 'hex'), 'AES-256-GCM', 'synthetic-key-v1',
  repeat('a', 64), repeat('b', 64)
);

insert into public.prospects (
  prospect_id, tenant_id, agency_id, person_id, source_classification
) values (
  'e4100000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  'e4000000-0000-0000-0000-000000000001', 'SYNTHETIC'
);

insert into public.quote_cases (
  quote_case_id, tenant_id, agency_id, tenant_configuration_id,
  tenant_configuration_version, jurisdiction, product_line, source_channel,
  state, prospect_id
) values (
  'e4200000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  'e2000000-0000-0000-0000-000000000001', 1, 'CA',
  'PRIVATE_PASSENGER_AUTO', 'WEB', 'CONSUMER_INPUT',
  'e4100000-0000-0000-0000-000000000001'
);

insert into public.drivers (
  driver_id, tenant_id, agency_id, quote_case_id, person_id,
  relationship_role, first_name, last_name, date_of_birth,
  license_jurisdiction, confirmation_state, source_type
) values (
  'e4300000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  'e4200000-0000-0000-0000-000000000001',
  'e4000000-0000-0000-0000-000000000001', 'NAMED_INSURED',
  'Avery', 'Synthetic', '1990-01-01', 'CA', 'CONFIRMED', 'CONSUMER'
);

insert into public.vehicles (
  vehicle_id, tenant_id, agency_id, quote_case_id, model_year,
  make, model, usage, confirmation_state, source_type
) values (
  'e4400000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  'e4200000-0000-0000-0000-000000000001', 2026,
  'Synthetic', 'Roadster', 'COMMUTE', 'CONFIRMED', 'CONSUMER'
);

insert into public.coverage_requests (
  coverage_request_id, tenant_id, agency_id, quote_case_id,
  requested_limits, preferences
) values (
  'e4500000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  'e4200000-0000-0000-0000-000000000001',
  '{"bodilyInjury":"100/300"}'::jsonb, '{"deductible":500}'::jsonb
);

create temporary table matched_request as
select * from public.create_privacy_request(
  'privacy-export.test', 'ACCESS', 'CA', 'WEB',
  decode(repeat('cd', 40), 'hex'), 'synthetic-key-v1',
  repeat('a', 64), repeat('b', 64), repeat('c', 64), repeat('d', 64),
  'e5000000-0000-4000-8000-000000000001'
);

create temporary table matched_verification as
select * from public.settle_privacy_identity_verification(
  'privacy-export.test', (select public_reference from matched_request),
  repeat('d', 64), 'e5100000-0000-4000-8000-000000000001', repeat('1', 64),
  'VERIFIED', 'synthetic-privacy-identity-v1', '1.0.0', 'synthetic-policy-v1',
  'synthetic-privacy-evidence:matched', array['SYNTHETIC_ASSERTION_ACCEPTED']
);

select has_table('public', 'privacy_discovery_runs', 'privacy discovery run table exists');
select has_table('public', 'privacy_export_artifacts', 'privacy export artifact table exists');
select hasnt_column('public', 'privacy_export_artifacts', 'plaintext_export', 'export artifacts never store plaintext');
select is(has_table_privilege('anon', 'public.privacy_export_artifacts', 'SELECT'), false, 'anonymous users cannot read export artifacts');
select is(
  has_function_privilege(
    'service_role',
    'public.prepare_privacy_discovery(text,uuid,text,uuid,text,text,text)',
    'EXECUTE'
  ), true, 'service role can prepare discovery'
);

create temporary table matched_prepared as
select * from public.prepare_privacy_discovery(
  'privacy-export.test', (select public_reference from matched_request),
  repeat('d', 64), 'e5200000-0000-4000-8000-000000000001', repeat('2', 64),
  'synthetic-privacy-export-v1', 'privacy-export-v1'
);

select is((select discovery_outcome::text from matched_prepared), 'MATCHED', 'unique protected lookup match is classified');
select is((select discovery_status::text from matched_prepared), 'PREPARED', 'new discovery is prepared before artifact settlement');
select is((select record_count from matched_prepared), 5, 'matched inventory counts person, case, driver, vehicle, and coverage');
select is(jsonb_array_length((select source_payload->'quoteCases' from matched_prepared)), 1, 'matched export source contains the scoped quote case');
select is(position(repeat('a', 64) in (select source_payload::text from matched_prepared)), 0, 'export source contains no lookup hashes');
select is(
  (select matched_person_id from public.privacy_requests where public_reference = (select public_reference from matched_request)),
  'e4000000-0000-0000-0000-000000000001'::uuid,
  'unique discovery attaches the canonical Person only after verification'
);

create temporary table matched_settled as
select * from public.settle_privacy_discovery(
  (select privacy_discovery_run_id from matched_prepared),
  decode(repeat('99', 40), 'hex'), 'synthetic-key-v1', repeat('8', 64), 5
);

select is((select state::text from matched_settled), 'APPLICABILITY_REVIEW', 'settlement advances the privacy workflow');
select is((select export_available from matched_settled), true, 'matched access request has an export');
select is((select status::text from public.privacy_discovery_runs where privacy_discovery_run_id = (select privacy_discovery_run_id from matched_prepared)), 'COMPLETED', 'settlement completes discovery');
select is((select count(*) from public.privacy_export_artifacts), 1::bigint, 'one encrypted artifact is persisted');
select is((select encode(encrypted_export, 'hex') from public.privacy_export_artifacts), repeat('99', 40), 'database stores only the supplied encrypted envelope');
select is((select count(*) from public.audit_events where event_type in ('PRIVACY_DISCOVERY_PREPARED', 'PRIVACY_DISCOVERY_COMPLETED')), 2::bigint, 'prepare and settle emit audit events');

create temporary table matched_replay as
select * from public.prepare_privacy_discovery(
  'privacy-export.test', (select public_reference from matched_request),
  repeat('d', 64), 'e5200000-0000-4000-8000-000000000001', repeat('2', 64),
  'synthetic-privacy-export-v1', 'privacy-export-v1'
);
select is((select discovery_status::text from matched_replay), 'COMPLETED', 'idempotent prepare replay returns completed status');
select is((select count(*) from public.privacy_discovery_runs), 1::bigint, 'prepare replay creates no duplicate run');
select is(
  (select export_available from public.settle_privacy_discovery(
    (select privacy_discovery_run_id from matched_prepared),
    decode(repeat('99', 40), 'hex'), 'synthetic-key-v1', repeat('8', 64), 5
  )), true, 'settlement replay returns the original result'
);
select is((select count(*) from public.privacy_export_artifacts), 1::bigint, 'settlement replay creates no duplicate artifact');

select is(
  (select export_ciphertext_hex from public.get_privacy_export_artifact(
    'privacy-export.test', (select public_reference from matched_request), repeat('d', 64)
  )), repeat('99', 40), 'valid requester credential retrieves the protected artifact'
);
select is((select count(*) from public.audit_events where event_type = 'PRIVACY_EXPORT_DOWNLOADED'), 1::bigint, 'successful export retrieval is audited');
select is(
  (select count(*) from public.get_privacy_export_artifact(
    'privacy-export.test', (select public_reference from matched_request), repeat('0', 64)
  )), 0::bigint, 'invalid credential reveals no export'
);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values ('e1000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'Other Privacy Agency', 'Other Privacy');
insert into public.person_private_profiles (
  person_id, tenant_id, agency_id, encrypted_payload, encryption_algorithm,
  key_version, email_lookup_hash
) values (
  'e4000000-0000-0000-0000-000000000099',
  'e0000000-0000-0000-0000-000000000002',
  'e1000000-0000-0000-0000-000000000002',
  decode(repeat('77', 40), 'hex'), 'AES-256-GCM', 'synthetic-key-v1',
  repeat('c', 64)
);

create temporary table no_match_request as
select * from public.create_privacy_request(
  'privacy-export.test', 'DELETION', 'CA', 'WEB',
  decode(repeat('ef', 40), 'hex'), 'synthetic-key-v1',
  repeat('c', 64), null, repeat('4', 64), repeat('e', 64),
  'e5000000-0000-4000-8000-000000000002'
);
create temporary table no_match_verification as
select * from public.settle_privacy_identity_verification(
  'privacy-export.test', (select public_reference from no_match_request),
  repeat('e', 64), 'e5100000-0000-4000-8000-000000000002', repeat('3', 64),
  'VERIFIED', 'synthetic-privacy-identity-v1', '1.0.0', 'synthetic-policy-v1',
  'synthetic-privacy-evidence:no-match', array['SYNTHETIC_ASSERTION_ACCEPTED']
);
create temporary table no_match_prepared as
select * from public.prepare_privacy_discovery(
  'privacy-export.test', (select public_reference from no_match_request),
  repeat('e', 64), 'e5200000-0000-4000-8000-000000000002', repeat('4', 64),
  'synthetic-privacy-export-v1', 'privacy-export-v1'
);
select is((select discovery_outcome::text from no_match_prepared), 'NO_MATCH', 'cross-tenant protected lookup material cannot create a match');
select is((select source_payload is null from no_match_prepared), true, 'no-match result exposes no candidate source');
create temporary table no_match_settled as
select * from public.settle_privacy_discovery(
  (select privacy_discovery_run_id from no_match_prepared), null, null, null, null
);
select is((select matched_person_id is null from public.privacy_requests where public_reference = (select public_reference from no_match_request)), true, 'no-match result attaches no Person');
select is((select count(*) from public.privacy_export_artifacts where privacy_request_id = (select privacy_request_id from public.privacy_requests where public_reference = (select public_reference from no_match_request))), 0::bigint, 'non-access no-match creates no export');
select is((select state::text from public.privacy_requests where public_reference = (select public_reference from no_match_request)), 'APPLICABILITY_REVIEW', 'no-match result requires applicability review');

insert into public.person_private_profiles (
  person_id, tenant_id, agency_id, encrypted_payload, encryption_algorithm,
  key_version, email_lookup_hash
) values
  ('e4000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', decode(repeat('11', 40), 'hex'), 'AES-256-GCM', 'synthetic-key-v1', repeat('f', 64)),
  ('e4000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', decode(repeat('22', 40), 'hex'), 'AES-256-GCM', 'synthetic-key-v1', repeat('f', 64));

create temporary table ambiguous_request as
select * from public.create_privacy_request(
  'privacy-export.test', 'ACCESS', 'CA', 'WEB',
  decode(repeat('33', 40), 'hex'), 'synthetic-key-v1',
  repeat('f', 64), null, repeat('5', 64), repeat('f', 64),
  'e5000000-0000-4000-8000-000000000003'
);
create temporary table ambiguous_verification as
select * from public.settle_privacy_identity_verification(
  'privacy-export.test', (select public_reference from ambiguous_request),
  repeat('f', 64), 'e5100000-0000-4000-8000-000000000003', repeat('5', 64),
  'VERIFIED', 'synthetic-privacy-identity-v1', '1.0.0', 'synthetic-policy-v1',
  'synthetic-privacy-evidence:ambiguous', array['SYNTHETIC_ASSERTION_ACCEPTED']
);
create temporary table ambiguous_prepared as
select * from public.prepare_privacy_discovery(
  'privacy-export.test', (select public_reference from ambiguous_request),
  repeat('f', 64), 'e5200000-0000-4000-8000-000000000003', repeat('6', 64),
  'synthetic-privacy-export-v1', 'privacy-export-v1'
);
select is((select discovery_outcome::text from ambiguous_prepared), 'AMBIGUOUS', 'multiple protected matches are classified for review');
select is((select source_payload is null from ambiguous_prepared), true, 'ambiguous result exposes no candidate identities');
create temporary table ambiguous_settled as
select * from public.settle_privacy_discovery(
  (select privacy_discovery_run_id from ambiguous_prepared), null, null, null, null
);
select is((select matched_person_id is null from public.privacy_requests where public_reference = (select public_reference from ambiguous_request)), true, 'ambiguous result attaches no Person');

create temporary table unverified_request as
select * from public.create_privacy_request(
  'privacy-export.test', 'ACCESS', 'CA', 'WEB',
  decode(repeat('44', 40), 'hex'), 'synthetic-key-v1',
  repeat('9', 64), null, repeat('7', 64), repeat('0', 64),
  'e5000000-0000-4000-8000-000000000004'
);
select throws_ok(
  $$select * from public.prepare_privacy_discovery(
    'privacy-export.test', (select public_reference from unverified_request),
    repeat('0', 64), 'e5200000-0000-4000-8000-000000000004', repeat('7', 64),
    'synthetic-privacy-export-v1', 'privacy-export-v1'
  )$$,
  '55000', 'PRIVACY_DISCOVERY_STATE_INVALID',
  'unverified requests cannot run discovery'
);
select throws_ok(
  $$select * from public.prepare_privacy_discovery(
    'privacy-export.test', (select public_reference from matched_request),
    repeat('d', 64), 'e5200000-0000-4000-8000-000000000001', repeat('7', 64),
    'synthetic-privacy-export-v1', 'privacy-export-v1'
  )$$,
  '22023', 'IDEMPOTENCY_KEY_REQUEST_MISMATCH',
  'discovery idempotency key cannot be reused for different input'
);
select is(
  has_function_privilege(
    'anon',
    'public.get_privacy_export_artifact(text,uuid,text)',
    'EXECUTE'
  ), false, 'anonymous users cannot execute export retrieval'
);

select * from finish();
rollback;
