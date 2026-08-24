# Synthetic Fixture Specification

## Rule
All development, CI, screenshots, demos, and acceptance rehearsals use synthetic data. Fixtures MUST not be derived from real consumers unless irreversibly de-identified under an approved process.

## Required fixture families

### F001 Happy path single driver/single vehicle
- California resident
- valid license
- one vehicle
- no claims
- no blocking MVR events
- complete coverage request
- approved notices
- successful carrier-stub response

### F002 Multiple drivers/multiple vehicles
Exercises household/driver assignment and multiple vehicle confirmation.

### F003 Prefill no-hit
Prefill returns no data; consumer completes manual entry.

### F004 MVR no-hit
Provider returns no match; agent review required according to policy.

### F005 Claims report no-hit
Claims provider returns no reportable claims/no-hit variant.

### F006 Conflicting license status
User-entered value conflicts with MVR. System must not silently overwrite.

### F007 Conflicting vehicle data
Consumer VIN decode differs from prefill candidate. Requires confirmation/review.

### F008 Stale report
ExternalReport is outside approved freshness window; refresh rules evaluated.

### F009 Provider outage
Timeout/unavailable response; intake remains recoverable.

### F010 Provider throttling
429/rate-limited response with bounded retry behavior.

### F011 Provider malformed response
Adapter rejects schema drift safely and creates operational alert.

### F012 Unauthorized purpose
Agent attempts an MVR lookup without valid purpose. Must be blocked before provider call.

### F013 Missing authorization
Required consent/authorization absent. Provider call must not occur.

### F014 Cross-agency access
Agency A user attempts to read Agency B case. Must be denied and audited.

### F015 Duplicate provider request
Same idempotency key replayed. Exactly one external order exists.

### F016 Duplicate carrier submission
Same idempotency key replayed. Exactly one carrier submission exists.

### F017 Consumer correction
Consumer corrects user-maintained annual mileage and requests review of an external record.

### F018 Potential FCRA adverse action
Synthetic consumer report contributes to a carrier-stub unfavorable decision. An authorized responsible party explicitly records the determination; the system creates an AdverseActionCase with the exact CarrierDecision, ExternalReport, CRA/dispute references, configured carrier ownership-policy version, and `CARRIER` owner. A separate idempotent handoff records owner acknowledgment without claiming notice delivery. A later synthetic delivery binds the exact synthetic adverse-action notice version/hash and delivery adapter/policy, then stores explicit deterministic delivered evidence. Hash mismatch, missing handoff, adapter mismatch, and rewritten evidence fail closed.

### F019 Privacy access request
Verified synthetic consumer requests access; system discovers all in-scope records and generates evidence.

### F020 Privacy deletion request
System resolves exact synthetic policies, destroys protected identity lookup/key material, anonymizes direct consumer identifiers, preserves explicit exceptions, and records opaque append-only evidence. Missing or incompatible policies remain blocked.

### F021 Legal hold
Retention expiration occurs while a formal Person-scoped hold is active; T805 rechecks the signal immediately before disposition, does not mutate held records, and records blocked work. An authorized administrator releases the hold with separate authority/evidence, the lifecycle remains immutable, and destructive work remains blocked until a new scheduler evaluation. The legacy `RETENTION_HOLD` QuoteCase signal remains a compatible fail-closed input.

### F022 Marketing separation
Consumer declines optional marketing consent but continues quote transaction normally.

### F023 Accessibility error flow
Required field errors, async provider status, and consent controls are tested with keyboard/screen reader expectations.

### F024 Session expiry
Resume/session token expires; access denied until approved re-verification.

### F025 Suspicious agent activity
Synthetic agent attempts repeated denied lookups; security signal triggers but no consumer risk observation is created.

### F026 Compliance evidence export
An MFA-authenticated synthetic administrator holding `AUDIT_READ` and `EXPORT_DATA` creates a QuoteCase evidence bundle at an explicit cutoff. The artifact includes exact notice, purpose, provider, carrier, adverse-action, notice-delivery, hold, and audit provenance available by that cutoff, but excludes planted notice-body and arbitrary audit-metadata markers. The manifest hash verifies; replay is stable; creation and download are separately audited. A user with only `AUDIT_READ`, a future cutoff, direct table access, mutation, and mismatched replay all fail closed.

### F027 Notice/version administration

An MFA-authenticated synthetic `POLICY_ADMIN` creates two versions of one notice key. PostgreSQL assigns versions 1 and 2 and hashes the exact bodies. Version 1 receives explicit approval evidence and an effective time, then retires with separate evidence; version 2 remains draft. Lifecycle commands replay idempotently and emit one append-only event plus AuditEvent each. Changed replay, draft retirement, direct content mutation/deletion, and a non-policy user all fail closed.

### F028 Data-use/retention policy inspection

One synthetic agency has a versioned data-use rule and an approved retention policy with explicit duration and legal authority; a second agency has distinct policy records. An MFA-backed policy administrator receives only the first agency's exact records. A privacy-only administrator receives only retention records. Direct table reads, privacy-only data-use inspection, ordinary-agent access, AAL1, and an identity with eligible roles in two agencies all fail closed.

## Fixture schema requirements
Each fixture MUST declare:
- fixture ID/version;
- jurisdiction;
- QuoteCase initial state;
- consumer inputs;
- consent/notice state;
- provider adapter responses;
- provider report metadata;
- expected normalized observations;
- expected ReadinessIssues;
- expected carrier stub behavior;
- expected AuditEvents;
- expected privacy/retention behavior;
- expected final state.

## Determinism
Fixtures MUST be deterministic. Randomized fuzz/property tests may exist separately but must emit reproducible seeds.
