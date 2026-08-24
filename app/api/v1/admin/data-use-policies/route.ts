import { NextResponse } from 'next/server';

import { listDataUsePolicyRules } from '@/src/application/policy/policy-inspection';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

function failure(error: unknown) {
  const message = error instanceof Error ? error.message : '';
  if (message.startsWith('WORKFORCE_') || message.includes('AUTHENTICATION_REQUIRED')
    || message.includes('POLICY_INSPECTION_SCOPE_NOT_FOUND')) {
    return NextResponse.json({ error: 'PERMISSION_DENIED' }, { status: 403, headers: { 'Cache-Control': 'no-store' } });
  }
  return NextResponse.json({ error: 'POLICY_INSPECTION_FAILED' }, { status: 500, headers: { 'Cache-Control': 'no-store' } });
}

export async function GET() {
  const client = await createSupabaseServerClient();
  try {
    await requireWorkforceContext(client);
    const dataUsePolicyRules = await listDataUsePolicyRules(client);
    return NextResponse.json({ dataUsePolicyRules }, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) { return failure(error); }
}
