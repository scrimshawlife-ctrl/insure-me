import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { createComplianceEvidenceExport } from '@/src/application/compliance/compliance-evidence-export';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const schema = z.object({
  quoteCaseId: z.uuid(),
  asOf: z.iso.datetime({ offset: true }),
  purposeRef: z.string().trim().min(3).max(500),
  reasonCodes: z.array(z.string().trim().min(1).max(100)).min(1).max(20),
  idempotencyKey: z.uuid(),
}).strict();

export async function POST(request: NextRequest) {
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: 'REQUEST_VALIDATION_FAILED' }, { status: 400 });
  }
  const client = await createSupabaseServerClient();
  try {
    await requireWorkforceContext(client);
    const complianceEvidenceExport = await createComplianceEvidenceExport(client, parsed.data);
    return NextResponse.json({ complianceEvidenceExport }, {
      status: 201,
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    if (message.startsWith('WORKFORCE_')) {
      return NextResponse.json({ error: 'PERMISSION_DENIED' }, { status: 403 });
    }
    if (message.includes('NOT_FOUND')) {
      return NextResponse.json({ error: 'NOT_FOUND' }, { status: 404 });
    }
    if (message.includes('MISMATCH')) {
      return NextResponse.json({ error: message }, { status: 409 });
    }
    if (message.includes('TOO_LARGE')) {
      return NextResponse.json({ error: message }, { status: 413 });
    }
    return NextResponse.json({ error: 'COMPLIANCE_EXPORT_CREATE_FAILED' }, { status: 500 });
  }
}
