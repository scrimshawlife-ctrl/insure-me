begin;

-- Structural assertions. These are intentionally plain SQL so they can run without pgTAP.
do $$
declare
  missing_table text;
  rls_disabled text;
begin
  select required.name into missing_table
  from (
    values
      ('agencies'),
      ('tenant_configurations'),
      ('roles'),
      ('agency_users'),
      ('agency_user_roles'),
      ('prospects'),
      ('quote_cases'),
      ('permissible_purpose_decisions'),
      ('audit_events'),
      ('idempotency_keys')
  ) as required(name)
  left join pg_class c
    on c.relname = required.name
   and c.relnamespace = 'public'::regnamespace
   and c.relkind = 'r'
  where c.oid is null
  limit 1;

  if missing_table is not null then
    raise exception 'SLICE1_MISSING_TABLE:%', missing_table;
  end if;

  select c.relname into rls_disabled
  from pg_class c
  where c.relnamespace = 'public'::regnamespace
    and c.relname in (
      'agencies','tenant_configurations','roles','agency_users','agency_user_roles',
      'prospects','quote_cases','permissible_purpose_decisions','audit_events','idempotency_keys'
    )
    and c.relrowsecurity is false
  limit 1;

  if rls_disabled is not null then
    raise exception 'SLICE1_RLS_DISABLED:%', rls_disabled;
  end if;
end
$$;

-- Verify every RLS-enabled Slice 1 table has at least one policy.
do $$
declare
  missing_policy text;
begin
  select c.relname into missing_policy
  from pg_class c
  where c.relnamespace = 'public'::regnamespace
    and c.relname in (
      'agencies','tenant_configurations','roles','agency_users','agency_user_roles',
      'prospects','quote_cases','permissible_purpose_decisions','audit_events','idempotency_keys'
    )
    and not exists (
      select 1 from pg_policy p where p.polrelid = c.oid
    )
  limit 1;

  if missing_policy is not null then
    raise exception 'SLICE1_RLS_POLICY_MISSING:%', missing_policy;
  end if;
end
$$;

-- Verify idempotency uniqueness at the database boundary.
insert into public.idempotency_keys (
  tenant_id, scope, idempotency_key, request_hash, status
) values (
  '00000000-0000-0000-0000-000000000001', 'provider-order', 'same-key', 'hash-a', 'CLAIMED'
);

do $$
begin
  begin
    insert into public.idempotency_keys (
      tenant_id, scope, idempotency_key, request_hash, status
    ) values (
      '00000000-0000-0000-0000-000000000001', 'provider-order', 'same-key', 'hash-a', 'CLAIMED'
    );
    raise exception 'SLICE1_IDEMPOTENCY_UNIQUENESS_NOT_ENFORCED';
  exception
    when unique_violation then
      null;
  end;
end
$$;

rollback;
