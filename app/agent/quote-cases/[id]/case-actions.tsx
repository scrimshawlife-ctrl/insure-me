'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';

import styles from '../../agent.module.css';

export function CaseActions({ quoteCaseId, readinessIssueId, blocking, enabled }: {
  quoteCaseId: string;
  readinessIssueId: string;
  blocking: boolean;
  enabled: boolean;
}) {
  const router = useRouter();
  const [mode, setMode] = useState<'idle' | 'resolve' | 'followup'>('idle');
  const [text, setText] = useState('');
  const [error, setError] = useState<string | null>(null);

  async function submit(action: 'RESOLVE_NON_BLOCKING' | 'REQUEST_CONSUMER_FOLLOW_UP') {
    setError(null);
    const body = action === 'RESOLVE_NON_BLOCKING'
      ? { action, readinessIssueId, evidence: text }
      : { action, readinessIssueId, requestType: 'MISSING_INFORMATION', message: text };
    const response = await fetch(`/api/v1/agent/quote-cases/${quoteCaseId}/case-actions`, {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body),
    });
    if (!response.ok) { setError('Action could not be completed.'); return; }
    setMode('idle'); setText(''); router.refresh();
  }

  if (!enabled) return null;
  if (mode === 'idle') return (
    <div className={styles.inlineActions}>
      <button className={styles.secondaryButton} onClick={() => setMode('followup')} type="button">Request follow-up</button>
      {!blocking && <button className={styles.actionButton} onClick={() => setMode('resolve')} type="button">Review and close</button>}
    </div>
  );
  return (
    <div className={styles.actionEditor}>
      <label htmlFor={`case-action-${readinessIssueId}`}>{mode === 'resolve' ? 'Resolution evidence' : 'Information requested from consumer'}</label>
      <textarea id={`case-action-${readinessIssueId}`} maxLength={mode === 'resolve' ? 1000 : 2000} onChange={(event) => setText(event.target.value)} value={text} />
      <div className={styles.inlineActions}>
        <button className={styles.secondaryButton} onClick={() => { setMode('idle'); setError(null); }} type="button">Cancel</button>
        <button className={styles.actionButton} disabled={text.trim().length < (mode === 'resolve' ? 3 : 1)} onClick={() => submit(mode === 'resolve' ? 'RESOLVE_NON_BLOCKING' : 'REQUEST_CONSUMER_FOLLOW_UP')} type="button">Save</button>
      </div>
      {error && <span className={styles.actionError} role="alert">{error}</span>}
    </div>
  );
}
