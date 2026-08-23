import { randomUUID } from 'node:crypto';

import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { getRequiredNotices } from '@/src/application/notice/get-required-notices';
import { recordConsumerConsent } from '@/src/application/notice/record-consumer-consent';
import { CONSENT_ACTIONS } from '@/src/domain/notice/consent';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const consentSchema = z.object({
  noticeDefinitionId: z.string().uuid(),
  noticeContentHash: z.string().regex(/^[a-f0-9]{64}$/i),
  actionType: z.enum(CONSENT_ACTIONS),
  presentedAt: z.string().datetime({ offset: true }),
  idempotencyKey: z.string().min(8).max(200),
});

export async function POST(
  request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id: quoteCaseId } = await context.params;
  const parsed = consentSchema.safeParse(await request.json().catch(() => null));

  if (!parsed.success) {
    return NextResponse.json(
      { error: 'REQUEST_VALIDATION_FAILED' },
      { status: 400 },
    );
  }

  const client = await createSupabaseServerClient();

  try {
    await requireConsumerQuoteContext(client, quoteCaseId);
    const notices = await getRequiredNotices(client, quoteCaseId);
    const notice = notices.find(
      (candidate) => candidate.noticeDefinitionId === parsed.data.noticeDefinitionId,
    );

    if (!notice) {
      return NextResponse.json(
        { error: 'NOTICE_NOT_AVAILABLE_FOR_QUOTE' },
        { status: 400 },
      );
    }

    const recorded = await recordConsumerConsent(client, {
      quoteCaseId,
      noticeDefinitionId: parsed.data.noticeDefinitionId,
      noticeContentHash: parsed.data.noticeContentHash,
      noticeCategory: notice.category,
      actionType: parsed.data.actionType,
      presentedAt: parsed.data.presentedAt,
      channel: 'WEB',
      evidenceRef: `web:${randomUUID()}`,
      idempotencyKey: parsed.data.idempotencyKey,
    });

    return NextResponse.json({ consent: recorded }, { status: 201 });
  } catch {
    return NextResponse.json(
      { error: 'CONSUMER_QUOTE_ACCESS_DENIED' },
      { status: 404 },
    );
  }
}
