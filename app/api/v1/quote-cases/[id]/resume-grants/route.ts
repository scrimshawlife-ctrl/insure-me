import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { createConsumerResumeGrant } from '@/src/application/quote/consumer-resume';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const requestSchema = z.object({
  ttlMinutes: z.number().int().min(5).max(1440).default(60),
});

export async function POST(
  request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id: quoteCaseId } = await context.params;
  const raw = await request.json().catch(() => ({}));
  const parsed = requestSchema.safeParse(raw);

  if (!parsed.success) {
    return NextResponse.json(
      { error: 'REQUEST_VALIDATION_FAILED' },
      { status: 400 },
    );
  }

  const client = await createSupabaseServerClient();

  try {
    await requireConsumerQuoteContext(client, quoteCaseId);
    const grant = await createConsumerResumeGrant(
      client,
      quoteCaseId,
      parsed.data.ttlMinutes,
    );
    return NextResponse.json(grant, { status: 201 });
  } catch {
    return NextResponse.json(
      { error: 'CONSUMER_QUOTE_ACCESS_DENIED' },
      { status: 404 },
    );
  }
}
