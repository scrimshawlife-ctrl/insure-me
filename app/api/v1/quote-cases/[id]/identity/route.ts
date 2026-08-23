import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { updateConsumerIdentity } from '@/src/application/identity/update-consumer-identity';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const identitySchema = z.object({
  firstName: z.string().trim().min(1).max(100),
  lastName: z.string().trim().min(1).max(100),
  dateOfBirth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  email: z.string().email().max(254),
  phone: z.string().trim().min(7).max(32).optional(),
  address: z.object({
    line1: z.string().trim().min(1).max(160),
    line2: z.string().trim().max(160).optional(),
    city: z.string().trim().min(1).max(100),
    state: z.literal('CA'),
    postalCode: z.string().regex(/^\d{5}(?:-\d{4})?$/),
  }),
});

export async function PATCH(
  request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id: quoteCaseId } = await context.params;
  const parsed = identitySchema.safeParse(await request.json().catch(() => null));

  if (!parsed.success) {
    return NextResponse.json(
      { error: 'REQUEST_VALIDATION_FAILED' },
      { status: 400 },
    );
  }

  const client = await createSupabaseServerClient();

  try {
    await requireConsumerQuoteContext(client, quoteCaseId);
    await updateConsumerIdentity(client, quoteCaseId, parsed.data);
    return NextResponse.json({ status: 'SAVED' });
  } catch {
    return NextResponse.json(
      { error: 'CONSUMER_QUOTE_ACCESS_DENIED' },
      { status: 404 },
    );
  }
}
