import { createCipheriv, createHmac, randomBytes } from 'node:crypto';

import { getIdentityProtectionEnvironment } from '@/src/infrastructure/config/env';

export interface ProtectedIdentifier {
  ciphertextHex: string;
  keyVersion: string;
  lookupHash: string;
  last4: string;
}

function normalizeIdentifier(value: string): string {
  return value.toUpperCase().replace(/[^A-Z0-9]/g, '');
}

export function protectSensitiveIdentifier(value: string): ProtectedIdentifier {
  const normalized = normalizeIdentifier(value);
  if (!normalized) {
    throw new Error('SENSITIVE_IDENTIFIER_REQUIRED');
  }

  const environment = getIdentityProtectionEnvironment();
  const key = Buffer.from(environment.IDENTITY_ENCRYPTION_KEY_B64, 'base64');
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([
    cipher.update(Buffer.from(normalized, 'utf8')),
    cipher.final(),
  ]);
  const authTag = cipher.getAuthTag();
  const envelope = Buffer.concat([Buffer.from([1]), iv, authTag, ciphertext]);

  return {
    ciphertextHex: envelope.toString('hex'),
    keyVersion: environment.IDENTITY_ENCRYPTION_KEY_VERSION,
    lookupHash: createHmac('sha256', environment.IDENTITY_LOOKUP_PEPPER)
      .update(normalized)
      .digest('hex'),
    last4: normalized.slice(-4),
  };
}
