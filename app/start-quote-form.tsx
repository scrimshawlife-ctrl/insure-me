'use client';

import { useState, type FormEvent } from 'react';

import { createSupabaseBrowserClient } from '@/src/infrastructure/supabase/browser';

export function StartQuoteForm() {
  const [email, setEmail] = useState('');
  const [status, setStatus] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus('sending');

    const supabase = createSupabaseBrowserClient();
    const redirectTo = `${window.location.origin}/auth/confirm?next=/quote`;
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: redirectTo,
        shouldCreateUser: true,
      },
    });

    setStatus(error ? 'error' : 'sent');
  }

  return (
    <form onSubmit={submit} aria-describedby="quote-start-message">
      <div className="field">
        <label htmlFor="quote-email">Email address</label>
        <input
          id="quote-email"
          name="email"
          type="email"
          autoComplete="email"
          inputMode="email"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder="you@example.com"
        />
      </div>
      <button className="primary-button" type="submit" disabled={status === 'sending' || status === 'sent'}>
        {status === 'sending' ? 'Sending secure link…' : status === 'sent' ? 'Check your email' : 'Start my auto quote'}
      </button>
      <p
        id="quote-start-message"
        className="form-message"
        role="status"
        aria-live="polite"
        data-tone={status === 'error' ? 'error' : status === 'sent' ? 'success' : undefined}
      >
        {status === 'sent' && 'We sent a secure sign-in link. Open it on this device to continue.'}
        {status === 'error' && 'We could not send the secure link. Please try again.'}
      </p>
      <p className="fine-print">
        Starting a quote does not authorize consumer reports. Required notices and permissions are shown separately before any regulated report request.
      </p>
    </form>
  );
}
