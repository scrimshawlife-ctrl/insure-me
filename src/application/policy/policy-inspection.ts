import type { SupabaseClient } from '@supabase/supabase-js';

import type { DataUsePolicyRule, RetentionPolicyVersion } from '@/src/domain/policy-inspection';
import type { Database } from '@/src/infrastructure/supabase/database.types';

type RpcResult = PromiseLike<{ data: unknown[] | null; error: { message: string } | null }>;
type Rpc = (name: string, args: Record<string, never>) => RpcResult;

async function list(client: SupabaseClient<Database>, name: string): Promise<Record<string, unknown>[]> {
  const { data, error } = await (client.rpc as unknown as Rpc)(name, {});
  if (error || !Array.isArray(data)) throw new Error(error?.message ?? 'POLICY_INSPECTION_FAILED');
  return data as Record<string, unknown>[];
}

export async function listDataUsePolicyRules(client: SupabaseClient<Database>): Promise<DataUsePolicyRule[]> {
  return (await list(client, 'list_data_use_policy_rules')).map((row) => ({
    dataUsePolicyRuleId: row.data_use_policy_rule_id as string,
    policyVersion: row.policy_version as string,
    observationType: row.observation_type as string,
    collectionAllowed: row.collection_allowed as boolean,
    agentDisplayAllowed: row.agent_display_allowed as boolean,
    underwritingAllowed: row.underwriting_allowed as boolean,
    ratingSubmissionAllowed: row.rating_submission_allowed as boolean,
    carrierOnly: row.carrier_only as boolean,
    prohibited: row.prohibited as boolean,
    effectiveAt: row.effective_at as string,
    retiredAt: row.retired_at as string | null,
    createdAt: row.created_at as string,
  }));
}

export async function listRetentionPolicies(client: SupabaseClient<Database>): Promise<RetentionPolicyVersion[]> {
  return (await list(client, 'list_retention_policies')).map((row) => ({
    retentionPolicyId: row.retention_policy_id as string,
    policySetId: row.policy_set_id as string,
    version: row.version as number,
    dataClass: row.data_class as string,
    jurisdiction: row.jurisdiction as 'CA',
    providerContractRef: row.provider_contract_ref as string | null,
    carrierProgramRef: row.carrier_program_ref as string | null,
    tenantRole: row.tenant_role as string,
    retentionInterval: row.retention_interval as string | null,
    disposition: row.disposition as RetentionPolicyVersion['disposition'],
    legalHoldBlocksDestructiveDisposition: row.legal_hold_blocks_destructive_disposition as boolean,
    certificationState: row.certification_state as RetentionPolicyVersion['certificationState'],
    legalAuthorityRefs: row.legal_authority_refs as string[],
    contractAuthorityRefs: row.contract_authority_refs as string[],
    effectiveAt: row.effective_at as string | null,
    retiredAt: row.retired_at as string | null,
    createdAt: row.created_at as string,
  }));
}
