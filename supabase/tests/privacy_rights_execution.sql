begin;

select plan(39);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values ('f1000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'Rights Agency', 'Rights');
insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status,
  enabled_jurisdictions, enabled_product_lines
) values (
  'f2000000-0000-0000-0000-000000000001',
  'f0000000-0000-0000-0000-000000000001',
  'f1000000-0000-0000-0000-000000000001', 1, 'ACTIVE',
  array['CA'], array['PRIVATE_PASSENGER_AUTO']
);
insert into public.tenant_hosts (
  tenant_host_id, hostname, tenant_id, agency_id,
  tenant_configuration_id, tenant_configuration_version, status
) values (
  'f3000000-0000-0000-0000-000000000001', 'privacy-rights.test',
  'f0000000-0000-0000-0000-000000000001',
  'f1000000-0000-0000-0000-000000000001',
  'f2000000-0000-0000-0000-000000000001', 1, 'ACTIVE'
);
insert into public.person_private_profiles (
  person_id, tenant_id, agency_id, encrypted_payload, encryption_algorithm,
  key_version, email_lookup_hash, phone_lookup_hash
) values (
  'f4000000-0000-0000-0000-000000000001',
  'f0000000-0000-0000-0000-000000000001',
  'f1000000-0000-0000-0000-000000000001',
  decode(repeat('aa', 40), 'hex'), 'AES-256-GCM', 'synthetic-key-v1',
  repeat('a', 64), repeat('b', 64)
);

insert into public.privacy_requests (
  privacy_request_id, public_reference, tenant_id, agency_id, request_type,
  state, identity_verification_state, jurisdiction, intake_channel,
  matched_person_id, identity_verified_at
) values
  ('f5000000-0000-0000-0000-000000000001', 'f5100000-0000-0000-0000-000000000001',
   'f0000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001',
   'CORRECTION', 'APPLICABILITY_REVIEW', 'VERIFIED', 'CA', 'WEB',
   'f4000000-0000-0000-0000-000000000001', now()),
  ('f5000000-0000-0000-0000-000000000002', 'f5100000-0000-0000-0000-000000000002',
   'f0000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001',
   'DELETION', 'APPLICABILITY_REVIEW', 'VERIFIED', 'CA', 'WEB',
   'f4000000-0000-0000-0000-000000000001', now()),
  ('f5000000-0000-0000-0000-000000000003', 'f5100000-0000-0000-0000-000000000003',
   'f0000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001',
   'RESTRICTION', 'APPLICABILITY_REVIEW', 'VERIFIED', 'CA', 'WEB',
   'f4000000-0000-0000-0000-000000000001', now()),
  ('f5000000-0000-0000-0000-000000000004', 'f5100000-0000-0000-0000-000000000004',
   'f0000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001',
   'DELETION', 'APPLICABILITY_REVIEW', 'VERIFIED', 'CA', 'WEB', null, now()),
  ('f5000000-0000-0000-0000-000000000005', 'f5100000-0000-0000-0000-000000000005',
   'f0000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001',
   'CORRECTION', 'APPLICABILITY_REVIEW', 'VERIFIED', 'CA', 'WEB', null, now());

insert into public.privacy_request_intake_evidence (
  privacy_request_id, tenant_id, agency_id, encrypted_requester_payload,
  encryption_algorithm, key_version, email_lookup_hash, request_hash, status_token_hash
)
select privacy_request_id, tenant_id, agency_id, decode(repeat('bb', 40), 'hex'),
  'AES-256-GCM', 'synthetic-key-v1', repeat('a', 64), repeat('c', 64),
  repeat(substr(privacy_request_id::text, 2, 1), 64)
from public.privacy_requests where privacy_request_id::text like 'f5000000-%';

insert into public.privacy_discovery_runs (
  privacy_discovery_run_id, privacy_request_id, tenant_id, agency_id,
  idempotency_key, request_hash, status, outcome, matched_person_id,
  configuration_version_ref, disclosure_policy_version, export_schema_version,
  record_counts, record_count, completed_at
)
select gen_random_uuid(), privacy_request_id, tenant_id, agency_id,
  gen_random_uuid(), repeat('d', 64), 'COMPLETED',
  case when matched_person_id is null and privacy_request_id = 'f5000000-0000-0000-0000-000000000005'
    then 'AMBIGUOUS'::public.privacy_discovery_outcome
    when matched_person_id is null then 'NO_MATCH'::public.privacy_discovery_outcome
    else 'MATCHED'::public.privacy_discovery_outcome end,
  matched_person_id, '1', 'synthetic-privacy-export-v1', 'privacy-export-v1',
  case when matched_person_id is null then '{}'::jsonb else '{"people":1}'::jsonb end,
  case when matched_person_id is null then 0 else 1 end, now()
from public.privacy_requests where privacy_request_id::text like 'f5000000-%';

select has_table('public', 'privacy_rights_executions', 'rights execution table exists');
select has_table('public', 'privacy_rights_actions', 'rights action table exists');
select has_table('public', 'privacy_processing_restrictions', 'processing restriction table exists');
select is(has_table_privilege('anon', 'public.privacy_rights_executions', 'SELECT'), false, 'anonymous cannot read execution evidence');
select is(has_table_privilege('authenticated', 'public.privacy_rights_actions', 'INSERT'), false, 'authenticated cannot write actions');
select is(has_table_privilege('anon', 'public.privacy_processing_restrictions', 'SELECT'), false, 'anonymous cannot enumerate restrictions');
select is(has_function_privilege('service_role', 'public.prepare_privacy_rights_execution(text,uuid,text,uuid,text,text,text[])', 'EXECUTE'), true, 'service role can prepare execution');
select is(has_function_privilege('anon', 'public.prepare_privacy_rights_execution(text,uuid,text,uuid,text,text,text[])', 'EXECUTE'), false, 'anonymous cannot prepare execution');
select hasnt_column('public', 'privacy_rights_executions', 'plaintext_corrections', 'execution evidence has no plaintext correction column');
select has_trigger('public', 'external_requests', 'privacy_restriction_external_requests', 'provider processing checks active restrictions');
select has_trigger('public', 'carrier_submissions', 'privacy_restriction_carrier_submissions', 'carrier processing checks active restrictions');

create temporary table correction_prepared as
select * from public.prepare_privacy_rights_execution(
  'privacy-rights.test', 'f5100000-0000-0000-0000-000000000001', repeat('5', 64),
  'f6000000-0000-4000-8000-000000000001', repeat('1', 64),
  'synthetic-privacy-rights-v1', array['email']
);
select is((select execution_status::text from correction_prepared), 'PREPARED', 'correction execution prepares');
select is((select encrypted_profile_hex from correction_prepared), repeat('aa', 40), 'trusted prepare returns protected current profile');
select is((select state::text from correction_prepared), 'IN_PROGRESS', 'prepare advances request atomically');

create temporary table correction_settled as
select * from public.settle_privacy_rights_execution(
  (select privacy_rights_execution_id from correction_prepared),
  decode(repeat('cc', 40), 'hex'), 'synthetic-key-v2', repeat('e', 64), null
);
select is((select execution_outcome::text from correction_settled), 'APPLIED', 'local correction is applied');
select is((select state::text from correction_settled), 'COMPLETED', 'correction without downstream records completes');
select is((select encode(encrypted_payload, 'hex') from public.person_private_profiles where person_id = 'f4000000-0000-0000-0000-000000000001'), repeat('cc', 40), 'only protected corrected profile is stored');
select is((select payload_version from public.person_private_profiles where person_id = 'f4000000-0000-0000-0000-000000000001'), 2, 'correction increments protected payload version');
select is((select count(*) from public.privacy_rights_actions where data_category = 'IDENTITY_PROFILE' and disposition = 'CORRECTED'), 1::bigint, 'correction action is recorded');
select is((select count(*) from public.audit_events where event_type in ('PRIVACY_RIGHTS_EXECUTION_PREPARED','PRIVACY_RIGHTS_EXECUTION_COMPLETED') and subject_ref = 'privacy-request:f5100000-0000-0000-0000-000000000001'), 2::bigint, 'correction prepare and settlement are audited');

create temporary table correction_replay as
select * from public.prepare_privacy_rights_execution(
  'privacy-rights.test', 'f5100000-0000-0000-0000-000000000001', repeat('5', 64),
  'f6000000-0000-4000-8000-000000000001', repeat('1', 64),
  'synthetic-privacy-rights-v1', array['email']
);
select is((select execution_status::text from correction_replay), 'COMPLETED', 'idempotent replay returns completion');
select is((select count(*) from public.privacy_rights_executions where privacy_request_id = 'f5000000-0000-0000-0000-000000000001'), 1::bigint, 'replay creates no duplicate execution');
select throws_ok(
  $$select * from public.prepare_privacy_rights_execution(
    'privacy-rights.test', 'f5100000-0000-0000-0000-000000000001', repeat('5', 64),
    'f6000000-0000-4000-8000-000000000001', repeat('2', 64),
    'synthetic-privacy-rights-v1', array['email'])$$,
  '22023', 'IDEMPOTENCY_KEY_REQUEST_MISMATCH', 'idempotency reuse cannot change correction evidence'
);

create temporary table deletion_prepared as
select * from public.prepare_privacy_rights_execution(
  'privacy-rights.test', 'f5100000-0000-0000-0000-000000000002', repeat('5', 64),
  'f6000000-0000-4000-8000-000000000002', repeat('3', 64),
  'synthetic-privacy-rights-v1', '{}'
);
create temporary table deletion_settled as
select * from public.settle_privacy_rights_execution(
  (select privacy_rights_execution_id from deletion_prepared), null, null, null, null
);
select is((select execution_outcome::text from deletion_settled), 'PARTIALLY_APPLIED', 'deletion distinguishes restriction from pending disposition');
select is((select state::text from deletion_settled), 'IN_PROGRESS', 'deletion remains open for retention disposition');
select is((select count(*) from public.privacy_processing_restrictions where privacy_request_id = 'f5000000-0000-0000-0000-000000000002' and active), 1::bigint, 'deletion immediately restricts processing');
select is((select count(*) from public.privacy_rights_actions where privacy_request_id = 'f5000000-0000-0000-0000-000000000002' and disposition = 'DELETE_QUEUED'), 2::bigint, 'deletion queues category disposition work');
select is((select count(*) from public.privacy_rights_actions where privacy_request_id = 'f5000000-0000-0000-0000-000000000002' and data_category = 'AUDIT_EVIDENCE' and disposition = 'EXEMPT'), 1::bigint, 'audit evidence exemption is explicit');
select is((select count(*) from public.person_private_profiles where person_id = 'f4000000-0000-0000-0000-000000000001'), 1::bigint, 'execution does not bypass retention worker with direct deletion');

create temporary table restriction_prepared as
select * from public.prepare_privacy_rights_execution(
  'privacy-rights.test', 'f5100000-0000-0000-0000-000000000003', repeat('5', 64),
  'f6000000-0000-4000-8000-000000000003', repeat('4', 64),
  'synthetic-privacy-rights-v1', '{}'
);
create temporary table restriction_settled as
select * from public.settle_privacy_rights_execution(
  (select privacy_rights_execution_id from restriction_prepared), null, null, null, null
);
select is((select execution_outcome::text from restriction_settled), 'APPLIED', 'local restriction is applied');
select is((select state::text from restriction_settled), 'COMPLETED', 'local restriction completes without downstream work');
select is((select scope::text from public.privacy_processing_restrictions where privacy_request_id = 'f5000000-0000-0000-0000-000000000003'), 'ALL_PROCESSING', 'restriction scope is enforceable and person linked');
select is((select count(*) from public.privacy_rights_actions where privacy_request_id = 'f5000000-0000-0000-0000-000000000003' and disposition = 'RESTRICTED'), 1::bigint, 'restriction action is recorded');

create temporary table no_match_prepared as
select * from public.prepare_privacy_rights_execution(
  'privacy-rights.test', 'f5100000-0000-0000-0000-000000000004', repeat('5', 64),
  'f6000000-0000-4000-8000-000000000004', repeat('6', 64),
  'synthetic-privacy-rights-v1', '{}'
);
create temporary table no_match_settled as
select * from public.settle_privacy_rights_execution(
  (select privacy_rights_execution_id from no_match_prepared), null, null, null, null
);
select is((select execution_outcome::text from no_match_settled), 'NO_RECORDS', 'no-match execution reveals only no-record outcome');
select is((select state::text from no_match_settled), 'COMPLETED', 'no-match request completes safely');
select is((select count(*) from public.privacy_rights_actions where privacy_request_id = 'f5000000-0000-0000-0000-000000000004' and disposition = 'NO_RECORDS'), 1::bigint, 'no-match creates no target actions');

select throws_ok(
  $$select * from public.prepare_privacy_rights_execution(
    'privacy-rights.test', 'f5100000-0000-0000-0000-000000000005', repeat('5', 64),
    'f6000000-0000-4000-8000-000000000005', repeat('7', 64),
    'synthetic-privacy-rights-v1', array['email'])$$,
  '55000', 'PRIVACY_RIGHTS_DISCOVERY_INVALID', 'ambiguous discovery cannot execute against a candidate'
);
select throws_ok(
  $$select * from public.prepare_privacy_rights_execution(
    'privacy-rights.test', 'f5100000-0000-0000-0000-000000000002', repeat('5', 64),
    'f6000000-0000-4000-8000-000000000006', repeat('8', 64),
    'synthetic-privacy-rights-v1', array['email'])$$,
  '55000', 'PRIVACY_RIGHTS_EXECUTION_STATE_INVALID', 'terminal or in-progress request cannot start incompatible execution'
);
select is(has_function_privilege('anon', 'public.settle_privacy_rights_execution(uuid,bytea,text,text,text)', 'EXECUTE'), false, 'anonymous cannot settle protected corrections');

select * from finish();
rollback;
