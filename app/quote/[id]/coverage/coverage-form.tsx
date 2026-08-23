'use client';

import { useRouter } from 'next/navigation';
import { useState, type FormEvent } from 'react';

export function CoverageForm({ quoteCaseId }: { quoteCaseId: string }) {
  const router = useRouter();
  const [status, setStatus] = useState<'idle' | 'saving' | 'error'>('idle');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus('saving');
    const form = new FormData(event.currentTarget);

    const response = await fetch(`/api/v1/quote-cases/${quoteCaseId}/coverage-request`, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        schemaVersion: 1,
        requestedLimits: {
          bodilyInjury: String(form.get('bodilyInjury') ?? ''),
          propertyDamage: String(form.get('propertyDamage') ?? ''),
          uninsuredMotorist: String(form.get('uninsuredMotorist') ?? ''),
        },
        preferences: {
          collisionDeductible: Number(form.get('collisionDeductible') ?? 1000),
          comprehensiveDeductible: Number(form.get('comprehensiveDeductible') ?? 500),
          effectiveDate: String(form.get('effectiveDate') ?? ''),
        },
        notes: String(form.get('notes') ?? '') || undefined,
      }),
    });

    if (!response.ok) { setStatus('error'); return; }
    router.push(`/quote/${quoteCaseId}/review`);
  }

  return (
    <form className="card step-card" onSubmit={submit}>
      <p className="eyebrow">Step 5 of 7</p>
      <h2>Coverage preferences</h2>
      <p>These are requested preferences for agent/carrier review. They are not a premium or eligibility decision.</p>

      <div className="field"><label htmlFor="bodilyInjury">Bodily injury liability<select id="bodilyInjury" name="bodilyInjury" defaultValue="100/300"><option value="15/30">$15k / $30k</option><option value="50/100">$50k / $100k</option><option value="100/300">$100k / $300k</option><option value="250/500">$250k / $500k</option></select></label></div>
      <div className="field"><label htmlFor="propertyDamage">Property damage liability<select id="propertyDamage" name="propertyDamage" defaultValue="100000"><option value="5000">$5,000</option><option value="50000">$50,000</option><option value="100000">$100,000</option></select></label></div>
      <div className="field"><label htmlFor="uninsuredMotorist">Uninsured / underinsured motorist<select id="uninsuredMotorist" name="uninsuredMotorist" defaultValue="MATCH_BI"><option value="MATCH_BI">Match bodily injury limits</option><option value="LOWER">Lower limits</option><option value="DISCUSS_WITH_AGENT">Discuss with agent</option></select></label></div>

      <div className="form-grid two">
        <div className="field"><label htmlFor="collisionDeductible">Collision deductible<select id="collisionDeductible" name="collisionDeductible" defaultValue="1000"><option value="500">$500</option><option value="1000">$1,000</option><option value="2000">$2,000</option></select></label></div>
        <div className="field"><label htmlFor="comprehensiveDeductible">Comprehensive deductible<select id="comprehensiveDeductible" name="comprehensiveDeductible" defaultValue="500"><option value="250">$250</option><option value="500">$500</option><option value="1000">$1,000</option></select></label></div>
      </div>
      <div className="field"><label htmlFor="effectiveDate">Preferred effective date<input id="effectiveDate" name="effectiveDate" type="date" required /></label></div>
      <div className="field"><label htmlFor="notes">Anything your agent should know? <span className="optional">optional</span><textarea id="notes" name="notes" maxLength={1000} rows={4} /></label></div>

      <button className="primary-button" type="submit" disabled={status === 'saving'}>{status === 'saving' ? 'Saving…' : 'Save coverage preferences'}</button>
      <p className="form-message" role="status" aria-live="polite" data-tone={status === 'error' ? 'error' : undefined}>{status === 'error' && 'We could not save these preferences. Please try again.'}</p>
    </form>
  );
}
