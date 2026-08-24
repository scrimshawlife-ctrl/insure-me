import { describe, expect, it } from 'vitest';

import {
  authorizeRetentionWorker,
  processRetentionDispositions,
} from '@/src/application/privacy/retention-disposition-worker';

const workerEnvironment = {
  RETENTION_WORKER_TOKEN: 'retention-worker-token-with-32-characters',
};

describe('retention disposition worker', () => {
  it('uses constant-length digest comparison for bearer authentication', () => {
    expect(authorizeRetentionWorker(
      `Bearer ${workerEnvironment.RETENTION_WORKER_TOKEN}`,
      workerEnvironment,
    )).toBe(true);
    expect(authorizeRetentionWorker('Bearer incorrect-token', workerEnvironment)).toBe(false);
    expect(authorizeRetentionWorker(null, workerEnvironment)).toBe(false);
  });

  it('uses synthetic policies only in the synthetic stage', async () => {
    const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
    const client = {
      rpc: async (name: string, args: Record<string, unknown>) => {
        calls.push({ name, args });
        return {
          data: [{
            retention_disposition_run_id: 'run-1',
            run_status: name.startsWith('prepare') ? 'IN_PROGRESS' : 'COMPLETED',
            status_summary: { COMPLETED: 2 },
          }],
          error: null,
        };
      },
    };
    const result = await processRetentionDispositions(client as never, {
      idempotencyKey: 'key-1',
      asOf: '2026-08-24T00:00:00.000Z',
      limit: 100,
    }, { DEPLOYMENT_STAGE: 'synthetic' });
    expect(result).toEqual({
      runId: 'run-1',
      status: 'COMPLETED',
      statusSummary: { COMPLETED: 2 },
    });
    expect(calls[0].args.p_expected_certification_state).toBe('SYNTHETIC');
    expect(calls.map((call) => call.name)).toEqual([
      'prepare_retention_disposition_run',
      'execute_retention_disposition_run',
    ]);
  });

  it('fails closed before approved-policy execution in an unready live stage', async () => {
    await expect(processRetentionDispositions({} as never, {
      idempotencyKey: 'key-1',
      asOf: '2026-08-24T00:00:00.000Z',
      limit: 100,
    }, { DEPLOYMENT_STAGE: 'production' })).rejects.toThrow('LIVE_DEPLOYMENT_BLOCKED');
  });
});
