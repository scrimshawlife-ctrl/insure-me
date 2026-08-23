import type { CanonicalSyntheticDataset } from './schema';
import { executeCanonicalScenario, type CanonicalScenarioObservation } from './scenario-harness';

export interface CanonicalScenarioDelta {
  field: string;
  expected: unknown;
  observed: unknown;
}

export interface CanonicalScenarioReport {
  datasetId: string;
  passed: boolean;
  observation: CanonicalScenarioObservation;
  deltas: CanonicalScenarioDelta[];
}

export interface CanonicalScenarioSuiteReport {
  schemaVersion: 'canonical-scenario-report-v1';
  total: number;
  passed: number;
  failed: number;
  reports: CanonicalScenarioReport[];
}

export async function runCanonicalScenario(
  dataset: CanonicalSyntheticDataset,
): Promise<CanonicalScenarioReport> {
  const observation = await executeCanonicalScenario(dataset);
  const deltas: CanonicalScenarioDelta[] = [];

  compare(deltas, 'providerStatuses', dataset.expected.providerStatuses, observation.providerStatuses);
  compare(deltas, 'readiness', dataset.expected.quoteReadiness, observation.readiness);
  compare(
    deltas,
    'carrierSubmissionAllowed',
    dataset.expected.carrierSubmissionAllowed,
    observation.carrierSubmissionAllowed,
  );
  compare(deltas, 'carrierStatus', dataset.carrier.expectedStatus, observation.carrierStatus);

  if (dataset.carrier.expectedReasonCodes) {
    compare(
      deltas,
      'carrierReasonCodes',
      dataset.carrier.expectedReasonCodes,
      observation.carrierReasonCodes,
    );
  }

  for (const request of dataset.providerRequests) {
    const key = request.capability.toLowerCase();
    const status = observation.providerStatuses[request.capability];
    const expectsFacts = status === 'SUCCESS' || status === 'PARTIAL' || status === 'STALE';
    compare(
      deltas,
      `normalizedFacts.${key}`,
      expectsFacts ? (dataset.normalizedFacts[key] ?? null) : null,
      observation.normalizedFacts[key] ?? null,
    );
  }

  return {
    datasetId: dataset.datasetId,
    passed: deltas.length === 0,
    observation,
    deltas,
  };
}

export async function runCanonicalScenarioSuite(
  datasets: CanonicalSyntheticDataset[],
  datasetId?: string,
): Promise<CanonicalScenarioSuiteReport> {
  const selected = datasetId
    ? datasets.filter((dataset) => dataset.datasetId === datasetId)
    : datasets;

  if (datasetId && selected.length === 0) {
    throw new Error(`CANONICAL_SCENARIO_NOT_FOUND:${datasetId}`);
  }

  const reports: CanonicalScenarioReport[] = [];
  for (const dataset of selected) {
    reports.push(await runCanonicalScenario(dataset));
  }

  const passed = reports.filter((report) => report.passed).length;
  return {
    schemaVersion: 'canonical-scenario-report-v1',
    total: reports.length,
    passed,
    failed: reports.length - passed,
    reports,
  };
}

function compare(
  deltas: CanonicalScenarioDelta[],
  field: string,
  expected: unknown,
  observed: unknown,
): void {
  if (stableJson(expected) === stableJson(observed)) return;
  deltas.push({ field, expected, observed });
}

function stableJson(value: unknown): string {
  return JSON.stringify(normalize(value));
}

function normalize(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(normalize);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, nested]) => [key, normalize(nested)]),
    );
  }
  return value;
}
