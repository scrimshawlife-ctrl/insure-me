'use client';

import { useState } from 'react';

export function ReviewSubmit({ quoteCaseId }: { quoteCaseId: string }) {
  const [state, setState] = useState<'idle' | 'submitting' | 'submitted' | 'incomplete' | 'error'>('idle');
  const [reason, setReason] = useState('');

  async function submit() {
    setState('submitting');
    const response = await fetch(`/api/v1/quote-cases/${quoteCaseId}/complete-consumer-intake`, { method: 'POST' });
    const body = await response.json().catch(() => ({})) as { error?: string; reason?: string; state?: string };

    if (response.ok) {
      setState('submitted');
      return;
    }
    if (response.status === 409) {
      setReason(body.reason ?? 'One or more required steps are incomplete.');
      setState('incomplete');
      return;
    }
    setState('error');
  }

  if (state === 'submitted') {
    return (
      <div className="card step-card status-card" role="status">
        <p className="eyebrow">Submitted</p>
        <h2>Your intake is ready for enrichment and agent review.</h2>
        <p>You can close this page. If more information is needed, the agency can follow up through the configured transactional channel.</p>
      </div>
    );
  }

  return (
    <div className="card step-card">
      <p className="eyebrow">Step 6 of 7</p>
      <h2>Review before submission</h2>
      <p>By submitting, you are sending the information and permissions already recorded in this quote to the next workflow stage. This does not create a binding premium or coverage.</p>
      <ul className="review-list">
        <li>Identity and contact details saved</li>
        <li>Notices and authorizations recorded separately</li>
        <li>Drivers and vehicles confirmed</li>
        <li>Coverage preferences saved</li>
      </ul>
      <button className="primary-button" type="button" onClick={submit} disabled={state === 'submitting'}>{state === 'submitting' ? 'Submitting…' : 'Submit quote intake'}</button>
      <p className="form-message" role="status" aria-live="polite" data-tone={state === 'incomplete' || state === 'error' ? 'error' : undefined}>
        {state === 'incomplete' && `A required step is incomplete: ${reason}`}
        {state === 'error' && 'We could not submit the intake. Your saved information has not been lost.'}
      </p>
    </div>
  );
}
