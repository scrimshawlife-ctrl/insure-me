import { describe, expect, it } from 'vitest';

import { protectConsumerIdentity } from '@/src/infrastructure/security/identity-protection';

const baseEnvironment = {
  IDENTITY_ENCRYPTION_KEY_B64: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  IDENTITY_ENCRYPTION_KEY_VERSION: 'test-key-v1',
  IDENTITY_LOOKUP_PEPPER: '0123456789abcdef0123456789abcdef',
};

function configureIdentityEnvironment() {
  Object.assign(process.env, baseEnvironment);
}

describe('consumer identity protection', () => {
  it('encrypts identity into a PostgreSQL bytea envelope without plaintext fields', () => {
    configureIdentityEnvironment();

    const protectedPayload = protectConsumerIdentity({
      firstName: 'Avery',
      lastName: 'Example',
      dateOfBirth: '1990-01-01',
      email: 'Avery.Example@example.test',
      phone: '(650) 555-0100',
      address: {
        line1: '123 Synthetic Way',
        city: 'Mountain View',
        state: 'CA',
        postalCode: '94040',
      },
    });

    expect(protectedPayload.pgBytea).toMatch(/^\\x[0-9a-f]+$/);
    expect(protectedPayload.pgBytea).not.toContain('Avery');
    expect(protectedPayload.pgBytea).not.toContain('Mountain View');
    expect(protectedPayload.keyVersion).toBe('test-key-v1');
  });

  it('uses normalized deterministic HMAC lookup hashes while ciphertext remains randomized', () => {
    configureIdentityEnvironment();

    const first = protectConsumerIdentity({
      firstName: 'Avery',
      lastName: 'Example',
      dateOfBirth: '1990-01-01',
      email: ' Avery.Example@Example.Test ',
      phone: '+1 (650) 555-0100',
      address: {
        line1: '123 Synthetic Way',
        city: 'Mountain View',
        state: 'CA',
        postalCode: '94040',
      },
    });

    const second = protectConsumerIdentity({
      firstName: 'Avery',
      lastName: 'Example',
      dateOfBirth: '1990-01-01',
      email: 'avery.example@example.test',
      phone: '+16505550100',
      address: {
        line1: '123 Synthetic Way',
        city: 'Mountain View',
        state: 'CA',
        postalCode: '94040',
      },
    });

    expect(first.emailLookupHash).toBe(second.emailLookupHash);
    expect(first.phoneLookupHash).toBe(second.phoneLookupHash);
    expect(first.pgBytea).not.toBe(second.pgBytea);
  });
});
