# Canonical Data Model

## Modeling rules
- Canonical entities MUST use provider- and carrier-neutral names.
- Every material externally derived value MUST preserve provenance.
- Tenant, provider, and carrier configuration MUST be versioned so historical actions can be reconstructed.
- `ExternalReport != UnderwritingObservation != RatingInput != CarrierDecision`.
- Carrier-specific mappings belong at the carrier boundary, not in canonical entities.
- Raw vendor payloads are not canonical domain state.

## Tenant and agency

### TenantConfiguration
Versioned configuration that controls one deployable agency/tenant context.

Minimum fields:
- `tenant_configuration_id`
- `tenant_id`
- `agency_id`
- `version`
- `status`: `DRAFT | ACTIVE | RETIRED`
- `brand_configuration_ref`
- `enabled_jurisdictions[]`
- `enabled_product_lines[]`
- `provider_capability_binding_ids[]`
- `carrier_program_ids[]`
- `notice_policy_set_id`
- `data_use_policy_set_id`
- `retention_policy_set_id`
- `effective_at`
- `retired_at?`
- `created_at`
- `created_by`

A QuoteCase MUST retain the TenantConfiguration version that governed its regulated actions. Later configuration edits MUST NOT rewrite historical policy context.

### Agency
Minimum fields:
- `agency_id`
- `tenant_id`
- `legal_name`
- `display_name`
- `license_metadata_ref?`
- `status`
- `created_at`

### AgencyUser
Minimum fields:
- `agency_user_id`
- `agency_id`
- `workforce_identity_id`
- `status`
- `role_ids[]`
- `created_at`

### Role / Permission
Permissions MUST be explicit and agency/tenant-scoped. Sensitive functions such as report retrieval, privacy administration, exports, carrier submission, and policy administration MUST have separate permissions.

## Carrier model

### Carrier
Represents an insurer or other authorized carrier endpoint without embedding workflow details.

Minimum fields:
- `carrier_id`
- `legal_name`
- `display_name`
- `status`: `CANDIDATE | CONFIGURED | ACTIVE | DISABLED | RETIRED`
- `created_at`

### CarrierProgram
A versioned carrier-specific capability/configuration unit. A carrier can have multiple programs by state, product, channel, or integration contract.

Minimum fields:
- `carrier_program_id`
- `carrier_id`
- `program_code`
- `version`
- `jurisdictions[]`
- `product_lines[]`
- `adapter_id`
- `handoff_mode`: `STUB | API | DEEPLINK | AMS_BRIDGE | STRUCTURED_EXPORT | MANUAL`
- `required_field_policy_version`
- `rating_input_policy_version`
- `response_mapping_version`
- `notice_ownership_policy_version`
- `retention_constraint_version?`
- `authentication_config_ref?`
- `certification_state`: `SYNTHETIC | SANDBOX | CERTIFIED | SUSPENDED | RETIRED`
- `kill_switch_enabled`
- `effective_at`
- `retired_at?`

No carrier name or program code may drive core branching logic.

## Quote domain

### QuoteCase
Minimum fields:
- `quote_case_id`
- `tenant_id`
- `agency_id`
- `tenant_configuration_id`
- `tenant_configuration_version`
- `jurisdiction`
- `product_line`
- `source_channel`
- `state`
- `prospect_id`
- `assigned_agent_id?`
- `selected_carrier_program_id?`
- `selected_carrier_program_version?`
- `created_at`
- `updated_at`
- `closed_at?`

Carrier selection MAY remain null until the agent or configured workflow chooses a program. Selection is context, not ownership of the canonical facts.

### Prospect
Represents the consumer relationship for a quote case.

Minimum fields:
- `prospect_id`
- `person_id`
- contact preference fields permitted by policy
- source classification
- created/updated timestamps

### Person
Canonical person record scoped to the quote workflow. Sensitive identity attributes MUST use the approved field-protection strategy.

### Driver
Minimum logical attributes:
- `driver_id`
- `quote_case_id`
- `person_id`
- relationship/role
- license jurisdiction
- protected license identifier
- license status when sourced/permitted
- years-licensed/first-issued signal when sourced/permitted
- confirmation state
- source/provenance references

### Vehicle
Minimum logical attributes:
- `vehicle_id`
- `quote_case_id`
- protected or appropriately displayed VIN
- year/make/model/trim
- ownership/lease state where required
- garaging reference
- usage
- annual mileage
- confirmation state
- source/provenance references

### CoverageRequest
Contains consumer/agent-requested coverage preferences and permitted underwriting inputs. It is not a carrier quote.

## Notice, purpose, and policy

### NoticeDefinition
Versioned immutable text/metadata for a notice, disclosure, acknowledgment, or authorization.

### ConsentRecord
Minimum fields:
- `consent_record_id`
- `quote_case_id`
- `subject_id`
- `notice_definition_id`
- `notice_version`
- `action_type`
- `presented_at`
- `acted_at`
- `channel`
- `evidence_ref`

### PermissiblePurposeDecision
Every regulated provider request MUST reference a server-created decision.

Minimum fields:
- `decision_id`
- `quote_case_id`
- `tenant_configuration_version`
- `actor_id`
- `jurisdiction`
- `capability`
- `purpose_code`
- `outcome`: `ALLOW | DENY`
- `reason_codes[]`
- `policy_version`
- `evaluated_at`

### DataUsePolicy
Versioned policy that classifies a field/observation for:
- collection;
- agent display;
- underwriting use;
- rating/submission use;
- carrier-only use;
- prohibited use.

The rating/submission decision MUST be carrier-program-aware when a target program is selected.

## External data and provenance

### ExternalRequest
Minimum fields:
- `external_request_id`
- `quote_case_id`
- `tenant_configuration_version`
- `provider_binding_id`
- `capability`
- `subject_ids[]`
- `permissible_purpose_decision_id`
- `consent_record_ids[]`
- `idempotency_key`
- `status`
- `requested_at`
- `completed_at?`
- provider request reference
- failure/reason codes

### ExternalReport
Represents provider-returned report metadata and approved normalized snapshot.

Minimum fields:
- `external_report_id`
- `external_request_id`
- `provider_id`
- `provider_product_id`
- `provider_report_ref?`
- `status`: `SUCCESS | NO_HIT | PARTIAL | STALE | ERROR`
- `retrieved_at`
- `fresh_until?`
- normalized snapshot/version
- raw-payload reference only when explicitly allowed
- contractual/legal metadata references

### ProvenanceEntry
Field- or fact-level lineage.

Minimum fields:
- `provenance_entry_id`
- source type/id
- source field/path or normalized fact key
- source timestamp
- transformation/version
- match/confidence state when supplied by source
- consumer confirmation/correction state when applicable

### UnderwritingObservation
A source-backed normalized fact available to authorized workflow logic. It is not itself a rating factor.

Minimum fields:
- `observation_id`
- `quote_case_id`
- `observation_type`
- `subject_id`
- normalized value
- provenance entries
- data-use classification/version
- freshness state
- conflict state
- created_at

### RatingInput
A deliberate carrier-program-specific projection of permitted canonical data.

Minimum fields:
- `rating_input_id`
- `quote_case_id`
- `carrier_program_id`
- `carrier_program_version`
- `source_observation_or_field_refs[]`
- `input_key`
- `approved_value`
- `data_use_policy_version`
- `mapping_version`
- `created_at`

No UnderwritingObservation may become a RatingInput without explicit allowlist evaluation for the selected CarrierProgram.

## Readiness and conflict model

### ReadinessIssue
Represents missing, stale, conflicting, unauthorized, or program-required work that prevents a defined next step.

Minimum fields:
- `readiness_issue_id`
- `quote_case_id`
- optional `carrier_program_id`
- type/severity
- blocking state
- subject/reference
- reason code
- resolution state/evidence
- timestamps

Readiness is a workflow-completeness concept, not a risk or insurability score.

## Carrier handoff

### CarrierSubmission
Minimum fields:
- `carrier_submission_id`
- `quote_case_id`
- `tenant_configuration_version`
- `carrier_id`
- `carrier_program_id`
- `carrier_program_version`
- `adapter_id`
- `handoff_mode`
- `mapping_version`
- `rating_input_ids[]`
- `idempotency_key`
- `status`
- `external_reference?`
- `submitted_at`
- `completed_at?`

Each submission is immutable evidence. A retry MUST be idempotent or create an explicitly linked new attempt according to the adapter contract.

### CarrierDecision
Carrier-owned result data.

Minimum fields:
- `carrier_decision_id`
- `carrier_submission_id`
- `carrier_program_id`
- `decision_type/status`
- premium/term data when returned and permitted
- eligibility/bind state when returned
- reason codes when returned
- external reference
- response mapping version
- received_at

Insure Me MUST NOT manufacture missing carrier reason codes or reinterpret a carrier result as its own decision.

### AdverseActionCase / AdverseActionReportSource / AdverseActionEvent
`AdverseActionCase` is the tenant-scoped support record for a responsible party's explicit determination. It references one QuoteCase and CarrierDecision, snapshots owner type/reference plus the CarrierProgram notice-ownership policy version, and stores opaque authority/evidence, reason codes, actor/time, status, and idempotency hashes. `AdverseActionReportSource` immutably links each exact contributing ExternalReport and ExternalRequest to its provider binding, CRA identity reference, dispute route, and contribution basis. `AdverseActionEvent` is append-only determination/handoff evidence. The only T807 transition is `NOTICE_INPUTS_READY` to `HANDED_OFF`; notice delivery remains T808.

## Privacy, retention, and audit

### PrivacyRequest
Tracks applicable access, correction, deletion, restriction/opt-out, and related identity-verification workflow.

Minimum fields:
- internal privacy-request ID and separate opaque public reference;
- tenant/agency and jurisdiction;
- request type and intake channel;
- request state and identity-verification state;
- matched Person only after verified identity;
- applicability/policy references and workflow timestamps.

Privacy intake contact data belongs in a separate protected `PrivacyRequestIntakeEvidence` record containing encrypted requester data, keyed lookup hashes, request/idempotency evidence, and a one-way status-token hash. Public intake MUST NOT populate matched Person or QuoteCase relationships.

### PrivacyIdentityVerificationAttempt
Append-only evidence for one provider-neutral verification attempt.

Minimum fields:
- privacy request and tenant/agency references;
- idempotency key and keyed request hash;
- attempt number and outcome;
- verifier adapter ID/version and policy version;
- opaque evidence reference and categorized reason codes;
- attempted timestamp.

The record MUST NOT store the requester assertion, verification code, or raw identity attributes. Successful T801 verification does not establish a canonical Person or QuoteCase match.

### PrivacyDiscoveryRun
Append-only evidence for one idempotent, tenant-scoped record-discovery attempt after verified identity.

Minimum fields:
- privacy request and tenant/agency references;
- idempotency key and keyed request hash;
- disclosure policy and export schema versions;
- result: `MATCHED | NO_MATCH | AMBIGUOUS`;
- matched Person only for a unique match;
- category-level record counts, package digest, status, and timestamps.

The run MUST NOT persist candidate identities, lookup hashes, plaintext identity data, or the plaintext export. Ambiguous candidates remain unattached and require controlled review.

### PrivacyExportArtifact
Protected snapshot created only for a uniquely matched access request.

Minimum fields:
- discovery-run and privacy-request references;
- encrypted export envelope, algorithm, and key version;
- plaintext content digest, record count, and creation timestamp.

The artifact MUST have no direct anonymous or authenticated Data API access. Export access requires the request status credential and creates AuditEvent evidence.

### PrivacyRightsExecution / PrivacyRightsAction
`PrivacyRightsExecution` is the idempotent, policy-versioned evidence envelope for a post-discovery correction, deletion, restriction, or opt-out. It stores only the keyed request hash, corrected field names, outcome, disposition summary, and timestamps. It MUST NOT store plaintext corrections, prior identity values, lookup hashes, or ambiguous candidates.

Append-only `PrivacyRightsAction` rows classify each affected data category as `CORRECTED`, `RESTRICTED`, `DELETE_QUEUED`, `EXEMPT`, `PROPAGATION_PENDING`, or `NO_RECORDS`, with record count and reason codes. `DELETE_QUEUED` is disposition work for T805 and never means legal/contractual evidence was silently erased.

### PrivacyProcessingRestriction
Person-scoped enforcement state for `ALL_PROCESSING`, `SALE_SHARING`, or `TARGETED_MARKETING`, linked to the originating request and policy version. Active restrictions MUST be checked by later processing/provider boundaries; ordinary Data API roles cannot write them.

### PrivacyPropagationBinding
Versioned, tenant/agency and provider-binding-scoped configuration for a downstream privacy adapter. It records adapter ID/version, policy version, certification state, and effective/retired timestamps. Provider availability does not imply privacy-propagation capability; a missing or suspended binding fails closed.

### PrivacyPropagationRun / PrivacyVendorPropagation
`PrivacyPropagationRun` records one idempotent orchestration attempt. `PrivacyVendorPropagation` is the stable target for one affected ExternalRequest and rights execution, with provider-neutral action, target status, attempt count, opaque evidence reference, and reason codes. Target rows MUST never expose vendor identity or references to the requester.

### PrivacyVendorPropagationAttempt
Append-only settlement evidence containing target/run references, keyed request hash, outcome, exact adapter/policy versions, opaque vendor evidence reference, categorized reason codes, and timestamp. It MUST NOT contain report payloads, corrected values, identity data, credentials, or raw vendor responses.

### RetentionPolicy
Versioned disposition rule by data class, jurisdiction, provider contract, tenant role, and legal hold state.

### RetentionDispositionRun / RetentionDispositionItem
`RetentionDispositionRun` is one bounded, idempotent scheduler invocation with an exact evaluation timestamp and expected policy certification state. `RetentionDispositionItem` is stable work for one `DELETE_QUEUED` privacy category. It snapshots the exact policy set/version, disposition, eligibility time, status, and categorized reason codes. Missing configuration, an unresolved interval, an incompatible policy certification state, or a retention-hold signal MUST remain `BLOCKED` and MUST NOT be interpreted as deletion.

### RetentionDispositionAttempt
Append-only execution evidence for one item and attempt. It records a keyed request hash, outcome, exact policy identity, opaque evidence reference, reason codes, and timestamp. It MUST NOT retain destroyed identity values, plaintext consumer input, encryption keys, or deleted ciphertext. `IDENTITY_PROFILE` deletion destroys lookup and encryption material while preserving the non-identifying Person anchor; `CONSUMER_INPUT` anonymization removes direct identifiers while preserving exempt audit and external-source evidence.

### LegalHold / LegalHoldEvent
`LegalHold` is tenant/agency scoped to exactly one Person, QuoteCase, or PrivacyRequest reference. It records active/released state, opaque authority/evidence references, reason codes, actor/timestamps, and idempotency request hashes. Scope and placement fields are immutable; release is the only permitted state transition. `LegalHoldEvent` is append-only evidence for placement and release. Ordinary Data API roles cannot mutate either table. An active formal hold participates in the same final pre-disposition gate as the legacy `RETENTION_HOLD` QuoteCase signal.

### AuditEvent
Append-only event evidence for sensitive reads/writes, regulated provider requests, consent actions, policy/configuration changes, carrier submissions, privacy actions, exports, and security-relevant denials.

Each event SHOULD include:
- event ID/type;
- opaque actor/subject/case references;
- tenant/agency;
- applicable configuration/policy versions;
- timestamp;
- outcome/reason codes;
- integrity/tamper-evidence metadata.

## Cross-tenant isolation invariants
- Every QuoteCase belongs to exactly one tenant/agency context.
- Provider credentials/bindings and carrier credentials/programs MUST be tenant/environment scoped.
- A tenant MUST NOT observe another tenant's prospects, reports, configuration, audit events, or carrier submissions.
- Branding is presentation configuration and MUST NOT modify canonical data semantics.

## Portability invariants
- Adding or replacing a carrier requires a Carrier/CarrierProgram configuration and adapter, not a canonical schema fork.
- Adding or replacing a provider requires a capability binding and adapter, not a canonical schema fork.
- Historical records retain the exact provider/carrier/configuration versions used at execution time.
- Synthetic adapters implement the same internal contracts as live adapters.
