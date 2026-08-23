import type { WorkforceContext } from '@/src/domain/auth/workforce';
import { createSupabaseAdminClient } from '@/src/infrastructure/supabase/admin';

type SignalType = 'PROVIDER_ORDER_ATTEMPT' | 'DENIED_LOOKUP';
type GenericRpc = (name: 'record_workforce_security_signal', args: Record<string, unknown>) => PromiseLike<{ data: unknown; error: { message: string } | null }>;

export async function recordWorkforceSecuritySignal(input: {
  workforce: WorkforceContext;
  signalType: SignalType;
  limit: number;
  windowSeconds: number;
  reasonCodes?: string[];
}): Promise<{ allowed: boolean; count: number; alertCreated: boolean }> {
  const client = createSupabaseAdminClient();
  const rpc = client.rpc as unknown as GenericRpc;
  const { data, error } = await rpc('record_workforce_security_signal', {
    p_tenant_id: input.workforce.tenantId,
    p_agency_id: input.workforce.agencyId,
    p_actor_id: input.workforce.userId,
    p_signal_type: input.signalType,
    p_route_category: 'PROVIDER_ORDER',
    p_limit: input.limit,
    p_window_seconds: input.windowSeconds,
    p_reason_codes: input.reasonCodes ?? [],
  });
  if (error) throw new Error(`SECURITY_SIGNAL_FAILED:${error.message}`);
  const row = Array.isArray(data) ? data[0] as Record<string, unknown> | undefined : undefined;
  if (!row) throw new Error('SECURITY_SIGNAL_FAILED:NO_RESULT');
  return { allowed: row.allowed === true, count: Number(row.signal_count), alertCreated: row.alert_created === true };
}
