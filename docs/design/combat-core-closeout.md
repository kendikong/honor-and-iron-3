# Combat core closeout (P2)

**Status:** `DRAFT`  
**Pillar ID:** P2  
**Authority chain:** `docs/TACTICAL_COMBAT_PARITY_PLAN.md` (Phases 10–14) · `IMPLEMENTATION_STATUS.md` · `presentation/combat_planning_input.gd`

## Goal

Close tactical SP combat parity (Phases 10–14) using **parity plan as sole phase detail** — this doc only lists gauntlet pieces and QA bars.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Sim + bridge | `.\scripts\run_regression_tests.ps1` PASS | — |
| Planning path | `.\scripts\run_planning_qa_gate.ps1` PASS | F5 parity checklists Ph 10–14 |
| Intent single-owner | Grep: one `_recompute_intent_units` | — |

## Non-goals

See parity plan §Explicit deferrals (Phase 15+). Do not duplicate that table here.

## Decomposition (gauntlet pieces)

| Piece | Parity anchor | BAR |
|-------|---------------|-----|
| P2-ph10 | Phase 10 deliverables | regression PASS |
| P2-ph11 | Phase 11 | planning QA PASS |
| P2-ph12 | Phase 12 | planning QA PASS |
| P2-ph13 | Phase 13 | planning QA PASS |
| P2-ph14 | Phase 14 Knight re-gate | both QA scripts PASS |

## Builder playbook

1. Read parity plan phase deliverable tables for current phase only.
2. Extend shared modules — no `board_view` copy-paste >20 lines.
3. Run regression + planning QA after each phase slice.

## Critic playbook

```powershell
.\scripts\lint_design_doc.ps1
.\scripts\run_regression_tests.ps1
.\scripts\run_planning_qa_gate.ps1
```

## Gauntlet stub

```text
GOAL: Phase N deliverables from parity plan + QA PASS
BAR: regression + planning QA
PASS_THRESHOLD: 88
RULES: move-preview-intent-truth.mdc, global-systems-first.mdc
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| `board_view.gd` (reference) | Shared formatters/intent state | Tactical stack |
| QA scripts | PASS/FAIL | Phase close |

## Exit criteria

- [ ] Phase 14 exit criteria in parity plan checked
- [ ] `IMPLEMENTATION_STATUS.md` Phase 9 FAIL documented; Phase 10+ progress rows
- [ ] No SP reliance on `board_view.gd`

## Doc polish scorecard

*(Critic fills — do not self-grade.)*
