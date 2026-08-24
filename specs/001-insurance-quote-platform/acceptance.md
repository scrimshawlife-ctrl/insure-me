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

### A-031 Privacy discovery and export safety
Given a verified privacy request, discovery MUST be idempotent, tenant/agency scoped, auditable, and based only on protected lookup material. A unique match may create an encrypted access export. No match or multiple matches MUST reveal no candidate identity or record count, attach no Person, and require applicability review. Anonymous/authenticated roles MUST have no direct access to discovery or export artifacts.

### A-032 Privacy rights execution safety
Given a verified and completed discovery, correction MUST update only requester-maintained protected identity data and retain no plaintext change evidence. Deletion MUST apply a processing restriction and produce explicit disposition/exemption work without deleting audit or external-source evidence. Restriction/opt-out MUST create a person-scoped enforcement record. All actions MUST be tenant-scoped, idempotent, atomic, audited, inaccessible to direct anonymous/authenticated writes, and remain `IN_PROGRESS` while deletion or downstream propagation work is pending.

### A-033 Downstream privacy propagation safety
Given a rights execution with downstream work, each affected ExternalRequest MUST map to one stable tenant-scoped target. Only an exact active adapter/policy binding may dispatch it. Missing bindings remain blocked; retry and settlement are idempotent and append-only; failures remain visible without leaking vendor detail to the requester. Correction/restriction/opt-out may close only when all required targets complete, while deletion remains open for retention disposition. Direct anonymous/authenticated writes to bindings, targets, runs, and attempts MUST be denied.

### A-034 Retention disposition worker safety
Given queued deletion categories, one bounded idempotent run MUST resolve only the active tenant policy set and exact allowed certification state. Missing policy/interval evidence, incompatible versions, unsafe operations, and retention-hold signals MUST fail closed without mutating source records. Eligible identity disposition MUST destroy protected key/lookup material; consumer-input anonymization MUST remove direct identifiers while preserving exempt audit and external-source evidence. Every attempt MUST be append-only and audited, direct anonymous/authenticated execution MUST be denied, and the request MUST close only after every local and downstream requirement completes.

### A-035 Legal-hold lifecycle safety
An MFA-authenticated `PRIVACY_ADMIN` or `POLICY_ADMIN` MAY place or release a tenant-scoped Person, QuoteCase, or PrivacyRequest hold only with explicit opaque authority/evidence references, reason codes, and idempotency evidence. Placement MUST block matching pending destructive work and remain effective at T805's final mutation check. Release MUST be append-only and audited, MUST NOT erase hold history, and MUST require scheduler reevaluation rather than automatically resuming destructive work. Cross-tenant scope, missing authority/evidence, direct table mutation, and mismatched idempotent replay MUST fail closed.

### A-036 Adverse-action support safety
An MFA-authenticated `POLICY_ADMIN` MAY record a responsible party's adverse-action determination only against a tenant-scoped CarrierDecision and exact contributing ExternalReports. The case MUST snapshot configured ownership-policy version, explicit owner, opaque authority/evidence, CRA identity and dispute-route references, reason codes, and idempotency evidence. The platform MUST NOT infer a determination from readiness, report data, or carrier status. Handoff MUST be a separate append-only, audited command and MUST NOT be represented as notice delivery. Cross-case, cross-tenant, missing-report, direct-mutation, and mismatched-replay attempts MUST fail closed.

### A-037 Adverse-action notice delivery safety
An MFA-authenticated `POLICY_ADMIN` MAY prepare an adverse-action delivery only after handoff and only with an active tenant-scoped `ADVERSE_ACTION` NoticeDefinition whose exact version and content hash match the request and deployment certification state. The envelope MUST snapshot configured owner/policy, approved channel, opaque recipient, adapter/policy descriptor, and idempotency evidence before dispatch. Every outcome MUST be append-only and audited; `ACCEPTED` MUST remain dispatched rather than delivered, and only explicit `DELIVERED` evidence may set a delivery timestamp. Missing handoff, wrong notice/category/state/hash, adapter mismatch, live synthetic configuration, direct mutation, and mismatched replay MUST fail closed.

### A-038 Compliance evidence export safety
An MFA-authenticated workforce user MAY create or download a QuoteCase compliance evidence export only when holding both `AUDIT_READ` and `EXPORT_DATA`. Creation MUST be tenant/agency derived, explicitly purpose/reason coded, idempotent, bounded to 10,000 records, and fixed to a non-future as-of cutoff. The immutable versioned manifest MUST preserve exact provenance/integrity fields while excluding identity data, raw/normalized provider payloads, notice bodies, premiums, corrections, secrets, and arbitrary audit metadata. SHA-256 verification MUST precede every separately audited download. Direct table access/mutation, one-permission users, future cutoffs, cross-tenant scopes, integrity failure, and mismatched replay MUST fail closed without an existence oracle.

### A-039 Notice/version administration safety
An MFA-authenticated `POLICY_ADMIN` MAY create immutable draft notice versions, list the active agency's exact versions, approve a draft only with explicit legal/compliance evidence and effective time, and retire only an approved or synthetic-fixture version with separate evidence. PostgreSQL MUST assign increasing versions, compute exact body hashes, derive replay hashes, preserve append-only lifecycle evidence, and audit every successful transition. Runtime callers MUST NOT create synthetic or pre-approved notices, choose hashes/versions, rewrite content, delete history, cross tenant/agency scope, retire drafts, or reuse idempotency keys with changed evidence.

### A-040 Policy inspection safety
An MFA-authenticated `POLICY_ADMIN` MAY inspect exact data-use rule versions for one active agency; an MFA-authenticated `POLICY_ADMIN` or `PRIVACY_ADMIN` MAY inspect exact retention policy versions for one active agency. Responses MUST preserve configured flags, unresolved durations, authority references, certification state, and lifecycle times without inference or secret material, and each successful inspection MUST emit an AuditEvent. Both tables MUST deny direct anonymous/authenticated reads, both APIs MUST be read-only and non-cacheable, and insufficient permission, AAL1, cross-agency data, or multiple eligible agency contexts MUST fail closed.

### A-041 Reliability contract
`reliability-v1` MUST define rolling-window availability, latency, asynchronous claim-time, and regulated-action audit-atomicity SLOs with deterministic eligibility and error-budget rules. It MUST define zero-loss/one-hour application recovery and a maximum five-minute RPO/four-hour RTO for database, queue, and identity state, plus an ordered fail-closed recovery sequence. Production readiness MUST remain `UNVERIFIED` until monitoring demonstrates the SLIs and T902 proves restore capability on the selected hosting plans. Provider/carrier outcomes MUST remain visible dependency signals and MUST NOT be misclassified as core platform success or silently excluded when the platform itself fails to dispatch, persist, reconcile, or present them.

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
- adverse-action support handoff and notice delivery;
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
