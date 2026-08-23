export interface CarrierProgramOptionInput {
  carrierProgramId: string;
  carrierDisplayName: string;
  programCode: string;
  programVersion: number;
  handoffMode: string;
  certificationState: string;
  killSwitchEnabled: boolean;
}

export interface CarrierProgramOption extends CarrierProgramOptionInput {
  selectable: boolean;
  unavailableReason: 'KILL_SWITCHED' | 'NOT_CERTIFIED' | null;
  selected: boolean;
}

export interface CarrierProgramSelectionModel {
  mode: 'NONE' | 'SINGLE' | 'MULTIPLE';
  options: CarrierProgramOption[];
  selectableCount: number;
}

const SELECTABLE_CERTIFICATION_STATES = new Set(['SYNTHETIC', 'SANDBOX', 'CERTIFIED']);

export function buildCarrierProgramSelectionModel(
  programs: CarrierProgramOptionInput[],
  selectedCarrierProgramId: string | null,
): CarrierProgramSelectionModel {
  const options = programs.map((program) => {
    const unavailableReason = program.killSwitchEnabled
      ? 'KILL_SWITCHED' as const
      : !SELECTABLE_CERTIFICATION_STATES.has(program.certificationState)
        ? 'NOT_CERTIFIED' as const
        : null;
    return {
      ...program,
      selectable: unavailableReason === null,
      unavailableReason,
      selected: program.carrierProgramId === selectedCarrierProgramId,
    };
  });
  const selectableCount = options.filter((option) => option.selectable).length;
  return {
    mode: selectableCount === 0 ? 'NONE' : selectableCount === 1 ? 'SINGLE' : 'MULTIPLE',
    options,
    selectableCount,
  };
}
