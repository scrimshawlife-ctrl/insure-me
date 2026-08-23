import type { SupabaseClient } from '@supabase/supabase-js';

import type { Database } from '@/src/infrastructure/supabase/database.types';

type ResumeGrantRow = {
  resume_grant_id: string;
  quote_case_id: string;
  expires_at: string;
};

type CreateResumeRpc = (
  functionName: 'create_consumer_resume_grant',
  args: { p_quote_case_id: string; p_ttl_minutes: number },
) => PromiseLike<{
  data: ResumeGrantRow | null;
  error: { message: string } | null;
}>;

type ConsumeResumeRpc = (
  functionName: 'consume_consumer_resume_grant',
  args: { p_resume_grant_id: string },
) => PromiseLike<{
  data: string | null;
  error: { message: string } | null;
}>;

export async function createConsumerResumeGrant(
  client: SupabaseClient<Database>,
  quoteCaseId: string,
  ttlMinutes = 60,
): Promise<{ resumeGrantId: string; expiresAt: string }> {
  const rpc = client.rpc as unknown as CreateResumeRpc;
  const { data, error } = await rpc('create_consumer_resume_grant', {
    p_quote_case_id: quoteCaseId,
    p_ttl_minutes: ttlMinutes,
  });

  if (error || !data) {
    throw new Error('RESUME_GRANT_CREATE_FAILED');
  }

  return {
    resumeGrantId: data.resume_grant_id,
    expiresAt: data.expires_at,
  };
}

export async function consumeConsumerResumeGrant(
  client: SupabaseClient<Database>,
  resumeGrantId: string,
): Promise<{ quoteCaseId: string }> {
  const rpc = client.rpc as unknown as ConsumeResumeRpc;
  const { data, error } = await rpc('consume_consumer_resume_grant', {
    p_resume_grant_id: resumeGrantId,
  });

  if (error || !data) {
    throw new Error('RESUME_GRANT_INVALID');
  }

  return { quoteCaseId: data };
}
