# Technical Plan: Angular Presentation Migration

## Objective
Migrate Insure Me's web presentation layer from the current Next.js shell to Angular 22 without changing canonical insurance-domain authority, provider/carrier abstraction, compliance enforcement, storage semantics, or backend API contracts except where a separately reviewed contract gap is discovered.

## Architecture

```text
Angular Web Application
  |
  +-- public surfaces (prerender/SSR allowed)
  +-- applicant surface (CSR)
  +-- agent surface (CSR)
  +-- admin/compliance surfaces (CSR)
  |
  v
Typed API Client
  |
  v
Canonical Insure Me HTTP API
  |
  +-- tenant/auth
  +-- quote-core
  +-- notice-ledger
  +-- provider-gateway
  +-- normalization/policy/readiness
  +-- carrier-registry/gateway
  +-- privacy-rights
  +-- audit/notifications
  |
  v
Provider + Carrier Adapters / Persistence
```

Angular is not a trust boundary. Server-side services remain authoritative.

## Framework baseline
- Angular 22.x;
- standalone components;
- Angular Router with lazy feature routes;
- Angular Signals for local/feature presentation state;
- typed reactive forms for deterministic forms;
- schema-driven form rendering for versioned program/jurisdiction overlays;
- Angular HttpClient with functional interceptors;
- hybrid rendering only where public surfaces benefit;
- strict TypeScript;
- OpenAPI/JSON Schema-backed typed API client;
- deterministic synthetic fixture mode;
- component/contract/E2E testing.

## Application boundaries

### `core`
Cross-cutting runtime infrastructure only: auth session integration, API client configuration, request correlation, error normalization, security helpers, telemetry, environment/runtime configuration.

### `shared`
Reusable presentation primitives only: accessible controls, layout, formatting, form controls, loading/empty/error states. `shared` MUST NOT become a dumping ground for insurance business logic.

### `applicant`
Consumer quote workflow, notice/authorization presentation, household/driver/vehicle inputs, corrections, coverage request, review, save/resume, and status projection.

### `quoting`
Quote request/result presentation and comparison of carrier-returned decisions. It MUST NOT compute authoritative premium, eligibility, or underwriting decisions.

### `evidence`
Canonical ExternalReport/UnderwritingObservation projections, provenance, conflicts, NO_HIT, PARTIAL, STALE, and error states.

### `compliance`
Privacy rights, adverse-action support, disclosure history, deletion/retention status, audit evidence, and compliance workflow projections.

### `agent`
Case queue, readiness review, evidence inspection, permitted refresh initiation, correction workflows, carrier-program selection, and handoff preparation.

### `admin`
Tenant users/roles, provider/carrier configuration projections, versioned policy references, synthetic environment tooling, audit/system health.

## Client state model
Use three explicit state classes:

1. **Server state**: QuoteCase, consent, evidence, readiness, carrier submissions/decisions, privacy, audit. Server authoritative; cached client-side only for presentation.
2. **Workflow state**: current wizard step, selected tab, filters, unsaved draft control state. Signals are preferred.
3. **Derived presentation state**: computed completeness displays, badges, grouped evidence, visible sections. Computed Signals are preferred.

Do not introduce a global store until a concrete cross-feature problem requires it.

## Form architecture

### Static forms
Use typed reactive forms for stable fields.

### Variable questionnaires
Represent configurable fields in versioned server-delivered schemas. A field definition SHOULD include:
- stable field key;
- schema/configuration version;
- value type;
- required/optional rule;
- options/constraints;
- jurisdiction and CarrierProgram scope when applicable;
- source/provenance semantics;
- presentation hints that do not encode legal authority.

The renderer maps schema fields to controlled Angular components. The backend validates the authoritative contract independently.

## API client strategy
1. Treat canonical OpenAPI/JSON Schema as source of truth.
2. Generate or verify TypeScript request/response types and clients.
3. Wrap generated calls in narrow feature facades when orchestration or presentation mapping is needed.
4. Components MUST NOT call provider-specific or carrier-specific endpoints directly.
5. Contract drift MUST fail CI.

Recommended flow:

```text
OpenAPI / JSON Schema
      |
      +--> generated Angular TypeScript client
      +--> fixture validation
      +--> backend contract tests
      +--> frontend contract tests
```

## HttpClient and interceptors
Functional interceptors SHOULD handle:
- authentication token/cookie integration as appropriate;
- opaque request/correlation ID;
- CSRF/XSRF integration where applicable;
- normalized API error mapping;
- approved telemetry context.

Interceptors MUST NOT log raw PII, report payloads, secrets, credentials, license numbers, DOB, or other prohibited fields.

## Authentication and authorization
- Preserve existing identity provider and server-side auth contracts unless a separate migration requirement is approved.
- Angular guards may block/redirect navigation for UX.
- Server endpoints remain authoritative for authentication, tenant resolution, RBAC/ABAC, permissible purpose, consent prerequisites, and regulated actions.
- Never infer permission from the presence of a route, button, or client role claim alone.

## Rendering strategy
Use CSR by default for authenticated product surfaces. Use prerendering or SSR only for public pages where SEO or first-load behavior justifies it.

Sensitive per-user state MUST NOT be embedded into public caches or static artifacts.

## Synthetic development mode
Angular MUST run against deterministic synthetic APIs/fixtures that cover the existing canonical fixture classes:
- happy path;
- NO_HIT;
- multiple drivers/vehicles;
- conflicting records;
- stale report;
- provider outage;
- correction;
- adverse-action handoff;
- privacy deletion;
- unauthorized lookup;
- carrier adapter failure.

Synthetic mode MUST not require live provider/carrier credentials or production PII.

## Testing strategy

### Unit/component
- Signals and derived state;
- typed validators;
- schema field mapping;
- route behavior;
- error-state rendering;
- accessibility primitives.

### Contract
- generated client against canonical schema;
- error/status enum parity;
- NO_HIT/PARTIAL/STALE preservation;
- fixture/schema validation;
- prohibited provider/carrier-specific DTO leakage.

### E2E
- start/save/resume quote;
- notice/authorization;
- driver/vehicle intake;
- enrichment state presentation;
- evidence provenance/conflict review;
- agent readiness flow;
- carrier handoff via StubCarrierAdapter;
- privacy request;
- adverse-action support handoff;
- tenant isolation/authorization failures;
- provider failure and recovery.

## Security-specific migration checks
- inspect browser storage for prohibited fields;
- inspect client logs/telemetry for PII leakage;
- verify CSP and XSRF behavior for Angular deployment;
- verify no server secret is bundled into browser assets;
- verify route guards do not replace server authorization;
- verify source maps and error surfaces do not disclose sensitive data;
- verify public rendering cannot cache authenticated content.

## Migration phases

### M0 — Contract inventory and freeze
- inventory current frontend routes, API calls, auth/session assumptions, and P0 flows;
- identify OpenAPI/JSON Schema coverage gaps;
- freeze canonical domain/API behavior for the migration slice;
- classify any gap as frontend-only, contract defect, or separate backend change.

### M1 — Angular workspace and core shell
- create Angular 22 workspace;
- enable strict TypeScript;
- define feature routing and lazy boundaries;
- create core HttpClient/interceptor/error/auth plumbing;
- create shared accessibility/layout primitives;
- configure deterministic synthetic environment.

### M2 — Applicant parity
- migrate quote initiation;
- notice/authorization;
- household/drivers/vehicles;
- coverage request;
- review/save/resume;
- mobile usability and accessibility.

### M3 — Evidence and agent parity
- readiness dashboard;
- evidence provenance and conflict states;
- NO_HIT/PARTIAL/STALE/error UX;
- correction/refresh controls;
- carrier-program handoff preparation.

### M4 — Admin/compliance parity
- tenant/config projections;
- policy/version views;
- privacy-rights workflows;
- adverse-action support;
- audit evidence;
- synthetic/admin health surfaces.

### M5 — Contract, security, and performance hardening
- full contract tests;
- accessibility checks;
- sensitive-browser-storage audit;
- bundle/performance checks;
- CSP/XSRF review;
- tenant/auth negative tests;
- synthetic E2E acceptance.

### M6 — Cutover and retirement
- deploy Angular behind controlled routing/feature flag or parallel hostname/path;
- execute parity acceptance against the same backend;
- retain rollback path;
- cut over only after P0 gates pass;
- remove Next.js presentation code in a separate cleanup commit/PR after rollback window and evidence approval.

## Rollback strategy
Because canonical data and server APIs remain unchanged, presentation rollback SHOULD consist of routing traffic back to the prior frontend artifact/version. No regulated data migration reversal should be required solely because of the Angular cutover.

Any backend contract change discovered during migration MUST have independent migration/rollback treatment.

## Deployment assumptions
Hosting is intentionally separable from Angular. The build MUST produce a deployable artifact appropriate to the selected hosting model. Public SSR, if enabled, is optional and MUST NOT become a prerequisite for core authenticated workflows.

## Exit gate
Angular becomes the canonical presentation runtime only when:
- all P0 migration acceptance criteria pass;
- contract drift is zero for canonical endpoints used by the UI;
- prohibited sensitive browser persistence/logging checks pass;
- tenant/auth negative tests pass;
- StubCarrierAdapter core handoff passes end-to-end;
- accessibility baseline passes;
- rollback has been exercised or demonstrably verified;
- no unresolved migration defect changes insurance/compliance semantics by accident.
