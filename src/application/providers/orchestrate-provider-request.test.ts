import { describe, expect, it, vi } from 'vitest';

import { orchestrateProviderRequest } from './orchestrate-provider-request';
import { SyntheticProviderAdapter } from '@/src/infrastructure/providers/synthetic-provider';
import type { ProviderRequestContext } from '@/src/domain/providers';

const context: ProviderRequestContext = {
  quoteCaseId: '94000000-0000-0000-0000-000000000001',
  tenantId: '90000000-0000-0000-0000-000000000001',
  agencyId: '91000000-0000-0000-0000-000000000001',
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

describe('orchestrateProviderRequest', () => {
  it('persists purpose, external request, and normalized settlement for an allowed request', async () => {
    const adapter = new SyntheticProviderAdapter('MVR');
    const persistence = {
      createPurposeDecision: vi.fn(async () => ({ decisionId: 'decision-1' })),
      createExternalRequest: vi.fn(async () => ({ externalRequestId: 'request-1', reused: false })),
      settleExternalResult: vi.fn(async () => undefined),
    };
    const policy = {
      evaluate: vi.fn(async () => ({
        allowed: true,
        purposeCode: 'INSURANCE_UNDERWRITING',
        policyVersion: 'synthetic-policy-v1',
        reasonCodes: [],
      })),
    };

    const result = await orchestrateProviderRequest({
      adapter,
      persistence,
      policy,
      context,
      request: { fixture: 'SUCCESS' as const },
    });

    expect(result.status).toBe('SUCCESS');
    expect(persistence.createPurposeDecision).toHaveBeenCalledOnce();
    expect(persistence.createExternalRequest).toHaveBeenCalledOnce();
    expect(persistence.settleExternalResult).toHaveBeenCalledOnce();
  });

  it('fails closed before adapter execution when policy denies the request', async () => {
    const adapter = new SyntheticProviderAdapter('MVR');
    const executeSpy = vi.spyOn(adapter, 'execute');
    const persistence = {
      createPurposeDecision: vi.fn(async () => ({ decisionId: 'decision-deny' })),
      createExternalRequest: vi.fn(async () => ({ externalRequestId: 'never', reused: false })),
      settleExternalResult: vi.fn(async () => undefined),
    };
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
        persistence,
        policy,
        context: { ...context, consentRecordIds: [] },
        request: { fixture: 'SUCCESS' as const },
      }),
    ).rejects.toThrow('PROVIDER_REQUEST_BLOCKED:MISSING_REQUIRED_AUTHORIZATION');

    expect(persistence.createPurposeDecision).toHaveBeenCalledOnce();
    expect(persistence.createExternalRequest).not.toHaveBeenCalled();
    expect(executeSpy).not.toHaveBeenCalled();
  });
});
