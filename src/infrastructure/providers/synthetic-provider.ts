import type {
  ProviderAdapter,
  ProviderCapability,
  ProviderCapabilityDescriptor,
  ProviderRequestContext,
  ProviderResult,
  ProvenanceEntry,
} from '@/src/domain/providers';

export interface SyntheticProviderRequest {
  scenario: 'SUCCESS' | 'NO_HIT' | 'PARTIAL' | 'STALE' | 'ERROR';
  /**
   * Synthetic-only normalized fact overrides used by canonical scenario tests.
   * These never cross the agent/provider API boundary and are forbidden in live adapters.
   */
  factOverrides?: Record<string, string | number | boolean | null>;
}

export interface SyntheticProviderNormalized {
  capability: ProviderCapability;
  subjectIds: string[];
  facts: Record<string, string | number | boolean | null>;
}

const VERSION = 'synthetic-provider-v1';

export class SyntheticProviderAdapter
  implements ProviderAdapter<SyntheticProviderRequest, SyntheticProviderNormalized>
{
  public constructor(private readonly capability: ProviderCapability) {}

  public capabilities(): ProviderCapabilityDescriptor[] {
    return [
      {
        capability: this.capability,
        adapterId: `synthetic-${this.capability.toLowerCase()}`,
        adapterVersion: VERSION,
        jurisdictions: ['CA'],
        productLines: ['PRIVATE_PASSENGER_AUTO'],
        requiredSubjectFields: [],
        requiredNoticeCategories:
          this.capability === 'MVR' || this.capability === 'CLAIMS'
            ? ['CONSUMER_REPORT_DISCLOSURE', 'REPORT_AUTHORIZATION']
            : [],
        rawPayloadStoragePermitted: false,
        freshnessSeconds: 86400,
        contractualPurposeCodes: ['INSURANCE_UNDERWRITING'],
      },
    ];
  }

  public async validate(
    context: ProviderRequestContext,
    _request: SyntheticProviderRequest,
  ): Promise<void> {
    if (context.capability !== this.capability) {
      throw new Error('PROVIDER_CAPABILITY_MISMATCH');
    }
    if (context.jurisdiction !== 'CA') {
      throw new Error('PROVIDER_JURISDICTION_UNSUPPORTED');
    }
    if (context.productLine !== 'PRIVATE_PASSENGER_AUTO') {
      throw new Error('PROVIDER_PRODUCT_UNSUPPORTED');
    }
  }

  public async execute(
    context: ProviderRequestContext,
    request: SyntheticProviderRequest,
  ): Promise<ProviderResult<SyntheticProviderNormalized>> {
    await this.validate(context, request);

    const retrievedAt = new Date('2026-08-23T00:00:00.000Z').toISOString();
    const providerRequestId = `synthetic-request:${context.idempotencyKey}`;
    const providerReportId = `synthetic-report:${this.capability.toLowerCase()}:${request.scenario.toLowerCase()}`;

    if (request.scenario === 'ERROR') {
      return {
        status: 'ERROR',
        providerRequestId,
        retrievedAt,
        normalized: null,
        provenance: [],
        warnings: ['SYNTHETIC_PROVIDER_ERROR'],
      };
    }

    if (request.scenario === 'NO_HIT') {
      return {
        status: 'NO_HIT',
        providerRequestId,
        providerReportId,
        retrievedAt,
        normalized: null,
        provenance: [],
        warnings: [],
      };
    }

    const normalized: SyntheticProviderNormalized = {
      capability: this.capability,
      subjectIds: [...context.subjectIds],
      facts: {
        ...syntheticFacts(this.capability),
        ...(request.factOverrides ?? {}),
      },
    };

    const provenance: ProvenanceEntry[] = Object.keys(normalized.facts).map((key) => ({
      sourceType: 'PROVIDER',
      sourceId: providerReportId,
      sourceField: `facts.${key}`,
      normalizedFactKey: key,
      sourceTimestamp: retrievedAt,
      transformationVersion: VERSION,
      confidence: 1,
    }));

    return {
      status: request.scenario,
      providerRequestId,
      providerReportId,
      retrievedAt,
      normalized,
      provenance,
      warnings: request.scenario === 'PARTIAL' ? ['SYNTHETIC_PARTIAL_RESULT'] : [],
    };
  }
}

function syntheticFacts(
  capability: ProviderCapability,
): Record<string, string | number | boolean | null> {
  switch (capability) {
    case 'MVR':
      return { licenseStatus: 'VALID', movingViolationCount: 0 };
    case 'CLAIMS':
      return { claimCount: 0, latestLossDate: null };
    case 'VEHICLE':
      return { titleStatus: 'CLEAN', severeDamageIndicator: false };
    case 'PREFILL':
      return { matchedDriverCount: 1, matchedVehicleCount: 1 };
    case 'IDENTITY':
      return { identityMatch: true };
  }
}
