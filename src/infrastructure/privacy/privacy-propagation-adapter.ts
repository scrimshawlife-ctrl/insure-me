import { createHash } from 'node:crypto';

import { z } from 'zod';

import type {
  PrivacyPropagationAdapter,
  PrivacyPropagationAdapterDescriptor,
} from '@/src/domain/privacy';
import {
  getDeploymentControlEnvironment,
  type EnvironmentSource,
} from '@/src/infrastructure/config/deployment';

const environmentSchema = z.object({
  PRIVACY_PROPAGATION_ADAPTER_ID: z.string().min(3).max(100),
  PRIVACY_PROPAGATION_POLICY_VERSION: z.string().min(3).max(100),
});

const SYNTHETIC_ADAPTER_ID = 'synthetic-privacy-propagation-v1';
const SYNTHETIC_POLICY_VERSION = 'synthetic-privacy-propagation-policy-v1';

class SyntheticPrivacyPropagationAdapter implements PrivacyPropagationAdapter {
  descriptor(): PrivacyPropagationAdapterDescriptor {
    return {
      adapterId: SYNTHETIC_ADAPTER_ID,
      adapterVersion: '1.0.0',
      policyVersion: SYNTHETIC_POLICY_VERSION,
      certificationState: 'SYNTHETIC',
    };
  }

  async propagate(input: Parameters<PrivacyPropagationAdapter['propagate']>[0]) {
    const digest = createHash('sha256')
      .update([
        input.privacyRequestId,
        input.propagationTargetId,
        input.action,
      ].join('|'))
      .digest('hex');
    return {
      outcome: 'COMPLETED' as const,
      evidenceRef: `synthetic-privacy-propagation:${digest.slice(0, 32)}`,
      reasonCodes: ['SYNTHETIC_VENDOR_ACKNOWLEDGED'],
    };
  }
}

export function resolvePrivacyPropagationAdapter(
  source: EnvironmentSource = process.env,
): PrivacyPropagationAdapter {
  const deployment = getDeploymentControlEnvironment(source);
  const parsed = environmentSchema.safeParse(source);
  if (
    parsed.success
    && deployment.DEPLOYMENT_STAGE === 'synthetic'
    && parsed.data.PRIVACY_PROPAGATION_ADAPTER_ID === SYNTHETIC_ADAPTER_ID
    && parsed.data.PRIVACY_PROPAGATION_POLICY_VERSION === SYNTHETIC_POLICY_VERSION
  ) {
    return new SyntheticPrivacyPropagationAdapter();
  }
  throw new Error('PRIVACY_PROPAGATION_ADAPTER_NOT_CONFIGURED');
}
