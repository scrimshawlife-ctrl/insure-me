# Production Enablement Acceptance

## Repository acceptance

The production-enablement implementation is accepted when all repository-controlled checks pass:

- synthetic-core acceptance remains unchanged;
- application lint, typecheck, tests, and production build pass;
- complete Supabase migration rebuild passes;
- all pgTAP suites pass;
- database lint passes;
- generated database-contract drift check passes;
- dependency-resolution drift check passes;
- deployment control tests pass;
- readiness route builds and exposes no secrets;
- synthetic provider/carrier adapters are rejected in `pilot` and `production`;
- production evidence template and launch runbook are committed;
- external unresolved gates remain explicitly blocked rather than guessed.

Repository verdict: `PRODUCTION_ENABLEMENT_REPO_READY`.

## Pilot acceptance

A specific deployment may be marked `PILOT_READY` only when external evidence exists for all live gates and:

- readiness returns HTTP 200 in `pilot`;
- at least one non-synthetic provider binding is certified and kill-switch tested;
- at least one non-synthetic carrier program is certified and kill-switch tested;
- exact approved notice set/version/hash is deployed;
- retention/storage rules are approved and implemented for the enabled data classes;
- incident owner and escalation path are active;
- authorized test cases reconcile end to end;
- telemetry contains no prohibited sensitive plaintext;
- rollback has been exercised.

Until then verdict is `PILOT_BLOCKED_EXTERNAL_EVIDENCE`.

## Production acceptance

A deployment may be marked `PRODUCTION_READY` only after `PILOT_READY` plus an explicit production launch decision by the operating authority and all required legal/security/carrier/provider reviewers.

No repository test can independently produce `PRODUCTION_READY` because the final authority is external to the codebase.
