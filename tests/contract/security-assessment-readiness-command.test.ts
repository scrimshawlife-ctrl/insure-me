import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

const script = 'scripts/security/security-assessment-readiness.mjs';
const allowed = ['schemaVersion', 'contractVersions', 'selectedDeployment', 'assessorAttestation', 'scopeCategories', 'aggregateFindingCounts', 'externalEvidence', 'timing', 'errorCode', 'verdict'].sort();
const forbiddenArtifactPattern = /rawFindings|payload|token|credential|password|email|phone|address|ssn|driver|vehicle|quoteCase/i;
function run(input: string) {
  const dir = mkdtempSync(join(tmpdir(), 't908-'));
  const out = join(dir, 'security-assessment-readiness-report-v1.json');
  const result = spawnSync(process.execPath, [script], { env: { ...process.env, SECURITY_ASSESSMENT_METADATA_PATH: input, SECURITY_ASSESSMENT_READINESS_REPORT_PATH: out }, encoding: 'utf8' });
  return { result, report: JSON.parse(readFileSync(out, 'utf8')), raw: readFileSync(out, 'utf8') };
}
function runMetadata(metadata: Record<string, unknown>) {
  const dir = mkdtempSync(join(tmpdir(), 't908-input-'));
  const input = join(dir, 'metadata.json');
  writeFileSync(input, JSON.stringify(metadata));
  return run(input);
}
const readyMetadata = JSON.parse(readFileSync('testdata/security-assessment/synthetic-ready-metadata-v1.json', 'utf8'));

describe('T908 security assessment readiness validator', () => {
  it('produces a PII-free READY_FOR_ASSESSMENT report for complete aggregate metadata', () => {
    const { result, report, raw } = run('testdata/security-assessment/synthetic-ready-metadata-v1.json');
    expect(result.status).toBe(0);
    expect(Object.keys(report).sort()).toEqual(allowed);
    expect(report.schemaVersion).toBe('security-assessment-readiness-report-v1');
    expect(report.contractVersions).toEqual({ acceptance: 'A-049', task: 'T908', handoff: 'T909' });
    expect(report.verdict).toBe('READY_FOR_ASSESSMENT');
    expect(report.verdict).not.toMatch(/COMPLETE|PASSED/i);
    expect(report.aggregateFindingCounts.high.open).toBe(0);
    expect(raw).not.toMatch(forbiddenArtifactPattern);
  });

  it('fails closed and still writes the artifact when high findings remain open', () => {
    const { result, report } = run('testdata/security-assessment/synthetic-blocked-open-high-metadata-v1.json');
    expect(result.status).toBe(1);
    expect(Object.keys(report).sort()).toEqual(allowed);
    expect(report.verdict).toBe('BLOCKED');
    expect(report.errorCode).toBe('OPEN_CRITICAL_OR_HIGH_FINDINGS');
    expect(report.aggregateFindingCounts.high.open).toBe(1);
    expect(report.selectedDeployment.exactBinding).toBe(true);
  });

  it.each([
    ['MISSING_EXACT_SELECTED_DEPLOYMENT_BINDING', { ...readyMetadata, selectedDeployment: { ...readyMetadata.selectedDeployment, exactBinding: false } }],
    ['MISSING_INDEPENDENT_ASSESSOR_ATTESTATION', { ...readyMetadata, assessorAttestation: { ...readyMetadata.assessorAttestation, independent: false } }],
    ['INVALID_SCOPE_CATEGORIES', { ...readyMetadata, scopeCategories: readyMetadata.scopeCategories.slice(1) }],
    ['INVALID_SCOPE_CATEGORIES', { ...readyMetadata, scopeCategories: [...readyMetadata.scopeCategories, 'https://sensitive.example.invalid'] }],
    ['MISSING_EXTERNAL_EVIDENCE', { ...readyMetadata, externalEvidence: { ...readyMetadata.externalEvidence, assessorAttestationReceived: false } }],
    ['FORBIDDEN_RAW_EVIDENCE_KEY', { ...readyMetadata, rawFindings: ['must-not-enter-report'] }],
  ])('fails closed with %s and redacts unvalidated metadata', (errorCode, metadata) => {
    const { result, report, raw } = runMetadata(metadata);
    expect(result.status).toBe(1);
    expect(report.verdict).toBe('BLOCKED');
    expect(report.errorCode).toBe(errorCode);
    expect(report.selectedDeployment.exactBinding).toBe(false);
    expect(report.assessorAttestation.independent).toBe(false);
    expect(raw).not.toContain('must-not-enter-report');
  });

  it('package command writes the canonical artifact with the synthetic CI fixture', () => {
    const dir = mkdtempSync(join(tmpdir(), 't908-package-'));
    const out = join(dir, 'security-assessment-readiness-report-v1.json');
    execFileSync('corepack', ['pnpm', 'security-assessment:readiness'], { env: { ...process.env, SECURITY_ASSESSMENT_READINESS_REPORT_PATH: out }, stdio: 'pipe' });
    const report = JSON.parse(readFileSync(out, 'utf8'));
    expect(report.verdict).toBe('READY_FOR_ASSESSMENT');
  });
});
