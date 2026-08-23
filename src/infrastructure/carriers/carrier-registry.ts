import type { CarrierAdapter } from '@/src/domain/carriers';
import { SyntheticCarrierAdapter } from '@/src/infrastructure/carriers/synthetic-carrier';
import { assertAdapterAllowedForDeployment } from '@/src/infrastructure/config/deployment';

export function resolveCarrierAdapter(input: {
  carrierId: string;
  carrierProgramId: string;
  adapterId: string;
  adapterVersion: string;
}): CarrierAdapter {
  assertAdapterAllowedForDeployment(input.adapterId);

  const variant = input.adapterId.endsWith('-a')
    ? 'A'
    : input.adapterId.endsWith('-b')
      ? 'B'
      : null;

  if (!variant || input.adapterVersion !== 'synthetic-carrier-v1') {
    throw new Error('CARRIER_ADAPTER_NOT_REGISTERED');
  }

  return new SyntheticCarrierAdapter(variant, {
    carrierId: input.carrierId,
    carrierProgramId: input.carrierProgramId,
    adapterId: input.adapterId,
    adapterVersion: input.adapterVersion,
  });
}
