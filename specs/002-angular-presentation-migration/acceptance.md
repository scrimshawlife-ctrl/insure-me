# Acceptance: Angular Presentation Migration

## Verdict model
Each criterion is `PASS`, `FAIL`, `BLOCKED`, or `NOT_APPLICABLE` with evidence.

The migration cutover verdict is `PASS` only when every P0 criterion is `PASS`. `BLOCKED` is not equivalent to pass.

## P0 — Architecture and authority

### ANG-ACC-001 Framework identity
**Given** the migrated web application
**When** build metadata and source configuration are inspected
**Then** it uses Angular 22.x and standalone application/component configuration for new code.

### ANG-ACC-002 Server authority preserved
**Given** a protected or regulated action
**When** a caller bypasses Angular route guards or directly calls the API without required authorization/purpose/consent
**Then** the server rejects the action and no regulated provider/carrier action executes.

### ANG-ACC-003 No canonical domain rewrite
**Given** the migration diff
**When** canonical entities and API schemas are compared before/after
**Then** no QuoteCase, Person, Driver, Vehicle, ExternalReport, UnderwritingObservation, RatingInput, CarrierSubmission, CarrierDecision, privacy, consent, retention, or audit semantic changed solely to satisfy Angular.

### ANG-ACC-004 Provider neutrality
**Given** Angular feature/domain code
**When** source is scanned
**Then** provider names/types do not control canonical feature behavior and provider-specific payload types are restricted to server adapter boundaries.

### ANG-ACC-005 Carrier neutrality
**Given** Angular feature/domain code
**When** source is scanned
**Then** carrier names do not control core branching behavior; CarrierProgram capability/configuration drives permissible carrier-specific presentation.

## P0 — Contracts

### ANG-ACC-010 Typed contract parity
**Given** the canonical OpenAPI/JSON Schema
**When** frontend contract tests run
**Then** every Angular API request/response used by P0 flows matches the canonical schema with zero unreviewed drift.

### ANG-ACC-011 Error semantic preservation
**Given** server responses for validation, authorization, prerequisite failure, NO_HIT, PARTIAL, STALE, provider unavailable, carrier rejection, and ambiguous carrier state
**When** Angular renders each response
**Then** materially distinct server states remain distinguishable and are not collapsed into a generic success/error state.

## P0 — Applicant workflow

### ANG-ACC-020 Quote initiation
Prospect can start a synthetic QuoteCase and receives the canonical jurisdiction/tenant/product context without regulated lookup occurring prematurely.

### ANG-ACC-021 Notice and authorization
Required notice/disclosure content and versions are displayed and server-confirmed acknowledgment/authorization is recorded before dependent regulated requests execute.

### ANG-ACC-022 Driver and vehicle intake
Multiple drivers and multiple vehicles can be entered/confirmed/corrected using typed Angular forms without loss of source/provenance semantics.

### ANG-ACC-023 Save/resume
A synthetic applicant can leave and resume the workflow with server-authoritative state restored correctly.

### ANG-ACC-024 Mobile/accessibility baseline
P0 applicant screens satisfy the project WCAG 2.2 AA engineering baseline and remain usable on the approved mobile viewport matrix.

## P0 — Evidence and agent workflow

### ANG-ACC-030 Provenance
Agent can inspect source, retrieval time/status, and canonical provenance for externally derived facts where the server contract provides it.

### ANG-ACC-031 NO_HIT/PARTIAL/STALE
Synthetic NO_HIT, PARTIAL, and STALE evidence fixtures produce distinct UI states and do not fabricate facts.

### ANG-ACC-032 Conflict preservation
Material conflicting evidence remains visibly unresolved until an authorized workflow resolves it; Angular does not silently choose a winner.

### ANG-ACC-033 Readiness semantics
Readiness is presented as completeness/workflow readiness and is never labeled or computed as risk score, insurability score, or predicted premium.

### ANG-ACC-034 Stub carrier handoff
Agent can complete the synthetic readiness-to-StubCarrierAdapter handoff and observe the canonical CarrierSubmission/CarrierDecision state end-to-end.

## P0 — Compliance/admin

### ANG-ACC-040 Privacy workflow
Synthetic access/correction/deletion or applicable exemption/hold flows can be initiated and their server-authoritative status observed.

### ANG-ACC-041 Adverse-action support
Synthetic adverse-action support data can be rendered and handed through the configured responsible-party workflow without Angular independently determining that adverse action is legally required.

### ANG-ACC-042 Audit projection
Authorized reviewer can inspect required synthetic audit evidence without exposing unauthorized cross-tenant records.

### ANG-ACC-043 Tenant isolation
Cross-tenant direct route manipulation and direct API calls fail server-side without resource-existence leakage beyond approved error semantics.

## P0 — Sensitive data and browser security

### ANG-ACC-050 Browser persistence
Automated/manual inspection shows no raw provider reports, credentials, secrets, full license numbers, full DOB, or other prohibited high-risk fields persisted in localStorage, sessionStorage, IndexedDB, or service-worker caches.

### ANG-ACC-051 Browser artifacts
Built browser assets contain no provider credentials, carrier credentials, managed-service secrets, private keys, or server-only environment values.

### ANG-ACC-052 Telemetry/logging
Client logs, telemetry, analytics, and error reporting contain no prohibited raw PII/report contents under all P0 synthetic scenarios.

### ANG-ACC-053 Public cache separation
Authenticated applicant/agent/admin/compliance responses are not emitted into public static artifacts or shared public caches by Angular rendering configuration.

## P0 — Synthetic scenario coverage
The following canonical deterministic scenarios MUST pass end-to-end:
- happy path;
- NO_HIT;
- multiple drivers;
- multiple vehicles;
- conflicting records;
- stale report;
- provider outage;
- consumer correction;
- adverse-action handoff;
- privacy deletion/exemption;
- unauthorized lookup attempt;
- carrier adapter failure;
- successful StubCarrierAdapter handoff.

## P0 — Cutover and rollback

### ANG-ACC-070 Parallel verification
Angular can be exercised against the same canonical backend/contracts as the prior presentation shell without a separate Angular-specific domain backend.

### ANG-ACC-071 Rollback
A failed Angular deployment can be routed back to the prior presentation artifact/version without reversing canonical regulated-data migrations solely due to the frontend rollback.

### ANG-ACC-072 Retirement gate
Next.js presentation code is not removed before all P0 criteria pass and rollback evidence is recorded.

## P1 — Quality and maintainability

### ANG-ACC-100 Lazy boundaries
Major applicant, agent, admin, and compliance features are lazy-loaded or otherwise isolated so unrelated authenticated features do not require one monolithic initial bundle.

### ANG-ACC-101 State discipline
Signals/computed state are feature-scoped by default; no global state library is introduced without a recorded cross-feature requirement.

### ANG-ACC-102 Schema-driven questionnaire
At least one representative configurable questionnaire path executes from versioned schema/configuration through Angular controls and server validation.

### ANG-ACC-103 Component accessibility
Reusable controls include deterministic accessible name, focus, validation, keyboard, and error-message behavior.

### ANG-ACC-104 Observability
Frontend performance/error metrics use opaque or approved dimensions and correlate with server request IDs without raw PII.

## Evidence required for cutover
- commit SHA and Angular version;
- canonical contract/schema version or SHA;
- synthetic fixture version/SHA;
- CI links/results for unit/component/contract/E2E tests;
- tenant/auth negative-test evidence;
- browser-storage scan evidence;
- built-artifact secret scan evidence;
- accessibility report;
- rollback test/evidence;
- explicit list of remaining P1/P2 gaps.

## Cutover verdict template

```text
ANGULAR_PRESENTATION_MIGRATION
commit_sha: <sha>
angular_version: <version>
contract_version: <sha/version>
fixture_version: <sha/version>
P0: PASS|FAIL|BLOCKED
P1: PASS|PARTIAL|NOT_RUN
rollback_verified: true|false
nextjs_retirement_authorized: true|false
notes: <evidence-backed notes>
```
