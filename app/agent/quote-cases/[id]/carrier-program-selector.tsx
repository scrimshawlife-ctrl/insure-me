'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';

import type { CarrierProgramSelectionModel } from '@/src/application/agent/carrier-program-selection';
import styles from '../../agent.module.css';

export function CarrierProgramSelector({ quoteCaseId, model, selectionEnabled }: { quoteCaseId: string; model: CarrierProgramSelectionModel; selectionEnabled: boolean }) {
  const router = useRouter();
  const initiallySelected = model.options.find((option) => option.selected)?.carrierProgramId
    ?? model.options.find((option) => option.selectable)?.carrierProgramId
    ?? '';
  const [selectedId, setSelectedId] = useState(initiallySelected);
  const [state, setState] = useState<'idle' | 'saving' | 'error'>('idle');

  async function save() {
    if (!selectedId || state === 'saving') return;
    setState('saving');
    const response = await fetch(`/api/v1/agent/quote-cases/${quoteCaseId}/carrier-program`, {
      method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ carrierProgramId: selectedId }),
    });
    if (!response.ok) { setState('error'); return; }
    setState('idle'); router.refresh();
  }

  return (
    <div className={styles.selector}>
      <label htmlFor="carrier-program-target">Configured target</label>
      <select id="carrier-program-target" onChange={(event) => setSelectedId(event.target.value)} value={selectedId}>
        {model.options.length === 0 && <option value="">No configured programs</option>}
        {model.options.map((option) => (
          <option disabled={!option.selectable} key={option.carrierProgramId} value={option.carrierProgramId}>
            {option.carrierDisplayName} · {option.programCode} v{option.programVersion}{option.unavailableReason ? ` · ${option.unavailableReason.replaceAll('_', ' ')}` : ''}
          </option>
        ))}
      </select>
      <p className={styles.context}>{model.mode === 'MULTIPLE' ? `${model.selectableCount} configured targets are available.` : model.mode === 'SINGLE' ? 'One configured target is available.' : 'No eligible target is available.'}</p>
      {!selectionEnabled && <p className={styles.warning}>The case must be in review, ready-for-carrier, or submitted state before its target can change.</p>}
      <button className={styles.actionButton} disabled={!selectionEnabled || !selectedId || state === 'saving' || model.mode === 'NONE'} onClick={save} type="button">
        {state === 'saving' ? 'Saving…' : 'Select target'}
      </button>
      {state === 'error' && <span className={styles.actionError} role="alert">Target could not be selected.</span>}
    </div>
  );
}
