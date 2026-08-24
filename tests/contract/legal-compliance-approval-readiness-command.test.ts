import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

const script = 'scripts/compliance/legal-compliance-approval-readiness.mjs';
const allowed = [
  'schemaVersion', 'contractVersions', 'selectedDeployment', 'approvalDomains', 'controlDomains',
  'openQuestionBlockers', 'externalEvidence', 'timing', 'errorCode', 'verdict',
].sort();
const forbiddenArtifactPattern = /rawEvidence|evidencePayload|noticeBody|legalOpinion|contractBody|providerResponse|carrierResponse|password|jwt|stackTrace|deadline|certification/i;
const readyMetadata = JSON.parse(readFileSync('testdata/legal-compliance/synthetic-ready-metadata-v1.json', 'utf8'));
const reservedSentinels = ['UNVERIFIED', 'UNKNOWN', 'BLOCKED', 'NOT_COMPUTABLE', 'unverified'];

function run(input: string) {
  const dir = mkdtempSync(join(tmpdir(), 't911-'));
  const output = join(dir, 'legal-compliance-approval-readiness-report-v1.json');
  const result = spawnSync(process.execPath, [script], {
    env: { ...process.env, LEGAL_COMPLIANCE_APPROVAL_METADATA_PATH: input, LEGAL_COMPLIANCE_APPROVAL_REPORT_PATH: output },
    encoding: 'utf8',
  });
  return { result, report: JSON.parse(readFileSync(output, 'utf8')), raw: readFileSync(output, 'utf8') };
}
function runMetadata(metadata: unknown) {
  const dir = mkdtempSync(join(tmpdir(), 't911-input-'));
  const input = join(dir, 'metadata.json');
  writeFileSync(input, JSON.stringify(metadata));
  return run(input);
}

describe('T911 legal/compliance approval readiness validator', () => {
  it('produces only READY_FOR_APPROVAL_REVIEW for complete synthetic metadata', () => {
    const { result, report, raw } = run('testdata/legal-compliance/synthetic-ready-metadata-v1.json');
    expect(result.status).toBe(0);
    expect(Object.keys(report).sort()).toEqual(allowed);
    expect(report.contractVersions).toEqual({ acceptance: 'A-052', task: 'T911' });
    expect(report.verdict).toBe('READY_FOR_APPROVAL_REVIEW');
    expect(report.verdict).not.toMatch(/APPROVED|PASS|COMPLETE|CERTIFIED/i);
    expect(report.selectedDeployment.tenantConfiguration.configurationVersion).toBe('tc-version-synthetic-001');
    expect(report.approvalDomains).toHaveLength(6);
    expect(report.controlDomains).toHaveLength(13);
    expect(report.approvalDomains[0]).toMatchObject({
      environment: report.selectedDeployment.environment,
      deploymentRef: report.selectedDeployment.deploymentRef,
      ...report.selectedDeployment.tenantConfiguration,
    });
    expect(report.openQuestionBlockers.map((entry: { questionId: string }) => entry.questionId)).toEqual([
      'Q-001', 'Q-002', 'Q-003', 'Q-004', 'Q-005', 'Q-006', 'Q-007', 'Q-008', 'Q-009', 'Q-010',
    ]);
    expect(raw).not.toMatch(forbiddenArtifactPattern);
  });

  it.each(reservedSentinels)('rejects reserved deployment sentinel %s while emitting a sanitized blocked artifact', (sentinel) => {
    const metadata = {
      ...readyMetadata,
      selectedDeployment: { ...readyMetadata.selectedDeployment, deploymentRef: sentinel },
    };
    const { result, report } = runMetadata(metadata);
    expect(result.status).toBe(1);
    expect(report.errorCode).toBe('MISSING_EXACT_SELECTED_DEPLOYMENT_BINDING');
    expect(report.selectedDeployment.deploymentRef).toBe('UNVERIFIED');
  });

  it.each(reservedSentinels)('rejects reserved approval evidence sentinel %s while allowing UNVERIFIED in the blocked artifact', (sentinel) => {
    const metadata = {
      ...readyMetadata,
      approvalDomains: readyMetadata.approvalDomains.map((entry: Record<string, unknown>, index: number) => index === 0 ? { ...entry, evidenceRef: sentinel } : entry),
    };
    const { result, report } = runMetadata(metadata);
    expect(result.status).toBe(1);
    expect(report.errorCode).toBe('INVALID_APPROVAL_REFERENCE');
    expect(report.approvalDomains[0].evidenceRef).toBe('UNVERIFIED');
  });

  it.each([
    ['MISSING_APPROVAL_DOMAIN_EVIDENCE', 'approvalDomains', 'configurationVersion', 'tc-version-stale-000'],
    ['MISSING_APPROVAL_DOMAIN_EVIDENCE', 'approvalDomains', 'deploymentRef', 'deployment-other-002'],
    ['MISSING_CONTROL_DOMAIN_EVIDENCE', 'controlDomains', 'configurationVersion', 'tc-version-stale-000'],
    ['MISSING_CONTROL_DOMAIN_EVIDENCE', 'controlDomains', 'deploymentRef', 'deployment-other-002'],
    ['UNRESOLVED_OPEN_QUESTION_BLOCKER', 'openQuestionBlockers', 'configurationVersion', 'tc-version-stale-000'],
    ['UNRESOLVED_OPEN_QUESTION_BLOCKER', 'openQuestionBlockers', 'deploymentRef', 'deployment-other-002'],
  ])('rejects stale or cross-deployment %s binding in %s', (errorCode, category, field, value) => {
    const metadata = {
      ...readyMetadata,
      [category]: readyMetadata[category].map((entry: Record<string, unknown>, index: number) => index === 0 ? { ...entry, [field]: value } : entry),
    };
    const { result, report } = runMetadata(metadata);
    expect(result.status).toBe(1);
    expect(report.errorCode).toBe(errorCode);
  });

  it('fails closed for the synthetic unresolved open-question fixture', () => {
    const { result, report } = run('testdata/legal-compliance/synthetic-blocked-open-question-metadata-v1.json');
    expect(result.status).toBe(1);
    expect(report.verdict).toBe('BLOCKED');
    expect(report.errorCode).toBe('UNRESOLVED_OPEN_QUESTION_BLOCKER');
  });

  it.each([
    ['INVALID_METADATA_SHAPE', []],
    ['INVALID_TOP_LEVEL_KEYS', { ...readyMetadata, unexpected: true }],
    ['INVALID_SCHEMA_VERSION', { ...readyMetadata, schemaVersion: 'unexpected' }],
    ['MISSING_EXACT_SELECTED_DEPLOYMENT_BINDING', { ...readyMetadata, selectedDeployment: { ...readyMetadata.selectedDeployment, exactBinding: false } }],
    ['MISSING_EXACT_SELECTED_DEPLOYMENT_BINDING', { ...readyMetadata, selectedDeployment: { ...readyMetadata.selectedDeployment, tenantConfiguration: { ...readyMetadata.selectedDeployment.tenantConfiguration, configurationVersion: '' } } }],
    ['INVALID_APPROVAL_DOMAINS', { ...readyMetadata, approvalDomains: readyMetadata.approvalDomains.slice(1) }],
    ['INVALID_APPROVAL_DOMAINS', { ...readyMetadata, approvalDomains: readyMetadata.approvalDomains.map((entry: unknown, index: number) => index === 0 ? { ...(entry as object), extra: true } : entry) }],
    ['INVALID_APPROVAL_REFERENCE', { ...readyMetadata, approvalDomains: readyMetadata.approvalDomains.map((entry: Record<string, unknown>, index: number) => index === 0 ? { ...entry, authorityRef: 'https://not-opaque.invalid/path' } : entry) }],
    ['MISSING_APPROVAL_DOMAIN_EVIDENCE', { ...readyMetadata, approvalDomains: readyMetadata.approvalDomains.map((entry: Record<string, unknown>, index: number) => index === 0 ? { ...entry, evidencePresent: false } : entry) }],
    ['INVALID_CONTROL_DOMAINS', { ...readyMetadata, controlDomains: readyMetadata.controlDomains.slice(1) }],
    ['INVALID_CONTROL_EVIDENCE_REFERENCE', { ...readyMetadata, controlDomains: readyMetadata.controlDomains.map((entry: Record<string, unknown>, index: number) => index === 0 ? { ...entry, evidenceRef: 'unsafe ref' } : entry) }],
    ['INVALID_CONTROL_EVIDENCE_REFERENCE', { ...readyMetadata, controlDomains: readyMetadata.controlDomains.map((entry: Record<string, unknown>, index: number) => index === 0 ? { ...entry, evidenceRef: 'NOT_COMPUTABLE' } : entry) }],
    ['MISSING_CONTROL_DOMAIN_EVIDENCE', { ...readyMetadata, controlDomains: readyMetadata.controlDomains.map((entry: Record<string, unknown>, index: number) => index === 0 ? { ...entry, exactBinding: false } : entry) }],
    ['INVALID_OPEN_QUESTION_BLOCKERS', { ...readyMetadata, openQuestionBlockers: readyMetadata.openQuestionBlockers.slice(1) }],
    ['INVALID_OPEN_QUESTION_REFERENCE', { ...readyMetadata, openQuestionBlockers: readyMetadata.openQuestionBlockers.map((entry: Record<string, unknown>, index: number) => index === 0 ? { ...entry, ownerRef: '' } : entry) }],
    ['INVALID_OPEN_QUESTION_REFERENCE', { ...readyMetadata, openQuestionBlockers: readyMetadata.openQuestionBlockers.map((entry: Record<string, unknown>, index: number) => index === 0 ? { ...entry, evidenceRef: 'BLOCKED' } : entry) }],
    ['UNRESOLVED_OPEN_QUESTION_BLOCKER', { ...readyMetadata, openQuestionBlockers: readyMetadata.openQuestionBlockers.map((entry: Record<string, unknown>, index: number) => index === 0 ? { ...entry, exactBinding: false } : entry) }],
    ['MISSING_EXTERNAL_EVIDENCE', { ...readyMetadata, externalEvidence: { ...readyMetadata.externalEvidence, openQuestionDecisionMetadataReceived: false } }],
    ['FORBIDDEN_RAW_EVIDENCE_KEY', { ...readyMetadata, nested: { noticeBody: 'must-never-appear' } }],
    ['FORBIDDEN_RAW_EVIDENCE_KEY', { ...readyMetadata, nested: [{ RawEvidence: 'case-variant-must-never-appear' }] }],
  ])('fails closed with %s and emits safe opaque values', (errorCode, metadata) => {
    const { result, report, raw } = runMetadata(metadata);
    expect(result.status).toBe(1);
    expect(report.verdict).toBe('BLOCKED');
    expect(report.errorCode).toBe(errorCode);
    expect(Object.keys(report).sort()).toEqual(allowed);
    expect(raw).not.toContain('must-never-appear');
    expect(raw).not.toContain('case-variant-must-never-appear');
    expect(raw).not.toContain('https://not-opaque.invalid/path');
    expect(raw).not.toContain('unsafe ref');
    expect(report.approvalDomains.every((entry: { ownerRef: string; authorityRef: string; evidenceRef: string }) => [entry.ownerRef, entry.authorityRef, entry.evidenceRef].every((value) => /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(value)))).toBe(true);
  });

  it('writes a blocked sanitized artifact when input cannot be read', () => {
    const { result, report } = run('/missing/t911-metadata.json');
    expect(result.status).toBe(1);
    expect(report.errorCode).toBe('METADATA_READ_OR_PARSE_FAILED');
    expect(report.selectedDeployment.tenantConfiguration.configurationVersion).toBe('UNVERIFIED');
  });

  it('package command writes the canonical synthetic readiness artifact', () => {
    const dir = mkdtempSync(join(tmpdir(), 't911-package-'));
    const output = join(dir, 'legal-compliance-approval-readiness-report-v1.json');
    execFileSync('corepack', ['pnpm', 'legal-compliance:approval-readiness'], {
      env: { ...process.env, LEGAL_COMPLIANCE_APPROVAL_REPORT_PATH: output }, stdio: 'pipe',
    });
    expect(JSON.parse(readFileSync(output, 'utf8')).verdict).toBe('READY_FOR_APPROVAL_REVIEW');
  });
});
