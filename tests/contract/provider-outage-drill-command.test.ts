import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { describe, expect, it, vi } from 'vitest';
import catalogJson from '../../testdata/canonical/v1/canonical-synthetic-datasets.v1.json';
import { executeCanonicalScenario } from '../../testdata/canonical/v1/scenario-harness';
import { canonicalSyntheticCatalogSchema } from '../../testdata/canonical/v1/schema';
import { assessProviderHealth } from '../../src/application/operations/provider-health';
import {
  orchestrateProviderRequest,
  type ProviderOrchestrationPersistence,
} from '../../src/application/providers/orchestrate-provider-request';
import type { ProviderRequestContext, ProviderResult } from '../../src/domain/providers';
import { SyntheticProviderAdapter, type SyntheticProviderNormalized } from '../../src/infrastructure/providers/synthetic-provider';

const reportPath = process.env.PROVIDER_OUTAGE_DRILL_REPORT_PATH?.trim();
const catalog = canonicalSyntheticCatalogSchema.parse(catalogJson);

describe('provider outage drill operator command', () => {
  it('fails closed, schedules retry, reports blocked health, and recovers', async () => {
    const startedAt = new Date().toISOString();
    const started = performance.now();
    const dataset = catalog.datasets.find((candidate) => candidate.datasetId === 'provider-outage');
    if (!dataset) throw new Error('PROVIDER_OUTAGE_FIXTURE_MISSING');

    const scenario = await executeCanonicalScenario(dataset);
    const adapter = new SyntheticProviderAdapter('MVR');
    vi.spyOn(adapter, 'execute').mockRejectedValueOnce(new Error('PROVIDER_UNAVAILABLE'));

    const drillState: {
      requestStatus: 'PENDING' | 'RUNNING' | 'SUCCEEDED';
      requestCreated: boolean;
      retry: { errorCode: string; backoffSeconds: number } | null;
      settled: ProviderResult<SyntheticProviderNormalized> | null;
    } = { requestStatus: 'PENDING', requestCreated: false, retry: null, settled: null };
    const persistence: ProviderOrchestrationPersistence = {
      createPurposeDecision: vi.fn(async () => ({ decisionId: 'synthetic-purpose-decision' })),
      createExternalRequest: vi.fn(async () => {
        const reused = drillState.requestCreated;
        drillState.requestCreated = true;
        return { externalRequestId: 'synthetic-external-request', reused };
      }),
      claimExternalRequest: vi.fn(async () => { drillState.requestStatus = 'RUNNING'; }),
      markExternalRequestRetry: vi.fn(async (input: { errorCode: string; backoffSeconds: number }) => {
        drillState.retry = { errorCode: input.errorCode, backoffSeconds: input.backoffSeconds };
        drillState.requestStatus = 'PENDING';
      }),
      getExternalRequestResult: async <T,>(_input: { externalRequestId: string }): Promise<{
        requestStatus: 'PENDING' | 'RUNNING' | 'SUCCEEDED' | 'FAILED' | 'BLOCKED';
        result: ProviderResult<T> | null;
      } | null> => ({
        requestStatus: drillState.requestStatus,
        result: drillState.settled as ProviderResult<T> | null,
      }),
      settleExternalResult: async <T,>(input: { result: ProviderResult<T> }) => {
        drillState.settled = input.result as ProviderResult<SyntheticProviderNormalized>;
        drillState.requestStatus = 'SUCCEEDED';
      },
    };
    const policy = { evaluate: vi.fn(async () => ({
      allowed: true,
      purposeCode: 'INSURANCE_UNDERWRITING',
      policyVersion: 'synthetic-policy-v1',
      reasonCodes: [],
    })) };
    const context: ProviderRequestContext = {
      quoteCaseId: 'synthetic-quote-case', tenantId: 'synthetic-tenant', agencyId: 'synthetic-agency',
      actorId: 'synthetic-actor', tenantConfigurationVersion: '1', jurisdiction: 'CA',
      productLine: 'PRIVATE_PASSENGER_AUTO', capability: 'MVR', providerBindingId: 'synthetic-binding',
      permissiblePurposeDecisionId: 'synthetic-purpose', consentRecordIds: ['synthetic-consent'],
      subjectIds: ['synthetic-subject'], traceId: 'synthetic-outage-drill', idempotencyKey: 'synthetic-outage-drill',
    };

    let outageErrorCode: string | null = null;
    try {
      await orchestrateProviderRequest({ adapter, persistence, policy, context, request: { scenario: 'SUCCESS' } });
    } catch (error) {
      outageErrorCode = error instanceof Error ? error.message : 'UNKNOWN';
    }

    const outageHealth = assessProviderHealth({ statuses: { MVR: 'ERROR' }, requiredCapabilities: ['MVR'] });
    const recovered = await orchestrateProviderRequest({ adapter, persistence, policy, context, request: { scenario: 'SUCCESS' } });
    const recoveryHealth = assessProviderHealth({ statuses: { MVR: recovered.status }, requiredCapabilities: ['MVR'] });
    const elapsedMilliseconds = performance.now() - started;
    const passed = scenario.providerStatuses.MVR === 'ERROR'
      && scenario.readiness === 'REVIEW_REQUIRED'
      && scenario.carrierSubmissionAllowed === false
      && scenario.carrierStatus === 'NOT_SUBMITTED'
      && outageErrorCode === 'PROVIDER_UNAVAILABLE'
      && drillState.retry?.errorCode === 'PROVIDER_UNAVAILABLE'
      && drillState.retry?.backoffSeconds === 60
      && outageHealth.verdict === 'blocked'
      && outageHealth.quoteCompletionBlocked
      && recovered.status === 'SUCCESS'
      && recoveryHealth.verdict === 'ready'
      && drillState.requestStatus === 'SUCCEEDED'
      && elapsedMilliseconds <= 60_000;

    const report = {
      schemaVersion: 'provider-outage-drill-report-v1',
      reliabilityContractVersion: 'reliability-v1',
      fixtureId: 'F009',
      datasetId: dataset.datasetId,
      startedAt,
      completedAt: new Date().toISOString(),
      observed: {
        outage: {
          providerCapability: 'MVR', providerStatus: scenario.providerStatuses.MVR,
          errorCode: outageErrorCode, retryBackoffSeconds: drillState.retry?.backoffSeconds ?? null,
          quoteReadiness: scenario.readiness, carrierSubmissionAllowed: scenario.carrierSubmissionAllowed,
          carrierStatus: scenario.carrierStatus, health: outageHealth,
        },
        recovery: { providerStatus: recovered.status, requestStatus: drillState.requestStatus, health: recoveryHealth },
        elapsedMilliseconds: Number(elapsedMilliseconds.toFixed(2)),
      },
      liveProviderVerified: false,
      passed,
    };
    const serialized = `${JSON.stringify(report, null, 2)}\n`;
    process.stdout.write(serialized);
    if (reportPath) {
      await mkdir(dirname(reportPath), { recursive: true });
      await writeFile(reportPath, serialized, 'utf8');
    }
    expect(passed).toBe(true);
  });
});
