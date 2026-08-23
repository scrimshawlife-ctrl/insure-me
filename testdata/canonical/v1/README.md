# Canonical Synthetic Datasets v1

## Purpose

This directory is the canonical deterministic test corpus for the Insure Me synthetic platform boundary. It satisfies FR-025 and is intended to drive unit, integration, API, database, staging, and future E2E tests without live consumer-report, carrier, or production credentials.

## Canonical rules

- Schema: `canonical-synthetic-dataset-v1`
- Clock: `2026-08-23T00:00:00.000Z`
- Jurisdiction: California only
- Product: private-passenger auto only
- Randomness: none
- Classification: `SYNTHETIC_TEST_ONLY`
- Real PII: forbidden
- Production use: forbidden
- Dataset IDs and semantic fixture IDs are stable human-readable test identifiers.
- Database-facing IDs are materialized deterministically as UUIDv5 values by `runtime-seed.ts`.
- Synthetic VIN labels are materialized into stable 17-character VIN-shaped values with forbidden VIN characters excluded.
- Expected results are part of each dataset. A fixture is not canonical if it contains only input data.
- Material conflicts must remain explicit until a test exercises an authorized resolution path.
- Adverse-action data represents workflow handoff/recording only. It does not encode independent Insure Me underwriting logic.

## Required scenario inventory

| Dataset | Primary invariant |
| --- | --- |
| `happy-path` | Complete case reaches carrier readiness and synthetic acceptance. |
| `provider-no-hit` | `NO_HIT` is distinct from success, stale, and error. |
| `multiple-drivers` | Multiple driver subjects remain explicit and source-addressable. |
| `multiple-vehicles` | Multiple vehicles remain explicit and independently addressable. |
| `conflicting-records` | Material conflict blocks handoff; no silent winner is selected. |
| `stale-report` | Stale MVR blocks readiness pending refresh/review. |
| `provider-outage` | Provider error blocks handoff and creates retry semantics. |
| `consumer-correction` | Consumer correction preserves prior/current values and provenance. |
| `adverse-action-handoff` | Responsibility remains with the configured responsible party/carrier. |
| `privacy-deletion` | Deletion request enters retention/policy evaluation rather than blind deletion. |
| `unauthorized-lookup` | Missing report authorization blocks MVR before provider execution. |
| `carrier-adapter-failure` | Synthetic carrier required-input validation fails deterministically. |

## Files

- `canonical-synthetic-datasets.v1.json` — human-readable canonical source catalog.
- `schema.ts` — executable Zod source-catalog contract.
- `runtime-seed.ts` — deterministic materializer for database/runtime identifiers and VIN-shaped values.
- `manifest.v1.json` — pinned inventory and source-blob provenance.
- `tests/contract/canonical-synthetic-datasets.test.ts` — inventory, safety, and semantic conformance.
- `tests/contract/canonical-runtime-seed.test.ts` — database-seed determinism and UUID/VIN conformance.

## Source vs runtime materialization

The JSON catalog deliberately keeps readable semantic IDs such as `qc-happy-path` and `driver-multiple-drivers-02`. Tests and humans can reason about those values directly. Code that must seed UUID-backed runtime tables MUST call `materializeRuntimeSeed()` and MUST NOT invent a second mapping scheme.

The materializer preserves source meaning while deriving stable UUIDv5 values for tenant, agency, tenant configuration, QuoteCase, prospect, person/subject, driver, vehicle, carrier, and CarrierProgram identities. Re-running the same dataset produces the same values.

## Change policy

Treat this corpus like a public contract inside the repository.

1. Do not mutate v1 scenario meaning to make a failing implementation test pass.
2. Fix the implementation when it violates an established invariant.
3. If a product/specification change legitimately changes expected behavior, revise the specification first and create a new dataset version when backward compatibility would be broken.
4. Never copy production records into this directory, even after redaction.
5. Synthetic provider/carrier behavior and this corpus must remain mutually consistent.
6. Do not bypass `runtime-seed.ts` for database seeding.
7. A changed canonical JSON blob requires an intentional manifest update and review.
