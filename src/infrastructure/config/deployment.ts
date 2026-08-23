import { z } from 'zod';

export const deploymentStageSchema = z.enum(['synthetic', 'pilot', 'production']);
export type DeploymentStage = z.infer<typeof deploymentStageSchema>;
export type EnvironmentSource = Record<string, string | undefined>;

const liveEvidenceSchema = z.object({
  DEPLOYMENT_STAGE: deploymentStageSchema.default('synthetic'),
  PUBLIC_BASE_URL: z.string().url().optional(),
  DEPLOYMENT_AUTHORITY_REF: z.string().min(3).optional(),
  LEGAL_NOTICE_APPROVAL_REF: z.string().min(3).optional(),
  DATA_RETENTION_APPROVAL_REF: z.string().min(3).optional(),
  FCRA_ROLE_APPROVAL_REF: z.string().min(3).optional(),
  PRIVACY_ROLE_APPROVAL_REF: z.string().min(3).optional(),
  SECURITY_REVIEW_REF: z.string().min(3).optional(),
  INCIDENT_RESPONSE_OWNER: z.string().min(3).optional(),
  LIVE_PROVIDER_BINDINGS_VERIFIED: z.enum(['true', 'false']).default('false'),
  LIVE_CARRIER_PROGRAMS_VERIFIED: z.enum(['true', 'false']).default('false'),
});

export type DeploymentControlEnvironment = z.infer<typeof liveEvidenceSchema>;

const liveRequiredKeys = [
  'PUBLIC_BASE_URL',
  'DEPLOYMENT_AUTHORITY_REF',
  'LEGAL_NOTICE_APPROVAL_REF',
  'DATA_RETENTION_APPROVAL_REF',
  'FCRA_ROLE_APPROVAL_REF',
  'PRIVACY_ROLE_APPROVAL_REF',
  'SECURITY_REVIEW_REF',
  'INCIDENT_RESPONSE_OWNER',
] as const;

export type DeploymentBlocker =
  | `MISSING_${(typeof liveRequiredKeys)[number]}`
  | 'LIVE_PROVIDER_BINDINGS_NOT_VERIFIED'
  | 'LIVE_CARRIER_PROGRAMS_NOT_VERIFIED';

export type DeploymentReadiness = {
  stage: DeploymentStage;
  ready: boolean;
  blockers: DeploymentBlocker[];
};

export function getDeploymentControlEnvironment(
  source: EnvironmentSource = process.env,
): DeploymentControlEnvironment {
  const parsed = liveEvidenceSchema.safeParse(source);
  if (!parsed.success) {
    throw new Error('DEPLOYMENT_CONTROL_ENVIRONMENT_INVALID');
  }
  return parsed.data;
}

export function assessDeploymentReadiness(
  source: EnvironmentSource = process.env,
): DeploymentReadiness {
  const environment = getDeploymentControlEnvironment(source);
  if (environment.DEPLOYMENT_STAGE === 'synthetic') {
    return { stage: 'synthetic', ready: true, blockers: [] };
  }

  const blockers: DeploymentBlocker[] = [];
  for (const key of liveRequiredKeys) {
    if (!environment[key]) {
      blockers.push(`MISSING_${key}` as DeploymentBlocker);
    }
  }
  if (environment.LIVE_PROVIDER_BINDINGS_VERIFIED !== 'true') {
    blockers.push('LIVE_PROVIDER_BINDINGS_NOT_VERIFIED');
  }
  if (environment.LIVE_CARRIER_PROGRAMS_VERIFIED !== 'true') {
    blockers.push('LIVE_CARRIER_PROGRAMS_NOT_VERIFIED');
  }

  return {
    stage: environment.DEPLOYMENT_STAGE,
    ready: blockers.length === 0,
    blockers,
  };
}

export function assertAdapterAllowedForDeployment(
  adapterId: string,
  source: EnvironmentSource = process.env,
): void {
  const environment = getDeploymentControlEnvironment(source);
  if (environment.DEPLOYMENT_STAGE !== 'synthetic' && adapterId.startsWith('synthetic-')) {
    throw new Error('SYNTHETIC_ADAPTER_FORBIDDEN_IN_LIVE_STAGE');
  }
}

export function requireLiveDeploymentReady(
  source: EnvironmentSource = process.env,
): DeploymentReadiness {
  const readiness = assessDeploymentReadiness(source);
  if (readiness.stage !== 'synthetic' && !readiness.ready) {
    throw new Error(`LIVE_DEPLOYMENT_BLOCKED:${readiness.blockers.join(',')}`);
  }
  return readiness;
}
