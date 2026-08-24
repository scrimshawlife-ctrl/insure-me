begin;

select plan(24);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name) values
  ('c1000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Hold Agency A', 'Hold A'),
  ('d1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'Hold Agency B', 'Hold B');
insert into public.agency_users (agency_user_id, tenant_id, agency_id, workforce_identity_id, status) values
  ('c2000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'c9000000-0000-0000-0000-000000000009', 'ACTIVE');
insert into public.roles (role_id, tenant_id, agency_id, name, permissions) values
  ('c3000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'legal-hold-admin', array['PRIVACY_ADMIN']::public.permission_code[]);
insert into public.agency_user_roles (agency_user_id, role_id) values
  ('c2000000-0000-0000-0000-000000000001', 'c3000000-0000-0000-0000-000000000001');
insert into public.person_private_profiles (
  person_id, tenant_id, agency_id, encrypted_payload, encryption_algorithm, key_version
) values
  ('c4000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', decode('00', 'hex'), 'AES-256-GCM', 'synthetic-key'),
  ('d4000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', decode('00', 'hex'), 'AES-256-GCM', 'synthetic-key');

select has_table('public', 'legal_holds', 'legal hold table exists');
select has_table('public', 'legal_hold_events', 'legal hold evidence table exists');
select col_type_is('public', 'legal_holds', 'scope_type', 'legal_hold_scope_type', 'hold scope is closed');
select col_type_is('public', 'legal_holds', 'status', 'legal_hold_status', 'hold status is closed');
select is(has_table_privilege('anon', 'public.legal_holds', 'SELECT'), false, 'anonymous cannot enumerate holds');
select is(has_table_privilege('authenticated', 'public.legal_holds', 'INSERT'), false, 'authenticated cannot directly place holds');
select is(has_table_privilege('authenticated', 'public.legal_hold_events', 'UPDATE'), false, 'authenticated cannot rewrite hold evidence');
select is(has_function_privilege('authenticated', 'public.place_legal_hold(uuid,uuid,public.legal_hold_scope_type,uuid,text,text,text[],uuid,text)', 'EXECUTE'), true, 'authenticated workforce can call checked placement RPC');
select is(has_function_privilege('anon', 'public.release_legal_hold(uuid,text,text,text[],uuid,text)', 'EXECUTE'), false, 'anonymous cannot release holds');

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub','c9000000-0000-0000-0000-000000000009', 'role','authenticated',
  'app_metadata',json_build_object('active_tenant_id','c0000000-0000-0000-0000-000000000001'),
  'aal','aal2')::text, true);

create temporary table placed_hold as select (public.place_legal_hold(
  'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001',
  'PERSON', 'c4000000-0000-0000-0000-000000000001', 'authority:synthetic-001',
  'evidence:synthetic-001', array['PRESERVATION_REQUIRED'],
  'c5000000-0000-4000-8000-000000000001', repeat('a',64))).*;

select is((select status::text from placed_hold), 'ACTIVE', 'placement creates an active hold');
select is((select count(*) from public.legal_holds), 1::bigint, 'admin sees one tenant-scoped hold');
select is((select count(*) from public.legal_hold_events where event_type = 'PLACED'), 1::bigint, 'placement creates evidence');
reset role;
select is((select private.has_retention_hold_signal(
  'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001',
  'c4000000-0000-0000-0000-000000000001')), true, 'active formal hold blocks retention');
set local role authenticated;
select is((select (public.place_legal_hold(
  'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001',
  'PERSON', 'c4000000-0000-0000-0000-000000000001', 'authority:synthetic-001',
  'evidence:synthetic-001', array['PRESERVATION_REQUIRED'],
  'c5000000-0000-4000-8000-000000000001', repeat('a',64))).legal_hold_id),
  (select legal_hold_id from placed_hold), 'placement replay returns the same hold');
select is((select count(*) from public.legal_hold_events), 1::bigint, 'placement replay creates no duplicate evidence');
select throws_ok($$select public.place_legal_hold(
  'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001',
  'PERSON', 'c4000000-0000-0000-0000-000000000001', 'authority:synthetic-001',
  'evidence:synthetic-001', array['PRESERVATION_REQUIRED'],
  'c5000000-0000-4000-8000-000000000001', repeat('b',64))$$,
  '22023', 'IDEMPOTENCY_KEY_REQUEST_MISMATCH', 'placement key cannot bind another request');
select throws_ok($$select public.place_legal_hold(
  'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001',
  'PERSON', 'd4000000-0000-0000-0000-000000000001', 'authority:synthetic-002',
  'evidence:synthetic-002', array['PRESERVATION_REQUIRED'],
  'c5000000-0000-4000-8000-000000000002', repeat('c',64))$$,
  'P0002', 'LEGAL_HOLD_SCOPE_NOT_FOUND', 'cross-tenant scope fails closed');

create temporary table released_hold as select (public.release_legal_hold(
  (select legal_hold_id from placed_hold), 'release-authority:synthetic-001',
  'release-evidence:synthetic-001', array['MATTER_CLOSED'],
  'c6000000-0000-4000-8000-000000000001', repeat('d',64))).*;
select is((select status::text from released_hold), 'RELEASED', 'explicit release closes the hold');
select is((select count(*) from public.legal_hold_events where event_type = 'RELEASED'), 1::bigint, 'release creates evidence');
reset role;
select is((select private.has_retention_hold_signal(
  'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001',
  'c4000000-0000-0000-0000-000000000001')), false, 'released formal hold no longer blocks retention');
set local role authenticated;
select is((select (public.release_legal_hold(
  (select legal_hold_id from placed_hold), 'release-authority:synthetic-001',
  'release-evidence:synthetic-001', array['MATTER_CLOSED'],
  'c6000000-0000-4000-8000-000000000001', repeat('d',64))).status::text),
  'RELEASED', 'release replay is idempotent');
reset role;
select is((select count(*) from public.audit_events where event_type in ('LEGAL_HOLD_PLACED','LEGAL_HOLD_RELEASED')), 2::bigint, 'placement and release are audited');
select throws_ok($$update public.legal_hold_events set evidence_ref = 'forged'$$,
  '22023', 'LEGAL_HOLD_EVENT_IMMUTABLE', 'hold evidence is append-only');
select throws_ok($$delete from public.legal_holds$$,
  '22023', 'LEGAL_HOLD_EVENT_IMMUTABLE', 'holds cannot be deleted');
select * from finish();
rollback;
