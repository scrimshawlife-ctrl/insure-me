import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { verifyPrivacyRequestIdentity } from '@/src/application/privacy/verify-privacy-request-identity';
import { createSupabaseAdminClient } from '@/src/infrastructure/supabase/admin';

const requestIdSchema = z.uuid();
const statusTokenSchema = z.string().regex(/^[A-Za-z0-9_-]{43}$/);
const verificationSchema = z.object({
  assertion: z.string().trim().min(1).max(128),
  idempotencyKey: z.uuid(),
}).strict();

function requestHostname(request: NextRequest): string {
  return new URL(request.url).hostname.toLowerCase();
}

function response(error: string, status: number) {
  return NextResponse.json(
    { error },
    { status, headers: { 'Cache-Control': 'no-store' } },
  );
}

export async function POST(
  request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const parsedId = requestIdSchema.safeParse(id);
  const parsedToken = statusTokenSchema.safeParse(
    request.headers.get('x-privacy-request-token'),
  );
  const parsedBody = verificationSchema.safeParse(
    await request.json().catch(() => null),
  );

  if (!parsedId.success || !parsedToken.success || !parsedBody.success) {
    return response('PRIVACY_REQUEST_NOT_FOUND', 404);
  }

  try {
    const result = await verifyPrivacyRequestIdentity(
      createSupabaseAdminClient(),
      {
        hostname: requestHostname(request),
        privacyRequestId: parsedId.data,
        statusToken: parsedToken.data,
        assertion: parsedBody.data.assertion,
        idempotencyKey: parsedBody.data.idempotencyKey,
      },
    );
    return NextResponse.json(result, {
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    if (
      message.includes('PRIVACY_IDENTITY_VERIFIER_NOT_CONFIGURED')
      || message.includes('SYNTHETIC_ADAPTER_FORBIDDEN_IN_LIVE_STAGE')
    ) {
      return response('PRIVACY_IDENTITY_VERIFICATION_UNAVAILABLE', 503);
    }
    return response('PRIVACY_REQUEST_NOT_FOUND', 404);
  }
}

