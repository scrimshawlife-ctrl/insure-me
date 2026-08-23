# Production Enablement Specification

## Status
`IMPLEMENTATION_ACTIVE / LIVE_AUTHORITY_BLOCKED`

This document begins after `SYNTHETIC_CORE_ACCEPTED`. It does not redefine the synthetic core. It defines the controls required before any pilot or production deployment may use real providers, real carrier programs, or legally operative consumer notices.

## What

Production enablement is a governed transition from a verified synthetic runtime to an authorized live runtime.

The runtime MUST support exactly three deployment stages:

- `synthetic` — deterministic fixtures and synthetic adapters are permitted;
- `pilot` — live data or live carrier connectivity may be used only after all live gates pass;
- `production` — live consumer operation may occur only after all live gates pass.

The system MUST fail closed when a live stage lacks required approval evidence. Synthetic adapters MUST be rejected in `pilot` and `production`.

## Why

The synthetic core proves internal architecture, security boundaries, portability, idempotency, and transactionality. It does not itself prove legal authority, contractual vendor access, carrier certification, production data-retention authority, or approved consumer copy. Those are deployment-specific facts and must not be inferred from working code.

## Live gate set

The following evidence is mandatory for `pilot` and `production`:

1. deployment authority for the operating licensed entity;
2. approved consumer notice/copy set and version;
3. approved data-retention/storage policy;
4. documented FCRA/report-user and adverse-action ownership;
5. documented privacy/CCPA/CPRA/GLBA role allocation as applicable;
6. completed security review;
7. named incident-response owner;
8. verified live provider bindings;
9. verified live carrier programs.

The runtime stores references to approvals, not privileged legal analysis or secret credentials.

## Runtime controls

`src/infrastructure/config/deployment.ts` is the deployment-control authority for process-level configuration.

Required behavior:

- default stage is `synthetic`;
- `synthetic` is allowed without live evidence;
- `pilot` and `production` enumerate missing evidence as blockers;
- readiness is machine-readable;
- live stages reject adapter IDs beginning with `synthetic-`;
- no API path may convert a missing approval into an assumed approval;
- secrets remain in deployment secret storage, never in committed evidence references.

## Readiness endpoint

`GET /api/health/readiness`

Responses:

- `200` when the configured stage is operationally allowed;
- `503` when a live stage is blocked or deployment-control configuration is invalid.

The endpoint MUST NOT expose credentials, tokens, encryption material, report contents, consumer PII, or confidential approval documents.

## Provider enablement

A real provider may be registered only when all of the following are known and documented:

- provider identity and product;
- capability (`IDENTITY`, `PREFILL`, `MVR`, `CLAIMS`, or `VEHICLE`);
- approved jurisdiction/product line;
- contractual purpose code;
- required notices/authorizations;
- storage permission and retention constraints;
- freshness semantics;
- adapter version;
- secret/configuration location;
- test/certification evidence;
- rollback/kill-switch procedure.

Provider-specific response fields MUST normalize into the existing provider-neutral observation/provenance model. Provider-specific fields MUST NOT expand the canonical QuoteCase schema unless separately specified.

## Carrier enablement

A real carrier program may be registered only when all of the following are known and documented:

- carrier and program identity;
- approved handoff mechanism;
- jurisdiction and product line;
- required-field policy version;
- rating-input mapping version;
- response mapping version;
- notice ownership version;
- certification state and evidence;
- adapter version;
- idempotency semantics;
- retry/reconciliation rules;
- rollback/kill-switch procedure.

Carrier-specific mappings remain configuration. They MUST NOT fork the canonical QuoteCase model.

## Notice and legal-copy enablement

Committed code MAY contain notice rendering mechanics and synthetic fixture copy. A live deployment MUST reference an approved notice set. Approval must identify the exact version/hash used by the deployment.

No engineer, model, or deployment script may mark legal copy approved without an external authorized reviewer/source.

## Data-retention enablement

A live deployment MUST have an approved retention policy that addresses, at minimum:

- abandoned quote data;
- completed quote data;
- consent evidence;
- identity data;
- provider reports;
- normalized observations;
- carrier submissions and decisions;
- audit events;
- privacy-request evidence.

Automated deletion/retention jobs MUST NOT be enabled until these periods are resolved.

## Observability

Production telemetry MUST preserve correlation while minimizing sensitive data. Logs and metrics MUST use identifiers such as trace ID, QuoteCase ID, provider request ID, carrier submission ID, adapter ID/version, status, latency, retry count, and reason code. Raw provider reports, identity plaintext, VIN/license plaintext, tokens, and secret values MUST NOT be logged.

Minimum alerts for live operation:

- readiness endpoint blocked;
- provider failure-rate or retry exhaustion;
- carrier submission failure/reconciliation mismatch;
- elevated authorization failures;
- database/migration failure;
- queue age above operational threshold;
- kill switch activation;
- abnormal error-rate increase.

## Pilot progression

A controlled pilot proceeds in this order:

1. deploy with `DEPLOYMENT_STAGE=pilot` and live gates intentionally incomplete;
2. verify readiness returns `503` with expected blockers;
3. configure approved evidence references;
4. configure one provider capability at a time;
5. certify one carrier program at a time;
6. verify readiness becomes `200` only after all configured gates pass;
7. run non-consumer or explicitly authorized test cases;
8. reconcile every provider request and carrier submission;
9. review telemetry/security evidence;
10. authorize limited consumer traffic only through an external launch decision.

## Non-goals

Production enablement does not invent:

- agency authority;
- carrier certification;
- provider contracts;
- legal opinions;
- notice approval;
- retention periods;
- credentials;
- real carrier mappings.

Unknown external facts remain `BLOCKED` or `UNVERIFIED`.
