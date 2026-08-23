import { createClient } from '@supabase/supabase-js';

import { getAdminEnvironment } from '@/src/infrastructure/config/env';
import type { Database } from '@/src/infrastructure/supabase/database.types';

export function createSupabaseAdminClient() {
  const environment = getAdminEnvironment();

  return createClient<Database>(
    environment.NEXT_PUBLIC_SUPABASE_URL,
    environment.SUPABASE_SECRET_KEY,
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false,
      },
    },
  );
}
