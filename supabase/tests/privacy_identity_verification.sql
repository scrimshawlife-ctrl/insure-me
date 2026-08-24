begin;

select plan(25);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values ('d1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'Privacy Verification Agency', 'Privacy Verification');

insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status,
  enabled_jurisdictions, enabled_product_lines
) values (
  'd2000000-0000-0000-0000-000000000001',
  'd0000000-0000-0000-0000-000000000001',
  'd1000000-0000-0000-0000-000000000001',
  1, 'ACTIVE', array['CA'], array['PRIVATE_PASSENGER_AUTO']
);

insert into public.tenant_hosts (
  tenant_host_id, hostname, tenant_id, agency_id,
  tenant_configuration_id, tenant_configuration_version, status
) values (
  'd3000000-0000-0000-0000-000000000001',
  'privacy-verification.test',
  'd0000000-0000-0000-0000-000000000001',
  'd1000000-0000-0000-0000-000000000001',
  'd2000000-0000-0000-0000-000000000001',
  1, 'ACTIVE'
);

create temporary table first_privacy_request as
select * from public.create_privacy_request(
  'privacy-verification.test', 'DELETION', 'CA', 'WEB',
  decode(repeat('ab', 40), 'hex'), 'synthetic-key-v1',
  repeat('a', 64), repeat('b', 64), repeat('c', 64), repeat('d', 64),
  'd4000000-0000-4000-8000-000000000001'
);

select has_table('public', 'privacy_identity_verification_attempts', 'verification attempts table exists');
select hasnt_column('public', 'privacy_identity_verification_attempts', 'assertion', 'raw assertions are not stored');
select hasnt_column('public', 'privacy_identity_verification_attempts', 'status_token', 'raw status tokens are not stored');

create temporary table failed_verification as
select * from public.settle_privacy_identity_verification(
  'privacy-verification.test',
  (select public_reference from first_privacy_request),
  repeat('d', 64), 'd5000000-0000-4000-8000-000000000001', repeat('1', 64),
  'FAILED', 'synthetic-privacy-identity-v1', '1.0.0', 'synthetic-policy-v1',
  'synthetic-privacy-evidence:failed1', array['ASSERTION_INVALID']
);

select is((select verification_outcome::text from failed_verification), 'FAILED', 'failed verification returns its outcome');
select is((select state::text from failed_verification), 'IDENTITY_VERIFICATION_PENDING', 'one failure leaves the request pending');
select is((select count(*) from public.privacy_identity_verification_attempts), 1::bigint, 'one failure creates one attempt');

select is(
  (select verification_outcome::text from public.settle_privacy_identity_verification(
    'privacy-verification.test', (select public_reference from first_privacy_request),
    repeat('d', 64), 'd5000000-0000-4000-8000-000000000001', repeat('1', 64),
    'FAILED', 'synthetic-privacy-identity-v1', '1.0.0', 'synthetic-policy-v1',
    'synthetic-privacy-evidence:failed1', array['ASSERTION_INVALID']
  )),
  'FAILED',
  'idempotent replay returns the original outcome'
);
select is((select count(*) from public.privacy_identity_verification_attempts), 1::bigint, 'idempotent replay creates no duplicate attempt');

select throws_ok(
  $$select * from public.settle_privacy_identity_verification(
    'privacy-verification.test', (select public_reference from first_privacy_request),
    repeat('d', 64), 'd5000000-0000-4000-8000-000000000001', repeat('2', 64),
    'FAILED', 'synthetic-privacy-identity-v1', '1.0.0', 'synthetic-policy-v1',
    'synthetic-privacy-evidence:failed1', array['ASSERTION_INVALID']
  )$$,
  '22023', 'IDEMPOTENCY_KEY_REQUEST_MISMATCH',
  'idempotency key cannot be reused for a different verification request'
);

create temporary table successful_verification as
select * from public.settle_privacy_identity_verification(
  'privacy-verification.test',
  (select public_reference from first_privacy_request),
  repeat('d', 64), 'd5000000-0000-4000-8000-000000000002', repeat('3', 64),
  'VERIFIED', 'synthetic-privacy-identity-v1', '1.0.0', 'synthetic-policy-v1',
  'synthetic-privacy-evidence:verified1', array['SYNTHETIC_ASSERTION_ACCEPTED']
);

select is((select verification_outcome::text from successful_verification), 'VERIFIED', 'successful verification returns its outcome');
select is((select state::text from successful_verification), 'IDENTITY_VERIFIED', 'successful verification advances workflow state');
select is((select identity_verification_state::text from successful_verification), 'VERIFIED', 'successful verification records verified identity state');
select is(
  (select identity_evidence_ref from public.privacy_requests where public_reference = (select public_reference from first_privacy_request)),
  'synthetic-privacy-evidence:verified1',
  'only the opaque evidence reference is attached to the request'
);
select is(
  (select matched_person_id is null from public.privacy_requests where public_reference = (select public_reference from first_privacy_request)),
  true,
  'identity verification performs no person matching'
);
select is(
  (select count(*) from public.audit_events where event_type in ('PRIVACY_IDENTITY_VERIFIED', 'PRIVACY_IDENTITY_VERIFICATION_FAILED')),
  2::bigint,
  'each non-replayed verification result emits one audit event'
);

select throws_ok(
  $$select * from public.settle_privacy_identity_verification(
    'privacy-verification.test', (select public_reference from first_privacy_request),
    repeat('d', 64), 'd5000000-0000-4000-8000-000000000003', repeat('4', 64),
    'FAILED', 'synthetic-privacy-identity-v1', '1.0.0', 'synthetic-policy-v1',
    'synthetic-privacy-evidence:late', array['ASSERTION_INVALID']
  )$$,
  '55000', 'PRIVACY_IDENTITY_ALREADY_VERIFIED',
  'a verified request rejects additional attempts'
);

select is(has_table_privilege('anon', 'public.privacy_identity_verification_attempts', 'SELECT'), false, 'anonymous users cannot read verification attempts');
select is(has_table_privilege('authenticated', 'public.privacy_identity_verification_attempts', 'INSERT'), false, 'authenticated users cannot insert verification attempts');
select is(
  has_function_privilege(
    'anon',
    'public.settle_privacy_identity_verification(text,uuid,text,uuid,text,public.privacy_identity_verification_outcome,text,text,text,text,text[])',
    'EXECUTE'
  ),
  false,
  'anonymous users cannot execute verification settlement'
);
select is(
  has_function_privilege(
    'service_role',
    'public.settle_privacy_identity_verification(text,uuid,text,uuid,text,public.privacy_identity_verification_outcome,text,text,text,text,text[])',
    'EXECUTE'
  ),
  true,
  'service role can execute verification settlement'
);

create temporary table locked_privacy_request as
select * from public.create_privacy_request(
  'privacy-verification.test', 'ACCESS', 'CA', 'WEB',
  decode(repeat('cd', 40), 'hex'), 'synthetic-key-v1',
  repeat('e', 64), repeat('f', 64), repeat('0', 64), repeat('9', 64),
  'd4000000-0000-4000-8000-000000000002'
);

do $$
declare
  v_attempt integer;
begin
  for v_attempt in 1..5 loop
    perform * from public.settle_privacy_identity_verification(
      'privacy-verification.test',
      (select public_reference from locked_privacy_request),
      repeat('9', 64),
      ('d6000000-0000-4000-8000-' || lpad(v_attempt::text, 12, '0'))::uuid,
      repeat(v_attempt::text, 64),
      'FAILED', 'synthetic-privacy-identity-v1', '1.0.0', 'synthetic-policy-v1',
      'synthetic-privacy-evidence:lockout' || v_attempt::text,
      array['ASSERTION_INVALID']
    );
  end loop;
end
$$;

select is(
  (select identity_verification_state::text from public.privacy_requests where public_reference = (select public_reference from locked_privacy_request)),
  'FAILED',
  'the fifth failed attempt locks identity verification'
);
select is(
  (select count(*) from public.privacy_identity_verification_attempts where privacy_request_id = (
    select privacy_request_id from public.privacy_requests where public_reference = (select public_reference from locked_privacy_request)
  )),
  5::bigint,
  'lockout preserves all five append-only attempts'
);
select is(
  (select reason_codes @> array['MAX_ATTEMPTS_EXCEEDED'] from public.privacy_identity_verification_attempts where privacy_request_id = (
    select privacy_request_id from public.privacy_requests where public_reference = (select public_reference from locked_privacy_request)
  ) and attempt_number = 5),
  true,
  'the fifth failure records the max-attempts reason'
);
select throws_ok(
  $$select * from public.settle_privacy_identity_verification(
    'privacy-verification.test', (select public_reference from locked_privacy_request),
    repeat('9', 64), 'd6000000-0000-4000-8000-000000000006', repeat('6', 64),
    'FAILED', 'synthetic-privacy-identity-v1', '1.0.0', 'synthetic-policy-v1',
    'synthetic-privacy-evidence:lockout6', array['ASSERTION_INVALID']
  )$$,
  '55000', 'PRIVACY_IDENTITY_VERIFICATION_LOCKED',
  'a locked request rejects a sixth attempt'
);
select is(
  (select matched_person_id is null from public.privacy_requests where public_reference = (select public_reference from locked_privacy_request)),
  true,
  'failed verification performs no person matching'
);

select * from finish();
rollback;
