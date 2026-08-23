import { describe, expect, it } from 'vitest';

import { isMutationOriginAllowed } from '@/src/infrastructure/security/csrf';
import { serializeSecurityTelemetry } from '@/src/infrastructure/security/security-telemetry';

describe('request security baseline', () => {
  it('allows safe methods and same-origin mutations', () => {
    expect(isMutationOriginAllowed({ method: 'GET', requestOrigin: 'https://evil.test', expectedOrigin: 'https://app.test', fetchSite: 'cross-site' })).toBe(true);
    expect(isMutationOriginAllowed({ method: 'POST', requestOrigin: 'https://app.test', expectedOrigin: 'https://app.test', fetchSite: 'same-origin' })).toBe(true);
  });

  it('rejects cross-site and malformed mutation origins', () => {
    expect(isMutationOriginAllowed({ method: 'POST', requestOrigin: 'https://evil.test', expectedOrigin: 'https://app.test', fetchSite: 'cross-site' })).toBe(false);
    expect(isMutationOriginAllowed({ method: 'PUT', requestOrigin: 'not-a-url', expectedOrigin: 'https://app.test', fetchSite: null })).toBe(false);
  });

  it('serializes only the fixed privacy-safe telemetry schema', () => {
    const event = JSON.parse(serializeSecurityTelemetry({
      eventType: 'PROVIDER_ORDER_DENIED', outcome: 'DENIED', routeCategory: 'PROVIDER_ORDER',
      tenantId: 'c0000000-0000-0000-0000-000000000001', actorId: 'c9000000-0000-0000-0000-000000000009',
      reasonCodes: ['PURPOSE_NOT_PERMITTED', 'unsafe value with spaces'],
    }));
    expect(event).toEqual({
      schemaVersion: 'security-event-v1', eventType: 'PROVIDER_ORDER_DENIED', outcome: 'DENIED', routeCategory: 'PROVIDER_ORDER',
      tenantId: 'c0000000-0000-0000-0000-000000000001', actorId: 'c9000000-0000-0000-0000-000000000009', reasonCodes: ['PURPOSE_NOT_PERMITTED'],
    });
    expect(JSON.stringify(event)).not.toContain('license');
  });
});
