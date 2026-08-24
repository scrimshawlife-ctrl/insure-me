import { describe, expect, it } from 'vitest';

import { resolvePrivacyIdentityVerifier } from '@/src/infrastructure/privacy/privacy-identity-verifier';

const syntheticEnvironment = {
  DEPLOYMENT_STAGE: 'synthetic',
  PRIVACY_IDENTITY_ADAPTER_ID: 'synthetic-privacy-identity-v1',
  PRIVACY_IDENTITY_POLICY_VERSION: 'synthetic-policy-v1',
};

describe('privacy identity verifier registry', () => {
  it('verifies the deterministic synthetic assertion with opaque evidence', async () => {
    const verifier = resolvePrivacyIdentityVerifier(syntheticEnvironment);
    const result = await verifier.verify({
      privacyRequestId: '10000000-0000-4000-8000-000000000001',
      assertion: 'SYNTHETIC-PRIVACY-VERIFIED',
    });

    expect(verifier.descriptor()).toEqual({
      adapterId: 'synthetic-privacy-identity-v1',
      adapterVersion: '1.0.0',
      policyVersion: 'synthetic-policy-v1',
      certificationState: 'SYNTHETIC',
    });
    expect(result).toEqual({
      outcome: 'VERIFIED',
      evidenceRef: expect.stringMatching(/^synthetic-privacy-evidence:[0-9a-f]{32}$/),
      reasonCodes: ['SYNTHETIC_ASSERTION_ACCEPTED'],
    });
  });

  it('returns a categorized failure without storing the assertion', async () => {
    const verifier = resolvePrivacyIdentityVerifier(syntheticEnvironment);
    const result = await verifier.verify({
      privacyRequestId: '10000000-0000-4000-8000-000000000001',
      assertion: 'incorrect-synthetic-assertion',
    });
    expect(result.outcome).toBe('FAILED');
    expect(result.reasonCodes).toEqual(['ASSERTION_INVALID']);
    expect(JSON.stringify(result)).not.toContain('incorrect-synthetic-assertion');
  });

  it('fails closed when no verifier is explicitly configured', () => {
    expect(() => resolvePrivacyIdentityVerifier({ DEPLOYMENT_STAGE: 'synthetic' }))
      .toThrow('PRIVACY_IDENTITY_VERIFIER_NOT_CONFIGURED');
  });

  it('forbids the synthetic verifier in pilot and production stages', () => {
    expect(() => resolvePrivacyIdentityVerifier({
      ...syntheticEnvironment,
      DEPLOYMENT_STAGE: 'production',
    })).toThrow('SYNTHETIC_ADAPTER_FORBIDDEN_IN_LIVE_STAGE');
  });
});

