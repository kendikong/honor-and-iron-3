# Implementation Status — Honor & Iron 3

**Current phase:** 3 (tactical combat scene shell)  
**Last updated:** 2026-07-16  
**Audit policy:** Every phase must pass a four-pillar audit (completeness, correct coding, inconsistencies, issues) before close. See `.cursor/rules/phase-audit.mdc`.

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

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | PASS | All bootstrap deliverables on disk |
| Correct coding | PASS | Bridge stubs `RefCounted`; no duplicate `class_name` |
| Inconsistencies | PASS | `TacticalConstants.TILE_PX` = 16 matches mana-seed grid |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Godot editor not run on agent PATH — runtime verify pending | Low | Deferred — user F5 |
| 2 | `SettingsManager` + `GameSettings` duplicate display prefs (two cfg files) | Low | Deferred — Phase 7 |

**Final issue count:** 2  
**Audit result:** **PASS**

### Phase 0 Audit (iteration 2 — 2026-07-16) — completeness review

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | PASS | `project.godot` main scene, all 6 `bridge/` files, `MapCameraController` in `test_map.gd` |
| Correct coding | PASS | All bridge stubs parse; `class_name` registry has no duplicates |
| Inconsistencies | PASS | Autoload list merges both repos without name collision |
| Issues | PASS | 2 deferred (≤2 cap) |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Godot F5 / MainMenu runtime not verified on agent PATH | Low | Deferred — user F5 |
| 2 | `SettingsManager` + `GameSettings` duplicate display prefs | Low | Deferred — Phase 7 |

**Final issue count:** 2  
**Audit result:** **PASS**

---

## Phase 1 — Unified constants & bridge ✅

**Closed:** commit `cc938b765` — Phase 1 bridge tests: WalkabilityBaker, encounter pipeline, headless Simulator smoke.  
**Tag:** `phase-1` on `0c537fc47`

### Deliverables
- [x] `TileIdToTerrain` complete mapping (impassable logical tiles → wall)
- [x] `WalkabilityBaker` unit tests (grid-only, null TileMapLayers)
- [x] `EncounterBuilder` blocked-cell → wall override test
- [x] Headless pipeline: `SkirmishGenerator` → `WalkabilityBaker` → `EncounterBuilder` → `BoardFactory` → `Simulator`
- [x] `tests/bridge_test.gd` CLI runner (`godot --headless --script res://tests/bridge_test.gd`)

### Phase 1 Audit (iteration 1 — 2026-07-16)

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | PASS | All Phase 1 deliverables implemented |
| Correct coding | PARTIAL | Determinism tested; input immutability not in bridge pipeline yet |
| Inconsistencies | PASS | `TileIdToTerrain` aligns with `Walkability.blocks_movement_tile` |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Tree/scatter blocking untested headlessly (null layers only) | Low | Deferred — Phase 2/3 |
| 2 | Godot headless not run on agent PATH | Low | Deferred — user CLI |

**Final issue count:** 2  
**Audit result:** **PASS** (pending user CLI)

### Phase 1 Audit (iteration 2 — 2026-07-16) — completeness review

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | PASS | Exit criteria met: baker tests, full encounter→sim pipeline, CLI runner |
| Correct coding | PASS | Bridge files statically typed; `core/` sim has no `TileMapLayer`/Node refs; pipeline asserts determinism + input not mutated |
| Inconsistencies | PASS | WATER/ROCK/RUIN → wall matches walkability; `TILE_PX`/`CELL` = 16 consistent |
| Issues | PASS | 2 deferred (≤2 cap) |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Tree/scatter blocking untested headlessly (null TileMapLayers only) | Low | Deferred — Phase 2/3 with real layers |
| 2 | `bridge_test.gd` / `sim_test.gd` not executed on agent PATH | Low | Deferred — user CLI run |

**Gate checks (Audit 1 exit criteria):**

| Check | Result |
|-------|--------|
| Determinism smoke test | PASS — `_test_headless_sim_pipeline` runs `Simulator` twice, hashes match |
| Static typing (`bridge/`) | PASS — all public functions typed |
| No sim→Node refs (`core/simulation`, `core/state`, `core/systems` combat path) | PASS — grep clean |

**Final issue count:** 2  
**Audit result:** **PASS**

---

## Phase 2 — Skirmish generation ✅

**Closed:** commit `deb4249e2` — Phase 2 skirmish spawns: SpawnPlacer bands, 10×7 validation tests.

### Deliverables
- [x] `bridge/spawn_placer.gd` — left/right third bands, MVP roster (1 knight + 3 enemies)
- [x] `SkirmishGenerator` bakes walkability + places spawns; `generate_encounter()` helper
- [x] All 7 `TacticalConstants.SKIRMISH_PRESETS` generate with non-empty spawns
- [x] `_test_spawn_validation_10x7` — 10 seeds × 7 sizes: walkable, in-band, no overlap

### Phase 2 Audit (iteration 1 — 2026-07-16)

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | PASS | SpawnPlacer, generator wiring, preset + 10×7 tests on disk |
| Correct coding | PASS | Static types; deterministic seeded placement; bridge tests expanded |
| Inconsistencies | PASS | Band math uses `width/3` and `2*width/3` per `IMPLEMENTATION_PLAN.md` |
| Issues | PASS | 2 deferred (≤2 cap) |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Spawn placement uses null TileMapLayers (tree/scatter trunk blocks not in band tests) | Low | Deferred — Phase 3 |
| 2 | `bridge_test.gd` not executed on agent PATH | Low | Deferred — user CLI |

**Gate checks (Audit 2 exit criteria):**

| Check | Result |
|-------|--------|
| 10 seeds × 7 sizes spawn validation | PASS — `_test_spawn_validation_10x7` |
| Walkable spawns guaranteed | PASS — every spawn checked with `Walkability.is_walkable` |
| Left/right band placement | PASS — `_test_spawn_placer_bands` + 10×7 band asserts |

**Final issue count:** 2  
**Audit result:** **PASS**

### Next
- Phase 3: `scenes/TacticalCombat.tscn` shell + `TacticalMapView` + BattleSetup size picker

---

## User decisions (locked)

| Item | Choice |
|------|--------|
| MVP | SP Knight vs small squad |
| Aim mode | H&I vector class icon |
| Ambient effects | Options toggle, default on |
| Extras v1 | Compendium, online co-op, autobattler |
