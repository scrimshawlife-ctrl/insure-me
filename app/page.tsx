import Link from 'next/link';

import { StartQuoteForm } from './start-quote-form';

export default function HomePage() {
  return (
    <main className="site-shell">
      <header className="site-header">
        <Link className="brand" href="/" aria-label="Insure Me home"><span className="brand-mark">I</span>Insure Me</Link>
        <span className="header-note">California auto quote preparation</span>
      </header>

      <section className="hero">
        <div>
          <p className="eyebrow">Insurance intake without the interrogation</p>
          <h1>Confirm what matters. Skip the busywork.</h1>
          <p className="hero-copy">
            Start a secure auto quote, verify your information, and give permission only when a regulated report is actually needed. No carrier lock-in and no hidden risk score.
          </p>
          <div className="trust-row" aria-label="Product principles">
            <span className="trust-chip">Mobile-first</span>
            <span className="trust-chip">Permission before reports</span>
            <span className="trust-chip">Save and resume</span>
          </div>
        </div>

        <div className="card start-card">
          <p className="eyebrow">Get started</p>
          <h2>Your secure quote link</h2>
          <p>Enter your email. We’ll send a passwordless sign-in link so your quote stays tied to you without creating another password.</p>
          <StartQuoteForm />
        </div>
      </section>

      <section className="process" aria-labelledby="process-heading">
        <p className="eyebrow">How it works</p>
        <h2 id="process-heading">A short path from intake to agent review.</h2>
        <div className="process-grid">
          <article className="card process-card"><span className="process-number">1</span><h3>Tell us the basics</h3><p>Confirm contact, driver, vehicle, and coverage information in small steps.</p></article>
          <article className="card process-card"><span className="process-number">2</span><h3>Approve what is needed</h3><p>Privacy notices and report authorizations are shown separately, in plain language.</p></article>
          <article className="card process-card"><span className="process-number">3</span><h3>Review and hand off</h3><p>An agent gets a complete, provenance-backed quote package instead of a mystery score.</p></article>
        </div>
      </section>
    </main>
  );
}
