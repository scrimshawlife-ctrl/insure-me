# Insure Me — Canonical Synthetic Core Build Prompt

Use this prompt with the coding agent that will implement the runtime.

---

You are implementing the Insure Me synthetic core from the canonical specification repository.

## Authority and read order
Before editing runtime code, read these files in order:

1. `CONSTITUTION.md`
2. `AGENTS.md`
3. `specs/001-insurance-quote-platform/spec.md`
4. `specs/001-insurance-quote-platform/data-model.md`
5. `specs/001-insurance-quote-platform/api-contracts.md`
6. `specs/001-insurance-quote-platform/compliance.md`
7. `specs/001-insurance-quote-platform/security.md`
8. `specs/001-insurance-quote-platform/integrations.md`
9. `specs/001-insurance-quote-platform/user-flows.md`
10. `specs/001-insurance-quote-platform/fixtures.md`
11. `specs/001-insurance-quote-platform/plan.md`
12. `specs/001-insurance-quote-platform/runtime-contract.md`
13. `specs/001-insurance-quote-platform/tasks.md`
14. `specs/001-insurance-quote-platform/acceptance.md`
15. `specs/001-insurance-quote-platform/traceability.md`
16. `specs/001-insurance-quote-platform/open-questions.md`
17. `specs/001-insurance-quote-platform/operations.md`

Treat that hierarchy as binding. Do not infer product requirements from convenience, UI taste, vendor SDKs, or carrier/provider assumptions.

If artifacts conflict, use this precedence:

`law/regulation -> certified carrier contract/program -> approved provider contract -> CONSTITUTION.md -> spec.md -> domain/API/compliance/security specs -> plan/runtime-contract -> tasks -> implementation preference`.

For the synthetic build, do not invent legal conclusions, live provider capabilities, live carrier capabilities, production credentials, or production authorization. Unknown live integrations remain disabled and marked `UNVERIFIED` or `BLOCKED` where applicable.

## Primary objective
Build the complete California private-passenger auto synthetic core and reach:

`SYNTHETIC_CORE_ACCEPTED`

This means the entire consumer -> provider enrichment -> normalization -> readiness -> agent review -> carrier handoff -> carrier response/follow-up path works with deterministic synthetic adapters and passes all P0 CORE acceptance criteria without live carrier or consumer-report credentials.

Do not attempt to declare `PRODUCTION_READY`.

## Locked runtime
Use the runtime contract exactly unless a concrete technical impossibility is proven and documented.

- Node.js 22 LTS
- TypeScript strict mode
- Next.js 16 App Router
- pnpm
- Tailwind CSS
- shadcn/ui
- Zod
- Vercel-compatible application runtime
- Supabase PostgreSQL
- Supabase Auth
- PostgreSQL RLS
- Supabase CLI SQL migrations
- Supabase Queues/pgmq behind an internal abstraction
- Vitest
- Playwright
- MSW or equivalent deterministic boundary mocks where useful
- OpenTelemetry-compatible telemetry

Do not introduce another framework, ORM, queue vendor, auth provider, or state-management library merely for convenience. Prefer platform-native capabilities and small modules.

## Non-negotiable architecture

### 1. Domain isolation
`src/domain/**` MUST NOT import:
- Next.js;
- React;
- Supabase SDKs;
- Vercel APIs;
- carrier SDKs;
- provider SDKs;
- UI code.

The domain layer contains canonical types, invariants, state transitions, policy inputs/outputs, and pure logic.

### 2. Tenant isolation
Every QuoteCase and regulated action resolves to trusted tenant/agency context.

- never trust client-provided `tenantId` as authority;
- server derives tenant scope from authenticated identity/configuration;
- enforce application-level object authorization;
- enforce PostgreSQL RLS as defense in depth;
- test cross-tenant reads, writes, exports, provider execution, carrier execution, and existence-oracle behavior;
- isolate credentials by tenant and environment.

Any cross-tenant leak is P0.

### 3. Provider independence
Core behavior depends on ProviderAdapter capability interfaces only.

Implement:
- `StubIdentityAdapter`
- `StubPrefillAdapter`
- `StubMvrAdapter`
- `StubClaimsAdapter`
- `StubVehicleAdapter`
- `StubInsuranceHistoryAdapter`

Provider names MUST NOT control core branches.

Every regulated provider request MUST perform server-side preflight for:
- valid QuoteCase;
- tenant/agency context;
- jurisdiction/product;
- actor/service principal;
- permissible purpose;
- required notice/authorization;
- configured provider capability;
- data minimization/request scope;
- case state;
- caller permission.

Fail closed before adapter execution if any prerequisite fails.

### 4. Carrier independence
Implement carrier behavior only through `Carrier`, `CarrierProgram`, capability descriptors, program configuration, mapping boundaries, and `CarrierAdapter`.

Implement at minimum:
- `StubCarrierAdapterA`
- `StubCarrierAdapterB`

The two synthetic carrier programs MUST differ meaningfully. For example, they may require different canonical input subsets, different rating-input allowlists, or different handoff payload shapes. The same canonical QuoteCase must be able to target either program without changing canonical Driver, Vehicle, Person, QuoteCase, ExternalReport, UnderwritingObservation, or CarrierDecision schemas.

Never write logic equivalent to:

```ts
if (carrier.name === "...") { ... }
```

Carrier-specific transformation belongs inside adapter/program mapping modules only.

### 5. Data semantics
Keep these objects separate:

`ExternalReport != UnderwritingObservation != RatingInput != CarrierSubmission != CarrierDecision`

Do not collapse them into a generic JSON blob.

A provider result cannot flow directly into a carrier payload without:
1. normalization;
2. provenance;
3. data-use classification;
4. readiness/policy evaluation;
5. explicit RatingInput/submission mapping where required.

### 6. Readiness
Readiness is workflow completeness only.

It may consider:
- required fields;
- freshness;
- missing provider results;
- conflicts;
- unresolved issues;
- selected CarrierProgram prerequisites.

It MUST NOT become:
- risk score;
- insurability score;
- predicted premium;
- autonomous underwriting decision.

### 7. Idempotency and atomicity
Use durable idempotency for:
- QuoteCase creation where applicable;
- provider requests;
- notice delivery;
- privacy requests;
- carrier submissions.

Duplicate provider charges/executions or carrier submissions are P0 defects.

Critical transitions MUST settle atomically with their audit evidence when the specs require one logical action.

Use database transactions for critical state transitions rather than unrelated best-effort writes.

### 8. Audit and provenance
Every sensitive or regulated action MUST generate the required AuditEvent.

Every material externally derived fact visible to an agent MUST resolve to provenance.

Historical evidence must retain exact configuration/policy/adapter versions needed to reconstruct why an action was permitted and how data moved.

### 9. Synthetic-only default
Local and CI MUST run with no live credentials and no required external network calls.

Never place production PII in:
- fixtures;
- tests;
- screenshots;
- logs;
- telemetry;
- source control.

## Required repository structure
Implement the structure in `runtime-contract.md` unless the repository already contains an equivalent structure that preserves the same dependency boundaries.

Expected major areas:

```text
app/
src/domain/
src/application/
src/adapters/
src/infrastructure/
src/contracts/
src/testkit/
supabase/migrations/
supabase/tests/
tests/unit/
tests/contract/
tests/integration/
tests/e2e/
```

Do not produce a page-first architecture where business logic lives in route handlers or React components.

## Database implementation
Create forward migrations from an empty database for the canonical relational model.

At minimum implement versioned persistence for:
- TenantConfiguration
- Agency
- workforce membership/role/permission
- QuoteCase
- Person/Prospect
- Driver
- Vehicle
- CoverageRequest
- NoticeDefinition
- ConsentRecord
- PermissiblePurposeDecision
- ProviderBinding / provider capability configuration
- ExternalRequest
- ExternalReport
- provenance relationships
- UnderwritingObservation
- RatingInput
- ReadinessIssue
- Carrier
- CarrierProgram
- CarrierSubmission
- CarrierDecision
- PrivacyRequest
- retention/disposition state
- AuditEvent

Use the canonical data model for exact fields and relationships.

Add:
- primary/foreign keys;
- tenant-scoped constraints;
- idempotency uniqueness constraints;
- lifecycle/state constraints where useful;
- timestamps/version references;
- RLS policies;
- indexes for expected queue/workspace/filter paths;
- migration tests.

Generated database types MUST match the current schema and be checked for drift in CI.

## Authentication and authorization
Implement distinct assurance rules.

Consumer:
- expiring magic-link/OTP or equivalent Supabase Auth session;
- access only to the authorized QuoteCase;
- no workforce permissions.

Workforce:
- authenticated Supabase user;
- MFA required for agent/admin routes;
- tenant-scoped membership;
- explicit roles/permissions;
- object-level authorization.

Service principals:
- server only;
- minimal capability;
- no policy bypass.

## API implementation
Implement the `/v1` contracts in `api-contracts.md`.

Route handlers MUST be thin.

Do not put domain logic, authorization truth, or carrier/provider branching into route files.

Requirements:
- Zod validation;
- stable reason/error codes;
- secure request bodies for sensitive fields;
- no sensitive identifiers in URLs/query strings;
- field-level authorization in responses;
- redacted audit endpoints;
- idempotency enforcement;
- server-side carrier/provider policy evaluation.

## Consumer experience
Build the mobile-first synthetic journey:
1. start QuoteCase;
2. secure resume/session;
3. identity/contact;
4. notices and authorizations;
5. deterministic synthetic prefill;
6. confirm/edit drivers;
7. confirm/edit vehicles;
8. execute permitted synthetic reports;
9. supply remaining quote inputs;
10. correction/status surfaces.

Keep the flow low-friction and accessible. Do not expose internal underwriting observations or prohibited provider details to the consumer status endpoint.

## Agent workspace
Build:
- MFA-gated case queue;
- QuoteCase detail;
- normalized drivers/vehicles/coverage;
- provider status;
- source provenance;
- conflict/readiness issue display;
- permitted refresh action;
- human issue resolution;
- carrier-program selector when multiple programs are enabled;
- submission state;
- synthetic carrier response/follow-up.

The workspace must make missing/conflicting data explicit rather than silently resolving it.

## Admin surface
Build the minimum functional configuration surface required by the specs:
- users/memberships/roles;
- tenant configuration;
- provider bindings/capabilities;
- Carrier/CarrierProgram configuration;
- notice/policy versions;
- environment certification state;
- kill switches;
- appropriate audit access.

Admin changes that affect regulated behavior must be versioned and audited.

## Privacy/retention surface
Implement synthetic workflows for:
- privacy request creation;
- requester-safe status;
- identity-verification state;
- correction/deletion/restriction handling;
- legal/contractual exception state;
- retention expiration;
- legal hold;
- disposition work;
- evidence/audit events.

Before identity verification, do not reveal whether a person or QuoteCase exists.

## Queue/workers
Wrap pgmq/Supabase Queues behind an internal interface.

Use durable jobs for work such as:
- provider executions when asynchronous;
- notice delivery;
- carrier polling when a future live adapter requires it;
- privacy/retention disposition;
- retry/dead-letter workflows.

Bound retries. Do not retry validation, authorization, purpose, or other deterministic policy failures.

## Synthetic fixtures
Implement every fixture required by `fixtures.md` and `acceptance.md`, including:
- happy path;
- no-hit;
- multiple drivers;
- multiple vehicles;
- conflicting facts;
- stale report;
- provider outage;
- malformed provider result;
- prohibited/unauthorized lookup;
- consumer correction;
- privacy deletion;
- legal hold;
- adverse-action support rehearsal;
- carrier validation failure;
- carrier auth failure;
- carrier timeout/unavailable;
- carrier rejection;
- ambiguous carrier status;
- CarrierProgram A;
- CarrierProgram B.

Fixtures must be deterministic and contain no real PII.

## Acceptance implementation
Convert every P0 CORE criterion in `acceptance.md` into automated tests where technically possible.

At minimum prove:
- A-001 through A-030 P0 CORE items applicable to synthetic acceptance;
- no provider execution before purpose/notice/jurisdiction gates;
- tenant isolation at API and RLS layers;
- provider neutrality;
- external-data provenance;
- report/observation/rating separation;
- readiness is not risk;
- conflict review;
- provider idempotency;
- carrier idempotency;
- telemetry PII exclusion;
- consumer session isolation;
- workforce MFA/authorization;
- complete synthetic provider path;
- complete synthetic carrier path;
- CarrierProgram gate/kill switch;
- carrier mapping boundary;
- defined failure/degraded modes;
- privacy existence protection;
- retention/legal hold;
- audit completeness;
- accessibility baseline;
- carrier portability using A and B;
- tenant configuration isolation;
- configuration-version replay;
- carrier switch does not rewrite canonical facts;
- notification consent separation.

If an acceptance item cannot be automated, create explicit machine-readable evidence output and explain why automation is not possible.

## CI gates
Create CI that fails on:
- formatting/lint failure;
- TypeScript failure;
- unit/contract/integration failure;
- Playwright P0 failure;
- migration-from-empty failure;
- RLS isolation failure;
- generated database type drift;
- prohibited PII or secret patterns in fixtures/log snapshots/telemetry tests;
- carrier-name/provider-name branching detected in protected core directories where practical;
- missing acceptance evidence.

## Security requirements
Implement the controls in `security.md` rather than creating a separate security model.

At minimum:
- secure cookies/session handling;
- CSRF controls where applicable;
- strict CORS;
- CSP;
- request-size limits;
- rate limits/abuse controls at sensitive paths;
- least privilege;
- encryption at rest/in transit through platform controls;
- no service-role key in client bundles;
- secrets only in secret stores/env injection;
- no sensitive GET parameters;
- safe error responses;
- audit-sensitive reads/writes/exports/config changes.

## No premature live integration
Do NOT implement a live carrier or consumer-report provider unless the repository contains the exact approved contract/capability/certification evidence required by the specs.

Instead create clean live-adapter extension points and leave them disabled.

Do not use a guessed field list from a carrier website or random API documentation to shape the canonical model.

## Documentation and evidence
During implementation keep these synchronized:
- migrations/schema;
- generated DB types;
- API contracts;
- implementation task status;
- acceptance test references;
- traceability identifiers;
- operational notes needed to run local/CI/staging.

Do not silently alter canonical requirements. If implementation reveals a genuine spec contradiction, stop that slice, document the exact conflict, and propose the smallest spec amendment before coding around it.

## Execution order
Work in vertical but spec-controlled slices:

### Slice 0 — bootstrap
Set up application, local Supabase, lint/typecheck/test/Playwright/CI, environment validation, and synthetic-only defaults.

### Slice 1 — domain/database/tenant kernel
Implement schema, migrations, RLS, TenantConfiguration, workforce membership, QuoteCase lifecycle, audit, idempotency primitives, and canonical domain types.

### Slice 2 — consumer identity/notices
Implement consumer session, identity/contact, notice ledger, consent state, secure resume, and required API paths.

### Slice 3 — provider gateway
Implement capability registry, preflight policy gate, ExternalRequest, deterministic adapters, normalization, ExternalReport, provenance, and failure taxonomy.

### Slice 4 — drivers/vehicles/coverage/readiness
Implement consumer confirmation/editing, observations, conflicts, DataUsePolicy, RatingInput boundary, and completeness-only readiness.

### Slice 5 — agent workspace
Implement MFA-gated queue/detail/provenance/issue resolution/refresh behavior.

### Slice 6 — dual synthetic carrier gateway
Implement Carrier/CarrierProgram registry, A/B program fixtures, mapping boundary, idempotent submission, failure states, CarrierDecision, follow-up, portability tests, and kill switches.

### Slice 7 — privacy/retention/admin
Implement privacy, disposition/legal-hold, configuration administration, version replay evidence, and audit completeness.

### Slice 8 — acceptance closure
Run all P0 CORE acceptance, security, RLS, accessibility, telemetry, migration, and e2e gates. Repair failures. Re-run until clean.

## Required completion report
When finished, return a concise report with:

1. exact branch and head SHA;
2. files/modules added or materially changed;
3. database migrations created;
4. implemented API routes;
5. implemented UI surfaces;
6. synthetic adapters implemented;
7. tests by category and pass counts;
8. P0 CORE acceptance matrix with PASS/FAIL/BLOCKED for every criterion;
9. tenant-isolation evidence;
10. carrier-portability evidence for Adapter A vs B;
11. provider/carrier idempotency evidence;
12. telemetry/PII-scan evidence;
13. migration-from-empty evidence;
14. remaining production-only blockers;
15. final state label.

The final state label may be `SYNTHETIC_CORE_ACCEPTED` only if every required P0 CORE criterion passes.

Never use `PRODUCTION_READY` unless the separate production gates in the canonical specification have actually been satisfied with evidence.

## Completion rule
Do not stop after scaffolding, one happy path, or visual completion.

Continue through the full synthetic acceptance chain. Fix implementation defects you discover. Preserve canonical boundaries. Do not hide failed tests or unresolved acceptance criteria.

The goal is not “an app that looks done.” The goal is a traceable, deterministic, carrier/provider-agnostic synthetic core whose architecture can accept real certified integrations later without rewriting its domain model.
