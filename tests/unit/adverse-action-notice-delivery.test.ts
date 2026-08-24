import { describe, expect, it } from 'vitest';

import { deliverAdverseActionNotice } from '@/src/application/compliance/adverse-action-notice-delivery';
import { resolveNoticeDeliveryAdapter } from '@/src/infrastructure/notice/notice-delivery-adapter';

const syntheticEnvironment = {
  DEPLOYMENT_STAGE: 'synthetic',
  NOTICE_DELIVERY_ADAPTER_ID: 'synthetic-notice-delivery-v1',
  NOTICE_DELIVERY_ADAPTER_VERSION: '1.0.0',
  NOTICE_DELIVERY_POLICY_VERSION: 'synthetic-notice-delivery-policy-v1',
};

const prepared = {
  adverse_action_notice_delivery_id: 'delivery-1',
  adverse_action_case_id: 'adverse-1',
  notice_definition_id: 'notice-1',
  notice_version: 2,
  notice_content_hash: 'a'.repeat(64),
  channel: 'EMAIL' as const,
  recipient_ref: 'consumer-channel:opaque',
  status: 'PREPARED' as const,
  prepared_at: '2026-08-24T00:00:00Z',
  dispatched_at: null,
  delivered_at: null,
  failed_at: null,
};

describe('adverse-action notice delivery', () => {
  it('binds exact notice and adapter evidence before settling delivery', async () => {
    const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
    const client = { rpc: async (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args });
      if (name === 'prepare_adverse_action_notice_delivery') return { data: prepared, error: null };
      return { data: { ...prepared, status: 'DELIVERED', dispatched_at: '2026-08-24T00:01:00Z', delivered_at: '2026-08-24T00:01:00Z' }, error: null };
    } };
    const result = await deliverAdverseActionNotice(client as never, {
      adverseActionCaseId: 'adverse-1', noticeDefinitionId: 'notice-1',
      noticeContentHash: 'a'.repeat(64), channel: 'EMAIL',
      recipientRef: 'consumer-channel:opaque', idempotencyKey: 'idempotency-1',
    }, syntheticEnvironment);
    expect(result.status).toBe('DELIVERED');
    expect(calls.map((call) => call.name)).toEqual([
      'prepare_adverse_action_notice_delivery',
      'settle_adverse_action_notice_delivery',
    ]);
    expect(calls[0].args).toMatchObject({
      p_notice_content_hash: 'a'.repeat(64),
      p_adapter_id: 'synthetic-notice-delivery-v1',
      p_certification_state: 'SYNTHETIC',
    });
    expect(calls[1].args).toMatchObject({
      p_outcome: 'DELIVERED',
      p_reason_codes: ['SYNTHETIC_DELIVERY_CONFIRMED'],
    });
  });

  it('does not redeliver an idempotently completed notice', async () => {
    const calls: string[] = [];
    const client = { rpc: async (name: string) => {
      calls.push(name);
      return { data: { ...prepared, status: 'DELIVERED', dispatched_at: '2026-08-24T00:01:00Z', delivered_at: '2026-08-24T00:01:00Z' }, error: null };
    } };
    const result = await deliverAdverseActionNotice(client as never, {
      adverseActionCaseId: 'adverse-1', noticeDefinitionId: 'notice-1',
      noticeContentHash: 'a'.repeat(64), channel: 'EMAIL',
      recipientRef: 'consumer-channel:opaque', idempotencyKey: 'idempotency-1',
    }, syntheticEnvironment);
    expect(result.status).toBe('DELIVERED');
    expect(calls).toEqual(['prepare_adverse_action_notice_delivery']);
  });

  it('is deterministic and fails closed outside explicit synthetic configuration', async () => {
    const adapter = resolveNoticeDeliveryAdapter(syntheticEnvironment);
    const input = {
      adverseActionCaseId: 'adverse-1', noticeDeliveryId: 'delivery-1',
      noticeDefinitionId: 'notice-1', noticeVersion: 2,
      noticeContentHash: 'a'.repeat(64), channel: 'EMAIL' as const,
      recipientRef: 'consumer-channel:opaque', idempotencyKey: 'idempotency-1',
    };
    expect(await adapter.deliver(input)).toEqual(await adapter.deliver(input));
    expect(() => resolveNoticeDeliveryAdapter({
      ...syntheticEnvironment,
      DEPLOYMENT_STAGE: 'production',
    })).toThrow('NOTICE_DELIVERY_ADAPTER_NOT_CONFIGURED');
    expect(() => resolveNoticeDeliveryAdapter({
      ...syntheticEnvironment,
      NOTICE_DELIVERY_POLICY_VERSION: 'invented-policy',
    })).toThrow('NOTICE_DELIVERY_ADAPTER_NOT_CONFIGURED');
  });
});
