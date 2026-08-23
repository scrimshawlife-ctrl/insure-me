import Link from 'next/link';
import { notFound } from 'next/navigation';

import { CoverageForm } from './coverage-form';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

export default async function CoveragePage({ params }: { params: Promise<{ id: string }> }) {
  const { id: quoteCaseId } = await params;
  const supabase = await createSupabaseServerClient();
  try { await requireConsumerQuoteContext(supabase, quoteCaseId); } catch { notFound(); }

  return (
    <main className="quote-shell">
      <div className="quote-header"><div><p className="eyebrow">Coverage</p><h1>What coverage feels right?</h1></div><Link className="brand" href="/" aria-label="Insure Me home"><span className="brand-mark">I</span>Insure Me</Link></div>
      <section className="card progress-card" aria-label="Quote progress"><div className="progress-meta"><strong>Coverage preferences</strong><span>5 of 7</span></div><div className="progress-track" aria-hidden="true"><div className="progress-fill progress-5" /></div></section>
      <div className="quote-grid"><CoverageForm quoteCaseId={quoteCaseId} /><aside className="card side-card"><h3>Preferences, not a decision</h3><p>This screen records what you want the agent or carrier to consider. It does not calculate a premium or make an underwriting decision.</p></aside></div>
    </main>
  );
}
