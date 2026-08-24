import type { ProviderCapability, ProviderResultStatus } from '@/src/domain/providers';

export type ProviderCapabilityHealth = 'OPERATIONAL' | 'DEGRADED' | 'UNAVAILABLE';
export type ProviderHealthVerdict = 'ready' | 'degraded' | 'blocked';

export interface ProviderHealthAssessment {
  verdict: ProviderHealthVerdict;
  quoteCompletionBlocked: boolean;
  capabilities: Partial<Record<ProviderCapability, ProviderCapabilityHealth>>;
  reasonCodes: string[];
}

export interface ProviderHealthSnapshot {
  observedAt: string;
  requiredCapabilities: ProviderCapability[];
  statuses: Partial<Record<ProviderCapability, ProviderResultStatus>>;
}

const providerCapabilities: ProviderCapability[] = ['IDENTITY', 'PREFILL', 'MVR', 'CLAIMS', 'VEHICLE'];

export function readProviderHealthSnapshot(
  source: Record<string, string | undefined> = process.env,
  now: Date = new Date(),
): ProviderHealthAssessment | null {
  const value = source.PROVIDER_HEALTH_SNAPSHOT_JSON;
  if (!value) return null;

  let snapshot: ProviderHealthSnapshot;
  try {
    snapshot = JSON.parse(value) as ProviderHealthSnapshot;
  } catch {
    throw new Error('PROVIDER_HEALTH_SNAPSHOT_INVALID');
  }

  const observedAt = Date.parse(snapshot.observedAt);
  if (!Number.isFinite(observedAt) || Math.abs(now.getTime() - observedAt) > 5 * 60 * 1000) {
    throw new Error('PROVIDER_HEALTH_SNAPSHOT_STALE');
  }
  if (!Array.isArray(snapshot.requiredCapabilities) || snapshot.requiredCapabilities.length === 0
    || snapshot.requiredCapabilities.some((item) => !providerCapabilities.includes(item))) {
    throw new Error('PROVIDER_HEALTH_SNAPSHOT_INVALID');
  }

  return assessProviderHealth(snapshot);
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
