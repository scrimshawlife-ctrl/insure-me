begin;

select plan(14);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values ('c1000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Privacy Intake Agency', 'Privacy Intake');

insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status,
  enabled_jurisdictions, enabled_product_lines
) values (
  'c2000000-0000-0000-0000-000000000001',
  'c0000000-0000-0000-0000-000000000001',
  'c1000000-0000-0000-0000-000000000001',
  1, 'ACTIVE', array['CA'], array['PRIVATE_PASSENGER_AUTO']
);

insert into public.tenant_hosts (
  tenant_host_id, hostname, tenant_id, agency_id,
  tenant_configuration_id, tenant_configuration_version, status
) values (
  'c3000000-0000-0000-0000-000000000001',
  'privacy.test',
  'c0000000-0000-0000-0000-000000000001',
  'c1000000-0000-0000-0000-000000000001',
  'c2000000-0000-0000-0000-000000000001',
  1, 'ACTIVE'
);

create temporary table first_privacy_result as
select * from public.create_privacy_request(
  'privacy.test', 'DELETION', 'CA', 'WEB',
  decode(repeat('ab', 40), 'hex'), 'synthetic-key-v1',
  repeat('a', 64), repeat('b', 64), repeat('c', 64), repeat('d', 64),
  'c4000000-0000-4000-8000-000000000001'
);

select is((select count(*) from first_privacy_result), 1::bigint, 'intake returns one requester-safe receipt');
select is((select state::text from first_privacy_result), 'IDENTITY_VERIFICATION_PENDING', 'intake begins at identity verification');
select is((select identity_verification_state::text from first_privacy_result), 'PENDING', 'identity remains unverified');
select is((select count(*) from public.privacy_requests), 1::bigint, 'one privacy request is persisted');
select is((select matched_person_id is null from public.privacy_requests), true, 'intake performs no person matching');
select is((select count(*) from public.privacy_request_intake_evidence), 1::bigint, 'protected intake evidence is persisted');
select is((select encode(encrypted_requester_payload, 'hex') from public.privacy_request_intake_evidence), repeat('ab', 40), 'database stores only the supplied encrypted envelope');
select is((select count(*) from public.audit_events where event_type = 'PRIVACY_REQUEST_RECEIVED'), 1::bigint, 'intake emits one audit event');

select is(
  (select public_reference from public.create_privacy_request(
    'privacy.test', 'DELETION', 'CA', 'WEB',
    decode(repeat('ef', 40), 'hex'), 'synthetic-key-v1',
    repeat('a', 64), repeat('b', 64), repeat('c', 64), repeat('d', 64),
    'c4000000-0000-4000-8000-000000000001'
  )),
  (select public_reference from first_privacy_result),
  'idempotent replay returns the original public reference'
);

select is((select count(*) from public.privacy_requests), 1::bigint, 'idempotent replay creates no duplicate');

select throws_ok(
  $$select * from public.create_privacy_request(
    'privacy.test', 'ACCESS', 'CA', 'WEB', decode(repeat('ab', 40), 'hex'),
    'synthetic-key-v1', repeat('a', 64), repeat('b', 64), repeat('e', 64),
    repeat('d', 64), 'c4000000-0000-4000-8000-000000000001'
  )$$,
  '22023', 'IDEMPOTENCY_KEY_REQUEST_MISMATCH',
  'idempotency key cannot be reused for a different request'
);

select is(
  (select state::text from public.get_privacy_request_status(
    'privacy.test', (select public_reference from first_privacy_result), repeat('d', 64)
  )),
  'IDENTITY_VERIFICATION_PENDING',
  'valid receipt returns requester-safe workflow state'
);

select is(
  (select count(*) from public.get_privacy_request_status(
    'privacy.test', (select public_reference from first_privacy_result), repeat('f', 64)
  )),
  0::bigint,
  'invalid receipt token reveals no request state'
);

select is(has_table_privilege('anon', 'public.privacy_request_intake_evidence', 'SELECT'), false, 'anonymous users cannot read intake evidence');

select * from finish();
rollback;

