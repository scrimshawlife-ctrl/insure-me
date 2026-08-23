import { randomUUID } from 'node:crypto';

import type { SupabaseClient } from '@supabase/supabase-js';

import { assertWorkforcePermission, type WorkforceContext } from '@/src/domain/auth/workforce';
import type { ProviderCapability, ProviderRequestContext } from '@/src/domain/providers';
import type { Database } from '@/src/infrastructure/supabase/database.types';
import { createSupabaseAdminClient } from '@/src/infrastructure/supabase/admin';

type GenericRpc = (
  functionName: string,
  args?: Record<string, unknown>,
) => PromiseLike<{ data: unknown; error: { message: string } | null }>;

export interface ResolvedProviderRequest {
  context: ProviderRequestContext;
  adapterId: string;
  adapterVersion: string;
  configuredPurposeCode: string;
  requiresReportAuthorization: boolean;
}

export async function resolveProviderRequestContext(input: {
  userClient: SupabaseClient<Database>;
  workforce: WorkforceContext;
  quoteCaseId: string;
  capability: ProviderCapability;
  subjectIds: string[];
  idempotencyKey: string;
  traceId?: string;
}): Promise<ResolvedProviderRequest> {
  assertWorkforcePermission(input.workforce, 'REPORT_RETRIEVE');

  // The workforce client is intentionally accepted to make the caller prove an authenticated
  // workforce session was established before entering this service. Data resolution itself uses
  // a server-only secret client after tenant/agency are derived from that verified session.
  void input.userClient;

  const admin = createSupabaseAdminClient();
  const rpc = admin.rpc as unknown as GenericRpc;
  const { data, error } = await rpc('resolve_provider_request_context', {
    p_quote_case_id: input.quoteCaseId,
    p_tenant_id: input.workforce.tenantId,
    p_agency_id: input.workforce.agencyId,
    p_capability: input.capability,
  });

  if (error) throw new Error(error.message);
  const row = Array.isArray(data) ? data[0] : null;
  if (!row || typeof row !== 'object') {
    throw new Error('PROVIDER_CONTEXT_NOT_RESOLVED');
  }

  const resolved = row as {
    tenant_configuration_version: number;
    jurisdiction: 'CA';
    product_line: 'PRIVATE_PASSENGER_AUTO';
    provider_binding_id: string;
    adapter_id: string;
    adapter_version: string;
    purpose_code: string;
    requires_report_authorization: boolean;
    consent_record_ids: string[];
  };

  return {
    context: {
      quoteCaseId: input.quoteCaseId,
      tenantId: input.workforce.tenantId,
      agencyId: input.workforce.agencyId,
      actorId: input.workforce.userId,
      tenantConfigurationVersion: String(resolved.tenant_configuration_version),
      jurisdiction: resolved.jurisdiction,
      productLine: resolved.product_line,
      capability: input.capability,
      providerBindingId: resolved.provider_binding_id,
      permissiblePurposeDecisionId: 'PENDING_SERVER_DECISION',
      consentRecordIds: resolved.consent_record_ids ?? [],
      subjectIds: input.subjectIds,
      traceId: input.traceId ?? randomUUID(),
      idempotencyKey: input.idempotencyKey,
    },
    adapterId: resolved.adapter_id,
    adapterVersion: resolved.adapter_version,
    configuredPurposeCode: resolved.purpose_code,
    requiresReportAuthorization: resolved.requires_report_authorization,
  };
}
