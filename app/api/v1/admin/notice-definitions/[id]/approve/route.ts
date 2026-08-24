import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { approveNoticeDefinitionVersion } from '@/src/application/notice/notice-administration';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const schema = z.object({ approvalRef: z.string().trim().min(3).max(500),
  effectiveAt: z.iso.datetime({ offset: true }), reasonCodes: z.array(z.string().trim().min(1).max(100)).min(1).max(20),
  idempotencyKey: z.uuid() }).strict();

export async function POST(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params; const parsedId = z.uuid().safeParse(id);
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsedId.success || !parsed.success) return NextResponse.json({ error: 'REQUEST_VALIDATION_FAILED' }, { status: 400 });
  const client = await createSupabaseServerClient();
  try {
    await requireWorkforceContext(client);
    const noticeDefinition = await approveNoticeDefinitionVersion(client,
      { noticeDefinitionId: parsedId.data, ...parsed.data });
    return NextResponse.json({ noticeDefinition }, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    if (message.startsWith('WORKFORCE_')) return NextResponse.json({ error: 'PERMISSION_DENIED' }, { status: 403 });
    if (message.includes('NOT_FOUND')) return NextResponse.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (message.includes('MISMATCH') || message.includes('STATE_INVALID')) return NextResponse.json({ error: message }, { status: 409 });
    return NextResponse.json({ error: 'NOTICE_APPROVAL_FAILED' }, { status: 500 });
  }
}
