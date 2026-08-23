import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { consumeConsumerResumeGrant } from '@/src/application/quote/consumer-resume';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const grantIdSchema = z.string().uuid();

export async function POST(
  _request: NextRequest,
  context: { params: Promise<{ grantId: string }> },
) {
  const { grantId } = await context.params;
  const parsedGrantId = grantIdSchema.safeParse(grantId);

  if (!parsedGrantId.success) {
    return NextResponse.json(
      { error: 'RESUME_GRANT_INVALID' },
      { status: 404 },
    );
  }

  const client = await createSupabaseServerClient();

  try {
    const result = await consumeConsumerResumeGrant(client, parsedGrantId.data);
    return NextResponse.json(result);
  } catch {
    return NextResponse.json(
      { error: 'RESUME_GRANT_INVALID' },
      { status: 404 },
    );
  }
}
