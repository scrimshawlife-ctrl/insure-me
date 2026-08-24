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
    ['MISSING_EXACT_SELECTED_DEPLOYMENT_BINDING', { ...readyMetadata, selectedDeployment: { ...readyMetadata.selectedDeployment, exactBinding: false } }],
    ['ASSESSMENT_BOUNDARY_MISMATCH', { ...readyMetadata, assessmentBinding: { ...readyMetadata.assessmentBinding, sameAssessmentBoundary: false } }],
    ['MISSING_ASSESSMENT_BINDING', { ...readyMetadata, assessmentBinding: { ...readyMetadata.assessmentBinding, findingRegisterRef: '' } }],
    ['INVALID_AGGREGATE_DISPOSITION_COUNTS', { ...readyMetadata, aggregateDispositionCounts: { ...readyMetadata.aggregateDispositionCounts, high: { ...readyMetadata.aggregateDispositionCounts.high, unexpected: 1 } } }],
    ['CRITICAL_OR_HIGH_ACCEPTED_RISK', withHigh({ acceptedRisk: 1 })],
    ['DISPOSITION_COUNT_MISMATCH', withHigh({ closed: 0 })],
    ['INCOMPLETE_REMEDIATION_COVERAGE', withHigh({ remediationImplemented: 0 })],
    ['INCOMPLETE_INDEPENDENT_RETEST_COVERAGE', withHigh({ retestVerified: 0 })],
    ['MISSING_INDEPENDENT_CLOSURE_ATTESTATION', { ...readyMetadata, independentClosureAttestation: { ...readyMetadata.independentClosureAttestation, independent: false } }],
    ['MISSING_EXTERNAL_DISPOSITION_EVIDENCE', { ...readyMetadata, externalEvidence: { ...readyMetadata.externalEvidence, independentRetestEvidenceReceived: false } }],
    ['FORBIDDEN_RAW_EVIDENCE_KEY', { ...readyMetadata, rawFindings: ['must-not-enter-report'] }],
  ])('fails closed with %s and does not leak unvalidated input', (errorCode, metadata) => {
    const { result, report, raw } = runMetadata(metadata);
    expect(result.status).toBe(1);
    expect(report.verdict).toBe('BLOCKED');
    expect(report.errorCode).toBe(errorCode);
    expect(raw).not.toContain('must-not-enter-report');
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
