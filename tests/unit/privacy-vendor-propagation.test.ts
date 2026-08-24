import { describe, expect, it } from 'vitest';

import { resolvePrivacyPropagationAdapter } from '@/src/infrastructure/privacy/privacy-propagation-adapter';
import { privacyPropagationRequestHash } from '@/src/infrastructure/security/identity-protection';

const identityEnvironment = {
  IDENTITY_ENCRYPTION_KEY_B64: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  IDENTITY_ENCRYPTION_KEY_VERSION: 'test-key-v1',
  IDENTITY_LOOKUP_PEPPER: '0123456789abcdef0123456789abcdef',
};

const syntheticEnvironment = {
  DEPLOYMENT_STAGE: 'synthetic',
  PRIVACY_PROPAGATION_ADAPTER_ID: 'synthetic-privacy-propagation-v1',
  PRIVACY_PROPAGATION_POLICY_VERSION: 'synthetic-privacy-propagation-policy-v1',
};

describe('privacy vendor propagation', () => {
  it('returns deterministic opaque completion evidence', async () => {
    const adapter = resolvePrivacyPropagationAdapter(syntheticEnvironment);
    const first = await adapter.propagate({
      privacyRequestId: 'request-1',
      propagationTargetId: 'target-1',
      action: 'DELETE',
    });
    const second = await adapter.propagate({
      privacyRequestId: 'request-1',
      propagationTargetId: 'target-1',
      action: 'DELETE',
    });
    expect(first).toEqual(second);
    expect(first.outcome).toBe('COMPLETED');
    expect(first.evidenceRef).toMatch(/^synthetic-privacy-propagation:[0-9a-f]{32}$/);
    expect(first.evidenceRef).not.toContain('request-1');
  });

  it('binds attempt evidence to target, adapter, policy, and action', () => {
    Object.assign(process.env, identityEnvironment);
    const base = {
      privacyRequestId: 'request-1',
      propagationTargetId: 'target-1',
      idempotencyKey: 'attempt-1',
      adapterId: 'synthetic-privacy-propagation-v1',
      adapterVersion: '1.0.0',
      policyVersion: 'synthetic-privacy-propagation-policy-v1',
      action: 'DELETE',
    };
    const first = privacyPropagationRequestHash(base);
    const second = privacyPropagationRequestHash({ ...base, action: 'RESTRICT' });
    expect(first).toMatch(/^[0-9a-f]{64}$/);
    expect(first).not.toBe(second);
    expect(first).not.toContain('target-1');
  });

  it('fails closed outside the explicit synthetic configuration', () => {
    expect(resolvePrivacyPropagationAdapter(syntheticEnvironment).descriptor()).toEqual({
      adapterId: 'synthetic-privacy-propagation-v1',
      adapterVersion: '1.0.0',
      policyVersion: 'synthetic-privacy-propagation-policy-v1',
      certificationState: 'SYNTHETIC',
    });
    expect(() => resolvePrivacyPropagationAdapter({
      ...syntheticEnvironment,
      DEPLOYMENT_STAGE: 'production',
    })).toThrow('PRIVACY_PROPAGATION_ADAPTER_NOT_CONFIGURED');
  });
});
