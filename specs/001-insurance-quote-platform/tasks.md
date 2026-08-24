# Implementation Tasks

## Ledger status
Reconciled against merged `main` acceptance evidence through PR #20 and the current T608–T610 implementation slice. Checked items are implemented and evidenced by the accepted runtime/CI chain. Items marked `PARTIAL` have meaningful implementation but do not yet satisfy the full task wording. External legal/provider/carrier/launch decisions remain open by design.

## Phase 0 — Governance and production prerequisites
- [ ] T001 Define the first production operator model: agency, brokerage, carrier program, or white-label deployment.
- [x] T002 Define generic CarrierAdapter contract and carrier capability registry.
- [x] T003 Define generic agency/tenant configuration and branding model.
- [ ] T004 Select and contract candidate MVR provider.
- [ ] T005 Select and contract candidate claims-history/CRA provider.
- [ ] T006 Select identity/prefill/vehicle providers as needed.
- [ ] T007 Complete provider role matrix: CRA status, DPPA purpose codes, state restrictions, notice/authorization, retention, dispute, raw-payload rules.
- [ ] T008 Legal review: insurance privacy notices, information-practices notice, FCRA/consumer-report disclosure, electronic consent, privacy policy, CCPA/CPRA applicability, TCPA/CAN-SPAM separation, adverse-action ownership.
- [ ] T009 Approve data-use matrix.
- [ ] T010 Approve retention schedule.
- [ ] T011 Assign security incident and privacy-rights owners.
- [x] T012 Define carrier onboarding/certification checklist independent of carrier name.

## Phase 1 — Repository and domain kernel
- [x] T100 Create runtime repository and link this specs repo as canonical requirement source. — Satisfied by the intentionally colocated runtime/spec layout and canonical read order; a second repository was not created.
- [ ] T101 Establish CI: typecheck, unit tests, lint, secret scan, dependency scan, SAST baseline. — PARTIAL: typecheck, tests, lint, deterministic dependency verification, build, database rebuild, pgTAP, DB lint, generated-type drift checks, and canonical scenario artifacts are implemented; secret scan/dependency-vulnerability scan/SAST baseline remain.
- [x] T102 Implement environment separation: local/CI/staging/production.
- [x] T103 Implement canonical IDs and timestamps.
- [x] T104 Implement QuoteCase state machine.
- [x] T105 Implement Agency, AgencyUser, Role, Permission, TenantConfiguration.
- [x] T106 Implement Prospect, Person, Driver, Vehicle, CoverageRequest.
- [x] T107 Implement NoticeDefinition and ConsentRecord.
- [x] T108 Implement PermissiblePurposeDecision.
- [x] T109 Implement ExternalRequest, ExternalReport, UnderwritingObservation.
- [x] T110 Implement DataUsePolicy and RatingInput boundary.
- [x] T111 Implement ReadinessIssue.
- [x] T112 Implement Carrier, CarrierProgram, CarrierSubmission, CarrierDecision.
- [x] T113 Implement PrivacyRequest and RetentionPolicy.
- [x] T114 Implement append-only AuditEvent pipeline.
- [x] T115 Create full synthetic fixture library.

## Phase 2 — Authentication and security baseline
- [ ] T200 Implement agency workforce identity provider abstraction. — PARTIAL: Supabase workforce context exists, but a provider abstraction is not yet complete.
- [x] T201 Enforce MFA.
- [x] T202 Implement RBAC + tenant/agency object scope.
- [x] T203 Implement service principal authentication.
- [x] T204 Implement consumer secure session/resume flow.
- [ ] T205 Implement KMS/secrets integration. — PARTIAL: server-only secrets and encrypted fields exist; production KMS lifecycle is not complete.
- [x] T206 Implement sensitive-field encryption/tokenization.
- [x] T207 Implement secure headers, CSP, CSRF controls, rate limits.
- [x] T208 Implement privacy-safe structured logging.
- [x] T209 Implement security alerts for denied/excessive lookup behavior.

## Phase 3 — Consumer quote experience
- [ ] T300 Build mobile-first quote landing/start flow.
- [ ] T301 Build identity/contact step.
- [ ] T302 Build versioned notice/authorization flow.
- [ ] T303 Build driver confirm/edit/add flow.
- [ ] T304 Build vehicle confirm/edit/add flow.
- [ ] T305 Build coverage request flow.
- [ ] T306 Build save/resume.
- [ ] T307 Build consumer review/submit.
- [ ] T308 Build no-hit/manual-entry fallback.
- [ ] T309 Build conflict/correction flow.
- [ ] T310 Build consumer status/follow-up flow.
- [ ] T311 Complete WCAG 2.2 AA engineering pass.
- [ ] T312 Implement tenant/agency theming without carrier-specific core components.

## Phase 4 — Provider gateway
- [x] T400 Define ProviderAdapter and capability descriptor contracts.
- [x] T401 Implement purpose/notice/jurisdiction policy preflight.
- [x] T402 Implement provider request idempotency.
- [ ] T403 Implement provider job queue/retry/circuit breaker. — PARTIAL: durable claim/retry/idempotent settlement exists; queue and circuit-breaker execution remain.
- [x] T404 Implement normalized result/provenance envelope.
- [x] T405 Implement synthetic StubIdentityAdapter.
- [x] T406 Implement synthetic StubPrefillAdapter.
- [x] T407 Implement synthetic StubMvrAdapter.
- [x] T408 Implement synthetic StubClaimsAdapter.
- [x] T409 Implement synthetic StubVehicleAdapter.
- [ ] T410 Add approved identity provider sandbox adapter.
- [ ] T411 Add approved prefill provider sandbox adapter.
- [ ] T412 Add approved MVR provider sandbox adapter.
- [ ] T413 Add approved claims provider sandbox adapter.
- [ ] T414 Add approved vehicle provider sandbox adapter.
- [ ] T415 Add contract tests for every adapter failure mode. — PARTIAL: synthetic adapter and canonical scenario failure contracts exist; live/sandbox adapters do not yet exist.

## Phase 5 — Normalization and readiness
- [x] T500 Implement field-level provenance.
- [x] T501 Implement UnderwritingObservation construction.
- [x] T502 Implement data-use policy enforcement.
- [x] T503 Implement conflict detection.
- [x] T504 Implement freshness/stale-report rules.
- [x] T505 Implement completeness-only readiness engine.
- [x] T506 Verify no observation can bypass RatingInput allowlist.
- [x] T507 Implement carrier-program field requirement overlays without modifying canonical domain entities.

## Phase 6 — Agent workspace
- [x] T600 Build quote queue.
- [x] T601 Build case detail view.
- [x] T602 Build readiness/blocking issues panel.
- [x] T603 Build driver/vehicle/coverage sections.
- [x] T604 Build external-report status panel.
- [x] T605 Build underwriting observation panel.
- [x] T606 Build provenance drawer.
- [x] T607 Build permitted provider refresh controls.
- [x] T608 Build issue-resolution workflow.
- [x] T609 Build consumer follow-up request flow.
- [x] T610 Build case audit timeline.
- [x] T611 Build configured carrier/program target selector where deployment permits multiple targets.

## Phase 7 — Carrier gateway
- [x] T700 Implement synthetic StubCarrierAdapter as the default build target.
- [x] T701 Implement CarrierAdapter capability descriptor.
- [x] T702 Implement carrier submission allowlist/schema mapping.
- [x] T703 Implement carrier submission idempotency.
- [x] T704 Implement carrier response/decision provenance.
- [x] T705 Implement per-carrier kill switch/disable control.
- [ ] T706 Implement adapter modes: API, deep link, AMS/comparative-rater bridge, structured export, manual handoff. — PARTIAL: capability/configuration model supports multiple modes; concrete mode implementations are not complete.
- [x] T707 Implement carrier-program configuration and versioning.
- [ ] T708 Add generic carrier adapter contract test suite. — PARTIAL: deterministic synthetic carrier contract/portability tests exist; reusable live-adapter certification suite remains.
- [ ] T709 Certify first live carrier adapter when a production partner is selected.
- [x] T710 Verify switching carrier adapters does not require core-domain code changes.

## Phase 8 — Compliance operations
- [x] T800 Build privacy request intake.
- [x] T801 Build identity verification for privacy requests.
- [x] T802 Build data discovery/export pipeline.
- [x] T803 Build correction/deletion/restriction execution workflow.
- [x] T804 Implement downstream vendor propagation tracking.
- [x] T805 Build retention scheduler/disposition worker.
- [x] T806 Implement legal hold.
- [x] T807 Build adverse-action support workflow.
- [x] T808 Build notice delivery evidence.
- [x] T809 Build compliance evidence export.
- [x] T810 Build notice/version administration.
- [x] T811 Build data-use/retention policy inspection admin surfaces.

## Phase 9 — Operations and production hardening
- [ ] T900 Define SLOs, RPO, RTO.
- [ ] T901 Load/performance test.
- [ ] T902 Restore/backup drill.
- [ ] T903 Provider outage drill.
- [ ] T904 Provider credential rotation drill.
- [ ] T905 Incident-response tabletop.
- [ ] T906 Privacy-rights end-to-end rehearsal.
- [ ] T907 FCRA/adverse-action synthetic rehearsal.
- [ ] T908 Penetration test/independent security assessment.
- [ ] T909 Resolve all critical/high findings.
- [x] T910 Run full P0 acceptance suite against synthetic providers and StubCarrierAdapter.
- [ ] T911 Obtain legal/compliance launch approval for the selected deployment.
- [ ] T912 Complete first live agency/carrier/provider production certification.
- [ ] T913 Production deployment and smoke test.
- [ ] T914 Post-launch audit and first-week control review.

## Dependency rule
Core implementation phases MAY proceed against deterministic synthetic providers and `StubCarrierAdapter`. No later task may silently convert an unresolved production-specific legal, provider, carrier, or agency requirement into an implementation assumption. Production activation requires evidence; core build completion does not.
