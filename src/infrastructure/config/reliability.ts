export const reliabilityContractVersion = 'reliability-v1' as const;

export const serviceLevelObjectives = [
  {
    id: 'core-request-availability',
    windowDays: 30,
    targetPercent: 99.9,
    indicator: 'eligible core requests completed without an unplanned platform 5xx response',
    exclusions: ['approved maintenance', 'synthetic probes', 'provider/carrier execution outcome'],
  },
  {
    id: 'core-request-latency-p95',
    windowDays: 30,
    targetPercent: 95,
    thresholdMilliseconds: 750,
    indicator: 'eligible core requests complete within threshold',
    exclusions: ['approved maintenance', 'synthetic probes', 'provider/carrier network wait'],
  },
  {
    id: 'async-work-claim-time',
    windowDays: 30,
    targetPercent: 99,
    thresholdMilliseconds: 300_000,
    indicator: 'eligible queued work is claimed within threshold',
    exclusions: ['approved maintenance', 'intentionally suspended bindings', 'legal-hold blocked work'],
  },
  {
    id: 'regulated-action-audit-atomicity',
    windowDays: 30,
    targetPercent: 100,
    indicator: 'successful regulated actions persist their required AuditEvent atomically',
    exclusions: [],
  },
] as const;

export const recoveryObjectives = [
  {
    component: 'application-and-versioned-configuration',
    rpoMinutes: 0,
    rtoMinutes: 60,
    recoverySource: 'immutable build artifact and version-controlled configuration',
  },
  {
    component: 'postgres-system-of-record',
    rpoMinutes: 5,
    rtoMinutes: 240,
    recoverySource: 'encrypted backup plus point-in-time recovery',
  },
  {
    component: 'durable-queues-and-workers',
    rpoMinutes: 5,
    rtoMinutes: 240,
    recoverySource: 'restored PostgreSQL queue state and idempotent worker replay',
  },
  {
    component: 'workforce-and-consumer-identity',
    rpoMinutes: 5,
    rtoMinutes: 240,
    recoverySource: 'Supabase Auth recovery capability and session revocation controls',
  },
] as const;

export const recoveryOrder = [
  'contain-and-freeze-live-integrations',
  'restore-database-and-verify-integrity',
  'restore-identity-and-revoke-unsafe-sessions',
  'restore-application-and-versioned-configuration',
  'verify-audit-and-policy-controls',
  'restore-queues-and-workers',
  'revalidate-provider-and-carrier-bindings',
  'resume-controlled-traffic',
] as const;

export const monthlyAvailabilityErrorBudgetMinutes = 43;
