import type { CarrierSubmissionResult } from '../../../src/domain/carriers';
import type { ProviderCapability, ProviderResultStatus } from '../../../src/domain/providers';
import { SyntheticCarrierAdapter } from '../../../src/infrastructure/carriers/synthetic-carrier';
import { SyntheticProviderAdapter } from '../../../src/infrastructure/providers/synthetic-provider';
import type { CanonicalSyntheticDataset } from './schema';
import { materializeRuntimeSeed, uuidV5 } from './runtime-seed';

export type HarnessProviderStatus = ProviderResultStatus | 'BLOCKED';
export type HarnessReadiness = 'READY_FOR_CARRIER' | 'REVIEW_REQUIRED' | 'RETENTION_HOLD';
export type HarnessCarrierStatus = CarrierSubmissionResult['status'] | 'NOT_SUBMITTED';

export interface CanonicalScenarioObservation {
  datasetId: string;
  quoteCaseId: string;
  providerStatuses: Record<string, HarnessProviderStatus>;
  normalizedFacts: Record<string, Record<string, string | number | boolean | null> | null>;
  readiness: HarnessReadiness;
  carrierSubmissionAllowed: boolean;
  carrierStatus: HarnessCarrierStatus;
  carrierReasonCodes: string[];
}

/**
 * Executes one canonical scenario against the real synthetic provider/carrier adapters.
 * The dataset `expected` section is never read here; it remains an external assertion oracle.
 */
export async function executeCanonicalScenario(
  dataset: CanonicalSyntheticDataset,
): Promise<CanonicalScenarioObservation> {
  const seed = materializeRuntimeSeed(dataset);
  const providerStatuses: Record<string, HarnessProviderStatus> = {};
  const normalizedFacts: CanonicalScenarioObservation['normalizedFacts'] = {};
  const noticeCategories = new Set(dataset.notices.map((notice) => notice.category));

  for (const [index, request] of seed.providerRequests.entries()) {
    const adapter = new SyntheticProviderAdapter(request.capability);
    const descriptor = adapter.capabilities()[0];
    if (!descriptor) throw new Error(`MISSING_SYNTHETIC_PROVIDER_DESCRIPTOR:${request.capability}`);

    const missingNotices = descriptor.requiredNoticeCategories.filter(
      (category) => !noticeCategories.has(category),
    );

    if (missingNotices.length > 0) {
      providerStatuses[request.capability] = 'BLOCKED';
      normalizedFacts[request.capability.toLowerCase()] = null;
      continue;
    }

    const factOverrides = normalizedFactOverrides(dataset, request.capability);
    const result = await adapter.execute(
      {
        quoteCaseId: seed.quoteCase.quoteCaseId,
        tenantId: seed.tenant.tenantId,
        agencyId: seed.tenant.agencyId,
        actorId: uuidV5(`actor:${dataset.datasetId}`),
        tenantConfigurationVersion: String(seed.tenant.configurationVersion),
        jurisdiction: 'CA',
        productLine: 'PRIVATE_PASSENGER_AUTO',
        capability: request.capability,
        providerBindingId: uuidV5(`provider-binding:${request.capability}`),
        permissiblePurposeDecisionId: uuidV5(
          `purpose:${dataset.datasetId}:${request.capability}:${index}`,
        ),
        consentRecordIds: dataset.notices.map((notice, noticeIndex) =>
          uuidV5(`consent:${dataset.datasetId}:${notice.category}:${noticeIndex}`),
        ),
        subjectIds: request.subjectIds,
        traceId: `canonical:${dataset.datasetId}:${request.capability.toLowerCase()}`,
        idempotencyKey: `canonical:${dataset.datasetId}:${request.capability.toLowerCase()}:${index}`,
      },
      {
        scenario: request.scenario,
        ...(factOverrides ? { factOverrides } : {}),
      },
    );

    providerStatuses[request.capability] = result.status;
    normalizedFacts[request.capability.toLowerCase()] = result.normalized?.facts ?? null;
  }

  const readiness = deriveReadiness(dataset, providerStatuses);
  const carrierSubmissionAllowed = readiness === 'READY_FOR_CARRIER';

  if (!carrierSubmissionAllowed) {
    return {
      datasetId: dataset.datasetId,
      quoteCaseId: seed.quoteCase.quoteCaseId,
      providerStatuses,
      normalizedFacts,
      readiness,
      carrierSubmissionAllowed,
      carrierStatus: 'NOT_SUBMITTED',
      carrierReasonCodes: [],
    };
  }

  const carrier = new SyntheticCarrierAdapter(dataset.carrier.variant, {
    carrierId: seed.carrier.carrierId,
    carrierProgramId: seed.carrier.carrierProgramId,
  });
  const carrierResult = await carrier.submit(
    {
      quoteCaseId: seed.quoteCase.quoteCaseId,
      tenantId: seed.tenant.tenantId,
      agencyId: seed.tenant.agencyId,
      tenantConfigurationVersion: String(seed.tenant.configurationVersion),
      carrierProgramId: seed.carrier.carrierProgramId,
      carrierProgramVersion: '1',
      traceId: `canonical:${dataset.datasetId}:carrier`,
      idempotencyKey: `canonical:${dataset.datasetId}:carrier`,
    },
    {
      ratingInputs: dataset.carrier.ratingInputs.map((input, index) => ({
        ratingInputId: uuidV5(`rating-input:${dataset.datasetId}:${input.inputKey}:${index}`),
        inputKey: input.inputKey,
        approvedValue: input.approvedValue,
        dataUsePolicyVersion: 'canonical-synthetic-data-use-v1',
        mappingVersion: `canonical-synthetic-${dataset.carrier.variant.toLowerCase()}-v1`,
      })),
    },
  );

  return {
    datasetId: dataset.datasetId,
    quoteCaseId: seed.quoteCase.quoteCaseId,
    providerStatuses,
    normalizedFacts,
    readiness,
    carrierSubmissionAllowed,
    carrierStatus: carrierResult.status,
    carrierReasonCodes: carrierResult.reasonCodes,
  };
}

function deriveReadiness(
  dataset: CanonicalSyntheticDataset,
  statuses: Record<string, HarnessProviderStatus>,
): HarnessReadiness {
  if (dataset.privacyActions.length > 0) return 'RETENTION_HOLD';
  if (dataset.conflicts.length > 0) return 'REVIEW_REQUIRED';

  const blockingStatuses = new Set<HarnessProviderStatus>([
    'BLOCKED',
    'NO_HIT',
    'PARTIAL',
    'STALE',
    'ERROR',
  ]);
  if (Object.values(statuses).some((status) => blockingStatuses.has(status))) {
    return 'REVIEW_REQUIRED';
  }

  return 'READY_FOR_CARRIER';
}

function normalizedFactOverrides(
  dataset: CanonicalSyntheticDataset,
  capability: ProviderCapability,
): Record<string, string | number | boolean | null> | undefined {
  const value = dataset.normalizedFacts[capability.toLowerCase()];
  if (!value || typeof value !== 'object' || Array.isArray(value)) return undefined;

  const output: Record<string, string | number | boolean | null> = {};
  for (const [key, fact] of Object.entries(value)) {
    if (
      fact === null ||
      typeof fact === 'string' ||
      typeof fact === 'number' ||
      typeof fact === 'boolean'
    ) {
      output[key] = fact;
    }
  }
  return output;
}
