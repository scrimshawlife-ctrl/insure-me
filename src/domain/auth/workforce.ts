export const WORKFORCE_PERMISSIONS = [
  'CASE_READ',
  'CASE_WRITE',
  'REPORT_RETRIEVE',
  'PRIVACY_ADMIN',
  'EXPORT_DATA',
  'CARRIER_SUBMIT',
  'POLICY_ADMIN',
  'AUDIT_READ',
  'TENANT_ADMIN',
] as const;

export type WorkforcePermission = (typeof WORKFORCE_PERMISSIONS)[number];

export interface WorkforceContext {
  userId: string;
  agencyUserId: string;
  tenantId: string;
  agencyId: string;
  assuranceLevel: 'aal2';
  permissions: readonly WorkforcePermission[];
}

export function assertWorkforceMfa(
  currentLevel: string | null | undefined,
): asserts currentLevel is 'aal2' {
  if (currentLevel !== 'aal2') {
    throw new Error('WORKFORCE_MFA_REQUIRED');
  }
}

export function assertWorkforcePermission(
  context: WorkforceContext,
  permission: WorkforcePermission,
): void {
  if (!context.permissions.includes(permission)) {
    throw new Error(`WORKFORCE_PERMISSION_REQUIRED:${permission}`);
  }
}

export function getActiveTenantId(appMetadata: unknown): string {
  if (
    typeof appMetadata !== 'object' ||
    appMetadata === null ||
    !('active_tenant_id' in appMetadata) ||
    typeof (appMetadata as { active_tenant_id?: unknown }).active_tenant_id !== 'string'
  ) {
    throw new Error('ACTIVE_TENANT_REQUIRED');
  }

  const tenantId = (appMetadata as { active_tenant_id: string }).active_tenant_id;
  if (!tenantId) {
    throw new Error('ACTIVE_TENANT_REQUIRED');
  }
  return tenantId;
}
