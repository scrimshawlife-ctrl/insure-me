# Technical Plan

## Objective
Implement Insure Me as a compliance-first quote intake and orchestration platform that remains provider-agnostic and carrier-controlled for rating/binding.

## Reference architecture

```text
Consumer Web/App
      |
      v
Edge/API Gateway
      |
      +--> Identity/Auth
      +--> Quote Service
      +--> Consent/Notice Service
      +--> Privacy Rights Service
      +--> Audit Service
      |
      v
Provider Gateway
  +--> Identity Adapter
  +--> Prefill Adapter
  +--> MVR Adapter
  +--> Claims Adapter
  +--> Vehicle Adapter
  +--> Insurance History Adapter
      |
      v
Normalization + Policy Layer
      |
      +--> Data-use classification
      +--> Jurisdiction rules
      +--> Readiness engine
      +--> Conflict detection
      |
      v
Agent Workspace
      |
      v
Carrier Gateway
      +--> Redirect/deep link
      +--> Secure export
      +--> API adapter when approved
```

## Architectural boundaries
### Consumer boundary
Owns quote initiation, minimal data collection, notice/authorization, verification, confirmation/editing, coverage request, corrections, and status.

### Agency boundary
Owns staff authentication, case review, exception resolution, provider refresh requests, carrier handoff, follow-up, and administrative configuration.

### Provider boundary
All external data access passes through provider adapters with explicit jurisdiction, purpose, subject, and trace context.

### Carrier boundary
Premium, eligibility, binding, and policy issuance remain carrier-owned unless a later contract delegates authority.

## Suggested implementation stack
Stack is intentionally non-binding until runtime planning begins. Preferred baseline:
- TypeScript;
- Next.js or equivalent responsive web framework for consumer + agent surfaces;
- PostgreSQL-compatible relational store;
- object storage only when contractually permitted for reports/documents;
- managed authentication for agency users with MFA;
- managed secret store/KMS;
- queue for provider jobs and notice delivery;
- structured audit/event pipeline;
- OpenTelemetry-compatible observability without raw PII.

A native mobile app is not required for MVP if the responsive consumer web flow meets mobile usability requirements. Native wrappers can follow later.

## Core services/modules
1. `quote-core`: QuoteCase lifecycle and domain invariants.
2. `identity`: consumer session identity and agency workforce identity.
3. `notice-ledger`: versioned notices, acknowledgments, and authorizations.
4. `provider-gateway`: adapter execution, retries, idempotency, purpose enforcement.
5. `normalization`: canonical schemas and provenance.
6. `policy-engine`: jurisdiction, data-use, retention, and capability rules. This is not a pricing engine.
7. `readiness`: completeness and blocking-issue calculation.
8. `carrier-gateway`: approved handoff mechanisms.
9. `privacy-rights`: access/correction/deletion/restriction workflows.
10. `audit`: append-only evidence events.
11. `notifications`: transactional email/SMS and notice delivery.
12. `admin`: agency users, roles, provider/carrier config, policy versions.

## Data storage strategy
- relational canonical records for QuoteCase, people, drivers, vehicles, coverage, consents, observations, issues, carrier submissions, privacy requests, and audit indexes;
- encrypted sensitive fields for license number, DOB, and other high-risk identifiers;
- raw external report storage disabled by default and enabled only per provider contract + retention approval;
- immutable normalized report snapshot/version for evidence where permitted;
- no secrets or production PII in source control;
- no production PII in analytics events.

## Request execution pattern
For every provider request:
1. validate authenticated actor/service principal;
2. load QuoteCase and jurisdiction;
3. evaluate permissible purpose;
4. evaluate notice/authorization prerequisites;
5. evaluate provider capability for jurisdiction;
6. enforce data minimization/request scope;
7. create pending ExternalRequest record with idempotency key;
8. call provider adapter;
9. persist response metadata and normalized facts;
10. create UnderwritingObservations;
11. recalculate readiness;
12. emit AuditEvent.

Any failed prerequisite MUST fail closed before provider execution.

## Idempotency
Quote creation, provider orders, notice deliveries, privacy requests, and carrier submissions MUST use idempotency keys. Duplicate provider charges and duplicate carrier submissions are release-blocking defects.

## Resilience
- classify provider errors: validation, authorization, throttling, unavailable, timeout, no-hit, partial, stale, contract restriction;
- bounded retries for transient failures only;
- circuit breaker per provider/capability;
- dead-letter queue for manual review;
- no automatic substitution to another provider when legal/disclosure semantics differ unless explicitly configured;
- degraded mode allows consumer intake to continue when enrichment is unavailable.

## Security architecture
- MFA for agency workforce;
- short-lived consumer session tokens;
- RBAC/ABAC using agency, role, case, jurisdiction, and capability;
- encrypted transport and storage;
- field-level encryption/tokenization for high-risk identifiers where practical;
- managed KMS/secret store;
- CSP, CSRF protection, secure cookies, rate limits, bot/abuse controls;
- append-only audit evidence;
- separate production and non-production data planes;
- vendor egress allowlisting where practical.

## Environments
- local: synthetic only;
- CI: synthetic only;
- staging: synthetic by default, limited approved sandbox vendor data only;
- production: real consumer data and production provider credentials.

Cross-environment data copying from production is prohibited unless formally approved and irreversibly de-identified.

## Delivery phases
### Phase 0: Governance and contracts
Resolve Allstate integration authority, provider procurement, legal notices, ownership matrix, security baseline.

### Phase 1: Domain kernel
QuoteCase, users/roles, data model, audit, policy rules, synthetic fixtures.

### Phase 2: Consumer intake
Mobile-first quote flow, notice ledger, drivers, vehicles, coverage request, save/resume.

### Phase 3: Provider gateway
Stub adapters first, then approved sandbox integrations for identity/prefill/MVR/claims/vehicle data.

### Phase 4: Agent workspace
Readiness, provenance, conflicts, corrections, refresh controls, handoff preparation.

### Phase 5: Carrier handoff
Implement the approved Allstate/carrier mode only after authority is documented.

### Phase 6: Privacy/compliance operations
Privacy-rights console, adverse-action support, retention jobs, evidence exports, vendor/audit tooling.

### Phase 7: Production hardening
Threat model, penetration test, disaster recovery, load tests, provider failure drills, launch acceptance.

## Migration strategy
Schema migrations MUST be forward-compatible where possible, reviewed for sensitive-data impact, reversible or paired with a documented recovery plan, and exercised in staging before production.

## Observability
Track latency, error class, provider request status, queue depth, readiness transitions, handoff status, notice delivery, privacy SLA, and authorization failures. Use opaque IDs; do not log raw reports, DOB, license numbers, VINs unless explicitly redacted/tokenized, or consumer report contents.

## Open implementation decisions
- hosting provider;
- database vendor;
- agency authentication vendor;
- notification vendor;
- exact MVR/claims/identity providers;
- Allstate handoff mode;
- whether report payloads can be persisted or only transiently processed;
- exact retention periods by record class;
- exact mobile delivery model after responsive web validation.

Each remains `UNVERIFIED` until contract or owner evidence exists.
