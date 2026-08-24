import { NextResponse } from 'next/server';

import { listRetentionPolicies } from '@/src/application/policy/policy-inspection';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

export async function GET() {
  const client = await createSupabaseServerClient();
  try {
    await requireWorkforceContext(client);
    const retentionPolicies = await listRetentionPolicies(client);
    return NextResponse.json({ retentionPolicies }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json({ error: 'PERMISSION_DENIED' }, { status: 403, headers: { 'Cache-Control': 'no-store' } });
  }
}
