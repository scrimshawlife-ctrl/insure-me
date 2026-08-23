# AGENTS.md

## Purpose
This repository is the canonical specification source for Insure Me. Runtime code MUST follow approved specifications in this repository.

## Required workflow
Use spec-driven development in this order:
1. constitution: governing rules and non-negotiable boundaries;
2. specification: what and why;
3. technical plan: how;
4. tasks: implementation sequence;
5. implementation;
6. verification against acceptance criteria.

Do not skip directly from an idea to runtime code when a change affects regulated data, security, privacy, carrier behavior, or user-facing insurance decisions.

## Read order
Before changing the system, read:
1. `CONSTITUTION.md`
2. `specs/001-insurance-quote-platform/spec.md`
3. relevant domain documents under the same spec directory
4. `plan.md`
5. `tasks.md`
6. `acceptance.md`

## Ubiquitous language
Use these terms consistently:
- Prospect: person seeking an insurance quote.
- QuoteCase: the complete transaction context for one quote attempt.
- Driver: a person proposed to be rated or listed for the policy.
- Vehicle: a vehicle proposed for coverage.
- ExternalReport: immutable metadata and normalized payload derived from an approved external provider.
- UnderwritingObservation: an evidence-backed observation derived from source data; not a carrier decision.
- RatingInput: a value explicitly approved for carrier rating use.
- CarrierSubmission: the structured handoff to a carrier-approved quoting or rating surface.
- CarrierDecision: response owned by the carrier, including premium, eligibility, or binding state.
- ConsentRecord: evidence of a consumer authorization or acknowledgment.
- PermissiblePurpose: the legally and contractually permitted reason for a regulated data request.
- AuditEvent: append-only evidence of a security, privacy, data-access, or workflow event.

## Provenance rules
Every externally derived value MUST identify its source. Never invent provider responses, legal permissions, carrier capabilities, or consumer data.

When evidence is missing, mark the requirement `BLOCKED`, `UNVERIFIED`, or `NOT_COMPUTABLE` as appropriate.

## Compliance rules
Do not encode legal conclusions as assumptions. Requirements involving CCPA/CPRA, California insurance privacy law, GLBA, DPPA, FCRA, California rating rules, electronic consent, breach notification, marketing communications, accessibility, or carrier agreements MUST have traceable source notes and require legal/compliance review before production.

## Architecture rules
- Prefer provider adapters over vendor coupling.
- Treat jurisdiction and permissible purpose as request inputs.
- Keep raw provider evidence separate from normalized observations, rating inputs, and carrier decisions.
- No production PII in fixtures, logs, analytics, screenshots, or telemetry.
- All sensitive access is authenticated, authorized, and auditable.
- Fail closed when required legal, identity, purpose, or consent context is missing.

## Scope discipline
MVP is California private-passenger auto for one agency/carrier operating context. Any expansion to another state, product line, carrier, payment flow, claims handling, or automated underwriting requires a new or amended specification.
