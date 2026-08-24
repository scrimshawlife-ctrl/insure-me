# Production Launch Runbook

## Purpose

This runbook is the operator procedure for moving Insure Me from synthetic verification to a controlled pilot and then to production. It is not authority to launch. External approvals remain mandatory.

## Preconditions

Before any live-stage deployment:

- PR #1 synthetic-core acceptance remains green at its sealed SHA;
- the production-enablement branch/PR is green;
- `production-evidence.yaml` contains references for every resolved external gate;
- provider and carrier adapters are non-synthetic and independently certified;
- all secrets are configured in the deployment secret store, not the repository;
- database backups and rollback procedures are verified;
- monitoring proves `reliability-v1` SLI computation and the selected plans can meet its RPO/RTO targets;
- incident-response ownership is assigned.

## Environment mapping

Set these server-side variables for a live stage:

- `DEPLOYMENT_STAGE=pilot` or `production`
- `PUBLIC_BASE_URL`
- `DEPLOYMENT_AUTHORITY_REF`
- `LEGAL_NOTICE_APPROVAL_REF`
- `DATA_RETENTION_APPROVAL_REF`
- `FCRA_ROLE_APPROVAL_REF`
- `PRIVACY_ROLE_APPROVAL_REF`
- `SECURITY_REVIEW_REF`
- `INCIDENT_RESPONSE_OWNER`
- `LIVE_PROVIDER_BINDINGS_VERIFIED=true`
- `LIVE_CARRIER_PROGRAMS_VERIFIED=true`

Existing Supabase and identity-protection secrets remain required by the runtime paths that use them.

## Gate test

### Expected blocked state

Before completing the evidence set, deploy with `DEPLOYMENT_STAGE=pilot`.

Expected result:

`GET /api/health/readiness` → HTTP `503` with explicit blockers.

A `200` response at this point is a release defect.

### Expected allowed state

After all evidence references and live binding assertions are configured:

`GET /api/health/readiness` → HTTP `200`, stage `pilot`, blocker list empty.

This confirms configuration completeness only. It does not replace provider/carrier certification or launch approval.

## Pilot sequence

1. Keep public consumer traffic disabled.
2. Enable one approved provider capability.
3. Run authorized test identities/cases only.
4. Confirm request creation, claim, execution, settlement, provenance, policy classification, and retry behavior.
5. Reconcile provider-side request IDs with local ExternalRequest/ExternalReport records.
6. Enable one approved carrier program.
7. Project RatingInputs and verify mapping against the certified test fixture.
8. Submit an authorized non-consumer test case.
9. Reconcile carrier request/decision IDs with local CarrierSubmission/CarrierDecision records.
10. Exercise provider and carrier kill switches.
11. Verify no plaintext sensitive identifiers or raw report payloads appear in application logs.
12. Review authorization failures, retry counts, queue age, error rate, and latency.
13. Record pilot evidence and decision reference.
14. Only then permit limited consumer traffic under an explicit external authorization.

## Rollback

Rollback triggers include:

- readiness becomes blocked;
- provider/career certification mismatch;
- incorrect notice version;
- security incident or suspected secret exposure;
- unexpected PII in telemetry;
- reconciliation mismatch;
- repeated retry exhaustion;
- policy/retention ambiguity discovered after deployment.

Rollback order:

1. disable affected carrier/provider via kill switch;
2. stop new live intake if scope is unclear;
3. preserve audit evidence;
4. restore the last verified application deployment if application change caused the issue;
5. do not reverse applied database migrations destructively without a reviewed migration-specific rollback;
6. notify the incident owner and external operating authority;
7. keep `DEPLOYMENT_STAGE` live only if readiness remains valid and the incident scope permits it; otherwise restore a blocked state.

## Production promotion

Pilot → production requires a new launch decision. Promotion is not automatic after successful tests.

Before setting `DEPLOYMENT_STAGE=production`:

- evidence manifest is current;
- legal notice hash/version matches deployed copy;
- retention policy is configured operationally;
- all live providers and carriers remain certified;
- security review has no unresolved launch blocker;
- incident/on-call ownership is active;
- rollback has been exercised;
- production decision reference is recorded.

After promotion, verify readiness immediately and run one controlled smoke transaction before expanding traffic.

## Reliability gate

Before pilot traffic, operators must attach evidence that:

- core availability, core latency, async claim time, and audit atomicity are measured with the canonical eligibility rules;
- 50%, 75%, and 100% error-budget alerts route to the named service and incident owners;
- PostgreSQL point-in-time recovery and encrypted backups support a five-minute RPO;
- the isolated T902 drill restores PostgreSQL, queues, identity access, and the exact application artifact within four hours, with the application artifact restored within one hour;
- restoration follows the canonical dependency order and includes integrity, tenant-isolation, policy-version, idempotency, and audit checks;
- provider/carrier bindings remain disabled until independently revalidated after recovery.

Missing or stale evidence keeps production readiness `UNVERIFIED`; an endpoint being reachable is not sufficient recovery proof.
