import type { SupabaseClient } from '@supabase/supabase-js';

import type { Database } from '@/src/infrastructure/supabase/database.types';

export interface CreateConsumerQuoteCaseCommand {
  hostname: string;
  consumerIdentityId: string;
  jurisdiction: 'CA';
  productLine: 'PRIVATE_PASSENGER_AUTO';
  sourceChannel: 'WEB';
}

export interface CreatedConsumerQuoteCase {
  quoteCaseId: string;
  state: 'DRAFT';
  nextAction: 'IDENTITY';
  accessExpiresAt: string;
}

type CreateQuoteRow = {
  quote_case_id: string;
  state: 'DRAFT';
  next_action: 'IDENTITY';
  access_expires_at: string;
};

type CreateQuoteRpc = (
  functionName: 'create_consumer_quote_case',
  args: {
    p_hostname: string;
    p_consumer_identity_id: string;
    p_jurisdiction: 'CA';
    p_product_line: 'PRIVATE_PASSENGER_AUTO';
    p_source_channel: 'WEB';
  },
) => PromiseLike<{
  data: CreateQuoteRow[] | null;
  error: { message: string } | null;
}>;

export async function createConsumerQuoteCase(
  adminClient: SupabaseClient<Database>,
  command: CreateConsumerQuoteCaseCommand,
): Promise<CreatedConsumerQuoteCase> {
  const rpc = adminClient.rpc as unknown as CreateQuoteRpc;
  const { data, error } = await rpc('create_consumer_quote_case', {
    p_hostname: command.hostname,
    p_consumer_identity_id: command.consumerIdentityId,
    p_jurisdiction: command.jurisdiction,
    p_product_line: command.productLine,
    p_source_channel: command.sourceChannel,
  });

  if (error) {
    throw new Error(`QUOTE_CASE_CREATE_FAILED:${error.message}`);
  }
  if (!data || data.length !== 1) {
    throw new Error('QUOTE_CASE_CREATE_INVALID_RESULT');
  }

  return {
    quoteCaseId: data[0].quote_case_id,
    state: data[0].state,
    nextAction: data[0].next_action,
    accessExpiresAt: data[0].access_expires_at,
  };
}
