begin;

select plan(16);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values (
  '71000000-0000-0000-0000-000000000001',
  '70000000-0000-0000-0000-000000000001',
  'Synthetic Consumer Agency',
  'Consumer Agency'
);

insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status
) values (
  '72000000-0000-0000-0000-000000000001',
  '70000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000001',
  1,
  'ACTIVE'
);

insert into public.prospects (prospect_id, tenant_id, agency_id)
values
  ('73000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001'),
  ('73000000-0000-0000-0000-000000000002', '70000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001');

insert into public.quote_cases (
  quote_case_id, tenant_id, agency_id, tenant_configuration_id,
  tenant_configuration_version, jurisdiction, product_line,
  source_channel, state, prospect_id
) values
  (
    '74000000-0000-0000-0000-000000000001',
    '70000000-0000-0000-0000-000000000001',
    '71000000-0000-0000-0000-000000000001',
    '72000000-0000-0000-0000-000000000001',
    1, 'CA', 'PRIVATE_PASSENGER_AUTO', 'TEST', 'NOTICE_REQUIRED',
    '73000000-0000-0000-0000-000000000001'
  ),
  (
    '74000000-0000-0000-0000-000000000002',
    '70000000-0000-0000-0000-000000000001',
    '71000000-0000-0000-0000-000000000001',
    '72000000-0000-0000-0000-000000000001',
    1, 'CA', 'PRIVATE_PASSENGER_AUTO', 'TEST', 'NOTICE_REQUIRED',
    '73000000-0000-0000-0000-000000000002'
  );

insert into public.consumer_quote_access (
  tenant_id, agency_id, quote_case_id, consumer_identity_id, status, expires_at
) values (
  '70000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000001',
  '74000000-0000-0000-0000-000000000001',
  '79000000-0000-0000-0000-000000000009',
  'ACTIVE',
  now() + interval '1 hour'
);

insert into public.notice_definitions (
  notice_definition_id, tenant_id, agency_id, notice_key, version, status,
  category, jurisdiction, product_line, title, body_markdown, content_hash,
  required_for_quote, effective_at
) values
  (
    '75000000-0000-0000-0000-000000000001',
    '70000000-0000-0000-0000-000000000001',
    '71000000-0000-0000-0000-000000000001',
    'synthetic-privacy', 1, 'SYNTHETIC', 'INSURANCE_PRIVACY',
    'CA', 'PRIVATE_PASSENGER_AUTO', 'Synthetic privacy notice',
    'SYNTHETIC_NOT_FOR_PRODUCTION', repeat('a', 64), true, now() - interval '1 minute'
  ),
  (
    '75000000-0000-0000-0000-000000000002',
    '70000000-0000-0000-0000-000000000001',
    '71000000-0000-0000-0000-000000000001',
    'synthetic-report-auth', 1, 'SYNTHETIC', 'REPORT_AUTHORIZATION',
    'CA', 'PRIVATE_PASSENGER_AUTO', 'Synthetic report authorization',
    'SYNTHETIC_NOT_FOR_PRODUCTION', repeat('b', 64), true, now() - interval '1 minute'
  ),
  (
    '75000000-0000-0000-0000-000000000003',
    '70000000-0000-0000-0000-000000000001',
    '71000000-0000-0000-0000-000000000001',
    'synthetic-marketing', 1, 'SYNTHETIC', 'MARKETING_OPTIONAL',
    'CA', 'PRIVATE_PASSENGER_AUTO', 'Synthetic optional marketing',
    'SYNTHETIC_NOT_FOR_PRODUCTION', repeat('c', 64), false, now() - interval '1 minute'
  );

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '79000000-0000-0000-0000-000000000009',
    'role', 'authenticated',
    'aal', 'aal1'
  )::text,
  true
);

select is(
  (select count(*) from public.quote_cases),
  1::bigint,
  'consumer sees only the explicitly authorized QuoteCase, even within the same tenant'
);

select is(
  (select count(*) from public.get_consumer_quote_context('74000000-0000-0000-0000-000000000001')),
  1::bigint,
  'consumer context resolves for owned QuoteCase'
);

select is(
  (select count(*) from public.get_consumer_quote_context('74000000-0000-0000-0000-000000000002')),
  0::bigint,
  'consumer context does not disclose unowned QuoteCase'
);

select is(
  (select count(*) from public.get_required_notices_for_quote('74000000-0000-0000-0000-000000000001')),
  3::bigint,
  'consumer receives active notices for owned QuoteCase'
);

select lives_ok(
  $$select public.record_consumer_consent_with_audit(
    '74000000-0000-0000-0000-000000000001',
    '75000000-0000-0000-0000-000000000001',
    repeat('a', 64), 'ACKNOWLEDGE', now(), 'WEB', 'test:privacy', 'privacy-key-0001'
  )$$,
  'privacy acknowledgment records successfully'
);

select is(
  (select state::text from public.quote_cases where quote_case_id = '74000000-0000-0000-0000-000000000001'),
  'NOTICE_REQUIRED',
  'one required acknowledgment does not prematurely advance the quote'
);

select lives_ok(
  $$select public.record_consumer_consent_with_audit(
    '74000000-0000-0000-0000-000000000001',
    '75000000-0000-0000-0000-000000000003',
    repeat('c', 64), 'OPT_IN', now(), 'WEB', 'test:marketing', 'marketing-key-0001'
  )$$,
  'optional marketing choice records independently'
);

select is(
  (select state::text from public.quote_cases where quote_case_id = '74000000-0000-0000-0000-000000000001'),
  'NOTICE_REQUIRED',
  'marketing opt-in never unlocks quote progression'
);

select throws_ok(
  $$select public.record_consumer_consent_with_audit(
    '74000000-0000-0000-0000-000000000001',
    '75000000-0000-0000-0000-000000000002',
    repeat('b', 64), 'ACKNOWLEDGE', now(), 'WEB', 'test:bad-auth', 'bad-auth-key-0001'
  )$$,
  '22023',
  'CONSENT_ACTION_INVALID_FOR_NOTICE_CATEGORY',
  'acknowledgment cannot substitute for report authorization'
);

select lives_ok(
  $$select public.record_consumer_consent_with_audit(
    '74000000-0000-0000-0000-000000000001',
    '75000000-0000-0000-0000-000000000002',
    repeat('b', 64), 'AUTHORIZE', now(), 'WEB', 'test:report-auth', 'report-auth-key-0001'
  )$$,
  'affirmative report authorization records successfully'
);

select is(
  (select state::text from public.quote_cases where quote_case_id = '74000000-0000-0000-0000-000000000001'),
  'CONSUMER_INPUT',
  'quote advances only after every required notice is satisfied'
);

select lives_ok(
  $$select public.record_consumer_consent_with_audit(
    '74000000-0000-0000-0000-000000000001',
    '75000000-0000-0000-0000-000000000002',
    repeat('b', 64), 'AUTHORIZE', now(), 'WEB', 'test:report-auth-retry', 'report-auth-key-0001'
  )$$,
  'same consent idempotency key and semantics returns existing record'
);

select is(
  (
    select count(*)
    from public.consent_records
    where quote_case_id = '74000000-0000-0000-0000-000000000001'
      and notice_definition_id = '75000000-0000-0000-0000-000000000002'
  ),
  1::bigint,
  'idempotent retry does not duplicate consent'
);

select throws_ok(
  $$select public.record_consumer_consent_with_audit(
    '74000000-0000-0000-0000-000000000002',
    '75000000-0000-0000-0000-000000000001',
    repeat('a', 64), 'ACKNOWLEDGE', now(), 'WEB', 'test:other', 'other-key-0001'
  )$$,
  '42501',
  'CONSUMER_QUOTE_ACCESS_DENIED',
  'consumer cannot record consent against another QuoteCase'
);

reset role;

select throws_ok(
  $$update public.notice_definitions
    set body_markdown = 'changed after activation'
    where notice_definition_id = '75000000-0000-0000-0000-000000000001'$$,
  '22023',
  'NOTICE_VERSION_IMMUTABLE',
  'activated notice content cannot be edited in place'
);

select throws_ok(
  $$insert into public.notice_definitions (
      tenant_id, agency_id, notice_key, version, status, category,
      jurisdiction, product_line, title, body_markdown, content_hash, required_for_quote
    ) values (
      '70000000-0000-0000-0000-000000000001',
      '71000000-0000-0000-0000-000000000001',
      'bad-marketing', 1, 'SYNTHETIC', 'MARKETING_OPTIONAL',
      'CA', 'PRIVATE_PASSENGER_AUTO', 'Bad marketing', 'synthetic', repeat('d', 64), true
    )$$,
  '23514',
  null,
  'marketing notice cannot be configured as required for quote'
);

select is(
  (
    select count(*)
    from public.audit_events
    where quote_case_id = '74000000-0000-0000-0000-000000000001'
      and event_type in ('CONSUMER_NOTICE_ACTION','QUOTE_CASE_REQUIRED_NOTICES_SATISFIED')
  ),
  4::bigint,
  'consent actions and progression produce auditable evidence'
);

select * from finish();
rollback;
