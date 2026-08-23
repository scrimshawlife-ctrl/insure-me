import { describe, expect, it, vi } from 'vitest';

import { orchestrateCarrierSubmission } from './orchestrate-carrier-submission';
import { SyntheticCarrierAdapter } from '@/src/infrastructure/carriers/synthetic-carrier';
import type { CarrierRequestContext, RatingInputItem } from '@/src/domain/carriers';

const context: CarrierRequestContext = {
  quoteCaseId: '94000000-0000-0000-0000-000000000001',
  tenantId: '90000000-0000-0000-0000-000000000001',
  agencyId: '91000000-0000-0000-0000-000000000001',
  tenantConfigurationVersion: '1',
  carrierProgramId: 'synthetic-program-a',
  carrierProgramVersion: '1',
  traceId: 'trace-carrier',
  idempotencyKey: 'carrier-idem-1',
};

const ratingInputs: RatingInputItem[] = [
  {
    ratingInputId: '1',
    inputKey: 'mvr.licenseStatus',
    approvedValue: 'VALID',
    dataUsePolicyVersion: 'base-rating-v1',
    mappingVersion: 'mapping-a-v1',
  },
  {
    ratingInputId: '2',
    inputKey: 'claims.claimCount',
    approvedValue: 0,
    dataUsePolicyVersion: 'base-rating-v1',
    mappingVersion: 'mapping-a-v1',
  },
];

function persistence(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    selectCarrierProgram: vi.fn(async () => undefined),
    projectRatingInputs: vi.fn(async () => 2),
    getRatingInputs: vi.fn(async () => ratingInputs),
    createCarrierSubmission: vi.fn(async () => ({ carrierSubmissionId: 'submission-1', reused: false })),
    claimCarrierSubmission: vi.fn(async () => undefined),
    getCarrierSubmissionResult: vi.fn(async () => null),
    settleCarrierSubmission: vi.fn(async () => undefined),
    markCarrierSubmissionFailed: vi.fn(async () => undefined),
    ...overrides,
  };
}

describe('orchestrateCarrierSubmission', () => {
  it('projects server-owned RatingInputs and settles the synthetic carrier result', async () => {
    const adapter = new SyntheticCarrierAdapter('A');
    const store = persistence();

    const result = await orchestrateCarrierSubmission({ adapter, persistence: store, context });

    expect(result.status).toBe('ACCEPTED');
    expect(store.selectCarrierProgram).toHaveBeenCalledOnce();
    expect(store.projectRatingInputs).toHaveBeenCalledOnce();
    expect(store.getRatingInputs).toHaveBeenCalledOnce();
    expect(store.createCarrierSubmission).toHaveBeenCalledOnce();
    expect(store.claimCarrierSubmission).toHaveBeenCalledOnce();
    expect(store.settleCarrierSubmission).toHaveBeenCalledOnce();
  });

  it('returns a cached decision for idempotent replay without another adapter submit', async () => {
    const adapter = new SyntheticCarrierAdapter('A');
    const submitSpy = vi.spyOn(adapter, 'submit');
    const cached = {
      status: 'ACCEPTED' as const,
      externalReference: 'synthetic:A:carrier-idem-1',
      premium: { amount: 120, currency: 'USD' as const, termMonths: 6 },
      reasonCodes: [],
      receivedAt: '2026-08-23T00:00:00.000Z',
    };
    const store = persistence({
      createCarrierSubmission: vi.fn(async () => ({ carrierSubmissionId: 'submission-1', reused: true })),
      getCarrierSubmissionResult: vi.fn(async () => ({ submissionStatus: 'SUCCEEDED' as const, result: cached })),
    });

    const result = await orchestrateCarrierSubmission({ adapter, persistence: store, context });

    expect(result).toEqual(cached);
    expect(store.claimCarrierSubmission).not.toHaveBeenCalled();
    expect(store.settleCarrierSubmission).not.toHaveBeenCalled();
    expect(submitSpy).not.toHaveBeenCalled();
  });

  it('blocks before submission persistence when required projected inputs are missing', async () => {
    const adapter = new SyntheticCarrierAdapter('A');
    const store = persistence({
      getRatingInputs: vi.fn(async () => [ratingInputs[0]]),
    });

    await expect(
      orchestrateCarrierSubmission({ adapter, persistence: store, context }),
    ).rejects.toThrow('CARRIER_HANDOFF_BLOCKED:MISSING_REQUIRED_INPUT:claims.claimCount');

    expect(store.createCarrierSubmission).not.toHaveBeenCalled();
    expect(store.claimCarrierSubmission).not.toHaveBeenCalled();
  });

  it('marks a claimed carrier submission failed when the adapter throws', async () => {
    const adapter = new SyntheticCarrierAdapter('A');
    vi.spyOn(adapter, 'submit').mockRejectedValueOnce(new Error('CARRIER_UNAVAILABLE'));
    const store = persistence();

    await expect(
      orchestrateCarrierSubmission({ adapter, persistence: store, context }),
    ).rejects.toThrow('CARRIER_UNAVAILABLE');

    expect(store.claimCarrierSubmission).toHaveBeenCalledOnce();
    expect(store.markCarrierSubmissionFailed).toHaveBeenCalledWith({
      carrierSubmissionId: 'submission-1',
      reasonCode: 'CARRIER_UNAVAILABLE',
    });
    expect(store.settleCarrierSubmission).not.toHaveBeenCalled();
  });
});
