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
- [ ] Run full CI and repair any implementation defects.
- [ ] Open production-enablement PR against the sealed synthetic-core branch.
- [ ] Mark repository verdict `PRODUCTION_ENABLEMENT_REPO_READY` after green CI.

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

Repository completion changes the verdict from `IMPLEMENTATION_ACTIVE` to `PRODUCTION_ENABLEMENT_REPO_READY`. It MUST NOT change external tasks to complete without evidence.
