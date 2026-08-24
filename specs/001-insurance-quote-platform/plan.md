# Technical Plan

## Objective
Implement Insure Me as a compliance-first insurance quote intake and orchestration platform with a carrier-, agency-, and data-provider-agnostic core. Carrier programs own rating, eligibility, binding, and policy issuance unless authority is explicitly delegated.

The two-door operator model is configuration on this kernel. Read
`two-door-plan.md`. Do not fork canonical domain objects to add a second door.

## Reference architecture

```text
Consumer Web/App
      |
      v
Edge/API Gateway
      |
      +--> Tenant Resolution
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
      +--> Tenant configuration
      +--> Carrier-program field overlays
      +--> Readiness engine
      +--> Conflict detection
      |
      +---------------------------+
      |                           |
      v                           v
Agent Workspace             Carrier Registry
                                  |
                                  v
                            Carrier Gateway
                              +--> Stub adapter
                              +--> API
                              +--> Deep link
                              +--> AMS/comparative-rater bridge
                              +--> Structured export/import
                              +--> Controlled manual handoff
```

## Architectural boundaries

### Consumer boundary
Owns quote initiation, minimal data collection, notice/authorization, verification, confirmation/editing, coverage request, corrections, and status.

### Tenant/agency boundary
Owns workforce access, branding, operational configuration, case review, exception resolution, permitted provider requests, configured carrier programs, follow-up, and administrative policy references.

### Provider boundary
All external data access passes through provider adapters with explicit tenant, jurisdiction, purpose, subject, and trace context. Provider names MUST NOT become canonical domain terminology.

### Carrier boundary
Every live carrier integration is an adapter plus versioned `CarrierProgram` configuration. Premium, eligibility, binding, and policy issuance remain carrier-owned unless an explicit contract delegates authority. No core service may branch on a carrier name.

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
1. `tenant-config`: tenant/agency identity, branding, jurisdiction/product enablement, provider bindings, and carrier-program bindings.
2. `quote-core`: QuoteCase lifecycle and domain invariants.
3. `identity`: consumer session identity and agency workforce identity.
4. `notice-ledger`: versioned notices, acknowledgments, and authorizations.
5. `provider-gateway`: adapter execution, retries, idempotency, purpose enforcement.
6. `normalization`: canonical schemas and provenance.
7. `policy-engine`: jurisdiction, data-use, retention, provider, and carrier-program rules. This is not a pricing engine.
8. `readiness`: completeness and blocking-issue calculation, including configured carrier-program overlays.
9. `carrier-registry`: carrier/program capability descriptors, certification state, and kill switches.
10. `carrier-gateway`: carrier-neutral handoff execution.
11. `privacy-rights`: access/correction/deletion/restriction workflows.
12. `audit`: append-only evidence events.
13. `notifications`: transactional email/SMS and notice delivery.
14. `admin`: tenant users, roles, provider/carrier config, policy versions, and compliance evidence.

## Data storage strategy
- relational canonical records for TenantConfiguration, Agency, QuoteCase, people, drivers, vehicles, coverage, consents, observations, issues, Carrier, CarrierProgram, carrier submissions/decisions, privacy requests, and audit indexes;
- encrypted sensitive fields for license number, DOB, and other high-risk identifiers;
- raw external report storage disabled by default and enabled only per provider contract + retention approval;
- immutable normalized report snapshot/version for evidence where permitted;
- version every tenant/provider/carrier configuration referenced by a regulated action;
- no secrets or production PII in source control;
- no production PII in analytics events.

## Provider request execution pattern
For every provider request:
1. validate authenticated actor/service principal;
2. resolve tenant and immutable configuration version;
3. load QuoteCase and jurisdiction;
4. evaluate permissible purpose;
5. evaluate notice/authorization prerequisites;
6. evaluate configured provider capability for jurisdiction/product;
7. enforce data minimization/request scope;
8. create pending ExternalRequest with idempotency key;
9. call provider adapter;
10. persist response metadata and normalized facts;
11. create UnderwritingObservations;
12. recalculate readiness;
13. emit AuditEvent.

Any failed prerequisite MUST fail closed before provider execution.

## Carrier handoff execution pattern
For every carrier submission:
1. resolve tenant configuration and target CarrierProgram version;
2. verify CarrierProgram is enabled, certified for the environment, and not kill-switched;
3. verify jurisdiction and product-line support;
4. calculate carrier-program-specific required-field readiness;
5. build the submission only from the approved RatingInput/submission allowlist;
6. validate the adapter capability descriptor and handoff mode;
7. create an idempotent CarrierSubmission;
8. execute the adapter or controlled manual handoff;
9. persist external reference and response as CarrierDecision when returned;
10. preserve carrier/program/configuration provenance;
11. emit AuditEvent.

A carrier-specific mapping MAY transform canonical data at the boundary. It MUST NOT mutate the canonical domain schema.

## Idempotency
Quote creation, provider orders, notice deliveries, privacy requests, and carrier submissions MUST use idempotency keys. Duplicate provider charges and duplicate carrier submissions are release-blocking defects.

## Resilience
- classify provider errors: validation, authorization, throttling, unavailable, timeout, no-hit, partial, stale, contract restriction;
- classify carrier errors: configuration, unsupported jurisdiction/product, validation, authentication, unavailable, timeout, rejected, ambiguous status;
- bounded retries for transient failures only;
- circuit breaker per provider/capability and per carrier adapter;
- dead-letter/manual-review path for non-deterministic failures;
- no automatic provider substitution when legal/disclosure semantics differ unless explicitly configured;
- no automatic carrier substitution after submission without an explicit new submission action;
- degraded mode allows consumer intake and synthetic workflows to continue when live enrichment or carrier systems are unavailable.

## Security architecture
- MFA for agency workforce;
- short-lived consumer session tokens;
- RBAC/ABAC using tenant, agency, role, case, jurisdiction, capability, and carrier-program context;
- encrypted transport and storage;
- field-level encryption/tokenization for high-risk identifiers where practical;
- managed KMS/secret store;
- carrier/provider credentials isolated by tenant and environment;
- CSP, CSRF protection, secure cookies, rate limits, bot/abuse controls;
- append-only audit evidence;
- separate production and non-production data planes;
- vendor egress allowlisting where practical.

## Environments
- local: deterministic synthetic provider adapters + `StubCarrierAdapter` only;
- CI: deterministic synthetic provider adapters + `StubCarrierAdapter` only;
- staging: synthetic by default; approved provider/carrier sandboxes MAY be enabled independently;
- production: real consumer data; only certified production provider and carrier configurations may activate.

Cross-environment data copying from production is prohibited unless formally approved and irreversibly de-identified.

## Delivery phases

### Phase 0: Governance framework
Define tenant/operator model, provider procurement requirements, legal notices, ownership matrix, data-use/retention governance, carrier certification framework, and security baseline. Unknown live vendors/carriers do not block synthetic implementation.

### Phase 1: Domain kernel
TenantConfiguration, QuoteCase, users/roles, Carrier/CarrierProgram, data model, audit, policy rules, and synthetic fixtures.

### Phase 2: Consumer intake
Mobile-first quote flow, notice ledger, drivers, vehicles, coverage request, save/resume, and tenant presentation.

### Phase 3: Provider gateway
Stub adapters first, then individually certified sandbox integrations for identity/prefill/MVR/claims/vehicle data.

### Phase 4: Agent workspace
Readiness, provenance, conflicts, corrections, refresh controls, carrier/program selection, and handoff preparation.

### Phase 5: Carrier gateway
Implement and fully accept `StubCarrierAdapter`; then certify concrete carrier/program adapters independently without changing core domain behavior.

### Phase 6: Privacy/compliance operations
Privacy-rights console, adverse-action support, retention jobs, evidence exports, vendor/audit tooling.

### Phase 7: Production hardening
Threat model, penetration test, disaster recovery, load tests, provider/carrier failure drills, and deployment-specific launch acceptance.

## Migration strategy
Schema migrations MUST be forward-compatible where possible, reviewed for sensitive-data impact, reversible or paired with a documented recovery plan, and exercised in staging before production. Carrier/provider mapping changes SHOULD be configuration-version migrations rather than canonical schema migrations whenever possible.

## Observability
Track latency, error class, tenant-safe dimensions, provider request status, carrier adapter/mode status, queue depth, readiness transitions, handoff status, notice delivery, privacy SLA, and authorization failures. Use opaque IDs; do not log raw reports, DOB, license numbers, unredacted VINs, or consumer-report contents.

## Open implementation decisions
- hosting provider;
- database vendor;
- workforce authentication vendor;
- notification vendor;
- first live MVR/claims/identity providers;
- first live carrier/program adapter and handoff mode;
- whether individual report payloads may be persisted or only transiently processed;
- exact retention periods by record class;
- exact native-mobile delivery model after responsive web validation.

These decisions affect deployment certification, not the synthetic core-build path. Each remains `UNVERIFIED` until contract or authorized-owner evidence exists.
