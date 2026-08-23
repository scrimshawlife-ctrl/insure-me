import type { ProviderCapability } from '@/src/domain/providers';
import {
  SyntheticProviderAdapter,
  type SyntheticProviderNormalized,
  type SyntheticProviderRequest,
} from '@/src/infrastructure/providers/synthetic-provider';

export function resolveProviderAdapter(input: {
  adapterId: string;
  adapterVersion: string;
  capability: ProviderCapability;
}): SyntheticProviderAdapter {
  const expectedId = `synthetic-${input.capability.toLowerCase()}`;
  if (input.adapterId !== expectedId || input.adapterVersion !== 'synthetic-provider-v1') {
    throw new Error('PROVIDER_ADAPTER_NOT_REGISTERED');
  }
  return new SyntheticProviderAdapter(input.capability);
}

export type RegisteredProviderRequest = SyntheticProviderRequest;
export type RegisteredProviderNormalized = SyntheticProviderNormalized;
