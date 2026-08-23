import { describe, expect, it } from 'vitest';
import {
  assessDeploymentReadiness,
  assertAdapterAllowedForDeployment,
  requireLiveDeploymentReady,
} from '@/src/infrastructure/config/deployment';

function liveEnvironment(overrides: NodeJS.ProcessEnv = {}): NodeJS.ProcessEnv {
  return {
    DEPLOYMENT_STAGE: 'pilot',
    PUBLIC_BASE_URL: 'https://pilot.example.com',
    DEPLOYMENT_AUTHORITY_REF: 'decision:Q-001',
    LEGAL_NOTICE_APPROVAL_REF: 'legal:notices:v1',
    DATA_RETENTION_APPROVAL_REF: 'legal:retention:v1',
    FCRA_ROLE_APPROVAL_REF: 'legal:fcra:v1',
    PRIVACY_ROLE_APPROVAL_REF: 'legal:privacy:v1',
    SECURITY_REVIEW_REF: 'security:review:v1',
    INCIDENT_RESPONSE_OWNER: 'security@example.com',
    LIVE_PROVIDER_BINDINGS_VERIFIED: 'true',
    LIVE_CARRIER_PROGRAMS_VERIFIED: 'true',
    ...overrides,
  };
}

describe('deployment controls', () => {
  it('keeps synthetic mode development-ready without live approvals', () => {
    expect(assessDeploymentReadiness({ DEPLOYMENT_STAGE: 'synthetic' })).toEqual({
      stage: 'synthetic',
      ready: true,
      blockers: [],
    });
  });

  it('blocks live deployment when approval evidence is incomplete', () => {
    const readiness = assessDeploymentReadiness({ DEPLOYMENT_STAGE: 'production' });
    expect(readiness.ready).toBe(false);
    expect(readiness.blockers).toContain('MISSING_DEPLOYMENT_AUTHORITY_REF');
    expect(readiness.blockers).toContain('LIVE_PROVIDER_BINDINGS_NOT_VERIFIED');
    expect(readiness.blockers).toContain('LIVE_CARRIER_PROGRAMS_NOT_VERIFIED');
  });

  it('accepts a live stage only when every configured gate is satisfied', () => {
    expect(assessDeploymentReadiness(liveEnvironment())).toEqual({
      stage: 'pilot',
      ready: true,
      blockers: [],
    });
    expect(() => requireLiveDeploymentReady(liveEnvironment())).not.toThrow();
  });

  it('forbids synthetic adapters in pilot and production', () => {
    expect(() =>
      assertAdapterAllowedForDeployment('synthetic-mvr', liveEnvironment()),
    ).toThrow('SYNTHETIC_ADAPTER_FORBIDDEN_IN_LIVE_STAGE');
    expect(() =>
      assertAdapterAllowedForDeployment('approved-mvr-vendor', liveEnvironment()),
    ).not.toThrow();
  });
});
