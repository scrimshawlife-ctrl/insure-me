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

### Canonical provider outage drill

T903 runs the canonical F009 MVR outage through the synthetic scenario harness and the provider orchestration boundary. The first execution deterministically returns `PROVIDER_UNAVAILABLE`; the drill requires the claimed request to return to pending with a categorized 60-second retry, no normalized facts, review-required quote state, no carrier submission, and blocked provider/aggregate quote-completion health. A second execution settles successfully and must return the required capability health to ready.

CI uploads `provider-outage-drill-report-v1.json` on success or failure. The report contains only fixture/dataset identity, capability and workflow statuses, categorized error/retry state, aggregate health, elapsed time, and verdict. It contains no consumer fields, subject/case identifiers, provider payloads, credentials, or raw errors. This proves deterministic fail-closed and recovery control shape only; live-provider behavior, production alert delivery, credential validity, and durable production retry execution remain `UNVERIFIED` deployment gates.

The served readiness endpoint consumes `PROVIDER_HEALTH_SNAPSHOT_JSON`, a monitoring-owned capability snapshot with an observation time, required capability list, and categorized statuses. Pilot and production return blocked health when the snapshot is absent, invalid, more than five minutes old, or shows a required capability unavailable. Synthetic mode may omit the snapshot. Snapshot contents remain low-risk operational dimensions and MUST NOT contain request, report, case, subject, or credential data.

### Canonical provider credential rotation drill

T904 exercises a provider-neutral two-slot credential contract. A new version is staged and validated before activation. After activation, a bounded verification must succeed before the prior version is revoked. Standby rejection leaves the current version unchanged; post-activation rejection rolls back to the prior version without revoking it. Staging, activation, rollback, and revocation are auditable state changes.

CI uploads `provider-credential-rotation-drill-report-v1.json` on success or failure. Evidence is limited to opaque version labels, categorized steps/results, timing, audit-event count, and verdict. Credential material, raw provider responses, endpoints, tenant/case/subject identifiers, and secret fingerprints are prohibited. This synthetic control-shape test does not verify a hosted secret manager, Supabase key rotation, a live provider credential, vendor-side revocation, production audit persistence, or zero-downtime production behavior; those remain `UNVERIFIED` launch gates.

### Canonical incident-response tabletop

T905 rehearses a suspected provider-credential exposure with possible regulated-data access. The scenario is P0 and immediately freezes ordinary releases plus live provider/carrier execution. The response follows the ten security-contract stages in order: detect, contain, preserve evidence, revoke/rotate credentials, identify affected scope, legal/compliance assessment, notification decision, eradicate/recover, validate controls, and record corrective actions. Legal/compliance and notification outcomes remain `PENDING_LEGAL_REVIEW`; recovery traffic remains blocked pending incident-owner authority.

CI uploads `incident-response-tabletop-report-v1.json` on success or failure. The report contains only scenario identity, impact categories, aggregate system counts, categorized actions, timing, and verdict. It prohibits PII, credential material/fingerprints, raw evidence, endpoint details, subject/case identifiers, and legal conclusions. This synthetic rehearsal does not verify production alerts, evidence custody, named responders, counsel/insurer/regulator/vendor contacts, notification deadlines, or production recovery; those remain `UNVERIFIED` launch gates.

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

T902 runs `scripts/recovery/restore-drill.mjs` against the disposable local Supabase database after all migrations and pgTAP tests. It inserts synthetic agency and audit sentinels, creates a custom-format logical snapshot of the application-owned `public` and `private` schemas plus `supabase_migrations`, and restores it into a separate database created from `template0`. The target receives only the Supabase compatibility prerequisites needed by application objects (`auth.uid()`, `auth.jwt()`, and `pgcrypto`), not Auth rows or managed-schema payloads. The drill then verifies:

- the exact synthetic agency and AuditEvent integrity evidence survived;
- AuditEvent RLS remains enabled;
- `authenticated` still cannot update AuditEvents;
- a current checked policy-inspection RPC and its authenticated execute grant exist;
- the latest migration identity matches the canonical migration set;
- the snapshot recovery point and measured restore duration stay within `reliability-v1` targets.

CI uploads `restore-drill-report-v1.json` on success or failure. The report contains timing, dump SHA-256, aggregate verification values, and verdict only; it never uploads the database dump or row payloads. The target database and dump are deleted after every attempt.

This proves the repository's logical backup/restore procedure and control preservation on an isolated Supabase-compatible PostgreSQL instance. It does not prove hosted backup availability, physical backup restoration, Supabase Auth user recovery, Storage object recovery, geographic failover, production-size restore time, or hosted PITR. Production therefore remains `UNVERIFIED` until the selected plan shows PITR enabled and a protected hosted rehearsal demonstrates the current database volume within the four-hour RTO.

## Canonical privacy-rights rehearsal

T906 runs `pnpm test:privacy-rights-rehearsal` against the disposable local Supabase database after migrations in the CI database lane. The rehearsal seeds only synthetic fixture setup records for tenant, consumer, QuoteCase, Driver, Vehicle, Coverage, policy, provider-binding, downstream external-request, retention-policy, and legal-hold evidence. It then exercises the existing application privacy services and Supabase persistence RPCs for intake, identity verification, discovery/export, correction, restriction, deletion, downstream propagation success/failure, retention-disposition closure, legal-hold blocking before retention with no destructive mutation, append-only audit immutability, idempotency/integrity replay, cross-tenant isolation, independent export-integrity tamper failure, missing/incompatible retention-policy evidence failure, exact persisted policy versions, and policy binding. It must include exactly seven request negative paths: unknown/inactive tenant host, failed identity verification, unverified request execution, cross-tenant host access, invalid export credential, policy/configuration binding mismatch, and idempotency/integrity mismatch.

CI uploads `privacy-rights-rehearsal-report-v1.json` on success or failure with `if-no-files-found: error`. The report is strictly aggregate and PII-free with this exact top-level allowlist only: `schemaVersion`, `contractVersions`, `syntheticFixture`, `workflowStates`, `aggregateCounts`, `downstreamStatus`, `timing`, `errorCode`, and `verdict`. It must not include `task`, `checks`, hashes, public references, raw exception/error messages, requester names, emails, phone numbers, addresses, quote/driver/vehicle row payloads, plaintext exports, status tokens, lookup hashes, ciphertext, encrypted payloads, raw vendor evidence refs, or Supabase credentials.

This proves the repository's synthetic privacy-rights control shape through production application services on a disposable Supabase-compatible database. It does not prove live identity verification, live vendor fulfillment, legal/compliance approval, production alert delivery, hosted Supabase behavior, or privacy SLA compliance.

## Canonical adverse-action rehearsal

T907 runs `pnpm test:adverse-action-rehearsal` against the disposable local Supabase database after migrations in the CI database lane. The rehearsal seeds only synthetic fixture setup records for tenant, workforce policy admin, QuoteCase, ExternalReport provenance, CarrierProgram, CarrierDecision, and NoticeDefinition evidence. It then exercises the existing `createAdverseActionCase`, `recordAdverseActionHandoff`, and `deliverAdverseActionNotice` services and checked RPCs for exact carrier decision/report provenance, explicit owner and ownership-policy snapshot, separate handoff, exact notice version/hash, exact adapter/policy descriptor, explicit delivered evidence, append-only audits, idempotency replay, and fail-closed direct-mutation behavior. It must include exactly nine negative paths: cross-tenant/case mismatch, missing contributing report, changed-input determination replay, delivery before handoff, notice hash mismatch, adapter/policy mismatch, live deployment with synthetic notice configuration, changed-input delivery replay, and direct evidence mutation.

CI uploads `adverse-action-rehearsal-report-v1.json` on success or failure with `if-no-files-found: error`. The report is strictly aggregate and PII-free with this exact top-level allowlist only: `schemaVersion`, `contractVersions`, `syntheticFixture`, `workflowStates`, `aggregateCounts`, `negativePaths`, `timing`, `errorCode`, and `verdict`. It must not include hashes, raw IDs beyond contract/version labels, notice bodies, report payloads, names, emails, phone numbers, addresses, exception stacks, secrets, JWTs, or raw delivery evidence refs.

This proves the repository's synthetic adverse-action control shape through production application services on a disposable Supabase-compatible database. It does not prove live CRA/provider authorization, carrier adverse-action ownership approval, legal/compliance approval, live notice delivery, hosted Supabase behavior, or production SLA compliance.

## Independent security assessment readiness

T908 readiness runs `pnpm security-assessment:readiness` against externally supplied assessment metadata. The assessor packet must be prepared outside CI by an independent assessor or assessment coordinator and must contain only aggregate metadata: the exact selected deployment and configuration version, the independent assessor attestation reference, required scope categories, aggregate finding counts by severity/status, and evidence-presence flags. Raw findings, exploit detail, PII, secrets, credentials, endpoint inventories, provider/carrier evidence refs, and report bodies are not accepted by the CI artifact.

CI uploads `security-assessment-readiness-report-v1.json` on success or failure with `if-no-files-found: error`. The report is strictly aggregate and PII-free with this exact top-level allowlist only: `schemaVersion`, `contractVersions`, `selectedDeployment`, `assessorAttestation`, `scopeCategories`, `aggregateFindingCounts`, `externalEvidence`, `timing`, `errorCode`, and `verdict`. The validator fails closed as `BLOCKED` when selected-deployment binding, independent attestation, required scope, external evidence, or zero open critical/high findings are not proven.

A `READY_FOR_ASSESSMENT` verdict only proves the repository can intake a sanitized assessor packet for the selected deployment boundary. T908 remains `UNVERIFIED` until an independent assessor actually performs the assessment against the selected deployment. Any open critical/high finding is handed to T909 and blocks launch until independently tracked remediation evidence closes it.

## Critical/high findings disposition readiness
T909 readiness runs `pnpm security-findings:disposition-readiness` against externally supplied aggregate disposition metadata. The packet must be prepared outside CI and copy the exact T908 selected deployment, configuration version, independent assessor attestation, externally controlled finding register, and aggregate critical/high baseline counts. Its independent closure attestation must repeat and exactly bind to the selected deployment and `assessmentBinding.findingRegisterRef`. It contains only aggregate critical/high counts and evidence-presence flags; raw findings, finding identifiers, exploit detail, endpoints, PII, secrets, credentials, report bodies, and raw remediation or retest evidence are not accepted.

CI executes the gate with `if: always()` and uploads `security-findings-disposition-readiness-report-v1.json` on success or failure with `if: always()` and `if-no-files-found: error`. The exact top-level allowlist is `schemaVersion`, `contractVersions`, `selectedDeployment`, `assessmentBinding`, `aggregateDispositionCounts`, `independentClosureAttestation`, `externalEvidence`, `timing`, `errorCode`, and `verdict`. The validator fails closed when the exact T908 deployment or assessor-attestation binding is unproven, T908 critical/high baseline counts do not reconcile, any critical/high finding remains open or accepted as risk, remediation or independent retest does not cover every assessed critical/high finding, the independent closure attestation is absent or does not exactly bind to the selected deployment and finding register, or required external evidence is missing. Invalid closure-attestation references and timestamps are emitted as `UNVERIFIED` on every blocked path rather than copied into the artifact.

A `READY_FOR_DISPOSITION_REVIEW` verdict proves only that the repository can intake a sanitized aggregate disposition packet and apply the fail-closed reconciliation contract. The synthetic CI fixture proves validator shape only. T908 and T909 remain `UNVERIFIED`; the verdict does not prove an assessment occurred, remediation was effective, production security is certified, or launch is approved.

## Legal/compliance launch-approval readiness
T911 readiness runs `pnpm legal-compliance:approval-readiness` against sanitized aggregate metadata bound to the exact selected deployment and TenantConfiguration ID, tenant, agency, and configuration version. It requires the production compliance-gate approval domains, the canonical compliance/control domains, and resolved selected-deployment decision metadata for Q-001 through Q-010. Every approval-domain, control-domain, and open-question record explicitly repeats the selected environment, deployment reference, TenantConfiguration ID, tenant ID, agency ID, and configuration version; the validator compares all six fields exactly to `selectedDeployment` and does not trust `exactBinding` alone. Only approval-domain and open-question records carry opaque owner/authority/evidence references; control-domain records carry opaque evidence references. Reserved missing/status sentinel values are rejected as input references.

CI runs and uploads `legal-compliance-approval-readiness-report-v1.json` on success or failure with `if: always()` and `if-no-files-found: error`. The exact top-level allowlist is `schemaVersion`, `contractVersions`, `selectedDeployment`, `approvalDomains`, `controlDomains`, `openQuestionBlockers`, `externalEvidence`, `timing`, `errorCode`, and `verdict`. Recursive forbidden raw-evidence keys fail closed, and unsafe or reserved input references are emitted as `UNVERIFIED` on every blocked path. `READY_FOR_APPROVAL_REVIEW` proves validator shape only. It does not claim legal review, approval, authority, a deadline, certification, or launch authorization; T911 and all real approvals remain `UNVERIFIED`.

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

## Repository-native security scanner baseline operations
T101 runs three local CI gates before build and deployment evidence collection: `pnpm security:secrets`, `pnpm security:sast`, and `pnpm security:dependencies`. The first two scan tracked source/config files using dependency-free repository scripts and local high-signal rules. The dependency gate wraps `pnpm audit --prod --audit-level high --json` and emits aggregate counts only.

All three commands write strict aggregate artifacts on pass or fail under `artifacts/`: `secret-baseline-report-v1.json`, `sast-baseline-report-v1.json`, and `pnpm-audit-baseline-report-v1.json`. Operators must treat these artifacts as safe-to-upload CI evidence because they exclude matched source, secret material, paths, raw advisories, endpoints, stack traces, consumer data, provider/carrier refs, and error text. A failing artifact identifies only aggregate rule or severity counts; investigation must be performed locally by an authorized engineer without copying suspected secrets or PII into tickets or logs. Explicitly synthetic fixture placeholders are the only local allowances and must not be broadened into path-wide suppressions.

These baselines satisfy T101 only. They do not complete T908 and do not replace an independent penetration test or security assessment.
