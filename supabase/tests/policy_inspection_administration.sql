begin;
select plan(15);

insert into public.agencies (agency_id,tenant_id,legal_name,display_name) values
('c1100000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','Policy Agency','Policy'),
('c1100000-0000-0000-0000-000000000002','c1000000-0000-0000-0000-000000000001','Other Policy Agency','Other');
insert into public.agency_users (agency_user_id,tenant_id,agency_id,workforce_identity_id,status) values
('c1200000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c1100000-0000-0000-0000-000000000001','c1900000-0000-0000-0000-000000000001','ACTIVE'),
('c1200000-0000-0000-0000-000000000002','c1000000-0000-0000-0000-000000000001','c1100000-0000-0000-0000-000000000001','c1900000-0000-0000-0000-000000000002','ACTIVE'),
('c1200000-0000-0000-0000-000000000003','c1000000-0000-0000-0000-000000000001','c1100000-0000-0000-0000-000000000001','c1900000-0000-0000-0000-000000000003','ACTIVE');
insert into public.roles (role_id,tenant_id,agency_id,name,permissions) values
('c1300000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c1100000-0000-0000-0000-000000000001','policy-admin',array['POLICY_ADMIN']::public.permission_code[]),
('c1300000-0000-0000-0000-000000000002','c1000000-0000-0000-0000-000000000001','c1100000-0000-0000-0000-000000000001','privacy-admin',array['PRIVACY_ADMIN']::public.permission_code[]),
('c1300000-0000-0000-0000-000000000003','c1000000-0000-0000-0000-000000000001','c1100000-0000-0000-0000-000000000001','agent',array['CASE_READ']::public.permission_code[]);
insert into public.agency_user_roles values
('c1200000-0000-0000-0000-000000000001','c1300000-0000-0000-0000-000000000001'),
('c1200000-0000-0000-0000-000000000002','c1300000-0000-0000-0000-000000000002'),
('c1200000-0000-0000-0000-000000000003','c1300000-0000-0000-0000-000000000003');

insert into public.data_use_policy_rules
  (data_use_policy_rule_id,tenant_id,agency_id,policy_version,observation_type,collection_allowed,agent_display_allowed) values
('c1400000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c1100000-0000-0000-0000-000000000001','data-use-v1','DRIVER_LICENSE_STATUS',true,true),
('c1400000-0000-0000-0000-000000000002','c1000000-0000-0000-0000-000000000001','c1100000-0000-0000-0000-000000000002','other-v1','OTHER',true,false);
insert into public.retention_policies
  (retention_policy_id,tenant_id,agency_id,policy_set_id,version,data_class,jurisdiction,retention_interval,disposition,certification_state,legal_authority_refs,effective_at) values
('c1500000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c1100000-0000-0000-0000-000000000001','retention-v1',1,'QUOTE_CASE','CA',interval '7 years','REVIEW','APPROVED',array['legal:approved'],now()),
('c1500000-0000-0000-0000-000000000002','c1000000-0000-0000-0000-000000000001','c1100000-0000-0000-0000-000000000002','other-v1',1,'OTHER','CA',null,'REVIEW','SYNTHETIC','{}',null);

select is(has_table_privilege('authenticated','public.data_use_policy_rules','SELECT'),false,'data-use rules deny direct authenticated reads');
select is(has_table_privilege('authenticated','public.retention_policies','SELECT'),false,'retention policies deny direct authenticated reads');
select is(has_function_privilege('authenticated','public.list_data_use_policy_rules()','EXECUTE'),true,'data-use inspection RPC is callable');
select is(has_function_privilege('authenticated','public.list_retention_policies()','EXECUTE'),true,'retention inspection RPC is callable');
select is(has_function_privilege('anon','public.list_data_use_policy_rules()','EXECUTE'),false,'anonymous cannot inspect data-use rules');
select is(has_function_privilege('anon','public.list_retention_policies()','EXECUTE'),false,'anonymous cannot inspect retention policies');

set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub','c1900000-0000-0000-0000-000000000001','role','authenticated','app_metadata',json_build_object('active_tenant_id','c1000000-0000-0000-0000-000000000001'),'aal','aal2')::text,true);
select is((select count(*) from public.list_data_use_policy_rules()),1::bigint,'policy admin sees active-agency data-use rules only');
select is((select policy_version from public.list_data_use_policy_rules()),'data-use-v1','data-use response preserves exact policy version');
select is((select count(*) from public.list_retention_policies()),1::bigint,'policy admin sees active-agency retention policies only');
select is((select retention_interval from public.list_retention_policies()),'7 years','retention interval is returned as stable text');

select set_config('request.jwt.claims',json_build_object('sub','c1900000-0000-0000-0000-000000000002','role','authenticated','app_metadata',json_build_object('active_tenant_id','c1000000-0000-0000-0000-000000000001'),'aal','aal2')::text,true);
select is((select count(*) from public.list_retention_policies()),1::bigint,'privacy admin may inspect retention policies');
select throws_ok($$select public.list_data_use_policy_rules()$$,'P0002','POLICY_INSPECTION_SCOPE_NOT_FOUND','privacy-only admin cannot inspect data-use rules');

select set_config('request.jwt.claims',json_build_object('sub','c1900000-0000-0000-0000-000000000003','role','authenticated','app_metadata',json_build_object('active_tenant_id','c1000000-0000-0000-0000-000000000001'),'aal','aal2')::text,true);
select throws_ok($$select public.list_retention_policies()$$,'P0002','POLICY_INSPECTION_SCOPE_NOT_FOUND','ordinary agent cannot inspect retention policies');

select set_config('request.jwt.claims',json_build_object('sub','c1900000-0000-0000-0000-000000000001','role','authenticated','app_metadata',json_build_object('active_tenant_id','c1000000-0000-0000-0000-000000000001'),'aal','aal1')::text,true);
select throws_ok($$select public.list_data_use_policy_rules()$$,'P0002','POLICY_INSPECTION_SCOPE_NOT_FOUND','AAL1 cannot inspect policy configuration');

reset role;
insert into public.agency_users (agency_user_id,tenant_id,agency_id,workforce_identity_id,status) values
('c1200000-0000-0000-0000-000000000004','c1000000-0000-0000-0000-000000000001','c1100000-0000-0000-0000-000000000002','c1900000-0000-0000-0000-000000000001','ACTIVE');
insert into public.roles (role_id,tenant_id,agency_id,name,permissions) values
('c1300000-0000-0000-0000-000000000004','c1000000-0000-0000-0000-000000000001','c1100000-0000-0000-0000-000000000002','other-policy-admin',array['POLICY_ADMIN']::public.permission_code[]);
insert into public.agency_user_roles values ('c1200000-0000-0000-0000-000000000004','c1300000-0000-0000-0000-000000000004');
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub','c1900000-0000-0000-0000-000000000001','role','authenticated','app_metadata',json_build_object('active_tenant_id','c1000000-0000-0000-0000-000000000001'),'aal','aal2')::text,true);
select throws_ok($$select public.list_data_use_policy_rules()$$,'P0002','POLICY_INSPECTION_SCOPE_NOT_FOUND','ambiguous eligible agency scope fails closed');

select * from finish();
rollback;
