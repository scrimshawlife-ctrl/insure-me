import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { resolveCarrierProgramContext } from '@/src/infrastructure/carriers/carrier-program-context';
import { SupabaseCarrierSubmissionPersistence } from '@/src/infrastructure/carriers/supabase-carrier-persistence';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const schema = z.object({ carrierProgramId: z.string().uuid() });

export async function PUT(
  request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id: quoteCaseId } = await context.params;
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: 'REQUEST_VALIDATION_FAILED' }, { status: 400 });
  }

  const userClient = await createSupabaseServerClient();
  try {
    const workforce = await requireWorkforceContext(userClient);
    await resolveCarrierProgramContext({
      userClient,
      workforce,
      quoteCaseId,
      carrierProgramId: parsed.data.carrierProgramId,
      idempotencyKey: 'selection-only',
      traceId: 'selection-only',
    });

    const persistence = new SupabaseCarrierSubmissionPersistence();
    await persistence.selectCarrierProgram({
      quoteCaseId,
      carrierProgramId: parsed.data.carrierProgramId,
    });

    return NextResponse.json({
      quoteCaseId,
      carrierProgramId: parsed.data.carrierProgramId,
      status: 'SELECTED',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'CARRIER_PROGRAM_SELECTION_FAILED';
    if (message.startsWith('WORKFORCE_') || message === 'ACTIVE_TENANT_REQUIRED') {
      return NextResponse.json({ error: message }, { status: 403 });
    }
    if (message === 'CARRIER_PROGRAM_NOT_CONFIGURED' || message === 'QUOTE_CASE_NOT_FOUND') {
      return NextResponse.json({ error: 'NOT_FOUND' }, { status: 404 });
    }
    if (message === 'CARRIER_KILL_SWITCHED' || message === 'CARRIER_NOT_CERTIFIED') {
      return NextResponse.json({ error: message }, { status: 409 });
    }
    return NextResponse.json({ error: 'CARRIER_PROGRAM_SELECTION_FAILED' }, { status: 500 });
  }
}
