import type { SupabaseClient } from '@supabase/supabase-js';

import type { Database } from '@/src/infrastructure/supabase/database.types';
import {
  protectConsumerIdentity,
  type ConsumerIdentityPayload,
} from '@/src/infrastructure/security/identity-protection';

type IdentityRpc = (
  functionName: 'upsert_consumer_identity',
  args: {
    p_quote_case_id: string;
    p_encrypted_payload: string;
    p_key_version: string;
    p_email_lookup_hash: string;
    p_phone_lookup_hash: string | null;
  },
) => PromiseLike<{
  data: string | null;
  error: { message: string } | null;
}>;

export async function updateConsumerIdentity(
  client: SupabaseClient<Database>,
  quoteCaseId: string,
  payload: ConsumerIdentityPayload,
): Promise<{ personId: string }> {
  const protectedPayload = protectConsumerIdentity(payload);
  const rpc = client.rpc as unknown as IdentityRpc;
  const { data, error } = await rpc('upsert_consumer_identity', {
    p_quote_case_id: quoteCaseId,
    p_encrypted_payload: protectedPayload.pgBytea,
    p_key_version: protectedPayload.keyVersion,
    p_email_lookup_hash: protectedPayload.emailLookupHash,
    p_phone_lookup_hash: protectedPayload.phoneLookupHash,
  });

  if (error || !data) {
    throw new Error('CONSUMER_IDENTITY_UPDATE_FAILED');
  }

  return { personId: data };
}
