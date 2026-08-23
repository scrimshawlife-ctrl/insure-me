import type { SupabaseClient } from '@supabase/supabase-js';

import {
  assertWorkforceMfa,
  getActiveTenantId,
  type WorkforceContext,
  type WorkforcePermission,
} from '@/src/domain/auth/workforce';
import type { Database } from '@/src/infrastructure/supabase/database.types';

type WorkforceContextRow = {
  agency_user_id: string;
  tenant_id: string;
  agency_id: string;
  permissions: WorkforcePermission[];
};

type WorkforceContextRpc = (
  functionName: 'get_current_workforce_context',
) => PromiseLike<{
  data: WorkforceContextRow[] | null;
  error: { message: string } | null;
}>;

export async function requireWorkforceContext(
  client: SupabaseClient<Database>,
): Promise<WorkforceContext> {
  const {
    data: { user },
    error: userError,
  } = await client.auth.getUser();

  if (userError || !user) {
    throw new Error('WORKFORCE_AUTHENTICATION_REQUIRED');
  }

  const { data: assurance, error: assuranceError } =
    await client.auth.mfa.getAuthenticatorAssuranceLevel();

  if (assuranceError) {
    throw new Error('WORKFORCE_ASSURANCE_UNAVAILABLE');
  }
  assertWorkforceMfa(assurance.currentLevel);

  const expectedTenantId = getActiveTenantId(user.app_metadata);
  const rpc = client.rpc as unknown as WorkforceContextRpc;
  const { data, error } = await rpc('get_current_workforce_context');

  if (error) {
    throw new Error('WORKFORCE_CONTEXT_UNAVAILABLE');
  }
  if (!data || data.length !== 1) {
    throw new Error('WORKFORCE_CONTEXT_NOT_UNIQUE');
  }

  const row = data[0];
  if (row.tenant_id !== expectedTenantId) {
    throw new Error('WORKFORCE_TENANT_CONTEXT_MISMATCH');
  }

  return {
    userId: user.id,
    agencyUserId: row.agency_user_id,
    tenantId: row.tenant_id,
    agencyId: row.agency_id,
    assuranceLevel: 'aal2',
    permissions: row.permissions,
  };
}
