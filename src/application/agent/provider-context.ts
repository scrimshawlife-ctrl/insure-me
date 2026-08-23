import type { SupabaseClient } from '@supabase/supabase-js';

import type { Database, Json } from '@/src/infrastructure/supabase/database.types';

export type AgentProviderCapability = 'IDENTITY' | 'PREFILL' | 'MVR' | 'CLAIMS' | 'VEHICLE';
export type AgentExternalRequestStatus = 'PENDING' | 'RUNNING' | 'SUCCEEDED' | 'FAILED' | 'BLOCKED';
export type AgentExternalReportStatus = 'SUCCESS' | 'NO_HIT' | 'PARTIAL' | 'STALE' | 'ERROR';

export interface AgentProviderReportView {
  providerBindingId: string;
  capability: AgentProviderCapability;
  adapterId: string;
  adapterVersion: string;
  requiredForReadiness: boolean;
  externalRequestId: string | null;
  requestStatus: AgentExternalRequestStatus | null;
  requestedAt: string | null;
  completedAt: string | null;
  subjectIds: string[];
  externalReportId: string | null;
  reportStatus: AgentExternalReportStatus | null;
  retrievedAt: string | null;
  freshUntil: string | null;
  warnings: string[];
  canRefresh: boolean;
}

export interface AgentProvenanceView {
  provenanceEntryId: string;
  externalReportId: string | null;
  sourceType: string;
  sourceId: string;
  factKey: string;
  sourcePath: string | null;
  sourceTimestamp: string | null;
  transformationVersion: string;
  confidenceState: string | null;
  confirmationState: string | null;
}

export interface AgentObservationView {
  observationId: string;
  observationType: string;
  subjectId: string | null;
  normalizedValue: Json;
  dataUseClassification: string;
  dataUsePolicyVersion: string | null;
  freshnessState: string;
  conflictState: string;
  createdAt: string;
  provenance: AgentProvenanceView[];
}

export interface AgentProviderContext {
  canRefreshProviders: boolean;
  reports: AgentProviderReportView[];
  observations: AgentObservationView[];
}

type ProviderContextRpc = (
  functionName: 'get_workforce_case_provider_context',
  args: { p_quote_case_id: string },
) => PromiseLike<{
  data: Json | null;
  error: { message: string } | null;
}>;

function asObject(value: Json | null): Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

export async function getAgentProviderContext(
  client: SupabaseClient<Database>,
  quoteCaseId: string,
): Promise<AgentProviderContext> {
  const rpc = client.rpc as unknown as ProviderContextRpc;
  const { data, error } = await rpc('get_workforce_case_provider_context', {
    p_quote_case_id: quoteCaseId,
  });

  if (error) throw new Error(`AGENT_PROVIDER_CONTEXT_FAILED:${error.message}`);
  const payload = asObject(data);

  return {
    canRefreshProviders: payload.canRefreshProviders === true,
    reports: Array.isArray(payload.reports)
      ? payload.reports as unknown as AgentProviderReportView[]
      : [],
    observations: Array.isArray(payload.observations)
      ? payload.observations as unknown as AgentObservationView[]
      : [],
  };
}
