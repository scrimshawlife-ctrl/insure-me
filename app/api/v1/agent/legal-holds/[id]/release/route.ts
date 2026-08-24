import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { releaseLegalHold } from '@/src/application/privacy/legal-hold';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const idSchema = z.uuid();
const schema = z.object({
  authorityRef: z.string().trim().min(3).max(500),
  evidenceRef: z.string().trim().min(3).max(500),
  reasonCodes: z.array(z.string().trim().min(1).max(100)).min(1).max(20),
  idempotencyKey: z.uuid(),
}).strict();

export async function POST(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  const parsedId = idSchema.safeParse(id);
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsedId.success || !parsed.success) {
    return NextResponse.json({ error: 'REQUEST_VALIDATION_FAILED' }, { status: 400 });
  }
  const client = await createSupabaseServerClient();
  try {
    await requireWorkforceContext(client);
    const hold = await releaseLegalHold(client, { legalHoldId: parsedId.data, ...parsed.data });
    return NextResponse.json({ legalHold: hold });
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    if (message.includes('NOT_PERMITTED') || message.startsWith('WORKFORCE_')) {
      return NextResponse.json({ error: 'PERMISSION_DENIED' }, { status: 403 });
    }
    if (message.includes('NOT_FOUND')) return NextResponse.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (message.includes('ALREADY_RELEASED') || message.includes('IDEMPOTENCY')) {
      return NextResponse.json({ error: message }, { status: 409 });
    }
    return NextResponse.json({ error: 'LEGAL_HOLD_RELEASE_FAILED' }, { status: 500 });
  }
}
