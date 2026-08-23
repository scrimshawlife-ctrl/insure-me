import { describe, expect, it } from 'vitest';

import type { ProviderRequestContext } from '@/src/domain/providers';
import { SyntheticProviderAdapter } from '@/src/infrastructure/providers/synthetic-provider';

function context(capability: ProviderRequestContext['capability']): ProviderRequestContext {
  return {
    quoteCaseId: 'qc_test',
    tenantId: 'tenant_test',
    agencyId: 'agency_test',
    actorId: 'actor_test',
    tenantConfigurationVersion: '1',
    jurisdiction: 'CA',
    productLine: 'PRIVATE_PASSENGER_AUTO',
    capability,
    providerBindingId: `binding_${capability.toLowerCase()}`,
    permissiblePurposeDecisionId: 'purpose_test',
    consentRecordIds: [],
    subjectIds: ['subject_test'],
    traceId: 'trace_test',
    idempotencyKey: 'idem_test',
  };
}

describe('SyntheticProviderAdapter', () => {
  it('is deterministic for the same capability and scenario', async () => {
    const adapter = new SyntheticProviderAdapter('MVR');
    const first = await adapter.execute(context('MVR'), { scenario: 'SUCCESS' });
    const second = await adapter.execute(context('MVR'), { scenario: 'SUCCESS' });
    expect(first).toEqual(second);
    expect(first.status).toBe('SUCCESS');
    expect(first.normalized?.facts.licenseStatus).toBe('VALID');
  });

  it('models no-hit without fabricating normalized facts', async () => {
    const adapter = new SyntheticProviderAdapter('CLAIMS');
    const result = await adapter.execute(context('CLAIMS'), { scenario: 'NO_HIT' });
    expect(result.status).toBe('NO_HIT');
    expect(result.normalized).toBeNull();
    expect(result.provenance).toEqual([]);
  });

  it('rejects a capability mismatch before execution', async () => {
    const adapter = new SyntheticProviderAdapter('VEHICLE');
    await expect(adapter.execute(context('MVR'), { scenario: 'SUCCESS' })).rejects.toThrow(
      'PROVIDER_CAPABILITY_MISMATCH',
    );
  });

  it('declares report authorization requirements for regulated report capabilities', () => {
    const descriptor = new SyntheticProviderAdapter('MVR').capabilities()[0];
    expect(descriptor.requiredNoticeCategories).toContain('REPORT_AUTHORIZATION');
    expect(descriptor.rawPayloadStoragePermitted).toBe(false);
  });
});
