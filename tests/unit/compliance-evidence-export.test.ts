import { describe, expect, it } from 'vitest';

import {
  createComplianceEvidenceExport,
  getComplianceEvidenceExport,
} from '@/src/application/compliance/compliance-evidence-export';

const summary = {
  compliance_evidence_export_id: 'export-1',
  quote_case_id: 'case-1',
  schema_version: 'compliance-evidence-bundle-v1' as const,
  as_of: '2026-08-24T04:00:00Z',
  manifest_hash: 'a'.repeat(64),
  evidence_record_count: 12,
  created_at: '2026-08-24T04:01:00Z',
};

describe('compliance evidence export', () => {
  it('creates an idempotent bounded export without returning its manifest', async () => {
    const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
    const client = { rpc: async (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args }); return { data: [summary], error: null };
    } };
    const result = await createComplianceEvidenceExport(client as never, {
      quoteCaseId: 'case-1', asOf: '2026-08-24T04:00:00Z',
      purposeRef: 'audit:synthetic', reasonCodes: ['SYNTHETIC_REHEARSAL'],
      idempotencyKey: 'idempotency-1',
    });
    expect(result.manifestHash).toBe('a'.repeat(64));
    expect(result).not.toHaveProperty('manifest');
    expect(calls[0].name).toBe('create_compliance_evidence_export');
    expect(calls[0].args.p_request_hash).toMatch(/^[0-9a-f]{64}$/);
  });

  it('retrieves the immutable manifest only through the audited RPC', async () => {
    const manifest = { schemaVersion: 'compliance-evidence-bundle-v1', auditTimeline: [] };
    const client = { rpc: async (name: string, args: Record<string, unknown>) => {
      expect(name).toBe('get_compliance_evidence_export');
      expect(args).toEqual({ p_compliance_evidence_export_id: 'export-1' });
      return { data: [{ ...summary, manifest }], error: null };
    } };
    const result = await getComplianceEvidenceExport(client as never, 'export-1');
    expect(result.manifest).toEqual(manifest);
  });
});
