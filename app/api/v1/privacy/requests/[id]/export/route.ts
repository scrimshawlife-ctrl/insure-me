import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { downloadPrivacyExport } from '@/src/application/privacy/privacy-data-discovery';
import { createSupabaseAdminClient } from '@/src/infrastructure/supabase/admin';

const requestIdSchema = z.uuid();
const statusTokenSchema = z.string().regex(/^[A-Za-z0-9_-]{43}$/);

function notFound() {
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
  if (!parsedId.success || !parsedToken.success) return notFound();

  try {
    const payload = await downloadPrivacyExport(createSupabaseAdminClient(), {
      hostname: new URL(request.url).hostname.toLowerCase(),
      privacyRequestId: parsedId.data,
      statusToken: parsedToken.data,
    });
    return new NextResponse(`${JSON.stringify(payload, null, 2)}\n`, {
      headers: {
        'Cache-Control': 'no-store',
        'Content-Type': 'application/json; charset=utf-8',
        'Content-Disposition': `attachment; filename="insure-me-privacy-export-${parsedId.data}.json"`,
        'X-Content-Type-Options': 'nosniff',
      },
    });
  } catch {
    return notFound();
  }
}
