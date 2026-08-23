import type {
  ProviderCapabilityDescriptor,
  ProviderRequestContext,
} from '@/src/domain/providers';
import type {
  PreflightDecision,
  ProviderPreflightPolicy,
} from '@/src/application/providers/orchestrate-provider-request';
import { createSupabaseAdminClient } from '@/src/infrastructure/supabase/admin';

interface ConsentEvidenceRow {
  consent_record_id: string;
  category:
    | 'INSURANCE_PRIVACY'
    | 'CONSUMER_REPORT_DISCLOSURE'
    | 'REPORT_AUTHORIZATION'
    | 'ELECTRONIC_COMMUNICATIONS'
    | 'NOTICE_AT_COLLECTION'
    | 'SMS_TRANSACTIONAL'
    | 'MARKETING_OPTIONAL';
  action_type: 'ACKNOWLEDGE' | 'AUTHORIZE' | 'DECLINE' | 'WITHDRAW' | 'OPT_IN' | 'OPT_OUT';
}

type GenericRpc = (
  functionName: string,
  args?: Record<string, unknown>,
) => PromiseLike<{ data: unknown; error: { message: string } | null }>;

export class SupabaseProviderPreflightPolicy implements ProviderPreflightPolicy {
  public constructor(
    private readonly configured: {
      adapterId: string;
      adapterVersion: string;
      purposeCode: string;
      requiresReportAuthorization: boolean;
    },
  ) {}

  public async evaluate(input: {
    context: ProviderRequestContext;
    descriptor: ProviderCapabilityDescriptor;
  }): Promise<PreflightDecision> {
    const reasonCodes: string[] = [];

    if (input.descriptor.adapterId !== this.configured.adapterId) {
      reasonCodes.push('PROVIDER_ADAPTER_BINDING_MISMATCH');
    }
    if (input.descriptor.adapterVersion !== this.configured.adapterVersion) {
      reasonCodes.push('PROVIDER_ADAPTER_VERSION_MISMATCH');
    }
    if (!input.descriptor.contractualPurposeCodes.includes(this.configured.purposeCode)) {
      reasonCodes.push('PROVIDER_PURPOSE_NOT_CONTRACTUALLY_ALLOWED');
    }

    if (
      ['MVR', 'CLAIMS', 'VEHICLE'].includes(input.context.capability) &&
      input.context.subjectIds.length === 0
    ) {
      reasonCodes.push('PROVIDER_SUBJECT_REQUIRED');
    }

    const admin = createSupabaseAdminClient();
    const rpc = admin.rpc as unknown as GenericRpc;
    const { data, error } = await rpc('get_provider_consent_categories', {
      p_quote_case_id: input.context.quoteCaseId,
      p_tenant_id: input.context.tenantId,
      p_agency_id: input.context.agencyId,
      p_consent_record_ids: input.context.consentRecordIds,
    });
    if (error) throw new Error(error.message);

    const rows = (Array.isArray(data) ? data : []) as ConsentEvidenceRow[];
    const acknowledgedCategories = new Set(
      rows
        .filter((row) => row.action_type === 'ACKNOWLEDGE' || row.action_type === 'AUTHORIZE')
        .map((row) => row.category),
    );

    for (const category of input.descriptor.requiredNoticeCategories) {
      if (!acknowledgedCategories.has(category as ConsentEvidenceRow['category'])) {
        reasonCodes.push(`MISSING_REQUIRED_NOTICE:${category}`);
      }
    }

    if (
      this.configured.requiresReportAuthorization &&
      !rows.some(
        (row) => row.category === 'REPORT_AUTHORIZATION' && row.action_type === 'AUTHORIZE',
      )
    ) {
      reasonCodes.push('MISSING_REQUIRED_AUTHORIZATION');
    }

    return {
      allowed: reasonCodes.length === 0,
      purposeCode: this.configured.purposeCode,
      policyVersion: 'provider-preflight-v1',
      reasonCodes,
    };
  }
}
