import Link from 'next/link';
import { redirect } from 'next/navigation';

import { QuoteStartClient } from './start-client';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

export default async function QuoteStartPage() {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.getClaims();
  const claims = data?.claims as { sub?: string } | undefined;

  if (error || !claims?.sub) {
    redirect('/');
  }

  return (
    <main className="quote-shell">
      <div className="quote-header">
        <div>
          <p className="eyebrow">Secure quote workspace</p>
          <h1>Let’s get your quote ready.</h1>
        </div>
        <Link className="brand" href="/" aria-label="Insure Me home"><span className="brand-mark">I</span>Insure Me</Link>
      </div>
      <div className="quote-grid">
        <QuoteStartClient />
        <aside className="card side-card">
          <h3>What happens next</h3>
          <p>First we’ll confirm your identity and contact details. Required privacy notices and report permissions come after that as separate steps.</p>
          <p>No consumer report is requested just because you started a quote.</p>
        </aside>
      </div>
    </main>
  );
}
