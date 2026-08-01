# Mass sim balance (appendix)

**Status:** `DRAFT`  
**Authority chain:** `core/batch/mass_sim_*.gd` · `tests/run_mass_sim_test.gd` · `tests/captures/README.md`

## Goal

When and how to run mass sim for class/enemy balance signals during P6 — not for planning/commit QA.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Smoke | `godot --headless --script res://tests/run_mass_sim_test.gd` | — |
| Interpretation | `PLANNED — tests/captures/mass_sim_interpretation.json` after run | Balance taste |
| Epoch honesty | `RULES_REVISION` bump when rules change | — |

## Non-goals

- Replacing planning QA gate
- Autobattler UI (Phase 15) — triage only

## Human-only worksheet

N/A

## When to run

| Trigger | Command |
|---------|---------|
| After class batch complete | `run_mass_sim_test.gd` |
| After enemy archetype batch | Same + compare interpretation |
| Rules epoch change | Bump `mass_sim_constants.gd` `RULES_REVISION` |

```text
godot --headless --path <repo> --script res://tests/run_mass_sim_test.gd
```

Optional capture: `.\scripts\capture_mass_sim_dashboard.ps1`

## Decomposition

1. Document triggers (this file)
2. P6 critic optional BAR includes mass sim
3. Triage/autobattler deferred Phase 15

## Builder playbook

1. Run smoke after balance-relevant data changes.
2. Archive interpretation to `tests/captures/`.
3. Do not use mass sim as planning parity proof.

## Critic playbook

```powershell
# Optional secondary BAR for P6 only
godot --headless --script res://tests/run_mass_sim_test.gd
```

## Gauntlet stub

```text
GOAL: Mass sim smoke PASS after class slice
BAR: run_mass_sim_test.gd exit 0
PASS_THRESHOLD: 88
RULES: qa-after-gameplay-changes.mdc
ARTIFACT: this file, lint stdout, tests/run_mass_sim_test.gd path
```

## Exit criteria

- [ ] Triggers documented in P6
- [ ] Interpretation path matches `tests/captures/README.md`

## Doc polish scorecard

*(Critic fills — do not self-grade.)*

| Dimension | /10 |
|-----------|-----|
| Covers scope | |
| Machine bars | |
| No duplication | |
| Agent-executable | |
| Human boundaries | |
| Sequencing | |
| Tooling I/O | |
| Loop-polishable | |
