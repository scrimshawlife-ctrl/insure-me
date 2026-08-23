'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

export function ResumeClient({ grantId }: { grantId: string }) {
  const router = useRouter();
  const [state, setState] = useState<'loading' | 'error'>('loading');

  useEffect(() => {
    let cancelled = false;

    async function resume() {
      const response = await fetch(`/api/v1/resume/${grantId}`, { method: 'POST' });
      if (!response.ok) {
        if (!cancelled) setState('error');
        return;
      }

      const payload = await response.json() as { quoteCaseId?: string };
      if (!payload.quoteCaseId) {
        if (!cancelled) setState('error');
        return;
      }

      router.replace(`/quote/${payload.quoteCaseId}`);
    }

    void resume();
    return () => { cancelled = true; };
  }, [grantId, router]);

  return (
    <div className="card step-card" role="status" aria-live="polite">
      <p className="eyebrow">Resume quote</p>
      <h2>{state === 'loading' ? 'Opening your saved quote…' : 'This resume link is no longer available.'}</h2>
      <p>{state === 'loading' ? 'We’re verifying the one-time resume grant against your signed-in account.' : 'The link may have expired or already been used. Your quote data has not been exposed.'}</p>
    </div>
  );
}
