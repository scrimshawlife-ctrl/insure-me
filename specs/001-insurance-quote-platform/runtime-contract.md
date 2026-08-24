# Runtime Implementation Contract

## Status
`LOCKED_FOR_SYNTHETIC_CORE_IMPLEMENTATION`

This document converts the canonical specification into a concrete first-runtime contract. It does not change product semantics. Where this file conflicts with `CONSTITUTION.md` or `spec.md`, the higher-order canonical artifact wins.

## Runtime objective
Build the complete synthetic Insure Me core as one deployable TypeScript application with strict tenant isolation, deterministic provider/carrier adapters, source-backed domain facts, executable policy gates, and acceptance evidence.

Live provider and carrier activation remains separately gated.

## Locked first implementation stack

### Application
- Node.js 22 LTS runtime.
- TypeScript with `strict: true`.
- Next.js 16 App Router.
- React Server Components by default; client components only for interactive UI boundaries.
- pnpm workspace/package manager.
- Tailwind CSS + shadcn/ui for accessible UI primitives.
- Zod for external/request/configuration runtime validation.

### Hosting
- Vercel for the Next.js web/API runtime.
- Separate preview/staging and production environment configuration.
- No production dependency may be inferred from a preview environment.

### Data platform
- Supabase PostgreSQL as the system of record.
- Supabase Auth for consumer and workforce identities.
- PostgreSQL Row Level Security as a defense-in-depth tenant boundary.
- Supabase CLI SQL migrations are canonical for database schema changes.
- Generated database types checked into the repository after schema changes.
- Supabase Queues/`pgmq` behind an internal queue abstraction for durable asynchronous work.
- Supabase Storage disabled for raw regulated reports by default; object storage use requires an approved retention/storage rule.

### Authentication
Consumer:
- expiring magic-link or OTP session;
- QuoteCase-scoped authorization;
- no workforce permissions.

Workforce:
- Supabase Auth identity;
- MFA required before agent/admin routes;
- tenant-scoped application roles and permissions;
- server-enforced RBAC/ABAC.

Service principals:
- server-only credentials;
- narrow explicit capabilities;
- never bypass purpose, consent, jurisdiction, tenant, or carrier-program policy gates.

### Testing
- Vitest for unit/domain/contract tests.
- MSW or equivalent deterministic HTTP boundary mocks where network-shape testing is useful.
- Playwright for end-to-end consumer, agent, admin, and privacy workflows.
- SQL/RLS tests for tenant and object isolation.
- deterministic synthetic adapters and fixture seeds from `fixtures.md`.

### Observability
- OpenTelemetry-compatible traces/metrics/logs.
- structured event logging.
- opaque identifiers only in ordinary telemetry.
- prohibited PII/report-content scanning in CI.

## Repository layout

```text
/
├── app/
│   ├── (consumer)/
│   ├── agent/
│   ├── admin/
│   ├── privacy/
│   └── api/v1/
├── src/
│   ├── domain/
│   │   ├── quote/
│   │   ├── identity/
│   │   ├── notice/
│   │   ├── provider/
│   │   ├── observations/
│   │   ├── readiness/
│   │   ├── carrier/
│   │   ├── privacy/
│   │   └── audit/
│   ├── application/
│   │   ├── commands/
│   │   ├── queries/
│   │   └── policies/
│   ├── adapters/
│   │   ├── providers/
│   │   │   ├── stub/
│   │   │   └── live/
│   │   ├── carriers/
│   │   │   ├── stub/
│   │   │   └── live/
│   │   ├── notifications/
│   │   └── queue/
│   ├── infrastructure/
│   │   ├── supabase/
│   │   ├── auth/
│   │   ├── telemetry/
│   │   └── config/
│   ├── contracts/
│   └── testkit/
├── supabase/
│   ├── migrations/
│   ├── seed.sql
│   └── tests/
├── tests/
│   ├── unit/
│   ├── contract/
│   ├── integration/
│   └── e2e/
└── specs/
```

Layer rule: `domain` cannot import Next.js, Supabase, Vercel, provider SDKs, carrier SDKs, or UI code.

## Canonical TypeScript boundaries

```ts
export type Jurisdiction = "CA";
export type ProductLine = "PRIVATE_PASSENGER_AUTO";

export interface TenantContext {
  tenantId: string;
  agencyId: string;
  configurationVersionId: string;
}

export interface QuoteCaseRef {
  quoteCaseId: string;
  tenantId: string;
  jurisdiction: Jurisdiction;
  productLine: ProductLine;
}

export interface ProvenanceEntry {
  sourceType: "USER" | "PROVIDER" | "CARRIER" | "SYSTEM";
  sourceId: string;
  retrievedAt?: string;
  reportId?: string;
  transformationVersion?: string;
}

export interface ProviderRequestContext extends TenantContext {
  quoteCaseId: string;
  jurisdiction: Jurisdiction;
  productLine: ProductLine;
  capability: ProviderCapability;
  permissiblePurposeDecisionId: string;
  consentRecordIds: string[];
  subjectIds: string[];
  traceId: string;
  idempotencyKey: string;
}

export interface ProviderAdapter<TRequest, TNormalized> {
  descriptor(): ProviderCapabilityDescriptor;
  validate(ctx: ProviderRequestContext, request: TRequest): Promise<void>;
  execute(
    ctx: ProviderRequestContext,
    request: TRequest
  ): Promise<ProviderResult<TNormalized>>;
}

export interface CarrierProgramDescriptor {
  carrierProgramId: string;
  versionId: string;
  supportedJurisdictions: Jurisdiction[];
  supportedProductLines: ProductLine[];
  handoffMode:
    | "STUB"
    | "API"
    | "DEEPLINK"
    | "AMS_BRIDGE"
    | "STRUCTURED_EXPORT"
    | "MANUAL";
  requiredCanonicalFields: string[];
  ratingInputAllowlist: string[];
  enabled: boolean;
  certificationState: "SYNTHETIC" | "SANDBOX" | "PRODUCTION" | "DISABLED";
  killSwitched: boolean;
}

export interface CarrierRequestContext extends TenantContext {
  quoteCaseId: string;
  carrierProgramId: string;
  carrierProgramVersionId: string;
  traceId: string;
  idempotencyKey: string;
}

export interface CarrierAdapter<TPayload = unknown> {
  descriptor(): CarrierProgramDescriptor;
  validateSubmission(ctx: CarrierRequestContext): Promise<ValidationResult>;
  buildPayload(ctx: CarrierRequestContext): Promise<TPayload>;
  submit(
    ctx: CarrierRequestContext,
    payload: TPayload
  ): Promise<CarrierSubmissionResult>;
  getStatus?(
    ctx: CarrierRequestContext,
    externalReference: string
  ): Promise<CarrierStatus>;
}
```

Exact detailed field definitions MUST be derived from `data-model.md` and `api-contracts.md`, not invented from these abbreviated boundary examples.

## Persistence boundaries
The initial relational schema MUST include versioned records for:
- TenantConfiguration;
- Agency;
- workforce membership/role/permission;
- QuoteCase;
- Person/Prospect;
- Driver;
- Vehicle;
- CoverageRequest;
- NoticeDefinition;
- ConsentRecord;
- PermissiblePurposeDecision;
- ProviderBinding / ProviderCapability configuration;
- ExternalRequest;
- ExternalReport;
- ProvenanceEntry or equivalent normalized provenance relationship;
- UnderwritingObservation;
- RatingInput;
- ReadinessIssue;
- Carrier;
- CarrierProgram;
- CarrierSubmission;
- CarrierDecision;
- PrivacyRequest;
- PrivacyDiscoveryRun and protected PrivacyExportArtifact;
- PrivacyRightsExecution, category actions, and processing restrictions;
- versioned PrivacyPropagationBinding, propagation runs/targets, and append-only attempts;
- RetentionPolicy, bounded RetentionDispositionRun, stable category items, and append-only attempts;
- AdverseActionCase, exact report sources, version-bound notice delivery envelopes, and append-only delivery attempts;
- AuditEvent.

Every regulated record MUST carry tenant scope directly or through an immutable parent relationship that is enforceable in authorization and RLS.

## Database transaction rules
Use database transactions for state transitions that must settle atomically, including:
- QuoteCase lifecycle transition + AuditEvent;
- ConsentRecord creation + relevant lifecycle transition;
- provider ExternalRequest creation/idempotency claim;
- provider result settlement + ExternalReport/observations + readiness recalculation trigger/state update;
- CarrierSubmission idempotency claim + state transition;
- CarrierDecision settlement + follow-up/readiness state;
- privacy/retention disposition state + AuditEvent.
- legal-hold placement/release + immutable LegalHoldEvent + AuditEvent.
- adverse-action determination/report linkage + handoff event + AuditEvent.

Do not implement critical state transitions as unrelated best-effort writes.

## Tenant isolation rules
- `tenant_id` is server-derived from trusted identity/configuration context, never accepted as authoritative from the client.
- RLS policies MUST deny cross-tenant reads and writes by default.
- application authorization MUST independently enforce tenant/object scope; RLS is defense in depth, not the sole control.
- service-role database access MUST be isolated to trusted server modules and MUST still execute application policy checks.
- provider/carrier credentials MUST be tenant + environment scoped.

## Environment contract

### Local
- synthetic fixtures only;
- local Supabase;
- stub provider adapters;
- StubCarrierAdapter;
- no live network dependencies required for acceptance.

### CI
- synthetic fixtures only;
- ephemeral/test database;
- deterministic provider/carrier adapters;
- all P0 CORE acceptance tests;
- schema migration verification;
- generated DB types drift check;
- PII/secret telemetry scan.

### Staging
- separate Supabase project;
- synthetic by default;
- provider/carrier sandbox adapters enabled only by explicit configuration;
- no production credentials.

### Production
- separate Supabase project;
- live adapters disabled unless their exact ProviderBinding/CarrierProgram versions are certified;
- production migration gate;
- deployment evidence records exact spec SHA, migration set, configuration versions, and adapter versions.

## Configuration model
Runtime behavior MUST be data/configuration driven for:
- tenant branding;
- enabled product/jurisdiction;
- provider bindings;
- provider capability policy;
- notice versions;
- carrier/program bindings;
- carrier required-field overlays;
- rating-input allowlists;
- notice/adverse-action ownership;
- retention rules;
- environment certification state;
- kill switches.

Carrier names and provider names MUST NOT appear in conditional core workflow logic.

## Synthetic adapter contract
Implement at minimum:
- StubIdentityAdapter;
- StubPrefillAdapter;
- StubMvrAdapter;
- StubClaimsAdapter;
- StubVehicleAdapter;
- StubInsuranceHistoryAdapter;
- StubCarrierAdapterA;
- StubCarrierAdapterB.

A and B MUST require meaningfully different carrier-program mappings so A-026 proves real adapter portability rather than two aliases of the same fixture.

## API implementation rules
- implement the versioned `/v1` routes defined in `api-contracts.md`;
- route handlers are thin transport boundaries;
- domain/application services own authorization, policy evaluation, idempotency, and state transitions;
- validate all request bodies with Zod;
- never trust client-supplied permissible-purpose, tenant, readiness, or carrier-certification assertions;
- stable machine-readable error taxonomy;
- no sensitive identifiers in URLs or query parameters.

## UI surfaces
Consumer:
- start/resume quote;
- identity/contact;
- notices/authorization;
- driver confirmation;
- vehicle confirmation;
- remaining quote inputs;
- correction/status.

Agent:
- MFA-gated queue;
- QuoteCase detail;
- provenance-aware observations;
- conflicts/readiness issues;
- permitted provider refresh;
- carrier-program selector where more than one is enabled;
- submission and response/follow-up.

Admin:
- tenant configuration;
- user/role management;
- provider bindings;
- carrier/program configuration;
- notice/policy versions;
- certification/kill-switch state;
- audit access according to permission.

Privacy:
- privacy request initiation;
- identity verification state;
- requester-safe status.

## Implementation sequence
Follow `tasks.md`; do not organize work by UI page alone.

First executable milestone:
1. project/bootstrap + CI;
2. database schema/migrations + RLS;
3. tenant/auth context;
4. canonical domain kernel;
5. audit/idempotency primitives;
6. synthetic provider gateway;
7. consumer intake;
8. normalization/readiness;
9. agent workspace;
10. synthetic dual-carrier gateway;
11. privacy/retention workflows;
12. full P0 CORE acceptance chain.

## Definition of synthetic core done
Do not declare completion until:
- every P0 CORE criterion in `acceptance.md` is automated or has explicit machine-verifiable evidence;
- both synthetic carrier programs pass portability tests;
- cross-tenant isolation tests pass at API and RLS levels;
- provider and carrier idempotency tests pass;
- no carrier/vendor name branching exists in core modules;
- no production credentials are needed;
- migrations apply from empty database and generated types match schema;
- lint, typecheck, unit, contract, integration, and Playwright suites pass;
- traceability from FR-001 through FR-029 remains intact.

Successful state label: `SYNTHETIC_CORE_ACCEPTED`.
