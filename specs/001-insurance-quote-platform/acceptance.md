# Acceptance Specification

## Purpose
This document defines release-blocking behavior for the Insure Me core platform and deployment-specific production activation. Synthetic acceptance MUST be possible without live carrier or consumer-report credentials.

## Acceptance levels
- `P0 CORE`: required for synthetic build completeness.
- `P0 PRODUCTION`: required before a specific live deployment activates regulated provider or carrier adapters.
- `P1`: important but may follow initial MVP when explicitly accepted.

## P0 CORE — domain and workflow

### A-001 QuoteCase required before regulated lookup
Given no valid QuoteCase, when any provider request is attempted, then execution is denied before provider invocation and an AuditEvent records the denial.

### A-002 Purpose enforcement
Given a QuoteCase without an allowed permissible-purpose decision, when a regulated provider request is attempted, then it fails closed with `PURPOSE_NOT_PERMITTED` and the adapter is not called.

### A-003 Notice/authorization enforcement
Given a capability requiring notice or authorization that has not been satisfied, when the capability is requested, then it fails before provider execution with a stable reason code.

### A-004 Jurisdiction/capability enforcement
Given a configured provider binding that does not support the case jurisdiction/product, the provider request MUST be blocked before adapter execution.

### A-005 Tenant isolation
Given users or service principals from Tenant A, attempts to read, mutate, export, or execute regulated actions against Tenant B objects MUST fail. No existence oracle or metadata leak is permitted.

### A-006 Provider-neutral canonical model
Replacing `StubMvrAdapter-A` with `StubMvrAdapter-B` MUST NOT require changes to QuoteCase, Driver, Vehicle, ExternalReport, UnderwritingObservation, RatingInput, or CarrierDecision schemas.

### A-007 External data provenance
Every material normalized provider fact shown to an agent MUST resolve to provider/report/retrieval/transformation provenance.

### A-008 Report/observation/rating separation
Tests MUST prove that an ExternalReport cannot directly become a CarrierSubmission field without normalization, data-use evaluation, and explicit RatingInput/submission mapping where required.

### A-009 Readiness is not risk
Readiness output MUST be based on workflow completeness, freshness, conflicts, and configured program prerequisites only. It MUST NOT expose a risk, insurability, or predicted-premium score.

### A-010 Conflicting facts require review
Materially conflicting sourced facts MUST create a blocking or review ReadinessIssue according to policy. The system MUST NOT silently select a winner.

### A-011 Provider idempotency
Two identical provider-order requests using the same idempotency key MUST produce at most one external execution/charge-equivalent event.

### A-012 Carrier submission idempotency
Two identical carrier submissions using the same idempotency key MUST produce at most one carrier execution unless the adapter contract explicitly records a linked new attempt.

### A-013 Sensitive data in telemetry
Automated tests MUST verify that raw DOB, license numbers, consumer-report contents, secrets, and other prohibited high-risk fields do not appear in standard logs, traces, analytics, or error payloads.

### A-014 Consumer session isolation
A consumer quote session MUST access only its authorized QuoteCase and MUST expire/revoke according to session policy.

### A-015 Workforce security
Agent/admin surfaces MUST enforce workforce authentication, MFA state, tenant/agency scope, and role/permission checks.

### A-016 Synthetic provider execution
Local and CI MUST complete the happy-path quote flow using deterministic StubIdentity, StubPrefill, StubMvr, StubClaims, and StubVehicle adapters without external network credentials.

### A-017 Synthetic carrier execution
Local and CI MUST complete carrier handoff and synthetic CarrierDecision ingestion using `StubCarrierAdapter` without a live carrier.

### A-018 Carrier program policy gate
A CarrierSubmission MUST fail if its selected CarrierProgram is disabled, unsupported for jurisdiction/product, kill-switched, or missing required readiness/data-use prerequisites.

### A-019 Carrier mapping boundary
Carrier-specific request fields MAY exist inside an adapter mapping fixture but MUST NOT be added to canonical Person, Driver, Vehicle, QuoteCase, or UnderwritingObservation solely to satisfy one carrier.

### A-020 Provider failure/degraded mode
Timeout, unavailable, no-hit, partial, malformed, and auth-failure fixtures MUST produce defined states/reason codes and MUST NOT corrupt canonical facts or cause infinite retries.

### A-021 Carrier failure states
Validation failure, authentication failure, timeout, unavailable, rejected, and ambiguous-status carrier fixtures MUST preserve an auditable CarrierSubmission state and MUST NOT fabricate a CarrierDecision.

### A-022 Privacy request existence protection
Before requester identity verification, privacy APIs MUST NOT reveal whether a person or quote exists.

### A-023 Retention/legal hold
Expired data MUST enter the approved disposition workflow. Legal hold MUST prevent destructive disposition for the held scope and record evidence.

### A-024 Audit completeness
Sensitive reads/writes, provider requests, consent actions, policy/configuration changes, carrier submissions, privacy actions, exports, and important denials MUST create append-only AuditEvents with sufficient policy/configuration provenance.

### A-025 Accessibility baseline
Critical consumer and agent journeys MUST pass the approved WCAG 2.2 AA engineering checks, including keyboard operation, focus visibility, labels/errors, contrast, and responsive zoom/reflow.

### A-026 Carrier portability
The same synthetic QuoteCase MUST be eligible for submission through two independently configured synthetic CarrierPrograms/CarrierAdapters with no carrier-name branch in core code and no canonical schema change. Differences MUST be expressed through program configuration and boundary mapping.

### A-027 Tenant configuration isolation
Two synthetic tenants with different branding, provider bindings, notices, retention policies, and carrier programs MUST execute concurrently without configuration or data leakage. Changing Tenant B configuration MUST NOT change Tenant A behavior.

### A-028 Configuration version replay
For a historical regulated request/submission, the system MUST identify the exact TenantConfiguration, policy, provider binding, CarrierProgram, and adapter versions used at execution time even after newer versions are activated.

### A-029 Carrier switch does not rewrite facts
Changing a QuoteCase's selected CarrierProgram before submission MAY change readiness and RatingInput projection. It MUST NOT rewrite the underlying user-provided or provider-sourced canonical facts.

### A-030 Marketing separation
Quote notices/consent MUST NOT imply marketing consent. Transactional and marketing permission states MUST remain separate.

## P0 PRODUCTION — provider activation
Before any live regulated provider capability is enabled for a deployment:
- provider contract/product is identified;
- DPPA/FCRA/insurance-purpose role is documented as applicable;
- jurisdiction/product capability is configured;
- required notices/authorizations are approved;
- raw-payload and retention rules are approved;
- dispute/correction routing is documented;
- production credentials are isolated and rotation tested;
- sandbox/contract tests pass including no-hit, partial, timeout, malformed, auth failure, restriction, and redaction cases;
- kill switch exists and is tested.

## P0 PRODUCTION — carrier activation
Before a live CarrierProgram is enabled for a deployment:
- operating agency/entity authority and relationship are documented;
- carrier/program and permitted handoff mode are documented;
- required-field and RatingInput allowlists are approved/versioned;
- authentication/security contract is configured;
- response/reason-code mapping is validated without invention;
- notice/adverse-action ownership is documented;
- retention/storage constraints are approved;
- sandbox/certification tests pass for the selected mode;
- idempotency and ambiguous-status recovery are tested;
- kill switch exists and is tested.

A live CarrierProgram activation is deployment-specific. Failure to certify Carrier A MUST NOT block synthetic core acceptance or certification work for Carrier B.

## P0 PRODUCTION — legal/privacy/security
Before real consumer data is accepted:
- privacy/information-practices notices are approved;
- consumer-report/FCRA workflows and adverse-action ownership are approved where applicable;
- data-use matrix is approved;
- retention schedule is approved;
- applicable CCPA/CPRA and California insurance privacy roles are documented;
- incident-response ownership/runbook is approved;
- backup/restore and disaster-recovery tests pass;
- penetration/security review is complete and release-blocking findings are resolved or formally accepted;
- privacy-rights workflow rehearsal passes.

## Required synthetic fixture classes
At minimum:
- happy path;
- multiple drivers;
- multiple vehicles;
- no-hit;
- partial MVR/claims result;
- stale report;
- provider outage/timeout;
- provider auth failure;
- prohibited-purpose attempt;
- missing authorization;
- conflicting external facts;
- consumer correction;
- unauthorized cross-tenant access;
- privacy access/correction/deletion;
- retention expiration;
- legal hold;
- adverse-action support handoff;
- carrier validation failure;
- carrier unavailable/timeout;
- carrier ambiguous status;
- two synthetic carrier programs with different required fields/mappings;
- two tenant configurations with different provider/carrier bindings.

## Core-build verdict
Core build may be marked `SYNTHETIC_CORE_ACCEPTED` only when all `P0 CORE` tests pass with deterministic fixtures and no unresolved defect allows unauthorized lookup, cross-tenant access, unapproved rating-input propagation, carrier-specific canonical coupling, or unaudited regulated actions.

## Production verdict
A specific deployment may be marked `PRODUCTION_READY` only when:
1. all P0 CORE tests pass;
2. that deployment's live provider capabilities satisfy the provider activation gates;
3. at least one intended live CarrierProgram satisfies carrier activation gates if live carrier handoff is in scope;
4. legal/privacy/security gates pass;
5. release evidence names the exact configuration and adapter versions being activated.

Unknown future carriers and providers are not global blockers. They remain unconfigured capabilities until individually certified.

## P1 examples
- native mobile shell after responsive validation;
- additional insurance product lines;
- additional jurisdictions after jurisdiction-specific compliance specification;
- advanced agency analytics using approved low-risk dimensions;
- additional AMS/comparative-rater adapters;
- self-service tenant onboarding after security/compliance review.
