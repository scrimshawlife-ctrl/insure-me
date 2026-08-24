import { describe, expect, it } from 'vitest';

import { listDataUsePolicyRules, listRetentionPolicies } from '@/src/application/policy/policy-inspection';

describe('policy inspection', () => {
  it('maps exact data-use policy versions from the checked RPC', async () => {
    const client = { rpc: async (name: string, args: Record<string, never>) => {
      expect(name).toBe('list_data_use_policy_rules');
      expect(args).toEqual({});
      return { data: [{ data_use_policy_rule_id: 'rule-1', policy_version: 'v1',
        observation_type: 'DRIVER_LICENSE_STATUS', collection_allowed: true,
        agent_display_allowed: true, underwriting_allowed: false,
        rating_submission_allowed: false, carrier_only: false, prohibited: false,
        effective_at: '2026-08-24T00:00:00Z', retired_at: null,
        created_at: '2026-08-24T00:00:00Z' }], error: null };
    } };
    const result = await listDataUsePolicyRules(client as never);
    expect(result[0]).toMatchObject({ policyVersion: 'v1', collectionAllowed: true });
  });

  it('maps retention authority and lifecycle without deriving durations', async () => {
    const client = { rpc: async () => ({ data: [{ retention_policy_id: 'retention-1',
      policy_set_id: 'set-v1', version: 1, data_class: 'QUOTE_CASE', jurisdiction: 'CA',
      provider_contract_ref: null, carrier_program_ref: null, tenant_role: 'CONTROLLER',
      retention_interval: '7 years', disposition: 'REVIEW',
      legal_hold_blocks_destructive_disposition: true, certification_state: 'APPROVED',
      legal_authority_refs: ['legal:approved'], contract_authority_refs: [],
      effective_at: '2026-08-24T00:00:00Z', retired_at: null,
      created_at: '2026-08-24T00:00:00Z' }], error: null }) };
    const result = await listRetentionPolicies(client as never);
    expect(result[0]).toMatchObject({ retentionInterval: '7 years',
      certificationState: 'APPROVED', legalAuthorityRefs: ['legal:approved'] });
  });
});
