import { describe, expect, it, vi } from 'vitest';

import { orchestrateProviderRequest } from './orchestrate-provider-request';
import { SyntheticProviderAdapter } from '@/src/infrastructure/providers/synthetic-provider';
import type { ProviderRequestContext } from '@/src/domain/providers';

const context: ProviderRequestContext = {
  quoteCaseId: '94000000-0000-0000-0000-000000000001',
  tenantId: '90000000-0000-0000-0000-000000000001',
  agencyId: '91000000-0000-0000-0000-000000000001',
  actorId: '92000000-0000-0000-0000-000000000001',
  tenantConfigurationVersion: '1',
  jurisdiction: 'CA',
  productLine: 'PRIVATE_PASSENGER_AUTO',
  capability: 'MVR',
  providerBindingId: '95000000-0000-0000-0000-000000000001',
  permissiblePurposeDecisionId: '00000000-0000-0000-0000-000000000000',
  consentRecordIds: ['96000000-0000-0000-0000-000000000001'],
  subjectIds: ['97000000-0000-0000-0000-000000000001'],
  traceId: 'trace-test',
  idempotencyKey: 'idem-test',
};

function persistence(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    createPurposeDecision: vi.fn(async () => ({ decisionId: 'decision-1' })),
    createExternalRequest: vi.fn(async () => ({ externalRequestId: 'request-1', reused: false })),
    claimExternalRequest: vi.fn(async () => undefined),
    markExternalRequestRetry: vi.fn(async () => undefined),
    getExternalRequestResult: vi.fn(async () => null),
    settleExternalResult: vi.fn(async () => undefined),
    ...overrides,
  };
}

const allowPolicy = {
  evaluate: vi.fn(async () => ({
    allowed: true,
    purposeCode: 'INSURANCE_UNDERWRITING',
    policyVersion: 'synthetic-policy-v1',
    reasonCodes: [],
  })),
};

describe('orchestrateProviderRequest', () => {
  it('persists purpose, claims the request, and settles an allowed provider execution', async () => {
    const adapter = new SyntheticProviderAdapter('MVR');
    const store = persistence();

    const result = await orchestrateProviderRequest({
      adapter,
      persistence: store,
      policy: allowPolicy,
      context,
      request: { scenario: 'SUCCESS' as const },
    });

    expect(result.status).toBe('SUCCESS');
    expect(store.createPurposeDecision).toHaveBeenCalledOnce();
    expect(store.createExternalRequest).toHaveBeenCalledOnce();
    expect(store.claimExternalRequest).toHaveBeenCalledOnce();
    expect(store.settleExternalResult).toHaveBeenCalledOnce();
    expect(store.markExternalRequestRetry).not.toHaveBeenCalled();
  });

  it('fails closed before request creation or adapter execution when policy denies', async () => {
    const adapter = new SyntheticProviderAdapter('MVR');
    const executeSpy = vi.spyOn(adapter, 'execute');
    const store = persistence();
    const policy = {
      evaluate: vi.fn(async () => ({
        allowed: false,
        purposeCode: 'INSURANCE_UNDERWRITING',
        policyVersion: 'synthetic-policy-v1',
        reasonCodes: ['MISSING_REQUIRED_AUTHORIZATION'],
      })),
    };

    await expect(
      orchestrateProviderRequest({
        adapter,
        persistence: store,
        policy,
        context: { ...context, consentRecordIds: [] },
        request: { scenario: 'SUCCESS' as const },
      }),
    ).rejects.toThrow('PROVIDER_REQUEST_BLOCKED:MISSING_REQUIRED_AUTHORIZATION');

    expect(store.createPurposeDecision).toHaveBeenCalledOnce();
    expect(store.createExternalRequest).not.toHaveBeenCalled();
    expect(store.claimExternalRequest).not.toHaveBeenCalled();
    expect(executeSpy).not.toHaveBeenCalled();
  });

  it('returns a cached settled result for an idempotent replay without executing provider again', async () => {
    const adapter = new SyntheticProviderAdapter('MVR');
    const executeSpy = vi.spyOn(adapter, 'execute');
    const cached = {
      status: 'SUCCESS' as const,
      providerRequestId: 'cached-request',
      providerReportId: 'cached-report',
      retrievedAt: '2026-08-23T00:00:00.000Z',
      normalized: {
        capability: 'MVR' as const,
        subjectIds: context.subjectIds,
        facts: { licenseStatus: 'VALID' },
      },
      provenance: [],
      warnings: [],
    };
    const store = persistence({
      createExternalRequest: vi.fn(async () => ({ externalRequestId: 'request-1', reused: true })),
      getExternalRequestResult: vi.fn(async () => ({
        requestStatus: 'SUCCEEDED' as const,
        result: cached,
      })),
    });

    const result = await orchestrateProviderRequest({
      adapter,
      persistence: store,
      policy: allowPolicy,
      context,
      request: { scenario: 'SUCCESS' as const },
    });

    expect(result).toEqual(cached);
    expect(store.claimExternalRequest).not.toHaveBeenCalled();
    expect(store.settleExternalResult).not.toHaveBeenCalled();
    expect(executeSpy).not.toHaveBeenCalled();
  });

  it('returns a claimed request to retry state when adapter execution throws', async () => {
    const adapter = new SyntheticProviderAdapter('MVR');
    vi.spyOn(adapter, 'execute').mockRejectedValueOnce(new Error('SYNTHETIC_TRANSIENT'));
    const store = persistence();

    await expect(
      orchestrateProviderRequest({
        adapter,
        persistence: store,
        policy: allowPolicy,
        context,
        request: { scenario: 'SUCCESS' as const },
      }),
    ).rejects.toThrow('SYNTHETIC_TRANSIENT');

    expect(store.claimExternalRequest).toHaveBeenCalledOnce();
    expect(store.markExternalRequestRetry).toHaveBeenCalledWith({
      externalRequestId: 'request-1',
      errorCode: 'SYNTHETIC_TRANSIENT',
      backoffSeconds: 60,
    });
    expect(store.settleExternalResult).not.toHaveBeenCalled();
  });
});
