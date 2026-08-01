# Encounter fixture format (appendix)

**Status:** `LOOP_READY` *(gauntlet C6: 89/88 PASS)*  
**Pillar ID:** P5 support  
**Authority chain:** `bridge/encounter_builder.gd` · `data/definitions/unit_placement.gd` · `tests/bridge_test_runner.gd` · `docs/design/enemy-design.md`

## Goal

JSON schema for handcrafted puzzle encounters. **PLANNED** loader maps fixture → `EncounterBuilder.build_from_player_grid` → `EncounterData` → headless `Simulator` smoke.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Bridge smoke (today) | `godot --headless --path <repo> --script res://tests/bridge_test_runner.gd` PASS | — |
| Fixture loader | `PLANNED — tests/encounter_fixture_test.gd` loads `tests/fixtures/encounters/*.json` | — |
| Schema reference | Bridge inputs + metadata fields (`id`) documented in encoding table | — |

## Non-goals

- Procedural endless mode
- Full campaign editor UI
- `intent` / `win_condition` in v1 loader (deferred to enemy data — see `enemy-design.md`)

## Human-only worksheet

N/A

## Schema (`EncounterBuilder.build_from_player_grid`)

Bridge today accepts programmatic types only. **PLANNED** JSON loader must map as follows:

| Fixture field | JSON type | Bridge type | Loader rule |
|---------------|-----------|-------------|-------------|
| `id` | string | *(metadata only)* | Fixture filename / test label; **not** passed to `EncounterBuilder` |
| `grid.width` / `grid.height` | number | `PlayerGrid` | `PlayerGrid.new(w, h)` — unfilled cells default `TileId.Type.GRASS` (`scripts/player_grid.gd`); `EncounterBuilder` sets `EncounterData.default_terrain` to plain |
| `blocked_cells` | `[[x,y], …]` | `Dictionary` | Each pair → `Vector2i(x, y): true`. `EncounterBuilder` upgrades blocked **walkable** grass to `wall` terrain (`bridge/encounter_builder.gd` L24–27) |
| `player_spawns[]` / `enemy_spawns[]` | object | `UnitPlacement` | `unit` string → `DataLibrary.get_unit(StringName(unit))`; `coord` `[x,y]` → `Vector2i(x, y)` |
| `unit` (spawn) | string | `UnitData` | Must match `UnitData.id` in `DataLibrary` (e.g. `knight`, `training_dummy`) |

### Example fixture

`tests/fixtures/encounters/puzzle_001.json`:

```json
{
  "id": "puzzle_001",
  "grid": {"width": 8, "height": 8},
  "blocked_cells": [[2, 3]],
  "player_spawns": [{"unit": "knight", "coord": [1, 1]}],
  "enemy_spawns": [{"unit": "training_dummy", "coord": [5, 5]}]
}
```

### Loader sketch (PLANNED)

```gdscript
# tests/encounter_fixture_loader.gd (not yet on disk)
var data := JSON.parse_string(FileAccess.get_file_as_string(path))
# data.id is metadata only — not passed to EncounterBuilder
var grid := PlayerGrid.new(data.grid.width, data.grid.height)
var blocked: Dictionary = {}
for pair: Array in data.blocked_cells:
    blocked[Vector2i(pair[0], pair[1])] = true
var player_spawns: Array[UnitPlacement] = []
for row: Dictionary in data.player_spawns:
    var p := UnitPlacement.new()
    p.unit = DataLibrary.get_unit(StringName(row.unit))
    p.coord = Vector2i(row.coord[0], row.coord[1])
    player_spawns.append(p)
# … enemy_spawns same pattern …
return EncounterBuilder.build_from_player_grid(grid, blocked, player_spawns, enemy_spawns)
```

`intent` / `win_condition` JSON fields: **PLANNED** — not consumed by `EncounterBuilder.build_from_player_grid` today.

## Decomposition

1. Document schema (this file) — **done**
2. Reference fixture on disk — `tests/fixtures/encounters/puzzle_001.json`
3. `tests/encounter_fixture_test.gd` — PLANNED
4. P5 `enemy-design.md` references fixtures

## Builder playbook

1. Author JSON per encoding table above.
2. Implement loader per sketch; assert `EncounterData.grid_size` matches fixture.
3. Wire `tests/encounter_fixture_test.gd` into bridge smoke when loader lands.

## Critic playbook

```powershell
.\scripts\lint_design_doc.ps1
Test-Path bridge/encounter_builder.gd
Test-Path tests/fixtures/encounters/puzzle_001.json
```

## Gauntlet stub

```text
GOAL: JSON encoding table + reference fixture aligned to EncounterBuilder (loader PLANNED)
BAR: lint PASS; bridge/encounter_builder.gd + puzzle_001.json exist
PASS_THRESHOLD: 88
RULES: global-systems-first.mdc
ARTIFACT: this file, tests/fixtures/encounters/puzzle_001.json, bridge/encounter_builder.gd
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| Fixture JSON | `EncounterData` via `EncounterBuilder.build_from_player_grid` | `BoardFactory.build_from_encounter` → `Simulator` (`enemy-design.md`) |

## Exit criteria

- [x] Bridge inputs + metadata fields documented (encoding table; `id` is metadata-only)
- [x] At least one fixture file in `tests/fixtures/encounters/` (`puzzle_001.json`)
- [ ] `tests/encounter_fixture_test.gd` PASS (when loader implemented)

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
