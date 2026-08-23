import type { SupabaseClient } from '@supabase/supabase-js';

import type { NoticeCategory } from '@/src/domain/notice/consent';
import type { Database } from '@/src/infrastructure/supabase/database.types';

export interface RequiredNoticeView {
  noticeDefinitionId: string;
  noticeKey: string;
  version: number;
  category: NoticeCategory;
  title: string;
  bodyMarkdown: string;
  contentHash: string;
  requiredForQuote: boolean;
}

type RequiredNoticeRow = {
  notice_definition_id: string;
  notice_key: string;
  version: number;
  category: NoticeCategory;
  title: string;
  body_markdown: string;
  content_hash: string;
  required_for_quote: boolean;
};

type RequiredNoticesRpc = (
  functionName: 'get_required_notices_for_quote',
  args: { p_quote_case_id: string },
) => PromiseLike<{
  data: RequiredNoticeRow[] | null;
  error: { message: string } | null;
}>;

export async function getRequiredNotices(
  client: SupabaseClient<Database>,
  quoteCaseId: string,
): Promise<RequiredNoticeView[]> {
  const rpc = client.rpc as unknown as RequiredNoticesRpc;
  const { data, error } = await rpc('get_required_notices_for_quote', {
    p_quote_case_id: quoteCaseId,
  });

  if (error) {
    throw new Error(`REQUIRED_NOTICES_FAILED:${error.message}`);
  }

  return (data ?? []).map((row) => ({
    noticeDefinitionId: row.notice_definition_id,
    noticeKey: row.notice_key,
    version: row.version,
    category: row.category,
    title: row.title,
    bodyMarkdown: row.body_markdown,
    contentHash: row.content_hash,
    requiredForQuote: row.required_for_quote,
  }));
}
