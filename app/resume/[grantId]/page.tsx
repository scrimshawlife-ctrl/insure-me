import Link from 'next/link';

import { StartQuoteForm } from '@/app/start-quote-form';
import { ResumeClient } from './resume-client';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

export default async function ResumePage({ params }: { params: Promise<{ grantId: string }> }) {
  const { grantId } = await params;
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.getClaims();
  const claims = data?.claims as { sub?: string } | undefined;
  const authenticated = !error && Boolean(claims?.sub);

  return (
    <main className="quote-shell">
      <div className="quote-header">
        <div><p className="eyebrow">Secure resume</p><h1>Continue your saved quote.</h1></div>
        <Link className="brand" href="/" aria-label="Insure Me home"><span className="brand-mark">I</span>Insure Me</Link>
      </div>
      <div className="quote-grid">
        {authenticated ? (
          <ResumeClient grantId={grantId} />
        ) : (
          <div className="card step-card">
            <p className="eyebrow">Sign in first</p>
            <h2>Verify it’s you.</h2>
            <p>The resume link identifies a saved checkpoint, but it does not grant access by itself. Sign in with the same email identity used for the quote.</p>
            <StartQuoteForm nextPath={`/resume/${grantId}`} submitLabel="Send secure sign-in link" />
          </div>
        )}
        <aside className="card side-card">
          <h3>One-time and expiring</h3>
          <p>Resume grants expire and can be consumed only once. Opening this page does not reveal whether a quote exists until authentication succeeds.</p>
        </aside>
      </div>
    </main>
  );
}
