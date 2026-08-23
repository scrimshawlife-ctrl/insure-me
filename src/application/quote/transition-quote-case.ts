import type { SupabaseClient } from '@supabase/supabase-js';

import { assertWorkforcePermission, type WorkforceContext } from '@/src/domain/auth/workforce';
import { assertQuoteCaseTransition, type QuoteCaseState } from '@/src/domain/quote/lifecycle';
import type { Database } from '@/src/infrastructure/supabase/database.types';

export interface TransitionQuoteCaseCommand {
  quoteCaseId: string;
  fromState: QuoteCaseState;
  toState: QuoteCaseState;
  eventType: string;
  reasonCodes?: string[];
}

export async function transitionQuoteCase(
  client: SupabaseClient<Database>,
  context: WorkforceContext,
  command: TransitionQuoteCaseCommand,
): Promise<Database['public']['Tables']['quote_cases']['Row']> {
  assertWorkforcePermission(context, 'CASE_WRITE');
  assertQuoteCaseTransition(command.fromState, command.toState);

  const { data, error } = await client.rpc('transition_quote_case_with_audit', {
    p_quote_case_id: command.quoteCaseId,
    p_to_state: command.toState,
    p_event_type: command.eventType,
    p_reason_codes: command.reasonCodes ?? [],
  });

  if (error) {
    throw new Error(`QUOTE_CASE_TRANSITION_FAILED:${error.message}`);
  }
  if (!data) {
    throw new Error('QUOTE_CASE_TRANSITION_EMPTY_RESULT');
  }
  if (data.tenant_id !== context.tenantId || data.agency_id !== context.agencyId) {
    throw new Error('QUOTE_CASE_TRANSITION_CONTEXT_MISMATCH');
  }
  if (data.state !== command.toState) {
    throw new Error('QUOTE_CASE_TRANSITION_STATE_MISMATCH');
  }

  return data;
}
