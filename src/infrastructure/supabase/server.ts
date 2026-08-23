import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

import { getServerEnvironment } from '@/src/infrastructure/config/env';
import type { Database } from '@/src/infrastructure/supabase/database.types';

export async function createSupabaseServerClient() {
  const cookieStore = await cookies();
  const environment = getServerEnvironment();

  return createServerClient<Database>(
    environment.NEXT_PUBLIC_SUPABASE_URL,
    environment.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            for (const { name, value, options } of cookiesToSet) {
              cookieStore.set(name, value, options);
            }
          } catch {
            // Server Components may be unable to write cookies. Middleware/route handlers
            // must own refresh writes; swallowing only this framework limitation is intentional.
          }
        },
      },
    },
  );
}
