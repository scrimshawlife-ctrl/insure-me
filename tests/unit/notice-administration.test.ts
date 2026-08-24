import { describe, expect, it } from 'vitest';

import { approveNoticeDefinitionVersion, createNoticeDefinitionVersion,
  listNoticeDefinitionVersions, retireNoticeDefinitionVersion } from '@/src/application/notice/notice-administration';

const row = { notice_definition_id: 'notice-1', notice_key: 'privacy', version: 2,
  status: 'DRAFT' as const, category: 'INSURANCE_PRIVACY' as const, jurisdiction: 'CA' as const,
  product_line: 'PRIVATE_PASSENGER_AUTO' as const, title: 'Privacy', body_markdown: 'Body',
  content_hash: 'a'.repeat(64), required_for_quote: true, effective_at: null,
  retired_at: null, approved_at: null, approval_ref: null, created_at: '2026-08-24T00:00:00Z' };

describe('notice administration', () => {
  it('creates a server-versioned draft without caller hash or version', async () => {
    const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
    const client = { rpc: async (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args }); return { data: [row], error: null };
    } };
    const result = await createNoticeDefinitionVersion(client as never, {
      noticeKey: 'privacy', category: 'INSURANCE_PRIVACY', title: 'Privacy', bodyMarkdown: 'Body',
      requiredForQuote: true, evidenceRef: 'draft:legal', reasonCodes: ['NEW_VERSION'],
      idempotencyKey: 'key-1' });
    expect(result.version).toBe(2);
    expect(calls[0].args).not.toHaveProperty('p_version');
    expect(calls[0].args).not.toHaveProperty('p_content_hash');
  });

  it('routes approval and retirement through distinct evidence commands', async () => {
    const names: string[] = [];
    const client = { rpc: async (name: string) => { names.push(name); return { data: [row], error: null }; } };
    await approveNoticeDefinitionVersion(client as never, { noticeDefinitionId: 'notice-1',
      approvalRef: 'legal:approved', effectiveAt: '2026-08-25T00:00:00Z',
      reasonCodes: ['LEGAL_APPROVED'], idempotencyKey: 'key-2' });
    await retireNoticeDefinitionVersion(client as never, { noticeDefinitionId: 'notice-1',
      evidenceRef: 'legal:retired', reasonCodes: ['SUPERSEDED'], idempotencyKey: 'key-3' });
    expect(names).toEqual(['approve_notice_definition_version', 'retire_notice_definition_version']);
  });

  it('lists exact versions through the checked RPC', async () => {
    const client = { rpc: async (name: string, args: Record<string, unknown>) => {
      expect(name).toBe('list_notice_definition_versions'); expect(args).toEqual({});
      return { data: [row], error: null };
    } };
    expect(await listNoticeDefinitionVersions(client as never)).toHaveLength(1);
  });
});
