import { describe, expect, it } from 'vitest';
import { assessProviderHealth } from './provider-health';

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
});
