import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('@/src/infrastructure/config/env', () => ({
  getIdentityProtectionEnvironment: () => ({
    IDENTITY_ENCRYPTION_KEY_B64: Buffer.alloc(32, 7).toString('base64'),
    IDENTITY_ENCRYPTION_KEY_VERSION: 'test-v1',
    IDENTITY_LOOKUP_PEPPER: 'synthetic-pepper',
  }),
}));

import { protectSensitiveIdentifier } from '@/src/infrastructure/security/sensitive-identifier-protection';

describe('protectSensitiveIdentifier', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('returns ciphertext, lookup hash, key version, and safe last4 only', () => {
    const result = protectSensitiveIdentifier('abc-123456');
    expect(result.keyVersion).toBe('test-v1');
    expect(result.lookupHash).toMatch(/^[a-f0-9]{64}$/);
    expect(result.ciphertextHex).toMatch(/^[a-f0-9]+$/);
    expect(result.last4).toBe('3456');
    expect(JSON.stringify(result)).not.toContain('ABC123456');
  });

  it('normalizes identifiers before hashing', () => {
    const a = protectSensitiveIdentifier('1HG-CM82633A004352');
    const b = protectSensitiveIdentifier('1hgcm82633a004352');
    expect(a.lookupHash).toBe(b.lookupHash);
    expect(a.last4).toBe('4352');
    expect(b.last4).toBe('4352');
  });
});
