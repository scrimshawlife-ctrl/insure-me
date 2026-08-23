# Canonical Scenario Runner

Status: `CANONICAL_SCENARIO_RUNNER_V1`

The runner executes the accepted canonical synthetic datasets through the accepted synthetic provider/carrier harness and returns deterministic machine-readable comparison reports.

## Modes

- Full suite: execute all canonical scenarios.
- Single scenario: select one canonical `datasetId`.

## Output contract

Each run returns `canonical-scenario-report-v1` with:

- total scenario count
- passed count
- failed count
- per-scenario observed runtime state
- exact expected-vs-observed deltas

Unknown scenario IDs fail closed with `CANONICAL_SCENARIO_NOT_FOUND:<id>`.

## Invariants

- The execution engine does not consume the canonical `expected` section.
- The runner consumes `expected` only after execution to calculate deltas.
- A passing report has zero deltas.
- Scenario meaning is owned by the canonical dataset version, not by the runner.
- Synthetic data and runner output are forbidden as production customer data.

## CI usage

The contract suite executes the full 12-scenario report and a single-scenario selection case. Any non-zero delta is a test failure.
