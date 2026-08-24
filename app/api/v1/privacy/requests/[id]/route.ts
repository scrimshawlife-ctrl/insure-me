import { createHash } from 'node:crypto';

import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { getPrivacyRequestStatus } from '@/src/application/privacy/privacy-request';
import { createSupabaseAdminClient } from '@/src/infrastructure/supabase/admin';

const requestIdSchema = z.uuid();
const statusTokenSchema = z.string().regex(/^[A-Za-z0-9_-]{43}$/);

function requestHostname(request: NextRequest): string {
  return new URL(request.url).hostname.toLowerCase();
}

function notFoundResponse() {
  return NextResponse.json(
    { error: 'PRIVACY_REQUEST_NOT_FOUND' },
    { status: 404, headers: { 'Cache-Control': 'no-store' } },
  );
}

export async function GET(
  request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const parsedId = requestIdSchema.safeParse(id);
  const parsedToken = statusTokenSchema.safeParse(
    request.headers.get('x-privacy-request-token'),
  );

  if (!parsedId.success || !parsedToken.success) {
    return notFoundResponse();
  }

  try {
    const result = await getPrivacyRequestStatus(createSupabaseAdminClient(), {
      hostname: requestHostname(request),
      privacyRequestId: parsedId.data,
      statusTokenHash: createHash('sha256').update(parsedToken.data).digest('hex'),
    });
    return NextResponse.json(result, {
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch {
    return notFoundResponse();
  }
}
