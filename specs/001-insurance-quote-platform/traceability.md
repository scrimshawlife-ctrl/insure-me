# Requirements Traceability

## Purpose
Map product requirements to controls, implementation areas, and acceptance evidence. This file is the index for change review.

| Requirement | Control/Design | Implementation Area | Acceptance |
|---|---|---|---|
| FR-001 QuoteCase creation | lifecycle state machine | quote-core | A-001 |
| FR-003 Notice/consent ledger | immutable versioned evidence | notice-ledger | A-003, A-017 |
| FR-004 Purpose enforcement | preflight policy decision | provider-gateway/policy-engine | A-001, A-002, A-004 |
| FR-005 Provider gateway | provider-neutral adapters | provider-gateway | provider contract suite |
| FR-006 Report preservation | normalized report + provenance | normalization/storage | A-007 |
| FR-009 MVR/claims observations | source-backed observations | normalization | A-007, A-008 |
| FR-010 Data-use classification | DataUsePolicy | policy-engine | A-009 |
| FR-011 Quote readiness | completeness-only engine | readiness | A-010 |
| FR-012 Carrier handoff | CarrierAdapter | carrier-gateway | A-011, A-013 |
| FR-014 Human review | ReadinessIssue + conflict state | agent workspace | A-008 |
| FR-015 Correction/dispute | correction + provider route | quote-core/privacy | A-019 support |
| FR-016 Adverse action | configurable ownership workflow | compliance ops | A-019 |
| FR-017 Privacy rights | request workflow | privacy-rights | A-018 |
| FR-018 Retention | RetentionPolicy + worker | retention | A-021 |
| FR-019 Audit | append-only/tamper evident events | audit | A-020 |
| FR-020 Workforce auth | MFA + RBAC/ABAC | identity/authz | A-005, A-006 |
| FR-021 Consumer sessions | scoped expiring tokens | identity | A-016 |
| FR-023 Accessibility | WCAG baseline | web UI | A-024, A-025 |
| FR-024 PII-safe telemetry | logging policy | observability | A-015 |
| FR-025 Synthetic fixtures | deterministic fixture catalog | test harness | full P0 suite |

## Compliance traceability

| Domain | Product obligation | Technical evidence |
|---|---|---|
| California insurance privacy | notices, information handling, safeguards | NoticeDefinition, ConsentRecord, DataUsePolicy, AuditEvent |
| GLBA | safeguards/vendor controls | security program controls, provider registry, audit |
| DPPA | permissible purpose | PermissiblePurposeDecision + blocked-request tests |
| FCRA | permissible purpose/adverse action/dispute support | CRA metadata, AdverseActionCase, notice evidence |
| CCPA/CPRA as applicable | data inventory/rights/purpose separation | PrivacyRequest, data inventory, marketing separation |
| Rating/underwriting rules | only approved fields used | RatingInput allowlist + CarrierAdapter schema |
| Electronic consent | proof of notice/action/version | ConsentRecord + content hash |
| Accessibility | operable equivalent experience | automated/manual accessibility evidence |

## Change rule
Any change to a traced requirement MUST update all affected columns: requirement, control/design, implementation, acceptance, and applicable compliance mapping.
