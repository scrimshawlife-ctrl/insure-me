import { NextResponse, type NextRequest } from 'next/server';

import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { listCarrierProgramsForCase } from '@/src/infrastructure/carriers/carrier-program-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

export async function GET(request: NextRequest) {
  const quoteCaseId = request.nextUrl.searchParams.get('quoteCaseId');
  if (!quoteCaseId) {
    return NextResponse.json({ error: 'QUOTE_CASE_ID_REQUIRED' }, { status: 400 });
  }

  const userClient = await createSupabaseServerClient();
  try {
    const workforce = await requireWorkforceContext(userClient);
    const programs = await listCarrierProgramsForCase({
      userClient,
      workforce,
      quoteCaseId,
    });

    return NextResponse.json({
      programs: programs.map((program) => ({
        carrierProgramId: program.carrierProgramId,
        carrierDisplayName: program.carrierDisplayName,
        programDisplayName: program.programCode,
        mode: program.handoffMode,
        certificationState: program.certificationState,
        killSwitchEnabled: program.killSwitchEnabled,
      })),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'CARRIER_PROGRAM_LIST_FAILED';
    if (message.startsWith('WORKFORCE_') || message === 'ACTIVE_TENANT_REQUIRED') {
      return NextResponse.json({ error: message }, { status: 403 });
    }
    return NextResponse.json({ error: 'CARRIER_PROGRAM_LIST_FAILED' }, { status: 500 });
  }
}
