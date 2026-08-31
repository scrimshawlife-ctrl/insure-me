# D-001 Two-door operator model

## ID
`D-001`

## Date
2026-08-24

## Decision
Operate Insure Me as two tenants under one human: an Exclusive
`TenantConfiguration` and a Broker `TenantConfiguration`, each with its own
`tenant_hosts` row and hard data wall.

Close the following questions as product decisions. Do not invent a licensed
entity, Allstate corporate approval, or a vendor contract.

### Q-010 Branding — closed
Exclusive MAY use carrier-shaped branding only with recorded third-party mark
approval. Until that approval exists, Exclusive MUST use a synthetic or agency
brand.

Broker is agency-branded or Insure Me white-label and MUST NOT use the Allstate
mark.

Live production mark evidence remains a launch gate. This close decides who
may wear which mark. It does not record an Allstate approval.

### Q-011 Multi-carrier strategy — closed
Exclusive = one configured `CarrierProgram` (`SINGLE`). Comparative quoting is
forbidden on Exclusive.

Broker = multiple programs allowed. Comparative quoting is still not required
for MVP.

### T001 Operator model — updated, not production-cleared
The operator model is two tenants (Exclusive + Broker) under one human.

The first licensed agency or entity remains `BLOCKED FOR PRODUCTION`. This
decision does not name, invent, or certify that entity (Q-001).

## Authority / source
- Operator intent for an Allstate producer who holds both an Exclusive book
  and a broker book
- `CONSTITUTION.md` §2.4, §2.6, §2.7, §2.16
- `spec.md` FR-001, FR-026, FR-027, FR-028
- `two-door-addendum.md`

## Alternatives considered
1. **One tenant, two brands.** Rejected. Constitution §2.7 forbids
   cross-tenant leakage; a shared case or consent ledger would become a lead
   mill.
2. **One tenant, carrier-name branch in the domain.** Rejected. Constitution
   §2.6 and FR-028 forbid core branching on carrier names.
3. **Forked Exclusive consumer/agent/provider objects.** Rejected. FR-026
   requires configuration and branding, not a workflow fork.
4. **Shared lead-pool entity.** Rejected. There is no lead-pool entity.
5. **Assume Allstate, LexisNexis, or Verisk approval.** Rejected. Provenance
   rules forbid invented corporate or vendor approval.

## Affected specs
- `two-door-addendum.md`
- `two-door-plan.md`
- `open-questions.md`
- `tasks.md`
- `operations.md`
- `user-flows.md`
- `acceptance.md`
- `data-model.md`
- `spec.md` (pointer only)

## Implementation consequence
Later synthetic work seeds a second tenant and host, proves A-027 isolation,
applies two-host synthetic theming, and lints Exclusive `SINGLE` plus compare
copy. That work is configuration and fixtures. It is not a runtime change in
the pull request that records this decision.

GitHub Pages may present the two doors with synthetic brands. Pages is not
live intake.

## Security / compliance consequence
Tenant isolation becomes the Exclusive/Broker hard wall. Hostname resolution
stays fail closed. Quote consent stays separate from marketing. No ads,
pixels, or shared thank-you tracker until Exclusive handoff is `CERTIFIED`
(`NOT_COMPUTABLE` today).

## Migration / rollback consequence
No canonical schema fork. Adding or removing the second tenant is a
configuration version change. Rollback retires the host and configuration.
Historical QuoteCase rows keep the `TenantConfiguration` version they used.

## Reviewer / owner
Product operations owns the two-tenant model. A named licensed-entity owner
is still required before production (Q-001) and is not invented here.
