# Requirements Traceability

## Purpose
Trace canonical product requirements to architectural controls, implementation tasks, acceptance evidence, and production gates. No requirement is considered implemented merely because a UI or external API call exists.

## Core traceability matrix

| Requirement | Primary control | Implementation tasks | Acceptance evidence |
|---|---|---|---|
| FR-001 QuoteCase creation | `quote-core` state machine; tenant resolution | T103-T106 | A-001, A-014 |
| FR-002 Identity/contact minimization | canonical Person/Prospect; field policy | T106, T301 | A-013, A-014 |
| FR-003 Notice/consent ledger | immutable `NoticeDefinition` version stream, append-only lifecycle evidence, `ConsentRecord` | T107, T302, T810 | A-003, A-024, A-039, F027 |
| FR-004 Purpose enforcement | `PermissiblePurposeDecision`; provider preflight | T108, T401 | A-002, A-004 |
| FR-005 Provider gateway | capability descriptors + adapters | T400-T415 | A-006, A-016, A-020 |
| FR-006 Provider report preservation | `ExternalRequest`, `ExternalReport`, provenance | T109, T404, T500 | A-007, A-024 |
| FR-007 Driver workflow | canonical Driver | T106, T303, T603 | synthetic multi-driver fixture |
| FR-008 Vehicle workflow | canonical Vehicle | T106, T304, T603 | synthetic multi-vehicle fixture |
| FR-009 Claims/MVR observations | normalization boundary | T109, T501 | A-008, A-010 |
| FR-010 Data-use classification | `DataUsePolicy`; RatingInput gate | T110, T502, T506 | A-008, A-018 |
| FR-011 Quote readiness | completeness-only readiness engine | T111, T505, T602 | A-009, A-029 |
| FR-012 Carrier gateway | `CarrierAdapter`, registry, boundary mapping | T700-T710 | A-017-A-019, A-026 |
| FR-013 Carrier response | `CarrierSubmission`, `CarrierDecision` | T112, T704 | A-017, A-021 |
| FR-014 Human review | issue/conflict workflow | T503, T608 | A-010 |
| FR-015 Consumer correction/dispute | correction/dispute workflow | T309, T803-T804 | A-032-A-033, correction fixture |
| FR-016 Adverse-action support | ownership-configurable AdverseActionCase + version-bound notice delivery | T807-T808 | A-036-A-037, adverse-action synthetic rehearsal |
| FR-017 Privacy rights | PrivacyRequest subsystem | T800-T804 | A-022, A-031-A-033, privacy rehearsal |
| FR-018 Retention | RetentionPolicy + disposition worker + LegalHold lifecycle | T113, T805-T806 | A-023, A-034-A-035 |
| FR-019 Audit | append-only AuditEvent pipeline + immutable evidence export | T114, T610, T809 | A-024, A-038, compliance export rehearsal |
| FR-020 Authentication/authorization | MFA + tenant RBAC/ABAC | T200-T203 | A-005, A-015 |
| FR-021 Consumer session security | secure resume/session boundary | T204, T306 | A-014 |
| FR-022 Notification separation | transactional notification subsystem | T310, T808 | A-030 |
| FR-023 Accessibility | WCAG 2.2 AA baseline | T311 | A-025 |
| FR-024 Observability | PII-safe telemetry | T208, T900+ | A-013 |
| FR-024a Reliability objectives | `reliability-v1` SLO/error-budget and recovery contract | T900, T902 | A-041 |
| FR-024b Synthetic performance regression | versioned production-build load profile and CI evidence | T901 | A-042 |
| FR-024c Recovery verification | isolated logical snapshot/restore and control-integrity evidence | T902 | A-041, A-043 |
| FR-025 Synthetic fixtures | deterministic fixture library | T115, T405-T409 | A-016-A-021 |
| FR-026 Tenant/branding configuration | `TenantConfiguration` | T105, T312 | A-005, A-027, A-028 |
| FR-027 Carrier capability registry | `Carrier`, `CarrierProgram`, capability descriptor | T112, T701, T707 | A-018, A-028 |
| FR-028 Multi-carrier readiness | program overlays + selector | T507, T611, T708-T710 | A-026, A-029 |
| FR-029 Synthetic carrier execution | `StubCarrierAdapter` | T700, T708, T910 | A-017, A-026 |

## Portability invariants

### Carrier portability
**Requirement:** A carrier/program can be added or replaced without modifying canonical QuoteCase, Person, Driver, Vehicle, ExternalReport, UnderwritingObservation, or CarrierDecision schemas.

Controls:
- `Carrier` / `CarrierProgram` versioned configuration;
- `CarrierAdapter` internal contract;
- carrier-specific field mapping at the boundary;
- program-specific RatingInput allowlist;
- no carrier-name branching in core services.

Evidence:
- A-019 Carrier mapping boundary;
- A-026 Carrier portability;
- A-029 Carrier switch does not rewrite facts;
- T710 verifies adapter substitution requires no core-domain change.

### Provider portability
**Requirement:** Provider replacement does not fork canonical domain schemas or silently change legal semantics.

Controls:
- provider capability descriptors;
- provider binding/version records;
- normalized result envelope;
- provider swap requires legal/contract/notice comparison;
- no automatic provider substitution when semantics differ.

Evidence:
- A-006 Provider-neutral canonical model;
- A-020 failure/degraded-mode tests;
- adapter contract tests T415.

### Tenant isolation
**Requirement:** Tenant data, policy, branding, credentials, provider bindings, and carrier programs remain isolated.

Controls:
- trusted tenant resolution;
- tenant-scoped object authorization;
- versioned TenantConfiguration;
- tenant/environment-scoped credentials;
- field-level response authorization.

Evidence:
- A-005 Tenant isolation;
- A-027 Tenant configuration isolation;
- A-028 Configuration version replay.

## Compliance traceability

### DPPA / motor-vehicle data
Product obligation:
- no arbitrary lookup;
- insurance permissible purpose evaluated before request;
- subject/case/actor/provider context retained;
- provider execution denied on failed preflight.

Technical controls:
- `PermissiblePurposeDecision`;
- provider capability registry;
- server-side preflight;
- immutable ExternalRequest/AuditEvent evidence.

Evidence:
- A-001 through A-004;
- prohibited-purpose fixture;
- provider activation documentation.

### FCRA / consumer-report products
Product obligation:
- identify consumer-report products and responsible report user;
- preserve report/provenance information needed for support/disputes;
- support adverse-action evidence workflow without inventing responsibility;
- route disputes/corrections correctly.

Technical controls:
- provider product metadata;
- ExternalReport provenance;
- configurable notice/adverse-action ownership;
- correction/dispute workflow;
- CarrierDecision reason-code provenance.

Evidence:
- adverse-action synthetic rehearsal;
- provider/carrier production certification;
- legal approval before live activation.

### California insurance/privacy + CCPA/CPRA applicability
Product obligation:
- classify processing purpose/role/data regime;
- support applicable rights and exemptions;
- maintain approved notices, retention, service-provider/vendor controls, and security safeguards.

Technical controls:
- NoticeDefinition/ConsentRecord;
- DataUsePolicy;
- PrivacyRequest;
- RetentionPolicy;
- TenantConfiguration versioning;
- AuditEvent evidence.

Evidence:
- A-022-A-024, A-028;
- privacy-rights rehearsal;
- deployment legal review.

## Security traceability

| Security property | Control | Evidence |
|---|---|---|
| workforce strong auth | MFA + managed IdP | A-015 |
| object/tenant isolation | server-side tenant-scoped authorization | A-005, A-027 |
| consumer session isolation | scoped expiring access | A-014 |
| high-risk field protection | encryption/tokenization + KMS | security tests/review |
| no PII telemetry | redaction + allowlisted dimensions | A-013 |
| no secret leakage | secret manager + response filtering | A-013 + security review |
| provider abuse resistance | purpose gate + rate limit + audit | A-001-A-004 |
| carrier submission safety | program allowlist + certification + kill switch | A-018, A-021 |
| historical reconstruction | versioned config/policy refs | A-028 |
| tamper-evident evidence | append-only audit pipeline | A-024 |

## Synthetic core vs production activation

### Synthetic core completion
The runtime may be declared `SYNTHETIC_CORE_ACCEPTED` when:
- all P0 CORE acceptance tests pass;
- deterministic provider stubs and `StubCarrierAdapter` execute the full end-to-end journey;
- carrier/provider portability and tenant isolation tests pass;
- no live credentials or live consumer-report access are required.

Primary tasks: T100-T115, T200-T209, T300-T312, T400-T415 using stubs, T500-T507, T600-T611, T700/T708/T710, T800-T811 as synthetic workflows, T910. T811 is verified through active-agency, MFA-backed, read-only data-use and retention inspection RPCs and non-cacheable administration routes.

### Production activation
A deployment may be declared `PRODUCTION_READY` only when the exact enabled configuration is certified:
- operating tenant/agency/entity documented;
- each live regulated provider capability separately approved/certified;
- each live CarrierProgram separately approved/certified;
- legal/privacy/FCRA ownership and notices approved;
- data-use and retention policies approved;
- production security review and operational drills passed;
- exact TenantConfiguration, provider-binding, CarrierProgram, policy, and adapter versions recorded in release evidence.

Unknown future integrations remain unconfigured and do not invalidate the synthetic core.

## Change-control rule
Any change to a requirement, provider/legal semantic, CarrierProgram capability, data-use classification, retention rule, or canonical entity MUST update all affected artifacts in the same specification change:
1. `spec.md` requirement/invariant;
2. `data-model.md` if domain semantics change;
3. `api-contracts.md` if interface behavior changes;
4. compliance/security artifacts where applicable;
5. implementation tasks;
6. acceptance evidence;
7. this traceability map.

A code change that cannot be traced to the canonical specification is not authorized by this spec set.
