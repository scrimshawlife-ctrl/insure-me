import Link from 'next/link';
import { notFound } from 'next/navigation';

import { DriverForm } from './driver-form';
import { getConsumerDrivers } from '@/src/application/intake/consumer-intake';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

export default async function DriversPage({ params }: { params: Promise<{ id: string }> }) {
  const { id: quoteCaseId } = await params;
  const supabase = await createSupabaseServerClient();
  try { await requireConsumerQuoteContext(supabase, quoteCaseId); } catch { notFound(); }

  const initialDrivers = (await getConsumerDrivers(supabase, quoteCaseId))
    .filter((driver) => driver.sourceType === 'CONSUMER');

  return (
    <main className="quote-shell">
      <div className="quote-header"><div><p className="eyebrow">Drivers</p><h1>Who drives the vehicles?</h1></div><Link className="brand" href="/" aria-label="Insure Me home"><span className="brand-mark">I</span>Insure Me</Link></div>
      <section className="card progress-card" aria-label="Quote progress"><div className="progress-meta"><strong>Drivers</strong><span>3 of 7</span></div><div className="progress-track" aria-hidden="true"><div className="progress-fill progress-3" /></div></section>
      <div className="quote-grid"><DriverForm quoteCaseId={quoteCaseId} initialDrivers={initialDrivers} /><aside className="card side-card"><h3>Keep it accurate</h3><p>Saved drivers are loaded using a safe projection. We never send the stored license number back to the browser.</p><p>If a license is already saved, leave the replacement field blank to keep it unchanged.</p></aside></div>
    </main>
  );
}
