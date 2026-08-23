# AGENTS.md

## Purpose
This repository is the canonical specification source for Insure Me. Runtime code MUST follow approved specifications in this repository.

## Required workflow
Use spec-driven development in this order:
1. constitution: governing rules and non-negotiable boundaries;
2. specification: what and why;
3. domain/API/compliance/security contracts;
4. technical plan: architecture and delivery strategy;
5. runtime contract: locked first implementation choices;
6. tasks: implementation sequence;
7. implementation;
8. verification against acceptance criteria and traceability.

Do not skip directly from an idea to runtime code when a change affects regulated data, security, privacy, tenant isolation, provider semantics, carrier behavior, or user-facing insurance decisions.

## Read order
Before changing the system, read:
1. `CONSTITUTION.md`
2. `specs/001-insurance-quote-platform/spec.md`
3. `specs/001-insurance-quote-platform/data-model.md`
4. `specs/001-insurance-quote-platform/api-contracts.md`
5. `specs/001-insurance-quote-platform/compliance.md`
6. `specs/001-insurance-quote-platform/security.md`
7. `specs/001-insurance-quote-platform/integrations.md`
8. `specs/001-insurance-quote-platform/user-flows.md`
9. `specs/001-insurance-quote-platform/fixtures.md`
10. `specs/001-insurance-quote-platform/plan.md`
11. `specs/001-insurance-quote-platform/runtime-contract.md`
12. `specs/001-insurance-quote-platform/tasks.md`
13. `specs/001-insurance-quote-platform/acceptance.md`
14. `specs/001-insurance-quote-platform/traceability.md`
15. `specs/001-insurance-quote-platform/open-questions.md`
16. `specs/001-insurance-quote-platform/operations.md`

`BUILD_PROMPT.md` is a handoff/execution prompt. It summarizes the canonical documents but does not outrank them.

## Ubiquitous language
Use these terms consistently:
- Prospect: person seeking an insurance quote.
- TenantConfiguration: versioned tenant/agency operational configuration governing enabled providers, carrier programs, branding, policies, and environment state.
- QuoteCase: the complete transaction context for one quote attempt.
- Driver: a person proposed to be rated or listed for the policy.
- Vehicle: a vehicle proposed for coverage.
- ExternalReport: immutable metadata and normalized payload derived from an approved external provider.
- UnderwritingObservation: an evidence-backed observation derived from source data; not a carrier decision.
- RatingInput: a value explicitly approved for carrier rating use for a configured CarrierProgram.
- Carrier: carrier identity/configuration root; not a source of canonical branching logic.
- CarrierProgram: versioned carrier capability and product configuration for a jurisdiction/product/handoff mode.
- CarrierSubmission: the structured handoff to a carrier-approved quoting or rating surface.
- CarrierDecision: response owned by the carrier, including premium, eligibility, or binding state.
- ConsentRecord: evidence of a consumer authorization or acknowledgment.
- PermissiblePurpose: the legally and contractually permitted reason for a regulated data request.
- AuditEvent: append-only evidence of a security, privacy, data-access, configuration, or workflow event.

## Provenance rules
Every externally derived value MUST identify its source. Never invent provider responses, legal permissions, carrier capabilities, consumer data, tenant authority, or production certification.

When evidence is missing, mark the requirement `BLOCKED`, `UNVERIFIED`, or `NOT_COMPUTABLE` as appropriate.

## Compliance rules
Do not encode legal conclusions as assumptions. Requirements involving CCPA/CPRA, California insurance privacy law, GLBA, DPPA, FCRA, California rating rules, electronic consent, breach notification, marketing communications, accessibility, or carrier agreements MUST have traceable source notes and require legal/compliance review before production.

Synthetic implementation MAY encode the required control shape and deterministic fixtures without claiming that a live legal/provider/carrier configuration has been approved.

## Architecture rules
- Prefer provider adapters over vendor coupling.
- Prefer CarrierAdapter + CarrierProgram configuration over carrier coupling.
- Carrier/provider names MUST NOT control core workflow branching.
- Treat tenant, jurisdiction, product line, permissible purpose, and configuration version as explicit execution context.
- Keep raw provider evidence separate from normalized observations, rating inputs, carrier submissions, and carrier decisions.
- No production PII in fixtures, logs, analytics, screenshots, or telemetry.
- All sensitive access is authenticated, authorized, tenant-scoped, and auditable.
- Fail closed when required identity, tenant, legal, purpose, consent, jurisdiction, provider, carrier-program, or certification context is missing.
- The full core MUST be testable with deterministic provider and carrier adapters without live credentials.

## Scope discipline
MVP is California private-passenger auto. Initial production MAY enable one tenant and one live carrier program, but the core architecture MUST remain tenant-aware, provider-agnostic, and multi-carrier capable.

Any expansion to another state, product line, payment flow, claims handling, independent rating, or autonomous underwriting requires a new or amended specification.
