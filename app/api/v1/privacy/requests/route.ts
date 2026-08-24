import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { createPrivacyRequest } from '@/src/application/privacy/privacy-request';
import { createSupabaseAdminClient } from '@/src/infrastructure/supabase/admin';

const privacyRequestSchema = z.object({
  requestType: z.enum(['ACCESS', 'CORRECTION', 'DELETION', 'RESTRICTION', 'OPT_OUT']),
  jurisdiction: z.literal('CA'),
  requester: z.object({
    firstName: z.string().trim().min(1).max(100),
    lastName: z.string().trim().min(1).max(100),
    email: z.string().trim().email().max(254),
    phone: z.string().trim().regex(/^(?=(?:\D*\d){7,})\+?[0-9() .-]{7,32}$/).optional(),
  }).strict(),
  idempotencyKey: z.uuid(),
}).strict();

function requestHostname(request: NextRequest): string {
  return new URL(request.url).hostname.toLowerCase();
}

export async function POST(request: NextRequest) {
  const parsed = privacyRequestSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: 'REQUEST_VALIDATION_FAILED' }, { status: 400 });
  }

  try {
    const result = await createPrivacyRequest(createSupabaseAdminClient(), {
      hostname: requestHostname(request),
      requestType: parsed.data.requestType,
      jurisdiction: parsed.data.jurisdiction,
      intakeChannel: 'WEB',
      requester: parsed.data.requester,
      idempotencyKey: parsed.data.idempotencyKey,
    });

    return NextResponse.json(result, {
      status: 202,
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch {
    return NextResponse.json({ error: 'PRIVACY_REQUEST_CREATE_FAILED' }, { status: 400 });
  }
}
