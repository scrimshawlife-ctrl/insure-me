'use client';

import { useMemo, useState } from 'react';

import type { RequiredNoticeView } from '@/src/application/notice/get-required-notices';
import type { ConsentAction, NoticeCategory } from '@/src/domain/notice/consent';

type NoticeState = 'idle' | 'saving' | 'saved' | 'declined' | 'error';

function primaryAction(category: NoticeCategory): ConsentAction {
  if (category === 'REPORT_AUTHORIZATION') return 'AUTHORIZE';
  if (category === 'SMS_TRANSACTIONAL' || category === 'MARKETING_OPTIONAL') return 'OPT_IN';
  return 'ACKNOWLEDGE';
}

function secondaryAction(category: NoticeCategory): ConsentAction | null {
  if (category === 'REPORT_AUTHORIZATION') return 'DECLINE';
  if (category === 'SMS_TRANSACTIONAL' || category === 'MARKETING_OPTIONAL') return 'OPT_OUT';
  return null;
}

function primaryLabel(category: NoticeCategory): string {
  if (category === 'REPORT_AUTHORIZATION') return 'Authorize and continue';
  if (category === 'SMS_TRANSACTIONAL') return 'Agree to transactional texts';
  if (category === 'MARKETING_OPTIONAL') return 'Opt in to marketing';
  return 'Acknowledge and continue';
}

function secondaryLabel(category: NoticeCategory): string {
  if (category === 'REPORT_AUTHORIZATION') return 'Decline report authorization';
  return 'No thanks';
}

export function NoticeSequence({ quoteCaseId, notices }: { quoteCaseId: string; notices: RequiredNoticeView[] }) {
  const [index, setIndex] = useState(0);
  const [state, setState] = useState<NoticeState>('idle');
  const [completed, setCompleted] = useState(false);
  const notice = notices[index];

  const paragraphs = useMemo(
    () => notice?.bodyMarkdown.split(/\n\s*\n/).map((paragraph) => paragraph.trim()).filter(Boolean) ?? [],
    [notice],
  );

  async function record(actionType: ConsentAction) {
    if (!notice) return;
    setState('saving');

    const response = await fetch(`/api/v1/quote-cases/${quoteCaseId}/consents`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        noticeDefinitionId: notice.noticeDefinitionId,
        noticeContentHash: notice.contentHash,
        actionType,
        presentedAt: new Date().toISOString(),
        idempotencyKey: crypto.randomUUID(),
      }),
    });

    if (!response.ok) {
      setState('error');
      return;
    }

    const satisfying = actionType === primaryAction(notice.category) && notice.category !== 'MARKETING_OPTIONAL';
    if (!satisfying && notice.requiredForQuote) {
      setState('declined');
      return;
    }

    setState('saved');
    const nextIndex = index + 1;
    if (nextIndex >= notices.length) {
      setCompleted(true);
      return;
    }

    setIndex(nextIndex);
    setState('idle');
  }

  if (notices.length === 0 || completed) {
    return (
      <div className="card step-card">
        <p className="eyebrow">Step 2 of 7</p>
        <h2>Notices complete</h2>
        <p>You’ve finished the notices currently required for this quote. Next we’ll confirm the drivers.</p>
        <a className="primary-link" href={`/quote/${quoteCaseId}/drivers`}>Continue to drivers</a>
      </div>
    );
  }

  if (!notice) return null;

  const alternate = secondaryAction(notice.category);

  return (
    <section className="card step-card" aria-labelledby="notice-title">
      <div className="notice-meta">
        <span>Notice {index + 1} of {notices.length}</span>
        <span>Version {notice.version}</span>
      </div>
      <p className="eyebrow">Step 2 of 7</p>
      <h2 id="notice-title">{notice.title}</h2>
      <div className="notice-copy">
        {paragraphs.map((paragraph, paragraphIndex) => <p key={`${notice.noticeDefinitionId}-${paragraphIndex}`}>{paragraph}</p>)}
      </div>
      <div className="notice-actions">
        <button className="primary-button" type="button" onClick={() => record(primaryAction(notice.category))} disabled={state === 'saving'}>
          {state === 'saving' ? 'Saving…' : primaryLabel(notice.category)}
        </button>
        {alternate && (
          <button className="secondary-button full-width" type="button" onClick={() => record(alternate)} disabled={state === 'saving'}>
            {secondaryLabel(notice.category)}
          </button>
        )}
      </div>
      <p className="form-message" role="status" aria-live="polite" data-tone={state === 'error' || state === 'declined' ? 'error' : undefined}>
        {state === 'error' && 'We could not record your choice. Please try again.'}
        {state === 'declined' && 'This permission is required before the related consumer report can be requested. Your quote remains saved.'}
      </p>
      <p className="fine-print">Recorded against notice version {notice.version} and the exact content hash presented on this screen.</p>
    </section>
  );
}
