# Deferred Scalable Runtime Evolution

## Status

`DEFERRED / NON-BINDING / CURRENT RUNTIME UNCHANGED`

Owner direction recorded: 2026-08-26.

This note preserves a preferred future architecture direction without changing the locked first runtime, current implementation order, acceptance criteria, production gates, or authority hierarchy.

## Current decision

Insure Me will finish the current implementation using the runtime locked by `../001-insurance-quote-platform/runtime-contract.md`:

- Next.js 16 and strict TypeScript for the current web/API runtime;
- Vercel for the current deployable application boundary;
- Supabase PostgreSQL and Auth;
- PostgreSQL Row Level Security as defense in depth;
- deterministic provider and carrier adapters;
- the existing modular domain/application/infrastructure boundaries.

The existing Angular workspace is migration-planning evidence and an inactive scaffold. It MUST NOT create a second active delivery track, delay completion of the current consumer surfaces, or require backend extraction during the current implementation cycle.

No current task is reopened solely because this note exists.

## Why the current path remains acceptable

The current runtime already preserves the architecture features most important to future scale:

- provider- and carrier-neutral domain interfaces;
- tenant-aware records and trusted tenant resolution;
- explicit application, domain, and infrastructure boundaries;
- server-authoritative policy, consent, purpose, privacy, and audit controls;
- transactional PostgreSQL settlement;
- idempotency and deterministic synthetic verification;
- presentation-independent canonical insurance semantics.

Next.js is a transport and presentation choice. It does not control the canonical domain. Completing the present runtime does not prevent later presentation replacement or API extraction.

## Preferred future target

If the revisit gates below are satisfied, the preferred target is:

```text
Angular web application
        |
        v
Canonical versioned HTTP API
        |
        +--> modular TypeScript application services
        +--> Supabase Auth verification
        +--> PostgreSQL transactions and RLS
        +--> durable outbox / Supabase Queues
        |
        v
Dedicated provider, carrier, notice, privacy, retention, and export workers
```

Candidate implementation choices:

- Angular 22.x standalone presentation runtime;
- Angular Signals and typed form architecture for feature/workflow state;
- generated or verified TypeScript client from canonical OpenAPI 3.1 and JSON Schema;
- a stateless Node.js 22 API transport, with NestJS plus Fastify as the leading candidate;
- Supabase PostgreSQL as the system of record;
- Supabase Auth for consumer and workforce identities;
- Supabase Queues/`pgmq` behind an internal queue abstraction;
- horizontally scalable API instances and independently scalable worker instances;
- OpenTelemetry-compatible, PII-safe observability;
- CDN/static delivery for authenticated Angular surfaces unless a reviewed public surface requires SSR;
- container-capable API/worker hosting in the same region as the primary database.

These are candidates, not active commitments. Exact hosting, API framework, workspace tooling, cache, and infrastructure vendors require a later decision record.

## Preserved invariants

Any future migration MUST preserve:

1. Constitution and specification authority.
2. Server-side authentication, authorization, tenant resolution, purpose, notice, consent, jurisdiction, data-use, retention, carrier-program, and certification checks.
3. `ExternalReport != UnderwritingObservation != RatingInput != CarrierDecision`.
4. Provider and carrier neutrality.
5. Atomic regulated state transitions plus AuditEvent evidence.
6. No direct browser authority over regulated database mutations.
7. No regulated secrets or raw report data in browser bundles, browser persistence, ordinary telemetry, or public caches.
8. Deterministic synthetic acceptance without live credentials.
9. Presentation rollback without regulated-data rollback whenever the API contract is unchanged.
10. Existing production hard stops and deployment-specific evidence requirements.

## Revisit gates

Architecture evolution becomes eligible for planning only when at least one trigger exists and the current core completion path is not disrupted:

- `SYNTHETIC_CORE_ACCEPTED` has been reached;
- a selected live provider or CarrierProgram requires durable asynchronous execution;
- Android/iOS companions require a stable presentation-independent HTTP contract;
- measured request duration, concurrency, provider latency, or queue pressure exceeds the current runtime envelope;
- independent API and presentation deployment becomes necessary;
- multiple teams require separately owned application surfaces or release cadences;
- the Next.js transport boundary prevents a required scaling, security, or compliance control;
- production KMS, worker, connection-pooling, or recovery requirements require a persistent service topology.

Weak preference, framework fashion, or an unmeasured assumption is not a migration trigger.

## Required future plan

A later activation decision MUST use the normal spec-driven sequence and include:

1. current-route, API, session, CSRF, and deployment inventory;
2. canonical OpenAPI/JSON Schema publication and drift detection;
3. extraction of thin HTTP transport from reusable application/domain code;
4. transactional outbox or equivalent atomic queue-publication design;
5. idempotent workers with bounded retries, visibility timeouts, circuit breakers, kill switches, and reconciliation;
6. versioned encryption-key resolution using managed KMS/envelope encryption;
7. canonical JSON plus SHA-256 or HMAC-SHA-256 for request/evidence hashing;
8. Angular parity against the same server contracts;
9. negative authorization, tenant-isolation, browser-storage, telemetry, accessibility, and load evidence;
10. controlled cutover, exercised rollback, and separate retirement of superseded presentation code.

## Scaling sequence

Scale in this order unless evidence requires another sequence:

1. optimize queries, indexes, bounded projections, and pagination;
2. use the database connection mode appropriate to persistent or serverless compute;
3. make external and long-running work durable and asynchronous;
4. scale stateless API instances horizontally;
5. scale workers independently by queue class and dependency limits;
6. isolate analytical/compliance-report reads from transactional traffic;
7. add read replicas only for measured read pressure and lag-tolerant workloads;
8. split a module into a service only when it needs materially different scaling, availability, security, ownership, or deployment behavior.

Microservices, Kafka, a distributed cache, and multi-region writes are explicitly not presumed.

## Current hardening items retained

This note does not create new current-sprint scope. Existing production-oriented work remains tracked in specification 001, including:

- T205 production KMS/secrets lifecycle;
- T403 durable provider queue/retry/circuit-breaker completion;
- live provider and carrier adapter certification;
- production observability and recovery evidence;
- production legal, compliance, retention, security, and operator approvals.

When future architecture work activates, it SHOULD also close these observed migration prerequisites:

- publish the canonical OpenAPI/JSON Schema artifact;
- build and test the Angular workspace in CI before claiming migration readiness;
- support decryption through a controlled versioned key ring rather than only the current key version;
- replace non-cryptographic request hashes at regulated/idempotent boundaries;
- define explicit application, worker, and contract packages in a real workspace.

## Impact

- Current runtime contract: unchanged.
- Current implementation priority: unchanged.
- P0 CORE acceptance: unchanged.
- Production gates: unchanged.
- Angular migration: deferred.
- Backend extraction: deferred.
- Mobile companions: not blocked conceptually, but should consume the canonical API only after its contract is published and stable.

## Seal

`CURRENT_RUNTIME_CONTINUES / FUTURE_EVOLUTION_RECORDED / NO_SCOPE_EXPANSION`
