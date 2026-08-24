import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

const script = 'scripts/security/security-findings-disposition-readiness.mjs';
const allowed = ['schemaVersion', 'contractVersions', 'selectedDeployment', 'assessmentBinding', 'aggregateDispositionCounts', 'independentClosureAttestation', 'externalEvidence', 'timing', 'errorCode', 'verdict'].sort();
const forbiddenArtifactPattern = /rawFindings|exploitDetails|endpoint|payload|token|credential|password|email|phone|address|ssn|quoteCase|stackTrace|remediationEvidenceRef|retestEvidenceRef/i;

function run(input: string) {
  const dir = mkdtempSync(join(tmpdir(), 't909-'));
  const out = join(dir, 'security-findings-disposition-readiness-report-v1.json');
  const result = spawnSync(process.execPath, [script], {
    env: { ...process.env, SECURITY_FINDINGS_DISPOSITION_METADATA_PATH: input, SECURITY_FINDINGS_DISPOSITION_REPORT_PATH: out },
    encoding: 'utf8',
  });
  return { result, report: JSON.parse(readFileSync(out, 'utf8')), raw: readFileSync(out, 'utf8') };
}
function runMetadata(metadata: Record<string, unknown>) {
  const dir = mkdtempSync(join(tmpdir(), 't909-input-'));
  const input = join(dir, 'metadata.json');
  writeFileSync(input, JSON.stringify(metadata));
  return run(input);
}
const readyMetadata = JSON.parse(readFileSync('testdata/security-assessment/synthetic-disposition-ready-metadata-v1.json', 'utf8'));

function withHigh(overrides: Record<string, number>) {
  return {
    ...readyMetadata,
    aggregateDispositionCounts: {
      ...readyMetadata.aggregateDispositionCounts,
      high: { ...readyMetadata.aggregateDispositionCounts.high, ...overrides },
    },
  };
}

describe('T909 security findings disposition readiness validator', () => {
  it('produces a sanitized readiness-for-review artifact without completing T908 or T909', () => {
    const { result, report, raw } = run('testdata/security-assessment/synthetic-disposition-ready-metadata-v1.json');
    expect(result.status).toBe(0);
    expect(Object.keys(report).sort()).toEqual(allowed);
    expect(report.schemaVersion).toBe('security-findings-disposition-readiness-report-v1');
    expect(report.contractVersions).toEqual({ acceptance: 'A-051', assessmentTask: 'T908', dispositionTask: 'T909' });
    expect(report.verdict).toBe('READY_FOR_DISPOSITION_REVIEW');
    expect(report.verdict).not.toMatch(/COMPLETE|PASSED|CERTIFIED|SECURE|REMEDIATED/i);
    expect(raw).not.toMatch(forbiddenArtifactPattern);
  });

  it('fails closed and still writes the artifact when a high finding remains open', () => {
    const { result, report } = run('testdata/security-assessment/synthetic-disposition-blocked-open-high-metadata-v1.json');
    expect(result.status).toBe(1);
    expect(Object.keys(report).sort()).toEqual(allowed);
    expect(report.verdict).toBe('BLOCKED');
    expect(report.errorCode).toBe('OPEN_CRITICAL_OR_HIGH_FINDINGS');
    expect(report.aggregateDispositionCounts.high.open).toBe(1);
  });

  it.each([
    ['INVALID_METADATA_SHAPE', []],
    ['INVALID_SCHEMA_VERSION', { ...readyMetadata, schemaVersion: 'unexpected-version' }],
    ['MISSING_EXACT_SELECTED_DEPLOYMENT_BINDING', { ...readyMetadata, selectedDeployment: { ...readyMetadata.selectedDeployment, exactBinding: false } }],
    ['T908_SELECTED_DEPLOYMENT_MISMATCH', { ...readyMetadata, assessmentBinding: { ...readyMetadata.assessmentBinding, t908SelectedDeployment: { ...readyMetadata.assessmentBinding.t908SelectedDeployment, deploymentRef: 'different-deployment' } } }],
    ['MISSING_T908_ASSESSMENT_BINDING', { ...readyMetadata, assessmentBinding: { ...readyMetadata.assessmentBinding, assessorAttestation: { ...readyMetadata.assessmentBinding.assessorAttestation, independent: false } } }],
    ['MISSING_T908_ASSESSMENT_BINDING', { ...readyMetadata, assessmentBinding: { ...readyMetadata.assessmentBinding, findingRegisterRef: '' } }],
    ['INVALID_T908_CRITICAL_HIGH_BASELINE', { ...readyMetadata, assessmentBinding: { ...readyMetadata.assessmentBinding, baselineFindingCounts: { ...readyMetadata.assessmentBinding.baselineFindingCounts, high: { ...readyMetadata.assessmentBinding.baselineFindingCounts.high, medium: 1 } } } }],
    ['INVALID_AGGREGATE_DISPOSITION_COUNTS', { ...readyMetadata, aggregateDispositionCounts: { ...readyMetadata.aggregateDispositionCounts, high: { ...readyMetadata.aggregateDispositionCounts.high, unexpected: 1 } } }],
    ['T908_BASELINE_COUNT_MISMATCH', { ...readyMetadata, assessmentBinding: { ...readyMetadata.assessmentBinding, baselineFindingCounts: { ...readyMetadata.assessmentBinding.baselineFindingCounts, high: { ...readyMetadata.assessmentBinding.baselineFindingCounts.high, remediated: 2 } } } }],
    ['T908_BASELINE_HAS_OPEN_CRITICAL_OR_HIGH', { ...readyMetadata, assessmentBinding: { ...readyMetadata.assessmentBinding, baselineFindingCounts: { ...readyMetadata.assessmentBinding.baselineFindingCounts, high: { open: 1, remediated: 0, acceptedRisk: 0 } } } }],
    ['T908_BASELINE_HAS_ACCEPTED_RISK_CRITICAL_OR_HIGH', { ...readyMetadata, assessmentBinding: { ...readyMetadata.assessmentBinding, baselineFindingCounts: { ...readyMetadata.assessmentBinding.baselineFindingCounts, high: { open: 0, remediated: 0, acceptedRisk: 1 } } } }],
    ['CRITICAL_OR_HIGH_ACCEPTED_RISK', withHigh({ acceptedRisk: 1 })],
    ['DISPOSITION_COUNT_MISMATCH', withHigh({ closed: 0 })],
    ['INCOMPLETE_REMEDIATION_COVERAGE', withHigh({ remediationImplemented: 0 })],
    ['INCOMPLETE_INDEPENDENT_RETEST_COVERAGE', withHigh({ retestVerified: 0 })],
    ['MISSING_INDEPENDENT_CLOSURE_ATTESTATION', { ...readyMetadata, independentClosureAttestation: { ...readyMetadata.independentClosureAttestation, independent: false } }],
    ['CLOSURE_ATTESTATION_BINDING_MISMATCH', { ...readyMetadata, independentClosureAttestation: { ...readyMetadata.independentClosureAttestation, selectedDeployment: { ...readyMetadata.independentClosureAttestation.selectedDeployment, deploymentRef: 'different-deployment' } } }],
    ['CLOSURE_ATTESTATION_BINDING_MISMATCH', { ...readyMetadata, independentClosureAttestation: { ...readyMetadata.independentClosureAttestation, findingRegisterRef: 'different-finding-register' } }],
    ['MISSING_EXTERNAL_DISPOSITION_EVIDENCE', { ...readyMetadata, externalEvidence: { ...readyMetadata.externalEvidence, independentRetestEvidenceReceived: false } }],
    ['FORBIDDEN_RAW_EVIDENCE_KEY', { ...readyMetadata, rawFindings: ['must-not-enter-report'] }],
  ])('fails closed with %s and does not leak unvalidated input', (errorCode, metadata) => {
    const { result, report, raw } = runMetadata(metadata as Record<string, unknown>);
    expect(result.status).toBe(1);
    expect(report.verdict).toBe('BLOCKED');
    expect(report.errorCode).toBe(errorCode);
    expect(raw).not.toContain('must-not-enter-report');
  });

  it('replaces invalid sensitive-looking closure attestation strings on blocked paths', () => {
    const sensitiveRef = 'credential=synthetic-secret';
    const sensitiveTimestamp = '2026-08-24T01:00:00Z token=synthetic-secret';
    const { result, report, raw } = runMetadata({
      ...readyMetadata,
      selectedDeployment: { ...readyMetadata.selectedDeployment, exactBinding: false },
      independentClosureAttestation: {
        ...readyMetadata.independentClosureAttestation,
        attestationRef: sensitiveRef,
        attestedAt: sensitiveTimestamp,
      },
    });
    expect(result.status).toBe(1);
    expect(report.errorCode).toBe('MISSING_EXACT_SELECTED_DEPLOYMENT_BINDING');
    expect(report.independentClosureAttestation.attestationRef).toBe('UNVERIFIED');
    expect(report.independentClosureAttestation.attestedAt).toBe('UNVERIFIED');
    expect(raw).not.toContain(sensitiveRef);
    expect(raw).not.toContain(sensitiveTimestamp);
  });

  it('fails closed and writes a sanitized artifact when metadata is missing or malformed', () => {
    const dir = mkdtempSync(join(tmpdir(), 't909-malformed-'));
    const malformed = join(dir, 'metadata.json');
    writeFileSync(malformed, '{not-json');
    for (const input of ['/definitely/missing/t909.json', malformed]) {
      const { result, report, raw } = run(input);
      expect(result.status).toBe(1);
      expect(report.errorCode).toBe('METADATA_READ_OR_PARSE_FAILED');
      expect(report.verdict).toBe('BLOCKED');
      expect(Object.keys(report).sort()).toEqual(allowed);
      expect(raw).not.toMatch(forbiddenArtifactPattern);
    }
  });

  it('keeps CI execution and upload fail-closed', () => {
    const workflow = readFileSync('.github/workflows/ci.yml', 'utf8');
    const section = workflow.slice(workflow.indexOf('- name: Run security findings disposition readiness gate'), workflow.indexOf('- name: Install PostgreSQL client'));
    expect(section).toContain('if: always()');
    expect(section).toContain('pnpm security-findings:disposition-readiness');
    expect(section).toContain('actions/upload-artifact@v4');
    expect(section).toContain('if-no-files-found: error');
  });

  it('package command writes the canonical synthetic artifact', () => {
    const dir = mkdtempSync(join(tmpdir(), 't909-package-'));
    const out = join(dir, 'security-findings-disposition-readiness-report-v1.json');
    execFileSync('corepack', ['pnpm', 'security-findings:disposition-readiness'], {
      env: { ...process.env, SECURITY_FINDINGS_DISPOSITION_REPORT_PATH: out },
      stdio: 'pipe',
    });
    const report = JSON.parse(readFileSync(out, 'utf8'));
    expect(report.verdict).toBe('READY_FOR_DISPOSITION_REVIEW');
  });
});
