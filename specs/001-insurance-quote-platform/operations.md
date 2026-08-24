# Operations and Production Readiness

## Operational objective
Run Insure Me as a high-sensitivity insurance workflow service with clear ownership, observable dependencies, controlled data lifecycle, tested recovery, and reversible integrations.

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

## Backup/restore
- encrypted backups;
- access limited to designated operators;
- routine restore rehearsal;
- test restores use isolated protected environments;
- deletion/retention implications documented;
- no ad-hoc production database copies to developer laptops.

## Disaster recovery
Before launch define:
- RPO;
- RTO;
- dependency recovery order;
- DNS/edge recovery;
- identity fallback policy;
- database restore process;
- secret restoration/rotation;
- provider/carrier revalidation after recovery.

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
