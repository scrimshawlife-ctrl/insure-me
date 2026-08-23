'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';

import styles from '../../agent.module.css';

export function ProviderRefreshButton({
  quoteCaseId,
  capability,
  subjectIds,
  enabled,
}: {
  quoteCaseId: string;
  capability: 'IDENTITY' | 'PREFILL' | 'MVR' | 'CLAIMS' | 'VEHICLE';
  subjectIds: string[];
  enabled: boolean;
}) {
  const router = useRouter();
  const [state, setState] = useState<'idle' | 'running' | 'error'>('idle');

  async function refresh() {
    if (!enabled || state === 'running') return;
    setState('running');
    const response = await fetch(`/api/v1/agent/quote-cases/${quoteCaseId}/provider-requests`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        capability,
        subjectIds,
        idempotencyKey: `agent-refresh:${crypto.randomUUID()}`,
      }),
    });

    if (!response.ok) {
      setState('error');
      return;
    }

    setState('idle');
    router.refresh();
  }

  return (
    <div className={styles.actionGroup}>
      <button
        className={styles.actionButton}
        disabled={!enabled || state === 'running'}
        onClick={refresh}
        type="button"
      >
        {state === 'running' ? 'Refreshing…' : 'Refresh provider'}
      </button>
      {state === 'error' && <span className={styles.actionError}>Refresh failed</span>}
    </div>
  );
}
