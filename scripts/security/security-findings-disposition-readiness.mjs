#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

const severities = ['critical', 'high'];
const assessmentStatuses = ['open', 'remediated', 'acceptedRisk'];
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
function validAssessmentBaselineCounts(value) {
  if (!isPlainObject(value) || Object.keys(value).length !== severities.length) return false;
  return severities.every((severity) => {
    const counts = value[severity];
    return isPlainObject(counts)
      && Object.keys(counts).length === assessmentStatuses.length
      && assessmentStatuses.every((status) => Number.isInteger(counts[status]) && counts[status] >= 0)
      && Object.keys(counts).every((status) => assessmentStatuses.includes(status));
  });
}
function blankAssessmentBaselineCounts() {
  return Object.fromEntries(severities.map((severity) => [severity, Object.fromEntries(assessmentStatuses.map((status) => [status, 0]))]));
}
function sameDeployment(left, right) {
  return left?.environment === right?.environment
    && left?.deploymentRef === right?.deploymentRef
    && left?.configurationVersion === right?.configurationVersion;
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
      t908SelectedDeployment: metadata.assessmentBinding.t908SelectedDeployment && isPlainObject(metadata.assessmentBinding.t908SelectedDeployment) ? {
        environment: String(metadata.assessmentBinding.t908SelectedDeployment.environment ?? 'UNVERIFIED'),
        deploymentRef: String(metadata.assessmentBinding.t908SelectedDeployment.deploymentRef ?? 'UNVERIFIED'),
        configurationVersion: String(metadata.assessmentBinding.t908SelectedDeployment.configurationVersion ?? 'UNVERIFIED'),
      } : { environment: 'UNVERIFIED', deploymentRef: 'UNVERIFIED', configurationVersion: 'UNVERIFIED' },
      assessorAttestation: metadata.assessmentBinding.assessorAttestation && isPlainObject(metadata.assessmentBinding.assessorAttestation) ? {
        independent: metadata.assessmentBinding.assessorAttestation.independent === true,
        attestationRef: String(metadata.assessmentBinding.assessorAttestation.attestationRef ?? 'UNVERIFIED'),
        attestedAt: String(metadata.assessmentBinding.assessorAttestation.attestedAt ?? 'UNVERIFIED'),
      } : { independent: false, attestationRef: 'UNVERIFIED', attestedAt: 'UNVERIFIED' },
      findingRegisterRef: String(metadata.assessmentBinding.findingRegisterRef ?? 'UNVERIFIED'),
      baselineFindingCounts: validAssessmentBaselineCounts(metadata.assessmentBinding.baselineFindingCounts) ? metadata.assessmentBinding.baselineFindingCounts : blankAssessmentBaselineCounts(),
    } : {
      t908SelectedDeployment: { environment: 'UNVERIFIED', deploymentRef: 'UNVERIFIED', configurationVersion: 'UNVERIFIED' },
      assessorAttestation: { independent: false, attestationRef: 'UNVERIFIED', attestedAt: 'UNVERIFIED' },
      findingRegisterRef: 'UNVERIFIED',
      baselineFindingCounts: blankAssessmentBaselineCounts(),
    },
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
  if (!sameDeployment(deployment, assessment?.t908SelectedDeployment)) return block('T908_SELECTED_DEPLOYMENT_MISMATCH');
  if (assessment?.assessorAttestation?.independent !== true
    || !isSafeOpaqueValue(assessment.assessorAttestation.attestationRef)
    || !isValidTimestamp(assessment.assessorAttestation.attestedAt)
    || !isSafeOpaqueValue(assessment.findingRegisterRef)) return block('MISSING_T908_ASSESSMENT_BINDING');
  if (!validAssessmentBaselineCounts(assessment.baselineFindingCounts)) return block('INVALID_T908_CRITICAL_HIGH_BASELINE');
  if (!validDispositionCounts(metadata.aggregateDispositionCounts)) return block('INVALID_AGGREGATE_DISPOSITION_COUNTS');
  const counts = metadata.aggregateDispositionCounts;
  const baseline = assessment.baselineFindingCounts;
  if (severities.some((severity) => counts[severity].assessed !== assessmentStatuses.reduce((total, status) => total + baseline[severity][status], 0))) return block('T908_BASELINE_COUNT_MISMATCH', metadata);
  if (severities.some((severity) => baseline[severity].open > 0)) return block('T908_BASELINE_HAS_OPEN_CRITICAL_OR_HIGH', metadata);
  if (severities.some((severity) => baseline[severity].acceptedRisk > 0)) return block('T908_BASELINE_HAS_ACCEPTED_RISK_CRITICAL_OR_HIGH', metadata);
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
