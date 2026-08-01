# Verification matrix (P9)

**Status:** `DRAFT`  
**Pillar ID:** P9  
**Authority chain:** `docs/design/REMAINING_WORK_MAP.md` · `docs/PLANNING_QA_GATE.md` · `docs/design/00-remaining-work-suite-plan.md`

## Goal

Single table: for each work domain, the **machine bar**, **secondary check**, and **human gate** — every path exists on disk or is marked `PLANNED`.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| This matrix | `.\scripts\lint_design_doc.ps1` PASS | — |
| Each row | `Test-Path` on primary bar | Pillar doc agrees |

## Non-goals

- Duplicating Tier 3 planning QA rules (link only)
- Inventing new global gameplay rules

## Human-only worksheet

N/A

## Matrix

| Domain | Pillar | Primary machine bar | Secondary | Human gate |
|--------|--------|---------------------|-----------|------------|
| Combat closeout | P2 | `.\scripts\run_regression_tests.ps1` | `.\scripts\run_planning_qa_gate.ps1` | F5 Ph 10–14 parity lists |
| Knight template | P3 | `.\scripts\run_planning_qa_gate.ps1` | `tests/planning_skill_scenarios_test.gd` | Checklist 7 phases |
| Roguelike run | P4 | `PLANNED — tests/run_state_test.gd` | — | P4 worksheet |
| Enemy design | P5 | `tests/bridge_test_runner.gd` | `docs/design/appendices/encounter-fixture-format.md` | Puzzle fun |
| Class rollout | P6 | `.\scripts\run_planning_qa_gate.ps1` | `tests/run_mass_sim_test.gd` | Balance taste |
| World / map | P7 | `docs/asset_manifest.md` | `PLANNED — F5 compositor gate (phase-audit.mdc)` | P7 worksheet |
| Presentation | P8 | `PLANNED — Sfx event map (P8 doc)` | `docs/design/presentation-audio-ui.md` | Typography/layout |
| Triage / autobattler | W4 appendix | `tests/run_mass_sim_test.gd` | `docs/design/appendices/mass-sim-balance.md` | Owner |
| Design docs | meta | `scripts/lint_design_doc.ps1` | `gauntlet-critic` ≥88/90 | Owner LOCK |

**Mass sim CLI:**

```text
godot --headless --path <repo> --script res://tests/run_mass_sim_test.gd
```

## Decomposition

1. Keep in sync with `REMAINING_WORK_MAP.md` primary commands
2. Update when new test files land

## Builder playbook

1. Grep repo for script paths before adding rows.
2. Mark `PLANNED` when path does not exist yet.

## Critic playbook

```powershell
.\scripts\lint_design_doc.ps1
```

Verify each primary bar path with filesystem check.

## Gauntlet stub

```text
GOAL: Matrix rows cite real paths or PLANNED
BAR: lint PASS; Test-Path each primary bar
PASS_THRESHOLD: 88
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| Pillar specs | Row updates | Gauntlet BAR handoffs |
| New tests on disk | Row path updates | This file |

## Exit criteria

- [x] No row cites missing path without `PLANNED`
- [x] Matches suite plan inline matrix (triage: test + `mass-sim-balance.md`)
- [x] Linked from `README.md`

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
