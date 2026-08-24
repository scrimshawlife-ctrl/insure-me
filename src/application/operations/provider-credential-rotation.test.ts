import { describe, expect, it } from 'vitest';

import {
  rotateProviderCredential,
  type ProviderCredentialRotationPort,
} from '@/src/application/operations/provider-credential-rotation';

function port(options: { staged?: 'VALID' | 'REJECTED'; active?: 'VALID' | 'REJECTED' } = {}) {
  const actions: string[] = [];
  const value: ProviderCredentialRotationPort = {
    readState: async () => ({ currentVersion: 'provider-v1', standbyVersion: null, previousVersion: null }),
    stage: async ({ version }) => void actions.push(`stage:${version}`),
    validate: async () => options.staged ?? 'VALID',
    activate: async ({ version }) => void actions.push(`activate:${version}`),
    verifyActive: async () => options.active ?? 'VALID',
    revoke: async ({ version }) => void actions.push(`revoke:${version}`),
    rollback: async ({ version }) => void actions.push(`rollback:${version}`),
    recordAudit: async ({ action, version }) => void actions.push(`audit:${action}:${version}`),
  };
  return { value, actions };
}

describe('rotateProviderCredential', () => {
  it('validates the standby credential before activation and revokes the previous version last', async () => {
    const fixture = port();
    const result = await rotateProviderCredential({
      port: fixture.value,
      newVersion: 'provider-v2',
      newCredential: 'synthetic-credential-material-v2-0000000000',
    });

    expect(result).toEqual({
      status: 'ROTATED', previousVersion: 'provider-v1', activeVersion: 'provider-v2',
      oldCredentialRevoked: true, reasonCode: null,
    });
    expect(fixture.actions).toEqual([
      'stage:provider-v2', 'audit:STAGED:provider-v2', 'activate:provider-v2',
      'audit:ACTIVATED:provider-v2', 'revoke:provider-v1', 'audit:REVOKED:provider-v1',
    ]);
  });

  it('keeps the current credential active when standby validation fails', async () => {
    const fixture = port({ staged: 'REJECTED' });
    const result = await rotateProviderCredential({
      port: fixture.value,
      newVersion: 'provider-v2',
      newCredential: 'synthetic-credential-material-v2-0000000000',
    });
    expect(result.status).toBe('ROLLED_BACK');
    expect(result.activeVersion).toBe('provider-v1');
    expect(result.oldCredentialRevoked).toBe(false);
    expect(fixture.actions).not.toContain('revoke:provider-v1');
  });

  it('rolls back before revocation when active verification fails', async () => {
    const fixture = port({ active: 'REJECTED' });
    const result = await rotateProviderCredential({
      port: fixture.value,
      newVersion: 'provider-v2',
      newCredential: 'synthetic-credential-material-v2-0000000000',
    });
    expect(result.reasonCode).toBe('ACTIVE_CREDENTIAL_VERIFICATION_FAILED');
    expect(fixture.actions).toContain('rollback:provider-v1');
    expect(fixture.actions).not.toContain('revoke:provider-v1');
  });
});
