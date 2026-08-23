import { describe, expect, it } from 'vitest';

import { SyntheticCarrierAdapter } from './synthetic-carrier';
import type { CarrierRequestContext, RatingInputItem } from '@/src/domain/carriers';

function context(program: 'a' | 'b'): CarrierRequestContext {
  return {
    quoteCaseId: '94000000-0000-0000-0000-000000000001',
    tenantId: '90000000-0000-0000-0000-000000000001',
    agencyId: '91000000-0000-0000-0000-000000000001',
    tenantConfigurationVersion: '1',
    carrierProgramId: `synthetic-program-${program}`,
    carrierProgramVersion: '1',
    traceId: 'trace-carrier',
    idempotencyKey: `carrier-${program}-idem`,
  };
}

function input(id: string, key: string, value: unknown): RatingInputItem {
  return {
    ratingInputId: id,
    inputKey: key,
    approvedValue: value,
    dataUsePolicyVersion: 'synthetic-rating-v1',
    mappingVersion: 'synthetic-map-v1',
  };
}

describe('SyntheticCarrierAdapter portability', () => {
  it('supports variant A using its own required projection', async () => {
    const adapter = new SyntheticCarrierAdapter('A');
    const submission = {
      ratingInputs: [
        input('1', 'license.status', 'VALID'),
        input('2', 'vehicle.annualMileage', 9000),
      ],
    };

    expect((await adapter.validateSubmission(context('a'), submission)).valid).toBe(true);
    expect((await adapter.submit(context('a'), submission)).status).toBe('ACCEPTED');
  });

  it('supports variant B using a different required projection without changing canonical schemas', async () => {
    const adapter = new SyntheticCarrierAdapter('B');
    const submission = {
      ratingInputs: [
        input('3', 'driver.yearsLicensed', 12),
        input('4', 'vehicle.usage', 'COMMUTE'),
      ],
    };

    expect((await adapter.validateSubmission(context('b'), submission)).valid).toBe(true);
    expect((await adapter.submit(context('b'), submission)).status).toBe('ACCEPTED');
  });

  it('rejects a projection intended for another carrier program', async () => {
    const adapter = new SyntheticCarrierAdapter('B');
    const submission = {
      ratingInputs: [
        input('1', 'license.status', 'VALID'),
        input('2', 'vehicle.annualMileage', 9000),
      ],
    };

    const result = await adapter.validateSubmission(context('b'), submission);
    expect(result.valid).toBe(false);
    expect(result.reasonCodes).toContain('MISSING_REQUIRED_INPUT:driver.yearsLicensed');
  });

  it('is deterministic for identical context and rating input', async () => {
    const adapter = new SyntheticCarrierAdapter('A');
    const submission = {
      ratingInputs: [
        input('1', 'license.status', 'VALID'),
        input('2', 'vehicle.annualMileage', 9000),
      ],
    };

    const first = await adapter.submit(context('a'), submission);
    const second = await adapter.submit(context('a'), submission);
    expect(second).toEqual(first);
  });
});
