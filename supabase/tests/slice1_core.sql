begin;

select plan(16);

select has_table('public', 'agencies', 'agencies table exists');
select has_table('public', 'tenant_configurations', 'tenant_configurations table exists');
select has_table('public', 'roles', 'roles table exists');
select has_table('public', 'agency_users', 'agency_users table exists');
select has_table('public', 'agency_user_roles', 'agency_user_roles table exists');
select has_table('public', 'prospects', 'prospects table exists');
select has_table('public', 'quote_cases', 'quote_cases table exists');
select has_table('public', 'permissible_purpose_decisions', 'purpose decisions table exists');
select has_table('public', 'audit_events', 'audit_events table exists');
select has_table('public', 'idempotency_keys', 'idempotency_keys table exists');

select ok(
  not exists (
    select 1
    from pg_class c
    where c.relnamespace = 'public'::regnamespace
      and c.relname in (
        'agencies','tenant_configurations','roles','agency_users','agency_user_roles',
        'prospects','quote_cases','permissible_purpose_decisions','audit_events','idempotency_keys'
      )
      and c.relrowsecurity is false
  ),
  'RLS is enabled on every Slice 1 public table'
);

select has_schema('private', 'private security schema exists');

select is(
  (
    select count(*)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and p.proname in (
        'transition_quote_case_with_audit',
        'claim_idempotency_key',
        'get_current_workforce_context',
        'has_tenant_membership',
        'has_permission'
      )
  ),
  0::bigint,
  'no privileged Slice 1 SECURITY DEFINER helper remains exposed in public'
);

select ok(
  (
    select count(*) >= 5
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private'
      and p.prosecdef
      and p.proname in (
        'has_tenant_membership',
        'has_permission',
        'transition_quote_case_with_audit_impl',
        'claim_idempotency_key_impl',
        'get_current_workforce_context_impl'
      )
  ),
  'privileged Slice 1 helpers are isolated in private schema'
);

insert into public.idempotency_keys (
  tenant_id, scope, idempotency_key, request_hash, status
) values (
  '00000000-0000-0000-0000-000000000001', 'provider-order', 'same-key', 'hash-a', 'CLAIMED'
);

select throws_ok(
  $$
    insert into public.idempotency_keys (
      tenant_id, scope, idempotency_key, request_hash, status
    ) values (
      '00000000-0000-0000-0000-000000000001', 'provider-order', 'same-key', 'hash-a', 'CLAIMED'
    )
  $$,
  '23505',
  null,
  'idempotency uniqueness is enforced by the database'
);

select ok(
  not has_table_privilege('authenticated', 'public.quote_cases', 'UPDATE'),
  'authenticated users cannot bypass QuoteCase transition RPC with direct UPDATE'
);

select * from finish();
rollback;
