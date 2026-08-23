import type {
  CarrierAdapter,
  CarrierCapabilityDescriptor,
  CarrierRequestContext,
  CarrierSubmissionInput,
  CarrierSubmissionResult,
  ValidationResult,
} from '@/src/domain/carriers';

type SyntheticCarrierVariant = 'A' | 'B';

const REQUIRED_KEYS: Record<SyntheticCarrierVariant, string[]> = {
  A: ['mvr.licenseStatus', 'claims.claimCount'],
  B: ['mvr.movingViolationCount', 'vehicle.severeDamageIndicator'],
};

export interface SyntheticCarrierBinding {
  carrierId?: string;
  carrierProgramId?: string;
  adapterId?: string;
  adapterVersion?: string;
}

export class SyntheticCarrierAdapter implements CarrierAdapter {
  public constructor(
    private readonly variant: SyntheticCarrierVariant,
    private readonly binding: SyntheticCarrierBinding = {},
  ) {}

  public descriptor(): CarrierCapabilityDescriptor {
    return {
      carrierId:
        this.binding.carrierId ?? `synthetic-carrier-${this.variant.toLowerCase()}`,
      carrierProgramId:
        this.binding.carrierProgramId ?? `synthetic-program-${this.variant.toLowerCase()}`,
      adapterId:
        this.binding.adapterId ?? `synthetic-carrier-adapter-${this.variant.toLowerCase()}`,
      adapterVersion: this.binding.adapterVersion ?? 'synthetic-carrier-v1',
      mode: 'STUB',
      jurisdictions: ['CA'],
      productLines: ['PRIVATE_PASSENGER_AUTO'],
      requiredFieldPolicyVersion: `synthetic-required-${this.variant.toLowerCase()}-v1`,
      ratingInputPolicyVersion: `synthetic-rating-${this.variant.toLowerCase()}-v1`,
      responseMappingVersion: `synthetic-response-${this.variant.toLowerCase()}-v1`,
      supportsAsyncStatus: false,
      certificationState: 'SYNTHETIC',
    };
  }

  public async validateSubmission(
    context: CarrierRequestContext,
    input: CarrierSubmissionInput,
  ): Promise<ValidationResult> {
    const descriptor = this.descriptor();
    if (context.carrierProgramId !== descriptor.carrierProgramId) {
      return { valid: false, reasonCodes: ['CARRIER_PROGRAM_MISMATCH'] };
    }

    const present = new Set(input.ratingInputs.map((item) => item.inputKey));
    const missing = REQUIRED_KEYS[this.variant].filter((key) => !present.has(key));
    return {
      valid: missing.length === 0,
      reasonCodes: missing.map((key) => `MISSING_REQUIRED_INPUT:${key}`),
    };
  }

  public async submit(
    context: CarrierRequestContext,
    input: CarrierSubmissionInput,
  ): Promise<CarrierSubmissionResult> {
    const validation = await this.validateSubmission(context, input);
    if (!validation.valid) {
      return {
        status: 'ERROR',
        reasonCodes: validation.reasonCodes,
        receivedAt: '2026-08-23T00:00:00.000Z',
      };
    }

    const inputFingerprint = [...input.ratingInputs]
      .sort((left, right) => left.inputKey.localeCompare(right.inputKey))
      .map((item) => `${item.inputKey}:${JSON.stringify(item.approvedValue)}`)
      .join('|');

    const premiumBase = this.variant === 'A' ? 118 : 123;
    const adjustment = inputFingerprint.length % 17;

    return {
      status: 'ACCEPTED',
      externalReference: `synthetic:${this.variant}:${context.idempotencyKey}`,
      premium: {
        amount: premiumBase + adjustment,
        currency: 'USD',
        termMonths: 6,
      },
      reasonCodes: [],
      receivedAt: '2026-08-23T00:00:00.000Z',
    };
  }
}
