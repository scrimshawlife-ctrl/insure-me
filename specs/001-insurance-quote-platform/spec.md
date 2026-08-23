# Feature Specification: Insurance Quote Platform

## Status
Draft canonical specification for MVP.

## Product statement
Insure Me is a California private-passenger auto insurance intake and quote-preparation platform for a local insurance agency. It gives consumers a low-friction mobile-friendly quote intake experience and gives agents a clear, auditable workspace that assembles authorized underwriting data and hands a quote-ready package to the carrier-approved rating or quoting workflow.

## Goals
1. Reduce consumer typing through safe prefill and verification.
2. Give agents one normalized view of drivers, vehicles, claims, MVR status, current coverage context, missing data, and source provenance.
3. Enforce purpose, consent/notice, jurisdiction, provider, and carrier controls before regulated data access.
4. Keep carrier rating and binding authority outside the platform unless explicitly authorized later.
5. Make privacy, FCRA/DPPA workflows, auditability, correction, and retention operational product capabilities.
6. Support provider substitution without redesigning the core domain model.
7. Produce an implementation-ready specification with acceptance tests and launch gates.

## Non-goals for MVP
- independent actuarial pricing;
- policy binding or issuance without carrier authorization;
- claims administration;
- payments;
- home, renters, life, commercial, or multi-state insurance;
- arbitrary DMV/public-record lookup;
- autonomous adverse underwriting decisions;
- consumer-report resale or unrelated profiling;
- advertising enrichment from underwriting data.

## Personas
### Prospect
A California resident seeking a private-passenger auto quote.

### Agent
A licensed or otherwise authorized agency user who reviews quote cases and completes carrier workflows.

### Agency Administrator
Manages users, roles, provider configuration, carrier configuration, notice versions, retention settings, and operational audit access.

### Compliance/Security Reviewer
Reviews data-access evidence, privacy rights activity, vendor behavior, incidents, and launch controls.

### Service Principal
A backend identity allowed to execute narrowly scoped system actions. It must never bypass purpose or jurisdiction controls.

## Primary consumer journey
1. Prospect starts a quote.
2. System collects minimal contact and identity attributes required for the next lawful step.
3. System presents applicable privacy notice, information-practices disclosure, and any report-specific authorization/acknowledgment.
4. Prospect acknowledges or authorizes where required.
5. System verifies identity to the degree needed by configured providers and fraud controls.
6. System obtains approved prefill data when permitted.
7. Prospect confirms or edits discovered household/driver/vehicle data.
8. System requests MVR, claims history, VIN/vehicle data, and other approved reports only when prerequisites are satisfied.
9. System normalizes results into source-backed observations and flags missing/conflicting data.
10. Prospect supplies remaining information such as annual mileage, garaging, requested coverage, and other carrier-required fields.
11. Agent receives a quote-readiness workspace.
12. Agent resolves exceptions and submits the case through the carrier-approved handoff.
13. Carrier returns or presents its authoritative quote decision.
14. Insure Me records the handoff, carrier response metadata, relevant reason codes, and notice obligations without claiming ownership of carrier rating logic.

## Primary agent journey
1. Authenticate with MFA.
2. Open assigned/new QuoteCase.
3. Review identity, drivers, vehicles, coverage request, report completion, conflicts, and missing fields.
4. Inspect source provenance for any external fact.
5. Request a permitted refresh only when purpose and retention rules allow it.
6. Correct user-entered data or send consumer correction flow as appropriate.
7. Resolve blocking readiness issues.
8. Initiate carrier handoff.
9. Record carrier result and required follow-up.
10. If a consumer-report-based adverse result occurs, trigger the configured notice and dispute workflow owned by the responsible party.

## Functional requirements

### FR-001 QuoteCase creation
The system MUST create a unique QuoteCase with jurisdiction, agency, product line, lifecycle state, and source channel before any regulated lookup.

### FR-002 Identity and contact
The system MUST collect only attributes required for the configured quote workflow and MUST distinguish user-provided from externally derived values.

### FR-003 Notice and consent ledger
The system MUST version notices/authorizations and record subject, text/version identifier, presentation time, acknowledgment/authorization action, timestamp, channel, and evidence.

### FR-004 Purpose enforcement
Every regulated external request MUST validate QuoteCase, jurisdiction, requesting actor, provider capability, permissible purpose, and required notice/authorization state before execution.

### FR-005 Provider gateway
The system MUST expose provider-neutral capability contracts for identity verification, prefill, MVR, claims history, vehicle data, and insurance-history services.

### FR-006 Provider report preservation
The system MUST retain immutable report metadata and a normalized representation sufficient for provenance, dispute support, audit, and carrier handoff. Storage of raw provider payloads MUST follow provider contract and retention policy.

### FR-007 Driver workflow
The system MUST support multiple drivers, driver relationship/role, license metadata, years licensed where carrier-required, and source-aware corrections.

### FR-008 Vehicle workflow
The system MUST support multiple vehicles, VIN validation/decoding, ownership/lease status where required, garaging, usage, and mileage inputs.

### FR-009 Claims/MVR observations
The system MUST convert external facts into UnderwritingObservations without converting them directly into a premium or eligibility decision.

### FR-010 Data-use classification
Each material normalized attribute MUST have a data-use classification that controls collect, display, underwriting, rating, carrier-only, and prohibited states.

### FR-011 Quote readiness
The system MUST calculate readiness from completeness and workflow prerequisites only. Readiness MUST NOT be represented as risk score, insurability score, or premium prediction.

### FR-012 Carrier handoff
The system MUST support a provider-neutral CarrierAdapter. MVP MAY support redirect, deep link, secure export, or API submission depending on Allstate/carrier approval.

### FR-013 Carrier response
Carrier-returned premium, eligibility, bind status, and reason codes MUST be stored as CarrierDecision data with carrier provenance.

### FR-014 Human review
Agents MUST be able to inspect and resolve missing/conflicting data before handoff. The system MUST NOT silently choose among materially conflicting external facts.

### FR-015 Consumer correction/dispute
The system MUST support consumer correction requests for user-maintained data and route external-report disputes to the responsible CRA/provider/carrier process as required.

### FR-016 Adverse-action workflow
When the responsible party determines that FCRA or state adverse-action notice duties are triggered, the system MUST support generating/recording the required notice inputs and delivery evidence. Responsibility MUST be configurable because the agency, carrier, or another party may own the notice.

### FR-017 Privacy rights
The system MUST maintain workflows for applicable access, correction, deletion, restriction/opt-out, and identity verification requests, with legal/contractual exemptions applied by rule rather than silent deletion.

### FR-018 Retention
Each data category MUST map to an approved retention rule. Expiration MUST create deletion, anonymization, or legal-hold work rather than indefinite storage.

### FR-019 Audit
Sensitive reads, writes, exports, external requests, permission changes, consent actions, privacy-rights actions, carrier submissions, and administrative changes MUST emit tamper-evident AuditEvents.

### FR-020 Authentication and authorization
Agents and administrators MUST use strong authentication with MFA. Authorization MUST be agency-scoped and role/permission based.

### FR-021 Consumer session security
Consumer quote sessions MUST use secure, expiring access mechanisms. Sensitive identifiers MUST not appear in URLs or analytics.

### FR-022 Notification
Email/SMS MAY be used for magic links, status updates, missing-information requests, and required notices. Marketing messaging MUST be separately governed and MUST NOT be implied by quote consent.

### FR-023 Accessibility
Consumer and agent surfaces MUST meet the approved accessibility target, with WCAG 2.2 AA used as the engineering baseline unless counsel/contract requires another standard.

### FR-024 Observability
Operational telemetry MUST avoid raw PII and report contents. Metrics MUST use opaque identifiers and approved low-risk dimensions.

### FR-025 Synthetic fixtures
A complete synthetic quote fixture set MUST exist for happy path, no-hit, multiple drivers, multiple vehicles, conflicting records, stale report, provider outage, consumer correction, adverse-action handoff, privacy deletion, and unauthorized lookup attempts.

## Lifecycle states
QuoteCase states:
- DRAFT
- NOTICE_REQUIRED
- CONSUMER_INPUT
- DATA_ENRICHMENT
- REVIEW_REQUIRED
- READY_FOR_CARRIER
- SUBMITTED_TO_CARRIER
- CARRIER_RESPONSE
- FOLLOW_UP
- CLOSED
- ABANDONED
- RETENTION_HOLD

State transitions MUST be explicit and auditable.

## Key invariants
- No regulated lookup without a QuoteCase.
- No lookup without permissible-purpose evaluation.
- No provider request if jurisdiction/provider capability forbids it.
- No required report request before required notice/authorization state is met.
- ExternalReport != UnderwritingObservation != RatingInput != CarrierDecision.
- Readiness != risk score.
- Consumer quote consent != marketing consent.
- Provider success != legal permission to use returned data for rating.
- Carrier quote != Insure Me quote unless the carrier expressly delegates quoting authority.

## Product success metrics
MVP metrics, measured without exposing PII:
- quote-start to consumer-complete conversion;
- median consumer completion time;
- fields auto-filled then confirmed vs manually entered;
- agent handling time before carrier handoff;
- percentage of cases reaching READY_FOR_CARRIER without manual data chase;
- provider request success/error/no-hit rate;
- correction rate by data source;
- privacy/dispute SLA compliance;
- unauthorized lookup attempts blocked;
- audit-event completeness.

Targets remain `TBD` until baseline data exists.

## Blocking assumptions
- `BLOCKED-ALLSTATE-001`: confirm whether the local Allstate agency may use this external intake/orchestration platform and what data may be stored outside Allstate systems.
- `BLOCKED-ALLSTATE-002`: identify approved carrier handoff mode/API/deep-link/export and required security review.
- `BLOCKED-PROVIDER-001`: contract and approve MVR provider.
- `BLOCKED-PROVIDER-002`: contract and approve claims-history provider/CRA.
- `BLOCKED-LEGAL-001`: counsel/compliance approval of notices, authorizations, privacy rights, retention, adverse-action ownership, and data-use matrix.
- `BLOCKED-SECURITY-001`: production security assessment and incident-response approval.

## Release criterion
MVP is production-ready only when all P0 acceptance criteria pass and all launch-blocking assumptions are resolved or explicitly waived by an authorized owner in a documented decision record.
