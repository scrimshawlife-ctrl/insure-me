import {
  createCipheriv,
  createDecipheriv,
  createHmac,
  createHash,
  randomBytes,
} from 'node:crypto';

import type { PrivacyRequestType } from '@/src/domain/privacy';
import { getIdentityProtectionEnvironment } from '@/src/infrastructure/config/env';

export interface ConsumerIdentityPayload {
  firstName: string;
  lastName: string;
  dateOfBirth: string;
  email: string;
  phone?: string;
  address: {
    line1: string;
    line2?: string;
    city: string;
    state: 'CA';
    postalCode: string;
  };
}

export interface ProtectedIdentityPayload {
  pgBytea: string;
  keyVersion: string;
  emailLookupHash: string;
  phoneLookupHash: string | null;
}

export interface PrivacyRequesterPayload {
  firstName: string;
  lastName: string;
  email: string;
  phone?: string;
}

export interface ProtectedPrivacyRequester extends ProtectedIdentityPayload {
  requestHash: string;
  statusToken: string;
  statusTokenHash: string;
}

function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}

function normalizePhone(value: string): string {
  return value.replace(/[^0-9+]/g, '');
}

function lookupHash(value: string, pepper: string): string {
  return createHmac('sha256', pepper).update(value).digest('hex');
}

function encryptPayload(payload: unknown, key: Buffer): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const plaintext = Buffer.from(JSON.stringify(payload), 'utf8');
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const authTag = cipher.getAuthTag();
  const envelope = Buffer.concat([Buffer.from([1]), iv, authTag, ciphertext]);
  return `\\x${envelope.toString('hex')}`;
}

function envelopeBytes(value: string): Buffer {
  const hex = value.startsWith('\\x') ? value.slice(2) : value;
  if (!/^[0-9a-f]+$/i.test(hex) || hex.length % 2 !== 0) {
    throw new Error('PROTECTED_ENVELOPE_INVALID');
  }
  return Buffer.from(hex, 'hex');
}

function decryptEnvelope(value: string, keyVersion: string): Buffer {
  const environment = getIdentityProtectionEnvironment();
  if (keyVersion !== environment.IDENTITY_ENCRYPTION_KEY_VERSION) {
    throw new Error('PROTECTED_ENVELOPE_KEY_UNAVAILABLE');
  }
  const envelope = envelopeBytes(value);
  if (envelope.length < 30 || envelope[0] !== 1) {
    throw new Error('PROTECTED_ENVELOPE_INVALID');
  }
  const decipher = createDecipheriv(
    'aes-256-gcm',
    Buffer.from(environment.IDENTITY_ENCRYPTION_KEY_B64, 'base64'),
    envelope.subarray(1, 13),
  );
  decipher.setAuthTag(envelope.subarray(13, 29));
  return Buffer.concat([
    decipher.update(envelope.subarray(29)),
    decipher.final(),
  ]);
}

export function unprotectJsonPayload<T>(value: string, keyVersion: string): T {
  try {
    return JSON.parse(decryptEnvelope(value, keyVersion).toString('utf8')) as T;
  } catch (error) {
    if (error instanceof Error && error.message.startsWith('PROTECTED_ENVELOPE_')) {
      throw error;
    }
    throw new Error('PROTECTED_ENVELOPE_INVALID');
  }
}

export function unprotectSensitiveIdentifier(
  value: string,
  keyVersion: string,
): string {
  return decryptEnvelope(value, keyVersion).toString('utf8');
}

export function protectPrivacyExport(
  payload: unknown,
  recordCount: number,
): {
  pgBytea: string;
  keyVersion: string;
  contentHash: string;
  recordCount: number;
} {
  const environment = getIdentityProtectionEnvironment();
  const serialized = JSON.stringify(payload);
  return {
    pgBytea: encryptPayload(
      JSON.parse(serialized) as unknown,
      Buffer.from(environment.IDENTITY_ENCRYPTION_KEY_B64, 'base64'),
    ),
    keyVersion: environment.IDENTITY_ENCRYPTION_KEY_VERSION,
    contentHash: createHash('sha256').update(serialized).digest('hex'),
    recordCount,
  };
}

export function protectConsumerIdentity(
  payload: ConsumerIdentityPayload,
): ProtectedIdentityPayload {
  const environment = getIdentityProtectionEnvironment();
  const key = Buffer.from(environment.IDENTITY_ENCRYPTION_KEY_B64, 'base64');

  return {
    pgBytea: encryptPayload(payload, key),
    keyVersion: environment.IDENTITY_ENCRYPTION_KEY_VERSION,
    emailLookupHash: lookupHash(
      normalizeEmail(payload.email),
      environment.IDENTITY_LOOKUP_PEPPER,
    ),
    phoneLookupHash: payload.phone
      ? lookupHash(
          normalizePhone(payload.phone),
          environment.IDENTITY_LOOKUP_PEPPER,
        )
      : null,
  };
}

export function protectPrivacyRequester(
  payload: PrivacyRequesterPayload,
  idempotencyKey: string,
  context: { requestType: PrivacyRequestType; jurisdiction: 'CA' },
): ProtectedPrivacyRequester {
  const environment = getIdentityProtectionEnvironment();
  const key = Buffer.from(environment.IDENTITY_ENCRYPTION_KEY_B64, 'base64');
  const normalized = {
    firstName: payload.firstName.trim(),
    lastName: payload.lastName.trim(),
    email: normalizeEmail(payload.email),
    phone: payload.phone ? normalizePhone(payload.phone) : null,
  };
  const requestHash = lookupHash(
    `privacy-request-v1|${context.requestType}|${context.jurisdiction}|${JSON.stringify(normalized)}`,
    environment.IDENTITY_LOOKUP_PEPPER,
  );
  const statusToken = createHmac('sha256', environment.IDENTITY_LOOKUP_PEPPER)
    .update(`privacy-status-v1|${idempotencyKey}|${requestHash}`)
    .digest('base64url');

  return {
    pgBytea: encryptPayload(normalized, key),
    keyVersion: environment.IDENTITY_ENCRYPTION_KEY_VERSION,
    emailLookupHash: lookupHash(
      normalized.email,
      environment.IDENTITY_LOOKUP_PEPPER,
    ),
    phoneLookupHash: normalized.phone
      ? lookupHash(normalized.phone, environment.IDENTITY_LOOKUP_PEPPER)
      : null,
    requestHash,
    statusToken,
    statusTokenHash: createHash('sha256').update(statusToken).digest('hex'),
  };
}

export function privacyVerificationAttemptHash(input: {
  privacyRequestId: string;
  assertion: string;
  idempotencyKey: string;
  adapterId: string;
  adapterVersion: string;
  policyVersion: string;
}): string {
  const environment = getIdentityProtectionEnvironment();
  return lookupHash(
    [
      'privacy-identity-verification-v1',
      input.privacyRequestId,
      input.assertion,
      input.idempotencyKey,
      input.adapterId,
      input.adapterVersion,
      input.policyVersion,
    ].join('|'),
    environment.IDENTITY_LOOKUP_PEPPER,
  );
}

export function privacyDiscoveryRequestHash(input: {
  privacyRequestId: string;
  idempotencyKey: string;
  policyVersion: string;
  exportSchemaVersion: string;
}): string {
  const environment = getIdentityProtectionEnvironment();
  return lookupHash(
    [
      'privacy-discovery-v1',
      input.privacyRequestId,
      input.idempotencyKey,
      input.policyVersion,
      input.exportSchemaVersion,
    ].join('|'),
    environment.IDENTITY_LOOKUP_PEPPER,
  );
}

export function privacyRightsExecutionRequestHash(input: {
  privacyRequestId: string;
  idempotencyKey: string;
  policyVersion: string;
  corrections: Record<string, unknown> | null;
}): string {
  const environment = getIdentityProtectionEnvironment();
  return lookupHash(
    [
      'privacy-rights-execution-v1',
      input.privacyRequestId,
      input.idempotencyKey,
      input.policyVersion,
      JSON.stringify(input.corrections),
    ].join('|'),
    environment.IDENTITY_LOOKUP_PEPPER,
  );
}
