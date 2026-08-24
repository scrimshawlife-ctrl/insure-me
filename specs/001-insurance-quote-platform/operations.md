# Operations and Production Readiness

## Operational objective
Run Insure Me as a high-sensitivity insurance workflow service with clear ownership, observable dependencies, controlled data lifecycle, tested recovery, and reversible integrations.

## Reliability contract

`reliability-v1` defines initial pilot/production targets. These are release requirements, not evidence that an undeployed environment currently meets them. A production launch remains blocked until monitoring and recovery rehearsals prove the targets for the selected Vercel and Supabase plans.

### Measurement rules

- SLO windows are rolling 30-day windows in UTC.
- Eligible traffic excludes approved maintenance and synthetic probes.
- Platform 5xx responses and timeouts count against availability. Valid 4xx policy, authentication, validation, not-found, conflict, and rate-limit responses do not.
- Provider/carrier business outcomes and remote latency are measured by capability binding and adapter version. They do not count as core platform failures when the platform records and presents their correct explicit state.
- A platform failure to dispatch, persist, reconcile, or present a dependency outcome counts against the applicable platform SLO.
- Telemetry must use opaque identifiers and must not contain raw PII, report content, credentials, authority-reference contents, or notice bodies.

### Service-level objectives

| SLI | Target | Threshold | Failure condition |
|---|---:|---:|---|
| Core request availability | 99.9% | rolling 30 days | eligible request returns unplanned 5xx or times out |
| Core request latency | 95% | 750 ms | eligible request exceeds threshold, excluding external provider/carrier network wait |
| Async work claim time | 99% | 5 minutes | eligible queued item remains unclaimed; suspended bindings and legal-hold-blocked work are excluded |
| Regulated-action audit atomicity | 100% | synchronous | successful regulated action lacks its required atomic AuditEvent |

At 99.9% monthly availability, the operational error budget is 43 whole minutes per 30-day window. The monitor may calculate the exact budget as 43.2 minutes; runbooks use 43 minutes to avoid overstating tolerance.

### Error-budget policy

- At 50% budget consumption before day 15, the service owner reviews burn rate and active changes.
- At 75% consumption in any window, pause nonessential production changes affecting the breached service.
- At 100% consumption, block ordinary production releases until the incident owner accepts an emergency fix or a recovery review confirms control.
- Any audit-atomicity miss, cross-agency access, integrity failure, or unauthorized regulated-data disclosure is an immediate incident and release freeze regardless of remaining availability budget.
- Dependency SLO breaches trigger the applicable provider/carrier kill switch and degraded-state runbook; they are never hidden by the core availability calculation.

### Canonical synthetic load profile

T901 runs `scripts/performance/load-test.mjs` against the production Next.js build in synthetic mode. After 20 warm-up requests, it sends 1,000 requests across `/` and `/api/health/readiness` at concurrency 20 with a five-second per-request timeout. The run passes only with at least 99.9% successful 2xx/3xx responses and combined p95 latency no greater than 750 ms. CI stores `load-test-report-v1.json` with the profile, targets, aggregate/route latency, throughput, failures, and verdict.

This profile detects application/edge regressions; it does not certify maximum capacity, database saturation, authenticated workflows, regulated mutations, queue throughput, provider/carrier performance, regional failover, or production hosting. Those require protected staging data, workload-specific authorization, and deployment-scale tests before launch. A result from a materially different runner or profile is not directly comparable without recording the changed environment and profile version.

## Service ownership
Before production, assign named owners for:
- product operations;
- application on-call;
- security incidents;
- privacy requests;
- compliance/legal escalation;
- provider relationships;
- carrier/Allstate relationship;
- database and backup operations;
- notification delivery.

## Runbooks required
1. Provider outage
2. Provider auth failure
3. Provider response schema drift
4. Duplicate provider order investigation
5. Carrier handoff failure
6. Duplicate carrier submission investigation
7. Consumer data correction
8. Privacy access/deletion/restriction request
9. FCRA/adverse-action support
10. Suspicious/unauthorized lookup
11. Lost/stolen workforce credential
12. Secret rotation
13. Data breach/security incident
14. Backup restore
15. Retention worker failure
16. Notice/template rollback
17. Emergency provider/carrier kill switch

## Health model
System health MUST distinguish:
- application health;
- database health;
- queue health;
- identity-provider health;
- provider capability health by vendor/product;
- carrier handoff health;
- notification health;
- audit pipeline health;
- retention/privacy worker health.

A provider outage MUST NOT incorrectly mark the entire platform healthy if it blocks quote completion.

## Operational metrics
Track without raw PII:
- quote starts/completions;
- state transition counts/durations;
- readiness blockers;
- provider latency and result status;
- provider no-hit/partial/error rate;
- carrier submission status;
- queue age/depth;
- notice delivery status;
- unauthorized access denials;
- privacy request age/SLA;
- retention backlog;
- audit event ingestion lag;
- auth/MFA failures.

## Alerting
P0/P1 alerts SHOULD include:
- provider credentials rejected across multiple requests;
- audit pipeline unavailable;
- cross-agency authorization anomaly;
- repeated purpose-denied requests by one actor;
- database unavailable;
- retention deletion job repeatedly failing;
- privacy request approaching SLA breach;
- carrier submissions stuck/duplicating;
- unexpected spike in report orders or exports.

## Deployment
- immutable build artifact;
- infrastructure/configuration versioned where possible;
- database migration reviewed before deploy;
- feature flags for real provider/carrier adapters;
- real integrations default OFF in new environments;
- staged rollout for provider/carrier changes;
- documented rollback for app + schema + integration configuration.

## Production change controls
Changes involving provider purpose codes, notice versions, data-use policy, retention, auth, permissions, carrier mappings, or sensitive-data storage require enhanced review and production evidence.

Notice release evidence MUST identify the exact tenant/agency, notice key/version/category, content hash, approval reference, approving actor/time, effective time, migration set, and application commit. Rollback retires the affected version and activates a separately approved prior/new version; it never edits or deletes legal copy already presented.

## Backup/restore
- encrypted backups;
- access limited to designated operators;
- routine restore rehearsal;
- test restores use isolated protected environments;
- deletion/retention implications documented;
- no ad-hoc production database copies to developer laptops.

## Disaster recovery
Before launch verify:
- the `reliability-v1` RPO/RTO targets below;
- dependency recovery order;
- DNS/edge recovery;
- identity fallback policy;
- database restore process;
- secret restoration/rotation;
- provider/carrier revalidation after recovery.

### Recovery objectives

| Component | RPO | RTO | Required recovery source |
|---|---:|---:|---|
| Application and versioned configuration | 0 minutes | 1 hour | immutable build artifact and version-controlled configuration |
| PostgreSQL system of record, including audit evidence | 5 minutes | 4 hours | encrypted backup plus point-in-time recovery |
| Durable queues and workers | 5 minutes | 4 hours | restored PostgreSQL queue state plus idempotent replay |
| Workforce and consumer identity | 5 minutes | 4 hours | Supabase Auth recovery capability plus session-revocation controls |

RPO is the maximum acceptable committed-data loss measured from the incident boundary. RTO is the maximum time to restore a verified controlled service, not merely to make an endpoint respond. These targets require plan capability, configuration evidence, and T902 restore-drill proof before production; absent evidence is `UNVERIFIED` and blocks launch.

### Recovery order

1. Contain the incident, block public traffic if scope is unclear, and freeze live provider/carrier execution.
2. Restore PostgreSQL to the selected recovery point and verify schema, tenant boundaries, integrity hashes, AuditEvents, policy versions, and idempotency records.
3. Restore identity capability; revoke or invalidate sessions whose safety is uncertain.
4. Restore the exact verified application artifact and versioned configuration.
5. Verify readiness, authorization, audit atomicity, notice/data-use/retention configuration, and privacy controls.
6. Resume durable workers in observe-only or bounded batches; reconcile claimed and ambiguous work before replay.
7. Revalidate every enabled provider and CarrierProgram independently.
8. Run a controlled smoke transaction, record recovery evidence, and resume traffic only under incident-owner authority.

DNS/edge recovery, secret rotation, and third-party revalidation run in parallel only when they cannot violate this dependency order. Lost secret material has no data RPO; it must be reissued or rotated, never reconstructed from logs or backups.

### Canonical restore drill

T902 runs `scripts/recovery/restore-drill.mjs` against the disposable local Supabase database after all migrations and pgTAP tests. It inserts synthetic agency and audit sentinels, creates a custom-format logical snapshot of the application-owned `public` and `private` schemas plus `supabase_migrations`, restores it into a separate database created from `template0`, and verifies:

- the exact synthetic agency and AuditEvent integrity evidence survived;
- AuditEvent RLS remains enabled;
- `authenticated` still cannot update AuditEvents;
- a current checked policy-inspection RPC and its authenticated execute grant exist;
- the latest migration identity matches the canonical migration set;
- the snapshot recovery point and measured restore duration stay within `reliability-v1` targets.

CI uploads `restore-drill-report-v1.json` on success or failure. The report contains timing, dump SHA-256, aggregate verification values, and verdict only; it never uploads the database dump or row payloads. The target database and dump are deleted after every attempt.

This proves the repository's logical backup/restore procedure and control preservation on an isolated Supabase-compatible PostgreSQL instance. It does not prove hosted backup availability, physical backup restoration, Supabase Auth user recovery, Storage object recovery, geographic failover, production-size restore time, or hosted PITR. Production therefore remains `UNVERIFIED` until the selected plan shows PITR enabled and a protected hosted rehearsal demonstrates the current database volume within the four-hour RTO.

## Provider kill switch
Each real provider capability MUST have an independently operable kill switch. Disabling a capability MUST:
- block new orders;
- preserve current case data;
- show operational state to agents;
- allow safe manual fallback where approved;
- emit an AuditEvent.

## Carrier kill switch
Carrier handoff can be independently disabled without shutting down consumer intake. Pending cases remain reviewable and are not resubmitted automatically after re-enable without idempotency validation.

## Support access
Support personnel receive no implicit broad PII access. Support elevation must be time-bound, reason-coded, approved where required, and audited.

## Compliance evidence export
Export operations track creation/download counts, failures, scope-too-large outcomes, and integrity failures using tenant-safe dimensions. Operators must not log manifests, purpose references, recipient references, provider evidence references, or download contents. Artifact hash mismatch is a security alert and blocks download.

## Launch checklist
- all P0 acceptance tests pass;
- production provider credentials validated;
- carrier handoff validated or intentionally manual;
- notice versions activated and approved;
- privacy links/workflows operational;
- retention policies active;
- backups and restore tested;
- audit pipeline verified;
- alerting verified;
- on-call ownership assigned;
- incident tabletop complete;
- security review complete;
- legal/compliance approval recorded;
- Allstate/carrier approval recorded.

## Post-launch
First 30 days require enhanced review of:
- denied lookup events;
- provider no-hit/partial rates;
- consumer corrections;
- agent handling time;
- privacy requests;
- unexpected data fields returned by providers;
- logging/redaction anomalies;
- carrier handoff errors;
- user accessibility feedback.
