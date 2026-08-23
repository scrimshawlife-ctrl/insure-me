begin;

select plan(15);

insert into public.agencies (agency_id,tenant_id,legal_name,display_name)
values ('c1000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','Carrier Submission Agency','Carrier Submission');

insert into public.tenant_configurations (tenant_configuration_id,tenant_id,agency_id,version,status)
values ('c2000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001',1,'ACTIVE');

insert into public.prospects (prospect_id,tenant_id,agency_id)
values ('c3000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001');

insert into public.quote_cases (
 quote_case_id,tenant_id,agency_id,tenant_configuration_id,tenant_configuration_version,
 jurisdiction,product_line,source_channel,state,prospect_id
) values (
 'c4000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001',
 'c2000000-0000-0000-0000-000000000001',1,'CA','PRIVATE_PASSENGER_AUTO','TEST','AGENT_REVIEW','c3000000-0000-0000-0000-000000000001'
);

insert into public.carriers (carrier_id,tenant_id,agency_id,legal_name,display_name)
values
 ('c5000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','Synthetic Carrier A','Carrier A'),
 ('c5000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','Synthetic Carrier B','Carrier B');

insert into public.carrier_programs (
 carrier_program_id,tenant_id,agency_id,carrier_id,program_code,version,jurisdictions,product_lines,
 adapter_id,adapter_version,handoff_mode,required_field_policy_version,rating_input_policy_version,
 response_mapping_version,notice_ownership_policy_version,certification_state
) values
 ('c6000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000001','A',1,array['CA'],array['PRIVATE_PASSENGER_AUTO'],'synthetic-carrier-adapter-a','synthetic-carrier-v1','STUB','required-a-v1','mapping-a-v1','response-a-v1','notice-a-v1','SYNTHETIC'),
 ('c6000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000002','B',1,array['CA'],array['PRIVATE_PASSENGER_AUTO'],'synthetic-carrier-adapter-b','synthetic-carrier-v1','STUB','required-b-v1','mapping-b-v1','response-b-v1','notice-b-v1','SYNTHETIC');

insert into public.carrier_program_rating_rules (
 tenant_id,agency_id,carrier_program_id,carrier_program_version,mapping_version,source_observation_type,input_key,required
) values
 ('c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001',1,'mapping-a-v1','LICENSE_STATUS','mvr.licenseStatus',true),
 ('c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001',1,'mapping-a-v1','CLAIM_COUNT','claims.claimCount',true),
 ('c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000002',1,'mapping-b-v1','MOVING_VIOLATION_COUNT','mvr.movingViolationCount',true),
 ('c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000002',1,'mapping-b-v1','VEHICLE_SEVERE_DAMAGE_INDICATOR','vehicle.severeDamageIndicator',true);

select throws_ok(
 $$select * from public.create_carrier_submission('c4000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001','idem-a','hash-a')$$,
 '42501','CARRIER_HANDOFF_BLOCKED:MISSING_RATING_INPUT','submission blocks before required RatingInputs exist'
);

insert into public.underwriting_observations (
 observation_id,tenant_id,agency_id,quote_case_id,observation_type,normalized_value,
 data_use_classification,data_use_policy_version,freshness_state,conflict_state
) values
 ('c7000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','LICENSE_STATUS','"VALID"'::jsonb,'RATING_SUBMISSION_ALLOWED','base-v1','CURRENT','NONE'),
 ('c7000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','CLAIM_COUNT','0'::jsonb,'RATING_SUBMISSION_ALLOWED','base-v1','CURRENT','NONE'),
 ('c7000000-0000-0000-0000-000000000003','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','MOVING_VIOLATION_COUNT','0'::jsonb,'RATING_SUBMISSION_ALLOWED','base-v1','CURRENT','NONE'),
 ('c7000000-0000-0000-0000-000000000004','c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','VEHICLE_SEVERE_DAMAGE_INDICATOR','false'::jsonb,'RATING_SUBMISSION_ALLOWED','base-v1','CURRENT','NONE');

select is(public.project_rating_inputs('c4000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001'),2,'program A projects two required inputs');
select is(public.project_rating_inputs('c4000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000002'),2,'program B projects a different two required inputs');

select lives_ok($$select * from public.create_carrier_submission('c4000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001','idem-a','hash-a')$$,'program A submission can be created');
select is((select count(*) from public.carrier_submissions where carrier_program_id='c6000000-0000-0000-0000-000000000001'),1::bigint,'one A submission exists');
select is((select reused from public.create_carrier_submission('c4000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001','idem-a','hash-a')),true,'same carrier idempotency key and hash reuses submission');
select throws_ok($$select * from public.create_carrier_submission('c4000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001','idem-a','different-hash')$$,'23505','IDEMPOTENCY_KEY_REUSE_WITH_DIFFERENT_REQUEST','same carrier idempotency key cannot change request meaning');

select lives_ok($$select public.claim_carrier_submission((select carrier_submission_id from public.carrier_submissions where carrier_program_id='c6000000-0000-0000-0000-000000000001'))$$,'program A submission can be claimed once');
select lives_ok($$select public.settle_carrier_submission(
 (select carrier_submission_id from public.carrier_submissions where carrier_program_id='c6000000-0000-0000-0000-000000000001'),
 'ACCEPTED','{"amount":120,"currency":"USD","termMonths":6}'::jsonb,'{}'::text[],'synthetic:A:idem-a','2026-08-23T00:00:00Z'
)$$,'program A carrier decision settles');
select is((select count(*) from public.carrier_decisions where carrier_program_id='c6000000-0000-0000-0000-000000000001'),1::bigint,'one immutable A carrier decision exists');
select lives_ok($$select public.settle_carrier_submission(
 (select carrier_submission_id from public.carrier_submissions where carrier_program_id='c6000000-0000-0000-0000-000000000001'),
 'ACCEPTED','{"amount":120,"currency":"USD","termMonths":6}'::jsonb,'{}'::text[],'synthetic:A:idem-a','2026-08-23T00:00:00Z'
)$$,'replayed settlement is idempotent');
select is((select count(*) from public.carrier_decisions where carrier_program_id='c6000000-0000-0000-0000-000000000001'),1::bigint,'settlement replay does not duplicate carrier decision');

select lives_ok($$select * from public.create_carrier_submission('c4000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000002','idem-b','hash-b')$$,'same canonical case can create independent program B submission');
select is((select count(*) from public.carrier_submissions where quote_case_id='c4000000-0000-0000-0000-000000000001'),2::bigint,'two carrier programs coexist without canonical case fork');

update public.carrier_programs set kill_switch_enabled=true where carrier_program_id='c6000000-0000-0000-0000-000000000002';
select throws_ok($$select public.select_carrier_program('c4000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000002')$$,'42501','CARRIER_KILL_SWITCHED','carrier kill switch blocks program selection');

select * from finish();
rollback;
