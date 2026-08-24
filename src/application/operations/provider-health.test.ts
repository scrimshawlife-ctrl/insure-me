import { describe, expect, it } from 'vitest';
import { assessProviderHealth, readProviderHealthSnapshot } from './provider-health';

describe('assessProviderHealth', () => {
  it('blocks overall health when a required capability is unavailable', () => {
    expect(assessProviderHealth({ statuses: { MVR: 'ERROR' }, requiredCapabilities: ['MVR'] }))
      .toEqual({
        verdict: 'blocked',
        quoteCompletionBlocked: true,
        capabilities: { MVR: 'UNAVAILABLE' },
        reasonCodes: ['MVR_PROVIDER_UNAVAILABLE'],
      });
  });

  it('distinguishes degraded from unavailable and healthy capability state', () => {
    expect(assessProviderHealth({
      statuses: { MVR: 'SUCCESS', CLAIMS: 'PARTIAL' },
      requiredCapabilities: ['MVR', 'CLAIMS'],
    })).toMatchObject({
      verdict: 'degraded',
      quoteCompletionBlocked: false,
      capabilities: { MVR: 'OPERATIONAL', CLAIMS: 'DEGRADED' },
    });
  });

  it('reads a fresh monitoring snapshot and rejects stale evidence', () => {
    const now = new Date('2026-08-24T00:00:00.000Z');
    const snapshot = JSON.stringify({
      observedAt: now.toISOString(), requiredCapabilities: ['MVR'], statuses: { MVR: 'ERROR' },
    });
    expect(readProviderHealthSnapshot({ PROVIDER_HEALTH_SNAPSHOT_JSON: snapshot }, now)?.verdict)
      .toBe('blocked');
    expect(() => readProviderHealthSnapshot({
      PROVIDER_HEALTH_SNAPSHOT_JSON: JSON.stringify({
        observedAt: '2026-08-23T23:00:00.000Z', requiredCapabilities: ['MVR'], statuses: { MVR: 'SUCCESS' },
      }),
    }, now)).toThrow('PROVIDER_HEALTH_SNAPSHOT_STALE');
  });
});
