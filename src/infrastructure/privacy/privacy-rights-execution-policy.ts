import { z } from 'zod';

import type { PrivacyRightsExecutionPolicyDescriptor } from '@/src/domain/privacy';
import {
  getDeploymentControlEnvironment,
  type EnvironmentSource,
} from '@/src/infrastructure/config/deployment';

const policyEnvironmentSchema = z.object({
  PRIVACY_RIGHTS_EXECUTION_POLICY_VERSION: z.string().min(3).max(100),
});

const SYNTHETIC_POLICY_VERSION = 'synthetic-privacy-rights-v1';

export function resolvePrivacyRightsExecutionPolicy(
  source: EnvironmentSource = process.env,
): PrivacyRightsExecutionPolicyDescriptor {
  const deployment = getDeploymentControlEnvironment(source);
  const parsed = policyEnvironmentSchema.safeParse(source);
  if (
    parsed.success
    && deployment.DEPLOYMENT_STAGE === 'synthetic'
    && parsed.data.PRIVACY_RIGHTS_EXECUTION_POLICY_VERSION === SYNTHETIC_POLICY_VERSION
  ) {
    return {
      policyVersion: SYNTHETIC_POLICY_VERSION,
      certificationState: 'SYNTHETIC',
    };
  }
  throw new Error('PRIVACY_RIGHTS_EXECUTION_POLICY_NOT_CONFIGURED');
}
