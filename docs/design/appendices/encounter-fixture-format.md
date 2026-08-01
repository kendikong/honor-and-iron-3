# Encounter fixture format (appendix)

**Status:** `DRAFT`  
**Pillar ID:** P5 support  
**Authority chain:** `bridge/encounter_builder.gd` · `tests/bridge_test_runner.gd` · `docs/design/enemy-design.md`

## Goal

JSON/schema for handcrafted puzzle encounters — **PLANNED** loader through `EncounterBuilder` → headless `Simulator` smoke.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Loader smoke | `PLANNED — tests/encounter_fixture_test.gd` after JSON loader lands | — |
| Schema reference | `bridge/encounter_builder.gd` API (programmatic grid today) | — |

## Non-goals

- Procedural endless mode
- Full campaign editor UI

## Human-only worksheet

N/A

## Schema (stub — `EncounterBuilder.build_from_player_grid`)

`PLANNED` JSON loader. Bridge today: `PlayerGrid` + `blocked_cells: Dictionary` + `Array[UnitPlacement]`.

| Fixture field | Bridge type |
|---------------|-------------|
| `grid.width` / `grid.height` | `PlayerGrid` size |
| `blocked_cells` | `Dictionary` (cell → blocked) |
| `player_spawns[]` / `enemy_spawns[]` | `UnitPlacement` (`unit` + `coord`) |

```json
{
  "id": "puzzle_001",
  "grid": {"width": 8, "height": 8},
  "blocked_cells": {"2,3": true},
  "player_spawns": [{"unit_id": "knight", "coord": [1, 1]}],
  "enemy_spawns": [{"unit_id": "tank", "coord": [5, 5], "intent": "advance"}],
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
GOAL: JSON schema documented; loader + fixture files are PLANNED infrastructure
BAR: lint PASS; bridge/encounter_builder.gd exists; do NOT claim JSON loader exists yet
PASS_THRESHOLD: 88
RULES: global-systems-first.mdc
ARTIFACT: this file, bridge/encounter_builder.gd
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| Fixture JSON | `BoardState` | `enemy-design.md` gauntlets |

## Exit criteria

- [ ] Schema fields match bridge API
- [ ] At least one fixture file in `tests/fixtures/encounters/` (when implemented)

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
