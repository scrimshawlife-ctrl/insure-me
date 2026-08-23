import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import {
  getConsumerCoverageRequest,
  saveConsumerCoverageRequest,
} from '@/src/application/intake/consumer-intake';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const bodySchema = z.object({
  schemaVersion: z.number().int().positive().default(1),
  requestedLimits: z.record(z.string(), z.union([z.string(), z.number(), z.boolean(), z.null()])),
  preferences: z.record(z.string(), z.union([z.string(), z.number(), z.boolean(), z.null()])),
  notes: z.string().trim().max(1000).optional(),
});

export async function GET(
  _request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id: quoteCaseId } = await context.params;
  const client = await createSupabaseServerClient();
  try {
    await requireConsumerQuoteContext(client, quoteCaseId);
    return NextResponse.json({ coverageRequest: await getConsumerCoverageRequest(client, quoteCaseId) });
  } catch {
    return NextResponse.json({ error: 'CONSUMER_QUOTE_ACCESS_DENIED' }, { status: 404 });
  }
}

export async function PUT(
  request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id: quoteCaseId } = await context.params;
  const parsed = bodySchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: 'REQUEST_VALIDATION_FAILED' }, { status: 400 });
  }

  const client = await createSupabaseServerClient();
  try {
    await requireConsumerQuoteContext(client, quoteCaseId);
    const coverageRequest = await saveConsumerCoverageRequest(client, quoteCaseId, parsed.data);
    return NextResponse.json({ coverageRequest });
  } catch {
    return NextResponse.json({ error: 'CONSUMER_QUOTE_ACCESS_DENIED' }, { status: 404 });
  }
}
