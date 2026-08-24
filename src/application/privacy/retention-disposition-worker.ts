import { createHash, timingSafeEqual } from 'node:crypto';

import type { SupabaseClient } from '@supabase/supabase-js';

import type { RetentionRunStatus } from '@/src/domain/privacy';
import {
  getDeploymentControlEnvironment,
  requireLiveDeploymentReady,
  type EnvironmentSource,
} from '@/src/infrastructure/config/deployment';
import { getRetentionWorkerEnvironment } from '@/src/infrastructure/config/env';
import type { Database } from '@/src/infrastructure/supabase/database.types';

type RetentionRunRow = {
  retention_disposition_run_id: string;
  run_status: RetentionRunStatus;
  status_summary: Record<string, number>;
};

type RetentionRpc = (
  functionName:
    | 'prepare_retention_disposition_run'
    | 'execute_retention_disposition_run',
  args: Record<string, unknown>,
) => PromiseLike<{
  data: RetentionRunRow[] | null;
  error: { message: string } | null;
}>;

export type RetentionWorkerResult = {
  runId: string;
  status: RetentionRunStatus;
  statusSummary: Record<string, number>;
};

function digest(value: string): Buffer {
  return createHash('sha256').update(value).digest();
}

export function authorizeRetentionWorker(
  authorization: string | null,
  environment: EnvironmentSource = process.env,
): boolean {
  const token = authorization?.match(/^Bearer ([^\s]+)$/)?.[1];
  if (!token) return false;
  const expected = getRetentionWorkerEnvironment(environment).RETENTION_WORKER_TOKEN;
  return timingSafeEqual(digest(token), digest(expected));
}

function result(row: RetentionRunRow): RetentionWorkerResult {
  return {
    runId: row.retention_disposition_run_id,
    status: row.run_status,
    statusSummary: row.status_summary,
  };
}

export async function processRetentionDispositions(
  adminClient: SupabaseClient<Database>,
  command: {
    idempotencyKey: string;
    asOf: string;
    limit: number;
  },
  environment: EnvironmentSource = process.env,
): Promise<RetentionWorkerResult> {
  const deployment = getDeploymentControlEnvironment(environment);
  if (deployment.DEPLOYMENT_STAGE !== 'synthetic') {
    requireLiveDeploymentReady(environment);
  }
  const expectedCertificationState = deployment.DEPLOYMENT_STAGE === 'synthetic'
    ? 'SYNTHETIC'
    : 'APPROVED';
  const rpc = adminClient.rpc.bind(adminClient) as unknown as RetentionRpc;
  const preparedResult = await rpc('prepare_retention_disposition_run', {
    p_idempotency_key: command.idempotencyKey,
    p_as_of: command.asOf,
    p_limit: command.limit,
    p_expected_certification_state: expectedCertificationState,
  });
  const prepared = preparedResult.data?.[0];
  if (preparedResult.error || !prepared || preparedResult.data?.length !== 1) {
    throw new Error('RETENTION_WORKER_FAILED');
  }
  if (prepared.run_status === 'COMPLETED') return result(prepared);
  const executedResult = await rpc('execute_retention_disposition_run', {
    p_run_id: prepared.retention_disposition_run_id,
    p_limit: command.limit,
  });
  const executed = executedResult.data?.[0];
  if (executedResult.error || !executed || executedResult.data?.length !== 1) {
    throw new Error('RETENTION_WORKER_FAILED');
  }
  return result(executed);
}
