# Encounter fixture format (appendix)

**Status:** `DRAFT`  
**Pillar ID:** P5 support  
**Authority chain:** `bridge/encounter_builder.gd` · `docs/design/enemy-design.md`

## Goal

JSON/schema for handcrafted puzzle encounters loadable through `EncounterBuilder` → headless `Simulator` smoke.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Schema doc | Fields listed below | — |
| Loader | `PLANNED — tests/encounter_fixture_test.gd` | Puzzle quality |

## Non-goals

- Procedural endless mode
- Full campaign editor UI

## Human-only worksheet

N/A

## Schema (stub)

```json
{
  "id": "puzzle_001",
  "player_grid_seed": 12345,
  "blocked_cells": [[2, 3]],
  "units": [
    {"team": "player", "class": "knight", "cell": [1, 1]},
    {"team": "enemy", "archetype": "tank", "cell": [5, 5], "intent": "advance"}
  ],
  "win_condition": "eliminate_enemies"
}
```

## Decomposition

1. Document schema (this file)
2. Fixture loader test
3. P5 enemy-design references fixtures

## Builder playbook

1. Align fields with `EncounterBuilder.build_from_player_grid` inputs.
2. Add `tests/encounter_fixture_test.gd` when implementing loader.

## Critic playbook

```powershell
.\scripts\lint_design_doc.ps1
```

## Gauntlet stub

```text
GOAL: Schema + test loads fixture to sim
BAR: bridge_test_runner or encounter_fixture_test PASS
PASS_THRESHOLD: 88
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| Fixture JSON | `BoardState` | `enemy-design.md` gauntlets |

## Exit criteria

- [ ] Schema fields match bridge API
- [ ] At least one fixture file in `tests/fixtures/encounters/` (when implemented)

## Doc polish scorecard

| Dimension | /10 |
|-----------|-----|
| Covers scope | 8 |
| Machine bars | 7 |
| No duplication | 9 |
| Agent-executable | 8 |
| Human boundaries | 8 |
| Sequencing | 8 |
| Tooling I/O | 8 |
| Loop-polishable | 8 |
