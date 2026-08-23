import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { describe, expect, it } from 'vitest';
import catalogJson from '../../testdata/canonical/v1/canonical-synthetic-datasets.v1.json';
import { runCanonicalScenarioSuite } from '../../testdata/canonical/v1/scenario-runner';
import { canonicalSyntheticCatalogSchema } from '../../testdata/canonical/v1/schema';

const catalog = canonicalSyntheticCatalogSchema.parse(catalogJson);
const selectedDatasetId = process.env.CANONICAL_SCENARIO_ID?.trim() || undefined;
const reportPath = process.env.CANONICAL_SCENARIO_REPORT_PATH?.trim() || undefined;

describe('canonical scenario operator command', () => {
  it(selectedDatasetId ? `runs ${selectedDatasetId}` : 'runs the full canonical suite', async () => {
    const report = await runCanonicalScenarioSuite(catalog.datasets, selectedDatasetId);
    const serialized = `${JSON.stringify(report, null, 2)}\n`;

    process.stdout.write(serialized);

    if (reportPath) {
      await mkdir(dirname(reportPath), { recursive: true });
      await writeFile(reportPath, serialized, 'utf8');
    }

    expect(report.failed).toBe(0);
    expect(report.passed).toBe(report.total);
    expect(report.total).toBe(selectedDatasetId ? 1 : 12);
  });
});
