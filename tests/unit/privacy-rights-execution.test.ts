import { describe, expect, it } from 'vitest';

import { applyPrivacyCorrections } from '@/src/application/privacy/privacy-rights-execution';
import { resolvePrivacyRightsExecutionPolicy } from '@/src/infrastructure/privacy/privacy-rights-execution-policy';
import {
  privacyRightsExecutionRequestHash,
  protectConsumerIdentity,
  unprotectJsonPayload,
  type ConsumerIdentityPayload,
} from '@/src/infrastructure/security/identity-protection';

const identityEnvironment = {
  IDENTITY_ENCRYPTION_KEY_B64: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  IDENTITY_ENCRYPTION_KEY_VERSION: 'test-key-v1',
  IDENTITY_LOOKUP_PEPPER: '0123456789abcdef0123456789abcdef',
};

const identity: ConsumerIdentityPayload = {
  firstName: 'Avery',
  lastName: 'Example',
  dateOfBirth: '1990-01-01',
  email: 'avery@example.test',
  phone: '+14155550100',
  address: {
    line1: '1 Test Way', city: 'Oakland', state: 'CA', postalCode: '94612',
  },
};

describe('privacy rights execution', () => {
  it('merges only supplied corrections and re-protects the complete identity', () => {
    Object.assign(process.env, identityEnvironment);
    const corrected = applyPrivacyCorrections(identity, {
      email: 'corrected@example.test',
      address: { ...identity.address, line1: '2 Corrected Way' },
    });
    const protectedIdentity = protectConsumerIdentity(corrected);
    expect(protectedIdentity.pgBytea).not.toContain('corrected@example.test');
    expect(unprotectJsonPayload(
      protectedIdentity.pgBytea,
      protectedIdentity.keyVersion,
    )).toEqual({
      ...identity,
      email: 'corrected@example.test',
      address: { ...identity.address, line1: '2 Corrected Way' },
    });
  });

  it('binds idempotency evidence to correction values without exposing them', () => {
    Object.assign(process.env, identityEnvironment);
    const first = privacyRightsExecutionRequestHash({
      privacyRequestId: 'request-id',
      idempotencyKey: 'idempotency-id',
      policyVersion: 'synthetic-privacy-rights-v1',
      corrections: { email: 'first@example.test' },
    });
    const second = privacyRightsExecutionRequestHash({
      privacyRequestId: 'request-id',
      idempotencyKey: 'idempotency-id',
      policyVersion: 'synthetic-privacy-rights-v1',
      corrections: { email: 'second@example.test' },
    });
    expect(first).toMatch(/^[0-9a-f]{64}$/);
    expect(first).not.toBe(second);
    expect(first).not.toContain('first@example.test');
  });

  it('fails closed outside the explicit synthetic policy', () => {
    expect(resolvePrivacyRightsExecutionPolicy({
      DEPLOYMENT_STAGE: 'synthetic',
      PRIVACY_RIGHTS_EXECUTION_POLICY_VERSION: 'synthetic-privacy-rights-v1',
    })).toEqual({
      policyVersion: 'synthetic-privacy-rights-v1',
      certificationState: 'SYNTHETIC',
    });
    expect(() => resolvePrivacyRightsExecutionPolicy({
      DEPLOYMENT_STAGE: 'production',
      PRIVACY_RIGHTS_EXECUTION_POLICY_VERSION: 'synthetic-privacy-rights-v1',
    })).toThrow('PRIVACY_RIGHTS_EXECUTION_POLICY_NOT_CONFIGURED');
  });
});
