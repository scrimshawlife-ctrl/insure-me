import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { deliverAdverseActionNotice } from '@/src/application/compliance/adverse-action-notice-delivery';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const schema = z.object({
  noticeDefinitionId: z.uuid(),
  noticeContentHash: z.string().regex(/^[0-9a-f]{64}$/),
  channel: z.enum(['EMAIL', 'POSTAL_MAIL', 'SECURE_PORTAL']),
  recipientRef: z.string().trim().min(3).max(500),
  idempotencyKey: z.uuid(),
}).strict();

export async function POST(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  const parsedId = z.uuid().safeParse(id);
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsedId.success || !parsed.success) {
    return NextResponse.json({ error: 'REQUEST_VALIDATION_FAILED' }, { status: 400 });
  }
  const client = await createSupabaseServerClient();
  try {
    await requireWorkforceContext(client);
    const noticeDelivery = await deliverAdverseActionNotice(client, {
      adverseActionCaseId: parsedId.data,
      ...parsed.data,
    });
    return NextResponse.json({ noticeDelivery }, {
      status: noticeDelivery.status === 'DELIVERED' ? 201 : 202,
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    if (message.includes('NOT_CONFIGURED')) {
      return NextResponse.json({ error: 'NOTICE_DELIVERY_UNAVAILABLE' }, { status: 503 });
    }
    if (message.includes('NOT_PERMITTED') || message.startsWith('WORKFORCE_')) {
      return NextResponse.json({ error: 'PERMISSION_DENIED' }, { status: 403 });
    }
    if (message.includes('NOT_FOUND')) return NextResponse.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (message.includes('MISMATCH') || message.includes('ALREADY') || message.includes('REQUIRED')) {
      return NextResponse.json({ error: message }, { status: 409 });
    }
    return NextResponse.json({ error: 'NOTICE_DELIVERY_FAILED' }, { status: 500 });
  }
}
