'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';

export function QuoteStartClient() {
  const router = useRouter();
  const [status, setStatus] = useState<'idle' | 'creating' | 'error'>('idle');

  async function createQuote() {
    setStatus('creating');
    const response = await fetch('/api/v1/quote-cases', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        jurisdiction: 'CA',
        productLine: 'PRIVATE_PASSENGER_AUTO',
        sourceChannel: 'WEB',
      }),
    });

    if (!response.ok) {
      setStatus('error');
      return;
    }

    const result = (await response.json()) as { quoteCaseId: string };
    router.push(`/quote/${result.quoteCaseId}`);
  }

  return (
    <div className="card step-card">
      <p className="eyebrow">California private passenger auto</p>
      <h2>Start a new quote</h2>
      <p>We’ll collect only what is needed for this quote. You can save and return later.</p>
      <button className="primary-button" type="button" onClick={createQuote} disabled={status === 'creating'}>
        {status === 'creating' ? 'Creating secure quote…' : 'Begin quote'}
      </button>
      <p className="form-message" role="status" aria-live="polite" data-tone={status === 'error' ? 'error' : undefined}>
        {status === 'error' && 'We could not start the quote. Please try again.'}
      </p>
    </div>
  );
}
