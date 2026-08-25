# T0 Browser/API Contract Matrix

## Purpose
Record the current browser-visible HTTP contracts that must remain stable while the Angular presentation layer is introduced.

## Consumer workflow calls

| Browser action | Current HTTP contract | Angular disposition |
|---|---|---|
| Start quote | `POST /api/v1/quote-cases` with `jurisdiction`, `productLine`, `sourceChannel`; expects `quoteCaseId` | Preserve path/method/payload/response or provide an explicitly versioned replacement |
| Save consumer identity | `PATCH /api/v1/quote-cases/{quoteCaseId}/identity` | Preserve canonical payload semantics; Angular typed form/client replaces React form only |
| Record notice/consent | `POST /api/v1/quote-cases/{quoteCaseId}/consents` with notice id/hash, action, presented time, idempotency key | Preserve exactly; server remains authoritative for whether action satisfies prerequisite |
| Replace driver set | `PUT /api/v1/quote-cases/{quoteCaseId}/drivers` | Preserve canonical semantics and protected identifier behavior |
| Replace vehicle set | `PUT /api/v1/quote-cases/{quoteCaseId}/vehicles` | Preserve canonical semantics and protected VIN behavior |
| Save coverage request | `PUT /api/v1/quote-cases/{quoteCaseId}/coverage-request` | Preserve request schema/versioning semantics |
| Complete intake | `POST /api/v1/quote-cases/{quoteCaseId}/complete-consumer-intake` | Preserve success/error behavior, including `409` for incomplete prerequisites |
| Create resume grant | `POST /api/v1/quote-cases/{quoteCaseId}/resume-grants` with TTL request | Preserve secure one-time grant semantics; Angular constructs UI link only from returned grant id |

## Current client-side assumptions that are NOT canonical authority
- California and `PRIVATE_PASSENGER_AUTO` are currently supplied by the browser when a quote is created. Angular MUST NOT treat these literals as permanent multi-jurisdiction architecture; they remain MVP configuration constrained by canonical specs.
- React currently computes which primary/secondary notice action button to show. The server still owns consent validity and lookup prerequisites. Angular MAY mirror this for UX but MUST NOT make it authoritative.
- React currently sends `confirmationState: CONFIRMED` for drivers and vehicles. This must be verified against the canonical API contract before generated Angular DTOs are frozen.
- Current coverage selections are UI option sets. They are not carrier rating tables and MUST NOT become client-side pricing logic.

## Server-rendered/direct-import coupling to remove
The current Next.js pages may import application-layer view types and invoke server-side composition directly. Angular cannot import those server modules in the browser bundle. Any such dependency must become one of:
1. an existing `/api/v1` read contract;
2. a new explicitly specified `/api/v1` read projection;
3. a generated type derived from the canonical contract.

Frontend-only DTO invention is prohibited when a server projection is missing.

## API families observed in current runtime
In addition to consumer quote routes, the existing route tree contains:
- agent quote-case actions and provider requests;
- carrier-program listing/selection and carrier submissions;
- adverse-action workflow and notice-delivery handoff;
- legal-hold operations;
- notice-definition administration;
- data-use and retention policy administration;
- compliance-evidence export operations;
- internal operational endpoints;
- health endpoint.

Each Angular feature must call these through a typed API facade. No Angular feature may import `src/application/**`, `src/domain/**`, Supabase server clients, provider adapters, or carrier adapters directly.

## Environment/configuration classification

### Browser-safe public configuration
Current examples:
- Supabase project URL;
- Supabase publishable key;
- public base URL;
- non-secret deployment-stage indicator if required by UI.

The Angular replacement must rename framework-prefixed variables as needed, but the values exposed to browser bundles must remain limited to intentionally public configuration.

### Server-only secrets/configuration
The following classes MUST NOT be compiled into Angular artifacts:
- Supabase secret/service credentials;
- identity encryption key and version material;
- identity lookup pepper;
- retention worker token;
- provider credentials;
- carrier credentials;
- any future notification/provider secrets.

### Policy/evidence references
Current production configuration also contains policy/version/evidence references for privacy, notices, retention, legal approval, security review, incident ownership, and live-provider/carrier verification. Angular MAY display server-projected status where authorized, but MUST NOT use browser environment variables as the source of truth for those gates.

## Auth/session contract
Current Next.js middleware performs same-origin mutation checks and Supabase session update/refresh for matched requests. Angular migration therefore requires a server/gateway companion during the transition. Client route guards alone are insufficient.

Required behavior to preserve:
- server-side authenticated subject resolution;
- server-side tenant/role authorization;
- secure-cookie/session semantics;
- mutation-origin/CSRF enforcement;
- auth confirmation callback semantics;
- fail-closed response when authorization or regulated prerequisites fail.

## Contract gaps to resolve before T1/T3 closure
The following remain explicit migration work rather than hidden assumptions:
- enumerate every browser read request currently satisfied by server-component direct imports;
- verify every `/api/v1` request/response schema against `api-contracts.md` and executable tests;
- identify any route handler without a matching canonical OpenAPI/JSON Schema description;
- define typed read projections needed by Angular agent/admin pages;
- decide the long-term hosting boundary for the existing Next.js API layer versus a framework-neutral server process.

These gaps do not block creation of the parallel Angular workspace, but they block removal of the existing presentation runtime and block declaring T3 contract generation complete.
