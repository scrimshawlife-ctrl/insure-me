import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import {
  getConsumerDrivers,
  replaceConsumerDrivers,
} from '@/src/application/intake/consumer-intake';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const driverSchema = z.object({
  relationshipRole: z.string().trim().min(1).max(50),
  firstName: z.string().trim().min(1).max(100),
  lastName: z.string().trim().min(1).max(100),
  dateOfBirth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  licenseJurisdiction: z.string().trim().length(2),
  licenseNumber: z.string().trim().min(3).max(64).optional(),
  yearsLicensed: z.number().int().min(0).max(100).optional(),
  confirmationState: z.enum(['UNCONFIRMED', 'CONFIRMED', 'CORRECTED']).default('CONFIRMED'),
});

const bodySchema = z.object({ drivers: z.array(driverSchema).max(12) });

export async function GET(
  _request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id: quoteCaseId } = await context.params;
  const client = await createSupabaseServerClient();
  try {
    await requireConsumerQuoteContext(client, quoteCaseId);
    return NextResponse.json({ drivers: await getConsumerDrivers(client, quoteCaseId) });
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
    const drivers = await replaceConsumerDrivers(client, quoteCaseId, parsed.data.drivers);
    return NextResponse.json({ drivers });
  } catch {
    return NextResponse.json({ error: 'CONSUMER_QUOTE_ACCESS_DENIED' }, { status: 404 });
  }
}
