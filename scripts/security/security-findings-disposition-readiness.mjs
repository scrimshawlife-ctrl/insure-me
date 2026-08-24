#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

const severities = ['critical', 'high'];
const dispositionFields = ['assessed', 'open', 'remediationImplemented', 'retestVerified', 'closed', 'acceptedRisk'];
const outputPath = process.env.SECURITY_FINDINGS_DISPOSITION_REPORT_PATH ?? 'artifacts/security-findings-disposition-readiness-report-v1.json';
const inputPath = process.env.SECURITY_FINDINGS_DISPOSITION_METADATA_PATH ?? 'testdata/security-assessment/synthetic-disposition-ready-metadata-v1.json';
const forbiddenKeys = new Set([
  'rawFindings', 'findings', 'findingIds', 'exploitDetails', 'endpoints', 'payload', 'payloads',
  'pii', 'secrets', 'secret', 'tokens', 'credentials', 'reportBodies', 'stack', 'stackTrace',
  'remediationEvidence', 'retestEvidence', 'providerEvidenceRefs', 'carrierEvidenceRefs',
]);

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
function isSafeOpaqueValue(value) {
  return typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(value);
}
function isValidTimestamp(value) {
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/.test(value) && !Number.isNaN(Date.parse(value));
}
function containsForbiddenKey(value) {
  if (Array.isArray(value)) return value.some(containsForbiddenKey);
  if (!isPlainObject(value)) return false;
  return Object.entries(value).some(([key, child]) => forbiddenKeys.has(key) || containsForbiddenKey(child));
}
function blankCounts() {
  return Object.fromEntries(severities.map((severity) => [severity, Object.fromEntries(dispositionFields.map((field) => [field, 0]))]));
}
function validDispositionCounts(value) {
  if (!isPlainObject(value) || Object.keys(value).length !== severities.length) return false;
  return severities.every((severity) => {
    const counts = value[severity];
    return isPlainObject(counts)
      && Object.keys(counts).length === dispositionFields.length
      && dispositionFields.every((field) => Number.isInteger(counts[field]) && counts[field] >= 0)
      && Object.keys(counts).every((field) => dispositionFields.includes(field));
  });
}
function sanitized(metadata) {
  return {
    selectedDeployment: metadata?.selectedDeployment && isPlainObject(metadata.selectedDeployment) ? {
      environment: String(metadata.selectedDeployment.environment ?? 'UNVERIFIED'),
      deploymentRef: String(metadata.selectedDeployment.deploymentRef ?? 'UNVERIFIED'),
      configurationVersion: String(metadata.selectedDeployment.configurationVersion ?? 'UNVERIFIED'),
      exactBinding: metadata.selectedDeployment.exactBinding === true,
    } : { environment: 'UNVERIFIED', deploymentRef: 'UNVERIFIED', configurationVersion: 'UNVERIFIED', exactBinding: false },
    assessmentBinding: metadata?.assessmentBinding && isPlainObject(metadata.assessmentBinding) ? {
      assessorAttestationRef: String(metadata.assessmentBinding.assessorAttestationRef ?? 'UNVERIFIED'),
      assessmentAttestedAt: String(metadata.assessmentBinding.assessmentAttestedAt ?? 'UNVERIFIED'),
      findingRegisterRef: String(metadata.assessmentBinding.findingRegisterRef ?? 'UNVERIFIED'),
      sameAssessmentBoundary: metadata.assessmentBinding.sameAssessmentBoundary === true,
    } : { assessorAttestationRef: 'UNVERIFIED', assessmentAttestedAt: 'UNVERIFIED', findingRegisterRef: 'UNVERIFIED', sameAssessmentBoundary: false },
    aggregateDispositionCounts: validDispositionCounts(metadata?.aggregateDispositionCounts) ? metadata.aggregateDispositionCounts : blankCounts(),
    independentClosureAttestation: metadata?.independentClosureAttestation && isPlainObject(metadata.independentClosureAttestation) ? {
      independent: metadata.independentClosureAttestation.independent === true,
      attestationRef: String(metadata.independentClosureAttestation.attestationRef ?? 'UNVERIFIED'),
      attestedAt: String(metadata.independentClosureAttestation.attestedAt ?? 'UNVERIFIED'),
      allCriticalHighRetested: metadata.independentClosureAttestation.allCriticalHighRetested === true,
    } : { independent: false, attestationRef: 'UNVERIFIED', attestedAt: 'UNVERIFIED', allCriticalHighRetested: false },
    externalEvidence: metadata?.externalEvidence && isPlainObject(metadata.externalEvidence) ? {
      assessmentBindingReceived: metadata.externalEvidence.assessmentBindingReceived === true,
      findingRegisterReceived: metadata.externalEvidence.findingRegisterReceived === true,
      remediationEvidenceReceived: metadata.externalEvidence.remediationEvidenceReceived === true,
      independentRetestEvidenceReceived: metadata.externalEvidence.independentRetestEvidenceReceived === true,
      closureAttestationReceived: metadata.externalEvidence.closureAttestationReceived === true,
    } : { assessmentBindingReceived: false, findingRegisterReceived: false, remediationEvidenceReceived: false, independentRetestEvidenceReceived: false, closureAttestationReceived: false },
  };
}
function buildReport(verdict, errorCode, metadata) {
  return {
    schemaVersion: 'security-findings-disposition-readiness-report-v1',
    contractVersions: { acceptance: 'A-051', assessmentTask: 'T908', dispositionTask: 'T909' },
    ...sanitized(metadata),
    timing: { producedEpochMs: Date.now() },
    errorCode,
    verdict,
  };
}
function block(code, metadata = undefined) {
  return buildReport('BLOCKED', code, metadata);
}
function validate(metadata) {
  if (!isPlainObject(metadata)) return block('INVALID_METADATA_SHAPE');
  if (metadata.schemaVersion !== 'security-findings-disposition-metadata-v1') return block('INVALID_SCHEMA_VERSION');
  if (containsForbiddenKey(metadata)) return block('FORBIDDEN_RAW_EVIDENCE_KEY');
  const deployment = metadata.selectedDeployment;
  if (!deployment?.exactBinding || !isSafeOpaqueValue(deployment.environment) || !isSafeOpaqueValue(deployment.deploymentRef) || !isSafeOpaqueValue(deployment.configurationVersion)) return block('MISSING_EXACT_SELECTED_DEPLOYMENT_BINDING');
  const assessment = metadata.assessmentBinding;
  if (!assessment?.sameAssessmentBoundary) return block('ASSESSMENT_BOUNDARY_MISMATCH');
  if (!isSafeOpaqueValue(assessment.assessorAttestationRef) || !isValidTimestamp(assessment.assessmentAttestedAt) || !isSafeOpaqueValue(assessment.findingRegisterRef)) return block('MISSING_ASSESSMENT_BINDING');
  if (!validDispositionCounts(metadata.aggregateDispositionCounts)) return block('INVALID_AGGREGATE_DISPOSITION_COUNTS');
  const counts = metadata.aggregateDispositionCounts;
  if (severities.some((severity) => counts[severity].open > 0)) return block('OPEN_CRITICAL_OR_HIGH_FINDINGS', metadata);
  if (severities.some((severity) => counts[severity].acceptedRisk > 0)) return block('CRITICAL_OR_HIGH_ACCEPTED_RISK', metadata);
  if (severities.some((severity) => counts[severity].assessed !== counts[severity].open + counts[severity].closed)) return block('DISPOSITION_COUNT_MISMATCH', metadata);
  if (severities.some((severity) => counts[severity].remediationImplemented !== counts[severity].assessed)) return block('INCOMPLETE_REMEDIATION_COVERAGE', metadata);
  if (severities.some((severity) => counts[severity].retestVerified !== counts[severity].assessed)) return block('INCOMPLETE_INDEPENDENT_RETEST_COVERAGE', metadata);
  if (severities.some((severity) => counts[severity].closed !== counts[severity].assessed)) return block('DISPOSITION_COUNT_MISMATCH', metadata);
  const closure = metadata.independentClosureAttestation;
  if (closure?.independent !== true || closure.allCriticalHighRetested !== true || !isSafeOpaqueValue(closure.attestationRef) || !isValidTimestamp(closure.attestedAt)) return block('MISSING_INDEPENDENT_CLOSURE_ATTESTATION');
  const evidence = metadata.externalEvidence;
  if (!evidence?.assessmentBindingReceived || !evidence?.findingRegisterReceived || !evidence?.remediationEvidenceReceived || !evidence?.independentRetestEvidenceReceived || !evidence?.closureAttestationReceived) return block('MISSING_EXTERNAL_DISPOSITION_EVIDENCE');
  return buildReport('READY_FOR_DISPOSITION_REVIEW', null, metadata);
}
function main() {
  let report;
  try {
    report = validate(JSON.parse(readFileSync(inputPath, 'utf8')));
  } catch {
    report = block('METADATA_READ_OR_PARSE_FAILED');
  }
  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
  if (report.verdict === 'BLOCKED') process.exitCode = 1;
}
main();
