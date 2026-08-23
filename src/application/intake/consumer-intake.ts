import type { SupabaseClient } from '@supabase/supabase-js';

import type { Database, Json } from '@/src/infrastructure/supabase/database.types';
import { protectSensitiveIdentifier } from '@/src/infrastructure/security/sensitive-identifier-protection';

export interface ConsumerDriverInput {
  relationshipRole: string;
  firstName: string;
  lastName: string;
  dateOfBirth: string;
  licenseJurisdiction: string;
  licenseNumber?: string;
  yearsLicensed?: number;
  confirmationState: 'UNCONFIRMED' | 'CONFIRMED' | 'CORRECTED';
}

export interface ConsumerVehicleInput {
  vin?: string;
  modelYear: number;
  make: string;
  model: string;
  trim?: string;
  ownershipState?: string;
  garagingPostalCode?: string;
  usage: string;
  annualMileage?: number;
  confirmationState: 'UNCONFIRMED' | 'CONFIRMED' | 'CORRECTED';
}

export interface CoverageRequestInput {
  schemaVersion: number;
  requestedLimits: Json;
  preferences: Json;
  notes?: string;
}

type GenericRpc = (
  functionName: string,
  args: Record<string, unknown>,
) => PromiseLike<{ data: unknown; error: { message: string } | null }>;

async function callRpc(
  client: SupabaseClient<Database>,
  functionName: string,
  args: Record<string, unknown>,
): Promise<unknown> {
  const rpc = client.rpc as unknown as GenericRpc;
  const { data, error } = await rpc(functionName, args);
  if (error) {
    throw new Error(error.message);
  }
  return data;
}

export async function getConsumerDrivers(
  client: SupabaseClient<Database>,
  quoteCaseId: string,
): Promise<unknown[]> {
  const data = await callRpc(client, 'get_consumer_drivers', {
    p_quote_case_id: quoteCaseId,
  });
  return Array.isArray(data) ? data : [];
}

export async function replaceConsumerDrivers(
  client: SupabaseClient<Database>,
  quoteCaseId: string,
  drivers: ConsumerDriverInput[],
): Promise<unknown[]> {
  const protectedDrivers = drivers.map((driver) => {
    const protectedLicense = driver.licenseNumber
      ? protectSensitiveIdentifier(driver.licenseNumber)
      : null;

    return {
      relationshipRole: driver.relationshipRole,
      firstName: driver.firstName,
      lastName: driver.lastName,
      dateOfBirth: driver.dateOfBirth,
      licenseJurisdiction: driver.licenseJurisdiction,
      licenseCiphertextHex: protectedLicense?.ciphertextHex ?? null,
      licenseKeyVersion: protectedLicense?.keyVersion ?? null,
      licenseLookupHash: protectedLicense?.lookupHash ?? null,
      licenseLast4: protectedLicense?.last4 ?? null,
      yearsLicensed: driver.yearsLicensed ?? null,
      confirmationState: driver.confirmationState,
    };
  });

  const data = await callRpc(client, 'replace_consumer_drivers', {
    p_quote_case_id: quoteCaseId,
    p_drivers: protectedDrivers,
  });
  return Array.isArray(data) ? data : [];
}

export async function getConsumerVehicles(
  client: SupabaseClient<Database>,
  quoteCaseId: string,
): Promise<unknown[]> {
  const data = await callRpc(client, 'get_consumer_vehicles', {
    p_quote_case_id: quoteCaseId,
  });
  return Array.isArray(data) ? data : [];
}

export async function replaceConsumerVehicles(
  client: SupabaseClient<Database>,
  quoteCaseId: string,
  vehicles: ConsumerVehicleInput[],
): Promise<unknown[]> {
  const protectedVehicles = vehicles.map((vehicle) => {
    const protectedVin = vehicle.vin
      ? protectSensitiveIdentifier(vehicle.vin)
      : null;

    return {
      vinCiphertextHex: protectedVin?.ciphertextHex ?? null,
      vinKeyVersion: protectedVin?.keyVersion ?? null,
      vinLookupHash: protectedVin?.lookupHash ?? null,
      vinLast4: protectedVin?.last4 ?? null,
      modelYear: vehicle.modelYear,
      make: vehicle.make,
      model: vehicle.model,
      trim: vehicle.trim ?? null,
      ownershipState: vehicle.ownershipState ?? null,
      garagingPostalCode: vehicle.garagingPostalCode ?? null,
      usage: vehicle.usage,
      annualMileage: vehicle.annualMileage ?? null,
      confirmationState: vehicle.confirmationState,
    };
  });

  const data = await callRpc(client, 'replace_consumer_vehicles', {
    p_quote_case_id: quoteCaseId,
    p_vehicles: protectedVehicles,
  });
  return Array.isArray(data) ? data : [];
}

export async function getConsumerCoverageRequest(
  client: SupabaseClient<Database>,
  quoteCaseId: string,
): Promise<unknown | null> {
  const data = await callRpc(client, 'get_consumer_coverage_request', {
    p_quote_case_id: quoteCaseId,
  });
  return Array.isArray(data) ? (data[0] ?? null) : null;
}

export async function saveConsumerCoverageRequest(
  client: SupabaseClient<Database>,
  quoteCaseId: string,
  input: CoverageRequestInput,
): Promise<unknown> {
  return callRpc(client, 'upsert_consumer_coverage_request', {
    p_quote_case_id: quoteCaseId,
    p_schema_version: input.schemaVersion,
    p_requested_limits: input.requestedLimits,
    p_preferences: input.preferences,
    p_notes: input.notes ?? null,
  });
}

export async function completeConsumerIntake(
  client: SupabaseClient<Database>,
  quoteCaseId: string,
): Promise<unknown> {
  const data = await callRpc(client, 'complete_consumer_intake', {
    p_quote_case_id: quoteCaseId,
  });
  return Array.isArray(data) ? (data[0] ?? null) : data;
}
