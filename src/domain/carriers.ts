export type CarrierMode =
  | 'STUB'
  | 'API'
  | 'DEEPLINK'
  | 'AMS_BRIDGE'
  | 'STRUCTURED_EXPORT'
  | 'MANUAL';

export type CarrierCertificationState =
  | 'SYNTHETIC'
  | 'SANDBOX'
  | 'CERTIFIED'
  | 'SUSPENDED'
  | 'RETIRED';

export interface CarrierCapabilityDescriptor {
  carrierId: string;
  carrierProgramId: string;
  adapterId: string;
  adapterVersion: string;
  mode: CarrierMode;
  jurisdictions: string[];
  productLines: string[];
  requiredFieldPolicyVersion: string;
  ratingInputPolicyVersion: string;
  responseMappingVersion: string;
  supportsAsyncStatus: boolean;
  certificationState: CarrierCertificationState;
}

export interface CarrierRequestContext {
  quoteCaseId: string;
  tenantId: string;
  agencyId: string;
  tenantConfigurationVersion: string;
  carrierProgramId: string;
  carrierProgramVersion: string;
  traceId: string;
  idempotencyKey: string;
}

export interface RatingInputItem {
  ratingInputId: string;
  inputKey: string;
  approvedValue: unknown;
  dataUsePolicyVersion: string;
  mappingVersion: string;
}

export interface CarrierSubmissionInput {
  ratingInputs: RatingInputItem[];
}

export interface ValidationResult {
  valid: boolean;
  reasonCodes: string[];
}

export interface CarrierSubmissionResult {
  status: 'ACCEPTED' | 'DECLINED' | 'REFERRED' | 'ERROR';
  externalReference?: string;
  premium?: {
    amount: number;
    currency: 'USD';
    termMonths: number;
  };
  reasonCodes: string[];
  receivedAt: string;
}

export interface CarrierAdapter {
  descriptor(): CarrierCapabilityDescriptor;
  validateSubmission(
    context: CarrierRequestContext,
    input: CarrierSubmissionInput,
  ): Promise<ValidationResult>;
  submit(
    context: CarrierRequestContext,
    input: CarrierSubmissionInput,
  ): Promise<CarrierSubmissionResult>;
  getStatus?(
    context: CarrierRequestContext,
    externalReference: string,
  ): Promise<CarrierSubmissionResult>;
}
