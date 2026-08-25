# T0 Contract Reconciliation

## Status
T0.3 is **PARTIAL / NOT YET CLOSED**. The current browser write surface is now mapped, but three contract discrepancies must be reconciled before typed Angular client generation is authoritative.

## Reconciled browser calls
The following current browser calls have clear canonical API counterparts:
- `POST /api/v1/quote-cases` -> canonical `POST /v1/quote-cases`.
- `PATCH /api/v1/quote-cases/{id}/identity` -> canonical identity update.
- `POST /api/v1/quote-cases/{id}/consents` -> canonical consent ledger write.
- `PUT /api/v1/quote-cases/{id}/drivers` -> canonical driver replacement/confirmation.
- `PUT /api/v1/quote-cases/{id}/vehicles` -> canonical vehicle replacement/confirmation.
- `PUT /api/v1/quote-cases/{id}/coverage-request` -> canonical coverage-request write.
- `POST /api/v1/quote-cases/{id}/complete-consumer-intake` -> canonical intake completion.
- `PUT /api/v1/agent/quote-cases/{id}/carrier-program` -> canonical carrier-program selection.
- `POST /api/v1/agent/quote-cases/{id}/provider-requests` -> canonical provider request, subject to discrepancy D-ANG-T0-001 below.

## D-ANG-T0-001 — provider purpose is server-derived
**Observed runtime:** the provider-request route accepts `capability`, `subjectIds`, and `idempotencyKey`; it resolves configured purpose server-side and passes that purpose into the preflight policy.

**Existing canonical text:** the API-contract example includes a client-supplied `purpose` field.

**Disposition:** runtime behavior is canonical for the Angular migration. Client-selected permissible purpose is prohibited. Angular MUST NOT send or select the purpose code. The server MUST derive it from trusted tenant/provider configuration and independently enforce purpose, notice/authorization, jurisdiction, capability, case state, and caller permission.

**Required follow-up:** amend `specs/001-insurance-quote-platform/api-contracts.md` so its provider-request example no longer implies that browser input establishes or selects permissible purpose.

## D-ANG-T0-002 — resume grant contract missing from canonical API document
**Observed runtime:** `POST /api/v1/quote-cases/{id}/resume-grants` accepts optional `ttlMinutes` constrained to 5–1440 minutes, requires the authenticated consumer quote context, returns a created grant with HTTP 201, and deliberately collapses access failures to `404 CONSUMER_QUOTE_ACCESS_DENIED`.

**Disposition:** preserve this runtime contract during Angular migration. The Angular client may request a grant and construct a resume URL from the returned opaque grant identifier, but it MUST NOT treat the grant as authentication or expose any server secret.

**Required follow-up:** add this endpoint to the canonical public/consumer API specification and define its response fields, one-time/expiry semantics, anti-enumeration behavior, and authentication requirement.

## D-ANG-T0-003 — case-actions route differs from canonical resolve-issue naming
**Observed runtime:** the agent browser posts a discriminated action to `POST /api/v1/agent/quote-cases/{id}/case-actions` for either:
- `RESOLVE_NON_BLOCKING` with readiness issue and evidence; or
- `REQUEST_CONSUMER_FOLLOW_UP` with request type/message.

**Existing canonical text:** documents `POST /v1/agent/quote-cases/{id}/resolve-issue` but does not describe the combined `case-actions` contract or consumer follow-up creation.

**Disposition:** do not invent an Angular-only DTO. Keep the current route stable until the API contract is explicitly reconciled. Angular T8 must consume whichever version becomes canonical after that reconciliation.

## Read projections required by Angular
Current Next.js server components bypass browser HTTP for several reads. Angular therefore needs typed HTTP projections for these existing canonical concepts:
- consumer required notices;
- consumer driver candidates;
- consumer vehicle candidates;
- consumer-safe status/next action;
- agent case queue;
- agent case detail/readiness/intake;
- agent provider/report/observation projection;
- carrier-program options;
- redacted audit timeline;
- consumer follow-up activity.

Where `api-contracts.md` already defines a GET route, Angular must use it. Where current server composition contains more data than the documented GET projection, the server contract must be extended explicitly; the browser must not import `src/application/**` or duplicate server policy logic.

## T0.3 closure rule
T0.3 becomes PASS only when:
1. D-ANG-T0-001 through D-ANG-T0-003 are resolved in canonical API documentation and executable contract tests;
2. every required Angular read projection has a versioned HTTP schema;
3. request/response/error semantics are represented in OpenAPI/JSON Schema or an equivalent executable contract source;
4. generated Angular types can be produced without importing server-only modules or inventing frontend-only domain types.

Until then, T1 workspace scaffolding may proceed in parallel, but T3 typed-client generation and Next.js retirement remain blocked.
