export const incidentResponseStages = [
  'DETECT',
  'CONTAIN',
  'PRESERVE_EVIDENCE',
  'REVOKE_OR_ROTATE_CREDENTIALS',
  'IDENTIFY_AFFECTED_SCOPE',
  'LEGAL_COMPLIANCE_ASSESSMENT',
  'NOTIFICATION_DECISION',
  'ERADICATE_AND_RECOVER',
  'VALIDATE_CONTROLS',
  'CORRECTIVE_ACTIONS',
] as const;

export type IncidentResponseStage = (typeof incidentResponseStages)[number];
export type IncidentImpact = 'CONFIDENTIALITY' | 'INTEGRITY' | 'AVAILABILITY' | 'REGULATED_DATA_ACCESS';

export type IncidentTabletopScenario = {
  scenarioId: string;
  detectedImpacts: IncidentImpact[];
  affectedSystems: string[];
  credentialCompromiseSuspected: boolean;
  credentialActionCompleted: boolean;
  regulatedDataAccessSuspected: boolean;
};

export type IncidentTabletopAction = {
  stage: IncidentResponseStage;
  status: 'COMPLETED' | 'PENDING_LEGAL_REVIEW';
  reasonCode: string;
};

export type IncidentTabletopResult = {
  scenarioId: string;
  severity: 'P0' | 'P1';
  releaseFrozen: true;
  liveIntegrationsFrozen: true;
  evidencePreserved: true;
  unsafeCredentialsRevokedOrRotated: boolean;
  notificationDecision: 'PENDING_LEGAL_REVIEW';
  recoveryAuthorized: false;
  actions: IncidentTabletopAction[];
};

function validateScenario(scenario: IncidentTabletopScenario): void {
  if (!/^[a-z0-9][a-z0-9._-]{0,63}$/i.test(scenario.scenarioId)) {
    throw new Error('INCIDENT_SCENARIO_ID_INVALID');
  }
  if (scenario.detectedImpacts.length === 0 || scenario.affectedSystems.length === 0) {
    throw new Error('INCIDENT_SCENARIO_INCOMPLETE');
  }
}

export function runIncidentResponseTabletop(
  scenario: IncidentTabletopScenario,
): IncidentTabletopResult {
  validateScenario(scenario);
  const severity = scenario.regulatedDataAccessSuspected ? 'P0' : 'P1';
  if (scenario.credentialActionCompleted && !scenario.credentialCompromiseSuspected) {
    throw new Error('INCIDENT_CREDENTIAL_ACTION_UNJUSTIFIED');
  }
  const credentialActionCompleted = scenario.credentialActionCompleted;

  const actions: IncidentTabletopAction[] = [
    { stage: 'DETECT', status: 'COMPLETED', reasonCode: 'INCIDENT_SIGNAL_CONFIRMED' },
    { stage: 'CONTAIN', status: 'COMPLETED', reasonCode: 'TRAFFIC_AND_LIVE_INTEGRATIONS_FROZEN' },
    { stage: 'PRESERVE_EVIDENCE', status: 'COMPLETED', reasonCode: 'FORENSIC_EVIDENCE_PRESERVED' },
    {
      stage: 'REVOKE_OR_ROTATE_CREDENTIALS',
      status: 'COMPLETED',
      reasonCode: credentialActionCompleted ? 'SUSPECTED_CREDENTIAL_ROTATED' : 'NO_CREDENTIAL_COMPROMISE_SIGNAL',
    },
    { stage: 'IDENTIFY_AFFECTED_SCOPE', status: 'COMPLETED', reasonCode: 'AFFECTED_SCOPE_INVENTORIED' },
    { stage: 'LEGAL_COMPLIANCE_ASSESSMENT', status: 'PENDING_LEGAL_REVIEW', reasonCode: 'LEGAL_FACT_ASSESSMENT_REQUIRED' },
    { stage: 'NOTIFICATION_DECISION', status: 'PENDING_LEGAL_REVIEW', reasonCode: 'NOTIFICATION_NOT_AUTOMATICALLY_DETERMINED' },
    { stage: 'ERADICATE_AND_RECOVER', status: 'COMPLETED', reasonCode: 'CONTROLLED_RECOVERY_REHEARSED' },
    { stage: 'VALIDATE_CONTROLS', status: 'COMPLETED', reasonCode: 'SECURITY_CONTROLS_REVALIDATED' },
    { stage: 'CORRECTIVE_ACTIONS', status: 'COMPLETED', reasonCode: 'CORRECTIVE_ACTIONS_RECORDED' },
  ];

  return {
    scenarioId: scenario.scenarioId,
    severity,
    releaseFrozen: true,
    liveIntegrationsFrozen: true,
    evidencePreserved: true,
    unsafeCredentialsRevokedOrRotated: credentialActionCompleted,
    notificationDecision: 'PENDING_LEGAL_REVIEW',
    recoveryAuthorized: false,
    actions,
  };
}
