import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { createConsumerQuoteCase } from '@/src/application/quote/create-consumer-quote-case';
import { createSupabaseAdminClient } from '@/src/infrastructure/supabase/admin';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const createQuoteSchema = z.object({
  jurisdiction: z.literal('CA'),
  productLine: z.literal('PRIVATE_PASSENGER_AUTO'),
  sourceChannel: z.literal('WEB'),
});

function requestHostname(request: NextRequest): string {
  return new URL(request.url).hostname.toLowerCase();
}

export async function POST(request: NextRequest) {
  const client = await createSupabaseServerClient();
  const { data: claimsData, error: claimsError } = await client.auth.getClaims();
  const claims = claimsData?.claims as { sub?: string } | undefined;

  if (claimsError || !claims?.sub) {
    return NextResponse.json(
      { error: 'CONSUMER_AUTHENTICATION_REQUIRED' },
      { status: 401 },
    );
  }

  const parsed = createQuoteSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json(
      { error: 'REQUEST_VALIDATION_FAILED' },
      { status: 400 },
    );
  }

  try {
    const result = await createConsumerQuoteCase(createSupabaseAdminClient(), {
      hostname: requestHostname(request),
      consumerIdentityId: claims.sub,
      ...parsed.data,
    });

    return NextResponse.json(
      {
        quoteCaseId: result.quoteCaseId,
        state: result.state,
        nextAction: result.nextAction,
      },
      { status: 201 },
    );
  } catch {
    return NextResponse.json(
      { error: 'QUOTE_CASE_CREATE_FAILED' },
      { status: 400 },
    );
  }
}
