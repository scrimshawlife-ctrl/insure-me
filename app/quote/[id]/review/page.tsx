import Link from 'next/link';
import { notFound } from 'next/navigation';

import { ReviewSubmit } from './review-submit';
import { getConsumerCoverageRequest, getConsumerDrivers, getConsumerVehicles } from '@/src/application/intake/consumer-intake';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

export default async function ReviewPage({ params }: { params: Promise<{ id: string }> }) {
  const { id: quoteCaseId } = await params;
  const supabase = await createSupabaseServerClient();
  try { await requireConsumerQuoteContext(supabase, quoteCaseId); } catch { notFound(); }

  const [drivers, vehicles, coverage] = await Promise.all([
    getConsumerDrivers(supabase, quoteCaseId),
    getConsumerVehicles(supabase, quoteCaseId),
    getConsumerCoverageRequest(supabase, quoteCaseId),
  ]);

  return (
    <main className="quote-shell">
      <div className="quote-header"><div><p className="eyebrow">Review</p><h1>One last check before handoff.</h1></div><Link className="brand" href="/" aria-label="Insure Me home"><span className="brand-mark">I</span>Insure Me</Link></div>
      <section className="card progress-card" aria-label="Quote progress"><div className="progress-meta"><strong>Review and submit</strong><span>6 of 7</span></div><div className="progress-track" aria-hidden="true"><div className="progress-fill progress-6" /></div></section>
      <div className="quote-grid">
        <ReviewSubmit quoteCaseId={quoteCaseId} />
        <aside className="card side-card">
          <h3>Saved in this quote</h3>
          <dl className="summary-list"><div><dt>Drivers</dt><dd>{drivers.length}</dd></div><div><dt>Vehicles</dt><dd>{vehicles.length}</dd></div><div><dt>Coverage preferences</dt><dd>{coverage ? 'Saved' : 'Missing'}</dd></div></dl>
          <p>If a required step is missing, submission fails closed and tells you what still needs attention.</p>
        </aside>
      </div>
    </main>
  );
}
