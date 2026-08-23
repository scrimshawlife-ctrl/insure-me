# Insure Me

Canonical specifications for a compliance-first California private-passenger auto insurance intake and quote-preparation platform.

## Product boundary
Insure Me helps a consumer start a quote, confirms authorized prefill, retrieves approved underwriting data through provider adapters, gives an agent a source-backed quote-readiness workspace, and hands the case to a configured carrier-approved quoting/rating workflow.

The platform is carrier-, agency-, and data-provider-agnostic. No insurer, agency management system, comparative rater, consumer-report provider, or messaging vendor is canonical to the domain model.

It does **not** independently bind coverage, issue policies, or invent authoritative premiums unless a configured carrier explicitly delegates those functions.

## Canonical workflow
This repository follows spec-driven development:

1. `CONSTITUTION.md` — governing principles and hard boundaries.
2. `specs/001-insurance-quote-platform/spec.md` — what the product must do and why.
3. `specs/001-insurance-quote-platform/plan.md` — technical implementation plan.
4. `specs/001-insurance-quote-platform/tasks.md` — actionable implementation sequence.
5. Runtime implementation only after relevant legal, provider, carrier, and security gates are resolved for the selected deployment.

## Specification index
- `CONSTITUTION.md` — purpose-bound access, provenance, carrier authority, compliance and launch gates.
- `AGENTS.md` — repository operating rules and ubiquitous language.
- `specs/001-insurance-quote-platform/spec.md` — end-to-end product specification.
- `specs/001-insurance-quote-platform/plan.md` — architecture and delivery phases.
- `specs/001-insurance-quote-platform/data-model.md` — canonical domain model and provenance boundaries.
- `specs/001-insurance-quote-platform/api-contracts.md` — public, agent, provider, and carrier interfaces.
- `specs/001-insurance-quote-platform/compliance.md` — California insurance privacy, GLBA, DPPA, FCRA, CCPA/CPRA, rating, retention, notice, and rights workflows.
- `specs/001-insurance-quote-platform/security.md` — threat model, identity, authorization, encryption, audit, telemetry, incident response.
- `specs/001-insurance-quote-platform/integrations.md` — provider candidates, capability registry, and carrier adapter requirements.
- `specs/001-insurance-quote-platform/user-flows.md` — consumer, agent, admin, privacy, and accessibility UX.
- `specs/001-insurance-quote-platform/acceptance.md` — P0/P1 release criteria and contract tests.
- `specs/001-insurance-quote-platform/tasks.md` — implementation task graph from governance through production.
- `specs/001-insurance-quote-platform/operations.md` — runbooks, deployment, observability, recovery, and production readiness.
- `specs/001-insurance-quote-platform/fixtures.md` — deterministic synthetic test scenarios.
- `specs/001-insurance-quote-platform/traceability.md` — requirement-to-control-to-test mapping.
- `specs/001-insurance-quote-platform/open-questions.md` — unresolved provider, legal, retention, carrier-capability, and architecture gates.

## MVP scope
- California only.
- Private-passenger auto only.
- One agency operating context initially, but no agency-specific domain coupling.
- Mobile-first consumer quote intake.
- Agent review workspace.
- Provider-neutral identity/prefill/MVR/claims/vehicle integrations.
- Carrier-neutral handoff through `CarrierAdapter`.
- Carrier-controlled rating and binding authority.
- Full provenance and audit trail.
- Privacy, retention, correction/dispute, and adverse-action support.

## Portability rule
A new agency or carrier MUST be onboarded by configuration plus an adapter/capability mapping. Core quote, consumer, provider, compliance, and audit domain objects MUST NOT require carrier-specific forks.

## Current status
`SPECIFICATION_DRAFT_COMPLETE / VENDOR_AND_LEGAL_GATES_BLOCK_PRODUCTION`

The main unresolved production dependencies are provider contracts, legal/compliance review, carrier-specific adapter certification for any selected deployment, FCRA/adverse-action ownership, data-use policy approval, retention approval, and security review.
