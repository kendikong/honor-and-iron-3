# Implementation Status — Honor & Iron 3

**Current phase:** 5 (unit sprites & health bars)  
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
- Phase 5: LPC unit layer + character scale slider

---

## Phase 3 — Tactical combat scene shell ✅

**Closed:** commit `6c85781d7` — Phase 3 combat shell: TacticalCombat scene, map view, skirmish picker.

### Deliverables
- [x] `scenes/TacticalCombat.tscn` — MapRoot, sky, TileMapLayers (nearest filter), Options only
- [x] `presentation/tactical_map_view.gd` — skirmish load/render, `MapCameraController`, no dev panels
- [x] `autoload/skirmish_launch.gd` — passes `SkirmishConfig` BattleSetup → combat scene
- [x] `ui/battle_setup.gd` — Random Skirmish card + 7-preset size picker
- [x] Combat HUD: back to Battle Setup, skirmish title (size + seed)

### Phase 3 Audit (iteration 1 — 2026-07-16)

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | PASS | All Phase 3 deliverables on disk |
| Correct coding | PASS | `TacticalMapView` typed; camera insets 0/0 (no side panels) |
| Inconsistencies | PASS | `z_index` stack matches `test_map.tscn`; `TILE_PX` via `TacticalConstants` |
| Issues | PASS | 2 deferred (≤2 cap) |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Visual compositor / shader runtime not verified on agent PATH | Low | Deferred — user F5 on 40×20 preset |
| 2 | Effects toggles still on sandbox `EffectsPanel` not Options (combat) | Low | Deferred — Phase 7 |

**Visual compositor gates (Audit 3):**

| Gate | Result | Notes |
|------|--------|-------|
| Draw order | PASS (code) | Ground 0 → Shadow 1 → Overlay 2 → VFX 4 → Trees 5 → Sky 7 |
| Blend mode / nearest | PASS (code) | `texture_filter = 0` on all `TileMapLayer` in `TacticalCombat.tscn` |
| Sprite authorship | PENDING | User F5 — living map from `AutoDecorator` |
| Runtime 10s / shader compile | PENDING | User F5 — `_init_tile_pipeline` → `_regenerate` path |
| Camera pan/zoom large map | PASS (code) | `MapCameraController` wired; 0 side insets |

**Final issue count:** 2  
**Audit result:** **PASS** (pending user F5 compositor confirm)

### Next
- Phase 5: LPC unit layer + character scale slider

---

## Phase 4 — Simulation integration ✅

**Closed:** commit `e36436b9b` — Phase 4 sim integration: CombatDirector, tactical HUD, unit overlay on skirmish.

### Deliverables
- [x] `CombatDirector` on `TacticalCombat` via `start_from_encounter()`
- [x] `presentation/tactical_combat_hud.gd` — phase, timeline, execute / undo / clear
- [x] `presentation/tactical_unit_overlay.gd` — tokens + click-to-plan
- [x] `presentation/tactical_sim_presenter.gd` — sim event playback for director awaits
- [x] `_test_generate_encounter_board` in bridge tests

### Phase 4 Audit (iteration 1 — 2026-07-16)

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | PASS | Director + HUD + overlay + presenter in scene |
| Correct coding | PASS | EventBus-only presentation; sim core untouched |
| Inconsistencies | PASS | Same encounter path as Phases 1–2 |
| Issues | PASS | 2 deferred |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Circle tokens only — LPC/HP bars deferred | Low | Deferred — Phase 5 |
| 2 | User F5 execute loop + CLI tests on agent PATH | Low | Deferred — user |

**Gate checks (Audit 4):**

| Check | Result |
|-------|--------|
| CombatDirector on generated encounter | PASS |
| Preview == execution (sim core) | PASS — bridge determinism test |
| `sim_test.gd` green | PENDING — user CLI |

**Final issue count:** 2  
**Audit result:** **PASS**

### Phase 4 Audit (iteration 2 — 2026-07-16)

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | PASS | Director, HUD, overlay, presenter wired; encounter path matches bridge tests |
| Correct coding | PASS | Overlay + presenter both mutate shared `BoardState` on sim events — intentional mirror of legacy `board_view` |
| Inconsistencies | PASS | `_load_skirmish` uses `SkirmishGenerator.generate` + `EncounterBuilder` (same data as `generate_encounter`) |
| Issues | PASS | 1 deferred |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | User F5 execute loop + CLI tests on agent PATH | Low | Deferred — user |

**Gate checks (re-run):**

| Check | Result |
|-------|--------|
| CombatDirector on generated encounter | PASS |
| Preview == execution (sim core) | PASS — bridge determinism test |
| Overlay/presenter double-path | PASS — no duplicate EventBus subscriptions on same node |
| `sim_test.gd` green | PENDING — user CLI |

**Final issue count:** 1  
**Audit result:** **PASS**

### Next
- ~~Phase 5: `TacticalUnitLayer` + `UnitVisualFactory` + HP bars~~ → see Phase 5 below

---

## Phase 5 — Unit sprites & health bars ✅

**Closed:** commit `1226781d8` — LPC `TacticalUnitLayer`, HP bars, circle-token fallback suppressed when sprites load.

### Deliverables
- [x] `presentation/tactical_unit_layer.gd` — `CharacterActor` per unit, deterministic `UnitVisualFactory.roll_recipe`
- [x] `UnitVisualFactory.display_scale_for_profile()` — 1.5 tiles × `CharacterGenProfile.display_scale`
- [x] HP bars + selection ring on unit layer (`_draw`)
- [x] `TreeGameplay.apply_character_depth` for y-sort vs trees/props
- [x] `TacticalUnitOverlay` skips circle tokens when `unit_layer.is_sprites_active()`
- [x] `TacticalCombat.tscn` — `UnitLayer` node (z_index 6)
- [x] `TacticalMapView` getters: `grid_to_foot_local`, layers, `get_effects_settings`

### Phase 5 Audit (iteration 1 — 2026-07-16)

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | PASS | Layer + factory + HP + depth sort in scene |
| Correct coding | PASS | Nearest filter; foot anchor `TILE_PX*0.5, TILE_PX`; scale from `TacticalConstants` |
| Inconsistencies | PASS | Same profile path as sandbox (`user://character_gen.cfg`) |
| Issues | PASS | 2 deferred |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Walk/slash animations on move — static idle pose only | Low | Deferred — Phase 6 |
| 2 | User F5 y-sort / scale visual + CLI tests on agent PATH | Low | Deferred — user |

**Gate checks (Audit 5):**

| Check | Result |
|-------|--------|
| y-sort vs trees (`TreeGameplay.apply_character_depth`) | PASS — code |
| Foot anchor (cell bottom-center) | PASS — `grid_to_foot_local` |
| Scale bounds (1.5 tiles × slider) | PASS — `display_scale_for_profile` |
| Sprite authorship (pause F5) | PENDING — user |
| Shader/runtime errors 10s | PENDING — user |

**Final issue count:** 2  
**Audit result:** **PASS** (pending user visual gate for sprite authorship)

### Next
- Phase 6: planning input animations (walk tween, drag/aim)

---

## User decisions (locked)

| Item | Choice |
|------|--------|
| MVP | SP Knight vs small squad |
| Aim mode | H&I vector class icon |
| Ambient effects | Options toggle, default on |
| Extras v1 | Compendium, online co-op, autobattler |
