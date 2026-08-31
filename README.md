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
3. domain/API/compliance/security artifacts — canonical semantic and control contracts.
4. `specs/001-insurance-quote-platform/plan.md` — technical architecture and delivery phases.
5. `specs/001-insurance-quote-platform/runtime-contract.md` — locked first implementation stack and runtime boundaries.
6. `specs/001-insurance-quote-platform/tasks.md` — actionable implementation sequence.
7. runtime implementation.
8. `acceptance.md` + `traceability.md` verification.

`BUILD_PROMPT.md` is the canonical coding-agent handoff prompt derived from these artifacts. It does not outrank them.

## Specification index
- `CONSTITUTION.md` — purpose-bound access, provenance, carrier authority, tenant isolation, synthetic-core and production gates.
- `AGENTS.md` — repository operating rules, read order, and ubiquitous language.
- `specs/001-insurance-quote-platform/spec.md` — end-to-end product specification.
- `specs/001-insurance-quote-platform/two-door-addendum.md` — Exclusive + Broker operator model on the sealed kernel.
- `specs/001-insurance-quote-platform/two-door-plan.md` — configuration plan for the two doors.
- `specs/001-insurance-quote-platform/decisions/D-001-two-door-operator.md` — Q-010, Q-011, and T001.
- `specs/001-insurance-quote-platform/plan.md` — architecture and delivery phases.
- `specs/001-insurance-quote-platform/runtime-contract.md` — locked Next.js/Vercel/Supabase first-runtime contract, module boundaries, environment rules, and synthetic-core definition of done.
- `specs/001-insurance-quote-platform/BUILD_PROMPT.md` — comprehensive coding-agent execution prompt for the synthetic core.
- `specs/001-insurance-quote-platform/data-model.md` — canonical domain model and provenance boundaries.
- `specs/001-insurance-quote-platform/api-contracts.md` — public, agent, provider, carrier, configuration, and internal interfaces.
- `specs/001-insurance-quote-platform/compliance.md` — California insurance privacy, GLBA, DPPA, FCRA, CCPA/CPRA, rating, retention, notice, and rights workflows.
- `specs/001-insurance-quote-platform/security.md` — threat model, identity, authorization, encryption, audit, telemetry, incident response.
- `specs/001-insurance-quote-platform/integrations.md` — provider candidates, capability registry, and carrier adapter requirements.
- `specs/001-insurance-quote-platform/user-flows.md` — consumer, agent, admin, privacy, and accessibility UX.
- `specs/001-insurance-quote-platform/acceptance.md` — P0 CORE / P0 PRODUCTION / P1 criteria and contract tests.
- `specs/001-insurance-quote-platform/tasks.md` — implementation task graph from governance through production.
- `specs/001-insurance-quote-platform/operations.md` — runbooks, deployment, observability, recovery, and production readiness.
- `specs/001-insurance-quote-platform/fixtures.md` — deterministic synthetic test scenarios.
- `specs/001-insurance-quote-platform/traceability.md` — requirement-to-control-to-test mapping.
- `specs/001-insurance-quote-platform/open-questions.md` — unresolved provider, legal, retention, carrier-capability, and architecture gates.

## MVP scope
- California only.
- Private-passenger auto only.
- Initial production may use one agency/tenant, while the canonical core remains tenant-aware.
- Mobile-first consumer quote intake.
- Agent review workspace.
- Provider-neutral identity/prefill/MVR/claims/vehicle/insurance-history integrations.
- Carrier-neutral handoff through `CarrierAdapter` + versioned `CarrierProgram` configuration.
- Multiple carrier programs supported by architecture and synthetic acceptance; production may activate only certified programs.
- Carrier-controlled rating and binding authority.
- Full provenance and audit trail.
- Privacy, retention, correction/dispute, and adverse-action support.
- Complete deterministic synthetic execution before live integrations.

## Portability rule
A new agency, provider, or carrier program MUST be onboarded by configuration plus a capability/adapter mapping. Core quote, consumer, provider, compliance, and audit domain objects MUST NOT require vendor- or carrier-specific forks.

## Locked first runtime
The first implementation is locked in `runtime-contract.md` to:

- Next.js 16 + TypeScript strict mode;
- Vercel application hosting;
- Supabase PostgreSQL/Auth/Queues;
- PostgreSQL RLS;
- deterministic provider and dual-carrier synthetic adapters;
- Vitest + Playwright acceptance automation;
- OpenTelemetry-compatible PII-safe telemetry.

These are implementation choices, not insurance-domain semantics.

## Current status
`SPECS_SEALED_FOR_SYNTHETIC_CORE_IMPLEMENTATION / PRODUCTION_INTEGRATIONS_GATED`

The synthetic build path is unblocked. The two-door operator model is an addendum: two `TenantConfiguration` records (Exclusive + Broker), one kernel, no shared lead pool. Live Allstate, LexisNexis, and Verisk stay gated.

The main unresolved production dependencies remain operating-entity evidence, live provider contracts/certification, live CarrierProgram certification, legal/compliance review, FCRA/adverse-action ownership, data-use policy approval, retention approval, and production security/operations review.

## GitHub Pages
The static board at `docs/site/` presents the two-door model. It is not the live quote app and it does not collect leads.

Published URL after you enable Pages:

https://scrimshawlife-ctrl.github.io/insure-me/

### Turn on GitHub Pages
1. Open the repository **Settings** tab.
2. Open **Pages**.
3. Set **Source** to **GitHub Actions**.
4. Merge to `main`. The `pages` workflow deploys `docs/site/` with base path `/insure-me/`.

Do not add a custom domain. Do not point this site at production DNS.

If you instead choose **Deploy from a branch** and folder `/docs` on the default branch, GitHub also publishes `docs/testing/`. Prefer GitHub Actions so only `docs/site/` goes live.

The `pages` workflow validates the site on every pull request so a branch push proves the board builds. Deploy runs only from `main`.
