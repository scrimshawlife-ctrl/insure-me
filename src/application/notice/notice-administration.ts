import type { SupabaseClient } from '@supabase/supabase-js';

import type { NoticeCategory, NoticeDefinitionVersion } from '@/src/domain/notice-administration';
import type { Database } from '@/src/infrastructure/supabase/database.types';

type NoticeRow = {
  notice_definition_id: string; notice_key: string; version: number;
  status: NoticeDefinitionVersion['status']; category: NoticeCategory;
  jurisdiction: 'CA'; product_line: 'PRIVATE_PASSENGER_AUTO'; title: string;
  body_markdown: string; content_hash: string; required_for_quote: boolean;
  effective_at: string | null; retired_at: string | null; approved_at: string | null;
  approval_ref: string | null; created_at: string;
};
type Rpc = (name: string, args: Record<string, unknown>) => PromiseLike<{
  data: NoticeRow[] | NoticeRow | null; error: { message: string } | null;
}>;

function map(row: NoticeRow): NoticeDefinitionVersion {
  return {
    noticeDefinitionId: row.notice_definition_id, noticeKey: row.notice_key,
    version: row.version, status: row.status, category: row.category,
    jurisdiction: row.jurisdiction, productLine: row.product_line, title: row.title,
    bodyMarkdown: row.body_markdown, contentHash: row.content_hash,
    requiredForQuote: row.required_for_quote, effectiveAt: row.effective_at,
    retiredAt: row.retired_at, approvedAt: row.approved_at,
    approvalRef: row.approval_ref, createdAt: row.created_at,
  };
}

async function one(client: SupabaseClient<Database>, name: string, args: Record<string, unknown>) {
  const { data, error } = await (client.rpc as unknown as Rpc)(name, args);
  const rows = Array.isArray(data) ? data : data ? [data] : [];
  if (error || rows.length !== 1) throw new Error(error?.message ?? 'NOTICE_ADMIN_COMMAND_FAILED');
  return map(rows[0]);
}

export function createNoticeDefinitionVersion(client: SupabaseClient<Database>, command: {
  agencyId: string; noticeKey: string; category: NoticeCategory; title: string;
  bodyMarkdown: string; requiredForQuote: boolean; evidenceRef: string;
  reasonCodes: string[]; idempotencyKey: string;
}) {
  return one(client, 'create_notice_definition_version', {
    p_agency_id: command.agencyId, p_notice_key: command.noticeKey,
    p_category: command.category, p_title: command.title, p_body_markdown: command.bodyMarkdown,
    p_required_for_quote: command.requiredForQuote, p_evidence_ref: command.evidenceRef,
    p_reason_codes: command.reasonCodes, p_idempotency_key: command.idempotencyKey,
  });
}

export function approveNoticeDefinitionVersion(client: SupabaseClient<Database>, command: {
  noticeDefinitionId: string; approvalRef: string; effectiveAt: string;
  reasonCodes: string[]; idempotencyKey: string;
}) {
  return one(client, 'approve_notice_definition_version', {
    p_notice_definition_id: command.noticeDefinitionId, p_approval_ref: command.approvalRef,
    p_effective_at: command.effectiveAt, p_reason_codes: command.reasonCodes,
    p_idempotency_key: command.idempotencyKey,
  });
}

export function retireNoticeDefinitionVersion(client: SupabaseClient<Database>, command: {
  noticeDefinitionId: string; evidenceRef: string; reasonCodes: string[]; idempotencyKey: string;
}) {
  return one(client, 'retire_notice_definition_version', {
    p_notice_definition_id: command.noticeDefinitionId, p_evidence_ref: command.evidenceRef,
    p_reason_codes: command.reasonCodes, p_idempotency_key: command.idempotencyKey,
  });
}

export async function listNoticeDefinitionVersions(client: SupabaseClient<Database>, agencyId: string) {
  const { data, error } = await (client.rpc as unknown as Rpc)('list_notice_definition_versions',
    { p_agency_id: agencyId });
  if (error || !Array.isArray(data)) throw new Error(error?.message ?? 'NOTICE_ADMIN_LIST_FAILED');
  return data.map(map);
}
