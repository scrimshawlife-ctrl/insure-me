import { describe, expect, it } from 'vitest';
import catalogJson from '../../testdata/canonical/v1/canonical-synthetic-datasets.v1.json';
import { executeCanonicalScenario } from '../../testdata/canonical/v1/scenario-harness';
import { canonicalSyntheticCatalogSchema } from '../../testdata/canonical/v1/schema';

const catalog = canonicalSyntheticCatalogSchema.parse(catalogJson);

describe('canonical scenario harness v1', () => {
  for (const dataset of catalog.datasets) {
    it(`executes ${dataset.datasetId} against the synthetic runtime contracts`, async () => {
      const observed = await executeCanonicalScenario(dataset);

      expect(observed.datasetId).toBe(dataset.datasetId);
      expect(observed.providerStatuses).toEqual(dataset.expected.providerStatuses);
      expect(observed.readiness).toBe(dataset.expected.quoteReadiness);
      expect(observed.carrierSubmissionAllowed).toBe(
        dataset.expected.carrierSubmissionAllowed,
      );
      expect(observed.carrierStatus).toBe(dataset.carrier.expectedStatus);

      if (dataset.carrier.expectedReasonCodes) {
        expect(observed.carrierReasonCodes).toEqual(dataset.carrier.expectedReasonCodes);
      }

      for (const request of dataset.providerRequests) {
        const key = request.capability.toLowerCase();
        const expectedFacts = dataset.normalizedFacts[key];
        const observedFacts = observed.normalizedFacts[key];

        if (
          observed.providerStatuses[request.capability] === 'SUCCESS' ||
          observed.providerStatuses[request.capability] === 'PARTIAL' ||
          observed.providerStatuses[request.capability] === 'STALE'
        ) {
          expect(observedFacts).toEqual(expectedFacts);
        } else {
          expect(observedFacts).toBeNull();
        }
      }
    });
  }

  it('executes exactly the canonical 12-scenario inventory', () => {
    expect(catalog.datasets).toHaveLength(12);
  });
});
