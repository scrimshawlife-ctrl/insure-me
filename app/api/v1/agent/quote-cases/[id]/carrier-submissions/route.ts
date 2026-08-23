import { randomUUID } from 'node:crypto';

import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { orchestrateCarrierSubmission } from '@/src/application/carriers/orchestrate-carrier-submission';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { resolveCarrierAdapter } from '@/src/infrastructure/carriers/carrier-registry';
import { resolveCarrierProgramContext } from '@/src/infrastructure/carriers/carrier-program-context';
import { SupabaseCarrierSubmissionPersistence } from '@/src/infrastructure/carriers/supabase-carrier-persistence';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const schema = z.object({
  carrierProgramId: z.string().uuid(),
  idempotencyKey: z.string().min(8).max(160),
});

export async function POST(
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
    const resolved = await resolveCarrierProgramContext({
      userClient,
      workforce,
      quoteCaseId,
      carrierProgramId: parsed.data.carrierProgramId,
      idempotencyKey: parsed.data.idempotencyKey,
      traceId: randomUUID(),
    });

    const adapter = resolveCarrierAdapter({
      carrierId: resolved.carrierId,
      carrierProgramId: resolved.context.carrierProgramId,
      adapterId: resolved.adapterId,
      adapterVersion: resolved.adapterVersion,
    });
    const persistence = new SupabaseCarrierSubmissionPersistence();
    const result = await orchestrateCarrierSubmission({
      adapter,
      persistence,
      context: resolved.context,
    });

    return NextResponse.json({
      status: result.status,
      externalReference: result.externalReference ?? null,
      premium: result.premium ?? null,
      reasonCodes: result.reasonCodes,
      receivedAt: result.receivedAt,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'CARRIER_SUBMISSION_FAILED';
    if (message.startsWith('WORKFORCE_') || message === 'ACTIVE_TENANT_REQUIRED') {
      return NextResponse.json({ error: message }, { status: 403 });
    }
    if (message.startsWith('CARRIER_HANDOFF_BLOCKED:')) {
      return NextResponse.json(
        {
          error: 'CARRIER_HANDOFF_BLOCKED',
          reasonCodes: message.slice('CARRIER_HANDOFF_BLOCKED:'.length).split(',').filter(Boolean),
        },
        { status: 409 },
      );
    }
    if (
      message === 'CARRIER_KILL_SWITCHED' ||
      message === 'CARRIER_NOT_CERTIFIED' ||
      message === 'CARRIER_INVALID_CASE_STATE'
    ) {
      return NextResponse.json({ error: message }, { status: 409 });
    }
    if (message === 'CARRIER_PROGRAM_NOT_CONFIGURED' || message === 'QUOTE_CASE_NOT_FOUND') {
      return NextResponse.json({ error: 'NOT_FOUND' }, { status: 404 });
    }
    return NextResponse.json({ error: 'CARRIER_SUBMISSION_FAILED' }, { status: 500 });
  }
}
