begin;

select plan(10);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values (
  '81000000-0000-0000-0000-000000000001',
  '80000000-0000-0000-0000-000000000001',
  'Synthetic Identity Agency',
  'Identity Agency'
);

insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status
) values (
  '82000000-0000-0000-0000-000000000001',
  '80000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000001',
  1,
  'ACTIVE'
);

insert into public.prospects (prospect_id, tenant_id, agency_id)
values
  ('83000000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001'),
  ('83000000-0000-0000-0000-000000000002', '80000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001');

insert into public.quote_cases (
  quote_case_id, tenant_id, agency_id, tenant_configuration_id,
  tenant_configuration_version, jurisdiction, product_line,
  source_channel, state, prospect_id
) values
  (
    '84000000-0000-0000-0000-000000000001',
    '80000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000001',
    '82000000-0000-0000-0000-000000000001',
    1, 'CA', 'PRIVATE_PASSENGER_AUTO', 'TEST', 'CONSUMER_INPUT',
    '83000000-0000-0000-0000-000000000001'
  ),
  (
    '84000000-0000-0000-0000-000000000002',
    '80000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000001',
    '82000000-0000-0000-0000-000000000001',
    1, 'CA', 'PRIVATE_PASSENGER_AUTO', 'TEST', 'CONSUMER_INPUT',
    '83000000-0000-0000-0000-000000000002'
  );

insert into public.consumer_quote_access (
  tenant_id, agency_id, quote_case_id, consumer_identity_id, status, expires_at
) values (
  '80000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000001',
  '84000000-0000-0000-0000-000000000001',
  '89000000-0000-0000-0000-000000000009',
  'ACTIVE',
  now() + interval '1 hour'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '89000000-0000-0000-0000-000000000009',
    'role', 'authenticated',
    'aal', 'aal1'
  )::text,
  true
);

select lives_ok(
  $$select public.upsert_consumer_identity(
    '84000000-0000-0000-0000-000000000001',
    '\x010203'::bytea,
    'synthetic-key-v1',
    repeat('a', 64),
    repeat('b', 64)
  )$$,
  'consumer can persist protected identity through checked RPC'
);

-- Inspect internal storage as the database owner; consumer RLS correctly hides prospects.
reset role;

select isnt(
  (
    select p.person_id
    from public.prospects p
    where p.prospect_id = '83000000-0000-0000-0000-000000000001'
  ),
  null::uuid,
  'identity persistence links a Person to the Prospect'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '89000000-0000-0000-0000-000000000009',
    'role', 'authenticated',
    'aal', 'aal1'
  )::text,
  true
);

select throws_ok(
  $$select * from public.person_private_profiles$$,
  '42501',
  null,
  'consumer cannot directly read protected identity table'
);

select lives_ok(
  $$select public.upsert_consumer_identity(
    '84000000-0000-0000-0000-000000000001',
    '\x040506'::bytea,
    'synthetic-key-v2',
    repeat('c', 64),
    null
  )$$,
  'consumer can update the existing protected identity through RPC'
);

reset role;

select is(
  (
    select pp.payload_version
    from public.person_private_profiles pp
    join public.prospects p on p.person_id = pp.person_id
    where p.prospect_id = '83000000-0000-0000-0000-000000000001'
  ),
  2,
  'identity update increments protected payload version instead of creating a second Person'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '89000000-0000-0000-0000-000000000009',
    'role', 'authenticated',
    'aal', 'aal1'
  )::text,
  true
);

select throws_ok(
  $$select public.upsert_consumer_identity(
    '84000000-0000-0000-0000-000000000002',
    '\x070809'::bytea,
    'synthetic-key-v1',
    repeat('d', 64),
    null
  )$$,
  '42501',
  'CONSUMER_QUOTE_ACCESS_DENIED',
  'consumer cannot persist identity against an unowned QuoteCase'
);

create temporary table _resume as
select (public.create_consumer_resume_grant(
  '84000000-0000-0000-0000-000000000001',
  60
)).*;

select is(
  (select quote_case_id from _resume),
  '84000000-0000-0000-0000-000000000001'::uuid,
  'resume grant is bound to the owned QuoteCase'
);

select throws_ok(
  $$select public.create_consumer_resume_grant(
    '84000000-0000-0000-0000-000000000001',
    2
  )$$,
  '22023',
  'RESUME_TTL_OUT_OF_RANGE',
  'resume grants enforce bounded expiration'
);

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '89000000-0000-0000-0000-000000000010',
    'role', 'authenticated',
    'aal', 'aal1'
  )::text,
  true
);

select throws_ok(
  format(
    'select public.consume_consumer_resume_grant(%L::uuid)',
    (select resume_grant_id::text from _resume)
  ),
  '42501',
  'RESUME_GRANT_INVALID',
  'resume identifier alone cannot be redeemed by another authenticated consumer'
);

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '89000000-0000-0000-0000-000000000009',
    'role', 'authenticated',
    'aal', 'aal1'
  )::text,
  true
);

select is(
  public.consume_consumer_resume_grant((select resume_grant_id from _resume)),
  '84000000-0000-0000-0000-000000000001'::uuid,
  'same authenticated consumer can redeem resume grant exactly once'
);

select * from finish();
rollback;
