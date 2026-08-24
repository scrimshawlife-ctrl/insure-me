import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import {
  propagatePrivacyRequestToVendors,
} from '@/src/application/privacy/privacy-vendor-propagation';
import { createSupabaseAdminClient } from '@/src/infrastructure/supabase/admin';

const requestIdSchema = z.uuid();
const statusTokenSchema = z.string().regex(/^[A-Za-z0-9_-]{43}$/);
const propagationSchema = z.object({ idempotencyKey: z.uuid() }).strict();

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
  const parsedBody = propagationSchema.safeParse(
    await request.json().catch(() => null),
  );
  if (!parsedId.success || !parsedToken.success || !parsedBody.success) {
    return response('PRIVACY_REQUEST_NOT_FOUND', 404);
  }
  try {
    const result = await propagatePrivacyRequestToVendors(
      createSupabaseAdminClient(),
      {
        hostname: new URL(request.url).hostname.toLowerCase(),
        privacyRequestId: parsedId.data,
        statusToken: parsedToken.data,
        idempotencyKey: parsedBody.data.idempotencyKey,
      },
    );
    return NextResponse.json(result, {
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    if (message.includes('PRIVACY_PROPAGATION_ADAPTER_NOT_CONFIGURED')) {
      return response('PRIVACY_PROPAGATION_UNAVAILABLE', 503);
    }
    return response('PRIVACY_REQUEST_NOT_FOUND', 404);
  }
}
