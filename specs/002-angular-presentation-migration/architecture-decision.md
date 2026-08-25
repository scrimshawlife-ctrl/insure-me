# Architecture Decision: Angular 22 Presentation Runtime

## Decision
**Status:** Proposed for canonical adoption by merge of this change.

Insure Me will use Angular 22.x as the canonical web presentation runtime for new frontend implementation and migration work.

This decision supersedes the non-binding frontend-framework suggestion in `specs/001-insurance-quote-platform/plan.md` for presentation implementation only. It does not supersede the reference architecture, service boundaries, domain model, API contracts, compliance controls, provider/carrier abstraction, storage rules, or production gates in specification 001.

## Context
The product is primarily a structured, stateful, regulated workflow application with:
- multi-step consumer intake;
- conditional and versioned questionnaires;
- multiple drivers and vehicles;
- agent case review;
- evidence/provenance inspection;
- compliance/admin surfaces;
- deterministic synthetic workflows;
- strict separation between client presentation and server authority.

Angular's standalone application model, Router, Signals, typed reactive forms, dependency injection, HttpClient, and hybrid rendering provide a coherent presentation architecture for these requirements.

## Decision constraints
1. Angular is a presentation/runtime choice, not a domain authority.
2. Canonical APIs remain framework-neutral.
3. Server-side authentication, authorization, permissible purpose, consent, privacy, carrier/provider controls, and audit remain authoritative.
4. Provider-specific and carrier-specific integration types stay behind backend adapter boundaries.
5. Synthetic fixtures remain the default development/CI/demo source.
6. Authenticated regulated surfaces use CSR by default; public pages may use prerendering/SSR.
7. No production credential or secret may be required in the browser build.
8. Migration must be reversible at the presentation-routing/deployment layer.

## Consequences
### Positive
- explicit feature boundaries for applicant, evidence, quoting, compliance, agent, and admin workflows;
- strong fit for typed, conditional insurance forms;
- predictable DI and HTTP middleware patterns;
- feature-scoped Signals without requiring a global store;
- framework-supported lazy routing and hybrid rendering;
- clearer presentation/domain separation than continuing framework ambiguity.

### Costs
- current Next.js presentation code must be migrated or retired after parity;
- Angular-specific build/test/deployment skills are required;
- existing React component code is not directly reusable;
- temporary dual-shell maintenance may be required during migration.

## Rejected alternatives
### Continue Next.js as canonical frontend
Rejected for this decision because the requested target is Angular and the product benefits from a more opinionated enterprise workflow architecture. Existing backend/domain work remains reusable.

### Rewrite backend around Angular
Rejected. Angular must not alter the insurance platform's trust boundaries or make the frontend authoritative.

### Micro-frontends during initial migration
Rejected for now. They increase deployment/state complexity without a demonstrated need. Revisit only if independent teams or release cadences create a concrete requirement.

### Global state library by default
Rejected. Server authority plus feature-scoped Signals is sufficient until a measured cross-feature state problem appears.

## Revisit triggers
Revisit this ADR only if:
- Angular cannot satisfy a P0 product or regulatory requirement without violating canonical invariants;
- deployment constraints make Angular materially non-viable;
- independent product surfaces require a different runtime and can remain contract-isolated;
- a later architectural decision replaces the presentation runtime with explicit migration evidence.
