# Insure Me

Canonical specifications for a compliance-first California private-passenger auto insurance intake and quote-preparation platform.

## Product boundary
Insure Me helps a consumer start a quote, confirms authorized prefill, retrieves approved underwriting data through provider adapters, gives an agent a source-backed quote-readiness workspace, and hands the case to a carrier-approved quoting/rating workflow.

It does **not** independently bind coverage, issue policies, or invent authoritative premiums unless a carrier explicitly delegates those functions.

## Canonical workflow
This repository follows spec-driven development:

1. `CONSTITUTION.md` — governing principles and hard boundaries.
2. `specs/001-insurance-quote-platform/spec.md` — what the product must do and why.
3. `specs/001-insurance-quote-platform/plan.md` — technical implementation plan.
4. `specs/001-insurance-quote-platform/tasks.md` — actionable implementation sequence.
5. Runtime implementation only after relevant external and compliance gates are resolved.

## Specification index
- `CONSTITUTION.md` — purpose-bound access, provenance, carrier authority, compliance and launch gates.
- `AGENTS.md` — repository operating rules and ubiquitous language.
- `specs/001-insurance-quote-platform/spec.md` — end-to-end product specification.
- `specs/001-insurance-quote-platform/plan.md` — architecture and delivery phases.
- `specs/001-insurance-quote-platform/data-model.md` — canonical domain model and provenance boundaries.
- `specs/001-insurance-quote-platform/api-contracts.md` — public, agent, provider, and carrier interfaces.
- `specs/001-insurance-quote-platform/compliance.md` — California insurance privacy, GLBA, DPPA, FCRA, CCPA/CPRA, rating, retention, notice, and rights workflows.
- `specs/001-insurance-quote-platform/security.md` — threat model, identity, authorization, encryption, audit, telemetry, incident response.
- `specs/001-insurance-quote-platform/integrations.md` — provider candidates, capability registry, and Allstate/carrier integration gates.
- `specs/001-insurance-quote-platform/user-flows.md` — consumer, agent, admin, privacy, and accessibility UX.
- `specs/001-insurance-quote-platform/acceptance.md` — P0/P1 release criteria and contract tests.
- `specs/001-insurance-quote-platform/tasks.md` — implementation task graph from governance through production.
- `specs/001-insurance-quote-platform/operations.md` — runbooks, deployment, observability, recovery, and production readiness.
- `specs/001-insurance-quote-platform/fixtures.md` — deterministic synthetic test scenarios.
- `specs/001-insurance-quote-platform/traceability.md` — requirement-to-control-to-test mapping.
- `specs/001-insurance-quote-platform/open-questions.md` — unresolved Allstate, provider, legal, retention, branding, and architecture gates.

## MVP scope
- California only.
- Private-passenger auto only.
- One agency operating context initially.
- Mobile-first consumer quote intake.
- Agent review workspace.
- Provider-neutral identity/prefill/MVR/claims/vehicle integrations.
- Carrier-controlled rating/handoff.
- Full provenance and audit trail.
- Privacy, retention, correction/dispute, and adverse-action support.

## Current status
`SPECIFICATION_DRAFT_COMPLETE / EXTERNAL_GATES_BLOCK_PRODUCTION`

The main unresolved production dependencies are Allstate integration authority, approved vendor contracts, notice/legal review, FCRA/adverse-action ownership, data-use policy approval, retention approval, and security review.
