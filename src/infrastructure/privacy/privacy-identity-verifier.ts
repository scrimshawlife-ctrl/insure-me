import { createHash } from 'node:crypto';

import { z } from 'zod';

import type {
  PrivacyIdentityVerifier,
  PrivacyIdentityVerificationResult,
} from '@/src/domain/privacy';
import {
  assertAdapterAllowedForDeployment,
  getDeploymentControlEnvironment,
  type EnvironmentSource,
} from '@/src/infrastructure/config/deployment';

const privacyIdentityEnvironmentSchema = z.object({
  PRIVACY_IDENTITY_ADAPTER_ID: z.string().min(3).max(100),
  PRIVACY_IDENTITY_POLICY_VERSION: z.string().min(3).max(100),
});

const SYNTHETIC_ADAPTER_ID = 'synthetic-privacy-identity-v1';
const SYNTHETIC_ADAPTER_VERSION = '1.0.0';
const SYNTHETIC_ASSERTION = 'SYNTHETIC-PRIVACY-VERIFIED';

class SyntheticPrivacyIdentityVerifier implements PrivacyIdentityVerifier {
  constructor(private readonly policyVersion: string) {}

  descriptor() {
    return {
      adapterId: SYNTHETIC_ADAPTER_ID,
      adapterVersion: SYNTHETIC_ADAPTER_VERSION,
      policyVersion: this.policyVersion,
      certificationState: 'SYNTHETIC' as const,
    };
  }

  async verify(input: {
    privacyRequestId: string;
    assertion: string;
  }): Promise<PrivacyIdentityVerificationResult> {
    const accepted = input.assertion === SYNTHETIC_ASSERTION;
    const evidenceDigest = createHash('sha256')
      .update(`${SYNTHETIC_ADAPTER_ID}|${input.privacyRequestId}|${accepted}`)
      .digest('hex')
      .slice(0, 32);

    return {
      outcome: accepted ? 'VERIFIED' : 'FAILED',
      evidenceRef: `synthetic-privacy-evidence:${evidenceDigest}`,
      reasonCodes: [accepted ? 'SYNTHETIC_ASSERTION_ACCEPTED' : 'ASSERTION_INVALID'],
    };
  }
}

export function resolvePrivacyIdentityVerifier(
  source: EnvironmentSource = process.env,
): PrivacyIdentityVerifier {
  const deployment = getDeploymentControlEnvironment(source);
  const parsed = privacyIdentityEnvironmentSchema.safeParse(source);
  if (!parsed.success) {
    throw new Error('PRIVACY_IDENTITY_VERIFIER_NOT_CONFIGURED');
  }

  assertAdapterAllowedForDeployment(parsed.data.PRIVACY_IDENTITY_ADAPTER_ID, source);

  if (
    deployment.DEPLOYMENT_STAGE === 'synthetic'
    && parsed.data.PRIVACY_IDENTITY_ADAPTER_ID === SYNTHETIC_ADAPTER_ID
  ) {
    return new SyntheticPrivacyIdentityVerifier(
      parsed.data.PRIVACY_IDENTITY_POLICY_VERSION,
    );
  }

  throw new Error('PRIVACY_IDENTITY_VERIFIER_NOT_CONFIGURED');
}

