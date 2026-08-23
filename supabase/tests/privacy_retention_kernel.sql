begin;

select plan(17);

select has_table('public', 'privacy_requests', 'PrivacyRequest table exists');
select has_table('public', 'retention_policies', 'RetentionPolicy table exists');
select col_type_is('public', 'privacy_requests', 'request_type', 'privacy_request_type', 'privacy request types are closed');
select col_type_is('public', 'retention_policies', 'disposition', 'retention_disposition', 'retention dispositions are closed');

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values
  ('a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Privacy Agency A', 'Privacy A'),
  ('b1000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'Privacy Agency B', 'Privacy B');

insert into public.agency_users (agency_user_id, tenant_id, agency_id, workforce_identity_id, status)
values
  ('a2000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a9000000-0000-0000-0000-000000000009', 'ACTIVE'),
  ('b2000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002', 'a9000000-0000-0000-0000-000000000009', 'ACTIVE');

insert into public.roles (role_id, tenant_id, agency_id, name, permissions)
values
  ('a3000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'privacy-admin', array['PRIVACY_ADMIN']::public.permission_code[]),
  ('b3000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002', 'privacy-admin', array['PRIVACY_ADMIN']::public.permission_code[]);

insert into public.agency_user_roles (agency_user_id, role_id)
values
  ('a2000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001'),
  ('b2000000-0000-0000-0000-000000000002', 'b3000000-0000-0000-0000-000000000002');

insert into public.person_private_profiles (
  person_id, tenant_id, agency_id, encrypted_payload, encryption_algorithm, key_version
) values (
  'a6000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001',
  decode('00', 'hex'),
  'AES-256-GCM',
  'synthetic-test-key'
);

insert into public.privacy_requests (
  privacy_request_id, public_reference, tenant_id, agency_id, request_type, state,
  identity_verification_state, jurisdiction, intake_channel
) values
  ('a4000000-0000-0000-0000-000000000001', 'a4100000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'DELETION', 'IDENTITY_VERIFICATION_PENDING', 'PENDING', 'CA', 'WEB'),
  ('b4000000-0000-0000-0000-000000000002', 'b4100000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002', 'ACCESS', 'RECEIVED', 'NOT_STARTED', 'CA', 'MAIL');

insert into public.retention_policies (
  retention_policy_id, tenant_id, agency_id, policy_set_id, version, data_class,
  jurisdiction, disposition, certification_state
) values
  ('a5000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'synthetic-v1', 1, 'QUOTE_CASE', 'CA', 'REVIEW', 'SYNTHETIC'),
  ('b5000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002', 'synthetic-v1', 1, 'QUOTE_CASE', 'CA', 'REVIEW', 'SYNTHETIC');

select is((select retention_interval is null from public.retention_policies where retention_policy_id = 'a5000000-0000-0000-0000-000000000001'), true, 'synthetic policy may leave unresolved retention duration empty');
select is((select legal_hold_blocks_destructive_disposition from public.retention_policies where retention_policy_id = 'a5000000-0000-0000-0000-000000000001'), true, 'legal hold blocks destructive disposition by default');

select throws_ok(
  $$insert into public.retention_policies (tenant_id, agency_id, policy_set_id, version, data_class, jurisdiction, retention_interval, disposition, certification_state, effective_at) values ('a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'invalid-approved', 1, 'AUDIT_EVENT', 'CA', interval '1 day', 'DELETE', 'APPROVED', now())$$,
  '23514',
  null,
  'approved policy requires legal or contract authority evidence'
);

select throws_ok(
  $$update public.retention_policies set disposition = 'DELETE' where retention_policy_id = 'a5000000-0000-0000-0000-000000000001'$$,
  '22023',
  'RETENTION_POLICY_VERSION_IMMUTABLE',
  'published retention policy content requires a new version'
);

select throws_ok(
  $$update public.privacy_requests set matched_person_id = 'a6000000-0000-0000-0000-000000000001' where privacy_request_id = 'a4000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'request cannot link a person before identity verification'
);

select hasnt_table_privilege('anon', 'public.privacy_requests', 'SELECT', 'anonymous users cannot enumerate privacy requests');
select hasnt_table_privilege('authenticated', 'public.privacy_requests', 'INSERT', 'authenticated users cannot directly create privacy requests');
select hasnt_table_privilege('authenticated', 'public.retention_policies', 'INSERT', 'authenticated users cannot directly create retention policy versions');

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'a9000000-0000-0000-0000-000000000009',
    'role', 'authenticated',
    'app_metadata', json_build_object('active_tenant_id', 'a0000000-0000-0000-0000-000000000001'),
    'aal', 'aal2'
  )::text,
  true
);

select is((select count(*) from public.privacy_requests), 1::bigint, 'privacy admin sees only active-tenant requests');
select is((select min(tenant_id::text) from public.privacy_requests), 'a0000000-0000-0000-0000-000000000001', 'privacy request RLS preserves tenant isolation');
select is((select count(*) from public.retention_policies), 1::bigint, 'privacy admin sees only active-tenant retention policies');

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'a9000000-0000-0000-0000-000000000009',
    'role', 'authenticated',
    'app_metadata', json_build_object('active_tenant_id', 'a0000000-0000-0000-0000-000000000001'),
    'aal', 'aal1'
  )::text,
  true
);

select is((select count(*) from public.privacy_requests), 0::bigint, 'AAL1 cannot inspect privacy requests');
select is((select count(*) from public.retention_policies), 0::bigint, 'AAL1 cannot inspect retention policies');

reset role;

select * from finish();
rollback;
