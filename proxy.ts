import { NextResponse, type NextRequest } from 'next/server';

import { isMutationOriginAllowed } from '@/src/infrastructure/security/csrf';
import { updateSession } from '@/src/infrastructure/supabase/proxy';

export async function proxy(request: NextRequest) {
  if (!isMutationOriginAllowed({
    method: request.method,
    requestOrigin: request.headers.get('origin'),
    expectedOrigin: request.nextUrl.origin,
    fetchSite: request.headers.get('sec-fetch-site'),
  })) {
    return NextResponse.json({ error: 'CROSS_SITE_MUTATION_DENIED' }, { status: 403 });
  }
  return updateSession(request);
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
