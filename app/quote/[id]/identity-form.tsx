'use client';

import { useRouter } from 'next/navigation';
import { useState, type FormEvent } from 'react';

export function IdentityForm({ quoteCaseId }: { quoteCaseId: string }) {
  const router = useRouter();
  const [status, setStatus] = useState<'idle' | 'saving' | 'saved' | 'error'>('idle');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus('saving');
    const form = new FormData(event.currentTarget);
    const response = await fetch(`/api/v1/quote-cases/${quoteCaseId}/identity`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        firstName: String(form.get('firstName') ?? ''),
        lastName: String(form.get('lastName') ?? ''),
        dateOfBirth: String(form.get('dateOfBirth') ?? ''),
        email: String(form.get('email') ?? ''),
        phone: String(form.get('phone') ?? '') || undefined,
        address: {
          line1: String(form.get('line1') ?? ''),
          line2: String(form.get('line2') ?? '') || undefined,
          city: String(form.get('city') ?? ''),
          state: 'CA',
          postalCode: String(form.get('postalCode') ?? ''),
        },
      }),
    });

    if (!response.ok) {
      setStatus('error');
      return;
    }

    setStatus('saved');
    router.push(`/quote/${quoteCaseId}/notices`);
  }

  return (
    <form className="card step-card" onSubmit={submit}>
      <p className="eyebrow">Step 1 of 7</p>
      <h2>About you</h2>
      <p>Use your legal name and current home address. We keep sensitive identity details encrypted.</p>

      <div className="form-grid two">
        <div className="field"><label htmlFor="firstName">First name</label><input id="firstName" name="firstName" autoComplete="given-name" required /></div>
        <div className="field"><label htmlFor="lastName">Last name</label><input id="lastName" name="lastName" autoComplete="family-name" required /></div>
      </div>
      <div className="form-grid two">
        <div className="field"><label htmlFor="dateOfBirth">Date of birth</label><input id="dateOfBirth" name="dateOfBirth" type="date" autoComplete="bday" required /></div>
        <div className="field"><label htmlFor="email">Email</label><input id="email" name="email" type="email" autoComplete="email" required /></div>
      </div>
      <div className="field"><label htmlFor="phone">Phone <span className="optional">optional</span></label><input id="phone" name="phone" type="tel" autoComplete="tel" /></div>
      <div className="field"><label htmlFor="line1">Street address</label><input id="line1" name="line1" autoComplete="address-line1" required /></div>
      <div className="field"><label htmlFor="line2">Apartment, suite, etc. <span className="optional">optional</span></label><input id="line2" name="line2" autoComplete="address-line2" /></div>
      <div className="form-grid city-grid">
        <div className="field"><label htmlFor="city">City</label><input id="city" name="city" autoComplete="address-level2" required /></div>
        <div className="field"><label htmlFor="state">State</label><input id="state" name="state" value="CA" readOnly aria-readonly="true" /></div>
        <div className="field"><label htmlFor="postalCode">ZIP code</label><input id="postalCode" name="postalCode" inputMode="numeric" autoComplete="postal-code" pattern="[0-9]{5}(-[0-9]{4})?" required /></div>
      </div>

      <button className="primary-button" type="submit" disabled={status === 'saving'}>
        {status === 'saving' ? 'Saving…' : 'Save and continue'}
      </button>
      <p className="form-message" role="status" aria-live="polite" data-tone={status === 'error' ? 'error' : status === 'saved' ? 'success' : undefined}>
        {status === 'saved' && 'Saved. Opening privacy notices…'}
        {status === 'error' && 'We could not save this information. Check the fields and try again.'}
      </p>
    </form>
  );
}
