import { describe, expect, it } from 'vitest';
import catalogJson from '../../testdata/canonical/v1/canonical-synthetic-datasets.v1.json';
import { canonicalSyntheticCatalogSchema } from '../../testdata/canonical/v1/schema';
import { materializeRuntimeSeed, syntheticVin, uuidV5 } from '../../testdata/canonical/v1/runtime-seed';

const catalog = canonicalSyntheticCatalogSchema.parse(catalogJson);
const UUID_V5 = /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const VIN = /^[A-HJ-NPR-Z0-9]{17}$/;

describe('canonical runtime seed materializer', () => {
  it('is deterministic', () => {
    expect(uuidV5('quote-case:qc-happy-path')).toBe(uuidV5('quote-case:qc-happy-path'));
    expect(syntheticVin('vehicle-happy-path-01')).toBe(syntheticVin('vehicle-happy-path-01'));
  });

  it('materializes every database-facing identity as UUIDv5', () => {
    for (const source of catalog.datasets) {
      const seed = materializeRuntimeSeed(source);
      const ids = [
        seed.tenant.tenantId,
        seed.tenant.agencyId,
        seed.tenant.tenantConfigurationId,
        seed.quoteCase.quoteCaseId,
        seed.quoteCase.prospectId,
        seed.consumer.personId,
        seed.consumer.subjectId,
        seed.carrier.carrierId,
        seed.carrier.carrierProgramId,
        ...seed.drivers.flatMap((driver) => [driver.driverId, driver.personId, driver.subjectId]),
        ...seed.vehicles.map((vehicle) => vehicle.vehicleId),
        ...seed.providerRequests.flatMap((request) => request.subjectIds),
      ];
      for (const id of ids) expect(id).toMatch(UUID_V5);
      expect(seed.tenant.configurationVersion).toBe(1);
    }
  });

  it('keeps the same semantic subject mapped to the same person UUID', () => {
    const source = catalog.datasets.find((dataset) => dataset.datasetId === 'multiple-drivers');
    expect(source).toBeDefined();
    const seed = materializeRuntimeSeed(source!);
    expect(seed.consumer.personId).toBe(seed.drivers[0]?.personId);
    expect(seed.consumer.subjectId).toBe(seed.drivers[0]?.subjectId);
    expect(seed.drivers[1]?.personId).not.toBe(seed.consumer.personId);
  });

  it('materializes VIN-shaped values without forbidden VIN characters', () => {
    for (const source of catalog.datasets) {
      const seed = materializeRuntimeSeed(source);
      for (const vehicle of seed.vehicles) expect(vehicle.vin).toMatch(VIN);
    }
  });

  it('does not mutate the canonical human-readable source catalog', () => {
    const source = catalog.datasets[0]!;
    const originalQuoteCaseId = source.quoteCase.quoteCaseId;
    const originalVin = source.vehicles[0]!.vin;
    materializeRuntimeSeed(source);
    expect(source.quoteCase.quoteCaseId).toBe(originalQuoteCaseId);
    expect(source.vehicles[0]!.vin).toBe(originalVin);
  });
});
