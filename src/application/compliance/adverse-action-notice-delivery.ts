import { createHash } from 'node:crypto';

import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  AdverseActionNoticeDelivery,
  NoticeDeliveryChannel,
  NoticeDeliveryOutcome,
} from '@/src/domain/privacy';
import type { EnvironmentSource } from '@/src/infrastructure/config/deployment';
import { resolveNoticeDeliveryAdapter } from '@/src/infrastructure/notice/notice-delivery-adapter';
import type { Database } from '@/src/infrastructure/supabase/database.types';

type Row = {
  adverse_action_notice_delivery_id: string;
  adverse_action_case_id: string;
  notice_definition_id: string;
  notice_version: number;
  notice_content_hash: string;
  channel: NoticeDeliveryChannel;
  recipient_ref: string;
  status: 'PREPARED' | 'DISPATCHED' | 'DELIVERED' | 'FAILED';
  prepared_at: string;
  dispatched_at: string | null;
  delivered_at: string | null;
  failed_at: string | null;
};

type Rpc = (
  name: 'prepare_adverse_action_notice_delivery' | 'settle_adverse_action_notice_delivery',
  args: Record<string, unknown>,
) => PromiseLike<{ data: Row | null; error: { message: string } | null }>;

function hash(parts: unknown[]): string {
  return createHash('sha256').update(JSON.stringify(parts)).digest('hex');
}

function map(row: Row): AdverseActionNoticeDelivery {
  return {
    noticeDeliveryId: row.adverse_action_notice_delivery_id,
    adverseActionCaseId: row.adverse_action_case_id,
    noticeDefinitionId: row.notice_definition_id,
    noticeVersion: row.notice_version,
    noticeContentHash: row.notice_content_hash,
    channel: row.channel,
    status: row.status,
    preparedAt: row.prepared_at,
    ...(row.dispatched_at ? { dispatchedAt: row.dispatched_at } : {}),
    ...(row.delivered_at ? { deliveredAt: row.delivered_at } : {}),
    ...(row.failed_at ? { failedAt: row.failed_at } : {}),
  };
}

export async function deliverAdverseActionNotice(
  client: SupabaseClient<Database>,
  command: {
    adverseActionCaseId: string;
    noticeDefinitionId: string;
    noticeContentHash: string;
    channel: NoticeDeliveryChannel;
    recipientRef: string;
    idempotencyKey: string;
  },
  environment: EnvironmentSource = process.env,
): Promise<AdverseActionNoticeDelivery> {
  const adapter = resolveNoticeDeliveryAdapter(environment);
  const descriptor = adapter.descriptor();
  const rpc = client.rpc.bind(client) as unknown as Rpc;
  const preparationHash = hash(['PREPARE', command.adverseActionCaseId,
    command.noticeDefinitionId, command.noticeContentHash, command.channel,
    command.recipientRef, descriptor]);
  const prepared = await rpc('prepare_adverse_action_notice_delivery', {
    p_adverse_action_case_id: command.adverseActionCaseId,
    p_notice_definition_id: command.noticeDefinitionId,
    p_notice_content_hash: command.noticeContentHash,
    p_channel: command.channel,
    p_recipient_ref: command.recipientRef,
    p_adapter_id: descriptor.adapterId,
    p_adapter_version: descriptor.adapterVersion,
    p_delivery_policy_version: descriptor.policyVersion,
    p_certification_state: descriptor.certificationState,
    p_idempotency_key: command.idempotencyKey,
    p_request_hash: preparationHash,
  });
  if (prepared.error || !prepared.data) {
    throw new Error(prepared.error?.message ?? 'NOTICE_DELIVERY_PREPARATION_FAILED');
  }
  if (prepared.data.status === 'DELIVERED') return map(prepared.data);

  const result = await adapter.deliver({
    adverseActionCaseId: command.adverseActionCaseId,
    noticeDeliveryId: prepared.data.adverse_action_notice_delivery_id,
    noticeDefinitionId: prepared.data.notice_definition_id,
    noticeVersion: prepared.data.notice_version,
    noticeContentHash: prepared.data.notice_content_hash,
    channel: prepared.data.channel,
    recipientRef: prepared.data.recipient_ref,
    idempotencyKey: command.idempotencyKey,
  });
  return settle(rpc, prepared.data, command.idempotencyKey, descriptor, result);
}

async function settle(
  rpc: Rpc,
  prepared: Row,
  idempotencyKey: string,
  descriptor: ReturnType<ReturnType<typeof resolveNoticeDeliveryAdapter>['descriptor']>,
  result: { outcome: NoticeDeliveryOutcome; evidenceRef: string; reasonCodes: string[] },
): Promise<AdverseActionNoticeDelivery> {
  const settlementHash = hash(['SETTLE', prepared.adverse_action_notice_delivery_id,
    idempotencyKey, descriptor, result]);
  const settled = await rpc('settle_adverse_action_notice_delivery', {
    p_adverse_action_notice_delivery_id: prepared.adverse_action_notice_delivery_id,
    p_outcome: result.outcome,
    p_adapter_id: descriptor.adapterId,
    p_adapter_version: descriptor.adapterVersion,
    p_delivery_policy_version: descriptor.policyVersion,
    p_evidence_ref: result.evidenceRef,
    p_reason_codes: result.reasonCodes,
    p_idempotency_key: idempotencyKey,
    p_request_hash: settlementHash,
  });
  if (settled.error || !settled.data) {
    throw new Error(settled.error?.message ?? 'NOTICE_DELIVERY_SETTLEMENT_FAILED');
  }
  return map(settled.data);
}
