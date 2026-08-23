import { z } from 'zod';

const serverEnvironmentSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: z.string().min(20),
});

export type ServerEnvironment = z.infer<typeof serverEnvironmentSchema>;

export function getServerEnvironment(
  source: NodeJS.ProcessEnv = process.env,
): ServerEnvironment {
  const parsed = serverEnvironmentSchema.safeParse(source);
  if (!parsed.success) {
    throw new Error('SERVER_ENVIRONMENT_INVALID');
  }
  return parsed.data;
}
