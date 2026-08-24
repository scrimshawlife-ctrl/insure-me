import { describe, expect, it } from 'vitest';

import { createAdverseActionCase, recordAdverseActionHandoff } from '@/src/application/compliance/adverse-action';

const row = { adverse_action_case_id: 'aa-1', quote_case_id: 'case-1',
  carrier_decision_id: 'decision-1', owner_type: 'CARRIER' as const,
  owner_ref: 'carrier-owner:synthetic', ownership_policy_version: 'ownership-v1',
  status: 'NOTICE_INPUTS_READY' as const, determined_at: '2026-08-24T00:00:00Z',
  handed_off_at: null };

describe('adverse-action support', () => {
  it('records a responsible-party determination with exact report provenance', async () => {
    const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
    const client = { rpc: async (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args }); return { data: row, error: null };
    } };
    const result = await createAdverseActionCase(client as never, {
      quoteCaseId: 'case-1', carrierDecisionId: 'decision-1', ownerType: 'CARRIER',
      ownerRef: 'carrier-owner:synthetic', determinationAuthorityRef: 'authority:synthetic',
      determinationEvidenceRef: 'evidence:synthetic', reasonCodes: ['RESPONSIBLE_PARTY_DETERMINED'],
      reportSources: [{ externalReportId: 'report-1', craIdentityRef: 'cra:synthetic',
        disputeRouteRef: 'dispute:synthetic', contributionBasisCode: 'CONTRIBUTED_PARTLY' }],
      idempotencyKey: 'key-1',
    });
    expect(result.status).toBe('NOTICE_INPUTS_READY');
    expect(calls[0].name).toBe('create_adverse_action_case');
    expect(calls[0].args.p_request_hash).toMatch(/^[0-9a-f]{64}$/);
    expect(calls[0].args.p_report_sources).toEqual(expect.arrayContaining([
      expect.objectContaining({ externalReportId: 'report-1' }),
    ]));
  });

  it('records handoff without claiming notice delivery', async () => {
    const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
    const client = { rpc: async (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args }); return { data: { ...row, status: 'HANDED_OFF', handed_off_at: '2026-08-24T01:00:00Z' }, error: null };
    } };
    const result = await recordAdverseActionHandoff(client as never, {
      adverseActionCaseId: 'aa-1', recipientRef: 'carrier-desk:synthetic',
      evidenceRef: 'handoff:synthetic', reasonCodes: ['OWNER_ACKNOWLEDGED'], idempotencyKey: 'key-2',
    });
    expect(result.status).toBe('HANDED_OFF');
    expect(calls[0].args).not.toHaveProperty('p_delivered_at');
  });
});
