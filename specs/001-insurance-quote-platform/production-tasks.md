# Production Enablement Tasks

## Repository-controlled tasks

- [x] Preserve `SYNTHETIC_CORE_ACCEPTED` as the immutable base boundary.
- [x] Create independent `runtime/production-enablement` branch.
- [x] Define `synthetic` / `pilot` / `production` deployment stages.
- [x] Add machine-readable readiness assessment.
- [x] Add HTTP readiness endpoint with fail-closed live behavior.
- [x] Reject synthetic provider adapters in live stages.
- [x] Reject synthetic carrier adapters in live stages.
- [x] Add tests for live evidence and synthetic-adapter rejection.
- [x] Add production evidence manifest template.
- [x] Add production launch/rollback runbook.
- [x] Define repository, pilot, and production acceptance states.
- [x] Embed the canonical dependency lock snapshot in the repository and reconstruct it deterministically in CI.
- [x] Verify the reconstructed lock SHA before use.
- [x] Install application and database dependencies with `--frozen-lockfile` from the same canonical artifact.
- [x] Run full application CI and repair implementation defects.
- [x] Rebuild the complete Supabase migration chain.
- [x] Pass all 130 pgTAP assertions across 10 database suites.
- [x] Pass database lint.
- [x] Generate and verify the pinned public database-contract hash.
- [x] Open production-enablement PR against the sealed synthetic-core branch.
- [x] Mark repository verdict `PRODUCTION_ENABLEMENT_REPO_READY` after green CI.

### Repository acceptance provenance

- Verdict: `PRODUCTION_ENABLEMENT_REPO_READY`
- Acceptance head before this ledger-only seal: `cec3da7ad25d304f61382a9e4110100383f81506`
- Acceptance CI: `32628441498`
- Dependency snapshot SHA-256: `bc16dd4902b6bd7c438238e9019d0751079d9929c3810eec3876603d00042886`
- Application verification: PASS
- Complete database migration rebuild: PASS
- pgTAP: `130/130 PASS`
- Database lint: PASS
- Generated database contract verification: PASS

## External enablement tasks

These tasks require real external facts and cannot be completed by code alone.

- [ ] Q-001 identify operating licensed entity and deployment authority.
- [ ] Q-002 approve data-storage boundaries.
- [ ] Q-003 select and certify first live carrier handoff.
- [ ] Q-004 contract/select live data providers.
- [ ] Q-005 resolve FCRA report-user/adverse-action ownership.
- [ ] Q-006 approve notice ownership and exact live copy.
- [ ] Q-007 approve retention periods by data class.
- [ ] Q-008 resolve privacy-role allocation.
- [ ] Q-009 complete launch-time California legal/regulatory review.
- [ ] Q-010 approve production branding/third-party marks.
- [ ] Record provider certification evidence and kill-switch test.
- [ ] Record carrier certification evidence and kill-switch test.
- [ ] Run authorized pilot reconciliation.
- [ ] Record explicit pilot launch decision.
- [ ] Record explicit production launch decision.

## State rule

Repository-controlled implementation is complete at the current specification boundary: `PRODUCTION_ENABLEMENT_REPO_READY`.

External state remains:

- `PILOT_BLOCKED_EXTERNAL_EVIDENCE`
- `PRODUCTION_BLOCKED_EXTERNAL_AUTHORITY`

No repository change, automated test, model output, or deployment script may mark an external task complete without evidence from the authorized real-world source.
