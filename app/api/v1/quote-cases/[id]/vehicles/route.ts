import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import {
  getConsumerVehicles,
  replaceConsumerVehicles,
} from '@/src/application/intake/consumer-intake';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const vehicleSchema = z.object({
  vehicleId: z.string().uuid().optional(),
  vin: z.string().trim().min(11).max(32).optional(),
  modelYear: z.number().int().min(1900).max(2100),
  make: z.string().trim().min(1).max(80),
  model: z.string().trim().min(1).max(80),
  trim: z.string().trim().max(80).optional(),
  ownershipState: z.string().trim().max(40).optional(),
  garagingPostalCode: z.string().regex(/^\d{5}(?:-\d{4})?$/).optional(),
  usage: z.string().trim().min(1).max(40),
  annualMileage: z.number().int().min(0).max(250000).optional(),
  confirmationState: z.enum(['UNCONFIRMED', 'CONFIRMED', 'CORRECTED']).default('CONFIRMED'),
});

const bodySchema = z.object({ vehicles: z.array(vehicleSchema).max(12) });

export async function GET(
  _request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id: quoteCaseId } = await context.params;
  const client = await createSupabaseServerClient();
  try {
    await requireConsumerQuoteContext(client, quoteCaseId);
    return NextResponse.json({ vehicles: await getConsumerVehicles(client, quoteCaseId) });
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
    const vehicles = await replaceConsumerVehicles(client, quoteCaseId, parsed.data.vehicles);
    return NextResponse.json({ vehicles });
  } catch {
    return NextResponse.json({ error: 'CONSUMER_QUOTE_ACCESS_DENIED' }, { status: 404 });
  }
}
