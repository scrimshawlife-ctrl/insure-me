# API Contracts

## Contract principles
- Version every public contract.
- Require idempotency on externally consequential writes.
- Do not expose provider- or carrier-specific response shapes to consumers.
- Do not place sensitive identifiers in paths, query strings, logs, or analytics.
- Return machine-readable reason codes for blocked regulated operations.
- Provider and carrier adapters are internal interfaces, not consumer APIs.
- Tenant context MUST be resolved by trusted routing/session context; public clients MUST NOT be able to switch tenants by supplying arbitrary tenant IDs.
- Core APIs MUST remain stable when carriers or data providers are replaced.

## Public/consumer API

### `POST /v1/quote-cases`
Creates a QuoteCase in the tenant context resolved by the server.

Request:
```json
{
  "jurisdiction": "CA",
  "productLine": "PRIVATE_PASSENGER_AUTO",
  "sourceChannel": "WEB"
}
```

Response:
```json
{
  "quoteCaseId": "qc_...",
  "state": "DRAFT",
  "nextAction": "IDENTITY"
}
```

The response MUST NOT expose internal tenant configuration, provider bindings, or carrier credentials.

### `PATCH /v1/quote-cases/{id}/identity`
Stores minimum identity/contact fields. Sensitive fields MUST use secure request bodies and field protection at rest.

### `GET /v1/quote-cases/{id}/required-notices`
Returns the current notice/authorization sequence for the case and requested next step.

### `POST /v1/quote-cases/{id}/consents`
Records acknowledgment/authorization. Required fields include `noticeDefinitionId`, `actionType`, and an idempotency key.

### `GET /v1/quote-cases/{id}/drivers`
Returns current driver candidates with provenance-safe display fields.

### `PUT /v1/quote-cases/{id}/drivers`
Confirms/adds/edits drivers.

### `GET /v1/quote-cases/{id}/vehicles`
Returns vehicle candidates and verification state.

### `PUT /v1/quote-cases/{id}/vehicles`
Confirms/adds/edits vehicles.

### `PUT /v1/quote-cases/{id}/coverage-request`
Stores requested coverage preferences and configured program-required inputs that are permitted at this stage.

### `POST /v1/quote-cases/{id}/complete-consumer-intake`
Validates the consumer portion and transitions to enrichment/review as appropriate.

### `GET /v1/quote-cases/{id}/status`
Returns consumer-safe status and next action. MUST NOT disclose internal risk observations or prohibited report details.

## Agent API
All routes require workforce authentication, MFA state, tenant/agency scope, and permission checks.

### `GET /v1/agent/quote-cases`
Filters cases by state, assignment, freshness, and operational flags.

### `GET /v1/agent/quote-cases/{id}`
Returns normalized case workspace data, readiness, observations, conflicts, and provenance references subject to display policy.

### `POST /v1/agent/quote-cases/{id}/provider-requests`
Requests an approved provider capability.

Request:
```json
{
  "capability": "MVR",
  "subjectIds": ["drv_..."],
  "purpose": "INSURANCE_UNDERWRITING",
  "idempotencyKey": "..."
}
```

The server MUST independently evaluate purpose, notice/authorization, jurisdiction, tenant provider binding, provider capability, data minimization, case state, and caller permission. Client assertions do not establish permission.

Blocked response example:
```json
{
  "error": "PROVIDER_REQUEST_BLOCKED",
  "reasonCodes": ["MISSING_REQUIRED_AUTHORIZATION"]
}
```

### `POST /v1/agent/quote-cases/{id}/resolve-issue`
Records a human resolution with source/evidence where required.

### `GET /v1/agent/carrier-programs?quoteCaseId={id}`
Returns carrier programs configured for the tenant that are eligible for the case's jurisdiction/product context. Returned data MUST be operational capability metadata only and MUST NOT expose secrets.

Example:
```json
{
  "programs": [
    {
      "carrierProgramId": "cp_...",
      "carrierDisplayName": "Synthetic Carrier A",
      "programDisplayName": "CA Auto",
      "mode": "STUB",
      "readiness": "READY",
      "blockingIssueCodes": []
    }
  ]
}
```

### `PUT /v1/agent/quote-cases/{id}/carrier-program`
Selects a configured CarrierProgram for the case. Selection MUST be auditable and MUST trigger program-specific readiness recalculation. It MUST NOT mutate canonical person/driver/vehicle facts.

### `POST /v1/agent/quote-cases/{id}/carrier-submissions`
Creates an idempotent carrier handoff only when readiness, data-use policy, and selected CarrierProgram prerequisites pass.

Request:
```json
{
  "carrierProgramId": "cp_...",
  "idempotencyKey": "..."
}
```

The server builds the carrier payload from approved canonical facts/RatingInputs. Clients MUST NOT submit arbitrary rating fields to bypass allowlists.

### `GET /v1/agent/quote-cases/{id}/carrier-submissions`
Returns submission/decision summaries with carrier/program provenance subject to permission.

### `GET /v1/agent/quote-cases/{id}/audit`
Returns a redacted, permission-filtered timeline.

## Administrative APIs
Elevated administration MUST be separated from ordinary agent permissions.

Required capability areas:
- tenant configuration inspection/versioning;
- workforce users/roles;
- provider capability bindings;
- Carrier/CarrierProgram registry;
- certification and kill-switch state;
- notice definitions;
- data-use policies;
- retention policies;
- compliance evidence export.

Production secret material MUST NOT be returned through administrative read APIs.

## Privacy APIs

### `POST /v1/privacy/requests`
Creates a privacy request. It MUST NOT expose whether a person exists before identity verification.

Request:
```json
{
  "requestType": "DELETION",
  "jurisdiction": "CA",
  "requester": {
    "firstName": "Avery",
    "lastName": "Example",
    "email": "avery@example.test",
    "phone": "+16505550100"
  },
  "idempotencyKey": "00000000-0000-4000-8000-000000000000"
}
```

Tenant/agency context MUST be resolved from trusted host configuration. Requester contact data MUST be encrypted before persistence. Intake MUST NOT search for or attach Person or QuoteCase records. T801 establishes identity-verification evidence; controlled record matching and discovery remain T802.

Successful response (`202`):
```json
{
  "privacyRequestId": "opaque-uuid",
  "state": "IDENTITY_VERIFICATION_PENDING",
  "identityVerificationState": "PENDING",
  "nextAction": "IDENTITY_VERIFICATION",
  "statusToken": "one-time-requester-secret"
}
```

The status token is a high-entropy requester credential. It MUST be returned only at intake, stored only as a hash, and excluded from URLs, logs, and analytics.

### `GET /v1/privacy/requests/{id}`
Returns requester-safe request status.

The caller MUST provide the status token in `X-Privacy-Request-Token`. Missing, malformed, unknown, cross-tenant, and mismatched credentials MUST produce the same generic not-found response. Before identity verification, the response MUST contain only request workflow state and MUST NOT contain person, quote, matching, exemption, retention, or deletion-eligibility data.

### `POST /v1/privacy/requests/{id}/identity-verification`
Submits a requester assertion to the configured provider-neutral privacy identity verifier. The caller MUST provide the status token in `X-Privacy-Request-Token` and a new UUID idempotency key in the request body.

Synthetic request:
```json
{
  "assertion": "SYNTHETIC-PRIVACY-VERIFIED",
  "idempotencyKey": "00000000-0000-4000-8000-000000000000"
}
```

The synthetic assertion is permitted only when `DEPLOYMENT_STAGE=synthetic` and the synthetic verifier is explicitly configured. Pilot and production MUST fail closed until an approved verifier adapter and identity-verification policy are configured.

The verifier result MUST be settled through a service-role-only atomic operation that records adapter/version, policy version, opaque evidence reference, categorized reason codes, attempt number, outcome, and AuditEvent. Assertions and raw identity data MUST NOT be stored in verification-attempt records or logs.

Successful verification changes only identity-verification workflow state. It MUST NOT search for or attach Person or QuoteCase records. Record discovery begins in T802.

### `POST /v1/privacy/requests/{id}/discovery`
Starts or replays controlled record discovery after verified identity. The caller MUST provide the status token in `X-Privacy-Request-Token` and a UUID `idempotencyKey` in the request body.

Discovery MUST use protected deterministic lookup material, trusted host-derived tenant/agency context, and an explicitly configured disclosure policy version. It MUST never perform a global person search. A unique match MAY attach the canonical Person to the PrivacyRequest. No match and multiple matches MUST advance to applicability review without exposing candidate identities or record counts to the requester.

For an `ACCESS` request with one match, the service MUST construct a versioned requester export, encrypt it before persistence, store only the encrypted artifact plus integrity metadata, and emit AuditEvents for discovery and export creation. Other privacy request types receive the discovery result but do not create an access export.

The synthetic disclosure policy is permitted only when `DEPLOYMENT_STAGE=synthetic` and `PRIVACY_EXPORT_POLICY_VERSION=synthetic-privacy-export-v1`. Pilot and production MUST fail closed until an approved disclosure/export policy is configured.

Successful response:
```json
{
  "privacyRequestId": "opaque-uuid",
  "state": "APPLICABILITY_REVIEW",
  "identityVerificationState": "VERIFIED",
  "nextAction": "PROCESSING",
  "discoveryOutcome": "MATCHED",
  "exportAvailable": true
}
```

### `GET /v1/privacy/requests/{id}/export`
Returns the completed encrypted-at-rest access export through an authenticated, no-store JSON download. The status token MUST be supplied in `X-Privacy-Request-Token`. Missing, malformed, unknown, cross-tenant, mismatched, non-access, incomplete, and unavailable exports MUST produce the same generic not-found response.

Every successful download MUST emit an AuditEvent. The response MUST NOT contain internal tenant IDs, lookup hashes, idempotency material, encryption metadata, service credentials, or records outside the matched Person's tenant/agency-scoped QuoteCases.

Administrative completion routes MUST require elevated permissions and evidence.

## Internal provider adapter interface

```ts
interface ProviderRequestContext {
  quoteCaseId: string;
  tenantId: string;
  agencyId: string;
  tenantConfigurationVersion: string;
  jurisdiction: "CA";
  productLine: "PRIVATE_PASSENGER_AUTO";
  capability: ProviderCapability;
  providerBindingId: string;
  permissiblePurposeDecisionId: string;
  consentRecordIds: string[];
  subjectIds: string[];
  traceId: string;
  idempotencyKey: string;
}

interface ProviderAdapter<TReq, TNormalized> {
  capabilities(): ProviderCapabilityDescriptor[];
  validate(ctx: ProviderRequestContext, req: TReq): Promise<void>;
  execute(ctx: ProviderRequestContext, req: TReq): Promise<ProviderResult<TNormalized>>;
}
```

Capability descriptor MUST include jurisdiction, product line, required subject fields, required notice/authorization types, raw-payload storage permission, freshness semantics, contractual purpose codes, and adapter version.

## Normalized provider result

```ts
interface ProviderResult<T> {
  status: "SUCCESS" | "NO_HIT" | "PARTIAL" | "STALE" | "ERROR";
  providerRequestId?: string;
  providerReportId?: string;
  retrievedAt: string;
  normalized: T | null;
  provenance: ProvenanceEntry[];
  warnings: string[];
}
```

## Carrier adapter contracts

```ts
type CarrierMode =
  | "STUB"
  | "API"
  | "DEEPLINK"
  | "AMS_BRIDGE"
  | "STRUCTURED_EXPORT"
  | "MANUAL";

interface CarrierCapabilityDescriptor {
  carrierId: string;
  carrierProgramId: string;
  adapterId: string;
  adapterVersion: string;
  mode: CarrierMode;
  jurisdictions: string[];
  productLines: string[];
  requiredFieldPolicyVersion: string;
  ratingInputPolicyVersion: string;
  responseMappingVersion: string;
  supportsAsyncStatus: boolean;
  certificationState: "SYNTHETIC" | "SANDBOX" | "CERTIFIED" | "SUSPENDED" | "RETIRED";
}

interface CarrierRequestContext {
  quoteCaseId: string;
  tenantId: string;
  agencyId: string;
  tenantConfigurationVersion: string;
  carrierProgramId: string;
  carrierProgramVersion: string;
  traceId: string;
  idempotencyKey: string;
}

interface CarrierAdapter {
  descriptor(): CarrierCapabilityDescriptor;
  validateSubmission(
    ctx: CarrierRequestContext,
    input: CarrierSubmissionInput
  ): Promise<ValidationResult>;
  submit(
    ctx: CarrierRequestContext,
    input: CarrierSubmissionInput
  ): Promise<CarrierSubmissionResult>;
  getStatus?(
    ctx: CarrierRequestContext,
    externalReference: string
  ): Promise<CarrierStatus>;
}
```

`StubCarrierAdapter` MUST implement this same contract in local/CI/staging. No live carrier selection is required for synthetic end-to-end acceptance.

A CarrierProgram selects an allowed mode/configuration. The adapter layer may map canonical fields to carrier-specific payloads, but carrier-specific fields MUST NOT leak back into the canonical domain model.

## Carrier submission safety
Before execution the server MUST verify:
- selected program belongs to the tenant configuration;
- program is enabled for jurisdiction/product;
- environment certification state permits execution;
- kill switch is off;
- required-field readiness passes;
- every RatingInput is allowed by the program's policy version;
- the adapter ID/version matches the configured program;
- idempotency constraints pass.

## Error taxonomy
- `AUTHENTICATION_REQUIRED`
- `MFA_REQUIRED`
- `PERMISSION_DENIED`
- `TENANT_CONTEXT_INVALID`
- `CASE_NOT_FOUND`
- `INVALID_CASE_STATE`
- `PURPOSE_NOT_PERMITTED`
- `MISSING_REQUIRED_NOTICE`
- `MISSING_REQUIRED_AUTHORIZATION`
- `JURISDICTION_NOT_SUPPORTED`
- `PROVIDER_CAPABILITY_NOT_ALLOWED`
- `PROVIDER_VALIDATION_ERROR`
- `PROVIDER_NO_HIT`
- `PROVIDER_PARTIAL`
- `PROVIDER_UNAVAILABLE`
- `PROVIDER_RATE_LIMITED`
- `CARRIER_PROGRAM_NOT_CONFIGURED`
- `CARRIER_CAPABILITY_NOT_ALLOWED`
- `CARRIER_NOT_CERTIFIED`
- `CARRIER_KILL_SWITCHED`
- `CARRIER_VALIDATION_ERROR`
- `CARRIER_UNAVAILABLE`
- `CARRIER_STATUS_AMBIGUOUS`
- `CARRIER_HANDOFF_BLOCKED`
- `CONFLICT_REQUIRES_REVIEW`
- `RETENTION_RESTRICTION`
- `LEGAL_HOLD`

## API security
- TLS only.
- No sensitive GET query parameters.
- SameSite/HttpOnly/Secure cookies where cookies are used.
- CSRF protection for browser sessions.
- Request-size limits.
- Rate limits and abuse detection.
- Strict CORS origins.
- Content Security Policy for web surfaces.
- Trace IDs MUST be opaque and non-sensitive.
- API responses MUST use field-level authorization, not only route-level authorization.
- Tenant isolation MUST be enforced server-side on every object lookup.
- Secrets and provider/carrier credentials MUST never appear in API responses.
