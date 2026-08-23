# API Contracts

## Contract principles
- Version every public contract.
- Require idempotency on externally consequential writes.
- Do not expose provider-specific response shapes to clients.
- Do not place sensitive identifiers in paths, query strings, logs, or analytics.
- Return machine-readable reason codes for blocked regulated operations.
- Provider and carrier adapters are internal interfaces, not consumer APIs.

## Public/consumer API

### `POST /v1/quote-cases`
Creates a QuoteCase.

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

### `PATCH /v1/quote-cases/{id}/identity`
Stores minimum identity/contact fields. Sensitive fields MUST use secure request bodies and field protection at rest.

### `GET /v1/quote-cases/{id}/required-notices`
Returns the current notice/authorization sequence for the case and requested next step.

### `POST /v1/quote-cases/{id}/consents`
Records acknowledgment/authorization.

Required fields include `noticeDefinitionId`, `actionType`, and an idempotency key.

### `GET /v1/quote-cases/{id}/drivers`
Returns current driver candidates with provenance-safe display fields.

### `PUT /v1/quote-cases/{id}/drivers`
Confirms/adds/edits drivers.

### `GET /v1/quote-cases/{id}/vehicles`
Returns vehicle candidates and verification state.

### `PUT /v1/quote-cases/{id}/vehicles`
Confirms/adds/edits vehicles.

### `PUT /v1/quote-cases/{id}/coverage-request`
Stores requested coverage preferences and carrier-required inputs that are permitted at this stage.

### `POST /v1/quote-cases/{id}/complete-consumer-intake`
Validates the consumer portion and transitions to enrichment/review as appropriate.

### `GET /v1/quote-cases/{id}/status`
Returns consumer-safe status and next action. MUST NOT disclose internal risk observations or prohibited report details.

## Agent API
All routes require workforce authentication, MFA state, agency scope, and permission checks.

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

The server MUST independently evaluate purpose, notice/authorization, jurisdiction, provider capability, data minimization, case state, and caller permission. Client assertions do not establish permission.

Blocked response example:
```json
{
  "error": "PROVIDER_REQUEST_BLOCKED",
  "reasonCodes": ["MISSING_REQUIRED_AUTHORIZATION"]
}
```

### `POST /v1/agent/quote-cases/{id}/resolve-issue`
Records a human resolution with source/evidence where required.

### `POST /v1/agent/quote-cases/{id}/carrier-submissions`
Creates an idempotent carrier handoff only when readiness and carrier prerequisites pass.

### `GET /v1/agent/quote-cases/{id}/audit`
Returns a redacted, permission-filtered timeline.

## Privacy APIs
### `POST /v1/privacy/requests`
Creates a privacy request. It MUST NOT expose whether a person exists before identity verification.

### `GET /v1/privacy/requests/{id}`
Returns requester-safe request status.

Administrative completion routes MUST require elevated permissions and evidence.

## Internal provider adapter interface

```ts
interface ProviderRequestContext {
  quoteCaseId: string;
  agencyId: string;
  jurisdiction: "CA";
  capability: ProviderCapability;
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

Capability descriptor MUST include jurisdiction, product line, required subject fields, required notice/authorization types, raw-payload storage permission, freshness semantics, and contractual purpose codes.

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

## Carrier adapter interface
```ts
interface CarrierAdapter {
  validateSubmission(caseId: string): Promise<ValidationResult>;
  submit(input: CarrierSubmissionInput): Promise<CarrierSubmissionResult>;
  getStatus?(externalReference: string): Promise<CarrierStatus>;
}
```

Allowed MVP adapter modes:
- `REDIRECT`
- `DEEPLINK`
- `SECURE_EXPORT`
- `API`

No mode is selected until Allstate/carrier approval is documented.

## Error taxonomy
- `AUTHENTICATION_REQUIRED`
- `MFA_REQUIRED`
- `PERMISSION_DENIED`
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
