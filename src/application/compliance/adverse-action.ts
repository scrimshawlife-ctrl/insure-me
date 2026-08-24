import { createHash } from 'node:crypto';

import type { SupabaseClient } from '@supabase/supabase-js';

import type { AdverseActionCase, AdverseActionOwnerType } from '@/src/domain/privacy';
import type { Database } from '@/src/infrastructure/supabase/database.types';

type Row = {
  adverse_action_case_id: string;
  quote_case_id: string;
  carrier_decision_id: string;
  owner_type: AdverseActionOwnerType;
  owner_ref: string;
  ownership_policy_version: string;
  status: 'NOTICE_INPUTS_READY' | 'HANDED_OFF';
  determined_at: string;
  handed_off_at: string | null;
};
type Rpc = (
  name: 'create_adverse_action_case' | 'record_adverse_action_handoff',
  args: Record<string, unknown>,
) => PromiseLike<{ data: Row | null; error: { message: string } | null }>;

function hash(parts: unknown[]): string {
  return createHash('sha256').update(JSON.stringify(parts)).digest('hex');
}
function map(row: Row): AdverseActionCase {
  return {
    adverseActionCaseId: row.adverse_action_case_id,
    quoteCaseId: row.quote_case_id,
    carrierDecisionId: row.carrier_decision_id,
    ownerType: row.owner_type,
    ownerRef: row.owner_ref,
    ownershipPolicyVersion: row.ownership_policy_version,
    status: row.status,
    determinedAt: row.determined_at,
    ...(row.handed_off_at ? { handedOffAt: row.handed_off_at } : {}),
  };
}

export async function createAdverseActionCase(client: SupabaseClient<Database>, command: {
  quoteCaseId: string;
  carrierDecisionId: string;
  ownerType: AdverseActionOwnerType;
  ownerRef: string;
  determinationAuthorityRef: string;
  determinationEvidenceRef: string;
  reasonCodes: string[];
  reportSources: Array<{
    externalReportId: string;
    craIdentityRef: string;
    disputeRouteRef: string;
    contributionBasisCode: string;
  }>;
  idempotencyKey: string;
}): Promise<AdverseActionCase> {
  const rpc = client.rpc.bind(client) as unknown as Rpc;
  const requestHash = hash(['DETERMINE', command.quoteCaseId, command.carrierDecisionId,
    command.ownerType, command.ownerRef, command.determinationAuthorityRef,
    command.determinationEvidenceRef, command.reasonCodes, command.reportSources]);
  const { data, error } = await rpc('create_adverse_action_case', {
    p_quote_case_id: command.quoteCaseId,
    p_carrier_decision_id: command.carrierDecisionId,
    p_owner_type: command.ownerType,
    p_owner_ref: command.ownerRef,
    p_determination_authority_ref: command.determinationAuthorityRef,
    p_determination_evidence_ref: command.determinationEvidenceRef,
    p_reason_codes: command.reasonCodes,
    p_report_sources: command.reportSources,
    p_idempotency_key: command.idempotencyKey,
    p_request_hash: requestHash,
  });
  if (error || !data) throw new Error(error?.message ?? 'ADVERSE_ACTION_CREATE_FAILED');
  return map(data);
}

export async function recordAdverseActionHandoff(client: SupabaseClient<Database>, command: {
  adverseActionCaseId: string;
  recipientRef: string;
  evidenceRef: string;
  reasonCodes: string[];
  idempotencyKey: string;
}): Promise<AdverseActionCase> {
  const rpc = client.rpc.bind(client) as unknown as Rpc;
  const requestHash = hash(['HANDOFF', command.adverseActionCaseId, command.recipientRef,
    command.evidenceRef, command.reasonCodes]);
  const { data, error } = await rpc('record_adverse_action_handoff', {
    p_adverse_action_case_id: command.adverseActionCaseId,
    p_recipient_ref: command.recipientRef,
    p_evidence_ref: command.evidenceRef,
    p_reason_codes: command.reasonCodes,
    p_idempotency_key: command.idempotencyKey,
    p_request_hash: requestHash,
  });
  if (error || !data) throw new Error(error?.message ?? 'ADVERSE_ACTION_HANDOFF_FAILED');
  return map(data);
}
