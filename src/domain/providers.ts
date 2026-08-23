export type ProviderCapability =
  | 'IDENTITY'
  | 'PREFILL'
  | 'MVR'
  | 'CLAIMS'
  | 'VEHICLE';

export type ProviderResultStatus =
  | 'SUCCESS'
  | 'NO_HIT'
  | 'PARTIAL'
  | 'STALE'
  | 'ERROR';

export interface ProviderCapabilityDescriptor {
  capability: ProviderCapability;
  adapterId: string;
  adapterVersion: string;
  jurisdictions: string[];
  productLines: string[];
  requiredSubjectFields: string[];
  requiredNoticeCategories: string[];
  rawPayloadStoragePermitted: boolean;
  freshnessSeconds: number | null;
  contractualPurposeCodes: string[];
}

export interface ProviderRequestContext {
  quoteCaseId: string;
  tenantId: string;
  agencyId: string;
  actorId: string;
  tenantConfigurationVersion: string;
  jurisdiction: 'CA';
  productLine: 'PRIVATE_PASSENGER_AUTO';
  capability: ProviderCapability;
  providerBindingId: string;
  permissiblePurposeDecisionId: string;
  consentRecordIds: string[];
  subjectIds: string[];
  traceId: string;
  idempotencyKey: string;
}

export interface ProvenanceEntry {
  sourceType: 'PROVIDER' | 'CONSUMER' | 'AGENT' | 'SYSTEM';
  sourceId: string;
  sourceField?: string;
  normalizedFactKey: string;
  sourceTimestamp: string;
  transformationVersion: string;
  confidence?: number;
}

export interface ProviderResult<T> {
  status: ProviderResultStatus;
  providerRequestId?: string;
  providerReportId?: string;
  retrievedAt: string;
  normalized: T | null;
  provenance: ProvenanceEntry[];
  warnings: string[];
}

export interface ProviderAdapter<TRequest, TNormalized> {
  capabilities(): ProviderCapabilityDescriptor[];
  validate(context: ProviderRequestContext, request: TRequest): Promise<void>;
  execute(
    context: ProviderRequestContext,
    request: TRequest,
  ): Promise<ProviderResult<TNormalized>>;
}
