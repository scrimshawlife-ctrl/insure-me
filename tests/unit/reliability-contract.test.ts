import { describe, expect, it } from 'vitest';

import { monthlyAvailabilityErrorBudgetMinutes, recoveryObjectives,
  recoveryOrder, reliabilityContractVersion, serviceLevelObjectives } from '@/src/infrastructure/config/reliability';

describe('reliability contract', () => {
  it('locks measurable service objectives without folding provider outcomes into core availability', () => {
    expect(reliabilityContractVersion).toBe('reliability-v1');
    expect(serviceLevelObjectives.map((objective) => objective.id)).toEqual([
      'core-request-availability', 'core-request-latency-p95',
      'async-work-claim-time', 'regulated-action-audit-atomicity',
    ]);
    expect(serviceLevelObjectives[0].targetPercent).toBe(99.9);
    expect(serviceLevelObjectives[0].exclusions).toContain('provider/carrier execution outcome');
    expect(monthlyAvailabilityErrorBudgetMinutes).toBe(43);
  });

  it('requires bounded recovery for every stateful platform dependency', () => {
    expect(recoveryObjectives.every((objective) => objective.rpoMinutes <= 5)).toBe(true);
    expect(recoveryObjectives.every((objective) => objective.rtoMinutes <= 240)).toBe(true);
    expect(recoveryObjectives.find((objective) => objective.component === 'application-and-versioned-configuration')?.rpoMinutes).toBe(0);
    expect(recoveryOrder.at(-1)).toBe('resume-controlled-traffic');
  });
});
