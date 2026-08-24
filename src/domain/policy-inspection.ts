export interface DataUsePolicyRule {
  dataUsePolicyRuleId: string;
  policyVersion: string;
  observationType: string;
  collectionAllowed: boolean;
  agentDisplayAllowed: boolean;
  underwritingAllowed: boolean;
  ratingSubmissionAllowed: boolean;
  carrierOnly: boolean;
  prohibited: boolean;
  effectiveAt: string;
  retiredAt: string | null;
  createdAt: string;
}

export type RetentionDisposition = 'DELETE' | 'ANONYMIZE' | 'REVIEW';
export type RetentionCertificationState = 'DRAFT' | 'SYNTHETIC' | 'APPROVED' | 'SUSPENDED' | 'RETIRED';

export interface RetentionPolicyVersion {
  retentionPolicyId: string;
  policySetId: string;
  version: number;
  dataClass: string;
  jurisdiction: 'CA';
  providerContractRef: string | null;
  carrierProgramRef: string | null;
  tenantRole: string;
  retentionInterval: string | null;
  disposition: RetentionDisposition;
  legalHoldBlocksDestructiveDisposition: boolean;
  certificationState: RetentionCertificationState;
  legalAuthorityRefs: string[];
  contractAuthorityRefs: string[];
  effectiveAt: string | null;
  retiredAt: string | null;
  createdAt: string;
}
