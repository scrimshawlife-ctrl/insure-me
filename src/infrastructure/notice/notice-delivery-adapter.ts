import { createHash } from 'node:crypto';

import { z } from 'zod';

import type { NoticeDeliveryAdapter } from '@/src/domain/privacy';
import {
  getDeploymentControlEnvironment,
  type EnvironmentSource,
} from '@/src/infrastructure/config/deployment';

const environmentSchema = z.object({
  NOTICE_DELIVERY_ADAPTER_ID: z.string().min(3).max(100),
  NOTICE_DELIVERY_ADAPTER_VERSION: z.string().min(1).max(100),
  NOTICE_DELIVERY_POLICY_VERSION: z.string().min(3).max(200),
});

const SYNTHETIC_ADAPTER_ID = 'synthetic-notice-delivery-v1';
const SYNTHETIC_ADAPTER_VERSION = '1.0.0';
const SYNTHETIC_POLICY_VERSION = 'synthetic-notice-delivery-policy-v1';

class SyntheticNoticeDeliveryAdapter implements NoticeDeliveryAdapter {
  descriptor() {
    return {
      adapterId: SYNTHETIC_ADAPTER_ID,
      adapterVersion: SYNTHETIC_ADAPTER_VERSION,
      policyVersion: SYNTHETIC_POLICY_VERSION,
      certificationState: 'SYNTHETIC' as const,
    };
  }

  async deliver(input: Parameters<NoticeDeliveryAdapter['deliver']>[0]) {
    const digest = createHash('sha256').update([
      input.adverseActionCaseId,
      input.noticeDeliveryId,
      input.noticeDefinitionId,
      input.noticeVersion,
      input.noticeContentHash,
      input.channel,
      input.recipientRef,
      input.idempotencyKey,
    ].join('|')).digest('hex');
    return {
      outcome: 'DELIVERED' as const,
      evidenceRef: `synthetic-notice-delivery:${digest.slice(0, 32)}`,
      reasonCodes: ['SYNTHETIC_DELIVERY_CONFIRMED'],
    };
  }
}

export function resolveNoticeDeliveryAdapter(
  source: EnvironmentSource = process.env,
): NoticeDeliveryAdapter {
  const deployment = getDeploymentControlEnvironment(source);
  const parsed = environmentSchema.safeParse(source);
  if (
    parsed.success
    && deployment.DEPLOYMENT_STAGE === 'synthetic'
    && parsed.data.NOTICE_DELIVERY_ADAPTER_ID === SYNTHETIC_ADAPTER_ID
    && parsed.data.NOTICE_DELIVERY_ADAPTER_VERSION === SYNTHETIC_ADAPTER_VERSION
    && parsed.data.NOTICE_DELIVERY_POLICY_VERSION === SYNTHETIC_POLICY_VERSION
  ) return new SyntheticNoticeDeliveryAdapter();
  throw new Error('NOTICE_DELIVERY_ADAPTER_NOT_CONFIGURED');
}
