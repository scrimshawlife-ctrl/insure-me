import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { createAdverseActionCase } from '@/src/application/compliance/adverse-action';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const reference = z.string().trim().min(3).max(500);
const schema = z.object({
  quoteCaseId: z.uuid(),
  carrierDecisionId: z.uuid(),
  ownerType: z.enum(['AGENCY', 'CARRIER', 'OTHER']),
  ownerRef: reference,
  determinationAuthorityRef: reference,
  determinationEvidenceRef: reference,
  reasonCodes: z.array(z.string().trim().min(1).max(100)).min(1).max(20),
  reportSources: z.array(z.object({
    externalReportId: z.uuid(),
    craIdentityRef: reference,
    disputeRouteRef: reference,
    contributionBasisCode: z.string().trim().min(3).max(100),
  }).strict()).min(1).max(20),
  idempotencyKey: z.uuid(),
}).strict();

export async function POST(request: NextRequest) {
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: 'REQUEST_VALIDATION_FAILED' }, { status: 400 });
  const client = await createSupabaseServerClient();
  try {
    await requireWorkforceContext(client);
    return NextResponse.json({ adverseActionCase: await createAdverseActionCase(client, parsed.data) }, { status: 201 });
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    if (message.includes('NOT_PERMITTED') || message.startsWith('WORKFORCE_')) return NextResponse.json({ error: 'PERMISSION_DENIED' }, { status: 403 });
    if (message.includes('NOT_FOUND')) return NextResponse.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (message.includes('MISMATCH') || message.includes('ALREADY')) return NextResponse.json({ error: message }, { status: 409 });
    return NextResponse.json({ error: 'ADVERSE_ACTION_CREATE_FAILED' }, { status: 500 });
  }
}
