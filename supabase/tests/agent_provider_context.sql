begin;

select plan(10);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values
  ('c1000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','Provider Context A','Provider A'),
  ('d1000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000002','Provider Context B','Provider B');

insert into public.tenant_configurations (tenant_configuration_id,tenant_id,agency_id,version,status)
values
  ('c2000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001',1,'ACTIVE'),
  ('d2000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000002',1,'ACTIVE');

insert into public.agency_users (agency_user_id,tenant_id,agency_id,workforce_identity_id,status)
values ('c3000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c9000000-0000-0000-0000-000000000009','ACTIVE');

insert into public.roles (role_id,tenant_id,agency_id,name,permissions)
values ('c4000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','reader',array['CASE_READ']::public.permission_code[]);

insert into public.agency_user_roles (agency_user_id,role_id)
values ('c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001');

insert into public.prospects (prospect_id,tenant_id,agency_id)
values
  ('c5000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001'),
  ('d5000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000002');

insert into public.quote_cases (
  quote_case_id,tenant_id,agency_id,tenant_configuration_id,tenant_configuration_version,
  jurisdiction,product_line,source_channel,state,prospect_id
) values
  ('c6000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001',1,'CA','PRIVATE_PASSENGER_AUTO','TEST','REVIEW_REQUIRED','c5000000-0000-0000-0000-000000000001'),
  ('d6000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000002','d2000000-0000-0000-0000-000000000002',1,'CA','PRIVATE_PASSENGER_AUTO','TEST','REVIEW_REQUIRED','d5000000-0000-0000-0000-000000000002');

insert into public.provider_bindings (
  provider_binding_id,tenant_id,agency_id,capability,adapter_id,adapter_version,
  jurisdiction,product_line,status,purpose_code,required_for_readiness
) values (
  'c7000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001',
  'MVR','stub-mvr','1.0.0','CA','PRIVATE_PASSENGER_AUTO','ACTIVE','INSURANCE_UNDERWRITING',true
);

insert into public.permissible_purpose_decisions (
  decision_id,tenant_id,quote_case_id,tenant_configuration_version,jurisdiction,
  capability,purpose_code,outcome,policy_version
) values (
  'c7100000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001',1,'CA',
  'MVR','INSURANCE_UNDERWRITING','ALLOW','purpose-v1'
);

insert into public.external_requests (
  external_request_id,tenant_id,agency_id,quote_case_id,tenant_configuration_version,
  provider_binding_id,capability,subject_ids,permissible_purpose_decision_id,
  idempotency_key,request_hash,status,requested_at,completed_at
) values (
  'c7200000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001',1,
  'c7000000-0000-0000-0000-000000000001','MVR',array['c7300000-0000-0000-0000-000000000001']::uuid[],'c7100000-0000-0000-0000-000000000001',
  'agent-provider-context-fixture','hash-fixture','SUCCEEDED',now() - interval '2 minutes',now() - interval '1 minute'
);

insert into public.external_reports (
  external_report_id,tenant_id,agency_id,quote_case_id,external_request_id,
  provider_id,provider_product_id,status,retrieved_at,fresh_until,normalized_snapshot,
  normalized_version,warnings
) values (
  'c7400000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001','c7200000-0000-0000-0000-000000000001',
  'synthetic','mvr','SUCCESS',now() - interval '1 minute',now() + interval '1 day','{"secretRaw":"must-not-project"}'::jsonb,
  'normalized-v1',array['SYNTHETIC_WARNING']::text[]
);

insert into public.provenance_entries (
  provenance_entry_id,tenant_id,agency_id,quote_case_id,external_report_id,
  source_type,source_id,fact_key,source_path,transformation_version,confidence_state
) values
  ('c7500000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001','c7400000-0000-0000-0000-000000000001','PROVIDER','synthetic:mvr','licenseStatus','$.license.status','normalize-v1','HIGH'),
  ('c7500000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001','c7400000-0000-0000-0000-000000000001','PROVIDER','synthetic:mvr','secretScore','$.secret.score','normalize-v1','HIGH');

insert into public.data_use_policy_rules (
  data_use_policy_rule_id,tenant_id,agency_id,policy_version,observation_type,
  collection_allowed,agent_display_allowed,underwriting_allowed,prohibited
) values
  ('c7600000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','data-v1','MVR_LICENSE_STATUS',true,true,true,false),
  ('c7600000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','data-v1','MVR_SECRET_SCORE',false,false,false,true);

insert into public.underwriting_observations (
  observation_id,tenant_id,agency_id,quote_case_id,observation_type,subject_id,
  normalized_value,provenance_entry_ids,data_use_classification,data_use_policy_version
) values
  ('c7700000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001','MVR_LICENSE_STATUS','c7300000-0000-0000-0000-000000000001','{"status":"VALID"}'::jsonb,array['c7500000-0000-0000-0000-000000000001']::uuid[],'UNDERWRITING_ALLOWED','data-v1'),
  ('c7700000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001','MVR_SECRET_SCORE','c7300000-0000-0000-0000-000000000001','{"score":999}'::jsonb,array['c7500000-0000-0000-0000-000000000002']::uuid[],'PROHIBITED','data-v1');

set local role authenticated;
select set_config('request.jwt.claims',json_build_object(
  'sub','c9000000-0000-0000-0000-000000000009',
  'role','authenticated',
  'app_metadata',json_build_object('active_tenant_id','c0000000-0000-0000-0000-000000000001'),
  'aal','aal2'
)::text,true);

select lives_ok(
  $$select public.get_workforce_case_provider_context('c6000000-0000-0000-0000-000000000001')$$,
  'AAL2 CASE_READ workforce can load provider context'
);

select is(
  (public.get_workforce_case_provider_context('c6000000-0000-0000-0000-000000000001')->>'canRefreshProviders')::boolean,
  false,
  'CASE_READ alone does not grant provider refresh'
);

select ok(
  not (public.get_workforce_case_provider_context('c6000000-0000-0000-0000-000000000001')->'reports'->0 ? 'normalizedSnapshot'),
  'report projection omits normalized provider snapshot'
);

select is(
  jsonb_array_length(public.get_workforce_case_provider_context('c6000000-0000-0000-0000-000000000001')->'observations'),
  1,
  'only policy-displayable observations are projected'
);

select is(
  public.get_workforce_case_provider_context('c6000000-0000-0000-0000-000000000001')->'observations'->0->>'observationType',
  'MVR_LICENSE_STATUS',
  'displayable observation is present and prohibited observation is absent'
);

select is(
  public.get_workforce_case_provider_context('c6000000-0000-0000-0000-000000000001')->'observations'->0->'provenance'->0->>'factKey',
  'licenseStatus',
  'provenance is projected only through admitted observation'
);

reset role;
update public.roles
set permissions = array['CASE_READ','REPORT_RETRIEVE']::public.permission_code[]
where role_id = 'c4000000-0000-0000-0000-000000000001';
set local role authenticated;

select is(
  (public.get_workforce_case_provider_context('c6000000-0000-0000-0000-000000000001')->>'canRefreshProviders')::boolean,
  true,
  'REPORT_RETRIEVE enables provider refresh capability'
);

select is(
  (public.get_workforce_case_provider_context('c6000000-0000-0000-0000-000000000001')->'reports'->0->>'canRefresh')::boolean,
  true,
  'provider row is refreshable when permission and prior subject context exist'
);

select throws_ok(
  $$select public.get_workforce_case_provider_context('d6000000-0000-0000-0000-000000000002')$$,
  '42501','CASE_READ_NOT_PERMITTED',
  'active tenant A cannot project tenant B provider context'
);

select set_config('request.jwt.claims',json_build_object(
  'sub','c9000000-0000-0000-0000-000000000009',
  'role','authenticated',
  'app_metadata',json_build_object('active_tenant_id','c0000000-0000-0000-0000-000000000001'),
  'aal','aal1'
)::text,true);

select throws_ok(
  $$select public.get_workforce_case_provider_context('c6000000-0000-0000-0000-000000000001')$$,
  '42501','CASE_READ_NOT_PERMITTED',
  'AAL1 cannot load workforce provider context'
);

select * from finish();
rollback;
