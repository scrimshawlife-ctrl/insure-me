'use client';

import { useState } from 'react';

export function SaveResumeControl({ quoteCaseId }: { quoteCaseId: string }) {
  const [state, setState] = useState<'idle' | 'creating' | 'ready' | 'copied' | 'error'>('idle');
  const [resumeUrl, setResumeUrl] = useState('');

  async function createGrant() {
    setState('creating');
    const response = await fetch(`/api/v1/quote-cases/${quoteCaseId}/resume-grants`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ ttlMinutes: 60 }),
    });

    if (!response.ok) {
      setState('error');
      return;
    }

    const payload = await response.json() as { resumeGrantId?: string };
    if (!payload.resumeGrantId) {
      setState('error');
      return;
    }

    const url = `${window.location.origin}/resume/${payload.resumeGrantId}`;
    setResumeUrl(url);
    setState('ready');
  }

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(resumeUrl);
      setState('copied');
    } catch {
      setState('error');
    }
  }

  return (
    <div className="resume-control">
      {resumeUrl ? (
        <>
          <p className="fine-print">This one-time link expires in about 60 minutes and still requires sign-in.</p>
          <button className="secondary-button full-width" type="button" onClick={copyLink}>
            {state === 'copied' ? 'Resume link copied' : 'Copy resume link'}
          </button>
        </>
      ) : (
        <button className="secondary-button full-width" type="button" onClick={createGrant} disabled={state === 'creating'}>
          {state === 'creating' ? 'Creating secure link…' : 'Save & resume later'}
        </button>
      )}
      <p className="form-message" role="status" aria-live="polite" data-tone={state === 'error' ? 'error' : state === 'copied' ? 'success' : undefined}>
        {state === 'error' && 'We could not create or copy the resume link. Please try again.'}
        {state === 'copied' && 'Copied. Keep the link private; it still requires your signed-in identity.'}
      </p>
    </div>
  );
}
