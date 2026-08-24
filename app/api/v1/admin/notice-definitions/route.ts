import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { createNoticeDefinitionVersion, listNoticeDefinitionVersions } from '@/src/application/notice/notice-administration';
import { noticeCategories } from '@/src/domain/notice-administration';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const schema = z.object({
  noticeKey: z.string().trim().min(3).max(100), category: z.enum(noticeCategories),
  title: z.string().trim().min(3).max(300), bodyMarkdown: z.string().min(1).max(100000),
  requiredForQuote: z.boolean(), evidenceRef: z.string().trim().min(3).max(500),
  reasonCodes: z.array(z.string().trim().min(1).max(100)).min(1).max(20),
  idempotencyKey: z.uuid(),
}).strict();

function failure(error: unknown) {
  const message = error instanceof Error ? error.message : '';
  if (message.startsWith('WORKFORCE_')) return NextResponse.json({ error: 'PERMISSION_DENIED' }, { status: 403 });
  if (message.includes('NOT_FOUND')) return NextResponse.json({ error: 'NOT_FOUND' }, { status: 404 });
  if (message.includes('MISMATCH')) return NextResponse.json({ error: message }, { status: 409 });
  return NextResponse.json({ error: 'NOTICE_ADMINISTRATION_FAILED' }, { status: 500 });
}

export async function POST(request: NextRequest) {
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: 'REQUEST_VALIDATION_FAILED' }, { status: 400 });
  const client = await createSupabaseServerClient();
  try {
    const context = await requireWorkforceContext(client);
    const noticeDefinition = await createNoticeDefinitionVersion(client, {
      agencyId: context.agencyId, ...parsed.data,
    });
    return NextResponse.json({ noticeDefinition }, { status: 201, headers: { 'Cache-Control': 'no-store' } });
  } catch (error) { return failure(error); }
}

export async function GET() {
  const client = await createSupabaseServerClient();
  try {
    const context = await requireWorkforceContext(client);
    const noticeDefinitions = await listNoticeDefinitionVersions(client, context.agencyId);
    return NextResponse.json({ noticeDefinitions }, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) { return failure(error); }
}
