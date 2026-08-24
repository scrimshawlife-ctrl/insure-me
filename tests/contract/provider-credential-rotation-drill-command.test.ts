import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';

import { describe, expect, it } from 'vitest';

import {
  rotateProviderCredential,
  type CredentialRotationState,
  type ProviderCredentialRotationPort,
} from '@/src/application/operations/provider-credential-rotation';

const reportPath = process.env.PROVIDER_CREDENTIAL_ROTATION_DRILL_REPORT_PATH;

async function writeReport(report: unknown): Promise<void> {
  if (!reportPath) return;
  await mkdir(dirname(reportPath), { recursive: true });
  await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
}

describe('provider credential rotation drill command', () => {
  it('rotates a synthetic credential without exposing credential material', async () => {
    const startedAt = new Date();
    const startedPerformance = performance.now();
    const events: Array<{ action: string; version: string }> = [];
    let state: CredentialRotationState = {
      currentVersion: 'synthetic-provider-v1', standbyVersion: null, previousVersion: null,
    };
    const accepted = new Set(['synthetic-provider-v1', 'synthetic-provider-v2']);

    const port: ProviderCredentialRotationPort = {
      readState: async () => ({ ...state }),
      stage: async ({ version }) => { state = { ...state, standbyVersion: version }; },
      validate: async ({ version }) => accepted.has(version) ? 'VALID' : 'REJECTED',
      activate: async ({ version }) => {
        state = { currentVersion: version, standbyVersion: null, previousVersion: state.currentVersion };
      },
      verifyActive: async ({ version }) => state.currentVersion === version && accepted.has(version) ? 'VALID' : 'REJECTED',
      revoke: async ({ version }) => {
        accepted.delete(version);
        if (state.previousVersion === version) state = { ...state, previousVersion: null };
      },
      rollback: async ({ version }) => { state = { currentVersion: version, standbyVersion: null, previousVersion: null }; },
      recordAudit: async (event) => { events.push(event); },
    };

    const failure = {
      schemaVersion: 'provider-credential-rotation-drill-report-v1',
      reliabilityContractVersion: 'reliability-v1',
      startedAt: startedAt.toISOString(), completedAt: new Date().toISOString(),
      observed: null, liveProviderVerified: false, hostedSecretStoreVerified: false,
      errorCode: 'PROVIDER_CREDENTIAL_ROTATION_DRILL_INCOMPLETE', passed: false,
    };
    await writeReport(failure);

    const result = await rotateProviderCredential({
      port,
      newVersion: 'synthetic-provider-v2',
      newCredential: 'synthetic-credential-material-v2-0000000000',
    });

    let rollbackInvoked = false;
    const rollbackPort: ProviderCredentialRotationPort = {
      readState: async () => ({ currentVersion: 'synthetic-provider-v1', standbyVersion: null, previousVersion: null }),
      stage: async () => undefined,
      validate: async () => 'VALID',
      activate: async () => undefined,
      verifyActive: async () => 'REJECTED',
      revoke: async () => { throw new Error('PREVIOUS_CREDENTIAL_REVOKED_BEFORE_VERIFICATION'); },
      rollback: async () => { rollbackInvoked = true; },
      recordAudit: async () => undefined,
    };
    const rollbackResult = await rotateProviderCredential({
      port: rollbackPort,
      newVersion: 'synthetic-provider-v2',
      newCredential: 'synthetic-credential-material-v2-0000000000',
    });

    const report = {
      ...failure,
      completedAt: new Date().toISOString(),
      observed: {
        sequence: events.map((event) => event.action),
        previousVersion: result.previousVersion,
        activeVersion: result.activeVersion,
        activeCredentialValid: state.currentVersion === 'synthetic-provider-v2',
        previousCredentialRejected: !accepted.has('synthetic-provider-v1'),
        oldCredentialRevoked: result.oldCredentialRevoked,
        rollbackPathTested: rollbackInvoked && rollbackResult.status === 'ROLLED_BACK',
        auditEventCount: events.length,
        elapsedMilliseconds: Number((performance.now() - startedPerformance).toFixed(2)),
      },
      errorCode: null,
      passed:
        result.status === 'ROTATED' &&
        !accepted.has('synthetic-provider-v1') &&
        rollbackInvoked &&
        rollbackResult.status === 'ROLLED_BACK',
    };
    await writeReport(report);

    expect(report.passed).toBe(true);
    expect(report.observed.rollbackPathTested).toBe(true);
    expect(JSON.stringify(report)).not.toContain('synthetic-credential-material');
    expect(events.map((event) => event.action)).toEqual(['STAGED', 'ACTIVATED', 'REVOKED']);
  });
});
