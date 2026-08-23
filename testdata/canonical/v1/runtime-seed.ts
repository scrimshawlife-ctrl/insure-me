import { createHash } from 'node:crypto';
import type { CanonicalSyntheticDataset } from './schema';

const UUID_NAMESPACE = '3c1d5bc7-17b0-4d3f-b641-4be6dc1f6f35';
const VIN_ALPHABET = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789';

type SourceTenant = CanonicalSyntheticDataset['tenant'];
type SourceQuoteCase = CanonicalSyntheticDataset['quoteCase'];
type SourceConsumer = CanonicalSyntheticDataset['consumer'];
type SourceDriver = CanonicalSyntheticDataset['drivers'][number];
type SourceVehicle = CanonicalSyntheticDataset['vehicles'][number];
type SourceProviderRequest = CanonicalSyntheticDataset['providerRequests'][number];
type SourceCarrier = CanonicalSyntheticDataset['carrier'];

export interface RuntimeSeedDataset extends Omit<CanonicalSyntheticDataset, 'tenant' | 'quoteCase' | 'consumer' | 'drivers' | 'vehicles' | 'providerRequests' | 'carrier'> {
  tenant: Omit<SourceTenant, 'tenantId' | 'agencyId' | 'configurationVersion'> & {
    tenantId: string;
    agencyId: string;
    tenantConfigurationId: string;
    configurationVersion: number;
  };
  quoteCase: Omit<SourceQuoteCase, 'quoteCaseId'> & {
    quoteCaseId: string;
    prospectId: string;
  };
  consumer: SourceConsumer & {
    personId: string;
    subjectId: string;
  };
  drivers: Array<SourceDriver & {
    driverId: string;
    personId: string;
    subjectId: string;
  }>;
  vehicles: Array<SourceVehicle & {
    vehicleId: string;
    vin: string;
  }>;
  providerRequests: Array<Omit<SourceProviderRequest, 'subjectIds'> & {
    subjectIds: string[];
  }>;
  carrier: SourceCarrier & {
    carrierId: string;
    carrierProgramId: string;
  };
}

export function materializeRuntimeSeed(dataset: CanonicalSyntheticDataset): RuntimeSeedDataset {
  const semanticSubjectToUuid = new Map<string, string>();
  const materializeSubject = (semantic: string) => {
    const existing = semanticSubjectToUuid.get(semantic);
    if (existing) return existing;
    const value = uuidV5(`subject:${semantic}`);
    semanticSubjectToUuid.set(semantic, value);
    return value;
  };

  return {
    ...dataset,
    tenant: {
      ...dataset.tenant,
      tenantId: uuidV5(`tenant:${dataset.tenant.tenantId}`),
      agencyId: uuidV5(`agency:${dataset.tenant.agencyId}`),
      tenantConfigurationId: uuidV5(`tenant-configuration:${dataset.tenant.configurationVersion}`),
      configurationVersion: parseConfigurationVersion(dataset.tenant.configurationVersion),
    },
    quoteCase: {
      ...dataset.quoteCase,
      quoteCaseId: uuidV5(`quote-case:${dataset.quoteCase.quoteCaseId}`),
      prospectId: uuidV5(`prospect:${dataset.quoteCase.quoteCaseId}`),
    },
    consumer: {
      ...dataset.consumer,
      personId: materializeSubject(dataset.consumer.subjectId),
      subjectId: materializeSubject(dataset.consumer.subjectId),
    },
    drivers: dataset.drivers.map((driver) => ({
      ...driver,
      driverId: uuidV5(`driver:${driver.driverId}`),
      personId: materializeSubject(driver.subjectId),
      subjectId: materializeSubject(driver.subjectId),
    })),
    vehicles: dataset.vehicles.map((vehicle) => ({
      ...vehicle,
      vehicleId: uuidV5(`vehicle:${vehicle.vehicleId}`),
      vin: syntheticVin(vehicle.vehicleId),
    })),
    providerRequests: dataset.providerRequests.map((request) => ({
      ...request,
      subjectIds: request.subjectIds.map((subjectId) =>
        subjectId.startsWith('vehicle-')
          ? uuidV5(`vehicle:${subjectId}`)
          : materializeSubject(subjectId),
      ),
    })),
    carrier: {
      ...dataset.carrier,
      carrierId: uuidV5(`carrier:${dataset.carrier.variant}`),
      carrierProgramId: uuidV5(`carrier-program:${dataset.carrier.carrierProgramId}`),
    },
  };
}

export function uuidV5(name: string): string {
  const namespace = uuidToBytes(UUID_NAMESPACE);
  const digest = createHash('sha1').update(namespace).update(name, 'utf8').digest();
  const bytes = Uint8Array.from(digest.subarray(0, 16));
  bytes[6] = (bytes[6]! & 0x0f) | 0x50;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  return bytesToUuid(bytes);
}

export function syntheticVin(seed: string): string {
  const digest = createHash('sha256').update(`vin:${seed}`, 'utf8').digest();
  let vin = '1';
  for (let index = 0; vin.length < 17; index += 1) {
    vin += VIN_ALPHABET[digest[index % digest.length]! % VIN_ALPHABET.length];
  }
  return vin;
}

function parseConfigurationVersion(value: string): number {
  const match = value.match(/v(\d+)$/i);
  if (!match) throw new Error(`INVALID_SYNTHETIC_CONFIGURATION_VERSION:${value}`);
  return Number.parseInt(match[1]!, 10);
}

function uuidToBytes(value: string): Buffer {
  const hex = value.replaceAll('-', '');
  if (!/^[0-9a-f]{32}$/i.test(hex)) throw new Error('INVALID_UUID_NAMESPACE');
  return Buffer.from(hex, 'hex');
}

function bytesToUuid(bytes: Uint8Array): string {
  const hex = Buffer.from(bytes).toString('hex');
  return [hex.slice(0, 8), hex.slice(8, 12), hex.slice(12, 16), hex.slice(16, 20), hex.slice(20, 32)].join('-');
}
