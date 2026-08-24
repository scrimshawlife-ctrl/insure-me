import { createHash } from 'node:crypto';

import type { SupabaseClient } from '@supabase/supabase-js';

import { requesterStatus, type RequesterPrivacyStatus } from '@/src/application/privacy/privacy-request';
import type {
  PrivacyDiscoveryOutcome,
  PrivacyIdentityState,
  PrivacyRequestState,
  PrivacyRequestType,
} from '@/src/domain/privacy';
import type { EnvironmentSource } from '@/src/infrastructure/config/deployment';
import { resolvePrivacyExportPolicy } from '@/src/infrastructure/privacy/privacy-export-policy';
import {
  privacyDiscoveryRequestHash,
  protectPrivacyExport,
  unprotectJsonPayload,
  unprotectSensitiveIdentifier,
} from '@/src/infrastructure/security/identity-protection';
import type { Database } from '@/src/infrastructure/supabase/database.types';

type JsonRecord = Record<string, unknown>;

type PreparedDiscoveryRow = {
  privacy_discovery_run_id: string;
  discovery_status: 'PREPARED' | 'COMPLETED';
  request_type: PrivacyRequestType;
  public_reference: string;
  state: PrivacyRequestState;
  identity_verification_state: PrivacyIdentityState;
  discovery_outcome: PrivacyDiscoveryOutcome;
  source_payload: JsonRecord | null;
  record_count: number;
};

type SettledDiscoveryRow = {
  public_reference: string;
  state: PrivacyRequestState;
  identity_verification_state: PrivacyIdentityState;
  discovery_outcome: PrivacyDiscoveryOutcome;
  export_available: boolean;
};

type ExportArtifactRow = {
  public_reference: string;
  export_ciphertext_hex: string;
  key_version: string;
  content_hash: string;
  record_count: number;
};

type PrivacyDiscoveryRpc = (
  functionName:
    | 'prepare_privacy_discovery'
    | 'settle_privacy_discovery'
    | 'get_privacy_export_artifact',
  args: Record<string, unknown>,
) => PromiseLike<{
  data: PreparedDiscoveryRow[] | SettledDiscoveryRow[] | ExportArtifactRow[] | null;
  error: { message: string } | null;
}>;

function record(value: unknown): JsonRecord {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('PRIVACY_EXPORT_SOURCE_INVALID');
  }
  return value as JsonRecord;
}

function records(value: unknown): JsonRecord[] {
  if (!Array.isArray(value)) throw new Error('PRIVACY_EXPORT_SOURCE_INVALID');
  return value.map(record);
}

function stringField(value: unknown): string {
  if (typeof value !== 'string') throw new Error('PRIVACY_EXPORT_SOURCE_INVALID');
  return value;
}

function discloseIdentifier(
  item: JsonRecord,
  ciphertextField: string,
  keyField: string,
  outputField: string,
): JsonRecord {
  const { [ciphertextField]: ciphertext, [keyField]: keyVersion, ...safe } = item;
  if (ciphertext === null || ciphertext === undefined) return safe;
  return {
    ...safe,
    [outputField]: unprotectSensitiveIdentifier(
      stringField(ciphertext),
      stringField(keyVersion),
    ),
  };
}

function buildRequesterExport(source: JsonRecord): JsonRecord {
  const protectedPerson = record(source.person);
  const {
    ciphertextHex,
    keyVersion,
    payloadVersion,
    createdAt,
    updatedAt,
  } = protectedPerson;
  const identity = unprotectJsonPayload<JsonRecord>(
    stringField(ciphertextHex),
    stringField(keyVersion),
  );

  return {
    metadata: record(source.metadata),
    person: {
      ...identity,
      payloadVersion,
      createdAt,
      updatedAt,
    },
    quoteCases: records(source.quoteCases),
    drivers: records(source.drivers).map((item) => discloseIdentifier(
      item,
      'licenseCiphertextHex',
      'licenseKeyVersion',
      'licenseNumber',
    )),
    vehicles: records(source.vehicles).map((item) => discloseIdentifier(
      item,
      'vinCiphertextHex',
      'vinKeyVersion',
      'vin',
    )),
    coverageRequests: records(source.coverageRequests),
    consents: records(source.consents),
    externalReports: records(source.externalReports),
    underwritingObservations: records(source.underwritingObservations),
    carrierDecisions: records(source.carrierDecisions),
  };
}

export type PrivacyDiscoveryStatus = RequesterPrivacyStatus & {
  discoveryOutcome: PrivacyDiscoveryOutcome;
  exportAvailable: boolean;
};

export async function discoverPrivacyRequestData(
  adminClient: SupabaseClient<Database>,
  command: {
    hostname: string;
    privacyRequestId: string;
    statusToken: string;
    idempotencyKey: string;
  },
  environment: EnvironmentSource = process.env,
): Promise<PrivacyDiscoveryStatus> {
  const policy = resolvePrivacyExportPolicy(environment);
  const statusTokenHash = createHash('sha256').update(command.statusToken).digest('hex');
  const requestHash = privacyDiscoveryRequestHash({
    privacyRequestId: command.privacyRequestId,
    idempotencyKey: command.idempotencyKey,
    policyVersion: policy.policyVersion,
    exportSchemaVersion: policy.exportSchemaVersion,
  });
  const rpc = adminClient.rpc as unknown as PrivacyDiscoveryRpc;
  const preparedResult = await rpc('prepare_privacy_discovery', {
    p_hostname: command.hostname,
    p_public_reference: command.privacyRequestId,
    p_status_token_hash: statusTokenHash,
    p_idempotency_key: command.idempotencyKey,
    p_request_hash: requestHash,
    p_disclosure_policy_version: policy.policyVersion,
    p_export_schema_version: policy.exportSchemaVersion,
  });
  const prepared = preparedResult.data?.[0] as PreparedDiscoveryRow | undefined;
  if (preparedResult.error || !prepared || preparedResult.data?.length !== 1) {
    throw new Error('PRIVACY_DISCOVERY_FAILED');
  }

  if (prepared.discovery_status === 'COMPLETED') {
    return {
      ...requesterStatus(prepared),
      discoveryOutcome: prepared.discovery_outcome,
      exportAvailable:
        prepared.request_type === 'ACCESS' && prepared.discovery_outcome === 'MATCHED',
    };
  }

  const requiresExport =
    prepared.request_type === 'ACCESS' && prepared.discovery_outcome === 'MATCHED';
  const protectedExport = requiresExport
    ? protectPrivacyExport(
        buildRequesterExport(record(prepared.source_payload)),
        prepared.record_count,
      )
    : null;
  const settledResult = await rpc('settle_privacy_discovery', {
    p_privacy_discovery_run_id: prepared.privacy_discovery_run_id,
    p_export_ciphertext: protectedExport?.pgBytea ?? null,
    p_key_version: protectedExport?.keyVersion ?? null,
    p_content_hash: protectedExport?.contentHash ?? null,
    p_record_count: protectedExport?.recordCount ?? null,
  });
  const settled = settledResult.data?.[0] as SettledDiscoveryRow | undefined;
  if (settledResult.error || !settled || settledResult.data?.length !== 1) {
    throw new Error('PRIVACY_DISCOVERY_FAILED');
  }
  return {
    ...requesterStatus(settled),
    discoveryOutcome: settled.discovery_outcome,
    exportAvailable: settled.export_available,
  };
}

export async function downloadPrivacyExport(
  adminClient: SupabaseClient<Database>,
  input: { hostname: string; privacyRequestId: string; statusToken: string },
): Promise<JsonRecord> {
  const rpc = adminClient.rpc as unknown as PrivacyDiscoveryRpc;
  const result = await rpc('get_privacy_export_artifact', {
    p_hostname: input.hostname,
    p_public_reference: input.privacyRequestId,
    p_status_token_hash: createHash('sha256').update(input.statusToken).digest('hex'),
  });
  const artifact = result.data?.[0] as ExportArtifactRow | undefined;
  if (result.error || !artifact || result.data?.length !== 1) {
    throw new Error('PRIVACY_EXPORT_NOT_FOUND');
  }
  const payload = unprotectJsonPayload<JsonRecord>(
    artifact.export_ciphertext_hex,
    artifact.key_version,
  );
  const actualHash = createHash('sha256').update(JSON.stringify(payload)).digest('hex');
  if (actualHash !== artifact.content_hash) {
    throw new Error('PRIVACY_EXPORT_INTEGRITY_INVALID');
  }
  return payload;
}
