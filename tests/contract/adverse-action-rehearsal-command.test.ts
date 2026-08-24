import { createHmac } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { createClient } from '@supabase/supabase-js';
import { describe, expect, it } from 'vitest';

import { createAdverseActionCase, recordAdverseActionHandoff } from '@/src/application/compliance/adverse-action';
import { deliverAdverseActionNotice } from '@/src/application/compliance/adverse-action-notice-delivery';
import type { Database } from '@/src/infrastructure/supabase/database.types';

type Primitive = string | number | boolean | null;
type Report = {
  schemaVersion: 'adverse-action-rehearsal-report-v1';
  contractVersions: Record<string, Primitive>;
  syntheticFixture: Record<string, Primitive>;
  workflowStates: Record<string, Primitive>;
  aggregateCounts: Record<string, Primitive>;
  negativePaths: Record<string, Primitive>;
  timing: Record<string, Primitive>;
  errorCode: string | null;
  verdict: 'PASSED' | 'FAILED';
};

const rehearsalDescribe = process.env.ADVERSE_ACTION_REHEARSAL_ENABLED === '1' ? describe : describe.skip;
const reportPath = process.env.ADVERSE_ACTION_REHEARSAL_REPORT_PATH ?? 'artifacts/adverse-action-rehearsal-report-v1.json';
const allowedTop = ['aggregateCounts', 'contractVersions', 'errorCode', 'negativePaths', 'schemaVersion', 'syntheticFixture', 'timing', 'verdict', 'workflowStates'];
const piiPattern = /Avery|example\.invalid|555|Main|Sacramento|95814|payload|token|secret|lookup|cipher|encrypted|firstName|lastName|dateOfBirth|email|phone|address/i;
const env = {
  DEPLOYMENT_STAGE: 'synthetic',
  NOTICE_DELIVERY_ADAPTER_ID: 'synthetic-notice-delivery-v1',
  NOTICE_DELIVERY_ADAPTER_VERSION: '1.0.0',
  NOTICE_DELIVERY_POLICY_VERSION: 'synthetic-notice-delivery-policy-v1',
};
const ids = {
  tenant: '90700000-0000-4000-8000-000000000001', agency: '90700000-0000-4000-8000-000000000002', config: '90700000-0000-4000-8000-000000000003', actor: '90700000-0000-4000-8000-000000000004', user: '90700000-0000-4000-8000-000000000005', role: '90700000-0000-4000-8000-000000000006', person: '90700000-0000-4000-8000-000000000007', prospect: '90700000-0000-4000-8000-000000000008', case: '90700000-0000-4000-8000-000000000009', binding: '90700000-0000-4000-8000-000000000010', purpose: '90700000-0000-4000-8000-000000000011', request: '90700000-0000-4000-8000-000000000012', report: '90700000-0000-4000-8000-000000000013', carrier: '90700000-0000-4000-8000-000000000014', program: '90700000-0000-4000-8000-000000000015', submission: '90700000-0000-4000-8000-000000000016', decision: '90700000-0000-4000-8000-000000000017', notice: '90700000-0000-4000-8000-000000000018', otherTenant: '90700000-0000-4000-8000-000000000101', otherAgency: '90700000-0000-4000-8000-000000000102', otherConfig: '90700000-0000-4000-8000-000000000103', otherPerson: '90700000-0000-4000-8000-000000000104', otherProspect: '90700000-0000-4000-8000-000000000105', otherCase: '90700000-0000-4000-8000-000000000106', otherCarrier: '90700000-0000-4000-8000-000000000107', otherProgram: '90700000-0000-4000-8000-000000000108', otherSubmission: '90700000-0000-4000-8000-000000000109', otherDecision: '90700000-0000-4000-8000-000000000110', otherNotice: '90700000-0000-4000-8000-000000000111',
};

function b64url(input: Buffer | string) { return Buffer.from(input).toString('base64url'); }
function jwt() {
  const secret = process.env.SUPABASE_JWT_SECRET ?? 'super-secret-jwt-token-with-at-least-32-characters-long';
  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = b64url(JSON.stringify({ iss: 'supabase', ref: 'insure-me', role: 'authenticated', sub: ids.actor, aal: 'aal2', app_metadata: { active_tenant_id: ids.tenant }, iat: 1600000000, exp: 1915360000 }));
  const sig = createHmac('sha256', secret).update(`${header}.${payload}`).digest('base64url');
  return `${header}.${payload}.${sig}`;
}
function runPsql(dbUrl: string, sql: string, vars: Record<string, string> = {}) {
  const dir = mkdtempSync(`${process.env.JCODE_SCRATCH_DIR ?? '/tmp'}/t907-`);
  const sqlPath = join(dir, 'statement.sql');
  writeFileSync(sqlPath, sql);
  return execFileSync('psql', [dbUrl, ...Object.entries(vars).flatMap(([k, v]) => ['--set', `${k}=${v}`]), '--file', sqlPath], { encoding: 'utf8', stdio: 'pipe' }).trim();
}
async function denied(label: string, fn: () => Promise<unknown>) { try { await fn(); } catch { return true; } throw new Error(label); }
async function writeReport(report: Report) {
  await mkdir(reportPath.split('/').slice(0, -1).join('/') || '.', { recursive: true });
  expect(Object.keys(report).sort()).toEqual(allowedTop);
  const serialized = JSON.stringify(report, null, 2);
  expect(serialized).not.toMatch(piiPattern);
  await writeFile(reportPath, `${serialized}\n`);
}
function seed(dbUrl: string) {
  runPsql(dbUrl, String.raw`\set ON_ERROR_STOP on
insert into public.agencies (agency_id, tenant_id, legal_name, display_name) values
(:'agency'::uuid, :'tenant'::uuid, 'Synthetic Adverse Action Agency', 'Synthetic Adverse Action'),
(:'otherAgency'::uuid, :'otherTenant'::uuid, 'Synthetic Other Agency', 'Synthetic Other') on conflict do nothing;
insert into public.agency_users (agency_user_id,tenant_id,agency_id,workforce_identity_id,status) values (:'user'::uuid,:'tenant'::uuid,:'agency'::uuid,:'actor'::uuid,'ACTIVE') on conflict do nothing;
insert into public.roles (role_id,tenant_id,agency_id,name,permissions) values (:'role'::uuid,:'tenant'::uuid,:'agency'::uuid,'policy-admin',array['POLICY_ADMIN']::public.permission_code[]) on conflict do nothing;
insert into public.agency_user_roles values (:'user'::uuid,:'role'::uuid) on conflict do nothing;
insert into public.tenant_configurations (tenant_configuration_id,tenant_id,agency_id,version,status,effective_at) values (:'config'::uuid,:'tenant'::uuid,:'agency'::uuid,1,'ACTIVE',now()),(:'otherConfig'::uuid,:'otherTenant'::uuid,:'otherAgency'::uuid,1,'ACTIVE',now()) on conflict do nothing;
insert into public.person_private_profiles (person_id,tenant_id,agency_id,encrypted_payload,encryption_algorithm,key_version) values (:'person'::uuid,:'tenant'::uuid,:'agency'::uuid,decode('00','hex'),'AES-256-GCM','synthetic-key'),(:'otherPerson'::uuid,:'otherTenant'::uuid,:'otherAgency'::uuid,decode('00','hex'),'AES-256-GCM','synthetic-key') on conflict do nothing;
insert into public.prospects (prospect_id,tenant_id,agency_id,person_id,source_classification) values (:'prospect'::uuid,:'tenant'::uuid,:'agency'::uuid,:'person'::uuid,'SYNTHETIC'),(:'otherProspect'::uuid,:'otherTenant'::uuid,:'otherAgency'::uuid,:'otherPerson'::uuid,'SYNTHETIC') on conflict do nothing;
insert into public.quote_cases (quote_case_id,tenant_id,agency_id,tenant_configuration_id,tenant_configuration_version,jurisdiction,product_line,source_channel,state,prospect_id) values (:'case'::uuid,:'tenant'::uuid,:'agency'::uuid,:'config'::uuid,1,'CA','PRIVATE_PASSENGER_AUTO','WEB','CARRIER_RESPONSE',:'prospect'::uuid),(:'otherCase'::uuid,:'otherTenant'::uuid,:'otherAgency'::uuid,:'otherConfig'::uuid,1,'CA','PRIVATE_PASSENGER_AUTO','WEB','CARRIER_RESPONSE',:'otherProspect'::uuid) on conflict do nothing;
insert into public.provider_bindings (provider_binding_id,tenant_id,agency_id,capability,adapter_id,adapter_version,jurisdiction,product_line,purpose_code) values (:'binding'::uuid,:'tenant'::uuid,:'agency'::uuid,'MVR','stub-mvr','1','CA','PRIVATE_PASSENGER_AUTO','INSURANCE_UNDERWRITING') on conflict do nothing;
insert into public.permissible_purpose_decisions (decision_id,tenant_id,quote_case_id,tenant_configuration_version,jurisdiction,capability,purpose_code,policy_version,outcome,reason_codes) values (:'purpose'::uuid,:'tenant'::uuid,:'case'::uuid,1,'CA','MVR','INSURANCE_UNDERWRITING','synthetic-purpose-v1','ALLOW',array['SYNTHETIC']) on conflict do nothing;
insert into public.external_requests (external_request_id,tenant_id,agency_id,quote_case_id,tenant_configuration_version,provider_binding_id,capability,permissible_purpose_decision_id,idempotency_key,request_hash,status,completed_at) values (:'request'::uuid,:'tenant'::uuid,:'agency'::uuid,:'case'::uuid,1,:'binding'::uuid,'MVR',:'purpose'::uuid,'provider-key-t907',repeat('1',64),'SUCCEEDED',now()) on conflict do nothing;
insert into public.external_reports (external_report_id,tenant_id,agency_id,quote_case_id,external_request_id,provider_id,provider_product_id,status,retrieved_at,normalized_version) values (:'report'::uuid,:'tenant'::uuid,:'agency'::uuid,:'case'::uuid,:'request'::uuid,'synthetic-cra','synthetic-mvr','SUCCESS',now(),'v1') on conflict do nothing;
insert into public.carriers (carrier_id,tenant_id,agency_id,legal_name,display_name) values (:'carrier'::uuid,:'tenant'::uuid,:'agency'::uuid,'Synthetic Carrier','Synthetic Carrier'),(:'otherCarrier'::uuid,:'otherTenant'::uuid,:'otherAgency'::uuid,'Synthetic Other Carrier','Synthetic Other Carrier') on conflict do nothing;
insert into public.carrier_programs (carrier_program_id,tenant_id,agency_id,carrier_id,program_code,version,jurisdictions,product_lines,adapter_id,adapter_version,handoff_mode,required_field_policy_version,rating_input_policy_version,response_mapping_version,notice_ownership_policy_version,certification_state) values (:'program'::uuid,:'tenant'::uuid,:'agency'::uuid,:'carrier'::uuid,'SYNTH-AA',1,array['CA'],array['PRIVATE_PASSENGER_AUTO'],'stub-carrier','1','STUB','required-v1','rating-v1','response-v1','ownership-v1','SYNTHETIC'),(:'otherProgram'::uuid,:'otherTenant'::uuid,:'otherAgency'::uuid,:'otherCarrier'::uuid,'SYNTH-OTHER',1,array['CA'],array['PRIVATE_PASSENGER_AUTO'],'stub-carrier','1','STUB','required-v1','rating-v1','response-v1','ownership-v1','SYNTHETIC') on conflict do nothing;
insert into public.carrier_submissions (carrier_submission_id,tenant_id,agency_id,quote_case_id,tenant_configuration_version,carrier_id,carrier_program_id,carrier_program_version,adapter_id,handoff_mode,mapping_version,rating_input_ids,idempotency_key,request_hash,status,completed_at) values (:'submission'::uuid,:'tenant'::uuid,:'agency'::uuid,:'case'::uuid,1,:'carrier'::uuid,:'program'::uuid,1,'stub-carrier','STUB','mapping-v1','{}','carrier-key-t907',repeat('2',64),'SUCCEEDED',now()),(:'otherSubmission'::uuid,:'otherTenant'::uuid,:'otherAgency'::uuid,:'otherCase'::uuid,1,:'otherCarrier'::uuid,:'otherProgram'::uuid,1,'stub-carrier','STUB','mapping-v1','{}','other-carrier-key-t907',repeat('3',64),'SUCCEEDED',now()) on conflict do nothing;
insert into public.carrier_decisions (carrier_decision_id,tenant_id,agency_id,carrier_submission_id,carrier_program_id,decision_status,reason_codes,response_mapping_version,received_at) values (:'decision'::uuid,:'tenant'::uuid,:'agency'::uuid,:'submission'::uuid,:'program'::uuid,'DECLINED',array['SYNTHETIC_UNFAVORABLE'],'response-v1',now()),(:'otherDecision'::uuid,:'otherTenant'::uuid,:'otherAgency'::uuid,:'otherSubmission'::uuid,:'otherProgram'::uuid,'DECLINED',array['SYNTHETIC_UNFAVORABLE'],'response-v1',now()) on conflict do nothing;
insert into public.notice_definitions (notice_definition_id,tenant_id,agency_id,notice_key,version,status,category,jurisdiction,product_line,title,body_markdown,content_hash,effective_at) values (:'notice'::uuid,:'tenant'::uuid,:'agency'::uuid,'adverse-action',1,'SYNTHETIC','ADVERSE_ACTION','CA','PRIVATE_PASSENGER_AUTO','Synthetic adverse action notice','Synthetic only.',repeat('a',64),now()),(:'otherNotice'::uuid,:'otherTenant'::uuid,:'otherAgency'::uuid,'adverse-action',1,'APPROVED','ADVERSE_ACTION','CA','PRIVATE_PASSENGER_AUTO','Synthetic other notice','Synthetic only.',repeat('b',64),now()) on conflict do nothing;
`, ids);
}
function count(dbUrl: string, sql: string) { return Number(runPsql(dbUrl, `\\set ON_ERROR_STOP on\n\\pset tuples_only on\n\\pset format unaligned\n${sql}`, ids).match(/\d+$/)?.[0] ?? 0); }

rehearsalDescribe('T907 adverse-action disposable Supabase rehearsal', () => {
  it('uses production adverse-action services/RPCs with exact PII-free evidence contract', async () => {
    process.env.NEXT_PUBLIC_SUPABASE_URL ??= 'http://127.0.0.1:54321';
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??= 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imluc3VyZS1tZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjAwMDAwMDAwLCJleHAiOjE5MTUzNjAwMDB9.2OH7gx7OvD7B2mOeUf34VjsZoNu6AqDoNld4UtKDgWs';
    const dbUrl = process.env.SUPABASE_DB_URL;
    if (!dbUrl) throw new Error('SUPABASE_DB_URL_MISSING');
    const started = Date.now();
    const report: Report = { schemaVersion: 'adverse-action-rehearsal-report-v1', contractVersions: { acceptance: 'A-048', fixture: 'F018', ownership: 'ownership-v1', noticeDelivery: env.NOTICE_DELIVERY_POLICY_VERSION }, syntheticFixture: { fixture: 'T907/F018', tenantCount: 2, usesRealServices: true }, workflowStates: {}, aggregateCounts: {}, negativePaths: {}, timing: { startedEpochMs: started, durationMs: 0 }, errorCode: null, verdict: 'FAILED' };
    try {
      seed(dbUrl);
      const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
      const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
      if (!supabaseUrl || !supabaseKey) throw new Error('SUPABASE_CLIENT_ENV_MISSING');
      const client = createClient<Database>(supabaseUrl, supabaseKey, { auth: { persistSession: false, autoRefreshToken: false }, global: { headers: { Authorization: `Bearer ${jwt()}` } } });
      const caseOne = await createAdverseActionCase(client, { quoteCaseId: ids.case, carrierDecisionId: ids.decision, ownerType: 'CARRIER', ownerRef: 'carrier-owner:synthetic', determinationAuthorityRef: 'authority:responsible-party', determinationEvidenceRef: 'evidence:determination', reasonCodes: ['RESPONSIBLE_PARTY_DETERMINED'], reportSources: [{ externalReportId: ids.report, craIdentityRef: 'cra:synthetic', disputeRouteRef: 'dispute:synthetic', contributionBasisCode: 'CONTRIBUTED_PARTLY' }], idempotencyKey: '90700000-0000-4000-8000-000000000201' });
      report.workflowStates.caseRecorded = caseOne.status === 'NOTICE_INPUTS_READY' && caseOne.ownerType === 'CARRIER' && caseOne.ownershipPolicyVersion === 'ownership-v1';
      report.negativePaths.crossTenantCaseDenied = await denied('cross_tenant_case', () => createAdverseActionCase(client, { quoteCaseId: ids.case, carrierDecisionId: ids.otherDecision, ownerType: 'CARRIER', ownerRef: 'carrier-owner:synthetic', determinationAuthorityRef: 'authority:responsible-party', determinationEvidenceRef: 'evidence:cross', reasonCodes: ['RESPONSIBLE_PARTY_DETERMINED'], reportSources: [{ externalReportId: ids.report, craIdentityRef: 'cra:synthetic', disputeRouteRef: 'dispute:synthetic', contributionBasisCode: 'CONTRIBUTED_PARTLY' }], idempotencyKey: '90700000-0000-4000-8000-000000000202' }));
      report.negativePaths.missingReportDenied = await denied('missing_report', () => createAdverseActionCase(client, { quoteCaseId: ids.case, carrierDecisionId: ids.decision, ownerType: 'CARRIER', ownerRef: 'carrier-owner:synthetic', determinationAuthorityRef: 'authority:responsible-party', determinationEvidenceRef: 'evidence:missing-report', reasonCodes: ['RESPONSIBLE_PARTY_DETERMINED'], reportSources: [{ externalReportId: ids.otherNotice, craIdentityRef: 'cra:synthetic', disputeRouteRef: 'dispute:synthetic', contributionBasisCode: 'CONTRIBUTED_PARTLY' }], idempotencyKey: '90700000-0000-4000-8000-000000000203' }));
      report.negativePaths.determinationReplayDenied = await denied('determination_replay', () => createAdverseActionCase(client, { quoteCaseId: ids.case, carrierDecisionId: ids.decision, ownerType: 'AGENCY', ownerRef: 'agency-owner:changed', determinationAuthorityRef: 'authority:responsible-party', determinationEvidenceRef: 'evidence:changed', reasonCodes: ['CHANGED'], reportSources: [{ externalReportId: ids.report, craIdentityRef: 'cra:synthetic', disputeRouteRef: 'dispute:synthetic', contributionBasisCode: 'CONTRIBUTED_PARTLY' }], idempotencyKey: '90700000-0000-4000-8000-000000000201' }));
      report.negativePaths.deliveryBeforeHandoffDenied = await denied('delivery_before_handoff', () => deliverAdverseActionNotice(client, { adverseActionCaseId: caseOne.adverseActionCaseId, noticeDefinitionId: ids.notice, noticeContentHash: 'a'.repeat(64), channel: 'EMAIL', recipientRef: 'consumer:opaque', idempotencyKey: '90700000-0000-4000-8000-000000000204' }, env));
      const handed = await recordAdverseActionHandoff(client, { adverseActionCaseId: caseOne.adverseActionCaseId, recipientRef: 'carrier-desk:synthetic', evidenceRef: 'evidence:handoff', reasonCodes: ['OWNER_ACKNOWLEDGED'], idempotencyKey: '90700000-0000-4000-8000-000000000205' });
      report.workflowStates.separateHandoffRecorded = handed.status === 'HANDED_OFF' && Boolean(handed.handedOffAt);
      report.negativePaths.noticeHashMismatchDenied = await denied('notice_hash_mismatch', () => deliverAdverseActionNotice(client, { adverseActionCaseId: caseOne.adverseActionCaseId, noticeDefinitionId: ids.notice, noticeContentHash: 'e'.repeat(64), channel: 'EMAIL', recipientRef: 'consumer:opaque', idempotencyKey: '90700000-0000-4000-8000-000000000206' }, env));
      report.negativePaths.adapterPolicyMismatchDenied = await denied('adapter_policy_mismatch', () => deliverAdverseActionNotice(client, { adverseActionCaseId: caseOne.adverseActionCaseId, noticeDefinitionId: ids.notice, noticeContentHash: 'a'.repeat(64), channel: 'EMAIL', recipientRef: 'consumer:opaque', idempotencyKey: '90700000-0000-4000-8000-000000000207' }, { ...env, NOTICE_DELIVERY_POLICY_VERSION: 'bad-policy-v1' }));
      report.negativePaths.liveSyntheticConfigDenied = await denied('live_synthetic_config', () => deliverAdverseActionNotice(client, { adverseActionCaseId: caseOne.adverseActionCaseId, noticeDefinitionId: ids.notice, noticeContentHash: 'a'.repeat(64), channel: 'EMAIL', recipientRef: 'consumer:opaque', idempotencyKey: '90700000-0000-4000-8000-000000000208' }, { ...env, DEPLOYMENT_STAGE: 'production' }));
      const delivered = await deliverAdverseActionNotice(client, { adverseActionCaseId: caseOne.adverseActionCaseId, noticeDefinitionId: ids.notice, noticeContentHash: 'a'.repeat(64), channel: 'EMAIL', recipientRef: 'consumer:opaque', idempotencyKey: '90700000-0000-4000-8000-000000000209' }, env);
      report.workflowStates.exactNoticeDelivered = delivered.status === 'DELIVERED' && delivered.noticeContentHash === 'a'.repeat(64) && Boolean(delivered.deliveredAt);
      report.workflowStates.exactCarrierReportProvenance = count(dbUrl, "select count(*) from public.adverse_action_cases a join public.adverse_action_report_sources s on s.adverse_action_case_id = a.adverse_action_case_id where a.tenant_id = :'tenant'::uuid and a.quote_case_id = :'case'::uuid and a.carrier_decision_id = :'decision'::uuid and s.external_report_id = :'report'::uuid and s.provider_binding_id = :'binding'::uuid and a.owner_type = 'CARRIER' and a.ownership_policy_version = 'ownership-v1';") === 1;
      report.workflowStates.exactAdapterPolicySnapshotted = count(dbUrl, "select count(*) from public.adverse_action_notice_deliveries where tenant_id = :'tenant'::uuid and adverse_action_case_id = :'caseId'::uuid and notice_definition_id = :'notice'::uuid and notice_version = 1 and notice_content_hash = repeat('a',64) and adapter_id = 'synthetic-notice-delivery-v1' and adapter_version = '1.0.0' and delivery_policy_version = 'synthetic-notice-delivery-policy-v1' and certification_state = 'SYNTHETIC' and status = 'DELIVERED';".replace(':\'caseId\'', `'${caseOne.adverseActionCaseId}'`)) === 1;
      report.negativePaths.deliveryReplayDenied = await denied('delivery_replay', () => deliverAdverseActionNotice(client, { adverseActionCaseId: caseOne.adverseActionCaseId, noticeDefinitionId: ids.notice, noticeContentHash: 'a'.repeat(64), channel: 'POSTAL_MAIL', recipientRef: 'consumer:opaque', idempotencyKey: '90700000-0000-4000-8000-000000000209' }, env));
      report.negativePaths.directMutationDenied = await denied('direct_mutation', async () => {
        type DirectMutation = (relation: string) => {
          update: (values: Record<string, string>) => {
            eq: (column: string, value: string) => Promise<{ error: unknown }>;
          };
        };
        const from = client.from.bind(client) as unknown as DirectMutation;
        const { error } = await from('adverse_action_notice_delivery_attempts')
          .update({ evidence_ref: 'forged' })
          .eq('tenant_id', ids.tenant);
        if (error) throw error;
      });
      report.aggregateCounts.adverseActionCases = count(dbUrl, "select count(*) from public.adverse_action_cases where tenant_id = :'tenant'::uuid;");
      report.aggregateCounts.reportSources = count(dbUrl, "select count(*) from public.adverse_action_report_sources where tenant_id = :'tenant'::uuid;");
      report.aggregateCounts.handoffs = count(dbUrl, "select count(*) from public.adverse_action_events where tenant_id = :'tenant'::uuid and event_type='HANDOFF_RECORDED';");
      report.aggregateCounts.noticeDeliveries = count(dbUrl, "select count(*) from public.adverse_action_notice_deliveries where tenant_id = :'tenant'::uuid and status='DELIVERED';");
      report.aggregateCounts.deliveryAttempts = count(dbUrl, "select count(*) from public.adverse_action_notice_delivery_attempts where tenant_id = :'tenant'::uuid and outcome='DELIVERED';");
      report.aggregateCounts.auditEvents = count(dbUrl, "select count(*) from public.audit_events where tenant_id = :'tenant'::uuid and event_type in ('ADVERSE_ACTION_DETERMINATION_RECORDED','ADVERSE_ACTION_HANDOFF_RECORDED','ADVERSE_ACTION_NOTICE_PREPARED','ADVERSE_ACTION_NOTICE_DELIVERY_ATTEMPTED');");
      report.aggregateCounts.negativePaths = Object.keys(report.negativePaths).length;
      expect(Object.values(report.workflowStates).every(Boolean)).toBe(true);
      expect(Object.values(report.negativePaths).every(Boolean)).toBe(true);
      expect(report.aggregateCounts.auditEvents).toBe(4);
      report.timing.durationMs = Date.now() - started;
      report.verdict = 'PASSED';
      await writeReport(report);
    } catch (error) {
      report.errorCode = error instanceof Error ? error.message.replace(/[^A-Z0-9_]/gi, '_').slice(0, 80) : 'UNKNOWN';
      report.timing.durationMs = Date.now() - started;
      await writeReport(report);
      throw error;
    }
  }, 180_000);
});
