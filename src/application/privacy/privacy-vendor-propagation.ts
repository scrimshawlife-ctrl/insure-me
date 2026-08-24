import { createHash } from 'node:crypto';

import type { SupabaseClient } from '@supabase/supabase-js';

import { requesterStatus, type RequesterPrivacyStatus } from '@/src/application/privacy/privacy-request';
import type {
  PrivacyIdentityState,
  PrivacyPropagationAction,
  PrivacyRequestState,
} from '@/src/domain/privacy';
import type { EnvironmentSource } from '@/src/infrastructure/config/deployment';
import { resolvePrivacyPropagationAdapter } from '@/src/infrastructure/privacy/privacy-propagation-adapter';
import { privacyPropagationRequestHash } from '@/src/infrastructure/security/identity-protection';
import type { Database } from '@/src/infrastructure/supabase/database.types';

type PropagationStatus = 'PENDING' | 'BLOCKED' | 'COMPLETED' | 'FAILED';

type PreparedPropagationRow = {
  privacy_propagation_run_id: string;
  privacy_vendor_propagation_id: string | null;
  target_status: PropagationStatus | null;
  action: PrivacyPropagationAction | null;
  adapter_id: string | null;
  adapter_version: string | null;
  policy_version: string | null;
  public_reference: string;
  state: PrivacyRequestState;
  identity_verification_state: PrivacyIdentityState;
  propagation_complete: boolean;
  status_summary: Record<string, number>;
};

type SettledPropagationRow = {
  public_reference: string;
  state: PrivacyRequestState;
  identity_verification_state: PrivacyIdentityState;
  propagation_complete: boolean;
  status_summary: Record<string, number>;
};

type PrivacyPropagationRpc = (
  functionName:
    | 'prepare_privacy_vendor_propagation'
    | 'settle_privacy_vendor_propagation',
  args: Record<string, unknown>,
) => PromiseLike<{
  data: PreparedPropagationRow[] | SettledPropagationRow[] | null;
  error: { message: string } | null;
}>;

export type PrivacyPropagationStatus = RequesterPrivacyStatus & {
  propagationComplete: boolean;
  statusSummary: Record<string, number>;
};

export async function propagatePrivacyRequestToVendors(
  adminClient: SupabaseClient<Database>,
  command: {
    hostname: string;
    privacyRequestId: string;
    statusToken: string;
    idempotencyKey: string;
  },
  environment: EnvironmentSource = process.env,
): Promise<PrivacyPropagationStatus> {
  const adapter = resolvePrivacyPropagationAdapter(environment);
  const descriptor = adapter.descriptor();
  const rpc = adminClient.rpc.bind(adminClient) as unknown as PrivacyPropagationRpc;
  const preparedResult = await rpc('prepare_privacy_vendor_propagation', {
    p_hostname: command.hostname,
    p_public_reference: command.privacyRequestId,
    p_status_token_hash: createHash('sha256').update(command.statusToken).digest('hex'),
    p_idempotency_key: command.idempotencyKey,
    p_adapter_id: descriptor.adapterId,
    p_adapter_version: descriptor.adapterVersion,
    p_policy_version: descriptor.policyVersion,
  });
  const prepared = preparedResult.data as PreparedPropagationRow[] | null;
  if (preparedResult.error || !prepared?.length) {
    throw new Error('PRIVACY_PROPAGATION_FAILED');
  }

  let result: PrivacyPropagationStatus = {
    ...requesterStatus(prepared[0]),
    propagationComplete: prepared[0].propagation_complete,
    statusSummary: prepared[0].status_summary,
  };
  for (const target of prepared) {
    if (
      !target.privacy_vendor_propagation_id
      || !target.action
      || target.target_status === 'BLOCKED'
      || target.target_status === 'COMPLETED'
    ) continue;
    if (
      target.adapter_id !== descriptor.adapterId
      || target.adapter_version !== descriptor.adapterVersion
      || target.policy_version !== descriptor.policyVersion
    ) {
      throw new Error('PRIVACY_PROPAGATION_BINDING_MISMATCH');
    }
    const propagated = await adapter.propagate({
      privacyRequestId: command.privacyRequestId,
      propagationTargetId: target.privacy_vendor_propagation_id,
      action: target.action,
    });
    const requestHash = privacyPropagationRequestHash({
      privacyRequestId: command.privacyRequestId,
      propagationTargetId: target.privacy_vendor_propagation_id,
      idempotencyKey: command.idempotencyKey,
      adapterId: descriptor.adapterId,
      adapterVersion: descriptor.adapterVersion,
      policyVersion: descriptor.policyVersion,
      action: target.action,
    });
    const settledResult = await rpc('settle_privacy_vendor_propagation', {
      p_privacy_vendor_propagation_id: target.privacy_vendor_propagation_id,
      p_idempotency_key: command.idempotencyKey,
      p_request_hash: requestHash,
      p_outcome: propagated.outcome,
      p_adapter_id: descriptor.adapterId,
      p_adapter_version: descriptor.adapterVersion,
      p_policy_version: descriptor.policyVersion,
      p_evidence_ref: propagated.evidenceRef,
      p_reason_codes: propagated.reasonCodes,
    });
    const settled = settledResult.data?.[0] as SettledPropagationRow | undefined;
    if (settledResult.error || !settled || settledResult.data?.length !== 1) {
      throw new Error('PRIVACY_PROPAGATION_FAILED');
    }
    result = {
      ...requesterStatus(settled),
      propagationComplete: settled.propagation_complete,
      statusSummary: settled.status_summary,
    };
  }
  return result;
}
