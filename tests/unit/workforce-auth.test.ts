import { describe, expect, it } from 'vitest';

import {
  assertWorkforceMfa,
  assertWorkforcePermission,
  getActiveTenantId,
  type WorkforceContext,
} from '@/src/domain/auth/workforce';

const context: WorkforceContext = {
  userId: 'user-1',
  agencyUserId: 'agency-user-1',
  tenantId: 'tenant-1',
  agencyId: 'agency-1',
  assuranceLevel: 'aal2',
  permissions: ['CASE_READ', 'CASE_WRITE'],
};

describe('workforce auth rules', () => {
  it('requires aal2', () => {
    expect(() => assertWorkforceMfa('aal1')).toThrow('WORKFORCE_MFA_REQUIRED');
    expect(() => assertWorkforceMfa('aal2')).not.toThrow();
  });

  it('requires an active tenant in trusted app metadata', () => {
    expect(getActiveTenantId({ active_tenant_id: 'tenant-1' })).toBe('tenant-1');
    expect(() => getActiveTenantId({})).toThrow('ACTIVE_TENANT_REQUIRED');
  });

  it('checks explicit workforce permissions', () => {
    expect(() => assertWorkforcePermission(context, 'CASE_WRITE')).not.toThrow();
    expect(() => assertWorkforcePermission(context, 'CARRIER_SUBMIT')).toThrow(
      'WORKFORCE_PERMISSION_REQUIRED:CARRIER_SUBMIT',
    );
  });
});
