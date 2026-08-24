import { createHash } from 'node:crypto';

import type { SupabaseClient } from '@supabase/supabase-js';

import { requesterStatus, type RequesterPrivacyStatus } from '@/src/application/privacy/privacy-request';
import type {
  PrivacyIdentityState,
  PrivacyRequestState,
  PrivacyRequestType,
  PrivacyRightsExecutionOutcome,
} from '@/src/domain/privacy';
import type { EnvironmentSource } from '@/src/infrastructure/config/deployment';
import {
  resolvePrivacyRightsExecutionPolicy,
} from '@/src/infrastructure/privacy/privacy-rights-execution-policy';
import {
  type ConsumerIdentityPayload,
  privacyRightsExecutionRequestHash,
  protectConsumerIdentity,
  unprotectJsonPayload,
} from '@/src/infrastructure/security/identity-protection';
import type { Database } from '@/src/infrastructure/supabase/database.types';

export type PrivacyCorrections = Partial<Pick<
  ConsumerIdentityPayload,
  'firstName' | 'lastName' | 'email' | 'phone' | 'address'
>>;

type PreparedExecutionRow = {
  privacy_rights_execution_id: string;
  execution_status: 'PREPARED' | 'COMPLETED';
  request_type: PrivacyRequestType;
  public_reference: string;
  state: PrivacyRequestState;
  identity_verification_state: PrivacyIdentityState;
  encrypted_profile_hex: string | null;
  profile_key_version: string | null;
  execution_outcome: PrivacyRightsExecutionOutcome | null;
  action_summary: Record<string, unknown>;
};

type SettledExecutionRow = {
  public_reference: string;
  state: PrivacyRequestState;
  identity_verification_state: PrivacyIdentityState;
  execution_outcome: PrivacyRightsExecutionOutcome;
  action_summary: Record<string, unknown>;
};

type PrivacyRightsRpc = (
  functionName: 'prepare_privacy_rights_execution' | 'settle_privacy_rights_execution',
  args: Record<string, unknown>,
) => PromiseLike<{
  data: PreparedExecutionRow[] | SettledExecutionRow[] | null;
  error: { message: string } | null;
}>;

export type PrivacyRightsExecutionStatus = RequesterPrivacyStatus & {
  executionOutcome: PrivacyRightsExecutionOutcome;
  actionSummary: Record<string, unknown>;
};

export function applyPrivacyCorrections(
  current: ConsumerIdentityPayload,
  corrections: PrivacyCorrections,
): ConsumerIdentityPayload {
  return {
    ...current,
    ...corrections,
    address: corrections.address ?? current.address,
  };
}

export async function executePrivacyRightsRequest(
  adminClient: SupabaseClient<Database>,
  command: {
    hostname: string;
    privacyRequestId: string;
    statusToken: string;
    idempotencyKey: string;
    corrections: PrivacyCorrections | null;
  },
  environment: EnvironmentSource = process.env,
): Promise<PrivacyRightsExecutionStatus> {
  const policy = resolvePrivacyRightsExecutionPolicy(environment);
  const requestHash = privacyRightsExecutionRequestHash({
    privacyRequestId: command.privacyRequestId,
    idempotencyKey: command.idempotencyKey,
    policyVersion: policy.policyVersion,
    corrections: command.corrections,
  });
  const correctionFields = command.corrections
    ? Object.keys(command.corrections).sort()
    : [];
  const rpc = adminClient.rpc as unknown as PrivacyRightsRpc;
  const preparedResult = await rpc('prepare_privacy_rights_execution', {
    p_hostname: command.hostname,
    p_public_reference: command.privacyRequestId,
    p_status_token_hash: createHash('sha256').update(command.statusToken).digest('hex'),
    p_idempotency_key: command.idempotencyKey,
    p_request_hash: requestHash,
    p_policy_version: policy.policyVersion,
    p_correction_fields: correctionFields,
  });
  const prepared = preparedResult.data?.[0] as PreparedExecutionRow | undefined;
  if (preparedResult.error || !prepared || preparedResult.data?.length !== 1) {
    throw new Error('PRIVACY_RIGHTS_EXECUTION_FAILED');
  }
  if (prepared.execution_status === 'COMPLETED') {
    if (!prepared.execution_outcome) throw new Error('PRIVACY_RIGHTS_EXECUTION_FAILED');
    return {
      ...requesterStatus(prepared),
      executionOutcome: prepared.execution_outcome,
      actionSummary: prepared.action_summary,
    };
  }

  let protectedProfile: ReturnType<typeof protectConsumerIdentity> | null = null;
  if (
    prepared.request_type === 'CORRECTION'
    && prepared.encrypted_profile_hex
    && prepared.profile_key_version
  ) {
    if (!command.corrections) {
      throw new Error('PRIVACY_RIGHTS_EXECUTION_FAILED');
    }
    const current = unprotectJsonPayload<ConsumerIdentityPayload>(
      prepared.encrypted_profile_hex,
      prepared.profile_key_version,
    );
    protectedProfile = protectConsumerIdentity(
      applyPrivacyCorrections(current, command.corrections),
    );
  }

  const settledResult = await rpc('settle_privacy_rights_execution', {
    p_privacy_rights_execution_id: prepared.privacy_rights_execution_id,
    p_encrypted_profile: protectedProfile?.pgBytea ?? null,
    p_profile_key_version: protectedProfile?.keyVersion ?? null,
    p_email_lookup_hash: protectedProfile?.emailLookupHash ?? null,
    p_phone_lookup_hash: protectedProfile?.phoneLookupHash ?? null,
  });
  const settled = settledResult.data?.[0] as SettledExecutionRow | undefined;
  if (settledResult.error || !settled || settledResult.data?.length !== 1) {
    throw new Error('PRIVACY_RIGHTS_EXECUTION_FAILED');
  }
  return {
    ...requesterStatus(settled),
    executionOutcome: settled.execution_outcome,
    actionSummary: settled.action_summary,
  };
}
