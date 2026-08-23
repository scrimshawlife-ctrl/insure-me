import type { ProviderCapability, ProviderResult, ProvenanceEntry } from '@/src/domain/providers';

export interface ProvenanceDraft extends ProvenanceEntry {
  factKey: string;
}

export interface UnderwritingObservationDraft {
  observationType: string;
  subjectId: string | null;
  normalizedValue: unknown;
  provenanceFactKeys: string[];
  dataUseClassification: 'UNCLASSIFIED';
  freshnessState: 'CURRENT' | 'STALE';
  conflictState: 'NONE';
}

const OBSERVATION_KEYS: Record<ProviderCapability, Record<string, string>> = {
  IDENTITY: {
    identityMatch: 'IDENTITY_MATCH',
  },
  PREFILL: {
    matchedDriverCount: 'PREFILL_MATCHED_DRIVER_COUNT',
    matchedVehicleCount: 'PREFILL_MATCHED_VEHICLE_COUNT',
  },
  MVR: {
    licenseStatus: 'LICENSE_STATUS',
    movingViolationCount: 'MOVING_VIOLATION_COUNT',
  },
  CLAIMS: {
    claimCount: 'CLAIM_COUNT',
    latestLossDate: 'LATEST_LOSS_DATE',
  },
  VEHICLE: {
    titleStatus: 'VEHICLE_TITLE_STATUS',
    severeDamageIndicator: 'VEHICLE_SEVERE_DAMAGE_INDICATOR',
  },
};

export function normalizeProviderResultForObservations(input: {
  capability: ProviderCapability;
  subjectIds: string[];
  result: ProviderResult<{
    capability: ProviderCapability;
    subjectIds: string[];
    facts: Record<string, string | number | boolean | null>;
  }>;
}): {
  provenance: ProvenanceDraft[];
  observations: UnderwritingObservationDraft[];
} {
  if (!input.result.normalized) {
    return { provenance: [], observations: [] };
  }

  const allowedKeys = OBSERVATION_KEYS[input.capability];
  const provenance = input.result.provenance
    .filter((entry) => entry.normalizedFactKey in allowedKeys)
    .map((entry) => ({ ...entry, factKey: entry.normalizedFactKey }));

  const observations = Object.entries(input.result.normalized.facts).flatMap(
    ([factKey, value]) => {
      const observationType = allowedKeys[factKey];
      if (!observationType) return [];

      const subjectId = input.subjectIds.length === 1 ? input.subjectIds[0] : null;
      return [
        {
          observationType,
          subjectId,
          normalizedValue: value,
          provenanceFactKeys: [factKey],
          dataUseClassification: 'UNCLASSIFIED' as const,
          freshnessState: input.result.status === 'STALE' ? ('STALE' as const) : ('CURRENT' as const),
          conflictState: 'NONE' as const,
        },
      ];
    },
  );

  return { provenance, observations };
}
