import type { ProviderCapability, ProviderResultStatus } from '@/src/domain/providers';

export type ProviderCapabilityHealth = 'OPERATIONAL' | 'DEGRADED' | 'UNAVAILABLE';
export type ProviderHealthVerdict = 'ready' | 'degraded' | 'blocked';

export interface ProviderHealthAssessment {
  verdict: ProviderHealthVerdict;
  quoteCompletionBlocked: boolean;
  capabilities: Partial<Record<ProviderCapability, ProviderCapabilityHealth>>;
  reasonCodes: string[];
}

export function assessProviderHealth(input: {
  statuses: Partial<Record<ProviderCapability, ProviderResultStatus>>;
  requiredCapabilities: ProviderCapability[];
}): ProviderHealthAssessment {
  const capabilities: ProviderHealthAssessment['capabilities'] = {};
  const reasonCodes: string[] = [];

  for (const capability of input.requiredCapabilities) {
    const status = input.statuses[capability];
    if (status === 'ERROR' || status === undefined) {
      capabilities[capability] = 'UNAVAILABLE';
      reasonCodes.push(`${capability}_PROVIDER_UNAVAILABLE`);
    } else if (status === 'PARTIAL' || status === 'STALE') {
      capabilities[capability] = 'DEGRADED';
      reasonCodes.push(`${capability}_PROVIDER_DEGRADED`);
    } else {
      capabilities[capability] = 'OPERATIONAL';
    }
  }

  const values = Object.values(capabilities);
  const quoteCompletionBlocked = values.includes('UNAVAILABLE');
  return {
    verdict: quoteCompletionBlocked
      ? 'blocked'
      : values.includes('DEGRADED')
        ? 'degraded'
        : 'ready',
    quoteCompletionBlocked,
    capabilities,
    reasonCodes,
  };
}
