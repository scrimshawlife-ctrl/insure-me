import { describe, expect, it } from 'vitest';

import { normalizeProviderResultForObservations } from './normalize-provider-result';
import { SyntheticProviderAdapter } from '@/src/infrastructure/providers/synthetic-provider';
import type { ProviderRequestContext } from '@/src/domain/providers';

const context: ProviderRequestContext = {
  quoteCaseId: 'qc-test',
  tenantId: 'tenant-test',
  agencyId: 'agency-test',
  tenantConfigurationVersion: '1',
  jurisdiction: 'CA',
  productLine: 'PRIVATE_PASSENGER_AUTO',
  capability: 'MVR',
  providerBindingId: 'binding-test',
  permissiblePurposeDecisionId: 'decision-test',
  consentRecordIds: ['consent-test'],
  subjectIds: ['driver-test'],
  traceId: 'trace-test',
  idempotencyKey: 'idem-test',
};

describe('normalizeProviderResultForObservations', () => {
  it('creates only allowlisted provenance-backed observation drafts', async () => {
    const result = await new SyntheticProviderAdapter('MVR').execute(context, {
      scenario: 'SUCCESS',
    });

    const normalized = normalizeProviderResultForObservations({
      capability: 'MVR',
      subjectIds: context.subjectIds,
      result,
    });

    expect(normalized.observations.map((item) => item.observationType)).toEqual([
      'LICENSE_STATUS',
      'MOVING_VIOLATION_COUNT',
    ]);
    expect(normalized.observations.every((item) => item.dataUseClassification === 'UNCLASSIFIED')).toBe(true);
    expect(normalized.provenance).toHaveLength(2);
  });

  it('does not invent observations for no-hit reports', async () => {
    const result = await new SyntheticProviderAdapter('MVR').execute(context, {
      scenario: 'NO_HIT',
    });

    expect(
      normalizeProviderResultForObservations({
        capability: 'MVR',
        subjectIds: context.subjectIds,
        result,
      }),
    ).toEqual({ provenance: [], observations: [] });
  });

  it('marks observations stale when the provider result is stale', async () => {
    const result = await new SyntheticProviderAdapter('MVR').execute(context, {
      scenario: 'STALE',
    });
    const normalized = normalizeProviderResultForObservations({
      capability: 'MVR',
      subjectIds: context.subjectIds,
      result,
    });

    expect(normalized.observations.every((item) => item.freshnessState === 'STALE')).toBe(true);
  });
});
