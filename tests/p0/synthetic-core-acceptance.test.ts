import { describe, expect, it } from 'vitest';

import { SyntheticProviderAdapter } from '@/src/infrastructure/providers/synthetic-provider';
import { normalizeProviderResultForObservations } from '@/src/application/providers/normalize-provider-result';
import { SyntheticCarrierAdapter } from '@/src/infrastructure/carriers/synthetic-carrier';
import type { ProviderRequestContext } from '@/src/domain/providers';
import type { CarrierRequestContext, RatingInputItem } from '@/src/domain/carriers';

const quoteCaseId = '94000000-0000-0000-0000-000000000001';
const tenantId = '90000000-0000-0000-0000-000000000001';
const agencyId = '91000000-0000-0000-0000-000000000001';
const actorId = '92000000-0000-0000-0000-000000000001';

function providerContext(
  capability: ProviderRequestContext['capability'],
  subjectIds: string[],
): ProviderRequestContext {
  return {
    quoteCaseId,
    tenantId,
    agencyId,
    actorId,
    tenantConfigurationVersion: '1',
    jurisdiction: 'CA',
    productLine: 'PRIVATE_PASSENGER_AUTO',
    capability,
    providerBindingId: `binding-${capability.toLowerCase()}`,
    permissiblePurposeDecisionId: `purpose-${capability.toLowerCase()}`,
    consentRecordIds: ['consent-report-authorization'],
    subjectIds,
    traceId: `trace-${capability.toLowerCase()}`,
    idempotencyKey: `idem-${capability.toLowerCase()}`,
  };
}

function carrierContext(program: 'a' | 'b'): CarrierRequestContext {
  return {
    quoteCaseId,
    tenantId,
    agencyId,
    tenantConfigurationVersion: '1',
    carrierProgramId: `synthetic-program-${program}`,
    carrierProgramVersion: '1',
    traceId: `trace-carrier-${program}`,
    idempotencyKey: `idem-carrier-${program}`,
  };
}

const programMappings = {
  a: {
    LICENSE_STATUS: 'mvr.licenseStatus',
    CLAIM_COUNT: 'claims.claimCount',
  },
  b: {
    MOVING_VIOLATION_COUNT: 'mvr.movingViolationCount',
    VEHICLE_SEVERE_DAMAGE_INDICATOR: 'vehicle.severeDamageIndicator',
  },
} as const;

function projectRatingInputs(
  program: 'a' | 'b',
  observations: Array<{
    observationType: string;
    normalizedValue: unknown;
    dataUseClassification: 'RATING_SUBMISSION_ALLOWED';
    freshnessState: 'CURRENT';
    conflictState: 'NONE';
  }>,
): RatingInputItem[] {
  const mapping: Record<string, string> = programMappings[program];
  return observations.flatMap((observation, index) => {
    const inputKey = mapping[observation.observationType];
    if (!inputKey) return [];
    return [
      {
        ratingInputId: `${program}-${index}`,
        inputKey,
        approvedValue: observation.normalizedValue,
        dataUsePolicyVersion: 'synthetic-data-use-v1',
        mappingVersion: `mapping-${program}-v1`,
      },
    ];
  });
}

describe('SYNTHETIC_CORE_ACCEPTED portability path', () => {
  it('flows deterministic provider facts through explicit policy projection into two independent carrier programs', async () => {
    const providerRuns = await Promise.all([
      new SyntheticProviderAdapter('MVR').execute(
        providerContext('MVR', ['driver-1']),
        { scenario: 'SUCCESS' },
      ),
      new SyntheticProviderAdapter('CLAIMS').execute(
        providerContext('CLAIMS', ['driver-1']),
        { scenario: 'SUCCESS' },
      ),
      new SyntheticProviderAdapter('VEHICLE').execute(
        providerContext('VEHICLE', ['vehicle-1']),
        { scenario: 'SUCCESS' },
      ),
    ]);

    const normalized = [
      normalizeProviderResultForObservations({
        capability: 'MVR',
        subjectIds: ['driver-1'],
        result: providerRuns[0],
      }),
      normalizeProviderResultForObservations({
        capability: 'CLAIMS',
        subjectIds: ['driver-1'],
        result: providerRuns[1],
      }),
      normalizeProviderResultForObservations({
        capability: 'VEHICLE',
        subjectIds: ['vehicle-1'],
        result: providerRuns[2],
      }),
    ];

    expect(normalized.every((slice) => slice.provenance.length > 0)).toBe(true);
    expect(
      normalized.flatMap((slice) => slice.observations).every(
        (observation) => observation.dataUseClassification === 'UNCLASSIFIED',
      ),
    ).toBe(true);

    const policyApproved = normalized.flatMap((slice) =>
      slice.observations.map((observation) => ({
        observationType: observation.observationType,
        normalizedValue: observation.normalizedValue,
        dataUseClassification: 'RATING_SUBMISSION_ALLOWED' as const,
        freshnessState: 'CURRENT' as const,
        conflictState: 'NONE' as const,
      })),
    );

    const carrierAInputs = projectRatingInputs('a', policyApproved);
    const carrierBInputs = projectRatingInputs('b', policyApproved);

    expect(carrierAInputs.map((item) => item.inputKey).sort()).toEqual([
      'claims.claimCount',
      'mvr.licenseStatus',
    ]);
    expect(carrierBInputs.map((item) => item.inputKey).sort()).toEqual([
      'mvr.movingViolationCount',
      'vehicle.severeDamageIndicator',
    ]);

    const carrierA = new SyntheticCarrierAdapter('A');
    const carrierB = new SyntheticCarrierAdapter('B');

    const resultA = await carrierA.submit(carrierContext('a'), {
      ratingInputs: carrierAInputs,
    });
    const resultB = await carrierB.submit(carrierContext('b'), {
      ratingInputs: carrierBInputs,
    });

    expect(resultA.status).toBe('ACCEPTED');
    expect(resultB.status).toBe('ACCEPTED');
    expect(resultA.externalReference).not.toBe(resultB.externalReference);
    expect(resultA.premium).toBeDefined();
    expect(resultB.premium).toBeDefined();
  });

  it('does not manufacture carrier inputs from a NO_HIT provider result', async () => {
    const noHit = await new SyntheticProviderAdapter('MVR').execute(
      providerContext('MVR', ['driver-1']),
      { scenario: 'NO_HIT' },
    );
    const normalized = normalizeProviderResultForObservations({
      capability: 'MVR',
      subjectIds: ['driver-1'],
      result: noHit,
    });

    expect(noHit.status).toBe('NO_HIT');
    expect(normalized.observations).toEqual([]);
    expect(projectRatingInputs('a', [])).toEqual([]);
  });

  it('does not project stale facts as current carrier inputs', async () => {
    const stale = await new SyntheticProviderAdapter('MVR').execute(
      providerContext('MVR', ['driver-1']),
      { scenario: 'STALE' },
    );
    const normalized = normalizeProviderResultForObservations({
      capability: 'MVR',
      subjectIds: ['driver-1'],
      result: stale,
    });

    expect(normalized.observations.every((observation) => observation.freshnessState === 'STALE')).toBe(true);
    const currentOnly = normalized.observations.filter(
      (observation) => observation.freshnessState === 'CURRENT',
    );
    expect(currentOnly).toEqual([]);
  });
});
