import Link from 'next/link';
import { notFound } from 'next/navigation';

import { VehicleForm } from './vehicle-form';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

export default async function VehiclesPage({ params }: { params: Promise<{ id: string }> }) {
  const { id: quoteCaseId } = await params;
  const supabase = await createSupabaseServerClient();
  try { await requireConsumerQuoteContext(supabase, quoteCaseId); } catch { notFound(); }

  return (
    <main className="quote-shell">
      <div className="quote-header"><div><p className="eyebrow">Vehicles</p><h1>What are we insuring?</h1></div><Link className="brand" href="/" aria-label="Insure Me home"><span className="brand-mark">I</span>Insure Me</Link></div>
      <section className="card progress-card" aria-label="Quote progress"><div className="progress-meta"><strong>Vehicles</strong><span>4 of 7</span></div><div className="progress-track" aria-hidden="true"><div className="progress-fill progress-4" /></div></section>
      <div className="quote-grid"><VehicleForm quoteCaseId={quoteCaseId} /><aside className="card side-card"><h3>Verify, don’t interrogate</h3><p>When prefill is available later, this same step can present candidates as cards. Manual entry remains a first-class fallback when no record is found.</p><p>VIN values are encrypted before storage.</p></aside></div>
    </main>
  );
}
