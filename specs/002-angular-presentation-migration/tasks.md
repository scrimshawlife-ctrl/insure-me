# Tasks: Angular Presentation Migration

## T0 — Governance and contract freeze
- [x] T0.1 Confirm Angular 22.x as canonical presentation framework for this migration.
- [x] T0.2 Inventory current Next.js routes, API calls, auth/session behavior, environment variables, and P0 workflows.
- [x] T0.3 Map every frontend API call to a canonical HTTP contract and define required Angular read projections.
- [x] T0.4 Record uncovered API-contract gaps; do not silently solve them with frontend-only DTOs.
- [x] T0.5 Confirm existing constitution invariants remain unchanged.
- [x] T0.6 Define rollback routing/version strategy before cutover work begins.

T0 evidence: `t0-contract-inventory.md`, `t0-browser-api-matrix.md`, `t0-contract-reconciliation.md`, and `t0-api-contract-addendum.md`.

T0 is closed for migration planning. T3 generated-client completion remains blocked until every required read/write projection exists as an executable server route or generated/verified contract surface.

## T1 — Angular workspace
- [ ] T1.1 Create Angular 22 workspace with strict TypeScript and standalone application configuration.
- [ ] T1.2 Configure Angular Router and lazy feature boundaries.
- [ ] T1.3 Create `core`, `shared`, `applicant`, `quoting`, `evidence`, `compliance`, `agent`, and `admin` boundaries.
- [ ] T1.4 Configure environment/runtime configuration without exposing secrets to the browser bundle.
- [ ] T1.5 Configure lint, formatting, type-check, unit/component test, contract-test, and E2E commands.
- [ ] T1.6 Add deterministic synthetic API/fixture mode.

## T2 — Core runtime plumbing
- [ ] T2.1 Integrate existing authentication/session contract.
- [ ] T2.2 Configure HttpClient.
- [ ] T2.3 Add functional auth interceptor where required by the existing contract.
- [ ] T2.4 Add opaque request/correlation ID interceptor.
- [ ] T2.5 Add normalized error interceptor/mapping.
- [ ] T2.6 Add approved telemetry plumbing with PII-redaction tests.
- [ ] T2.7 Add route guards for navigation UX while preserving server authorization as authority.
- [ ] T2.8 Add global loading, empty, unavailable, forbidden, and generic-error primitives.

## T3 — Typed API client
- [ ] T3.1 Generate or verify TypeScript client/types from canonical OpenAPI/JSON Schema.
- [ ] T3.2 Add CI contract-drift check.
- [ ] T3.3 Add feature facades for quote, evidence, carrier, privacy, compliance, and admin APIs where needed.
- [ ] T3.4 Prohibit provider-specific DTOs in Angular feature/domain code.
- [ ] T3.5 Prohibit carrier-name branching in Angular feature/domain code.

## T4 — Shared UI and accessibility
- [ ] T4.1 Implement mobile-first application shell and navigation.
- [ ] T4.2 Implement accessible form controls, validation summary, stepper/wizard navigation, dialogs, tables/lists, badges, alerts, and empty/error states.
- [ ] T4.3 Establish WCAG 2.2 AA automated and manual checks.
- [ ] T4.4 Establish responsive viewport acceptance for current target devices/breakpoints.

## T5 — Form system
- [ ] T5.1 Implement typed reactive-form patterns for stable fields.
- [ ] T5.2 Define versioned questionnaire schema contract for variable fields.
- [ ] T5.3 Implement schema-to-control registry.
- [ ] T5.4 Preserve required/optional state, validation constraints, source/provenance semantics, and jurisdiction/program scope.
- [ ] T5.5 Add client/server validation parity tests.
- [ ] T5.6 Verify frontend validation never substitutes for server policy/authorization checks.

## T6 — Applicant workflow parity
- [ ] T6.1 Quote initiation.
- [ ] T6.2 Notice/disclosure presentation and acknowledgment/authorization.
- [ ] T6.3 Contact and identity inputs.
- [ ] T6.4 Household and drivers.
- [ ] T6.5 Vehicles/VIN/usage/mileage.
- [ ] T6.6 Coverage request.
- [ ] T6.7 Prefill confirmation/correction states.
- [ ] T6.8 Save/resume.
- [ ] T6.9 Review and submit-to-agent/readiness transition.
- [ ] T6.10 Mobile and accessibility parity.

## T7 — Evidence and quote presentation
- [ ] T7.1 Render canonical evidence facts with provenance.
- [ ] T7.2 Render MATCH, NO_HIT, PARTIAL, STALE, and ERROR distinctly.
- [ ] T7.3 Render conflicts without silently selecting a material fact.
- [ ] T7.4 Render quote/carrier decisions as carrier-authoritative results.
- [ ] T7.5 Ensure no client-side authoritative pricing or underwriting logic exists.

## T8 — Agent workspace parity
- [ ] T8.1 Case queue/dashboard.
- [ ] T8.2 QuoteCase detail.
- [ ] T8.3 Readiness blockers and missing-data view.
- [ ] T8.4 Evidence/provenance inspection.
- [ ] T8.5 Correction workflow.
- [ ] T8.6 Permitted provider refresh initiation.
- [ ] T8.7 CarrierProgram selection from capability/configuration metadata.
- [ ] T8.8 StubCarrierAdapter handoff preparation and execution.
- [ ] T8.9 Carrier response/follow-up presentation.

## T9 — Compliance and admin parity
- [ ] T9.1 Privacy-rights request views/actions.
- [ ] T9.2 Adverse-action support workflow.
- [ ] T9.3 Retention/deletion/legal-hold status views.
- [ ] T9.4 Disclosure/authorization history.
- [ ] T9.5 Audit evidence browser.
- [ ] T9.6 Tenant/user/role administration.
- [ ] T9.7 Provider binding and CarrierProgram configuration projections.
- [ ] T9.8 Synthetic environment and system-health surfaces.

## T10 — Security verification
- [ ] T10.1 Prove server-side authorization rejects direct unauthorized calls despite route-guard bypass.
- [ ] T10.2 Inspect localStorage/sessionStorage/IndexedDB/service-worker caches for prohibited sensitive data.
- [ ] T10.3 Inspect logs, telemetry, error reporting, and source maps for PII leakage.
- [ ] T10.4 Verify no provider/carrier/server credentials appear in browser artifacts.
- [ ] T10.5 Verify CSP and XSRF/CSRF behavior for selected hosting model.
- [ ] T10.6 Verify authenticated data cannot enter public/static caches.
- [ ] T10.7 Execute tenant-isolation negative tests.

## T11 — Contract and synthetic E2E verification
- [ ] T11.1 Happy path.
- [ ] T11.2 NO_HIT.
- [ ] T11.3 Multiple drivers/vehicles.
- [ ] T11.4 Conflicting records.
- [ ] T11.5 Stale evidence.
- [ ] T11.6 Provider outage/retry/manual-review state.
- [ ] T11.7 Consumer correction.
- [ ] T11.8 Adverse-action handoff.
- [ ] T11.9 Privacy deletion/exemption path.
- [ ] T11.10 Unauthorized lookup attempt.
- [ ] T11.11 Carrier adapter failure.
- [ ] T11.12 Full StubCarrierAdapter handoff.

## T12 — Cutover
- [ ] T12.1 Deploy Angular in parallel or behind controlled routing.
- [ ] T12.2 Execute P0 parity acceptance against the same backend/versioned fixtures.
- [ ] T12.3 Exercise rollback to prior frontend artifact/version.
- [ ] T12.4 Record migration evidence and known non-P0 gaps.
- [ ] T12.5 Cut over only when acceptance gate is PASS.
- [ ] T12.6 Remove Next.js presentation code in a separate cleanup change after rollback confidence is established.

## Dependency order
`T0 -> T1 -> T2/T3/T4 -> T5 -> T6 -> T7/T8 -> T9 -> T10/T11 -> T12`

Parallel work is allowed only when shared contracts are already frozen and tasks do not create competing frontend domain models.
