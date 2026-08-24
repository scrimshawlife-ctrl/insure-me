import { z } from 'zod';

import type { PrivacyExportPolicyDescriptor } from '@/src/domain/privacy';
import {
  getDeploymentControlEnvironment,
  type EnvironmentSource,
} from '@/src/infrastructure/config/deployment';

const policyEnvironmentSchema = z.object({
  PRIVACY_EXPORT_POLICY_VERSION: z.string().min(3).max(100),
});

const SYNTHETIC_POLICY_VERSION = 'synthetic-privacy-export-v1';

export function resolvePrivacyExportPolicy(
  source: EnvironmentSource = process.env,
): PrivacyExportPolicyDescriptor {
  const deployment = getDeploymentControlEnvironment(source);
  const parsed = policyEnvironmentSchema.safeParse(source);
  if (!parsed.success) {
    throw new Error('PRIVACY_EXPORT_POLICY_NOT_CONFIGURED');
  }

  if (
    deployment.DEPLOYMENT_STAGE === 'synthetic'
    && parsed.data.PRIVACY_EXPORT_POLICY_VERSION === SYNTHETIC_POLICY_VERSION
  ) {
    return {
      policyVersion: SYNTHETIC_POLICY_VERSION,
      exportSchemaVersion: 'privacy-export-v1',
      certificationState: 'SYNTHETIC',
    };
  }

  throw new Error('PRIVACY_EXPORT_POLICY_NOT_CONFIGURED');
}
