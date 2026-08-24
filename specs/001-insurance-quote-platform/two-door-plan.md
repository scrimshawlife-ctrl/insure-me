# Two-door configuration plan

## Status
Short plan for `two-door-addendum.md`. This is configuration on the sealed
kernel, not a domain fork and not a stack change.

## Approach
Reuse the objects the runtime already has:

- `TenantConfiguration`
- `tenant_hosts`
- `create_consumer_quote_case`
- `brand_configuration_ref`
- `CarrierProgram` allowlists
- agent selection mode `NONE | SINGLE | MULTIPLE`

Add a second synthetic tenant and host later. Do not invent new consumer,
agent, or provider entities. Do not add a lead-pool table.

```text
Exclusive hostname --> tenant_hosts --> Exclusive TenantConfiguration
                                           + one CarrierProgram (SINGLE)
                                           + synthetic brand ref

Broker hostname    --> tenant_hosts --> Broker TenantConfiguration
                                           + current multi-program path
                                           + agency / Insure Me brand ref

                    one kernel, no shared QuoteCase
```

Exclusive Allstate is a tenant allowlist plus a `CarrierAdapter` at the
boundary. Core workflow MUST NOT read a carrier display name.

## What you configure

| Concern | Exclusive tenant | Broker tenant |
|---|---|---|
| `tenant_hosts` | one active hostname | a different active hostname |
| `carrier_program_ids` | exactly one | one or more |
| Selection UI | `SINGLE`; no “which carrier?” | current multi-program selector when count > 1 |
| `brand_configuration_ref` | synthetic or agency until Q-010 approval | agency or Insure Me white-label; no Allstate mark |
| Handoff | `STUB` or `MANUAL` until Q-003 | current stub path until a certified program exists |
| Providers | same capability slots; LexisNexis/Verisk stay uncontracted | same |

## Day-one production notes
Apply these only on the live paths this addendum touches.

- **Fail closed tenant resolution.** Unknown, inactive, or mismatched
  `tenant_hosts` rows MUST deny QuoteCase creation and privacy intake. Do not
  infer a tenant from a client field.
- **Idempotency.** QuoteCase creation, provider orders, and carrier submissions
  keep their existing idempotency keys. Two doors do not share keys or cases.
- **Secrets.** Keep provider and carrier credentials tenant-scoped. The GitHub
  Pages site MUST contain no secrets, tokens, or analytics IDs.
- **Migrations and rollback.** The later second-tenant seed is data, not a
  canonical schema fork. Roll back by retiring the `tenant_hosts` row and the
  `TenantConfiguration` version. Do not rewrite historical QuoteCase policy
  context.
- **Logs.** Record hostname plus opaque tenant, configuration, and case IDs.
  Do not log raw PII, notice bodies, or report contents.
- **Timeouts.** Hostname resolution is a local system-of-record read. Do not
  add a new outbound network hop to resolve a tenant.

## Scale gate
Hostname maps stay small. Do not introduce Kubernetes, database sharding, or
a dedicated tenant-routing cluster for this operator model.

## Out of scope for this plan
- implementing the later synthetic seed tasks
- enabling live Allstate, LexisNexis, or Verisk
- adding `INSURANCE_HISTORY` to the runtime capability enum
- GitHub Pages as a live quote app
