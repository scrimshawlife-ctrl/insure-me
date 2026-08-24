#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

const requiredScopeCategories = [
  'canonical-threat-model',
  'application-runtime',
  'authentication-and-session-boundary',
  'tenant-isolation-and-rls',
  'regulated-data-flows',
  'provider-and-carrier-boundaries',
  'secrets-and-configuration',
  'ci-cd-and-supply-chain',
  'infrastructure-hosting-and-networking',
  'observability-audit-and-incident-response',
];
const severities = ['critical', 'high', 'medium', 'low', 'informational'];
const statuses = ['open', 'remediated', 'acceptedRisk'];
const outputPath = process.env.SECURITY_ASSESSMENT_READINESS_REPORT_PATH ?? 'artifacts/security-assessment-readiness-report-v1.json';
const inputPath = process.env.SECURITY_ASSESSMENT_METADATA_PATH ?? 'testdata/security-assessment/synthetic-ready-metadata-v1.json';

function blankCounts() {
  return Object.fromEntries(severities.map((severity) => [severity, Object.fromEntries(statuses.map((status) => [status, 0]))]));
}
function block(code, metadata = undefined) {
  return buildReport('BLOCKED', code, metadata);
}
function isPlainObject(value) { return value !== null && typeof value === 'object' && !Array.isArray(value); }
function isSafeOpaqueValue(value) {
  return typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(value);
}
function isValidTimestamp(value) {
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/.test(value) && !Number.isNaN(Date.parse(value));
}
function hasOnlyAggregateKeys(value) {
  if (!isPlainObject(value)) return false;
  return Object.keys(value).every((k) => severities.includes(k)) && severities.every((sev) => isPlainObject(value[sev]) && Object.keys(value[sev]).every((s) => statuses.includes(s)) && statuses.every((s) => Number.isInteger(value[sev][s]) && value[sev][s] >= 0));
}
function buildReport(verdict, errorCode, metadata) {
  const findingCounts = hasOnlyAggregateKeys(metadata?.findingCounts) ? metadata.findingCounts : blankCounts();
  return {
    schemaVersion: 'security-assessment-readiness-report-v1',
    contractVersions: { acceptance: 'A-049', task: 'T908', handoff: 'T909' },
    selectedDeployment: metadata?.selectedDeployment && isPlainObject(metadata.selectedDeployment) ? {
      environment: String(metadata.selectedDeployment.environment ?? 'UNVERIFIED'),
      deploymentRef: String(metadata.selectedDeployment.deploymentRef ?? 'UNVERIFIED'),
      configurationVersion: String(metadata.selectedDeployment.configurationVersion ?? 'UNVERIFIED'),
      exactBinding: metadata.selectedDeployment.exactBinding === true,
    } : { environment: 'UNVERIFIED', deploymentRef: 'UNVERIFIED', configurationVersion: 'UNVERIFIED', exactBinding: false },
    assessorAttestation: metadata?.assessorAttestation && isPlainObject(metadata.assessorAttestation) ? {
      independent: metadata.assessorAttestation.independent === true,
      attestationRef: String(metadata.assessorAttestation.attestationRef ?? 'UNVERIFIED'),
      attestedAt: String(metadata.assessorAttestation.attestedAt ?? 'UNVERIFIED'),
    } : { independent: false, attestationRef: 'UNVERIFIED', attestedAt: 'UNVERIFIED' },
    scopeCategories: Array.isArray(metadata?.scopeCategories) ? metadata.scopeCategories.map(String).sort() : [],
    aggregateFindingCounts: findingCounts,
    externalEvidence: metadata?.externalEvidence && isPlainObject(metadata.externalEvidence) ? {
      assessmentMetadataReceived: metadata.externalEvidence.assessmentMetadataReceived === true,
      assessorAttestationReceived: metadata.externalEvidence.assessorAttestationReceived === true,
      selectedDeploymentBindingReceived: metadata.externalEvidence.selectedDeploymentBindingReceived === true,
      t909HandoffPrepared: metadata.externalEvidence.t909HandoffPrepared === true,
    } : { assessmentMetadataReceived: false, assessorAttestationReceived: false, selectedDeploymentBindingReceived: false, t909HandoffPrepared: false },
    timing: { producedEpochMs: Date.now() },
    errorCode,
    verdict,
  };
}
function validate(metadata) {
  if (!isPlainObject(metadata)) return block('INVALID_METADATA_SHAPE');
  if (metadata.schemaVersion !== 'security-assessment-metadata-v1') return block('INVALID_SCHEMA_VERSION');
  const forbidden = ['rawFindings', 'findings', 'pii', 'secrets', 'secret', 'tokens', 'credentials', 'evidencePayload'];
  if (forbidden.some((key) => Object.prototype.hasOwnProperty.call(metadata, key))) return block('FORBIDDEN_RAW_EVIDENCE_KEY');
  if (!metadata.selectedDeployment?.exactBinding || !isSafeOpaqueValue(metadata.selectedDeployment?.environment) || !isSafeOpaqueValue(metadata.selectedDeployment?.deploymentRef) || !isSafeOpaqueValue(metadata.selectedDeployment?.configurationVersion)) return block('MISSING_EXACT_SELECTED_DEPLOYMENT_BINDING');
  if (metadata.assessorAttestation?.independent !== true || !isSafeOpaqueValue(metadata.assessorAttestation?.attestationRef) || !isValidTimestamp(metadata.assessorAttestation?.attestedAt)) return block('MISSING_INDEPENDENT_ASSESSOR_ATTESTATION');
  if (!hasOnlyAggregateKeys(metadata.findingCounts)) return block('INVALID_AGGREGATE_FINDING_COUNTS');
  const suppliedScopes = Array.isArray(metadata.scopeCategories) ? metadata.scopeCategories : [];
  const scopes = new Set(suppliedScopes);
  if (suppliedScopes.length !== requiredScopeCategories.length || scopes.size !== requiredScopeCategories.length || !requiredScopeCategories.every((scope) => scopes.has(scope))) return block('INVALID_SCOPE_CATEGORIES');
  const evidence = metadata.externalEvidence;
  if (!evidence?.assessmentMetadataReceived || !evidence?.assessorAttestationReceived || !evidence?.selectedDeploymentBindingReceived || !evidence?.t909HandoffPrepared) return block('MISSING_EXTERNAL_EVIDENCE');
  if (metadata.findingCounts.critical.open > 0 || metadata.findingCounts.high.open > 0) return block('OPEN_CRITICAL_OR_HIGH_FINDINGS', metadata);
  return buildReport('READY_FOR_ASSESSMENT', null, metadata);
}
function main() {
  let report;
  try { report = validate(JSON.parse(readFileSync(inputPath, 'utf8'))); }
  catch { report = block('METADATA_READ_OR_PARSE_FAILED'); }
  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
  if (report.verdict === 'BLOCKED') process.exitCode = 1;
}
main();
