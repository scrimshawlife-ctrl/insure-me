import { describe, expect, it } from 'vitest';

import { protectPrivacyRequester } from '@/src/infrastructure/security/identity-protection';

const baseEnvironment = {
  IDENTITY_ENCRYPTION_KEY_B64: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  IDENTITY_ENCRYPTION_KEY_VERSION: 'test-key-v1',
  IDENTITY_LOOKUP_PEPPER: '0123456789abcdef0123456789abcdef',
};

describe('privacy request intake protection', () => {
  it('encrypts requester contact data and exposes no plaintext', () => {
    Object.assign(process.env, baseEnvironment);
    const result = protectPrivacyRequester({
      firstName: 'Avery',
      lastName: 'Example',
      email: 'Avery@example.test',
      phone: '+1 (650) 555-0100',
    }, '10000000-0000-4000-8000-000000000001', {
      requestType: 'DELETION', jurisdiction: 'CA',
    });

    expect(result.pgBytea).toMatch(/^\\x[0-9a-f]+$/);
    expect(result.pgBytea).not.toContain('Avery');
    expect(result.requestHash).toMatch(/^[0-9a-f]{64}$/);
    expect(result.statusToken).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(result.statusTokenHash).toMatch(/^[0-9a-f]{64}$/);
  });

  it('normalizes retries into stable lookup, request, and status-token hashes', () => {
    Object.assign(process.env, baseEnvironment);
    const first = protectPrivacyRequester({
      firstName: ' Avery ', lastName: ' Example ',
      email: 'Avery@Example.Test', phone: '+1 (650) 555-0100',
    }, '10000000-0000-4000-8000-000000000001', {
      requestType: 'DELETION', jurisdiction: 'CA',
    });
    const second = protectPrivacyRequester({
      firstName: 'Avery', lastName: 'Example',
      email: 'avery@example.test', phone: '+16505550100',
    }, '10000000-0000-4000-8000-000000000001', {
      requestType: 'DELETION', jurisdiction: 'CA',
    });

    expect(first.requestHash).toBe(second.requestHash);
    expect(first.emailLookupHash).toBe(second.emailLookupHash);
    expect(first.phoneLookupHash).toBe(second.phoneLookupHash);
    expect(first.statusToken).toBe(second.statusToken);
    expect(first.pgBytea).not.toBe(second.pgBytea);
  });

  it('changes the status token when the idempotency key changes', () => {
    Object.assign(process.env, baseEnvironment);
    const payload = { firstName: 'Avery', lastName: 'Example', email: 'avery@example.test' };
    const first = protectPrivacyRequester(
      payload,
      '10000000-0000-4000-8000-000000000001',
      { requestType: 'DELETION', jurisdiction: 'CA' },
    );
    const second = protectPrivacyRequester(
      payload,
      '20000000-0000-4000-8000-000000000002',
      { requestType: 'DELETION', jurisdiction: 'CA' },
    );
    expect(first.requestHash).toBe(second.requestHash);
    expect(first.statusToken).not.toBe(second.statusToken);
  });

  it('binds the idempotency hash to privacy request semantics', () => {
    Object.assign(process.env, baseEnvironment);
    const payload = { firstName: 'Avery', lastName: 'Example', email: 'avery@example.test' };
    const deletion = protectPrivacyRequester(
      payload,
      '10000000-0000-4000-8000-000000000001',
      { requestType: 'DELETION', jurisdiction: 'CA' },
    );
    const access = protectPrivacyRequester(
      payload,
      '10000000-0000-4000-8000-000000000001',
      { requestType: 'ACCESS', jurisdiction: 'CA' },
    );
    expect(deletion.requestHash).not.toBe(access.requestHash);
    expect(deletion.statusToken).not.toBe(access.statusToken);
  });
});
