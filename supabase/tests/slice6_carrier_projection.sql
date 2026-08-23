begin;

select plan(10);

insert into public.agencies (agency_id, tenant_id, legal_name, display_name)
values ('b1000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','Synthetic Carrier Agency','Carrier Agency');

insert into public.tenant_configurations (
  tenant_configuration_id, tenant_id, agency_id, version, status
) values ('b2000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001',1,'ACTIVE');

insert into public.prospects (prospect_id, tenant_id, agency_id)
values ('b3000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001');

insert into public.quote_cases (
 quote_case_id, tenant_id, agency_id, tenant_configuration_id, tenant_configuration_version,
 jurisdiction, product_line, source_channel, state, prospect_id
) values (
 'b4000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001',
 'b2000000-0000-0000-0000-000000000001',1,'CA','PRIVATE_PASSENGER_AUTO','TEST','AGENT_REVIEW','b3000000-0000-0000-0000-000000000001'
);

insert into public.underwriting_observations (
 observation_id, tenant_id, agency_id, quote_case_id, observation_type,
 normalized_value, data_use_classification, freshness_state, conflict_state
) values
 ('b5000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','LICENSE_STATUS','"VALID"'::jsonb,'UNCLASSIFIED','CURRENT','NONE'),
 ('b5000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','CLAIM_COUNT','0'::jsonb,'UNCLASSIFIED','CURRENT','NONE'),
 ('b5000000-0000-0000-0000-000000000003','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','MOVING_VIOLATION_COUNT','0'::jsonb,'UNCLASSIFIED','CURRENT','NONE'),
 ('b5000000-0000-0000-0000-000000000004','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','VEHICLE_SEVERE_DAMAGE_INDICATOR','false'::jsonb,'UNCLASSIFIED','CURRENT','NONE'),
 ('b5000000-0000-0000-0000-000000000005','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','PROHIBITED_EXAMPLE','"secret"'::jsonb,'UNCLASSIFIED','CURRENT','NONE');

insert into public.data_use_policy_rules (
 tenant_id, agency_id, policy_version, observation_type,
 collection_allowed, agent_display_allowed, underwriting_allowed, rating_submission_allowed, prohibited
) values
 ('b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','base-rating-v1','LICENSE_STATUS',true,true,true,true,false),
 ('b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','base-rating-v1','CLAIM_COUNT',true,true,true,true,false),
 ('b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','base-rating-v1','MOVING_VIOLATION_COUNT',true,true,true,true,false),
 ('b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','base-rating-v1','VEHICLE_SEVERE_DAMAGE_INDICATOR',true,true,true,true,false),
 ('b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','base-rating-v1','PROHIBITED_EXAMPLE',false,false,false,false,true);

insert into public.carriers (carrier_id, tenant_id, agency_id, legal_name, display_name)
values
 ('b6000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','Synthetic Carrier A','Carrier A'),
 ('b6000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','Synthetic Carrier B','Carrier B');

insert into public.carrier_programs (
 carrier_program_id, tenant_id, agency_id, carrier_id, program_code, version,
 jurisdictions, product_lines, adapter_id, adapter_version, handoff_mode,
 required_field_policy_version, rating_input_policy_version, response_mapping_version,
 notice_ownership_policy_version, certification_state
) values
 ('b7000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b6000000-0000-0000-0000-000000000001','CA-AUTO-A',1,array['CA'],array['PRIVATE_PASSENGER_AUTO'],'synthetic-carrier-adapter-a','synthetic-carrier-v1','STUB','required-a-v1','mapping-a-v1','response-a-v1','notice-a-v1','SYNTHETIC'),
 ('b7000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b6000000-0000-0000-0000-000000000002','CA-AUTO-B',1,array['CA'],array['PRIVATE_PASSENGER_AUTO'],'synthetic-carrier-adapter-b','synthetic-carrier-v1','STUB','required-b-v1','mapping-b-v1','response-b-v1','notice-b-v1','SYNTHETIC');

insert into public.carrier_program_rating_rules (
 tenant_id, agency_id, carrier_program_id, carrier_program_version, mapping_version,
 source_observation_type, input_key, required
) values
 ('b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b7000000-0000-0000-0000-000000000001',1,'mapping-a-v1','LICENSE_STATUS','mvr.licenseStatus',true),
 ('b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b7000000-0000-0000-0000-000000000001',1,'mapping-a-v1','CLAIM_COUNT','claims.claimCount',true),
 ('b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b7000000-0000-0000-0000-000000000002',1,'mapping-b-v1','MOVING_VIOLATION_COUNT','mvr.movingViolationCount',true),
 ('b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b7000000-0000-0000-0000-000000000002',1,'mapping-b-v1','VEHICLE_SEVERE_DAMAGE_INDICATOR','vehicle.severeDamageIndicator',true),
 ('b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b7000000-0000-0000-0000-000000000001',1,'mapping-a-v1','PROHIBITED_EXAMPLE','forbidden.secret',false);

select is(public.project_rating_inputs('b4000000-0000-0000-0000-000000000001','b7000000-0000-0000-0000-000000000001'),0,'unclassified observations cannot become RatingInputs');
select is(public.apply_data_use_policy('b4000000-0000-0000-0000-000000000001','base-rating-v1'),5,'data-use policy evaluates every known observation');
select is((select data_use_classification from public.underwriting_observations where observation_type='PROHIBITED_EXAMPLE'),'PROHIBITED','prohibited observation is explicitly classified');
select is(public.project_rating_inputs('b4000000-0000-0000-0000-000000000001','b7000000-0000-0000-0000-000000000001'),2,'carrier A projects only its two allowed observations');
select is(public.project_rating_inputs('b4000000-0000-0000-0000-000000000001','b7000000-0000-0000-0000-000000000002'),2,'carrier B projects a different allowed observation set');
select is((select count(*) from public.rating_inputs where carrier_program_id='b7000000-0000-0000-0000-000000000001'),2::bigint,'carrier A has exactly two RatingInputs');
select is((select count(*) from public.rating_inputs where carrier_program_id='b7000000-0000-0000-0000-000000000002'),2::bigint,'carrier B has exactly two RatingInputs');
select is((select count(*) from public.rating_inputs where input_key='forbidden.secret'),0::bigint,'prohibited observation cannot bypass RatingInput allowlist');
select ok(exists(select 1 from public.rating_inputs where carrier_program_id='b7000000-0000-0000-0000-000000000001' and input_key='mvr.licenseStatus'),'carrier A mapping remains program-specific');
select ok(exists(select 1 from public.rating_inputs where carrier_program_id='b7000000-0000-0000-0000-000000000002' and input_key='vehicle.severeDamageIndicator'),'carrier B mapping remains program-specific');

select * from finish();
rollback;
