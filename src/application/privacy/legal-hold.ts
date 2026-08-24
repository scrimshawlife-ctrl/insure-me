import { createHash } from 'node:crypto';

import type { SupabaseClient } from '@supabase/supabase-js';

import type { LegalHold, LegalHoldScopeType } from '@/src/domain/privacy';
import type { Database } from '@/src/infrastructure/supabase/database.types';

type LegalHoldRow = {
  legal_hold_id: string;
  tenant_id: string;
  agency_id: string;
  scope_type: LegalHoldScopeType;
  scope_ref: string;
  status: 'ACTIVE' | 'RELEASED';
  authority_ref: string;
  evidence_ref: string;
  reason_codes: string[];
  placed_at: string;
  released_at: string | null;
};

type LegalHoldRpc = (
  functionName: 'place_legal_hold' | 'release_legal_hold',
  args: Record<string, unknown>,
) => PromiseLike<{ data: LegalHoldRow | null; error: { message: string } | null }>;

function commandHash(parts: unknown[]): string {
  return createHash('sha256').update(JSON.stringify(parts)).digest('hex');
}

function mapHold(row: LegalHoldRow): LegalHold {
  return {
    legalHoldId: row.legal_hold_id,
    tenantId: row.tenant_id,
    agencyId: row.agency_id,
    scopeType: row.scope_type,
    scopeRef: row.scope_ref,
    status: row.status,
    authorityRef: row.authority_ref,
    evidenceRef: row.evidence_ref,
    reasonCodes: row.reason_codes,
    placedAt: row.placed_at,
    ...(row.released_at ? { releasedAt: row.released_at } : {}),
  };
}

export async function placeLegalHold(
  client: SupabaseClient<Database>,
  command: {
    tenantId: string;
    agencyId: string;
    scopeType: LegalHoldScopeType;
    scopeRef: string;
    authorityRef: string;
    evidenceRef: string;
    reasonCodes: string[];
    idempotencyKey: string;
  },
): Promise<LegalHold> {
  const rpc = client.rpc as unknown as LegalHoldRpc;
  const requestHash = commandHash([
    'PLACE', command.tenantId, command.agencyId, command.scopeType,
    command.scopeRef, command.authorityRef, command.evidenceRef, command.reasonCodes,
  ]);
  const { data, error } = await rpc('place_legal_hold', {
    p_tenant_id: command.tenantId,
    p_agency_id: command.agencyId,
    p_scope_type: command.scopeType,
    p_scope_ref: command.scopeRef,
    p_authority_ref: command.authorityRef,
    p_evidence_ref: command.evidenceRef,
    p_reason_codes: command.reasonCodes,
    p_idempotency_key: command.idempotencyKey,
    p_request_hash: requestHash,
  });
  if (error || !data) throw new Error(error?.message ?? 'LEGAL_HOLD_PLACEMENT_FAILED');
  return mapHold(data);
}

export async function releaseLegalHold(
  client: SupabaseClient<Database>,
  command: {
    legalHoldId: string;
    authorityRef: string;
    evidenceRef: string;
    reasonCodes: string[];
    idempotencyKey: string;
  },
): Promise<LegalHold> {
  const rpc = client.rpc as unknown as LegalHoldRpc;
  const requestHash = commandHash([
    'RELEASE', command.legalHoldId, command.authorityRef,
    command.evidenceRef, command.reasonCodes,
  ]);
  const { data, error } = await rpc('release_legal_hold', {
    p_legal_hold_id: command.legalHoldId,
    p_authority_ref: command.authorityRef,
    p_evidence_ref: command.evidenceRef,
    p_reason_codes: command.reasonCodes,
    p_idempotency_key: command.idempotencyKey,
    p_request_hash: requestHash,
  });
  if (error || !data) throw new Error(error?.message ?? 'LEGAL_HOLD_RELEASE_FAILED');
  return mapHold(data);
}
