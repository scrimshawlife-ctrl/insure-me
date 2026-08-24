begin;

select plan(40);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values ('a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Propagation Agency', 'Propagation');
insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status,
  enabled_jurisdictions, enabled_product_lines
) values (
  'a2000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001', 1, 'ACTIVE',
  array['CA'], array['PRIVATE_PASSENGER_AUTO']
);
insert into public.tenant_hosts (
  tenant_host_id, hostname, tenant_id, agency_id,
  tenant_configuration_id, tenant_configuration_version, status
) values (
  'a3000000-0000-0000-0000-000000000001', 'privacy-propagation.test',
  'a0000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001', 1, 'ACTIVE'
);
insert into public.person_private_profiles (
  person_id, tenant_id, agency_id, encrypted_payload, encryption_algorithm,
  key_version, email_lookup_hash
) values
  ('a4000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', decode(repeat('11', 40), 'hex'), 'AES-256-GCM', 'synthetic-key-v1', repeat('1', 64)),
  ('a4000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', decode(repeat('22', 40), 'hex'), 'AES-256-GCM', 'synthetic-key-v1', repeat('2', 64)),
  ('a4000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', decode(repeat('33', 40), 'hex'), 'AES-256-GCM', 'synthetic-key-v1', repeat('3', 64));
insert into public.prospects (
  prospect_id, tenant_id, agency_id, person_id, source_classification
) values
  ('a4100000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a4000000-0000-0000-0000-000000000001', 'SYNTHETIC'),
  ('a4100000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a4000000-0000-0000-0000-000000000002', 'SYNTHETIC'),
  ('a4100000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a4000000-0000-0000-0000-000000000003', 'SYNTHETIC');
insert into public.quote_cases (
  quote_case_id, tenant_id, agency_id, tenant_configuration_id,
  tenant_configuration_version, jurisdiction, product_line, source_channel,
  state, prospect_id
) values
  ('a4200000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000001', 1, 'CA', 'PRIVATE_PASSENGER_AUTO', 'WEB', 'REVIEW_REQUIRED', 'a4100000-0000-0000-0000-000000000001'),
  ('a4200000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000001', 1, 'CA', 'PRIVATE_PASSENGER_AUTO', 'WEB', 'REVIEW_REQUIRED', 'a4100000-0000-0000-0000-000000000002'),
  ('a4200000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000001', 1, 'CA', 'PRIVATE_PASSENGER_AUTO', 'WEB', 'REVIEW_REQUIRED', 'a4100000-0000-0000-0000-000000000003');
insert into public.permissible_purpose_decisions (
  decision_id, tenant_id, quote_case_id, tenant_configuration_version,
  jurisdiction, capability, purpose_code, outcome, policy_version
) values
  ('a4300000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'a4200000-0000-0000-0000-000000000001', 1, 'CA', 'MVR', 'INSURANCE_QUOTE', 'ALLOW', 'synthetic-purpose-v1'),
  ('a4300000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'a4200000-0000-0000-0000-000000000002', 1, 'CA', 'MVR', 'INSURANCE_QUOTE', 'ALLOW', 'synthetic-purpose-v1'),
  ('a4300000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'a4200000-0000-0000-0000-000000000003', 1, 'CA', 'CLAIMS', 'INSURANCE_QUOTE', 'ALLOW', 'synthetic-purpose-v1');
insert into public.provider_bindings (
  provider_binding_id, tenant_id, agency_id, capability, adapter_id,
  adapter_version, jurisdiction, product_line, status,
  requires_report_authorization, purpose_code
) values
  ('a4400000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'MVR', 'synthetic-source-a', '1.0.0', 'CA', 'PRIVATE_PASSENGER_AUTO', 'ACTIVE', false, 'INSURANCE_QUOTE'),
  ('a4400000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'CLAIMS', 'synthetic-source-b', '1.0.0', 'CA', 'PRIVATE_PASSENGER_AUTO', 'ACTIVE', false, 'INSURANCE_QUOTE');
insert into public.external_requests (
  external_request_id, tenant_id, agency_id, quote_case_id,
  tenant_configuration_version, provider_binding_id, capability,
  subject_ids, permissible_purpose_decision_id, idempotency_key,
  request_hash, status, provider_request_ref, completed_at
) values
  ('a4500000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a4200000-0000-0000-0000-000000000001', 1, 'a4400000-0000-0000-0000-000000000001', 'MVR', array['a4000000-0000-0000-0000-000000000001'::uuid], 'a4300000-0000-0000-0000-000000000001', 'source-1', repeat('a', 64), 'SUCCEEDED', 'opaque-source-1', now()),
  ('a4500000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a4200000-0000-0000-0000-000000000002', 1, 'a4400000-0000-0000-0000-000000000001', 'MVR', array['a4000000-0000-0000-0000-000000000002'::uuid], 'a4300000-0000-0000-0000-000000000002', 'source-2', repeat('b', 64), 'SUCCEEDED', 'opaque-source-2', now()),
  ('a4500000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a4200000-0000-0000-0000-000000000003', 1, 'a4400000-0000-0000-0000-000000000002', 'CLAIMS', array['a4000000-0000-0000-0000-000000000003'::uuid], 'a4300000-0000-0000-0000-000000000003', 'source-3', repeat('c', 64), 'SUCCEEDED', 'opaque-source-3', now());

insert into public.privacy_propagation_bindings (
  privacy_propagation_binding_id, tenant_id, agency_id, provider_binding_id,
  adapter_id, adapter_version, policy_version, state
) values (
  'a4600000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001',
  'a4400000-0000-0000-0000-000000000001',
  'synthetic-privacy-propagation-v1', '1.0.0',
  'synthetic-privacy-propagation-policy-v1', 'SYNTHETIC'
);

insert into public.privacy_requests (
  privacy_request_id, public_reference, tenant_id, agency_id, request_type,
  state, identity_verification_state, jurisdiction, intake_channel,
  matched_person_id, identity_verified_at
) values
  ('a5000000-0000-0000-0000-000000000001', 'a5100000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'CORRECTION', 'IN_PROGRESS', 'VERIFIED', 'CA', 'WEB', 'a4000000-0000-0000-0000-000000000001', now()),
  ('a5000000-0000-0000-0000-000000000002', 'a5100000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'DELETION', 'IN_PROGRESS', 'VERIFIED', 'CA', 'WEB', 'a4000000-0000-0000-0000-000000000002', now()),
  ('a5000000-0000-0000-0000-000000000003', 'a5100000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'RESTRICTION', 'IN_PROGRESS', 'VERIFIED', 'CA', 'WEB', 'a4000000-0000-0000-0000-000000000003', now());
insert into public.privacy_request_intake_evidence (
  privacy_request_id, tenant_id, agency_id, encrypted_requester_payload,
  encryption_algorithm, key_version, email_lookup_hash, request_hash,
  status_token_hash
)
select privacy_request_id, tenant_id, agency_id, decode(repeat('99', 40), 'hex'),
  'AES-256-GCM', 'synthetic-key-v1', repeat(right(privacy_request_id::text, 1), 64),
  repeat('d', 64), repeat(right(privacy_request_id::text, 1), 64)
from public.privacy_requests where privacy_request_id::text like 'a5000000-%';
insert into public.privacy_rights_executions (
  privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id,
  idempotency_key, request_hash, policy_version, status, outcome,
  action_summary, completed_at
) values
  ('a5200000-0000-0000-0000-000000000001', 'a5000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a5300000-0000-4000-8000-000000000001', repeat('1', 64), 'synthetic-privacy-rights-v1', 'COMPLETED', 'PARTIALLY_APPLIED', '{"PROPAGATION_PENDING":1}', now()),
  ('a5200000-0000-0000-0000-000000000002', 'a5000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a5300000-0000-4000-8000-000000000002', repeat('2', 64), 'synthetic-privacy-rights-v1', 'COMPLETED', 'PARTIALLY_APPLIED', '{"PROPAGATION_PENDING":1,"DELETE_QUEUED":1}', now()),
  ('a5200000-0000-0000-0000-000000000003', 'a5000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a5300000-0000-4000-8000-000000000003', repeat('3', 64), 'synthetic-privacy-rights-v1', 'COMPLETED', 'PARTIALLY_APPLIED', '{"PROPAGATION_PENDING":1}', now());
insert into public.privacy_rights_actions (
  privacy_rights_execution_id, privacy_request_id, tenant_id, agency_id,
  data_category, disposition, record_count, reason_codes
) values
  ('a5200000-0000-0000-0000-000000000001', 'a5000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'DOWNSTREAM_VENDOR', 'PROPAGATION_PENDING', 1, array['T804_PROPAGATION_REQUIRED']),
  ('a5200000-0000-0000-0000-000000000002', 'a5000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'DOWNSTREAM_VENDOR', 'PROPAGATION_PENDING', 1, array['T804_PROPAGATION_REQUIRED']),
  ('a5200000-0000-0000-0000-000000000002', 'a5000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'IDENTITY_PROFILE', 'DELETE_QUEUED', 1, array['RETENTION_DISPOSITION_REQUIRED']),
  ('a5200000-0000-0000-0000-000000000003', 'a5000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'DOWNSTREAM_VENDOR', 'PROPAGATION_PENDING', 1, array['T804_PROPAGATION_REQUIRED']);

select has_table('public', 'privacy_propagation_bindings', 'propagation binding table exists');
select has_table('public', 'privacy_propagation_runs', 'propagation run table exists');
select has_table('public', 'privacy_vendor_propagations', 'vendor target table exists');
select has_table('public', 'privacy_vendor_propagation_attempts', 'append-only attempt table exists');
select is(has_table_privilege('anon', 'public.privacy_vendor_propagations', 'SELECT'), false, 'anonymous cannot enumerate vendor targets');
select is(has_table_privilege('authenticated', 'public.privacy_vendor_propagation_attempts', 'INSERT'), false, 'authenticated cannot forge attempts');
select is(has_function_privilege('service_role', 'public.prepare_privacy_vendor_propagation(text,uuid,text,uuid,text,text,text)', 'EXECUTE'), true, 'service role can prepare propagation');
select is(has_function_privilege('anon', 'public.prepare_privacy_vendor_propagation(text,uuid,text,uuid,text,text,text)', 'EXECUTE'), false, 'anonymous cannot prepare propagation');

create temporary table correction_prepared as
select * from public.prepare_privacy_vendor_propagation(
  'privacy-propagation.test', 'a5100000-0000-0000-0000-000000000001', repeat('1', 64),
  'a6000000-0000-4000-8000-000000000001',
  'synthetic-privacy-propagation-v1', '1.0.0',
  'synthetic-privacy-propagation-policy-v1'
);
select is((select count(*) from correction_prepared), 1::bigint, 'one affected external request creates one stable target');
select is((select target_status::text from correction_prepared), 'PENDING', 'configured target is dispatchable');
select is((select action::text from correction_prepared), 'CORRECT', 'request type maps to provider-neutral correction action');
select is((select propagation_complete from correction_prepared), false, 'pending target keeps propagation incomplete');
select is((select status_summary->>'PENDING' from correction_prepared), '1', 'requester-safe summary contains only aggregate status');
select is((select count(*) from public.audit_events where event_type = 'PRIVACY_PROPAGATION_PREPARED' and subject_ref = 'privacy-request:a5100000-0000-0000-0000-000000000001'), 1::bigint, 'preparation is audited');

create temporary table correction_failed as
select * from public.settle_privacy_vendor_propagation(
  (select privacy_vendor_propagation_id from correction_prepared),
  'a6000000-0000-4000-8000-000000000001', repeat('4', 64),
  'RETRYABLE_FAILURE', 'synthetic-privacy-propagation-v1', '1.0.0',
  'synthetic-privacy-propagation-policy-v1', 'opaque:retryable-1',
  array['SYNTHETIC_RETRYABLE_FAILURE']
);
select is((select propagation_complete from correction_failed), false, 'retryable failure does not complete propagation');
select is((select state::text from correction_failed), 'IN_PROGRESS', 'failed downstream work keeps request open');
select is((select status::text from public.privacy_vendor_propagations where privacy_rights_execution_id = 'a5200000-0000-0000-0000-000000000001'), 'FAILED', 'target preserves failed state');
select is((select attempt_count from public.privacy_vendor_propagations where privacy_rights_execution_id = 'a5200000-0000-0000-0000-000000000001'), 1, 'failed attempt increments target counter');
select is((select count(*) from public.privacy_vendor_propagation_attempts where privacy_rights_execution_id = 'a5200000-0000-0000-0000-000000000001'), 1::bigint, 'failed attempt evidence is append-only');

create temporary table correction_retry as
select * from public.prepare_privacy_vendor_propagation(
  'privacy-propagation.test', 'a5100000-0000-0000-0000-000000000001', repeat('1', 64),
  'a6000000-0000-4000-8000-000000000002',
  'synthetic-privacy-propagation-v1', '1.0.0',
  'synthetic-privacy-propagation-policy-v1'
);
select is((select target_status::text from correction_retry), 'FAILED', 'new orchestration key can retry failed stable target');
select is((select count(*) from public.privacy_vendor_propagations where privacy_rights_execution_id = 'a5200000-0000-0000-0000-000000000001'), 1::bigint, 'retry does not duplicate target');
create temporary table correction_completed as
select * from public.settle_privacy_vendor_propagation(
  (select privacy_vendor_propagation_id from correction_retry),
  'a6000000-0000-4000-8000-000000000002', repeat('5', 64),
  'COMPLETED', 'synthetic-privacy-propagation-v1', '1.0.0',
  'synthetic-privacy-propagation-policy-v1', 'opaque:completed-2',
  array['SYNTHETIC_VENDOR_ACKNOWLEDGED']
);
select is((select propagation_complete from correction_completed), true, 'completed retry settles all targets');
select is((select state::text from correction_completed), 'COMPLETED', 'correction closes only after all targets complete');
select is((select count(*) from public.privacy_vendor_propagation_attempts where privacy_rights_execution_id = 'a5200000-0000-0000-0000-000000000001'), 2::bigint, 'retry preserves both attempt records');
select is((select attempt_count from public.privacy_vendor_propagations where privacy_rights_execution_id = 'a5200000-0000-0000-0000-000000000001'), 2, 'target counts retry attempts');
select is((select count(*) from public.audit_events where event_type = 'PRIVACY_PROPAGATION_ATTEMPTED' and subject_ref = 'privacy-request:a5100000-0000-0000-0000-000000000001'), 2::bigint, 'each downstream attempt is audited');

create temporary table correction_replay as
select * from public.prepare_privacy_vendor_propagation(
  'privacy-propagation.test', 'a5100000-0000-0000-0000-000000000001', repeat('1', 64),
  'a6000000-0000-4000-8000-000000000002',
  'synthetic-privacy-propagation-v1', '1.0.0',
  'synthetic-privacy-propagation-policy-v1'
);
select is((select target_status::text from correction_replay), 'COMPLETED', 'idempotent replay returns completed target');
select is((select count(*) from public.privacy_propagation_runs where privacy_rights_execution_id = 'a5200000-0000-0000-0000-000000000001'), 2::bigint, 'replay creates no duplicate run');
select throws_ok(
  $$select * from public.prepare_privacy_vendor_propagation(
    'privacy-propagation.test', 'a5100000-0000-0000-0000-000000000001', repeat('1', 64),
    'a6000000-0000-4000-8000-000000000002',
    'synthetic-privacy-propagation-v1', '2.0.0',
    'synthetic-privacy-propagation-policy-v1')$$,
  '22023', 'IDEMPOTENCY_KEY_REQUEST_MISMATCH', 'run idempotency cannot change adapter evidence'
);

create temporary table deletion_prepared as
select * from public.prepare_privacy_vendor_propagation(
  'privacy-propagation.test', 'a5100000-0000-0000-0000-000000000002', repeat('2', 64),
  'a6000000-0000-4000-8000-000000000003',
  'synthetic-privacy-propagation-v1', '1.0.0',
  'synthetic-privacy-propagation-policy-v1'
);
create temporary table deletion_completed as
select * from public.settle_privacy_vendor_propagation(
  (select privacy_vendor_propagation_id from deletion_prepared),
  'a6000000-0000-4000-8000-000000000003', repeat('6', 64),
  'COMPLETED', 'synthetic-privacy-propagation-v1', '1.0.0',
  'synthetic-privacy-propagation-policy-v1', 'opaque:deletion-complete',
  array['SYNTHETIC_VENDOR_ACKNOWLEDGED']
);
select is((select propagation_complete from deletion_completed), true, 'deletion target propagation can complete');
select is((select state::text from deletion_completed), 'IN_PROGRESS', 'deletion remains open for T805 disposition');
select is((select applicability_reason_codes[1] from public.privacy_requests where privacy_request_id = 'a5000000-0000-0000-0000-000000000002'), 'RETENTION_DISPOSITION_PENDING', 'deletion exposes the remaining workflow reason');

create temporary table blocked_prepared as
select * from public.prepare_privacy_vendor_propagation(
  'privacy-propagation.test', 'a5100000-0000-0000-0000-000000000003', repeat('3', 64),
  'a6000000-0000-4000-8000-000000000004',
  'synthetic-privacy-propagation-v1', '1.0.0',
  'synthetic-privacy-propagation-policy-v1'
);
select is((select target_status::text from blocked_prepared), 'BLOCKED', 'missing exact propagation binding fails closed');
select is((select adapter_id is null from blocked_prepared), true, 'blocked target exposes no inferred adapter');
select is((select status_summary->>'BLOCKED' from blocked_prepared), '1', 'blocked target is visible only as aggregate status');
select is((select state::text from blocked_prepared), 'IN_PROGRESS', 'blocked target keeps privacy request open');
select throws_ok(
  $$select * from public.settle_privacy_vendor_propagation(
    (select privacy_vendor_propagation_id from blocked_prepared),
    'a6000000-0000-4000-8000-000000000004', repeat('7', 64),
    'COMPLETED', 'synthetic-privacy-propagation-v1', '1.0.0',
    'synthetic-privacy-propagation-policy-v1', 'opaque:invalid', '{}')$$,
  'P0002', 'PRIVACY_PROPAGATION_TARGET_NOT_FOUND', 'blocked target cannot be settled through an invented adapter'
);
select throws_ok(
  $$select * from public.prepare_privacy_vendor_propagation(
    'privacy-propagation.test', 'a5100000-0000-0000-0000-000000000003', repeat('9', 64),
    'a6000000-0000-4000-8000-000000000005',
    'synthetic-privacy-propagation-v1', '1.0.0',
    'synthetic-privacy-propagation-policy-v1')$$,
  'P0002', 'PRIVACY_REQUEST_NOT_FOUND', 'wrong requester credential reveals no propagation state'
);
select is(has_function_privilege('anon', 'public.settle_privacy_vendor_propagation(uuid,uuid,text,public.privacy_propagation_outcome,text,text,text,text,text[])', 'EXECUTE'), false, 'anonymous cannot settle vendor evidence');
select is((select count(*) from public.privacy_vendor_propagation_attempts where evidence_ref like '%opaque-source%'), 0::bigint, 'attempt evidence never copies provider request references');

select * from finish();
rollback;
