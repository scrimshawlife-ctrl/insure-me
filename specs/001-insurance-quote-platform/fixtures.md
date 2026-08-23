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
Synthetic consumer report contributes to carrier-stub unfavorable decision. System creates an AdverseActionCase with correct CRA linkage and ownership state.

### F019 Privacy access request
Verified synthetic consumer requests access; system discovers all in-scope records and generates evidence.

### F020 Privacy deletion request
System applies delete/anonymize/retain-exception actions according to policy and records evidence.

### F021 Legal hold
Retention expiration occurs while legal hold is active; deletion must not execute.

### F022 Marketing separation
Consumer declines optional marketing consent but continues quote transaction normally.

### F023 Accessibility error flow
Required field errors, async provider status, and consent controls are tested with keyboard/screen reader expectations.

### F024 Session expiry
Resume/session token expires; access denied until approved re-verification.

### F025 Suspicious agent activity
Synthetic agent attempts repeated denied lookups; security signal triggers but no consumer risk observation is created.

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
