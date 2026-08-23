# Implementation Tasks

## Phase 0 — External authority and governance
- [ ] T001 Confirm local Allstate agency relationship, authorized external-app use, data-storage constraints, branding rules, and security/vendor onboarding.
- [ ] T002 Identify approved Allstate/carrier quote handoff method.
- [ ] T003 Determine whether Allstate mandates specific MVR/claims providers.
- [ ] T004 Select and contract candidate MVR provider.
- [ ] T005 Select and contract candidate claims-history/CRA provider.
- [ ] T006 Select identity/prefill/vehicle providers as needed.
- [ ] T007 Complete provider role matrix: CRA status, DPPA purpose codes, state restrictions, notice/authorization, retention, dispute, raw-payload rules.
- [ ] T008 Legal review: insurance privacy notices, information-practices notice, FCRA/consumer-report disclosure, electronic consent, privacy policy, CCPA/CPRA applicability, TCPA/CAN-SPAM separation, adverse-action ownership.
- [ ] T009 Approve data-use matrix.
- [ ] T010 Approve retention schedule.
- [ ] T011 Assign security incident and privacy-rights owners.

## Phase 1 — Repository and domain kernel
- [ ] T100 Create runtime repository and link this specs repo as canonical requirement source.
- [ ] T101 Establish CI: typecheck, unit tests, lint, secret scan, dependency scan, SAST baseline.
- [ ] T102 Implement environment separation: local/CI/staging/production.
- [ ] T103 Implement canonical IDs and timestamps.
- [ ] T104 Implement QuoteCase state machine.
- [ ] T105 Implement Agency, AgencyUser, Role, Permission.
- [ ] T106 Implement Prospect, Person, Driver, Vehicle, CoverageRequest.
- [ ] T107 Implement NoticeDefinition and ConsentRecord.
- [ ] T108 Implement PermissiblePurposeDecision.
- [ ] T109 Implement ExternalRequest, ExternalReport, UnderwritingObservation.
- [ ] T110 Implement DataUsePolicy and RatingInput boundary.
- [ ] T111 Implement ReadinessIssue.
- [ ] T112 Implement CarrierSubmission and CarrierDecision.
- [ ] T113 Implement PrivacyRequest and RetentionPolicy.
- [ ] T114 Implement append-only AuditEvent pipeline.
- [ ] T115 Create full synthetic fixture library.

## Phase 2 — Authentication and security baseline
- [ ] T200 Implement agency workforce identity provider.
- [ ] T201 Enforce MFA.
- [ ] T202 Implement RBAC + agency object scope.
- [ ] T203 Implement service principal authentication.
- [ ] T204 Implement consumer secure session/resume flow.
- [ ] T205 Implement KMS/secrets integration.
- [ ] T206 Implement sensitive-field encryption/tokenization.
- [ ] T207 Implement secure headers, CSP, CSRF controls, rate limits.
- [ ] T208 Implement privacy-safe structured logging.
- [ ] T209 Implement security alerts for denied/excessive lookup behavior.

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

## Phase 4 — Provider gateway
- [ ] T400 Define ProviderAdapter and capability descriptor contracts.
- [ ] T401 Implement purpose/notice/jurisdiction policy preflight.
- [ ] T402 Implement provider request idempotency.
- [ ] T403 Implement provider job queue/retry/circuit breaker.
- [ ] T404 Implement normalized result/provenance envelope.
- [ ] T405 Implement synthetic StubIdentityAdapter.
- [ ] T406 Implement synthetic StubPrefillAdapter.
- [ ] T407 Implement synthetic StubMvrAdapter.
- [ ] T408 Implement synthetic StubClaimsAdapter.
- [ ] T409 Implement synthetic StubVehicleAdapter.
- [ ] T410 Add approved identity provider sandbox adapter.
- [ ] T411 Add approved prefill provider sandbox adapter.
- [ ] T412 Add approved MVR provider sandbox adapter.
- [ ] T413 Add approved claims provider sandbox adapter.
- [ ] T414 Add approved vehicle provider sandbox adapter.
- [ ] T415 Add contract tests for every adapter failure mode.

## Phase 5 — Normalization and readiness
- [ ] T500 Implement field-level provenance.
- [ ] T501 Implement UnderwritingObservation construction.
- [ ] T502 Implement data-use policy enforcement.
- [ ] T503 Implement conflict detection.
- [ ] T504 Implement freshness/stale-report rules.
- [ ] T505 Implement completeness-only readiness engine.
- [ ] T506 Verify no observation can bypass RatingInput allowlist.

## Phase 6 — Agent workspace
- [ ] T600 Build quote queue.
- [ ] T601 Build case detail view.
- [ ] T602 Build readiness/blocking issues panel.
- [ ] T603 Build driver/vehicle/coverage sections.
- [ ] T604 Build external-report status panel.
- [ ] T605 Build underwriting observation panel.
- [ ] T606 Build provenance drawer.
- [ ] T607 Build permitted provider refresh controls.
- [ ] T608 Build issue-resolution workflow.
- [ ] T609 Build consumer follow-up request flow.
- [ ] T610 Build case audit timeline.

## Phase 7 — Carrier handoff
- [ ] T700 Keep carrier stub enabled until external authority is resolved.
- [ ] T701 Implement approved CarrierAdapter mode only.
- [ ] T702 Implement carrier submission allowlist/schema mapping.
- [ ] T703 Implement carrier submission idempotency.
- [ ] T704 Implement carrier response/decision provenance.
- [ ] T705 Implement kill switch/disable control.
- [ ] T706 Complete carrier sandbox certification/acceptance.

## Phase 8 — Compliance operations
- [ ] T800 Build privacy request intake.
- [ ] T801 Build identity verification for privacy requests.
- [ ] T802 Build data discovery/export pipeline.
- [ ] T803 Build correction/deletion/restriction execution workflow.
- [ ] T804 Implement downstream vendor propagation tracking.
- [ ] T805 Build retention scheduler/disposition worker.
- [ ] T806 Implement legal hold.
- [ ] T807 Build adverse-action support workflow.
- [ ] T808 Build notice delivery evidence.
- [ ] T809 Build compliance evidence export.
- [ ] T810 Build notice/version administration.
- [ ] T811 Build data-use/retention policy inspection admin surfaces.

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
- [ ] T910 Run full P0 acceptance suite.
- [ ] T911 Obtain legal/compliance launch approval.
- [ ] T912 Obtain agency/carrier production approval.
- [ ] T913 Production deployment and smoke test.
- [ ] T914 Post-launch audit and first-week control review.

## Dependency rule
No task in a later phase may silently resolve an unresolved Phase 0 assumption. External authority must be evidenced, not inferred from technical feasibility.
