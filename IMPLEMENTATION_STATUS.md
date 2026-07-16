# Implementation Status — Honor & Iron 3

**Current phase:** 2 (skirmish generation)  
**Last updated:** 2026-07-16

---

## Phase 0 — Bootstrap ✅

**Closed:** commit `213043474` — Bootstrap Phase 0: honor-and-iron-3 merge foundation with bridge stubs and map camera.

### Deliverables
- [x] Copy `mana-seed-test` → `honor-and-iron-3` (exclude `.godot`, `.git`)
- [x] Port `honor-and-iron`: `core/`, `data/`, `presentation/`, `ui/`, `scenes/`, `tests/`, `.agents/`, `class_abilities.txt`
- [x] Merged `project.godot` (autoloads from both projects; main scene `MainMenu.tscn`)
- [x] `bridge/` stubs: `TacticalConstants`, `TileIdToTerrain`, `WalkabilityBaker`, `EncounterBuilder`, `SkirmishGenerator`, `UnitVisualFactory`
- [x] `presentation/map_camera_controller.gd` — middle-mouse pan + Ctrl+scroll zoom
- [x] `test_map.gd` wired to `MapCameraController`
- [x] `tests/bridge_test_runner.gd` smoke test
- [x] `IMPLEMENTATION_PLAN.md`, `.gitignore`

### Phase 0 Audit (iteration 1 — 2026-07-15)

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Godot editor not run on agent PATH — runtime verify pending | Low | Deferred — user F5 |
| 2 | `SettingsManager` + `GameSettings` duplicate display prefs (two cfg files) | Low | Deferred — unify Phase 7 |

**Final issue count:** 2 (pass)  
**Audit result:** **PASS**

---

## Phase 1 — Unified constants & bridge ✅

**Closed:** commit `cc938b765` — Phase 1 bridge tests: WalkabilityBaker, encounter pipeline, headless Simulator smoke.

### Deliverables
- [x] `TileIdToTerrain` complete mapping (impassable logical tiles → wall)
- [x] `WalkabilityBaker` unit tests (grid-only, null TileMapLayers)
- [x] `EncounterBuilder` blocked-cell → wall override test
- [x] Headless pipeline: `SkirmishGenerator` → `WalkabilityBaker` → `EncounterBuilder` → `BoardFactory` → `Simulator`
- [x] `tests/bridge_test.gd` CLI runner (`godot --headless --script res://tests/bridge_test.gd`)

### Phase 1 Audit (iteration 1 — 2026-07-16)

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Tree/scatter blocking untested headlessly (null layers only) | Low | Deferred — Phase 2/3 with real TileMapLayers |
| 2 | Godot headless not run on agent PATH — bridge_test pending user CLI | Low | Deferred — user run |

**Final issue count:** 2 (pass)  
**Audit result:** **PASS** (pending user `bridge_test.gd` + `sim_test.gd` CLI)

### Next
- Phase 2: `SkirmishGenerator` spawn bands + walkable spawn guarantee (10 seeds × 7 sizes)

---

## User decisions (locked)

| Item | Choice |
|------|--------|
| MVP | SP Knight vs small squad |
| Aim mode | H&I vector class icon |
| Ambient effects | Options toggle, default on |
| Extras v1 | Compendium, online co-op, autobattler |
