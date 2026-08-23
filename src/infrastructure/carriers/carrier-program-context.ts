import type { SupabaseClient } from '@supabase/supabase-js';

import { assertWorkforcePermission, type WorkforceContext } from '@/src/domain/auth/workforce';
import type { CarrierRequestContext } from '@/src/domain/carriers';
import type { Database } from '@/src/infrastructure/supabase/database.types';
import { createSupabaseAdminClient } from '@/src/infrastructure/supabase/admin';

type GenericRpc = (
  functionName: string,
  args?: Record<string, unknown>,
) => PromiseLike<{ data: unknown; error: { message: string } | null }>;

export interface CarrierProgramSummary {
  carrierId: string;
  carrierProgramId: string;
  carrierDisplayName: string;
  programCode: string;
  programVersion: number;
  adapterId: string;
  adapterVersion: string;
  handoffMode: string;
  certificationState: string;
  killSwitchEnabled: boolean;
}

export async function listCarrierProgramsForCase(input: {
  userClient: SupabaseClient<Database>;
  workforce: WorkforceContext;
  quoteCaseId: string;
}): Promise<CarrierProgramSummary[]> {
  assertWorkforcePermission(input.workforce, 'CARRIER_SUBMIT');
  void input.userClient;

  const admin = createSupabaseAdminClient();
  const rpc = admin.rpc as unknown as GenericRpc;
  const { data, error } = await rpc('list_carrier_programs_for_case', {
    p_quote_case_id: input.quoteCaseId,
    p_tenant_id: input.workforce.tenantId,
    p_agency_id: input.workforce.agencyId,
  });
  if (error) throw new Error(error.message);

  return (Array.isArray(data) ? data : []).map((value) => {
    const row = value as Record<string, unknown>;
    return {
      carrierId: String(row.carrier_id),
      carrierProgramId: String(row.carrier_program_id),
      carrierDisplayName: String(row.carrier_display_name),
      programCode: String(row.program_code),
      programVersion: Number(row.program_version),
      adapterId: String(row.adapter_id),
      adapterVersion: String(row.adapter_version),
      handoffMode: String(row.handoff_mode),
      certificationState: String(row.certification_state),
      killSwitchEnabled: Boolean(row.kill_switch_enabled),
    };
  });
}

export async function resolveCarrierProgramContext(input: {
  userClient: SupabaseClient<Database>;
  workforce: WorkforceContext;
  quoteCaseId: string;
  carrierProgramId: string;
  idempotencyKey: string;
  traceId: string;
}): Promise<{
  context: CarrierRequestContext;
  carrierId: string;
  adapterId: string;
  adapterVersion: string;
  killSwitchEnabled: boolean;
  certificationState: string;
}> {
  assertWorkforcePermission(input.workforce, 'CARRIER_SUBMIT');
  void input.userClient;

  const admin = createSupabaseAdminClient();
  const rpc = admin.rpc as unknown as GenericRpc;
  const { data, error } = await rpc('resolve_carrier_program_context', {
    p_quote_case_id: input.quoteCaseId,
    p_tenant_id: input.workforce.tenantId,
    p_agency_id: input.workforce.agencyId,
    p_carrier_program_id: input.carrierProgramId,
  });
  if (error) throw new Error(error.message);
  const row = Array.isArray(data) ? data[0] : null;
  if (!row || typeof row !== 'object') throw new Error('CARRIER_CONTEXT_NOT_RESOLVED');
  const resolved = row as Record<string, unknown>;

  if (Boolean(resolved.kill_switch_enabled)) throw new Error('CARRIER_KILL_SWITCHED');
  if (!['SYNTHETIC', 'SANDBOX', 'CERTIFIED'].includes(String(resolved.certification_state))) {
    throw new Error('CARRIER_NOT_CERTIFIED');
  }

  return {
    context: {
      quoteCaseId: input.quoteCaseId,
      tenantId: input.workforce.tenantId,
      agencyId: input.workforce.agencyId,
      tenantConfigurationVersion: String(resolved.tenant_configuration_version),
      carrierProgramId: String(resolved.carrier_program_id),
      carrierProgramVersion: String(resolved.carrier_program_version),
      traceId: input.traceId,
      idempotencyKey: input.idempotencyKey,
    },
    carrierId: String(resolved.carrier_id),
    adapterId: String(resolved.adapter_id),
    adapterVersion: String(resolved.adapter_version),
    killSwitchEnabled: Boolean(resolved.kill_switch_enabled),
    certificationState: String(resolved.certification_state),
  };
}
