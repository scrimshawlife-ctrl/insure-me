'use client';

import { useRouter } from 'next/navigation';
import { useState, type FormEvent } from 'react';

import type { ConsumerVehicleView } from '@/src/application/intake/consumer-intake';

type VehicleDraft = {
  vehicleId?: string;
  vin: string;
  vinLast4?: string | null;
  modelYear: string;
  make: string;
  model: string;
  trim: string;
  ownershipState: string;
  garagingPostalCode: string;
  usage: string;
  annualMileage: string;
};

const EMPTY_VEHICLE: VehicleDraft = {
  vin: '', modelYear: '', make: '', model: '', trim: '', ownershipState: '', garagingPostalCode: '', usage: 'PERSONAL', annualMileage: '',
};

function toDraft(vehicle: ConsumerVehicleView): VehicleDraft {
  return {
    vehicleId: vehicle.vehicleId,
    vin: '',
    vinLast4: vehicle.vinLast4,
    modelYear: String(vehicle.modelYear),
    make: vehicle.make,
    model: vehicle.model,
    trim: vehicle.trim ?? '',
    ownershipState: vehicle.ownershipState ?? '',
    garagingPostalCode: vehicle.garagingPostalCode ?? '',
    usage: vehicle.usage,
    annualMileage: vehicle.annualMileage === null ? '' : String(vehicle.annualMileage),
  };
}

export function VehicleForm({
  quoteCaseId,
  initialVehicles,
}: {
  quoteCaseId: string;
  initialVehicles: ConsumerVehicleView[];
}) {
  const router = useRouter();
  const [vehicles, setVehicles] = useState<VehicleDraft[]>(
    initialVehicles.length > 0 ? initialVehicles.map(toDraft) : [{ ...EMPTY_VEHICLE }],
  );
  const [status, setStatus] = useState<'idle' | 'saving' | 'error'>('idle');

  function update(index: number, field: keyof VehicleDraft, value: string) {
    setVehicles((current) => current.map((vehicle, i) => i === index ? { ...vehicle, [field]: value } : vehicle));
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus('saving');
    const response = await fetch(`/api/v1/quote-cases/${quoteCaseId}/vehicles`, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        vehicles: vehicles.map((vehicle) => ({
          vehicleId: vehicle.vehicleId,
          vin: vehicle.vin || undefined,
          modelYear: Number(vehicle.modelYear),
          make: vehicle.make,
          model: vehicle.model,
          trim: vehicle.trim || undefined,
          ownershipState: vehicle.ownershipState || undefined,
          garagingPostalCode: vehicle.garagingPostalCode || undefined,
          usage: vehicle.usage,
          annualMileage: vehicle.annualMileage ? Number(vehicle.annualMileage) : undefined,
          confirmationState: 'CONFIRMED',
        })),
      }),
    });
    if (!response.ok) { setStatus('error'); return; }
    router.push(`/quote/${quoteCaseId}/coverage`);
  }

  return (
    <form className="card step-card" onSubmit={submit}>
      <p className="eyebrow">Step 4 of 7</p><h2>Vehicles on this quote</h2><p>Confirm each saved vehicle or add another. Stored VINs are never sent back to this screen.</p>
      <div className="entry-stack">
        {vehicles.map((vehicle, index) => (
          <fieldset className="entry-card" key={vehicle.vehicleId ?? `new-${index}`}>
            <legend>Vehicle {index + 1}</legend>
            <div className="form-grid three"><div className="field"><label>Year<input type="number" min="1900" max="2100" value={vehicle.modelYear} onChange={(e) => update(index, 'modelYear', e.target.value)} required /></label></div><div className="field"><label>Make<input value={vehicle.make} onChange={(e) => update(index, 'make', e.target.value)} required /></label></div><div className="field"><label>Model<input value={vehicle.model} onChange={(e) => update(index, 'model', e.target.value)} required /></label></div></div>
            <div className="form-grid two"><div className="field"><label>Trim <span className="optional">optional</span><input value={vehicle.trim} onChange={(e) => update(index, 'trim', e.target.value)} /></label></div><div className="field"><label>VIN <span className="optional">optional</span><input minLength={11} maxLength={32} value={vehicle.vin} onChange={(e) => update(index, 'vin', e.target.value.toUpperCase())} placeholder={vehicle.vinLast4 ? `Saved ••••${vehicle.vinLast4}` : undefined} /></label>{vehicle.vinLast4 && <span className="field-help">Leave blank to keep the saved VIN ending in {vehicle.vinLast4}.</span>}</div></div>
            <div className="form-grid two"><div className="field"><label>Primary use<select value={vehicle.usage} onChange={(e) => update(index, 'usage', e.target.value)}><option value="PERSONAL">Personal</option><option value="COMMUTE">Commute</option><option value="PLEASURE">Pleasure</option><option value="BUSINESS">Business</option></select></label></div><div className="field"><label>Annual mileage <span className="optional">optional</span><input type="number" min="0" max="250000" value={vehicle.annualMileage} onChange={(e) => update(index, 'annualMileage', e.target.value)} /></label></div></div>
            <div className="form-grid two"><div className="field"><label>Garaging ZIP <span className="optional">optional</span><input pattern="[0-9]{5}(-[0-9]{4})?" value={vehicle.garagingPostalCode} onChange={(e) => update(index, 'garagingPostalCode', e.target.value)} /></label></div><div className="field"><label>Ownership <span className="optional">optional</span><select value={vehicle.ownershipState} onChange={(e) => update(index, 'ownershipState', e.target.value)}><option value="">Select</option><option value="OWNED">Owned</option><option value="FINANCED">Financed</option><option value="LEASED">Leased</option></select></label></div></div>
            {vehicles.length > 1 && <button className="text-button" type="button" onClick={() => setVehicles((current) => current.filter((_, i) => i !== index))}>Remove vehicle</button>}
          </fieldset>
        ))}
      </div>
      <button className="secondary-button full-width add-button" type="button" onClick={() => setVehicles((current) => [...current, { ...EMPTY_VEHICLE }])}>Add another vehicle</button>
      <button className="primary-button" type="submit" disabled={status === 'saving'}>{status === 'saving' ? 'Saving…' : 'Confirm vehicles and continue'}</button>
      <p className="form-message" role="status" aria-live="polite" data-tone={status === 'error' ? 'error' : undefined}>{status === 'error' && 'We could not save the vehicles. Please check the information and try again.'}</p>
    </form>
  );
}
