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

  await input.adapter.validate(input.context, input.request);
  const result = await input.adapter.execute(input.context, input.request);

  await input.persistence.settleExternalResult({
    context: input.context,
    externalRequestId: externalRequest.externalRequestId,
    descriptor,
    result,
  });

  return result;
}
