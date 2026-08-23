import type { SupabaseClient } from '@supabase/supabase-js';

import {
  isConsentActionValid,
  type ConsentAction,
} from '@/src/domain/notice/consent';
import type { Database } from '@/src/infrastructure/supabase/database.types';

export interface RecordConsumerConsentCommand {
  quoteCaseId: string;
  noticeDefinitionId: string;
  noticeContentHash: string;
  noticeCategory: Parameters<typeof isConsentActionValid>[0];
  actionType: ConsentAction;
  presentedAt: string;
  channel: 'WEB';
  evidenceRef: string;
  idempotencyKey: string;
}

export interface RecordedConsent {
  consentRecordId: string;
  noticeDefinitionId: string;
  noticeVersion: number;
  noticeContentHash: string;
  actionType: ConsentAction;
  actedAt: string;
}

type ConsentRow = {
  consent_record_id: string;
  notice_definition_id: string;
  notice_version: number;
  notice_content_hash: string;
  action_type: ConsentAction;
  acted_at: string;
};

type RecordConsentRpc = (
  functionName: 'record_consumer_consent_with_audit',
  args: {
    p_quote_case_id: string;
    p_notice_definition_id: string;
    p_notice_content_hash: string;
    p_action_type: ConsentAction;
    p_presented_at: string;
    p_channel: string;
    p_evidence_ref: string;
    p_idempotency_key: string;
  },
) => PromiseLike<{
  data: ConsentRow | ConsentRow[] | null;
  error: { message: string } | null;
}>;

export async function recordConsumerConsent(
  client: SupabaseClient<Database>,
  command: RecordConsumerConsentCommand,
): Promise<RecordedConsent> {
  if (!isConsentActionValid(command.noticeCategory, command.actionType)) {
    throw new Error('CONSENT_ACTION_INVALID_FOR_NOTICE_CATEGORY');
  }

  const rpc = client.rpc as unknown as RecordConsentRpc;
  const { data, error } = await rpc('record_consumer_consent_with_audit', {
    p_quote_case_id: command.quoteCaseId,
    p_notice_definition_id: command.noticeDefinitionId,
    p_notice_content_hash: command.noticeContentHash,
    p_action_type: command.actionType,
    p_presented_at: command.presentedAt,
    p_channel: command.channel,
    p_evidence_ref: command.evidenceRef,
    p_idempotency_key: command.idempotencyKey,
  });

  if (error) {
    throw new Error(`CONSENT_RECORD_FAILED:${error.message}`);
  }

  const row = Array.isArray(data) ? data[0] : data;
  if (!row) {
    throw new Error('CONSENT_RECORD_EMPTY_RESULT');
  }

  return {
    consentRecordId: row.consent_record_id,
    noticeDefinitionId: row.notice_definition_id,
    noticeVersion: row.notice_version,
    noticeContentHash: row.notice_content_hash,
    actionType: row.action_type,
    actedAt: row.acted_at,
  };
}
