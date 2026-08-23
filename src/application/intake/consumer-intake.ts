import type { SupabaseClient } from '@supabase/supabase-js';

import type { Database, Json } from '@/src/infrastructure/supabase/database.types';
import { protectSensitiveIdentifier } from '@/src/infrastructure/security/sensitive-identifier-protection';

export interface ConsumerDriverInput {
  driverId?: string;
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
  vehicleId?: string;
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

export interface ConsumerDriverView {
  driverId: string;
  relationshipRole: string;
  firstName: string;
  lastName: string;
  dateOfBirth: string;
  licenseJurisdiction: string;
  licenseLast4: string | null;
  licenseStatus: string | null;
  yearsLicensed: number | null;
  confirmationState: 'UNCONFIRMED' | 'CONFIRMED' | 'CORRECTED';
  sourceType: 'CONSUMER' | 'AGENT' | 'PREFILL' | 'PROVIDER';
}

export interface ConsumerVehicleView {
  vehicleId: string;
  vinLast4: string | null;
  modelYear: number;
  make: string;
  model: string;
  trim: string | null;
  ownershipState: string | null;
  garagingPostalCode: string | null;
  usage: string;
  annualMileage: number | null;
  confirmationState: 'UNCONFIRMED' | 'CONFIRMED' | 'CORRECTED';
  sourceType: 'CONSUMER' | 'AGENT' | 'PREFILL' | 'PROVIDER';
}

export interface ConsumerCoverageRequestView {
  coverageRequestId: string;
  schemaVersion: number;
  requestedLimits: Json;
  preferences: Json;
  notes: string | null;
  updatedAt: string;
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

type DriverRow = {
  driver_id: string;
  relationship_role: string;
  first_name: string;
  last_name: string;
  date_of_birth: string;
  license_jurisdiction: string;
  license_last4: string | null;
  license_status: string | null;
  years_licensed: number | null;
  confirmation_state: ConsumerDriverView['confirmationState'];
  source_type: ConsumerDriverView['sourceType'];
};

type VehicleRow = {
  vehicle_id: string;
  vin_last4: string | null;
  model_year: number;
  make: string;
  model: string;
  trim: string | null;
  ownership_state: string | null;
  garaging_postal_code: string | null;
  usage: string;
  annual_mileage: number | null;
  confirmation_state: ConsumerVehicleView['confirmationState'];
  source_type: ConsumerVehicleView['sourceType'];
};

type CoverageRow = {
  coverage_request_id: string;
  schema_version: number;
  requested_limits: Json;
  preferences: Json;
  notes: string | null;
  updated_at: string;
};

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
): Promise<ConsumerDriverView[]> {
  const data = await callRpc(client, 'get_consumer_drivers', {
    p_quote_case_id: quoteCaseId,
  });
  if (!Array.isArray(data)) return [];
  return (data as DriverRow[]).map((row) => ({
    driverId: row.driver_id,
    relationshipRole: row.relationship_role,
    firstName: row.first_name,
    lastName: row.last_name,
    dateOfBirth: row.date_of_birth,
    licenseJurisdiction: row.license_jurisdiction,
    licenseLast4: row.license_last4,
    licenseStatus: row.license_status,
    yearsLicensed: row.years_licensed,
    confirmationState: row.confirmation_state,
    sourceType: row.source_type,
  }));
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
      driverId: driver.driverId ?? null,
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
): Promise<ConsumerVehicleView[]> {
  const data = await callRpc(client, 'get_consumer_vehicles', {
    p_quote_case_id: quoteCaseId,
  });
  if (!Array.isArray(data)) return [];
  return (data as VehicleRow[]).map((row) => ({
    vehicleId: row.vehicle_id,
    vinLast4: row.vin_last4,
    modelYear: row.model_year,
    make: row.make,
    model: row.model,
    trim: row.trim,
    ownershipState: row.ownership_state,
    garagingPostalCode: row.garaging_postal_code,
    usage: row.usage,
    annualMileage: row.annual_mileage,
    confirmationState: row.confirmation_state,
    sourceType: row.source_type,
  }));
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
      vehicleId: vehicle.vehicleId ?? null,
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
): Promise<ConsumerCoverageRequestView | null> {
  const data = await callRpc(client, 'get_consumer_coverage_request', {
    p_quote_case_id: quoteCaseId,
  });
  if (!Array.isArray(data) || !data[0]) return null;
  const row = data[0] as CoverageRow;
  return {
    coverageRequestId: row.coverage_request_id,
    schemaVersion: row.schema_version,
    requestedLimits: row.requested_limits,
    preferences: row.preferences,
    notes: row.notes,
    updatedAt: row.updated_at,
  };
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
