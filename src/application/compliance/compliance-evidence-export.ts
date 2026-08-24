import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  ComplianceEvidenceExportArtifact,
  ComplianceEvidenceExportSummary,
} from '@/src/domain/compliance';
import type { Database } from '@/src/infrastructure/supabase/database.types';

type SummaryRow = {
  compliance_evidence_export_id: string;
  quote_case_id: string;
  schema_version: 'compliance-evidence-bundle-v1';
  as_of: string;
  manifest_hash: string;
  evidence_record_count: number;
  created_at: string;
};
type ArtifactRow = SummaryRow & { manifest: Record<string, unknown> };
type Rpc = (
  name: 'create_compliance_evidence_export' | 'get_compliance_evidence_export',
  args: Record<string, unknown>,
) => PromiseLike<{
  data: SummaryRow[] | ArtifactRow[] | null;
  error: { message: string } | null;
}>;

function map(row: SummaryRow): ComplianceEvidenceExportSummary {
  return {
    complianceEvidenceExportId: row.compliance_evidence_export_id,
    quoteCaseId: row.quote_case_id,
    schemaVersion: row.schema_version,
    asOf: row.as_of,
    manifestHash: row.manifest_hash,
    evidenceRecordCount: row.evidence_record_count,
    createdAt: row.created_at,
  };
}

export async function createComplianceEvidenceExport(
  client: SupabaseClient<Database>,
  command: {
    quoteCaseId: string;
    asOf: string;
    purposeRef: string;
    reasonCodes: string[];
    idempotencyKey: string;
  },
): Promise<ComplianceEvidenceExportSummary> {
  const { data, error } = await (client.rpc as unknown as Rpc)(
    'create_compliance_evidence_export',
    {
      p_quote_case_id: command.quoteCaseId,
      p_as_of: command.asOf,
      p_purpose_ref: command.purposeRef,
      p_reason_codes: command.reasonCodes,
      p_idempotency_key: command.idempotencyKey,
    },
  );
  const row = data?.[0];
  if (error || !row || data?.length !== 1) {
    throw new Error(error?.message ?? 'COMPLIANCE_EXPORT_CREATE_FAILED');
  }
  return map(row);
}

export async function getComplianceEvidenceExport(
  client: SupabaseClient<Database>,
  complianceEvidenceExportId: string,
): Promise<ComplianceEvidenceExportArtifact> {
  const { data, error } = await (client.rpc as unknown as Rpc)(
    'get_compliance_evidence_export',
    { p_compliance_evidence_export_id: complianceEvidenceExportId },
  );
  const row = data?.[0] as ArtifactRow | undefined;
  if (error || !row || data?.length !== 1) {
    throw new Error(error?.message ?? 'COMPLIANCE_EXPORT_NOT_FOUND');
  }
  return { ...map(row), manifest: row.manifest };
}
