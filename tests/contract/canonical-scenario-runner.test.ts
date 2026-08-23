import { describe, expect, it } from 'vitest';
import catalogJson from '../../testdata/canonical/v1/canonical-synthetic-datasets.v1.json';
import {
  runCanonicalScenarioSuite,
} from '../../testdata/canonical/v1/scenario-runner';
import { canonicalSyntheticCatalogSchema } from '../../testdata/canonical/v1/schema';

const catalog = canonicalSyntheticCatalogSchema.parse(catalogJson);

describe('canonical scenario report runner v1', () => {
  it('reports all 12 canonical scenarios as passing', async () => {
    const report = await runCanonicalScenarioSuite(catalog.datasets);
    expect(report.schemaVersion).toBe('canonical-scenario-report-v1');
    expect(report.total).toBe(12);
    expect(report.passed).toBe(12);
    expect(report.failed).toBe(0);
    expect(report.reports.every((item) => item.passed && item.deltas.length === 0)).toBe(true);
  });

  it('runs one selected scenario by canonical dataset ID', async () => {
    const report = await runCanonicalScenarioSuite(catalog.datasets, 'stale-report');
    expect(report.total).toBe(1);
    expect(report.reports[0]?.datasetId).toBe('stale-report');
    expect(report.reports[0]?.passed).toBe(true);
  });

  it('fails closed for an unknown canonical scenario ID', async () => {
    await expect(
      runCanonicalScenarioSuite(catalog.datasets, 'not-a-canonical-scenario'),
    ).rejects.toThrow('CANONICAL_SCENARIO_NOT_FOUND:not-a-canonical-scenario');
  });
});
