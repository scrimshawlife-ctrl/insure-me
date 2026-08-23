import Link from 'next/link';
import { notFound } from 'next/navigation';

import { DriverForm } from './driver-form';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

export default async function DriversPage({ params }: { params: Promise<{ id: string }> }) {
  const { id: quoteCaseId } = await params;
  const supabase = await createSupabaseServerClient();
  try { await requireConsumerQuoteContext(supabase, quoteCaseId); } catch { notFound(); }

  return (
    <main className="quote-shell">
      <div className="quote-header"><div><p className="eyebrow">Drivers</p><h1>Who drives the vehicles?</h1></div><Link className="brand" href="/" aria-label="Insure Me home"><span className="brand-mark">I</span>Insure Me</Link></div>
      <section className="card progress-card" aria-label="Quote progress"><div className="progress-meta"><strong>Drivers</strong><span>3 of 7</span></div><div className="progress-track" aria-hidden="true"><div className="progress-fill progress-3" /></div></section>
      <div className="quote-grid"><DriverForm quoteCaseId={quoteCaseId} /><aside className="card side-card"><h3>Keep it accurate</h3><p>Enter what you know. Missing optional license details can be resolved later instead of blocking the whole quote.</p><p>License identifiers are encrypted before storage.</p></aside></div>
    </main>
  );
}
