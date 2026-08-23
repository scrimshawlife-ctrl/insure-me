import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

const requestSchema = z.discriminatedUnion('action', [
  z.object({
    action: z.literal('RESOLVE_NON_BLOCKING'),
    readinessIssueId: z.string().uuid(),
    evidence: z.string().trim().min(3).max(1000),
  }),
  z.object({
    action: z.literal('REQUEST_CONSUMER_FOLLOW_UP'),
    readinessIssueId: z.string().uuid().nullable(),
    requestType: z.enum(['MISSING_INFORMATION', 'CORRECTION', 'DOCUMENTATION']),
    message: z.string().trim().min(1).max(2000),
  }),
]);

type ActionRpc = (
  functionName: 'resolve_workforce_readiness_issue' | 'create_workforce_consumer_follow_up',
  args: Record<string, string | null>,
) => PromiseLike<{ data: string | null; error: { message: string } | null }>;

export async function POST(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  const { id: quoteCaseId } = await context.params;
  const parsed = requestSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: 'REQUEST_VALIDATION_FAILED' }, { status: 400 });

  const client = await createSupabaseServerClient();
  try {
    await requireWorkforceContext(client);
    const rpc = client.rpc as unknown as ActionRpc;
    const call = parsed.data.action === 'RESOLVE_NON_BLOCKING'
      ? await rpc('resolve_workforce_readiness_issue', {
          p_quote_case_id: quoteCaseId,
          p_readiness_issue_id: parsed.data.readinessIssueId,
          p_resolution_code: 'REVIEWED_NON_BLOCKING',
          p_evidence: parsed.data.evidence,
        })
      : await rpc('create_workforce_consumer_follow_up', {
          p_quote_case_id: quoteCaseId,
          p_readiness_issue_id: parsed.data.readinessIssueId,
          p_request_type: parsed.data.requestType,
          p_message: parsed.data.message,
        });
    if (call.error) throw new Error(call.error.message);
    return NextResponse.json({ resourceId: call.data });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'CASE_ACTION_FAILED';
    if (message.includes('NOT_PERMITTED') || message.startsWith('WORKFORCE_')) {
      return NextResponse.json({ error: 'PERMISSION_DENIED' }, { status: 403 });
    }
    if (message.includes('NOT_FOUND')) return NextResponse.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (message.includes('BLOCKING_ISSUE') || message.includes('INVALID_')) {
      return NextResponse.json({ error: message }, { status: 409 });
    }
    return NextResponse.json({ error: 'CASE_ACTION_FAILED' }, { status: 500 });
  }
}
