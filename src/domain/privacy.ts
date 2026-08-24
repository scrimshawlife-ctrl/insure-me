export type PrivacyRequestType =
  | 'ACCESS'
  | 'CORRECTION'
  | 'DELETION'
  | 'RESTRICTION'
  | 'OPT_OUT';

export type PrivacyRequestState =
  | 'RECEIVED'
  | 'IDENTITY_VERIFICATION_PENDING'
  | 'IDENTITY_VERIFIED'
  | 'APPLICABILITY_REVIEW'
  | 'IN_PROGRESS'
  | 'COMPLETED'
  | 'DENIED'
  | 'CANCELLED';

export type PrivacyIdentityState =
  | 'NOT_STARTED'
  | 'PENDING'
  | 'VERIFIED'
  | 'FAILED'
  | 'EXPIRED';

export type PrivacyIdentityVerificationOutcome = 'VERIFIED' | 'FAILED';

export type PrivacyDiscoveryOutcome = 'MATCHED' | 'NO_MATCH' | 'AMBIGUOUS';

export type PrivacyRightsExecutionOutcome =
  | 'APPLIED'
  | 'PARTIALLY_APPLIED'
  | 'NO_RECORDS';

export interface PrivacyRightsExecutionPolicyDescriptor {
  policyVersion: string;
  certificationState: 'SYNTHETIC' | 'APPROVED';
}

export interface PrivacyExportPolicyDescriptor {
  policyVersion: string;
  exportSchemaVersion: string;
  certificationState: 'SYNTHETIC' | 'APPROVED';
}

export interface PrivacyIdentityVerifierDescriptor {
  adapterId: string;
  adapterVersion: string;
  policyVersion: string;
  certificationState: 'SYNTHETIC' | 'CERTIFIED';
}

export interface PrivacyIdentityVerificationResult {
  outcome: PrivacyIdentityVerificationOutcome;
  evidenceRef: string;
  reasonCodes: string[];
}

export interface PrivacyIdentityVerifier {
  descriptor(): PrivacyIdentityVerifierDescriptor;
  verify(input: {
    privacyRequestId: string;
    assertion: string;
  }): Promise<PrivacyIdentityVerificationResult>;
}

export interface PrivacyRequest {
  privacyRequestId: string;
  publicReference: string;
  tenantId: string;
  agencyId: string;
  requestType: PrivacyRequestType;
  state: PrivacyRequestState;
  identityVerificationState: PrivacyIdentityState;
  jurisdiction: 'CA';
  policyVersionRefs: string[];
  receivedAt: string;
  dueAt?: string;
  completedAt?: string;
}

export type RetentionDisposition = 'DELETE' | 'ANONYMIZE' | 'REVIEW';

export type RetentionPolicyCertificationState =
  | 'DRAFT'
  | 'SYNTHETIC'
  | 'APPROVED'
  | 'SUSPENDED'
  | 'RETIRED';

export interface RetentionPolicy {
  retentionPolicyId: string;
  tenantId: string;
  agencyId: string;
  policySetId: string;
  version: number;
  dataClass: string;
  jurisdiction: 'CA';
  providerContractRef?: string;
  carrierProgramRef?: string;
  tenantRole: string;
  retentionSeconds?: number;
  disposition: RetentionDisposition;
  legalHoldBlocksDestructiveDisposition: true;
  certificationState: RetentionPolicyCertificationState;
  legalAuthorityRefs: string[];
  contractAuthorityRefs: string[];
  effectiveAt?: string;
  retiredAt?: string;
}

export function requesterSafePrivacyStatus(
  request: Pick<PrivacyRequest, 'publicReference' | 'state' | 'identityVerificationState'>,
): Pick<PrivacyRequest, 'publicReference' | 'state' | 'identityVerificationState'> {
  return {
    publicReference: request.publicReference,
    state: request.state,
    identityVerificationState: request.identityVerificationState,
  };
}

export function assertRetentionPolicyActivatable(
  policy: Pick<
    RetentionPolicy,
    | 'certificationState'
    | 'retentionSeconds'
    | 'legalAuthorityRefs'
    | 'contractAuthorityRefs'
    | 'effectiveAt'
    | 'legalHoldBlocksDestructiveDisposition'
  >,
): void {
  if (policy.certificationState !== 'APPROVED') return;

  if (
    !policy.retentionSeconds ||
    policy.retentionSeconds <= 0 ||
    !policy.effectiveAt ||
    !policy.legalHoldBlocksDestructiveDisposition ||
    policy.legalAuthorityRefs.length + policy.contractAuthorityRefs.length === 0
  ) {
    throw new Error('RETENTION_POLICY_APPROVAL_EVIDENCE_REQUIRED');
  }
}
