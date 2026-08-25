# T0 API Contract Addendum

## Status
Canonical migration contract addendum for Angular T0.3.

This document resolves browser/API discrepancies found during Angular migration inventory. Where this addendum conflicts with older examples in `specs/001-insurance-quote-platform/api-contracts.md`, this addendum governs the Angular migration until the base contract is consolidated.

## Governing rule
The browser is never authoritative for permissible purpose, tenant, agency, carrier/provider binding, role, readiness, underwriting, rating, adverse-action, privacy, legal-hold, or compliance state. These values are resolved or enforced by trusted server-side code.

## Reconciled write contracts

### Provider request
`POST /api/v1/agent/quote-cases/{id}/provider-requests`

Request:
```json
{
  "capability": "MVR",
  "subjectIds": ["00000000-0000-4000-8000-000000000000"],
  "idempotencyKey": "agent-refresh:00000000-0000-4000-8000-000000000000"
}
```

Canonical rule:
- the client MUST NOT supply permissible purpose;
- the server resolves configured purpose from trusted tenant/provider binding context;
- the server independently verifies authorization, notice/consent prerequisites, jurisdiction, capability, subject scope, rate limit, case state, and workforce permission;
- failure to satisfy prerequisites MUST fail closed;
- synthetic scenario selection is server/test-harness controlled and MUST NOT be browser-selectable.

Success projection:
```json
{
  "status": "SETTLED",
  "providerRequestId": "opaque-or-null",
  "providerReportId": "opaque-or-null",
  "warnings": []
}
```

Blocked regulated operation:
```json
{
  "error": "PROVIDER_REQUEST_BLOCKED",
  "reasonCodes": ["MISSING_REQUIRED_AUTHORIZATION"]
}
```

### Consumer resume grant
`POST /api/v1/quote-cases/{id}/resume-grants`

Request:
```json
{
  "ttlMinutes": 60
}
```

Constraints:
- `ttlMinutes` MUST be an integer from 5 through 1440;
- the caller MUST already have consumer access to the QuoteCase;
- invalid or unauthorized quote context MUST not disclose case existence;
- the generated grant is time bounded and does not replace sign-in/session requirements;
- grant material MUST NOT be logged or emitted to analytics.

The response MUST include an opaque `resumeGrantId` sufficient for the presentation layer to construct the configured resume route. The server remains authoritative for expiry, one-time/replay semantics, and quote access.

### Agent case actions
`POST /api/v1/agent/quote-cases/{id}/case-actions`

Supported request variants:

```json
{
  "action": "RESOLVE_NON_BLOCKING",
  "readinessIssueId": "00000000-0000-4000-8000-000000000000",
  "evidence": "Reviewed source-backed evidence."
}
```

```json
{
  "action": "REQUEST_CONSUMER_FOLLOW_UP",
  "readinessIssueId": "00000000-0000-4000-8000-000000000000",
  "requestType": "MISSING_INFORMATION",
  "message": "Please provide the missing information."
}
```

Canonical rule:
- blocking readiness issues MUST NOT be closed through `RESOLVE_NON_BLOCKING`;
- consumer follow-up records a request for an approved transactional channel and MUST NOT claim delivery;
- the server re-checks workforce context and permission;
- presentation code MUST display server-returned conflicts/permission failures rather than infer success.

The older `POST /v1/agent/quote-cases/{id}/resolve-issue` wording is superseded for this migration by `case-actions` unless a future contract version reintroduces a dedicated endpoint.

## Required Angular read projections

Current Next.js server components call application modules directly. Angular cannot do this. The following read boundaries are therefore canonical migration requirements.

### Consumer quote projection
`GET /api/v1/quote-cases/{id}`

Purpose: load the consumer-safe QuoteCase shell and next workflow action.

Minimum response fields:
```json
{
  "quoteCaseId": "opaque",
  "state": "CONSUMER_INPUT",
  "jurisdiction": "CA",
  "productLine": "PRIVATE_PASSENGER_AUTO",
  "sourceChannel": "WEB",
  "nextAction": "NOTICES"
}
```

The response MUST NOT expose internal tenant IDs, provider bindings, carrier credentials, prohibited report facts, workforce-only readiness details, or sensitive identifiers not needed by the current consumer step.

### Consumer drivers projection
`GET /api/v1/quote-cases/{id}/drivers`

Returns only consumer-safe fields required to confirm or edit drivers. Stored license numbers MUST NOT be returned. A masked suffix MAY be returned when approved.

### Consumer vehicles projection
`GET /api/v1/quote-cases/{id}/vehicles`

Returns only consumer-safe fields required to confirm or edit vehicles. Stored VINs MUST NOT be returned. A masked suffix MAY be returned when approved.

### Consumer coverage projection
`GET /api/v1/quote-cases/{id}/coverage-request`

Returns the saved requested-coverage object and version required to resume/edit the current consumer workflow. It MUST remain a preference/request projection, not a carrier quote or premium decision.

### Required notices projection
`GET /api/v1/quote-cases/{id}/required-notices`

Returns the exact notice sequence and immutable evidence fields required for presentation and recording, including notice identifier, version, content hash, category, title, rendered/approved body source, and `requiredForQuote` state.

### Agent queue projection
`GET /api/v1/agent/quote-cases`

Returns the permission-filtered queue currently built by `listAgentQueue`. Minimum operational fields:
- QuoteCase opaque identifier;
- lifecycle state;
- assignment summary;
- blocking/warning counts;
- source channel;
- created/updated timestamps.

It MUST NOT expose prohibited underwriting or report contents in the queue projection.

### Agent case workspace projection
`GET /api/v1/agent/quote-cases/{id}`

This becomes the canonical Angular case-detail read model and MUST compose, server-side, the policy-filtered information currently assembled by the Next.js case page:
- QuoteCase summary and lifecycle state;
- readiness issues;
- consumer-safe intake summary for authorized workforce display;
- provider/report operational status;
- policy-displayable underwriting observations and provenance;
- consumer follow-up requests;
- permission-filtered audit timeline;
- selected CarrierProgram reference;
- explicit capability flags such as whether provider refresh, case action, carrier selection, audit view, or carrier submission actions are permitted.

The projection MUST be built on the server from canonical application/domain services. Angular MUST NOT compose these records from direct database access or provider-specific APIs.

### Carrier program projection
`GET /api/v1/agent/carrier-programs?quoteCaseId={id}`

Returns only configured carrier/program capability and selection metadata needed by the workspace. No credential, secret, proprietary payload, or raw carrier configuration may be returned.

### Carrier submissions projection
`GET /api/v1/agent/quote-cases/{id}/carrier-submissions`

Returns submission/decision summaries with carrier/program provenance and server-derived lifecycle state. Premium/eligibility values remain carrier-authoritative results.

## Error contract baseline
Angular MUST treat HTTP status and machine-readable error codes as contract data.

Required classes:
- `400` request validation failure;
- `403` authenticated but not permitted where existence disclosure is not sensitive;
- `404` generic not-found/access-denied where existence must not be disclosed;
- `409` state/policy/readiness conflict or blocked regulated operation;
- `429` rate limit;
- `500` generic server failure with no raw provider/database details.

Exact route-specific reason codes remain server-owned and versioned.

## Cache and transport rules
- authenticated consumer, agent, admin, compliance, privacy, and audit projections MUST be non-public and MUST NOT enter shared/static caches;
- responses containing sensitive or regulated data SHOULD use `Cache-Control: no-store` unless a stricter approved strategy exists;
- raw PII MUST NOT be placed in URLs, analytics, logs, or correlation IDs;
- mutation protections remain enforced at the server/gateway boundary;
- Angular route guards are navigation UX only and do not replace authorization.

## T0.3 closure criteria
T0.3 is PASS when:
1. provider request purpose is explicitly server-derived;
2. resume-grant and case-action runtime contracts are documented;
3. Angular-required consumer and workforce read projections are explicitly specified;
4. frontend-only DTO invention is prohibited where a canonical HTTP projection is required;
5. generated-client work is blocked until these projections exist as executable routes/contracts;
6. no contract change weakens the Insure Me constitution.

## T1/T3 handoff
T1 MAY scaffold Angular immediately against placeholders/mocks shaped exactly like these contracts. T3 MUST NOT be declared complete until every required read/write route has an executable server implementation and generated or contract-verified TypeScript client surface.
