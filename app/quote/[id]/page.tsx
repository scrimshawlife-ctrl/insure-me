import Link from 'next/link';
import { notFound } from 'next/navigation';

import { IdentityForm } from './identity-form';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

export default async function ConsumerQuotePage({ params }: { params: Promise<{ id: string }> }) {
  const { id: quoteCaseId } = await params;
  const supabase = await createSupabaseServerClient();

  try {
    await requireConsumerQuoteContext(supabase, quoteCaseId);
  } catch {
    notFound();
  }

  return (
    <main className="quote-shell">
      <div className="quote-header">
        <div>
          <p className="eyebrow">Your auto quote</p>
          <h1>We’ll keep this simple.</h1>
        </div>
        <Link className="brand" href="/" aria-label="Insure Me home"><span className="brand-mark">I</span>Insure Me</Link>
      </div>

      <section className="card progress-card" aria-label="Quote progress">
        <div className="progress-meta"><strong>About you</strong><span>1 of 7</span></div>
        <div className="progress-track" aria-hidden="true"><div className="progress-fill" /></div>
      </section>

      <div className="quote-grid">
        <IdentityForm quoteCaseId={quoteCaseId} />
        <aside className="card side-card">
          <h3>Why we ask</h3>
          <p>Your contact and address details help prepare this quote and match the right records later, if you authorize those requests.</p>
          <p><strong>Not yet:</strong> saving this screen does not request a motor vehicle or claims report.</p>
          <hr className="soft-rule" />
          <p className="quote-reference">Quote reference<br /><code>{quoteCaseId.slice(0, 8)}</code></p>
        </aside>
      </div>
    </main>
  );
}
