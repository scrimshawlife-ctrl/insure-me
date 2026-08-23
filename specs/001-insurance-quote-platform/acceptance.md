# Acceptance Specification

## Rule
A feature is not complete because the UI works. It is complete when the product behavior, compliance control, security control, failure behavior, and audit evidence all pass.

## P0 launch acceptance

### A-001 QuoteCase prerequisite
Given no QuoteCase, when any regulated provider request is attempted, then the request is denied before provider execution and an audit event records the denial.

### A-002 Permissible purpose
Given a QuoteCase without an allowed purpose decision, when MVR/claims data is requested, then the request fails closed with a machine-readable reason.

### A-003 Required notice/authorization
Given a provider capability that requires a notice/authorization, when the consumer has not completed it, then provider execution does not occur.

### A-004 Jurisdiction restriction
Given a California case and a provider capability not approved for California, the system blocks the request even if the provider API would technically accept it.

### A-005 Object-level authorization
An agent from Agency A cannot read, mutate, export, or order reports for Agency B.

### A-006 MFA
A workforce user without satisfied MFA cannot access the agent workspace or regulated report operations.

### A-007 Provenance
Every displayed external observation can be traced to provider, report/reference, retrieval time, and source field/path where contract permits.

### A-008 No silent conflict resolution
When user-provided and external facts materially conflict, the system creates a review state and does not silently choose a value.

### A-009 Rating separation
No ExternalReport or UnderwritingObservation automatically becomes a RatingInput. Only carrier-approved mapping can create a RatingInput.

### A-010 Readiness semantics
Readiness reflects completeness/workflow state only and is never labeled or used as consumer risk/insurability score.

### A-011 Carrier authority
Without an approved CarrierAdapter, the system cannot display an independently calculated binding premium or bind coverage.

### A-012 Idempotent provider requests
Replaying the same idempotency key does not place a second provider order or duplicate chargeable transaction.

### A-013 Idempotent carrier submission
Replaying a carrier-submission idempotency key does not create a duplicate submission.

### A-014 Provider outage
If enrichment provider is unavailable, consumer intake remains recoverable and case state clearly indicates pending/review instead of losing data.

### A-015 No production PII in telemetry
Automated scanning verifies logs/analytics do not contain configured sensitive fields or raw provider payloads.

### A-016 Consumer session security
Sensitive identifiers are absent from URLs and expired resume/session credentials no longer grant access.

### A-017 Consent evidence
For any regulated request requiring authorization, an auditor can identify the exact notice version, subject, action, and time associated with the request.

### A-018 Privacy request
Synthetic access/correction/deletion test locates applicable records, applies approved exceptions, propagates required vendor actions, and produces closure evidence.

### A-019 Adverse-action support
A synthetic carrier adverse decision partially based on a consumer report produces the configured workflow with CRA identity, consumer-report linkage, responsible party, notice inputs, and dispute route.

### A-020 Audit integrity
Normal application roles cannot edit/delete historical AuditEvents. Tamper-evidence validation passes.

### A-021 Retention
Expired synthetic records transition to the configured disposition; legal-hold records do not.

### A-022 Provider credential isolation
Browser/mobile clients never receive provider credentials. Sandbox credentials cannot execute production requests.

### A-023 Admin security
Role, integration, provider, and notice activation changes require authorized admin access, step-up auth where specified, and audit evidence.

### A-024 Accessibility
Critical consumer and agent journeys pass automated checks plus manual keyboard and screen-reader verification against the approved baseline.

### A-025 Mobile usability
Consumer happy path is usable at common mobile widths with no horizontal scrolling and no inaccessible fixed overlays.

## P1 acceptance
- Agent can trace material observations to provenance in <=2 interactions.
- Consumer can resume an incomplete case securely.
- Notification delivery/bounce states are visible.
- Provider partial/no-hit states are normalized consistently.
- Stale report behavior follows provider freshness rules.
- Manual entry works when prefill fails.
- All case-state transitions are audited.
- Case closure and abandonment trigger retention scheduling.

## Contract tests per provider
Each adapter MUST prove:
- valid success;
- no hit;
- partial;
- stale response;
- validation failure;
- auth failure;
- timeout;
- throttling;
- malformed payload;
- duplicate idempotency;
- jurisdiction restriction;
- prohibited purpose;
- logging redaction.

## Carrier acceptance
Before a real Allstate/carrier adapter is enabled:
- contract/approval evidence recorded;
- submission schema approved;
- data-use mapping approved;
- auth/security method approved;
- sandbox test passed;
- duplicate-submission test passed;
- carrier error taxonomy mapped;
- response provenance preserved;
- premium/eligibility clearly labeled carrier-supplied;
- rollback/disable switch tested.

## Performance targets
Exact SLOs remain TBD until provider contracts and hosting are known. P0 behavior requirements:
- local validation and policy denials return without waiting on external providers;
- UI remains responsive during async enrichment;
- long provider operations use job/status patterns rather than blocking browser requests indefinitely;
- provider timeouts do not corrupt case state.

## Production go/no-go
GO requires all P0 tests passing plus closure of:
- Allstate/carrier integration authority;
- provider contracts;
- legal notice/authorization approval;
- data-use matrix;
- retention schedule;
- security review;
- incident response owner;
- privacy/FCRA ownership matrix.

Any unresolved item results in NO-GO unless an authorized risk owner provides a documented exception that does not violate law or contract.
