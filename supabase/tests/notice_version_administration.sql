begin;
select plan(28);

insert into public.agencies (agency_id,tenant_id,legal_name,display_name) values
('b1100000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','Notice Admin Agency','Notice Admin');
insert into public.agency_users (agency_user_id,tenant_id,agency_id,workforce_identity_id,status) values
('b1200000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-000000000001','b1900000-0000-0000-0000-000000000009','ACTIVE'),
('b1200000-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-000000000001','b1900000-0000-0000-0000-000000000008','ACTIVE');
insert into public.roles (role_id,tenant_id,agency_id,name,permissions) values
('b1300000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-000000000001','policy-admin',array['POLICY_ADMIN']::public.permission_code[]),
('b1300000-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-000000000001','agent',array['CASE_READ']::public.permission_code[]);
insert into public.agency_user_roles values
('b1200000-0000-0000-0000-000000000001','b1300000-0000-0000-0000-000000000001'),
('b1200000-0000-0000-0000-000000000002','b1300000-0000-0000-0000-000000000002');

select has_table('public','notice_definition_events','notice lifecycle event table exists');
select is((select relrowsecurity from pg_class where oid='public.notice_definition_events'::regclass),true,'lifecycle events have RLS');
select is(has_table_privilege('authenticated','public.notice_definitions','INSERT'),false,'authenticated cannot directly create notice versions');
select is(has_table_privilege('authenticated','public.notice_definitions','UPDATE'),false,'authenticated cannot directly transition notices');
select is(has_table_privilege('authenticated','public.notice_definition_events','SELECT'),false,'events are not directly exposed');
select is(has_function_privilege('authenticated','public.create_notice_definition_version(text,public.notice_category,text,text,boolean,text,text[],uuid)','EXECUTE'),true,'checked create RPC is callable');

set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub','b1900000-0000-0000-0000-000000000009','role','authenticated','app_metadata',json_build_object('active_tenant_id','b1000000-0000-0000-0000-000000000001'),'aal','aal2')::text,true);
create temporary table created_notice as select * from public.create_notice_definition_version(
  'privacy-notice','INSURANCE_PRIVACY','Privacy notice',
  'Canonical privacy body',true,'draft:legal-review',array['NEW_LEGAL_COPY'],'b1400000-0000-4000-8000-000000000001');
select is((select version from created_notice),1,'server assigns first version');
select is((select status::text from created_notice),'DRAFT','new version is draft');
select is((select content_hash from created_notice),encode(extensions.digest(convert_to('Canonical privacy body','UTF8'),'sha256'),'hex'),'server hashes exact body');
select is((select count(*) from public.create_notice_definition_version('privacy-notice','INSURANCE_PRIVACY','Privacy notice','Canonical privacy body',true,'draft:legal-review',array['NEW_LEGAL_COPY'],'b1400000-0000-4000-8000-000000000001')),1::bigint,'create replay is idempotent');
select throws_ok($$select public.create_notice_definition_version('privacy-notice','INSURANCE_PRIVACY','Changed title','Canonical privacy body',true,'draft:legal-review',array['NEW_LEGAL_COPY'],'b1400000-0000-4000-8000-000000000001')$$,'22023','NOTICE_ADMIN_IDEMPOTENCY_MISMATCH','create replay cannot change content');
create temporary table approved_notice as select * from public.approve_notice_definition_version(
  (select notice_definition_id from created_notice),'legal:approval-001',now(),array['LEGAL_APPROVED'],'b1400000-0000-4000-8000-000000000002');
select is((select status::text from approved_notice),'APPROVED','approval activates approved lifecycle');
select is((select approval_ref from approved_notice),'legal:approval-001','approval evidence is recorded');
select is((select count(*) from public.approve_notice_definition_version((select notice_definition_id from created_notice),'legal:approval-001',now(),array['LEGAL_APPROVED'],'b1400000-0000-4000-8000-000000000002')),1::bigint,'approval replay is idempotent');
select throws_ok($$update public.notice_definitions set body_markdown='forged' where notice_definition_id=(select notice_definition_id from created_notice)$$,'42501',null,'direct rewrite is denied');
select is((select count(*) from public.list_notice_definition_versions()),1::bigint,'authorized admin lists exact versions');
create temporary table second_notice as select * from public.create_notice_definition_version(
  'privacy-notice','INSURANCE_PRIVACY','Privacy notice v2',
  'Canonical privacy body v2',true,'draft:legal-review-2',array['NEW_LEGAL_COPY'],'b1400000-0000-4000-8000-000000000003');
select is((select version from second_notice),2,'next version is allocated atomically');
create temporary table retired_notice as select * from public.retire_notice_definition_version(
  (select notice_definition_id from created_notice),'retirement:superceded',array['SUPERSEDED'],'b1400000-0000-4000-8000-000000000004');
select is((select status::text from retired_notice),'RETIRED','approved version can be retired');
select isnt((select retired_at from retired_notice),null::timestamptz,'retirement time is recorded');
select throws_ok($$select public.retire_notice_definition_version((select notice_definition_id from second_notice),'retirement:invalid',array['INVALID'],'b1400000-0000-4000-8000-000000000005')$$,'22023','NOTICE_RETIREMENT_STATE_INVALID','draft cannot be retired');
reset role;
select is((select count(*) from public.notice_definition_events),4::bigint,'each successful lifecycle transition has one event');
select is((select count(*) from public.audit_events where event_type like 'NOTICE_VERSION_%'),4::bigint,'each lifecycle transition is audited');
select throws_ok($$delete from public.notice_definitions where notice_definition_id=(select notice_definition_id from created_notice)$$,'22023','NOTICE_ADMINISTRATION_IMMUTABLE','notice history cannot be deleted');
select throws_ok($$update public.notice_definition_events set evidence_ref='forged'$$,'22023','NOTICE_ADMINISTRATION_IMMUTABLE','lifecycle evidence cannot be rewritten');
select throws_ok($$update public.notice_definitions set approval_ref='forged' where notice_definition_id=(select notice_definition_id from created_notice)$$,'22023','NOTICE_APPROVAL_EVIDENCE_IMMUTABLE','retirement cannot rewrite prior approval evidence');

insert into public.agencies (agency_id,tenant_id,legal_name,display_name) values
('b1100000-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000001','Second Notice Agency','Second Notice');
insert into public.agency_users (agency_user_id,tenant_id,agency_id,workforce_identity_id,status) values
('b1200000-0000-0000-0000-000000000003','b1000000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-000000000002','b1900000-0000-0000-0000-000000000009','ACTIVE');
insert into public.roles (role_id,tenant_id,agency_id,name,permissions) values
('b1300000-0000-0000-0000-000000000003','b1000000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-000000000002','second-policy-admin',array['POLICY_ADMIN']::public.permission_code[]);
insert into public.agency_user_roles values
('b1200000-0000-0000-0000-000000000003','b1300000-0000-0000-0000-000000000003');
set local role authenticated;
select throws_ok($$select public.list_notice_definition_versions()$$,'P0002','NOTICE_ADMIN_SCOPE_NOT_FOUND','ambiguous active agency context fails closed');
reset role;

set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub','b1900000-0000-0000-0000-000000000008','role','authenticated','app_metadata',json_build_object('active_tenant_id','b1000000-0000-0000-0000-000000000001'),'aal','aal2')::text,true);
select throws_ok($$select public.list_notice_definition_versions()$$,'P0002','NOTICE_ADMIN_SCOPE_NOT_FOUND','non-policy user cannot list notices');
select throws_ok($$select public.create_notice_definition_version('blocked','INSURANCE_PRIVACY','Blocked','Body',false,'blocked:evidence',array['BLOCKED'],'b1400000-0000-4000-8000-000000000006')$$,'P0002','NOTICE_ADMIN_SCOPE_NOT_FOUND','non-policy user cannot create notices');

select * from finish();
rollback;
