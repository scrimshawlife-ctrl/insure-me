import type { CarrierSubmissionPersistence } from '@/src/application/carriers/orchestrate-carrier-submission';
import type { CarrierSubmissionResult, RatingInputItem } from '@/src/domain/carriers';
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

export class SupabaseCarrierSubmissionPersistence
  implements CarrierSubmissionPersistence
{
  public async selectCarrierProgram(input: {
    quoteCaseId: string;
    carrierProgramId: string;
  }): Promise<void> {
    await rpc('select_carrier_program', {
      p_quote_case_id: input.quoteCaseId,
      p_carrier_program_id: input.carrierProgramId,
    });
  }

  public async projectRatingInputs(input: {
    quoteCaseId: string;
    carrierProgramId: string;
  }): Promise<number> {
    return rpc<number>('project_rating_inputs', {
      p_quote_case_id: input.quoteCaseId,
      p_carrier_program_id: input.carrierProgramId,
    });
  }

  public async getRatingInputs(input: {
    quoteCaseId: string;
    carrierProgramId: string;
  }): Promise<RatingInputItem[]> {
    const rows = await rpc<
      Array<{
        rating_input_id: string;
        input_key: string;
        approved_value: unknown;
        data_use_policy_version: string;
        mapping_version: string;
      }>
    >('get_carrier_rating_inputs', {
      p_quote_case_id: input.quoteCaseId,
      p_carrier_program_id: input.carrierProgramId,
    });

    return (rows ?? []).map((row) => ({
      ratingInputId: row.rating_input_id,
      inputKey: row.input_key,
      approvedValue: row.approved_value,
      dataUsePolicyVersion: row.data_use_policy_version,
      mappingVersion: row.mapping_version,
    }));
  }

  public async createCarrierSubmission(input: {
    quoteCaseId: string;
    carrierProgramId: string;
    idempotencyKey: string;
    requestHash: string;
  }): Promise<{ carrierSubmissionId: string; reused: boolean }> {
    const rows = await rpc<Array<{ carrier_submission_id: string; reused: boolean }>>(
      'create_carrier_submission',
      {
        p_quote_case_id: input.quoteCaseId,
        p_carrier_program_id: input.carrierProgramId,
        p_idempotency_key: input.idempotencyKey,
        p_request_hash: input.requestHash,
      },
    );
    const row = rows?.[0];
    if (!row) throw new Error('CARRIER_SUBMISSION_PERSIST_FAILED');
    return {
      carrierSubmissionId: row.carrier_submission_id,
      reused: row.reused,
    };
  }

  public async claimCarrierSubmission(input: {
    carrierSubmissionId: string;
  }): Promise<void> {
    await rpc('claim_carrier_submission', {
      p_carrier_submission_id: input.carrierSubmissionId,
    });
  }

  public async getCarrierSubmissionResult(input: {
    carrierSubmissionId: string;
  }): Promise<{
    submissionStatus: 'PENDING' | 'RUNNING' | 'SUCCEEDED' | 'FAILED' | 'BLOCKED';
    result: CarrierSubmissionResult | null;
  } | null> {
    const rows = await rpc<
      Array<{
        submission_status: 'PENDING' | 'RUNNING' | 'SUCCEEDED' | 'FAILED' | 'BLOCKED';
        decision_status: CarrierSubmissionResult['status'] | null;
        premium: CarrierSubmissionResult['premium'] | null;
        reason_codes: string[] | null;
        external_reference: string | null;
        received_at: string | null;
      }>
    >('get_carrier_submission_result', {
      p_carrier_submission_id: input.carrierSubmissionId,
    });
    const row = rows?.[0];
    if (!row) return null;

    return {
      submissionStatus: row.submission_status,
      result:
        row.decision_status && row.received_at
          ? {
              status: row.decision_status,
              premium: row.premium ?? undefined,
              reasonCodes: row.reason_codes ?? [],
              externalReference: row.external_reference ?? undefined,
              receivedAt: row.received_at,
            }
          : null,
    };
  }

  public async settleCarrierSubmission(input: {
    carrierSubmissionId: string;
    result: CarrierSubmissionResult;
  }): Promise<void> {
    await rpc('settle_carrier_submission', {
      p_carrier_submission_id: input.carrierSubmissionId,
      p_decision_status: input.result.status,
      p_premium: input.result.premium ?? null,
      p_reason_codes: input.result.reasonCodes,
      p_external_reference: input.result.externalReference ?? null,
      p_received_at: input.result.receivedAt,
    });
  }

  public async markCarrierSubmissionFailed(input: {
    carrierSubmissionId: string;
    reasonCode: string;
  }): Promise<void> {
    await rpc('mark_carrier_submission_failed', {
      p_carrier_submission_id: input.carrierSubmissionId,
      p_reason_code: input.reasonCode,
    });
  }
}
