import { describe, expect, it } from 'vitest';

import { resolvePrivacyExportPolicy } from '@/src/infrastructure/privacy/privacy-export-policy';
import {
  protectPrivacyExport,
  unprotectJsonPayload,
  unprotectSensitiveIdentifier,
} from '@/src/infrastructure/security/identity-protection';
import { protectSensitiveIdentifier } from '@/src/infrastructure/security/sensitive-identifier-protection';

const identityEnvironment = {
  IDENTITY_ENCRYPTION_KEY_B64: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  IDENTITY_ENCRYPTION_KEY_VERSION: 'test-key-v1',
  IDENTITY_LOOKUP_PEPPER: '0123456789abcdef0123456789abcdef',
};

describe('privacy export protection and policy', () => {
  it('encrypts and restores a requester export with a content digest', () => {
    Object.assign(process.env, identityEnvironment);
    const payload = {
      metadata: { schemaVersion: 'privacy-export-v1' },
      person: { firstName: 'Avery', email: 'avery@example.test' },
    };
    const protectedExport = protectPrivacyExport(payload, 2);

    expect(protectedExport.pgBytea).toMatch(/^\\x[0-9a-f]+$/);
    expect(protectedExport.pgBytea).not.toContain('Avery');
    expect(protectedExport.contentHash).toMatch(/^[0-9a-f]{64}$/);
    expect(unprotectJsonPayload(
      protectedExport.pgBytea,
      protectedExport.keyVersion,
    )).toEqual(payload);
  });

  it('restores protected identifiers only with the configured key version', () => {
    Object.assign(process.env, identityEnvironment);
    const identifier = protectSensitiveIdentifier('ABC-123456');
    expect(unprotectSensitiveIdentifier(
      identifier.ciphertextHex,
      identifier.keyVersion,
    )).toBe('ABC123456');
    expect(() => unprotectSensitiveIdentifier(
      identifier.ciphertextHex,
      'retired-key',
    )).toThrow('PROTECTED_ENVELOPE_KEY_UNAVAILABLE');
  });

  it('enables only the explicitly configured synthetic policy', () => {
    expect(resolvePrivacyExportPolicy({
      DEPLOYMENT_STAGE: 'synthetic',
      PRIVACY_EXPORT_POLICY_VERSION: 'synthetic-privacy-export-v1',
    })).toEqual({
      policyVersion: 'synthetic-privacy-export-v1',
      exportSchemaVersion: 'privacy-export-v1',
      certificationState: 'SYNTHETIC',
    });
    expect(() => resolvePrivacyExportPolicy({
      DEPLOYMENT_STAGE: 'production',
      PRIVACY_EXPORT_POLICY_VERSION: 'synthetic-privacy-export-v1',
    })).toThrow('PRIVACY_EXPORT_POLICY_NOT_CONFIGURED');
  });
});
