import {
  createCipheriv,
  createHmac,
  randomBytes,
} from 'node:crypto';

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

function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}

function normalizePhone(value: string): string {
  return value.replace(/[^0-9+]/g, '');
}

function lookupHash(value: string, pepper: string): string {
  return createHmac('sha256', pepper).update(value).digest('hex');
}

export function protectConsumerIdentity(
  payload: ConsumerIdentityPayload,
): ProtectedIdentityPayload {
  const environment = getIdentityProtectionEnvironment();
  const key = Buffer.from(environment.IDENTITY_ENCRYPTION_KEY_B64, 'base64');
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const plaintext = Buffer.from(JSON.stringify(payload), 'utf8');
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const authTag = cipher.getAuthTag();

  // Binary envelope: version(1) | iv(12) | authTag(16) | ciphertext(N).
  const envelope = Buffer.concat([Buffer.from([1]), iv, authTag, ciphertext]);

  return {
    pgBytea: `\\x${envelope.toString('hex')}`,
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
