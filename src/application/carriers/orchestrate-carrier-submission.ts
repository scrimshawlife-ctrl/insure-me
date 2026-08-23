import type {
  CarrierAdapter,
  CarrierRequestContext,
  CarrierSubmissionResult,
  RatingInputItem,
} from '@/src/domain/carriers';

export interface CarrierSubmissionPersistence {
  selectCarrierProgram(input: {
    quoteCaseId: string;
    carrierProgramId: string;
  }): Promise<void>;
  projectRatingInputs(input: {
    quoteCaseId: string;
    carrierProgramId: string;
  }): Promise<number>;
  getRatingInputs(input: {
    quoteCaseId: string;
    carrierProgramId: string;
  }): Promise<RatingInputItem[]>;
  createCarrierSubmission(input: {
    quoteCaseId: string;
    carrierProgramId: string;
    idempotencyKey: string;
    requestHash: string;
  }): Promise<{ carrierSubmissionId: string; reused: boolean }>;
  claimCarrierSubmission(input: { carrierSubmissionId: string }): Promise<void>;
  getCarrierSubmissionResult(input: {
    carrierSubmissionId: string;
  }): Promise<{
    submissionStatus: 'PENDING' | 'RUNNING' | 'SUCCEEDED' | 'FAILED' | 'BLOCKED';
    result: CarrierSubmissionResult | null;
  } | null>;
  settleCarrierSubmission(input: {
    carrierSubmissionId: string;
    result: CarrierSubmissionResult;
  }): Promise<void>;
  markCarrierSubmissionFailed(input: {
    carrierSubmissionId: string;
    reasonCode: string;
  }): Promise<void>;
}

function stableRatingInputHash(inputs: RatingInputItem[]): string {
  const canonical = [...inputs]
    .sort((left, right) => left.inputKey.localeCompare(right.inputKey))
    .map((item) => [item.ratingInputId, item.inputKey, item.approvedValue, item.dataUsePolicyVersion, item.mappingVersion]);
  const stable = JSON.stringify(canonical);
  let hash = 2166136261;
  for (let index = 0; index < stable.length; index += 1) {
    hash ^= stable.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return `fnv1a32:${(hash >>> 0).toString(16).padStart(8, '0')}`;
}

function errorCode(error: unknown): string {
  if (error instanceof Error && error.message) {
    return error.message.slice(0, 120).replace(/[^A-Z0-9_:-]/gi, '_').toUpperCase();
  }
  return 'CARRIER_EXECUTION_FAILED';
}

export async function orchestrateCarrierSubmission(input: {
  adapter: CarrierAdapter;
  persistence: CarrierSubmissionPersistence;
  context: CarrierRequestContext;
}): Promise<CarrierSubmissionResult> {
  const descriptor = input.adapter.descriptor();
  if (descriptor.carrierProgramId !== input.context.carrierProgramId) {
    throw new Error('CARRIER_PROGRAM_MISMATCH');
  }
  if (!descriptor.jurisdictions.includes('CA') || !descriptor.productLines.includes('PRIVATE_PASSENGER_AUTO')) {
    throw new Error('CARRIER_CAPABILITY_NOT_ALLOWED');
  }
  if (!['SYNTHETIC', 'SANDBOX', 'CERTIFIED'].includes(descriptor.certificationState)) {
    throw new Error('CARRIER_NOT_CERTIFIED');
  }

  await input.persistence.selectCarrierProgram({
    quoteCaseId: input.context.quoteCaseId,
    carrierProgramId: input.context.carrierProgramId,
  });
  await input.persistence.projectRatingInputs({
    quoteCaseId: input.context.quoteCaseId,
    carrierProgramId: input.context.carrierProgramId,
  });

  const ratingInputs = await input.persistence.getRatingInputs({
    quoteCaseId: input.context.quoteCaseId,
    carrierProgramId: input.context.carrierProgramId,
  });
  const validation = await input.adapter.validateSubmission(input.context, { ratingInputs });
  if (!validation.valid) {
    throw new Error(`CARRIER_HANDOFF_BLOCKED:${validation.reasonCodes.join(',')}`);
  }

  const submission = await input.persistence.createCarrierSubmission({
    quoteCaseId: input.context.quoteCaseId,
    carrierProgramId: input.context.carrierProgramId,
    idempotencyKey: input.context.idempotencyKey,
    requestHash: stableRatingInputHash(ratingInputs),
  });

  if (submission.reused) {
    const existing = await input.persistence.getCarrierSubmissionResult({
      carrierSubmissionId: submission.carrierSubmissionId,
    });
    if (existing?.submissionStatus === 'SUCCEEDED' && existing.result) {
      return existing.result;
    }
    if (existing?.submissionStatus === 'RUNNING') {
      throw new Error('CARRIER_SUBMISSION_ALREADY_RUNNING');
    }
  }

  await input.persistence.claimCarrierSubmission({
    carrierSubmissionId: submission.carrierSubmissionId,
  });

  try {
    const result = await input.adapter.submit(input.context, { ratingInputs });
    await input.persistence.settleCarrierSubmission({
      carrierSubmissionId: submission.carrierSubmissionId,
      result,
    });
    return result;
  } catch (error) {
    await input.persistence.markCarrierSubmissionFailed({
      carrierSubmissionId: submission.carrierSubmissionId,
      reasonCode: errorCode(error),
    });
    throw error;
  }
}
