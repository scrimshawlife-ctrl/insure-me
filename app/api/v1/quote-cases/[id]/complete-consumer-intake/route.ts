import { NextResponse, type NextRequest } from 'next/server';

import { completeConsumerIntake } from '@/src/application/intake/consumer-intake';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

export async function POST(
  _request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id: quoteCaseId } = await context.params;
  const client = await createSupabaseServerClient();

  try {
    await requireConsumerQuoteContext(client, quoteCaseId);
    const result = await completeConsumerIntake(client, quoteCaseId);
    return NextResponse.json(result ?? { quoteCaseId, state: 'DATA_ENRICHMENT', nextAction: 'ENRICHMENT' });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'CONSUMER_INTAKE_COMPLETION_FAILED';
    const known = [
      'DRIVER_REQUIRED',
      'VEHICLE_REQUIRED',
      'COVERAGE_REQUEST_REQUIRED',
      'REQUIRED_NOTICES_INCOMPLETE',
      'CONSUMER_INTAKE_STATE_INVALID',
    ];
    if (known.some((code) => message.includes(code))) {
      return NextResponse.json({ error: 'CONSUMER_INTAKE_INCOMPLETE', reason: message }, { status: 409 });
    }
    return NextResponse.json({ error: 'CONSUMER_QUOTE_ACCESS_DENIED' }, { status: 404 });
  }
}
