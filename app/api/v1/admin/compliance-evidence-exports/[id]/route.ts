import { createHash } from 'node:crypto';

import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { getComplianceEvidenceExport } from '@/src/application/compliance/compliance-evidence-export';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

export async function GET(
  _request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const parsedId = z.uuid().safeParse(id);
  if (!parsedId.success) {
    return NextResponse.json({ error: 'NOT_FOUND' }, { status: 404 });
  }
  const client = await createSupabaseServerClient();
  try {
    await requireWorkforceContext(client);
    const artifact = await getComplianceEvidenceExport(client, parsedId.data);
    const payload = `${JSON.stringify(artifact.manifest, null, 2)}\n`;
    const contentHash = createHash('sha256').update(payload).digest('hex');
    return new NextResponse(payload, {
      headers: {
        'Cache-Control': 'no-store',
        'Content-Type': 'application/json; charset=utf-8',
        'Content-Disposition': `attachment; filename="insure-me-compliance-evidence-${artifact.complianceEvidenceExportId}.json"`,
        'X-Content-SHA256': contentHash,
        'X-Manifest-SHA256': artifact.manifestHash,
        'X-Content-Type-Options': 'nosniff',
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    if (message.startsWith('WORKFORCE_')) {
      return NextResponse.json({ error: 'PERMISSION_DENIED' }, { status: 403 });
    }
    return NextResponse.json({ error: 'NOT_FOUND' }, { status: 404 });
  }
}
