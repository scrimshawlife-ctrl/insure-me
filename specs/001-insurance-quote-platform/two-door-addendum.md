# Two-door operator addendum

## Status
Addendum to the sealed synthetic-core specification
(`SPECS_SEALED_FOR_SYNTHETIC_CORE_IMPLEMENTATION`). This document specifies
what and why. It does not choose a stack and it does not fork the canonical
domain.

Related artifacts:

- `two-door-plan.md` — configuration plan, not a domain fork
- `decisions/D-001-two-door-operator.md` — Q-010, Q-011, and T001
- `tasks.md` — later unchecked synthetic seed work

## Why this addendum exists
An Allstate producer can operate both an Exclusive book and a broker book. If
Insure Me treated those books as one intake surface, one lead list, or one
thank-you funnel, the platform would become a shared lead mill.

Channel is the tenant. You give the operator two front doors, two
`TenantConfiguration` records, and one kernel.

This addendum does **not** claim Allstate corporate approval, a live Exclusive
handoff, or a contracted LexisNexis or Verisk product.

## Constitution check
Treat the following as operator intent that this addendum verified against
`CONSTITUTION.md`. Discard any hypothesis the constitution forbids.

| Hypothesis | Verdict |
|---|---|
| Two `TenantConfiguration` records and two `tenant_hosts` rows for one human operator | **Aligned** with §2.7 and §2.16. Multiple tenant configurations are an architectural requirement, not a product-line expansion. |
| Hard wall: no shared `QuoteCase`, `ExternalReport`, `ConsentRecord`, or lead pool | **Aligned** with §2.7. Cross-tenant data access is prohibited. |
| Exclusive tenant allowlists one `CarrierProgram`; Broker may configure several | **Aligned** with §2.4, §2.6, FR-027, and FR-028. Program count is configuration. Core code must not branch on a carrier name. |
| Exclusive Allstate-shaped presentation is `brand_configuration_ref` plus third-party mark approval | **Aligned** with FR-026. Branding must not fork consumer or agent objects. Live third-party mark use stays gated (Q-010). |
| Hostname routing already in `tenant_hosts` / `create_consumer_quote_case`; client must not send `tenant_id` | **Aligned** with FR-001 and the existing API contract. |
| Shared lead-pool entity, ping-post, or aged-lead intake into Exclusive | **Discarded.** §2.7 and this addendum forbid it. There is no lead-pool entity. |
| `if (carrier === 'Allstate')` in `src/domain/` | **Discarded.** §2.4 and §2.6 require `CarrierProgram` + `CarrierAdapter` at the boundary. |
| Forked consumer, agent, or provider objects for Exclusive versus Broker | **Discarded.** FR-026 forbids that fork. |
| Invented Allstate corporate approval, vendor contract, or unnamed AMS/rater/messaging vendor | **Discarded.** Provenance rules forbid invented approvals and unnamed vendors. |

## Product statement
Insure Me remains a California private-passenger auto quote-preparation kernel.
The two-door operator model is a tenant-configuration pattern on that kernel:

- **Exclusive door:** one configured `CarrierProgram`, Exclusive presentation
  rules, no comparative shopping copy.
- **Broker door:** the current multi-program path, agency or Insure Me
  white-label presentation, no Exclusive carrier mark.

Both doors share the same QuoteCase, consent, provider, readiness, and carrier
handoff semantics. They do not share cases, reports, consents, credentials, or
prospects.

## Non-goals
- a lead-pool, ping-post, or aged-lead entity or workflow
- a domain fork of Prospect, Driver, Vehicle, `ExternalReport`, or provider
  objects
- carrier-name branching in the canonical domain
- live Allstate corporate approval or a certified Exclusive handoff
- contracted LexisNexis or Verisk activation
- consumer ads, pixels, or a shared thank-you tracker
- relaxing purpose, notice, portal-scrape, marketing-consent, underwriting-data
  ads, or readiness-versus-risk-score rules

## Functional requirements

### FR-030 Two doors, one kernel
You MUST represent the Exclusive book and the Broker book as two
`TenantConfiguration` records and two `tenant_hosts` rows. One human operator
MAY exist behind both tenants. The kernel MUST remain a single
carrier-neutral, provider-neutral, tenant-aware implementation.

This extends FR-001, FR-026, FR-027, FR-028, and constitution §2.6, §2.7, and
§2.16. It does not replace them.

### FR-031 Hard wall and no lead pool
A QuoteCase, `ExternalReport`, `ConsentRecord`, provider credential, carrier
credential, notice set, and workforce action MUST belong to exactly one
tenant.

There is **no** lead-pool entity. Do not add a shared lead, ping-post,
aged-lead, or cross-door prospect table in a later change. Exclusive MUST
reject ping-post and aged-lead intake.

### FR-032 Exclusive tenant constraints
For the Exclusive `TenantConfiguration`:

- allowlist exactly one `CarrierProgram` (`SINGLE`);
- forbid compare copy and any post-pull “which carrier?” step;
- treat carrier-shaped branding as `brand_configuration_ref` plus third-party
  mark approval (Q-010 / D-001);
- use synthetic or agency brands until that approval exists;
- keep handoff `STUB` or `MANUAL` until Q-003 answers deep link versus
  structured export;
- do not promise Allstate corporate approval;
- do not place consumer ads, pixels, or a shared thank-you tracker on Exclusive
  until Exclusive handoff is `CERTIFIED`.

That certification is `NOT_COMPUTABLE` today.

### FR-033 Broker tenant constraints
For the Broker `TenantConfiguration`:

- keep the current multi-program path;
- allow more than one `CarrierProgram` when configuration says so;
- do not require comparative quoting for MVP;
- do not use the Allstate mark;
- treat LexisNexis and Verisk as `CANDIDATE / UNCONTRACTED` capability slots
  only.

### FR-034 Trusted hostname resolution
You MUST resolve tenant context from a trusted `tenant_hosts` match on the
request hostname, then create the QuoteCase with that tenant, agency, and
`TenantConfiguration` version.

The client MUST NOT supply `tenant_id`. Unknown, inactive, or ambiguous hosts
MUST fail closed before intake, regulated lookup, or privacy discovery.

## Presentation rules
- Exclusive copy MUST never say compare.
- Exclusive consumer copy MUST never name Allstate unless a recorded
  third-party mark approval exists for that `brand_configuration_ref`. Until
  then, use a synthetic or agency brand.
- Broker copy MUST never wear the Allstate mark.
- GitHub Pages door pages are specification presentation, not live intake.

## Controls you must not relax
- no lookup without a tenant-bound QuoteCase, permissible purpose, and required
  notice;
- no portal scrape;
- quote consent is not marketing consent;
- no advertising enrichment from underwriting data;
- readiness is not a risk score.

## Insurance-history capability note
Constitution §2.5 and FR-005 require an insurance-history capability interface.
The locked runtime `ProviderCapability` enum is `IDENTITY | PREFILL | MVR |
CLAIMS | VEHICLE` and does **not** include insurance-history.

Record that gap here. Do not add the enum in this specification change.

## Production gates this addendum does not lift
Live Allstate, live LexisNexis, and live Verisk stay gated. Q-001 licensed
entity evidence, Q-003 live handoff, Q-004 provider contracts, and production
mark approval remain `BLOCKED` or `UNVERIFIED` until authorized evidence
exists.
