begin;

select plan(35);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values (
  'b1000000-0000-0000-0000-000000000001',
  'b0000000-0000-0000-0000-000000000001',
  'Retention Agency', 'Retention'
);
insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status,
  enabled_jurisdictions, enabled_product_lines, retention_policy_set_id,
  effective_at
) values (
  'b2000000-0000-0000-0000-000000000001',
  'b0000000-0000-0000-0000-000000000001',
  'b1000000-0000-0000-0000-000000000001', 1, 'ACTIVE',
  array['CA'], array['PRIVATE_PASSENGER_AUTO'], 'synthetic-retention-v1',
  now() - interval '2 days'
);
insert into public.retention_policies (
  retention_policy_id, tenant_id, agency_id, policy_set_id, version,
  data_class, jurisdiction, retention_interval, disposition,
  certification_state, effective_at
) values
  ('b3000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'synthetic-retention-v1', 1, 'IDENTITY_PROFILE', 'CA', interval '1 second', 'DELETE', 'SYNTHETIC', now() - interval '2 days'),
  ('b3000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'synthetic-retention-v1', 1, 'CONSUMER_INPUT', 'CA', interval '1 second', 'ANONYMIZE', 'SYNTHETIC', now() - interval '2 days');
insert into public.person_private_profiles (
  person_id, tenant_id, agency_id, encrypted_payload, encryption_algorithm,
  key_version, email_lookup_hash, phone_lookup_hash, created_at
) values
  ('b4000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', decode(repeat('aa', 40), 'hex'), 'AES-256-GCM', 'synthetic-key-v1', repeat('a', 64), repeat('b', 64), now() - interval '2 days'),
  ('b4000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', decode(repeat('bb', 40), 'hex'), 'AES-256-GCM', 'synthetic-key-v1', repeat('c', 64), repeat('d', 64), now() - interval '2 days');
insert into public.prospects (
  prospect_id, tenant_id, agency_id, person_id, source_classification
) values
  ('b4100000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'b4000000-0000-0000-0000-000000000001', 'SYNTHETIC'),
  ('b4100000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'b4000000-0000-0000-0000-000000000002', 'SYNTHETIC');
insert into public.quote_cases (
  quote_case_id, tenant_id, agency_id, tenant_configuration_id,
  tenant_configuration_version, jurisdiction, product_line, source_channel,
  state, prospect_id
) values
  ('b4200000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001', 1, 'CA', 'PRIVATE_PASSENGER_AUTO', 'WEB', 'CLOSED', 'b4100000-0000-0000-0000-000000000001'),
  ('b4200000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001', 1, 'CA', 'PRIVATE_PASSENGER_AUTO', 'WEB', 'RETENTION_HOLD', 'b4100000-0000-0000-0000-000000000002');
insert into public.drivers (
  driver_id, tenant_id, agency_id, quote_case_id, person_id,
  relationship_role, first_name, last_name, date_of_birth,
  license_jurisdiction, license_identifier_ciphertext,
  license_identifier_key_version, license_identifier_lookup_hash,
  license_last4, source_ref
) values
  ('b4300000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'b4200000-0000-0000-0000-000000000001', 'b4000000-0000-0000-0000-000000000001', 'PRIMARY', 'Synthetic', 'Delete', date '1990-01-01', 'CA', decode(repeat('11', 40), 'hex'), 'synthetic-key-v1', repeat('1', 64), '1234', 'consumer'),
  ('b4300000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'b4200000-0000-0000-0000-000000000002', 'b4000000-0000-0000-0000-000000000002', 'PRIMARY', 'Synthetic', 'Hold', date '1991-01-01', 'CA', decode(repeat('22', 40), 'hex'), 'synthetic-key-v1', repeat('2', 64), '5678', 'consumer');
insert into public.vehicles (
  vehicle_id, tenant_id, agency_id, quote_case_id, vin_ciphertext,
  vin_key_version, vin_lookup_hash, vin_last4, model_year, make, model,
  garaging_postal_code, usage, source_ref
) values
  ('b4400000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'b4200000-0000-0000-0000-000000000001', decode(repeat('33', 40), 'hex'), 'synthetic-key-v1', repeat('3', 64), 'ABCD', 2024, 'Example', 'One', '94040', 'COMMUTE', 'consumer'),
  ('b4400000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'b4200000-0000-0000-0000-000000000002', decode(repeat('44', 40), 'hex'), 'synthetic-key-v1', repeat('4', 64), 'EFGH', 2024, 'Example', 'Two', '94041', 'COMMUTE', 'consumer');
insert into public.coverage_requests (
  coverage_request_id, tenant_id, agency_id, quote_case_id, notes
) values
  ('b4500000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'b4200000-0000-0000-0000-000000000001', 'sensitive note'),
  ('b4500000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'b4200000-0000-0000-0000-000000000002', 'held note');
insert into public.privacy_requests (
  privacy_request_id, public_reference, tenant_id, agency_id, request_type,
  state, identity_verification_state, jurisdiction, intake_channel,
  matched_person_id, identity_verified_at, received_at
) values
  ('b5000000-0000-0000-0000-000000000001', 'b5100000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'DELETION', 'IN_PROGRESS', 'VERIFIED', 'CA', 'WEB', 'b4000000-0000-0000-0000-000000000001', now(), now() - interval '2 days'),
  ('b5000000-0000-0000-0000-000000000002', 'b5100000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'DELETION', 'IN_PROGRESS', 'VERIFIED', 'CA', 'WEB', 'b4000000-0000-0000-0000-000000000002', now(), now() - interval '2 days');
insert into public.privacy_rights_executions (
  privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id,
  idempotency_key, request_hash, policy_version, status, outcome,
  action_summary, completed_at
) values
  ('b5200000-0000-0000-0000-000000000001', 'b5000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'b5300000-0000-4000-8000-000000000001', repeat('5', 64), 'synthetic-privacy-rights-v1', 'COMPLETED', 'PARTIALLY_APPLIED', '{"DELETE_QUEUED":2}', now()),
  ('b5200000-0000-0000-0000-000000000002', 'b5000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'b5300000-0000-4000-8000-000000000002', repeat('6', 64), 'synthetic-privacy-rights-v1', 'COMPLETED', 'PARTIALLY_APPLIED', '{"DELETE_QUEUED":2}', now());
insert into public.privacy_rights_actions (
  privacy_rights_action_id, privacy_rights_execution_id, privacy_request_id,
  tenant_id, agency_id, data_category, disposition, record_count,
  reason_codes, created_at
) values
  ('b5400000-0000-0000-0000-000000000001', 'b5200000-0000-0000-0000-000000000001', 'b5000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'IDENTITY_PROFILE', 'DELETE_QUEUED', 1, array['RETENTION_DISPOSITION_REQUIRED'], now() - interval '2 days'),
  ('b5400000-0000-0000-0000-000000000002', 'b5200000-0000-0000-0000-000000000001', 'b5000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'CONSUMER_INPUT', 'DELETE_QUEUED', 3, array['RETENTION_DISPOSITION_REQUIRED'], now() - interval '2 days'),
  ('b5400000-0000-0000-0000-000000000003', 'b5200000-0000-0000-0000-000000000002', 'b5000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'IDENTITY_PROFILE', 'DELETE_QUEUED', 1, array['RETENTION_DISPOSITION_REQUIRED'], now() - interval '2 days'),
  ('b5400000-0000-0000-0000-000000000004', 'b5200000-0000-0000-0000-000000000002', 'b5000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'CONSUMER_INPUT', 'DELETE_QUEUED', 3, array['RETENTION_DISPOSITION_REQUIRED'], now() - interval '2 days');

select has_table('public', 'retention_disposition_runs', 'retention run table exists');
select has_table('public', 'retention_disposition_items', 'retention item table exists');
select has_table('public', 'retention_disposition_attempts', 'append-only attempt table exists');
select is(has_table_privilege('anon', 'public.retention_disposition_items', 'SELECT'), false, 'anonymous cannot enumerate retention work');
select is(has_table_privilege('authenticated', 'public.retention_disposition_attempts', 'INSERT'), false, 'authenticated cannot forge retention evidence');
select is(has_function_privilege('service_role', 'public.prepare_retention_disposition_run(uuid,timestamp with time zone,integer,public.retention_policy_certification_state)', 'EXECUTE'), true, 'service role can schedule retention');
select is(has_function_privilege('anon', 'public.execute_retention_disposition_run(uuid,integer)', 'EXECUTE'), false, 'anonymous cannot execute retention');

create temporary table retention_prepared as
select * from public.prepare_retention_disposition_run(
  'b6000000-0000-4000-8000-000000000001', now(), 100, 'SYNTHETIC'
);
select is((select run_status::text from retention_prepared), 'IN_PROGRESS', 'eligible work starts an in-progress run');
select is((select status_summary->>'SCHEDULED' from retention_prepared), '2', 'eligible items are scheduled');
select is((select status_summary->>'BLOCKED' from retention_prepared), '2', 'hold-scoped items fail closed');
select is((select count(*) from public.retention_disposition_items), 4::bigint, 'each queued category receives one work item');
select is((select count(*) from public.retention_disposition_items where reason_codes @> array['LEGAL_HOLD_SIGNAL']), 2::bigint, 'hold evidence is explicit');
select is((select count(distinct retention_policy_id) from public.retention_disposition_items where status = 'SCHEDULED'), 2::bigint, 'items retain exact policy versions');

create temporary table retention_executed as
select * from public.execute_retention_disposition_run(
  (select retention_disposition_run_id from retention_prepared), 100
);
select is((select run_status::text from retention_executed), 'ATTENTION_REQUIRED', 'blocked hold work keeps operator attention visible');
select is((select status_summary->>'COMPLETED' from retention_executed), '2', 'eligible destructive work completes');
select is((select status_summary->>'BLOCKED' from retention_executed), '2', 'held work remains blocked');
select is((select count(*) from public.retention_disposition_attempts), 2::bigint, 'each executed item creates append-only evidence');
select is((select count(*) from public.retention_disposition_attempts where evidence_ref ~ '^retention:[0-9a-f]{64}$'), 2::bigint, 'evidence references are opaque digests');
select is((select count(*) from public.retention_disposition_attempts where request_hash ~ '^[0-9a-f]{64}$'), 2::bigint, 'attempt request evidence is keyed and opaque');
select like((select key_version from public.person_private_profiles where person_id = 'b4000000-0000-0000-0000-000000000001'), 'DESTROYED:%', 'identity encryption material is destroyed');
select is((select email_lookup_hash is null and phone_lookup_hash is null from public.person_private_profiles where person_id = 'b4000000-0000-0000-0000-000000000001'), true, 'identity lookup material is removed');
select is((select first_name from public.drivers where driver_id = 'b4300000-0000-0000-0000-000000000001'), 'REDACTED', 'consumer driver identity is anonymized');
select is((select license_identifier_ciphertext is null from public.drivers where driver_id = 'b4300000-0000-0000-0000-000000000001'), true, 'driver license identifier is removed');
select is((select vin_ciphertext is null and garaging_postal_code is null from public.vehicles where vehicle_id = 'b4400000-0000-0000-0000-000000000001'), true, 'vehicle identifiers are removed');
select is((select notes is null from public.coverage_requests where coverage_request_id = 'b4500000-0000-0000-0000-000000000001'), true, 'free-form consumer notes are removed');
select is((select state::text from public.privacy_requests where privacy_request_id = 'b5000000-0000-0000-0000-000000000001'), 'COMPLETED', 'request closes after every required local disposition completes');
select is((select state::text from public.privacy_requests where privacy_request_id = 'b5000000-0000-0000-0000-000000000002'), 'IN_PROGRESS', 'held request remains open');
select is((select key_version from public.person_private_profiles where person_id = 'b4000000-0000-0000-0000-000000000002'), 'synthetic-key-v1', 'held identity data remains unchanged');
select is((select first_name from public.drivers where driver_id = 'b4300000-0000-0000-0000-000000000002'), 'Synthetic', 'held consumer input remains unchanged');
select is((select count(*) from public.audit_events where event_type = 'RETENTION_DISPOSITION_ATTEMPTED'), 2::bigint, 'each disposition attempt is audited');

create temporary table retention_replay as
select * from public.prepare_retention_disposition_run(
  'b6000000-0000-4000-8000-000000000001',
  (select as_of from public.retention_disposition_runs where idempotency_key = 'b6000000-0000-4000-8000-000000000001'),
  100, 'SYNTHETIC'
);
select is((select retention_disposition_run_id from retention_replay), (select retention_disposition_run_id from retention_prepared), 'idempotent replay returns the same run');
select is((select count(*) from public.retention_disposition_runs), 1::bigint, 'replay creates no duplicate run');
select throws_ok(
  $$select * from public.prepare_retention_disposition_run(
    'b6000000-0000-4000-8000-000000000001', now() + interval '1 day',
    100, 'SYNTHETIC')$$,
  '22023', 'IDEMPOTENCY_KEY_REQUEST_MISMATCH',
  'idempotency reuse cannot change the scheduling boundary'
);
select throws_ok(
  $$update public.retention_disposition_attempts set evidence_ref = 'forged'$$,
  '22023', 'RETENTION_ATTEMPT_IMMUTABLE',
  'attempt evidence is immutable'
);
select is((select count(*) from public.audit_events where event_type = 'RETENTION_DISPOSITION_SCHEDULED'), 1::bigint, 'scheduling is audited once per tenant and agency');

select * from finish();
rollback;
