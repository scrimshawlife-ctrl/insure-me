import { describe, expect, it } from 'vitest';

import { incidentResponseStages, runIncidentResponseTabletop } from './incident-response-tabletop';

describe('runIncidentResponseTabletop', () => {
  it('freezes release and integrations for suspected regulated-data credential misuse', () => {
    const result = runIncidentResponseTabletop({
      scenarioId: 'synthetic-provider-credential-exposure',
      detectedImpacts: ['CONFIDENTIALITY', 'REGULATED_DATA_ACCESS'],
      affectedSystems: ['provider-gateway', 'audit-pipeline'],
      credentialCompromiseSuspected: true,
      credentialActionCompleted: true,
      regulatedDataAccessSuspected: true,
    });

    expect(result).toMatchObject({
      severity: 'P0', releaseFrozen: true, liveIntegrationsFrozen: true,
      evidencePreserved: true, unsafeCredentialsRevokedOrRotated: true,
      notificationDecision: 'PENDING_LEGAL_REVIEW', recoveryAuthorized: false,
    });
    expect(result.actions.map((action) => action.stage)).toEqual(incidentResponseStages);
  });

  it('does not invent notification duties or credential compromise', () => {
    const result = runIncidentResponseTabletop({
      scenarioId: 'synthetic-availability-incident',
      detectedImpacts: ['AVAILABILITY'],
      affectedSystems: ['provider-gateway'],
      credentialCompromiseSuspected: false,
      credentialActionCompleted: false,
      regulatedDataAccessSuspected: false,
    });
    expect(result.severity).toBe('P1');
    expect(result.unsafeCredentialsRevokedOrRotated).toBe(false);
    expect(result.actions.find((action) => action.stage === 'NOTIFICATION_DECISION')).toEqual({
      stage: 'NOTIFICATION_DECISION',
      status: 'PENDING_LEGAL_REVIEW',
      reasonCode: 'NOTIFICATION_NOT_AUTOMATICALLY_DETERMINED',
    });
  });

  it('rejects incomplete scenarios', () => {
    expect(() => runIncidentResponseTabletop({
      scenarioId: 'incomplete', detectedImpacts: [], affectedSystems: [],
      credentialCompromiseSuspected: false, regulatedDataAccessSuspected: false,
      credentialActionCompleted: false,
    })).toThrow('INCIDENT_SCENARIO_INCOMPLETE');
  });
});
