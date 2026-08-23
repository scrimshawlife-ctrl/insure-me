import { describe, expect, it } from 'vitest';
import {
  assertRetentionPolicyActivatable,
  requesterSafePrivacyStatus,
  type PrivacyRequest,
  type RetentionPolicy,
} from '@/src/domain/privacy';

const syntheticPolicy: RetentionPolicy = {
  retentionPolicyId: 'rp_synthetic',
  tenantId: 'tenant_synthetic',
  agencyId: 'agency_synthetic',
  policySetId: 'synthetic-policy-set',
  version: 1,
  dataClass: 'QUOTE_CASE',
  jurisdiction: 'CA',
  tenantRole: 'CONTROLLER',
  disposition: 'REVIEW',
  legalHoldBlocksDestructiveDisposition: true,
  certificationState: 'SYNTHETIC',
  legalAuthorityRefs: [],
  contractAuthorityRefs: [],
};

describe('privacy and retention domain kernel', () => {
  it('returns requester-safe status without subject or case linkage', () => {
    const request: PrivacyRequest = {
      privacyRequestId: 'internal-request-id',
      publicReference: 'opaque-public-reference',
      tenantId: 'tenant-synthetic',
      agencyId: 'agency-synthetic',
      requestType: 'DELETION',
      state: 'IDENTITY_VERIFICATION_PENDING',
      identityVerificationState: 'PENDING',
      jurisdiction: 'CA',
      policyVersionRefs: [],
      receivedAt: '2026-08-23T00:00:00.000Z',
    };

    expect(requesterSafePrivacyStatus(request)).toEqual({
      publicReference: 'opaque-public-reference',
      state: 'IDENTITY_VERIFICATION_PENDING',
      identityVerificationState: 'PENDING',
    });
  });

  it('allows unapproved synthetic policies to omit unresolved legal durations', () => {
    expect(() => assertRetentionPolicyActivatable(syntheticPolicy)).not.toThrow();
  });

  it('rejects approved policies without duration, authority, and effective date evidence', () => {
    expect(() =>
      assertRetentionPolicyActivatable({
        ...syntheticPolicy,
        certificationState: 'APPROVED',
      }),
    ).toThrow('RETENTION_POLICY_APPROVAL_EVIDENCE_REQUIRED');
  });

  it('accepts a fully evidenced approved policy', () => {
    expect(() =>
      assertRetentionPolicyActivatable({
        ...syntheticPolicy,
        certificationState: 'APPROVED',
        retentionSeconds: 3600,
        legalAuthorityRefs: ['legal-review-v1'],
        effectiveAt: '2026-08-23T00:00:00.000Z',
      }),
    ).not.toThrow();
  });
});

