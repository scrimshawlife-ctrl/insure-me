import { createHash } from 'node:crypto';

import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  PrivacyIdentityState,
  PrivacyIdentityVerificationOutcome,
  PrivacyRequestState,
} from '@/src/domain/privacy';
import { requesterStatus, type RequesterPrivacyStatus } from '@/src/application/privacy/privacy-request';
import type { EnvironmentSource } from '@/src/infrastructure/config/deployment';
import { resolvePrivacyIdentityVerifier } from '@/src/infrastructure/privacy/privacy-identity-verifier';
import { privacyVerificationAttemptHash } from '@/src/infrastructure/security/identity-protection';
import type { Database } from '@/src/infrastructure/supabase/database.types';

type VerificationRow = {
  public_reference: string;
  state: PrivacyRequestState;
  identity_verification_state: PrivacyIdentityState;
  verification_outcome: PrivacyIdentityVerificationOutcome;
};

type VerificationRpc = (
  functionName: 'settle_privacy_identity_verification',
  args: Record<string, unknown>,
) => PromiseLike<{
  data: VerificationRow[] | null;
  error: { message: string } | null;
}>;

export async function verifyPrivacyRequestIdentity(
  adminClient: SupabaseClient<Database>,
  command: {
    hostname: string;
    privacyRequestId: string;
    statusToken: string;
    assertion: string;
    idempotencyKey: string;
  },
  environment: EnvironmentSource = process.env,
): Promise<RequesterPrivacyStatus & {
  verificationOutcome: PrivacyIdentityVerificationOutcome;
}> {
  const verifier = resolvePrivacyIdentityVerifier(environment);
  const descriptor = verifier.descriptor();
  const verification = await verifier.verify({
    privacyRequestId: command.privacyRequestId,
    assertion: command.assertion,
  });
  const requestHash = privacyVerificationAttemptHash({
    privacyRequestId: command.privacyRequestId,
    assertion: command.assertion,
    idempotencyKey: command.idempotencyKey,
    adapterId: descriptor.adapterId,
    adapterVersion: descriptor.adapterVersion,
    policyVersion: descriptor.policyVersion,
  });
  const rpc = adminClient.rpc.bind(adminClient) as unknown as VerificationRpc;
  const { data, error } = await rpc('settle_privacy_identity_verification', {
    p_hostname: command.hostname,
    p_public_reference: command.privacyRequestId,
    p_status_token_hash: createHash('sha256').update(command.statusToken).digest('hex'),
    p_idempotency_key: command.idempotencyKey,
    p_request_hash: requestHash,
    p_outcome: verification.outcome,
    p_adapter_id: descriptor.adapterId,
    p_adapter_version: descriptor.adapterVersion,
    p_policy_version: descriptor.policyVersion,
    p_evidence_ref: verification.evidenceRef,
    p_reason_codes: verification.reasonCodes,
  });

  if (error || !data || data.length !== 1) {
    throw new Error('PRIVACY_IDENTITY_VERIFICATION_FAILED');
  }

  return {
    ...requesterStatus(data[0]),
    verificationOutcome: data[0].verification_outcome,
  };
}
