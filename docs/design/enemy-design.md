# Enemy design (P5)

**Status:** `DRAFT` *(doc gauntlet PASS 88/88 — worksheet gates LOOP_READY)*  
**Pillar ID:** P5  
**Authority chain:** `class_abilities.txt` (enemies) · `docs/design/appendices/encounter-fixture-format.md` · `bridge/encounter_builder.gd` · `tests/bridge_test_runner.gd`

## Goal

Handcrafted **puzzle encounters**: public intents, board-state weaknesses, fixture-driven regression — not DPS races.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| **Bridge smoke (today)** | `godot --headless --path <repo> --script res://tests/bridge_test_runner.gd` PASS | — |
| **Fixture JSON puzzles** (separate piece) | `PLANNED — tests/encounter_fixture_test.gd` loads `tests/fixtures/encounters/puzzle_001.json` | Puzzle fun |
| Intent display (when enemies affect planning) | `.\scripts\run_planning_qa_gate.ps1` PASS | Difficulty curve |

Doc gauntlet BAR = lint + path existence for bridge smoke and appendix schema — **not** full regression suite.

## Non-goals

- RNG combat
- Full bestiary before Knight LOCK
- Boss cinematics

## Human-only worksheet

| Decision | Your answer |
|----------|-------------|
| Target solve rate (training dummies) | |
| Boss identity pillars | |

**Human gate rule:** Doc gauntlet BAR = `lint_design_doc.ps1` + cited paths on disk. Empty worksheet is expected in `DRAFT` and must **not** FAIL critic rounds. Worksheet completeness is owner-only and gates **`LOOP_READY`** promotion only — not doc-critic PASS. Unchecked implementation exit criteria are **PLANNED** and must not FAIL doc critic.

## Decomposition

1. Fixture format LOCK — `appendices/encounter-fixture-format.md` + `tests/fixtures/encounters/puzzle_001.json`
2. 3 tutorial puzzles — PLANNED after JSON loader
3. Intent grammar (data-driven, no per-enemy code branches):

| Intent | Meaning | Data owner |
|--------|---------|------------|
| `advance` | Move toward player | Enemy `UnitData` / spawn meta `PLANNED` |
| `hold` | Stay unless pushed | Enemy `UnitData` `PLANNED` |
| `attack` | Focus damage tile | Enemy `UnitData` `PLANNED` |

Fixture `intent` field: **PLANNED** until loader + enemy intent data land (`encounter-fixture-format.md`).

## Builder playbook

1. Author fixture JSON per appendix encoding table.
2. Run bridge smoke (`bridge_test_runner.gd`).
3. When loader exists: add `encounter_fixture_test.gd` and sim smoke per puzzle.
4. F5 intent readability when enemies affect planning preview.

## Critic playbook

```powershell
.\scripts\lint_design_doc.ps1
Test-Path tests/bridge_test_runner.gd
Test-Path docs/design/appendices/encounter-fixture-format.md
Test-Path tests/fixtures/encounters/puzzle_001.json
```

## Gauntlet stub

```text
GOAL: P5 pillar doc — bridge smoke vs fixture loader clearly split; intent grammar documented
BAR: lint PASS; bridge_test_runner.gd + encounter appendix + puzzle_001.json exist; empty worksheet must not FAIL
PASS_THRESHOLD: 88
RULES: skill-global-rules.mdc, global-systems-first.mdc
ARTIFACT: this file, appendices/encounter-fixture-format.md, lint stdout
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| Fixture JSON | `EncounterData` → `BoardState` | Run loop (P4), `Simulator` smoke |

## Exit criteria (implementation — PLANNED)

- [ ] ≥3 fixtures with sim smoke (`encounter_fixture_test.gd`)
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
