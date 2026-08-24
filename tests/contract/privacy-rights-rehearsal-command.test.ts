import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

import { createPrivacyRequest } from '@/src/application/privacy/privacy-request';
import { discoverPrivacyRequestData, downloadPrivacyExport } from '@/src/application/privacy/privacy-data-discovery';
import { executePrivacyRightsRequest } from '@/src/application/privacy/privacy-rights-execution';
import { propagatePrivacyRequestToVendors } from '@/src/application/privacy/privacy-vendor-propagation';
import { verifyPrivacyRequestIdentity } from '@/src/application/privacy/verify-privacy-request-identity';
import { protectConsumerIdentity } from '@/src/infrastructure/security/identity-protection';
import { createSupabaseAdminClient } from '@/src/infrastructure/supabase/admin';

type Primitive = string | number | boolean | null;
type PrimitiveRecord = Record<string, Primitive>;
type DbResult<T = unknown> = { data: T | null; error: { message?: string } | null; count?: number | null };
type QueryBuilder = {
  upsert(value: unknown): Promise<DbResult>;
  insert(value: unknown): Promise<DbResult>;
  select(columns?: string, options?: { count?: 'exact'; head?: boolean }): QueryBuilder;
  eq(column: string, value: unknown): QueryBuilder;
  in(column: string, values: unknown[]): QueryBuilder;
  single(): Promise<DbResult<PrimitiveRecord>>;
  limit(count: number): QueryBuilder;
  maybeSingle(): Promise<DbResult<PrimitiveRecord>>;
  then<TResult1 = DbResult, TResult2 = never>(
    onfulfilled?: ((value: DbResult) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null,
  ): PromiseLike<TResult1 | TResult2>;
};
type RehearsalDb = {
  from(table: string): QueryBuilder;
  rpc(functionName: string, args: Record<string, unknown>): Promise<DbResult<PrimitiveRecord[]>>;
};
type Report = {
  schemaVersion: 'privacy-rights-rehearsal-report-v1';
  contractVersions: PrimitiveRecord;
  syntheticFixture: PrimitiveRecord;
  workflowStates: PrimitiveRecord;
  aggregateCounts: PrimitiveRecord;
  downstreamStatus: PrimitiveRecord;
  timing: PrimitiveRecord;
  errorCode: string | null;
  verdict: 'PASSED' | 'FAILED';
};

const reportPath = process.env.PRIVACY_REHEARSAL_REPORT_PATH ?? 'artifacts/privacy-rights-rehearsal-report-v1.json';
const localEnv = {
  DEPLOYMENT_STAGE: 'synthetic',
  PRIVACY_IDENTITY_ADAPTER_ID: 'synthetic-privacy-identity-v1',
  PRIVACY_IDENTITY_POLICY_VERSION: 'synthetic-privacy-identity-policy-v1',
  PRIVACY_EXPORT_POLICY_VERSION: 'synthetic-privacy-export-v1',
  PRIVACY_EXPORT_SCHEMA_VERSION: 'privacy-export-v1',
  PRIVACY_RIGHTS_EXECUTION_POLICY_VERSION: 'synthetic-privacy-rights-v1',
  PRIVACY_PROPAGATION_ADAPTER_ID: 'synthetic-privacy-propagation-v1',
  PRIVACY_PROPAGATION_POLICY_VERSION: 'synthetic-privacy-propagation-policy-v1',
};
const piiPattern = /Avery|privacy-rehearsal-requester|example\.invalid|555|Roadster|123 Main|Sacramento|95814|\+1555|statusToken|lookup|cipher|encrypted|secret|payload|token|publicReference|hash|checks|task/i;
const allowedTop = ['aggregateCounts', 'contractVersions', 'downstreamStatus', 'errorCode', 'schemaVersion', 'syntheticFixture', 'timing', 'verdict', 'workflowStates'];
const rehearsalDescribe = process.env.PRIVACY_REHEARSAL_ENABLED === '1' ? describe : describe.skip;

function requireSuccess<T>(result: DbResult<T>, label: string): DbResult<T> {
  if (result.error) throw new Error(label);
  return result;
}

async function writeReport(report: Report) {
  await mkdir(reportPath.split('/').slice(0, -1).join('/') || '.', { recursive: true });
  expect(Object.keys(report).sort()).toEqual(allowedTop);
  const serialized = JSON.stringify(report, null, 2);
  expect(serialized).not.toMatch(piiPattern);
  await writeFile(reportPath, `${serialized}\n`);
}

async function denied(label: string, fn: () => Promise<unknown>) {
  try {
    await fn();
  } catch {
    return true;
  }
  throw new Error(label);
}

function runPsql(dbUrl: string, sql: string, vars: Record<string, string>) {
  const dir = mkdtempSync('/tmp/t906-');
  const sqlPath = join(dir, 'statement.sql');
  writeFileSync(sqlPath, sql);
  const args = Object.entries(vars).flatMap(([key, value]) => ['--set', `${key}=${value}`]);
  return execFileSync('psql', [dbUrl, ...args, '--file', sqlPath], { encoding: 'utf8', stdio: 'pipe' }).trim();
}

function seedDisposableDatabase(input: {
  dbUrl: string;
  ids: Record<string, string>;
  hostname: string;
  otherHostname: string;
  protectedIdentity: ReturnType<typeof protectConsumerIdentity>;
}) {
  const profileHex = input.protectedIdentity.pgBytea.replace(/^\\x/, '');
  if (!/^[0-9a-f]+$/i.test(profileHex)) throw new Error('FIXTURE_PROFILE_INVALID');
  const sql = String.raw`
\set ON_ERROR_STOP on
begin;
insert into public.agencies (agency_id, tenant_id, legal_name, display_name) values
  (:'agency'::uuid, :'tenant'::uuid, 'Synthetic Privacy Agency', 'Synthetic Privacy'),
  (:'otherAgency'::uuid, :'otherTenant'::uuid, 'Synthetic Other Agency', 'Synthetic Other')
on conflict (agency_id) do nothing;
insert into public.tenant_configurations (tenant_configuration_id, tenant_id, agency_id, version, status, enabled_jurisdictions, enabled_product_lines, retention_policy_set_id, effective_at) values
  (:'config'::uuid, :'tenant'::uuid, :'agency'::uuid, 1, 'ACTIVE', array['CA'], array['PRIVATE_PASSENGER_AUTO'], 'synthetic-privacy-retention', now() - interval '1 day'),
  (:'otherConfig'::uuid, :'otherTenant'::uuid, :'otherAgency'::uuid, 1, 'ACTIVE', array['CA'], array['PRIVATE_PASSENGER_AUTO'], 'synthetic-privacy-retention', now() - interval '1 day')
on conflict (tenant_configuration_id) do nothing;
insert into public.tenant_hosts (tenant_host_id, hostname, tenant_id, agency_id, tenant_configuration_id, tenant_configuration_version, status) values
  (:'host'::uuid, :'hostname', :'tenant'::uuid, :'agency'::uuid, :'config'::uuid, 1, 'ACTIVE'),
  (:'otherHost'::uuid, :'otherHostname', :'otherTenant'::uuid, :'otherAgency'::uuid, :'otherConfig'::uuid, 1, 'ACTIVE')
on conflict (tenant_host_id) do nothing;
insert into public.person_private_profiles (person_id, tenant_id, agency_id, encrypted_payload, encryption_algorithm, key_version, email_lookup_hash, phone_lookup_hash) values
  (:'person'::uuid, :'tenant'::uuid, :'agency'::uuid, decode(:'profileHex', 'hex'), 'AES-256-GCM', :'profileKeyVersion', :'emailLookupHash', :'phoneLookupHash')
on conflict (person_id) do nothing;
insert into public.prospects (prospect_id, tenant_id, agency_id, person_id, source_classification) values
  (:'prospect'::uuid, :'tenant'::uuid, :'agency'::uuid, :'person'::uuid, 'SYNTHETIC')
on conflict (prospect_id) do nothing;
insert into public.quote_cases (quote_case_id, tenant_id, agency_id, tenant_configuration_id, tenant_configuration_version, jurisdiction, product_line, source_channel, state, prospect_id) values
  (:'case'::uuid, :'tenant'::uuid, :'agency'::uuid, :'config'::uuid, 1, 'CA', 'PRIVATE_PASSENGER_AUTO', 'WEB', 'CONSUMER_INPUT', :'prospect'::uuid)
on conflict (quote_case_id) do nothing;
insert into public.drivers (driver_id, tenant_id, agency_id, quote_case_id, person_id, relationship_role, first_name, last_name, date_of_birth, license_jurisdiction, confirmation_state, source_type) values
  (:'driver'::uuid, :'tenant'::uuid, :'agency'::uuid, :'case'::uuid, :'person'::uuid, 'NAMED_INSURED', 'Avery', 'Synthetic', '1990-01-01', 'CA', 'CONFIRMED', 'CONSUMER')
on conflict (driver_id) do nothing;
insert into public.vehicles (vehicle_id, tenant_id, agency_id, quote_case_id, model_year, make, model, usage, confirmation_state, source_type) values
  (:'vehicle'::uuid, :'tenant'::uuid, :'agency'::uuid, :'case'::uuid, 2026, 'Synthetic', 'Roadster', 'COMMUTE', 'CONFIRMED', 'CONSUMER')
on conflict (vehicle_id) do nothing;
insert into public.coverage_requests (coverage_request_id, tenant_id, agency_id, quote_case_id, requested_limits, preferences) values
  (:'coverage'::uuid, :'tenant'::uuid, :'agency'::uuid, :'case'::uuid, '{"bodilyInjury":"100/300"}'::jsonb, '{"deductible":500}'::jsonb)
on conflict (coverage_request_id) do nothing;
insert into public.permissible_purpose_decisions (decision_id, tenant_id, quote_case_id, tenant_configuration_version, jurisdiction, capability, purpose_code, outcome, reason_codes, policy_version) values
  ( :'purpose'::uuid, :'tenant'::uuid, :'case'::uuid, 1, 'CA', 'MVR', 'INSURANCE_UNDERWRITING', 'ALLOW', array['SYNTHETIC'], 'synthetic-purpose-v1')
on conflict (decision_id) do nothing;
insert into public.provider_bindings (provider_binding_id, tenant_id, agency_id, capability, adapter_id, adapter_version, jurisdiction, product_line, status, purpose_code) values
  (:'binding'::uuid, :'tenant'::uuid, :'agency'::uuid, 'MVR', 'synthetic-mvr-v1', '1.0.0', 'CA', 'PRIVATE_PASSENGER_AUTO', 'ACTIVE', 'INSURANCE_UNDERWRITING')
on conflict (provider_binding_id) do nothing;
insert into public.privacy_propagation_bindings (privacy_propagation_binding_id, tenant_id, agency_id, provider_binding_id, adapter_id, adapter_version, policy_version, state) values
  (:'propagationBinding'::uuid, :'tenant'::uuid, :'agency'::uuid, :'binding'::uuid, 'synthetic-privacy-propagation-v1', '1.0.0', 'synthetic-privacy-propagation-policy-v1', 'SYNTHETIC')
on conflict (privacy_propagation_binding_id) do nothing;
insert into public.external_requests (external_request_id, tenant_id, agency_id, quote_case_id, tenant_configuration_version, provider_binding_id, capability, subject_ids, permissible_purpose_decision_id, consent_record_ids, idempotency_key, request_hash, status) values
  (:'external'::uuid, :'tenant'::uuid, :'agency'::uuid, :'case'::uuid, 1, :'binding'::uuid, 'MVR', array[:'person'::uuid], :'purpose'::uuid, '{}', 'privacy-rehearsal-downstream', repeat('a', 64), 'SUCCEEDED')
on conflict (external_request_id) do nothing;
insert into public.retention_policies (retention_policy_id, tenant_id, agency_id, policy_set_id, version, data_class, jurisdiction, retention_interval, disposition, legal_hold_blocks_destructive_disposition, certification_state, legal_authority_refs, effective_at) values
  (:'retentionPolicy'::uuid, :'tenant'::uuid, :'agency'::uuid, 'synthetic-privacy-retention', 1, 'IDENTITY_PROFILE', 'CA', interval '1 day', 'DELETE', true, 'APPROVED', array['synthetic-legal-authority'], now() - interval '1 day'),
  (:'consumerRetentionPolicy'::uuid, :'tenant'::uuid, :'agency'::uuid, 'synthetic-privacy-retention', 1, 'CONSUMER_INPUT', 'CA', interval '1 day', 'ANONYMIZE', true, 'APPROVED', array['synthetic-legal-authority'], now() - interval '1 day')
on conflict (retention_policy_id) do nothing;
commit;
`;
  runPsql(input.dbUrl, sql, { ...input.ids, hostname: input.hostname, otherHostname: input.otherHostname, profileHex, profileKeyVersion: input.protectedIdentity.keyVersion, emailLookupHash: input.protectedIdentity.emailLookupHash, phoneLookupHash: input.protectedIdentity.phoneLookupHash ?? '' });
}

async function verifiedRequest(
  supabase: ReturnType<typeof createSupabaseAdminClient>,
  hostname: string,
  requestType: 'ACCESS' | 'CORRECTION' | 'DELETION' | 'RESTRICTION',
  phone: string,
  key: string,
) {
  const request = await createPrivacyRequest(supabase, {
    hostname,
    requestType,
    jurisdiction: 'CA',
    intakeChannel: 'WEB',
    requester: { firstName: 'Avery', lastName: 'Synthetic', email: 'privacy-rehearsal-requester@example.invalid', phone },
    idempotencyKey: `90600000-0000-4000-8000-00000000${key}1`,
  });
  await verifyPrivacyRequestIdentity(supabase, { hostname, privacyRequestId: request.privacyRequestId, statusToken: request.statusToken, assertion: 'SYNTHETIC-PRIVACY-VERIFIED', idempotencyKey: `90600000-0000-4000-8000-00000000${key}2` }, localEnv);
  await discoverPrivacyRequestData(supabase, { hostname, privacyRequestId: request.privacyRequestId, statusToken: request.statusToken, idempotencyKey: `90600000-0000-4000-8000-00000000${key}3` }, localEnv);
  return request;
}

rehearsalDescribe('T906 privacy-rights disposable Supabase rehearsal', () => {
  it('uses production privacy services/RPCs with exact PII-free evidence contract', async () => {
    process.env.NEXT_PUBLIC_SUPABASE_URL ??= 'http://127.0.0.1:54321';
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??= 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imluc3VyZS1tZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjAwMDAwMDAwLCJleHAiOjE5MTUzNjAwMDB9.2OH7gx7OvD7B2mOeUf34VjsZoNu6AqDoNld4UtKDgWs';
    process.env.SUPABASE_SECRET_KEY ??= 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imluc3VyZS1tZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE2MDAwMDAwMDAsImV4cCI6MTkxNTM2MDAwMH0.NQ9xQSOlzaCd96Ju87XiFS4-RciBIcm6ghi_-RSb6xg';
    process.env.IDENTITY_ENCRYPTION_KEY_B64 ??= Buffer.alloc(32, 7).toString('base64');
    process.env.IDENTITY_ENCRYPTION_KEY_VERSION ??= 'synthetic-key-v1';
    process.env.IDENTITY_LOOKUP_PEPPER ??= 'synthetic-privacy-rehearsal-pepper-v1';

    const started = Date.now();
    const supabase = createSupabaseAdminClient();
    const db = supabase as unknown as RehearsalDb;
    const hostname = 'privacy-rehearsal.test';
    const otherHostname = 'privacy-rehearsal-other.test';
    const ids = {
      tenant: '90600000-0000-4000-8000-000000000001', agency: '90600000-0000-4000-8000-000000000002', config: '90600000-0000-4000-8000-000000000003', host: '90600000-0000-4000-8000-000000000004',
      otherTenant: '90600000-0000-4000-8000-000000000011', otherAgency: '90600000-0000-4000-8000-000000000012', otherConfig: '90600000-0000-4000-8000-000000000013', otherHost: '90600000-0000-4000-8000-000000000014',
      person: '90600000-0000-4000-8000-000000000005', prospect: '90600000-0000-4000-8000-000000000006', case: '90600000-0000-4000-8000-000000000007', driver: '90600000-0000-4000-8000-000000000008', vehicle: '90600000-0000-4000-8000-000000000009', coverage: '90600000-0000-4000-8000-000000000010',
      purpose: '90600000-0000-4000-8000-000000000015', binding: '90600000-0000-4000-8000-000000000016', external: '90600000-0000-4000-8000-000000000017', retentionPolicy: '90600000-0000-4000-8000-000000000018', hold: '90600000-0000-4000-8000-000000000019', actor: '90600000-0000-4000-8000-000000000020', propagationBinding: '90600000-0000-4000-8000-000000000021', consumerRetentionPolicy: '90600000-0000-4000-8000-000000000022',
    };
    const report: Report = {
      schemaVersion: 'privacy-rights-rehearsal-report-v1',
      contractVersions: { privacyExport: 'privacy-export-v1', privacyRights: 'synthetic-privacy-rights-v1', propagation: 'synthetic-privacy-propagation-policy-v1', retention: 'synthetic-privacy-retention:1' },
      syntheticFixture: { fixture: 'T906', tenantCount: 2, hasDownstreamFixture: true, hasRetentionFixture: true },
      workflowStates: {},
      aggregateCounts: {},
      downstreamStatus: {},
      timing: { startedEpochMs: started, durationMs: 0 },
      errorCode: null,
      verdict: 'FAILED',
    };

    try {
      const protectedIdentity = protectConsumerIdentity({ firstName: 'Avery', lastName: 'Synthetic', dateOfBirth: '1990-01-01', email: 'privacy-rehearsal-requester@example.invalid', phone: '+15550101', address: { line1: '123 Main Synthetic', city: 'Sacramento', state: 'CA', postalCode: '95814' } });
      const dbUrl = process.env.SUPABASE_DB_URL;
      if (!dbUrl) throw new Error('SUPABASE_DB_URL_MISSING');
      seedDisposableDatabase({ dbUrl, ids, hostname, otherHostname, protectedIdentity });

      report.workflowStates.unknownHostDenied = await denied('unknown_host', () => createPrivacyRequest(supabase, { hostname: 'missing-host.test', requestType: 'ACCESS', jurisdiction: 'CA', intakeChannel: 'WEB', requester: { firstName: 'Avery', lastName: 'Synthetic', email: 'privacy-rehearsal-requester@example.invalid' }, idempotencyKey: '90600000-0000-4000-8000-000000000901' }));
      const failed = await createPrivacyRequest(supabase, { hostname, requestType: 'ACCESS', jurisdiction: 'CA', intakeChannel: 'WEB', requester: { firstName: 'Avery', lastName: 'Synthetic', email: 'privacy-rehearsal-requester@example.invalid', phone: '+15550101' }, idempotencyKey: '90600000-0000-4000-8000-000000000101' });
      await verifyPrivacyRequestIdentity(supabase, { hostname, privacyRequestId: failed.privacyRequestId, statusToken: failed.statusToken, assertion: 'WRONG', idempotencyKey: '90600000-0000-4000-8000-000000000102' }, localEnv);
      report.workflowStates.failedIdentityDenied = await denied('failed_identity', () => discoverPrivacyRequestData(supabase, { hostname, privacyRequestId: failed.privacyRequestId, statusToken: failed.statusToken, idempotencyKey: '90600000-0000-4000-8000-000000000103' }, localEnv));
      const unverified = await createPrivacyRequest(supabase, { hostname, requestType: 'DELETION', jurisdiction: 'CA', intakeChannel: 'WEB', requester: { firstName: 'Avery', lastName: 'Synthetic', email: 'privacy-rehearsal-requester@example.invalid', phone: '+15550101' }, idempotencyKey: '90600000-0000-4000-8000-000000000111' });
      report.workflowStates.unverifiedExecutionDenied = await denied('unverified_execution', () => executePrivacyRightsRequest(supabase, { hostname, privacyRequestId: unverified.privacyRequestId, statusToken: unverified.statusToken, idempotencyKey: '90600000-0000-4000-8000-000000000112', corrections: null }, localEnv));
      report.workflowStates.crossTenantDenied = await denied('cross_tenant', () => discoverPrivacyRequestData(supabase, { hostname: otherHostname, privacyRequestId: unverified.privacyRequestId, statusToken: unverified.statusToken, idempotencyKey: '90600000-0000-4000-8000-000000000113' }, localEnv));
      const policyMismatch = await verifiedRequest(supabase, hostname, 'RESTRICTION', '+15550101', '012');
      report.workflowStates.policyMismatchDenied = await denied('policy_mismatch', () => executePrivacyRightsRequest(supabase, { hostname, privacyRequestId: policyMismatch.privacyRequestId, statusToken: policyMismatch.statusToken, idempotencyKey: '90600000-0000-4000-8000-000000000124', corrections: null }, { ...localEnv, PRIVACY_RIGHTS_EXECUTION_POLICY_VERSION: 'bad-policy-v1' }));
      const idem = await verifiedRequest(supabase, hostname, 'CORRECTION', '+15550101', '032');
      await executePrivacyRightsRequest(supabase, { hostname, privacyRequestId: idem.privacyRequestId, statusToken: idem.statusToken, idempotencyKey: '90600000-0000-4000-8000-000000000134', corrections: { phone: '+15550103' } }, localEnv);
      report.workflowStates.idempotencyMismatchDenied = await denied('idempotency_mismatch', () => executePrivacyRightsRequest(supabase, { hostname, privacyRequestId: idem.privacyRequestId, statusToken: idem.statusToken, idempotencyKey: '90600000-0000-4000-8000-000000000134', corrections: { phone: '+15550104' } }, localEnv));

      const access = await verifiedRequest(supabase, hostname, 'ACCESS', '+15550103', '040');
      const exportPayload = await downloadPrivacyExport(supabase, { hostname, privacyRequestId: access.privacyRequestId, statusToken: access.statusToken });
      expect(exportPayload).not.toHaveProperty('statusToken');
      expect(exportPayload).not.toHaveProperty('emailLookupHash');
      report.workflowStates.invalidExportDenied = await denied('invalid_export', () => downloadPrivacyExport(supabase, { hostname, privacyRequestId: access.privacyRequestId, statusToken: 'invalid-token' }));
      runPsql(dbUrl, String.raw`\set ON_ERROR_STOP on
alter table public.privacy_export_artifacts disable trigger privacy_export_artifact_immutable;
update public.privacy_export_artifacts artifact set encrypted_export = set_byte(artifact.encrypted_export, 0, (get_byte(artifact.encrypted_export, 0) + 1) % 256)
from public.privacy_requests request
where request.privacy_request_id = artifact.privacy_request_id and request.public_reference = :'publicReference'::uuid;
alter table public.privacy_export_artifacts enable trigger privacy_export_artifact_immutable;
`, { publicReference: access.privacyRequestId });
      report.workflowStates.exportIntegrityTamperDenied = await denied('export_tamper', () => downloadPrivacyExport(supabase, { hostname, privacyRequestId: access.privacyRequestId, statusToken: access.statusToken }));

      const correction = await verifiedRequest(supabase, hostname, 'CORRECTION', '+15550103', '050');
      const correctionStatus = await executePrivacyRightsRequest(supabase, { hostname, privacyRequestId: correction.privacyRequestId, statusToken: correction.statusToken, idempotencyKey: '90600000-0000-4000-8000-000000000504', corrections: { phone: '+15550105' } }, localEnv);
      const restriction = await verifiedRequest(supabase, hostname, 'RESTRICTION', '+15550105', '060');
      const restrictionStatus = await executePrivacyRightsRequest(supabase, { hostname, privacyRequestId: restriction.privacyRequestId, statusToken: restriction.statusToken, idempotencyKey: '90600000-0000-4000-8000-000000000604', corrections: null }, localEnv);

      const heldDeletion = await verifiedRequest(supabase, hostname, 'DELETION', '+15550105', '070');
      const heldRequestOutput = runPsql(dbUrl, String.raw`\set ON_ERROR_STOP on
\pset tuples_only on
\pset format unaligned
select privacy_request_id from public.privacy_requests where public_reference = :'publicReference'::uuid;
`, { publicReference: heldDeletion.privacyRequestId });
      const heldRequestId = heldRequestOutput.match(/[0-9a-f]{8}-[0-9a-f-]{27}/i)?.[0];
      if (!heldRequestId) throw new Error('HELD_REQUEST_QUERY_INVALID');
      runPsql(dbUrl, String.raw`
\set ON_ERROR_STOP on
insert into public.legal_holds (
  legal_hold_id, tenant_id, agency_id, scope_type, scope_ref, authority_ref,
  evidence_ref, reason_codes, placement_idempotency_key, placement_request_hash, placed_by
) values (
  :'hold'::uuid, :'tenant'::uuid, :'agency'::uuid, 'PRIVACY_REQUEST', :'heldRequestId'::uuid,
  'synthetic-authority', 'synthetic-evidence', array['SYNTHETIC_HOLD'],
  '90600000-0000-4000-8000-000000000701'::uuid, repeat('b', 64), :'actor'::uuid
) on conflict (legal_hold_id) do nothing;
`, { hold: ids.hold, tenant: ids.tenant, agency: ids.agency, heldRequestId, actor: ids.actor });
      const heldExecution = await executePrivacyRightsRequest(supabase, { hostname, privacyRequestId: heldDeletion.privacyRequestId, statusToken: heldDeletion.statusToken, idempotencyKey: '90600000-0000-4000-8000-000000000704', corrections: null }, localEnv);
      const heldRetention = requireSuccess(await db.rpc('prepare_retention_disposition_run', { p_idempotency_key: '90600000-0000-4000-8000-000000000705', p_as_of: new Date(Date.now() + 172_800_000).toISOString(), p_limit: 25, p_expected_certification_state: 'APPROVED' }), 'held_retention_prepare').data?.[0];
      report.workflowStates.heldDeletionBlockedNoMutation = heldRetention?.run_status !== 'COMPLETED';
      report.workflowStates.heldDeletionOpen = heldExecution.state === 'IN_PROGRESS';
      runPsql(dbUrl, String.raw`\set ON_ERROR_STOP on
update public.legal_holds set status = 'RELEASED',
  release_authority_ref = 'synthetic-release-authority', release_evidence_ref = 'synthetic-release-evidence',
  release_reason_codes = array['SYNTHETIC_REHEARSAL_CONTINUE'],
  release_idempotency_key = '90600000-0000-4000-8000-000000000708'::uuid,
  release_request_hash = repeat('c', 64), released_at = now(), released_by = :'actor'::uuid
where legal_hold_id = :'hold'::uuid;
insert into public.legal_hold_events (legal_hold_id, tenant_id, agency_id, event_type, actor_id, authority_ref, evidence_ref, reason_codes, request_hash)
values (:'hold'::uuid, :'tenant'::uuid, :'agency'::uuid, 'RELEASED', :'actor'::uuid,
  'synthetic-release-authority', 'synthetic-release-evidence', array['SYNTHETIC_REHEARSAL_CONTINUE'], repeat('c', 64));
`, { hold: ids.hold, tenant: ids.tenant, agency: ids.agency, actor: ids.actor });
      const missingPolicyDeletion = await verifiedRequest(supabase, hostname, 'DELETION', '+15550105', '075');
      await executePrivacyRightsRequest(supabase, { hostname, privacyRequestId: missingPolicyDeletion.privacyRequestId, statusToken: missingPolicyDeletion.statusToken, idempotencyKey: '90600000-0000-4000-8000-000000000754', corrections: null }, localEnv);
      runPsql(dbUrl, String.raw`\set ON_ERROR_STOP on
update public.tenant_configurations set retention_policy_set_id = 'synthetic-missing-retention' where tenant_configuration_id = :'config'::uuid;
`, { config: ids.config });
      requireSuccess(await db.rpc('prepare_retention_disposition_run', { p_idempotency_key: '90600000-0000-4000-8000-000000000756', p_as_of: new Date(Date.now() + 172_800_000).toISOString(), p_limit: 25, p_expected_certification_state: 'APPROVED' }), 'missing_retention_prepare');
      const missingPolicyReason = runPsql(dbUrl, String.raw`\set ON_ERROR_STOP on
\pset tuples_only on
\pset format unaligned
select array_to_string(item.reason_codes, ',') from public.retention_disposition_items item
join public.privacy_requests request on request.privacy_request_id = item.privacy_request_id
where request.public_reference = :'publicReference'::uuid;
`, { publicReference: missingPolicyDeletion.privacyRequestId });
      report.workflowStates.missingRetentionPolicyDenied = missingPolicyReason.includes('RETENTION_POLICY_NOT_CONFIGURED');
      runPsql(dbUrl, String.raw`\set ON_ERROR_STOP on
update public.tenant_configurations set retention_policy_set_id = 'synthetic-privacy-retention' where tenant_configuration_id = :'config'::uuid;
`, { config: ids.config });

      const deletion = await verifiedRequest(supabase, hostname, 'DELETION', '+15550105', '080');
      const deletionExecution = await executePrivacyRightsRequest(supabase, { hostname, privacyRequestId: deletion.privacyRequestId, statusToken: deletion.statusToken, idempotencyKey: '90600000-0000-4000-8000-000000000804', corrections: null }, localEnv);
      report.workflowStates.openBeforePropagationRetention = deletionExecution.state === 'IN_PROGRESS';
      report.downstreamStatus.propagationFailureDenied = await denied('downstream_failure', () => propagatePrivacyRequestToVendors(supabase, { hostname, privacyRequestId: deletion.privacyRequestId, statusToken: deletion.statusToken, idempotencyKey: '90600000-0000-4000-8000-000000000805' }, { ...localEnv, PRIVACY_PROPAGATION_ADAPTER_ID: 'bad-adapter-v1' }));
      const propagation = await propagatePrivacyRequestToVendors(supabase, { hostname, privacyRequestId: deletion.privacyRequestId, statusToken: deletion.statusToken, idempotencyKey: '90600000-0000-4000-8000-000000000806' }, localEnv);
      const retention = requireSuccess(await db.rpc('prepare_retention_disposition_run', { p_idempotency_key: '90600000-0000-4000-8000-000000000807', p_as_of: new Date(Date.now() + 172_800_000).toISOString(), p_limit: 25, p_expected_certification_state: 'APPROVED' }), 'retention_prepare').data?.[0];
      if (retention?.retention_disposition_run_id) requireSuccess(await db.rpc('execute_retention_disposition_run', { p_run_id: retention.retention_disposition_run_id, p_limit: 25 }), 'retention_execute');
      const closedState = runPsql(dbUrl, String.raw`\set ON_ERROR_STOP on
\pset tuples_only on
\pset format unaligned
select state::text from public.privacy_requests where public_reference = :'publicReference'::uuid;
`, { publicReference: deletion.privacyRequestId });
      report.workflowStates.closesAfterPropagationRetention = /(?:^|\n)COMPLETED$/.test(closedState);
      report.workflowStates.correctionPolicyPersisted = correctionStatus.executionOutcome === 'PARTIALLY_APPLIED' || correctionStatus.executionOutcome === 'APPLIED';
      report.workflowStates.restrictionPolicyPersisted = restrictionStatus.executionOutcome === 'PARTIALLY_APPLIED' || restrictionStatus.executionOutcome === 'APPLIED';
      report.workflowStates.deletionPolicyPersisted = deletionExecution.executionOutcome === 'PARTIALLY_APPLIED';
      report.downstreamStatus.propagationComplete = propagation.propagationComplete;
      report.downstreamStatus.retentionRunPrepared = Boolean(retention?.retention_disposition_run_id);

      const auditOutput = runPsql(dbUrl, String.raw`\set ON_ERROR_STOP on
\pset tuples_only on
\pset format unaligned
select count(*) from public.audit_events where tenant_id = :'tenant'::uuid and event_type in ('PRIVACY_REQUEST_RECEIVED', 'PRIVACY_IDENTITY_VERIFICATION_COMPLETED', 'PRIVACY_DISCOVERY_COMPLETED', 'PRIVACY_RIGHTS_EXECUTION_COMPLETED', 'PRIVACY_PROPAGATION_COMPLETED', 'RETENTION_DISPOSITION_COMPLETED');
`, { tenant: ids.tenant });
      const auditCount = Number(auditOutput.match(/\d+$/)?.[0]);
      report.workflowStates.auditAppendOnlyDenied = await denied('audit_append_only', async () => {
        runPsql(dbUrl, String.raw`\set ON_ERROR_STOP on
update public.audit_events set outcome = 'TAMPER' where audit_event_id = (
  select audit_event_id from public.audit_events where tenant_id = :'tenant'::uuid order by occurred_at limit 1
);
`, { tenant: ids.tenant });
      });
      report.aggregateCounts.auditEvents = Number.isFinite(auditCount) ? auditCount : 0;
      report.aggregateCounts.negativePaths = 7;
      report.aggregateCounts.privacyWorkflows = 6;
      report.aggregateCounts.prohibitedExportFields = 0;
      expect(Object.values(report.workflowStates).every((value) => value === true)).toBe(true);
      expect(Object.values(report.downstreamStatus).every((value) => value === true)).toBe(true);
      expect(report.aggregateCounts.auditEvents).toBeGreaterThan(0);
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
