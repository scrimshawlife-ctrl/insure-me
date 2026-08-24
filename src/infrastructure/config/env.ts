import { z } from 'zod';

const serverEnvironmentSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: z.string().min(20),
});

const adminEnvironmentSchema = serverEnvironmentSchema.extend({
  SUPABASE_SECRET_KEY: z.string().min(20),
});

const identityProtectionEnvironmentSchema = z.object({
  IDENTITY_ENCRYPTION_KEY_B64: z.string().min(40),
  IDENTITY_ENCRYPTION_KEY_VERSION: z.string().min(1).max(64),
  IDENTITY_LOOKUP_PEPPER: z.string().min(32),
});

const retentionWorkerEnvironmentSchema = z.object({
  RETENTION_WORKER_TOKEN: z.string().min(32).max(500),
});

export type ServerEnvironment = z.infer<typeof serverEnvironmentSchema>;
export type AdminEnvironment = z.infer<typeof adminEnvironmentSchema>;
export type IdentityProtectionEnvironment = z.infer<
  typeof identityProtectionEnvironmentSchema
>;
export type RetentionWorkerEnvironment = z.infer<
  typeof retentionWorkerEnvironmentSchema
>;

export function getServerEnvironment(
  source: NodeJS.ProcessEnv = process.env,
): ServerEnvironment {
  const parsed = serverEnvironmentSchema.safeParse(source);
  if (!parsed.success) {
    throw new Error('SERVER_ENVIRONMENT_INVALID');
  }
  return parsed.data;
}

export function getAdminEnvironment(
  source: NodeJS.ProcessEnv = process.env,
): AdminEnvironment {
  const parsed = adminEnvironmentSchema.safeParse(source);
  if (!parsed.success) {
    throw new Error('ADMIN_ENVIRONMENT_INVALID');
  }
  return parsed.data;
}

export function getIdentityProtectionEnvironment(
  source: NodeJS.ProcessEnv = process.env,
): IdentityProtectionEnvironment {
  const parsed = identityProtectionEnvironmentSchema.safeParse(source);
  if (!parsed.success) {
    throw new Error('IDENTITY_PROTECTION_ENVIRONMENT_INVALID');
  }

  const key = Buffer.from(parsed.data.IDENTITY_ENCRYPTION_KEY_B64, 'base64');
  if (key.length !== 32) {
    throw new Error('IDENTITY_ENCRYPTION_KEY_INVALID');
  }

  return parsed.data;
}

export function getRetentionWorkerEnvironment(
  source: NodeJS.ProcessEnv = process.env,
): RetentionWorkerEnvironment {
  const parsed = retentionWorkerEnvironmentSchema.safeParse(source);
  if (!parsed.success) {
    throw new Error('RETENTION_WORKER_ENVIRONMENT_INVALID');
  }
  return parsed.data;
}
