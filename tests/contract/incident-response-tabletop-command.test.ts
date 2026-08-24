import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';

import { describe, expect, it } from 'vitest';

import {
  incidentResponseStages,
  runIncidentResponseTabletop,
} from '@/src/application/operations/incident-response-tabletop';
import {
  rotateProviderCredential,
  type ProviderCredentialRotationPort,
} from '@/src/application/operations/provider-credential-rotation';

const reportPath = process.env.INCIDENT_RESPONSE_TABLETOP_REPORT_PATH?.trim();

async function writeReport(report: unknown): Promise<void> {
  if (!reportPath) return;
  await mkdir(dirname(reportPath), { recursive: true });
  await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
}

describe('incident response tabletop command', () => {
  it('rehearses the canonical synthetic credential-exposure scenario', async () => {
    const startedAt = new Date();
    const startedPerformance = performance.now();
    const failure = {
      schemaVersion: 'incident-response-tabletop-report-v1',
      reliabilityContractVersion: 'reliability-v1',
      scenarioId: 'synthetic-provider-credential-exposure',
      startedAt: startedAt.toISOString(), completedAt: new Date().toISOString(),
      observed: null, productionResponseVerified: false, legalDecisionVerified: false,
      errorCode: 'INCIDENT_RESPONSE_TABLETOP_INCOMPLETE', passed: false,
    };
    await writeReport(failure);

    let activeVersion = 'synthetic-provider-v1';
    const acceptedVersions = new Set(['synthetic-provider-v1', 'synthetic-provider-v2']);
    const rotationPort: ProviderCredentialRotationPort = {
      readState: async () => ({ currentVersion: activeVersion, standbyVersion: null, previousVersion: null }),
      stage: async () => undefined,
      validate: async ({ version }) => acceptedVersions.has(version) ? 'VALID' : 'REJECTED',
      activate: async ({ version }) => { activeVersion = version; },
      verifyActive: async ({ version }) => activeVersion === version ? 'VALID' : 'REJECTED',
      revoke: async ({ version }) => { acceptedVersions.delete(version); },
      rollback: async ({ version }) => { activeVersion = version; },
      recordAudit: async () => undefined,
    };
    const rotation = await rotateProviderCredential({
      port: rotationPort,
      newVersion: 'synthetic-provider-v2',
      newCredential: 'synthetic-credential-material-v2-0000000000',
    });

    const result = runIncidentResponseTabletop({
      scenarioId: failure.scenarioId,
      detectedImpacts: ['CONFIDENTIALITY', 'REGULATED_DATA_ACCESS'],
      affectedSystems: ['provider-gateway', 'audit-pipeline'],
      credentialCompromiseSuspected: true,
      credentialActionCompleted: rotation.status === 'ROTATED' && rotation.oldCredentialRevoked,
      regulatedDataAccessSuspected: true,
    });
    const orderedStages = result.actions.map((action) => action.stage);
    const passed = result.severity === 'P0'
      && result.releaseFrozen
      && result.liveIntegrationsFrozen
      && result.evidencePreserved
      && result.unsafeCredentialsRevokedOrRotated
      && result.notificationDecision === 'PENDING_LEGAL_REVIEW'
      && !result.recoveryAuthorized
      && JSON.stringify(orderedStages) === JSON.stringify(incidentResponseStages);

    const report = {
      ...failure,
      completedAt: new Date().toISOString(),
      observed: {
        severity: result.severity,
        releaseFrozen: result.releaseFrozen,
        liveIntegrationsFrozen: result.liveIntegrationsFrozen,
        evidencePreserved: result.evidencePreserved,
        credentialAction: result.unsafeCredentialsRevokedOrRotated ? 'ROTATED_OR_REVOKED' : 'NOT_REQUIRED',
        affectedSystemCount: 2,
        stages: result.actions,
        notificationDecision: result.notificationDecision,
        recoveryAuthorized: result.recoveryAuthorized,
        elapsedMilliseconds: Number((performance.now() - startedPerformance).toFixed(2)),
      },
      errorCode: null,
      passed,
    };
    await writeReport(report);

    expect(report.passed).toBe(true);
    expect(JSON.stringify(report)).not.toMatch(/credential-material|consumer|driver|license|date-of-birth/i);
  });
});
