# Data Model

## Design rule
`ExternalReport != UnderwritingObservation != RatingInput != CarrierDecision`.

The model MUST preserve provenance, legal-use classification, jurisdiction, ownership, and lifecycle state.

## Core entities

### Agency
- `id`
- `legal_name`
- `display_name`
- `carrier_relationships[]`
- `jurisdictions[]`
- `status`
- `created_at`

### AgencyUser
- `id`
- `agency_id`
- `identity_subject`
- `name`
- `email`
- `role_ids[]`
- `license_metadata` (when required)
- `mfa_state`
- `status`
- `last_login_at`

### Role / Permission
Permissions MUST be capability-specific, including:
- quote.read
- quote.write
- provider.request.mvr
- provider.request.claims
- provider.request.identity
- carrier.submit
- privacy.review
- audit.read
- admin.users
- admin.integrations

### Prospect
- `id`
- `agency_id`
- `canonical_person_id`
- `contact_preferences`
- `created_at`

### Person
- `id`
- `name`
- `dob_encrypted`
- `address_ids[]`
- `phone_encrypted`
- `email`
- `identity_status`
- `source_provenance[]`

### QuoteCase
- `id`
- `agency_id`
- `prospect_id`
- `jurisdiction`
- `product_line` = `CA_PRIVATE_PASSENGER_AUTO`
- `source_channel`
- `state`
- `assigned_agent_id`
- `started_at`
- `consumer_completed_at`
- `submitted_at`
- `closed_at`
- `retention_policy_id`
- `legal_hold_state`

### Driver
- `id`
- `quote_case_id`
- `person_id`
- `relationship_to_applicant`
- `license_number_encrypted`
- `license_state`
- `license_status`
- `first_licensed_date_or_year`
- `driver_role`
- `provenance[]`

### Vehicle
- `id`
- `quote_case_id`
- `vin_encrypted_or_tokenized`
- `year`
- `make`
- `model`
- `trim`
- `ownership_type`
- `garaging_address_id`
- `annual_mileage`
- `primary_use`
- `primary_driver_id`
- `provenance[]`

### CoverageRequest
- `id`
- `quote_case_id`
- `requested_effective_date`
- `coverage_selections`
- `deductible_preferences`
- `current_coverage_context`
- `consumer_priorities`

### NoticeDefinition
- `id`
- `notice_type`
- `version`
- `effective_at`
- `jurisdiction`
- `content_hash`
- `content_location`
- `approved_by`
- `approval_reference`

### ConsentRecord
- `id`
- `quote_case_id`
- `person_id`
- `notice_definition_id`
- `action_type` (`ACKNOWLEDGE`, `AUTHORIZE`, `OPT_IN`, `OPT_OUT`, `WITHDRAW`)
- `purpose`
- `presented_at`
- `acted_at`
- `channel`
- `evidence_hash`
- `ip_or_device_evidence` only if approved/minimized

### PermissiblePurposeDecision
- `id`
- `quote_case_id`
- `request_type`
- `legal_basis_code`
- `contract_basis_code`
- `jurisdiction`
- `decision` (`ALLOW`, `DENY`, `REVIEW`)
- `rule_version`
- `evaluated_at`
- `reason_codes[]`

### ExternalRequest
- `id`
- `quote_case_id`
- `provider_id`
- `capability`
- `subject_ids[]`
- `permissible_purpose_decision_id`
- `consent_record_ids[]`
- `idempotency_key`
- `status`
- `requested_at`
- `completed_at`
- `provider_request_id`
- `error_class`

### ExternalReport
- `id`
- `external_request_id`
- `provider_id`
- `provider_report_id`
- `report_type`
- `jurisdiction`
- `retrieved_at`
- `freshness_expires_at`
- `normalized_schema_version`
- `normalized_payload`
- `raw_payload_location` nullable and disabled by default
- `raw_payload_retention_policy_id` nullable
- `content_hash`
- `status`

### UnderwritingObservation
- `id`
- `quote_case_id`
- `subject_type`
- `subject_id`
- `observation_type`
- `value`
- `source_external_report_id`
- `source_path`
- `observed_at`
- `confidence_or_status`
- `data_use_policy_id`
- `review_state`

### DataUsePolicy
- `id`
- `attribute_or_observation_type`
- `jurisdiction`
- `product_line`
- `collect_state`
- `display_state`
- `underwriting_state`
- `rating_state`
- `carrier_only_state`
- `prohibited_state`
- `source_authority`
- `effective_at`
- `expires_at`

### RatingInput
Used only where the carrier explicitly approves platform transmission of a field for rating.
- `id`
- `quote_case_id`
- `field_name`
- `value`
- `source_type`
- `source_id`
- `carrier_id`
- `approval_rule_version`

### ReadinessIssue
- `id`
- `quote_case_id`
- `severity` (`BLOCKING`, `WARNING`, `INFO`)
- `type`
- `message_code`
- `subject_id`
- `source_ids[]`
- `state`
- `resolution`
- `resolved_by`
- `resolved_at`

### CarrierSubmission
- `id`
- `quote_case_id`
- `carrier_id`
- `adapter_type`
- `schema_version`
- `submission_hash`
- `idempotency_key`
- `submitted_by`
- `submitted_at`
- `status`
- `external_reference`

### CarrierDecision
- `id`
- `carrier_submission_id`
- `decision_type`
- `premium` nullable
- `eligibility_state` nullable
- `bind_state` nullable
- `reason_codes[]`
- `effective_date` nullable
- `received_at`
- `carrier_reference`
- `raw_response_location` nullable per contract

### AdverseActionCase
- `id`
- `quote_case_id`
- `carrier_decision_id`
- `responsible_party`
- `consumer_report_source_ids[]`
- `trigger_state`
- `notice_required`
- `notice_status`
- `notice_sent_at`
- `dispute_route`

### PrivacyRequest
- `id`
- `person_id`
- `request_type`
- `jurisdiction`
- `received_at`
- `identity_verification_state`
- `scope`
- `exceptions[]`
- `due_at`
- `status`
- `completed_at`
- `evidence_location`

### RetentionPolicy
- `id`
- `record_class`
- `jurisdiction`
- `retention_basis`
- `duration_or_rule`
- `disposition`
- `approved_by`
- `effective_at`

### AuditEvent
Append-only logical model:
- `id`
- `occurred_at`
- `actor_type`
- `actor_id`
- `agency_id`
- `quote_case_id` nullable
- `event_type`
- `resource_type`
- `resource_id`
- `action`
- `result`
- `reason_codes[]`
- `trace_id`
- `metadata_redacted`
- `previous_event_hash` or equivalent tamper-evidence mechanism

## Provenance envelope
Any canonical field derived from outside user input SHOULD use:

```json
{
  "value": "...",
  "source_type": "EXTERNAL_REPORT",
  "source_id": "...",
  "source_path": "...",
  "retrieved_at": "...",
  "jurisdiction": "CA",
  "data_use_policy_id": "..."
}
```

## Deletion model
Deletion MUST be policy-driven. A privacy or retention action may result in:
- hard delete;
- cryptographic erasure;
- irreversible anonymization;
- deletion of raw report while preserving minimum audit metadata;
- legal/contractual hold.

The disposition and basis MUST be auditable.
