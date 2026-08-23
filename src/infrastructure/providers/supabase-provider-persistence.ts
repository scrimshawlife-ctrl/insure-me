import type {
  ProviderCapabilityDescriptor,
  ProviderRequestContext,
  ProviderResult,
} from '@/src/domain/providers';
import type {
  ProviderOrchestrationPersistence,
} from '@/src/application/providers/orchestrate-provider-request';
import { normalizeProviderResultForObservations } from '@/src/application/providers/normalize-provider-result';
import { createSupabaseAdminClient } from '@/src/infrastructure/supabase/admin';

interface RpcResponse<T> {
  data: T | null;
  error: { message: string } | null;
}

type GenericRpc = (
  functionName: string,
  args?: Record<string, unknown>,
) => PromiseLike<RpcResponse<unknown>>;

async function rpc<T>(functionName: string, args: Record<string, unknown>): Promise<T> {
  const client = createSupabaseAdminClient();
  const call = client.rpc as unknown as GenericRpc;
  const { data, error } = await call(functionName, args);
  if (error) throw new Error(error.message);
  return data as T;
}

export class SupabaseProviderOrchestrationPersistence
  implements ProviderOrchestrationPersistence
{
  public async createPurposeDecision(input: {
    context: ProviderRequestContext;
    purposeCode: string;
    policyVersion: string;
    allowed: boolean;
    reasonCodes: string[];
  }): Promise<{ decisionId: string }> {
    const decisionId = await rpc<string>('record_provider_purpose_decision', {
      p_quote_case_id: input.context.quoteCaseId,
      p_actor_id: input.context.actorId,
      p_capability: input.context.capability,
      p_purpose_code: input.purposeCode,
      p_policy_version: input.policyVersion,
      p_allowed: input.allowed,
      p_reason_codes: input.reasonCodes,
    });
    if (!decisionId) throw new Error('PURPOSE_DECISION_PERSIST_FAILED');
    return { decisionId };
  }

  public async createExternalRequest(input: {
    context: ProviderRequestContext;
    requestHash: string;
    decisionId: string;
  }): Promise<{ externalRequestId: string; reused: boolean }> {
    const rows = await rpc<Array<{ external_request_id: string; reused: boolean }>>(
      'create_provider_external_request',
      {
        p_quote_case_id: input.context.quoteCaseId,
        p_provider_binding_id: input.context.providerBindingId,
        p_capability: input.context.capability,
        p_subject_ids: input.context.subjectIds,
        p_decision_id: input.decisionId,
        p_consent_record_ids: input.context.consentRecordIds,
        p_idempotency_key: input.context.idempotencyKey,
        p_request_hash: input.requestHash,
      },
    );
    const row = rows?.[0];
    if (!row) throw new Error('EXTERNAL_REQUEST_PERSIST_FAILED');
    return {
      externalRequestId: row.external_request_id,
      reused: row.reused,
    };
  }

  public async claimExternalRequest(input: {
    externalRequestId: string;
    workerId: string;
  }): Promise<void> {
    await rpc('claim_provider_request', {
      p_external_request_id: input.externalRequestId,
      p_worker_id: input.workerId,
    });
  }

  public async markExternalRequestRetry(input: {
    externalRequestId: string;
    errorCode: string;
    backoffSeconds: number;
  }): Promise<void> {
    await rpc('mark_provider_request_retry', {
      p_external_request_id: input.externalRequestId,
      p_error_code: input.errorCode,
      p_backoff_seconds: input.backoffSeconds,
    });
  }

  public async getExternalRequestResult<T>(input: {
    externalRequestId: string;
  }): Promise<{
    requestStatus: 'PENDING' | 'RUNNING' | 'SUCCEEDED' | 'FAILED' | 'BLOCKED';
    result: ProviderResult<T> | null;
  } | null> {
    const rows = await rpc<
      Array<{
        request_status: 'PENDING' | 'RUNNING' | 'SUCCEEDED' | 'FAILED' | 'BLOCKED';
        report_status: ProviderResult<T>['status'] | null;
        provider_request_ref: string | null;
        provider_report_ref: string | null;
        retrieved_at: string | null;
        normalized_snapshot: T | null;
        warnings: string[] | null;
      }>
    >('get_provider_request_result', {
      p_external_request_id: input.externalRequestId,
    });

    const row = rows?.[0];
    if (!row) return null;
    return {
      requestStatus: row.request_status,
      result:
        row.report_status && row.retrieved_at
          ? {
              status: row.report_status,
              providerRequestId: row.provider_request_ref ?? undefined,
              providerReportId: row.provider_report_ref ?? undefined,
              retrievedAt: row.retrieved_at,
              normalized: row.normalized_snapshot,
              provenance: [],
              warnings: row.warnings ?? [],
            }
          : null,
    };
  }

  public async settleExternalResult<T>(input: {
    context: ProviderRequestContext;
    externalRequestId: string;
    descriptor: ProviderCapabilityDescriptor;
    result: ProviderResult<T>;
  }): Promise<void> {
    const normalized = input.result.normalized as
      | {
          capability: ProviderRequestContext['capability'];
          subjectIds: string[];
          facts: Record<string, string | number | boolean | null>;
        }
      | null;

    const drafts = normalizeProviderResultForObservations({
      capability: input.context.capability,
      subjectIds: input.context.subjectIds,
      result: {
        ...input.result,
        normalized,
      },
    });

    const freshUntil = input.descriptor.freshnessSeconds
      ? new Date(
          new Date(input.result.retrievedAt).getTime() +
            input.descriptor.freshnessSeconds * 1000,
        ).toISOString()
      : null;

    await rpc('settle_provider_result', {
      p_external_request_id: input.externalRequestId,
      p_provider_id: input.descriptor.adapterId,
      p_provider_product_id: input.context.capability,
      p_provider_report_ref: input.result.providerReportId ?? null,
      p_status: input.result.status,
      p_retrieved_at: input.result.retrievedAt,
      p_fresh_until: freshUntil,
      p_normalized_snapshot: input.result.normalized ?? null,
      p_normalized_version: input.descriptor.adapterVersion,
      p_warnings: input.result.warnings,
      p_provenance: drafts.provenance,
      p_observations: drafts.observations,
    });
  }
}
