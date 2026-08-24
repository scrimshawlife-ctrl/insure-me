import { describe, expect, it } from 'vitest';

import { placeLegalHold, releaseLegalHold } from '@/src/application/privacy/legal-hold';

const row = {
  legal_hold_id: 'hold-1', tenant_id: 'tenant-1', agency_id: 'agency-1',
  scope_type: 'PERSON' as const, scope_ref: 'person-1', status: 'ACTIVE' as const,
  authority_ref: 'authority:synthetic', evidence_ref: 'evidence:synthetic',
  reason_codes: ['PRESERVATION_REQUIRED'], placed_at: '2026-08-24T00:00:00Z', released_at: null,
};

describe('legal hold administration', () => {
  it('binds placement to tenant scope and a deterministic request hash', async () => {
    const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
    const client = { rpc: async (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args }); return { data: row, error: null };
    } };
    const command = {
      tenantId: 'tenant-1', agencyId: 'agency-1', scopeType: 'PERSON' as const,
      scopeRef: 'person-1', authorityRef: 'authority:synthetic',
      evidenceRef: 'evidence:synthetic', reasonCodes: ['PRESERVATION_REQUIRED'],
      idempotencyKey: 'key-1',
    };
    const result = await placeLegalHold(client as never, command);
    await placeLegalHold(client as never, command);
    expect(result.status).toBe('ACTIVE');
    expect(calls[0].name).toBe('place_legal_hold');
    expect(calls[0].args.p_request_hash).toMatch(/^[0-9a-f]{64}$/);
    expect(calls[1].args.p_request_hash).toBe(calls[0].args.p_request_hash);
  });

  it('requires explicit release authority and leaves resumption to database reevaluation', async () => {
    const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
    const client = { rpc: async (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args });
      return { data: { ...row, status: 'RELEASED', released_at: '2026-08-24T01:00:00Z' }, error: null };
    } };
    const result = await releaseLegalHold(client as never, {
      legalHoldId: 'hold-1', authorityRef: 'release-authority:synthetic',
      evidenceRef: 'release-evidence:synthetic', reasonCodes: ['MATTER_CLOSED'],
      idempotencyKey: 'key-2',
    });
    expect(result.status).toBe('RELEASED');
    expect(calls[0].name).toBe('release_legal_hold');
    expect(calls[0].args).not.toHaveProperty('p_resume_disposition');
  });
});
