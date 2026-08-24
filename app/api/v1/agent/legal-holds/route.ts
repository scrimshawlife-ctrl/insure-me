import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { placeLegalHold } from '@/src/application/privacy/legal-hold';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const schema = z.object({
  scopeType: z.enum(['PERSON', 'QUOTE_CASE', 'PRIVACY_REQUEST']),
  scopeRef: z.uuid(),
  authorityRef: z.string().trim().min(3).max(500),
  evidenceRef: z.string().trim().min(3).max(500),
  reasonCodes: z.array(z.string().trim().min(1).max(100)).min(1).max(20),
  idempotencyKey: z.uuid(),
}).strict();

export async function POST(request: NextRequest) {
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: 'REQUEST_VALIDATION_FAILED' }, { status: 400 });
  const client = await createSupabaseServerClient();
  try {
    const workforce = await requireWorkforceContext(client);
    const hold = await placeLegalHold(client, {
      tenantId: workforce.tenantId,
      agencyId: workforce.agencyId,
      ...parsed.data,
    });
    return NextResponse.json({ legalHold: hold }, { status: 201 });
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    if (message.includes('NOT_PERMITTED') || message.startsWith('WORKFORCE_')) {
      return NextResponse.json({ error: 'PERMISSION_DENIED' }, { status: 403 });
    }
    if (message.includes('NOT_FOUND')) return NextResponse.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (message.includes('IDEMPOTENCY')) return NextResponse.json({ error: message }, { status: 409 });
    return NextResponse.json({ error: 'LEGAL_HOLD_PLACEMENT_FAILED' }, { status: 500 });
  }
}
