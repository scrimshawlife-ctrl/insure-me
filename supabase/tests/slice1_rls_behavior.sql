begin;

-- Deterministic synthetic tenant fixtures.
insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Synthetic Agency A', 'Agency A'),
  ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Synthetic Agency B', 'Agency B');

insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status
) values
  ('11000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 1, 'ACTIVE'),
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

do $$
declare
  visible_count integer;
  visible_tenant uuid;
begin
  select count(*), min(tenant_id)
  into visible_count, visible_tenant
  from public.quote_cases;

  if visible_count <> 1 or visible_tenant <> '00000000-0000-0000-0000-000000000001'::uuid then
    raise exception 'SLICE1_ACTIVE_TENANT_ISOLATION_FAILED';
  end if;
end
$$;

-- Atomic transition succeeds in the active tenant and creates exactly one audit event.
select public.transition_quote_case_with_audit(
  '61000000-0000-0000-0000-000000000001',
  'NOTICE_REQUIRED',
  'QUOTE_CASE_STATE_CHANGED',
  array['TEST_TRANSITION']
);

do $$
declare
  state_value public.quote_case_state;
  audit_count integer;
begin
  select state into state_value
  from public.quote_cases
  where quote_case_id = '61000000-0000-0000-0000-000000000001';

  if state_value <> 'NOTICE_REQUIRED' then
    raise exception 'SLICE1_ATOMIC_TRANSITION_STATE_FAILED';
  end if;

  select count(*) into audit_count
  from public.audit_events
  where quote_case_id = '61000000-0000-0000-0000-000000000001'
    and event_type = 'QUOTE_CASE_STATE_CHANGED';

  if audit_count <> 1 then
    raise exception 'SLICE1_ATOMIC_TRANSITION_AUDIT_FAILED';
  end if;
end
$$;

-- Same identity is also a member of Tenant B, but active tenant A MUST still deny Tenant B.
do $$
begin
  begin
    perform public.transition_quote_case_with_audit(
      '62000000-0000-0000-0000-000000000002',
      'NOTICE_REQUIRED',
      'QUOTE_CASE_STATE_CHANGED',
      array['MUST_DENY']
    );
    raise exception 'SLICE1_CROSS_TENANT_RPC_NOT_DENIED';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

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

do $$
declare
  visible_count integer;
begin
  select count(*) into visible_count from public.quote_cases;
  if visible_count <> 0 then
    raise exception 'SLICE1_AAL1_WORKFORCE_ACCESS_NOT_DENIED';
  end if;
end
$$;

reset role;

-- Verify the denied cross-tenant call did not partially mutate state or emit audit evidence.
do $$
declare
  state_value public.quote_case_state;
  audit_count integer;
begin
  select state into state_value
  from public.quote_cases
  where quote_case_id = '62000000-0000-0000-0000-000000000002';

  if state_value <> 'DRAFT' then
    raise exception 'SLICE1_CROSS_TENANT_PARTIAL_STATE_MUTATION';
  end if;

  select count(*) into audit_count
  from public.audit_events
  where quote_case_id = '62000000-0000-0000-0000-000000000002';

  if audit_count <> 0 then
    raise exception 'SLICE1_CROSS_TENANT_PARTIAL_AUDIT_WRITE';
  end if;
end
$$;

rollback;
