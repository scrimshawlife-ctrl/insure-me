'use client';

import { useRouter } from 'next/navigation';
import { useState, type FormEvent } from 'react';

import type { ConsumerDriverView } from '@/src/application/intake/consumer-intake';

type DriverDraft = {
  driverId?: string;
  relationshipRole: string;
  firstName: string;
  lastName: string;
  dateOfBirth: string;
  licenseJurisdiction: string;
  licenseNumber: string;
  licenseLast4?: string | null;
  yearsLicensed: string;
};

const EMPTY_DRIVER: DriverDraft = {
  relationshipRole: 'PRIMARY',
  firstName: '',
  lastName: '',
  dateOfBirth: '',
  licenseJurisdiction: 'CA',
  licenseNumber: '',
  yearsLicensed: '',
};

function toDraft(driver: ConsumerDriverView): DriverDraft {
  return {
    driverId: driver.driverId,
    relationshipRole: driver.relationshipRole,
    firstName: driver.firstName,
    lastName: driver.lastName,
    dateOfBirth: driver.dateOfBirth,
    licenseJurisdiction: driver.licenseJurisdiction,
    licenseNumber: '',
    licenseLast4: driver.licenseLast4,
    yearsLicensed: driver.yearsLicensed === null ? '' : String(driver.yearsLicensed),
  };
}

export function DriverForm({
  quoteCaseId,
  initialDrivers,
}: {
  quoteCaseId: string;
  initialDrivers: ConsumerDriverView[];
}) {
  const router = useRouter();
  const [drivers, setDrivers] = useState<DriverDraft[]>(
    initialDrivers.length > 0 ? initialDrivers.map(toDraft) : [{ ...EMPTY_DRIVER }],
  );
  const [status, setStatus] = useState<'idle' | 'saving' | 'error'>('idle');

  function update(index: number, field: keyof DriverDraft, value: string) {
    setDrivers((current) => current.map((driver, i) => i === index ? { ...driver, [field]: value } : driver));
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus('saving');
    const response = await fetch(`/api/v1/quote-cases/${quoteCaseId}/drivers`, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        drivers: drivers.map((driver) => ({
          driverId: driver.driverId,
          relationshipRole: driver.relationshipRole,
          firstName: driver.firstName,
          lastName: driver.lastName,
          dateOfBirth: driver.dateOfBirth,
          licenseJurisdiction: driver.licenseJurisdiction.toUpperCase(),
          licenseNumber: driver.licenseNumber || undefined,
          yearsLicensed: driver.yearsLicensed ? Number(driver.yearsLicensed) : undefined,
          confirmationState: 'CONFIRMED',
        })),
      }),
    });

    if (!response.ok) {
      setStatus('error');
      return;
    }
    router.push(`/quote/${quoteCaseId}/vehicles`);
  }

  return (
    <form className="card step-card" onSubmit={submit}>
      <p className="eyebrow">Step 3 of 7</p>
      <h2>Drivers on this quote</h2>
      <p>Confirm each saved driver or add someone new. Stored license numbers are never sent back to this screen.</p>

      <div className="entry-stack">
        {drivers.map((driver, index) => (
          <fieldset className="entry-card" key={driver.driverId ?? `new-${index}`}>
            <legend>Driver {index + 1}</legend>
            <div className="form-grid two">
              <div className="field"><label>First name<input value={driver.firstName} onChange={(event) => update(index, 'firstName', event.target.value)} required /></label></div>
              <div className="field"><label>Last name<input value={driver.lastName} onChange={(event) => update(index, 'lastName', event.target.value)} required /></label></div>
            </div>
            <div className="form-grid two">
              <div className="field"><label>Date of birth<input type="date" value={driver.dateOfBirth} onChange={(event) => update(index, 'dateOfBirth', event.target.value)} required /></label></div>
              <div className="field"><label>Role<select value={driver.relationshipRole} onChange={(event) => update(index, 'relationshipRole', event.target.value)}><option value="PRIMARY">Primary driver</option><option value="HOUSEHOLD">Household driver</option><option value="OTHER">Other driver</option></select></label></div>
            </div>
            <div className="form-grid two">
              <div className="field"><label>License state<input maxLength={2} value={driver.licenseJurisdiction} onChange={(event) => update(index, 'licenseJurisdiction', event.target.value)} required /></label></div>
              <div className="field">
                <label>License number <span className="optional">optional</span>
                  <input value={driver.licenseNumber} onChange={(event) => update(index, 'licenseNumber', event.target.value)} placeholder={driver.licenseLast4 ? `Saved ••••${driver.licenseLast4}` : undefined} />
                </label>
                {driver.licenseLast4 && <span className="field-help">Leave blank to keep the saved license ending in {driver.licenseLast4}.</span>}
              </div>
            </div>
            <div className="field"><label>Years licensed <span className="optional">optional</span><input type="number" min="0" max="100" inputMode="numeric" value={driver.yearsLicensed} onChange={(event) => update(index, 'yearsLicensed', event.target.value)} /></label></div>
            {drivers.length > 1 && <button className="text-button" type="button" onClick={() => setDrivers((current) => current.filter((_, i) => i !== index))}>Remove driver</button>}
          </fieldset>
        ))}
      </div>

      <button className="secondary-button full-width add-button" type="button" onClick={() => setDrivers((current) => [...current, { ...EMPTY_DRIVER, relationshipRole: 'HOUSEHOLD' }])}>Add another driver</button>
      <button className="primary-button" type="submit" disabled={status === 'saving'}>{status === 'saving' ? 'Saving…' : 'Confirm drivers and continue'}</button>
      <p className="form-message" role="status" aria-live="polite" data-tone={status === 'error' ? 'error' : undefined}>{status === 'error' && 'We could not save the drivers. Please check the information and try again.'}</p>
    </form>
  );
}
