import Link from 'next/link';
import { notFound } from 'next/navigation';

import { NoticeSequence } from './notice-sequence';
import { getRequiredNotices } from '@/src/application/notice/get-required-notices';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

export default async function ConsumerNoticesPage({ params }: { params: Promise<{ id: string }> }) {
  const { id: quoteCaseId } = await params;
  const supabase = await createSupabaseServerClient();

  try {
    await requireConsumerQuoteContext(supabase, quoteCaseId);
  } catch {
    notFound();
  }

  const notices = await getRequiredNotices(supabase, quoteCaseId);

  return (
    <main className="quote-shell">
      <div className="quote-header">
        <div>
          <p className="eyebrow">Privacy and permissions</p>
          <h1>Know exactly what you’re agreeing to.</h1>
        </div>
        <Link className="brand" href="/" aria-label="Insure Me home"><span className="brand-mark">I</span>Insure Me</Link>
      </div>

      <section className="card progress-card" aria-label="Quote progress">
        <div className="progress-meta"><strong>Notices and permissions</strong><span>2 of 7</span></div>
        <div className="progress-track" aria-hidden="true"><div className="progress-fill progress-2" /></div>
      </section>

      <div className="quote-grid">
        <NoticeSequence quoteCaseId={quoteCaseId} notices={notices} />
        <aside className="card side-card">
          <h3>Separate choices</h3>
          <p>Privacy acknowledgments, consumer-report disclosure, report authorization, transactional messaging, and optional marketing are recorded separately.</p>
          <p>Optional marketing can never unlock or block your quote.</p>
        </aside>
      </div>
    </main>
  );
}
