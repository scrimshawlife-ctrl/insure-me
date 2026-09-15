# Feature Specification: Angular Presentation Migration

## Status
`DEFERRED MIGRATION SPEC / NOT ACTIVE CURRENT-RUNTIME WORK`.

This specification is retained as a future migration package. It does not supersede the locked Next.js runtime, reopen current tasks, or authorize parallel implementation. Activation requires a later owner decision under `../003-scalable-runtime-evolution/architecture-note.md`.

## Purpose
If activated, adopt Angular 22 as the canonical presentation architecture for Insure Me while preserving the existing insurance domain, compliance, provider, carrier, audit, data, and API contracts as framework-independent server-side authority.

This change is a presentation/runtime migration. It is not a rewrite of the insurance platform.

## Goals
1. Replace the current Next.js presentation shell with an Angular 22 application using standalone components, Angular Router, Signals, typed reactive forms, and HttpClient.
2. Preserve all canonical insurance-domain semantics and server-side authority defined by `001-insurance-quote-platform`.
3. Keep provider and carrier integrations behind existing capability interfaces and adapters.
4. Make consumer, agent, admin, compliance, and evidence workflows explicit Angular feature boundaries.
5. Use schema-driven forms for jurisdiction/program-variable questionnaires where practical.
6. Generate or maintain a typed client from canonical OpenAPI/JSON Schema contracts rather than duplicating API types manually.
7. Reuse deterministic synthetic fixtures for local development, CI, demos, component tests, contract tests, and end-to-end tests.
8. Support mobile-first responsive behavior without requiring a native app for MVP.
9. Permit hybrid rendering for public pages while keeping authenticated workflows client-rendered by default.
10. Provide a phased migration path with rollback and parity gates.

## Non-goals
- changing QuoteCase, Person, Driver, Vehicle, ExternalReport, UnderwritingObservation, RatingInput, CarrierSubmission, CarrierDecision, consent, privacy, retention, or audit semantics solely for Angular;
- moving provider credentials or provider SDK authority into the browser;
- moving rating, underwriting, adverse-action, or compliance authority into client code;
- introducing provider-name or carrier-name branching in the frontend domain model;
- replacing server-side authorization with route guards;
- making browser storage authoritative for regulated state;
- requiring SSR for authenticated quote or admin workflows;
- changing database vendors, provider vendors, carrier integrations, or live deployment certification as part of this migration.

## Personas and surfaces

### Prospect
Uses the mobile-first applicant flow for quote initiation, notice/authorization, household/driver/vehicle confirmation, coverage requests, corrections, save/resume, and status.

### Agent
Uses the agent workspace for readiness, provenance, conflicts, permitted refreshes, carrier/program handoff preparation, and follow-up.

### Agency Administrator
Uses administration surfaces for tenant users, roles, branding, provider bindings, carrier programs, policy versions, and operational controls.

### Compliance/Security Reviewer
Uses compliance surfaces for audit evidence, privacy requests, adverse-action support, retention, disputes, provider/carrier evidence, and configuration history.

## Functional requirements

### ANG-FR-001 Canonical framework
The primary web application MUST use Angular 22.x. New application code MUST use standalone components unless a documented compatibility reason requires otherwise.

### ANG-FR-002 Feature boundaries
The Angular application MUST organize code by domain/feature boundaries rather than one global `components/services/models` hierarchy. At minimum: `core`, `shared`, `applicant`, `quoting`, `evidence`, `compliance`, `agent`, and `admin`.

### ANG-FR-003 Server authority
Client state MUST be treated as a projection/cache of server-authoritative state. Browser state MUST NOT become authoritative for regulated decisions, consents, provider requests, carrier submissions, privacy-rights actions, or audit evidence.

### ANG-FR-004 Signals
Angular Signals SHOULD be used for local and feature-scoped UI state, derived state, filters, wizard state, selection state, and asynchronous presentation state where they reduce ambiguity. A global store MAY be introduced only when a documented cross-feature requirement justifies it.

### ANG-FR-005 Typed reactive forms
Insurance intake and administration forms MUST use typed reactive forms or an equivalent Angular-supported typed form model. Form validation MUST not duplicate server-side compliance or authorization rules as sole authority.

### ANG-FR-006 Schema-driven questionnaires
Program/jurisdiction-variable questions SHOULD be represented by versioned schema/configuration and rendered through reusable Angular form controls. Schema interpretation MUST preserve field provenance, required/optional status, jurisdiction/program context, and validation semantics.

### ANG-FR-007 Typed API client
The frontend MUST consume canonical HTTP contracts through a typed client generated from or verified against OpenAPI/JSON Schema. Handwritten frontend DTOs MUST NOT silently diverge from canonical contracts.

### ANG-FR-008 HttpClient boundary
All HTTP access MUST flow through Angular HttpClient or a documented wrapper built on it. Functional interceptors SHOULD provide authentication attachment, correlation/request IDs, error normalization, and telemetry context. Sensitive values MUST NOT be logged.

### ANG-FR-009 Route authorization
Angular route guards MAY improve navigation UX but MUST NOT be treated as authorization controls. Every protected server operation MUST independently enforce authentication, tenant context, role/permission, purpose, and domain rules.

### ANG-FR-010 Rendering modes
Public marketing/legal/help surfaces MAY use prerendering or SSR. Authenticated applicant, agent, admin, and compliance surfaces SHOULD use CSR by default unless a specific reviewed requirement justifies server rendering.

### ANG-FR-011 Synthetic fixture mode
The Angular application MUST support a deterministic synthetic mode that exercises the complete core workflow without live provider or carrier credentials.

### ANG-FR-012 Provider neutrality
Frontend domain contracts MUST represent canonical capability results such as evidence status, facts, provenance, no-hit, partial, stale, and error states. Provider-specific response types MUST remain at adapter boundaries.

### ANG-FR-013 Carrier neutrality
Frontend domain contracts MUST represent CarrierProgram and CarrierDecision semantics without carrier-name control flow. Carrier-specific UI MAY be rendered only from versioned program capability/configuration metadata.

### ANG-FR-014 Compliance projection
Compliance status displayed in Angular MUST be derived from canonical server records and policies. The client MAY explain, group, and visualize compliance state but MUST NOT silently infer legal permission or complete regulated actions without server confirmation.

### ANG-FR-015 Accessibility
The migrated Angular surfaces MUST preserve the existing WCAG 2.2 AA engineering baseline and mobile-first usability target.

### ANG-FR-016 Sensitive browser storage
Raw provider reports, license numbers, full DOB, secrets, carrier/provider credentials, and similarly high-risk data MUST NOT be persisted in localStorage, sessionStorage, IndexedDB, service-worker caches, analytics payloads, or client logs unless an explicit reviewed exception exists.

### ANG-FR-017 Error semantics
The UI MUST distinguish validation failure, authorization failure, consent/notice prerequisite failure, provider no-hit, provider partial, provider unavailable, stale evidence, carrier rejection, carrier ambiguity, and internal error when the server contract exposes that distinction.

### ANG-FR-018 Migration parity
The current frontend MUST NOT be retired until Angular parity passes the migration acceptance matrix for all P0 synthetic flows and protected workflows.

### ANG-FR-019 Rollback
The deployment design MUST permit rollback to the prior presentation shell without data migration reversal when the Angular release fails presentation/runtime acceptance.

### ANG-FR-020 No domain migration by convenience
A frontend implementation inconvenience MUST NOT justify changing canonical insurance entities, compliance rules, provider/carrier adapter semantics, or audit requirements without a separate spec change.

## Target application structure

```text
src/app/
  core/
    auth/
    api/
    config/
    errors/
    telemetry/
    security/
  shared/
    ui/
    forms/
    accessibility/
    formatting/
  applicant/
    application/
    consent/
    household/
    drivers/
    vehicles/
    properties/
    disclosures/
    review/
  quoting/
    quote-request/
    quote-results/
    comparison/
    quote-details/
  evidence/
    provider-results/
    provenance/
    discrepancies/
    no-hit/
  compliance/
    adverse-action/
    privacy/
    deletion/
    disclosures/
    audit/
  agent/
    dashboard/
    applicants/
    cases/
    quotes/
  admin/
    providers/
    policies/
    synthetic-data/
    audit/
    system-health/
```

## Rendering policy

| Surface | Default mode |
| --- | --- |
| Marketing/public product pages | prerender/SSR allowed |
| Privacy, disclosures, help | prerender/SSR allowed |
| Login | CSR |
| Applicant quote workflow | CSR |
| Quote results | CSR |
| Agent workspace | CSR |
| Admin console | CSR |
| Compliance console | CSR |

## Migration constraints
- Existing API contracts remain canonical.
- Existing synthetic fixtures remain canonical test inputs unless separately versioned.
- Existing backend authorization and policy checks remain mandatory.
- Existing tenant, provider, carrier, audit, notice, privacy, retention, and adverse-action invariants remain unchanged.
- No live production activation is implied by completion of this migration.

## Success criteria
- Angular executes all P0 synthetic consumer and agent flows end-to-end.
- No provider or carrier-specific frontend branching is required.
- Contract tests prove typed client compatibility with canonical API schemas.
- Browser persistence and logging checks show no prohibited sensitive data.
- Accessibility and mobile usability meet baseline.
- Current presentation shell can be removed only after parity and rollback gates pass.
