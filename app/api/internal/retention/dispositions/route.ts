import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import {
  authorizeRetentionWorker,
  processRetentionDispositions,
} from '@/src/application/privacy/retention-disposition-worker';
import { createSupabaseAdminClient } from '@/src/infrastructure/supabase/admin';

export const dynamic = 'force-dynamic';

const requestSchema = z.object({
  idempotencyKey: z.uuid(),
  asOf: z.iso.datetime({ offset: true }),
  limit: z.number().int().min(1).max(500).default(100),
}).strict();

function response(error: string, status: number) {
  return NextResponse.json(
    { error },
    { status, headers: { 'Cache-Control': 'no-store' } },
  );
}

export async function POST(request: NextRequest) {
  try {
    if (!authorizeRetentionWorker(request.headers.get('authorization'))) {
      return response('RETENTION_WORKER_UNAUTHORIZED', 401);
    }
  } catch {
    return response('RETENTION_WORKER_UNAVAILABLE', 503);
  }
  const parsed = requestSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return response('RETENTION_WORKER_INPUT_INVALID', 400);
  try {
    const result = await processRetentionDispositions(
      createSupabaseAdminClient(),
      parsed.data,
    );
    return NextResponse.json(result, {
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch {
    return response('RETENTION_WORKER_FAILED', 503);
  }
}
