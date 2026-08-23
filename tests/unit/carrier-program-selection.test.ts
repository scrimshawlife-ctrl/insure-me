import { describe, expect, it } from 'vitest';

import { buildCarrierProgramSelectionModel } from '@/src/application/agent/carrier-program-selection';

const base = {
  carrierDisplayName: 'Synthetic Carrier',
  programCode: 'AUTO',
  programVersion: 1,
  handoffMode: 'STUB',
  certificationState: 'SYNTHETIC',
  killSwitchEnabled: false,
};

describe('carrier program selection model', () => {
  it('uses a single-target mode when exactly one program is eligible', () => {
    const model = buildCarrierProgramSelectionModel([{ ...base, carrierProgramId: 'program-a' }], null);
    expect(model.mode).toBe('SINGLE');
    expect(model.selectableCount).toBe(1);
  });

  it('uses a multiple-target mode without carrier-name branching', () => {
    const model = buildCarrierProgramSelectionModel([
      { ...base, carrierProgramId: 'program-a' },
      { ...base, carrierProgramId: 'program-b', programCode: 'AUTO-B' },
    ], 'program-b');
    expect(model.mode).toBe('MULTIPLE');
    expect(model.options.find((option) => option.selected)?.carrierProgramId).toBe('program-b');
  });

  it('disables killed and uncertified programs', () => {
    const model = buildCarrierProgramSelectionModel([
      { ...base, carrierProgramId: 'killed', killSwitchEnabled: true },
      { ...base, carrierProgramId: 'draft', certificationState: 'DRAFT' },
    ], null);
    expect(model.mode).toBe('NONE');
    expect(model.options.map((option) => option.unavailableReason)).toEqual(['KILL_SWITCHED', 'NOT_CERTIFIED']);
  });
});
