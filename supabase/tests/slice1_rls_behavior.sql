begin;

select plan(13);

-- Deterministic synthetic tenant fixtures.
insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Synthetic Agency A', 'Agency A'),
  ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Synthetic Agency B', 'Agency B');

insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status
) values
  ('11000000-0000-0000-0000-000000000001', '00000000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 1, 'ACTIVE'),
  ('22000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 1, 'ACTIVE');

insert into public.agency_users (
  agency_user_id, tenant_id, agency_id, workforce_identity_id, status
) values
  ('31000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000009', 'ACTIVE'),
  ('32000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000009', 'ACTIVE');

insert into public.roles (role_id, tenant_id, agency_id, name, permissions)
values
  ('41000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'agent', array['CASE_READ','CASE_WRITE','AUDIT_READ']::public.permission_code[]),
  ('42000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'agent', array['CASE_READ','CASE_WRITE','AUDIT_READ']::public.permission_code[]);

insert into public.agency_user_roles (agency_user_id, role_id)
values
  ('31000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000001'),
  ('32000000-0000-0000-0000-000000000002', '42000000-0000-0000-0000-000000000002');

insert into public.prospects (prospect_id, tenant_id, agency_id)
values
  ('51000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001'),
  ('52000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002');

insert into public.quote_cases (
  quote_case_id, tenant_id, agency_id, tenant_configuration_id,
  tenant_configuration_version, jurisdiction, product_line, source_channel, prospect_id
) values
  ('61000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001', 1, 'CA', 'PRIVATE_PASSENGER_AUTO', 'TEST', '51000000-0000-0000-0000-000000000001'),
  ('62000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', '22000000-0000-0000-0000-000000000002', 1, 'CA', 'PRIVATE_PASSENGER_AUTO', 'TEST', '52000000-0000-0000-0000-000000000002');

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '90000000-0000-0000-0000-000000000009',
    'role', 'authenticated',
    'app_metadata', json_build_object('active_tenant_id', '00000000-0000-0000-0000-000000000001'),
    'aal', 'aal2'
  )::text,
  true
);

select is(
  (select count(*) from public.quote_cases),
  1::bigint,
  'active tenant sees exactly one QuoteCase even when identity belongs to two tenants'
);

select is(
  (select min(tenant_id::text) from public.quote_cases),
  '00000000-0000-0000-0000-000000000001',
  'visible QuoteCase belongs to active tenant A'
);

select is(
  (select count(*) from public.get_current_workforce_context()),
  1::bigint,
  'trusted workforce context resolves exactly once for active tenant'
);

select lives_ok(
  $$
    select public.transition_quote_case_with_audit(
      '61000000-0000-0000-0000-000000000001',
      'NOTICE_REQUIRED',
      'QUOTE_CASE_STATE_CHANGED',
      array['TEST_TRANSITION']
    )
  $$,
  'atomic transition RPC succeeds inside active tenant'
);

select is(
  (
    select state::text
    from public.quote_cases
    where quote_case_id = '61000000-0000-0000-0000-000000000001'
  ),
  'NOTICE_REQUIRED',
  'atomic transition updates QuoteCase state'
);

select is(
  (
    select count(*)
    from public.audit_events
    where quote_case_id = '61000000-0000-0000-0000-000000000001'
      and event_type = 'QUOTE_CASE_STATE_CHANGED'
  ),
  1::bigint,
  'atomic transition creates exactly one audit event'
);

select throws_ok(
  $$
    select public.transition_quote_case_with_audit(
      '62000000-0000-0000-0000-000000000002',
      'NOTICE_REQUIRED',
      'QUOTE_CASE_STATE_CHANGED',
      array['MUST_DENY']
    )
  $$,
  '42501',
  'CASE_WRITE_NOT_PERMITTED',
  'active tenant A cannot mutate tenant B through privileged RPC'
);

select lives_ok(
  $$select public.claim_idempotency_key('quote-transition', 'same-request', 'hash-a')$$,
  'first idempotency claim succeeds'
);

select lives_ok(
  $$select public.claim_idempotency_key('quote-transition', 'same-request', 'hash-a')$$,
  'same idempotency key and request hash returns the existing claim'
);

select throws_ok(
  $$select public.claim_idempotency_key('quote-transition', 'same-request', 'hash-b')$$,
  '22023',
  'IDEMPOTENCY_KEY_REQUEST_MISMATCH',
  'same idempotency key cannot be reused for a different request'
);

-- AAL1 cannot read tenant data even with valid membership and active tenant metadata.
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '90000000-0000-0000-0000-000000000009',
    'role', 'authenticated',
    'app_metadata', json_build_object('active_tenant_id', '00000000-0000-0000-0000-000000000001'),
    'aal', 'aal1'
  )::text,
  true
);

select is(
  (select count(*) from public.quote_cases),
  0::bigint,
  'AAL1 cannot read workforce QuoteCases'
);

reset role;

-- Cross-tenant denial must not partially mutate tenant B.
select is(
  (
    select state::text
    from public.quote_cases
    where quote_case_id = '62000000-0000-0000-0000-000000000002'
  ),
  'DRAFT',
  'denied cross-tenant call leaves tenant B state unchanged'
);

select is(
  (
    select count(*)
    from public.audit_events
    where quote_case_id = '62000000-0000-0000-0000-000000000002'
  ),
  0::bigint,
  'denied cross-tenant call emits no tenant B audit mutation'
);

select * from finish();
rollback;
