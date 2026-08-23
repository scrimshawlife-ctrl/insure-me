import type { SupabaseClient } from '@supabase/supabase-js';

import {
  assertConsumerQuoteContext,
  type ConsumerQuoteContext,
} from '@/src/domain/auth/consumer';
import type { Database } from '@/src/infrastructure/supabase/database.types';

type ConsumerContextRow = {
  quote_case_id: string;
  tenant_id: string;
  agency_id: string;
  access_expires_at: string;
};

type ConsumerContextRpc = (
  functionName: 'get_consumer_quote_context',
  args: { p_quote_case_id: string },
) => PromiseLike<{
  data: ConsumerContextRow[] | null;
  error: { message: string } | null;
}>;

export async function requireConsumerQuoteContext(
  client: SupabaseClient<Database>,
  quoteCaseId: string,
): Promise<ConsumerQuoteContext> {
  const { data: claimsData, error: claimsError } = await client.auth.getClaims();
  const claims = claimsData?.claims as { sub?: string } | undefined;

  if (claimsError || !claims?.sub) {
    throw new Error('CONSUMER_AUTHENTICATION_REQUIRED');
  }

  const rpc = client.rpc as unknown as ConsumerContextRpc;
  const { data, error } = await rpc('get_consumer_quote_context', {
    p_quote_case_id: quoteCaseId,
  });

  if (error) {
    throw new Error('CONSUMER_QUOTE_CONTEXT_UNAVAILABLE');
  }
  if (!data || data.length !== 1) {
    throw new Error('CONSUMER_QUOTE_ACCESS_DENIED');
  }

  const row = data[0];
  const context: ConsumerQuoteContext = {
    userId: claims.sub,
    quoteCaseId: row.quote_case_id,
    tenantId: row.tenant_id,
    agencyId: row.agency_id,
    accessExpiresAt: row.access_expires_at,
  };

  assertConsumerQuoteContext(context, quoteCaseId);
  return context;
}
