import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  PrivacyIdentityState,
  PrivacyRequestState,
  PrivacyRequestType,
} from '@/src/domain/privacy';
import type { Database } from '@/src/infrastructure/supabase/database.types';
import {
  protectPrivacyRequester,
  type PrivacyRequesterPayload,
} from '@/src/infrastructure/security/identity-protection';

type PrivacyStatusRow = {
  public_reference: string;
  state: PrivacyRequestState;
  identity_verification_state: PrivacyIdentityState;
};

type PrivacyRpc = (
  functionName: 'create_privacy_request' | 'get_privacy_request_status',
  args: Record<string, unknown>,
) => PromiseLike<{
  data: PrivacyStatusRow[] | null;
  error: { message: string } | null;
}>;

export interface CreatePrivacyRequestCommand {
  hostname: string;
  requestType: PrivacyRequestType;
  jurisdiction: 'CA';
  intakeChannel: 'WEB';
  requester: PrivacyRequesterPayload;
  idempotencyKey: string;
}

export interface RequesterPrivacyStatus {
  privacyRequestId: string;
  state: PrivacyRequestState;
  identityVerificationState: PrivacyIdentityState;
  nextAction: 'IDENTITY_VERIFICATION' | 'CONTACT_SUPPORT' | 'PROCESSING' | 'COMPLETE';
}

function nextAction(
  state: PrivacyRequestState,
  identityState: PrivacyIdentityState,
): RequesterPrivacyStatus['nextAction'] {
  if (state === 'COMPLETED' || state === 'DENIED' || state === 'CANCELLED') {
    return 'COMPLETE';
  }
  if (identityState === 'FAILED' || identityState === 'EXPIRED') {
    return 'CONTACT_SUPPORT';
  }
  if (state === 'RECEIVED' || state === 'IDENTITY_VERIFICATION_PENDING') {
    return 'IDENTITY_VERIFICATION';
  }
  return 'PROCESSING';
}

function requesterStatus(row: PrivacyStatusRow): RequesterPrivacyStatus {
  return {
    privacyRequestId: row.public_reference,
    state: row.state,
    identityVerificationState: row.identity_verification_state,
    nextAction: nextAction(row.state, row.identity_verification_state),
  };
}

export { requesterStatus };

export async function createPrivacyRequest(
  adminClient: SupabaseClient<Database>,
  command: CreatePrivacyRequestCommand,
): Promise<RequesterPrivacyStatus & { statusToken: string }> {
  const protectedRequester = protectPrivacyRequester(
    command.requester,
    command.idempotencyKey,
    { requestType: command.requestType, jurisdiction: command.jurisdiction },
  );
  const rpc = adminClient.rpc.bind(adminClient) as unknown as PrivacyRpc;
  const { data, error } = await rpc('create_privacy_request', {
    p_hostname: command.hostname,
    p_request_type: command.requestType,
    p_jurisdiction: command.jurisdiction,
    p_intake_channel: command.intakeChannel,
    p_encrypted_requester_payload: protectedRequester.pgBytea,
    p_key_version: protectedRequester.keyVersion,
    p_email_lookup_hash: protectedRequester.emailLookupHash,
    p_phone_lookup_hash: protectedRequester.phoneLookupHash,
    p_request_hash: protectedRequester.requestHash,
    p_status_token_hash: protectedRequester.statusTokenHash,
    p_idempotency_key: command.idempotencyKey,
  });

  if (error || !data || data.length !== 1) {
    const databaseCode = error && 'code' in error && typeof error.code === 'string'
      ? error.code.replace(/[^A-Z0-9_]/gi, '_').slice(0, 24)
      : 'UNKNOWN';
    throw new Error(`PRIVACY_REQUEST_CREATE_FAILED_${databaseCode}`);
  }

  return {
    ...requesterStatus(data[0]),
    statusToken: protectedRequester.statusToken,
  };
}

export async function getPrivacyRequestStatus(
  adminClient: SupabaseClient<Database>,
  input: { hostname: string; privacyRequestId: string; statusTokenHash: string },
): Promise<RequesterPrivacyStatus> {
  const rpc = adminClient.rpc.bind(adminClient) as unknown as PrivacyRpc;
  const { data, error } = await rpc('get_privacy_request_status', {
    p_hostname: input.hostname,
    p_public_reference: input.privacyRequestId,
    p_status_token_hash: input.statusTokenHash,
  });

  if (error || !data || data.length !== 1) {
    throw new Error('PRIVACY_REQUEST_NOT_FOUND');
  }

  return requesterStatus(data[0]);
}
