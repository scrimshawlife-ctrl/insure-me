import type {
  ProviderAdapter,
  ProviderCapabilityDescriptor,
  ProviderRequestContext,
  ProviderResult,
} from '@/src/domain/providers';

export type PreflightDecision = {
  allowed: boolean;
  purposeCode: string;
  policyVersion: string;
  reasonCodes: string[];
};

export interface ProviderOrchestrationPersistence {
  createPurposeDecision(input: {
    context: ProviderRequestContext;
    purposeCode: string;
    policyVersion: string;
    allowed: boolean;
    reasonCodes: string[];
  }): Promise<{ decisionId: string }>;
  createExternalRequest(input: {
    context: ProviderRequestContext;
    requestHash: string;
    decisionId: string;
  }): Promise<{ externalRequestId: string; reused: boolean }>;
  claimExternalRequest(input: {
    externalRequestId: string;
    workerId: string;
  }): Promise<void>;
  markExternalRequestRetry(input: {
    externalRequestId: string;
    errorCode: string;
    backoffSeconds: number;
  }): Promise<void>;
  getExternalRequestResult<T>(input: {
    externalRequestId: string;
  }): Promise<{
    requestStatus: 'PENDING' | 'RUNNING' | 'SUCCEEDED' | 'FAILED' | 'BLOCKED';
    result: ProviderResult<T> | null;
  } | null>;
  settleExternalResult<T>(input: {
    context: ProviderRequestContext;
    externalRequestId: string;
    descriptor: ProviderCapabilityDescriptor;
    result: ProviderResult<T>;
  }): Promise<void>;
}

export interface ProviderPreflightPolicy {
  evaluate(input: {
    context: ProviderRequestContext;
    descriptor: ProviderCapabilityDescriptor;
  }): Promise<PreflightDecision>;
}

function stableRequestHash(value: unknown): string {
  const stable = JSON.stringify(value, Object.keys((value ?? {}) as Record<string, unknown>).sort());
  let hash = 2166136261;
  for (let index = 0; index < stable.length; index += 1) {
    hash ^= stable.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return `fnv1a32:${(hash >>> 0).toString(16).padStart(8, '0')}`;
}

function selectDescriptor<TRequest, TNormalized>(
  adapter: ProviderAdapter<TRequest, TNormalized>,
  context: ProviderRequestContext,
): ProviderCapabilityDescriptor {
  const descriptor = adapter.capabilities().find(
    (candidate) =>
      candidate.capability === context.capability &&
      candidate.jurisdictions.includes(context.jurisdiction) &&
      candidate.productLines.includes(context.productLine),
  );

  if (!descriptor) {
    throw new Error('PROVIDER_CAPABILITY_NOT_CONFIGURED');
  }

  return descriptor;
}

function errorCode(error: unknown): string {
  if (error instanceof Error && error.message) {
    return error.message.slice(0, 120).replace(/[^A-Z0-9_:-]/gi, '_').toUpperCase();
  }
  return 'PROVIDER_EXECUTION_FAILED';
}

export async function orchestrateProviderRequest<TRequest, TNormalized>(input: {
  adapter: ProviderAdapter<TRequest, TNormalized>;
  persistence: ProviderOrchestrationPersistence;
  policy: ProviderPreflightPolicy;
  context: ProviderRequestContext;
  request: TRequest;
}): Promise<ProviderResult<TNormalized>> {
  const descriptor = selectDescriptor(input.adapter, input.context);
  const preflight = await input.policy.evaluate({
    context: input.context,
    descriptor,
  });

  const purposeDecision = await input.persistence.createPurposeDecision({
    context: input.context,
    purposeCode: preflight.purposeCode,
    policyVersion: preflight.policyVersion,
    allowed: preflight.allowed,
    reasonCodes: preflight.reasonCodes,
  });

  if (!preflight.allowed) {
    throw new Error(`PROVIDER_REQUEST_BLOCKED:${preflight.reasonCodes.join(',')}`);
  }

  const externalRequest = await input.persistence.createExternalRequest({
    context: {
      ...input.context,
      permissiblePurposeDecisionId: purposeDecision.decisionId,
    },
    requestHash: stableRequestHash(input.request),
    decisionId: purposeDecision.decisionId,
  });

  if (externalRequest.reused) {
    const existing = await input.persistence.getExternalRequestResult<TNormalized>({
      externalRequestId: externalRequest.externalRequestId,
    });
    if (existing?.requestStatus === 'SUCCEEDED' && existing.result) {
      return existing.result;
    }
    if (existing?.requestStatus === 'RUNNING') {
      throw new Error('PROVIDER_REQUEST_ALREADY_RUNNING');
    }
  }

  await input.adapter.validate(
    { ...input.context, permissiblePurposeDecisionId: purposeDecision.decisionId },
    input.request,
  );

  await input.persistence.claimExternalRequest({
    externalRequestId: externalRequest.externalRequestId,
    workerId: `provider:${input.context.traceId}`,
  });

  try {
    const executionContext = {
      ...input.context,
      permissiblePurposeDecisionId: purposeDecision.decisionId,
    };
    const result = await input.adapter.execute(executionContext, input.request);

    if (result.status === 'ERROR') {
      await input.persistence.markExternalRequestRetry({
        externalRequestId: externalRequest.externalRequestId,
        errorCode: errorCode(result.warnings[0] ?? 'PROVIDER_UNAVAILABLE'),
        backoffSeconds: 60,
      });
      return result;
    }

    await input.persistence.settleExternalResult({
      context: executionContext,
      externalRequestId: externalRequest.externalRequestId,
      descriptor,
      result,
    });

    return result;
  } catch (error) {
    await input.persistence.markExternalRequestRetry({
      externalRequestId: externalRequest.externalRequestId,
      errorCode: errorCode(error),
      backoffSeconds: 60,
    });
    throw error;
  }
}
