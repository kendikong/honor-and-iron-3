# Mass sim balance (appendix)

**Status:** `LOOP_READY` *(gauntlet C5: 88/88 PASS)*  
**Authority chain:** `core/batch/mass_sim_*.gd` · `tests/run_mass_sim_test.gd` · `tests/captures/README.md`

## Goal

When and how to run mass sim for class/enemy balance signals during P6 — not for planning/commit QA.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Smoke | `godot --headless --script res://tests/run_mass_sim_test.gd` | — |
| Interpretation | `tests/captures/mass_sim_interpretation.json` (generated; gitignored) | Balance taste |
| Epoch honesty | `RULES_REVISION` bump when rules change | — |

## Non-goals

- Replacing planning QA gate
- Autobattler UI (Phase 15) — triage only

## Human-only worksheet

N/A

## P6 balance loop (owner + agent)

| Step | Action | Path / command |
|------|--------|----------------|
| 1 | Configure skirmish | Mass Sim dashboard / `core/batch/mass_sim_skirmish_setup.gd` |
| 2 | New Epoch before rule change | `core/batch/mass_sim_constants.gd` `RULES_REVISION` bump |
| 3 | Run queue | `godot --headless --script res://tests/run_mass_sim_test.gd` |
| 4 | Interpret export | `tests/captures/mass_sim_interpretation.json` (see `tests/captures/README.md`) |

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

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| `core/batch/mass_sim_constants.gd` | `RULES_REVISION` epoch | Interpretation compare |
| Skirmish setup | Battle queue | `run_mass_sim_test.gd` |
| Run output | `tests/captures/mass_sim_interpretation.json` | P6 balance review |

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
GOAL: Mass sim appendix doc — triggers + P6 loop paths
BAR: lint PASS; Test-Path run_mass_sim_test.gd + captures/README.md
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
