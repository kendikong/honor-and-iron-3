# Enemy design (P5)

**Status:** `DRAFT`  
**Pillar ID:** P5  
**Authority chain:** `class_abilities.txt` (enemies) · `docs/design/appendices/encounter-fixture-format.md` · `bridge/encounter_builder.gd`

## Goal

Handcrafted **puzzle encounters**: public intents, board-state weaknesses, fixture-driven regression — not DPS races.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Fixture → sim | `tests/bridge_test_runner.gd` PASS | Puzzle fun |
| Intent display | Planning QA if enemy affects preview | Difficulty curve |

## Non-goals

- RNG combat
- Full bestiary before Knight LOCK
- Boss cinematics

## Human-only worksheet

| Decision | Your answer |
|----------|-------------|
| Target solve rate (training dummies) | |
| Boss identity pillars | |

## Decomposition

1. Fixture format LOCK
2. 3 tutorial puzzles
3. Intent grammar doc in data

## Builder playbook

1. Author fixture JSON per appendix.
2. Run bridge + sim smoke.
3. F5 intent readability.

## Critic playbook

```powershell
.\scripts\run_regression_tests.ps1
```

## Gauntlet stub

```text
GOAL: Encounter puzzle_<id> loads and sim smoke PASS
BAR: bridge_test_runner + fixture path
PASS_THRESHOLD: 88
RULES: skill-global-rules.mdc, qa-after-gameplay-changes.mdc
ARTIFACT: this file, lint stdout, appendices/encounter-fixture-format.md
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| Fixture JSON | Encounter in tactical skirmish | Run loop (P4) |

## Exit criteria

- [ ] ≥3 fixtures with sim smoke
- [ ] Intents visible in planning phase

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
