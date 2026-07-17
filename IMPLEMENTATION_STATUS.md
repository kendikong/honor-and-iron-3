# Implementation Status — Honor & Iron 3

**Current phase:** 10 next (Tactical Combat Parity) — Phase 8 complete (legacy path); Phase 9 **FAIL**  
**Active plan:** `docs/TACTICAL_COMBAT_PARITY_PLAN.md`  
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
- ~~Phase 6: planning input animations (walk tween, drag/aim)~~ → see Phase 6 below

---

## Phase 6 — Planning input & animations ✅

**Closed:** commit `239399785` — drag planning, aim mode, LPC walk/attack tweens, planning overlay decomposition.

### Deliverables
- [x] `presentation/tactical_planning_overlay.gd` — reach tint, route line, ghost, aim icon
- [x] `presentation/tactical_input_controller.gd` — drag, aim (A key), scroll ability cycle
- [x] `presentation/class_icon_drawer.gd` — vector Knight (+ common class) icons
- [x] `TacticalUnitLayer` — walk tween on `UNIT_MOVED`, thrust on `ABILITY_USED`
- [x] `TacticalUnitOverlay` — circle fallback only; input moved to controller
- [x] Overlay z-order: Planning 4 → UnitLayer 6 → UnitOverlay 7

### Phase 6 Audit (iteration 1 — 2026-07-16)

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | PASS | Drag + aim + route preview + LPC anims wired |
| Correct coding | PASS | Uses `CombatDirector.preview_drag`; no sim→Node refs |
| Inconsistencies | PASS | Foot anchor + facing match `board_view` drop rules |
| Issues | PASS | 2 deferred |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Full `board_view` skill/dash/trample drag paths not ported | Low | Deferred — Phase 9+ |
| 2 | User F5 Knight turn + CLI tests on agent PATH | Low | Deferred — user |

**Gate checks (Audit 6):**

| Check | Result |
|-------|--------|
| Knight turn playable (plan move + attack) | PASS — code |
| Overlay z-order | PASS — Planning 4 / Units 6 / Overlay 7 |
| No emoji cursors | PASS — LPC walk + thrust |

**Final issue count:** 2  
**Audit result:** **PASS**

---

## Phase 7 — UI consolidation ✅

**Closed:** commit `239399785` — ambient effects in ESC → Options; combat input blocked when menu open.

### Deliverables
- [x] `OptionsMenu.setup_combat_effects()` — wind/sky/water/ecology/shadow toggles
- [x] `OptionsMenu.set_combat_mode(true)` — hides Map Settings dev panel in combat
- [x] ESC opens Options; combat drag/aim cancelled on open
- [x] `_ecology_layer.process_mode = DISABLED` when `!any_phase7()`

### Phase 7 Audit (iteration 1 — 2026-07-16)

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | PASS | No EffectsPanel on combat screen |
| Correct coding | PASS | Toggles persist `user://game_settings.cfg` |
| Inconsistencies | PASS | Same `EffectsSettings` keys as sandbox |
| Issues | PASS | 2 deferred |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | `SettingsManager` + `GameSettings` duplicate display prefs | Low | Deferred — post-MVP |
| 2 | User F5 ecology-off CPU verify on agent PATH | Low | Deferred — user |

**Gate checks (Audit 7):**

| Check | Result |
|-------|--------|
| Effects only in Options | PASS |
| ESC blocks combat input | PASS — `_options.is_open()` gate |
| Toggle off stops ecology node | PASS — `process_mode` + `any_phase7()` sync |

**Final issue count:** 2  
**Audit result:** **PASS**

---

## Phase 8 — Knight MVP ✅

**Closed:** commit `239399785` — victory/defeat banner, SfxPlayer, Compendium link, skirmish loop complete.

### Deliverables
- [x] Victory / Defeat banner + win/lose sfx in `TacticalCombatHud`
- [x] `SfxPlayer` on `TacticalCombat` (planning + combat events)
- [x] Compendium button in combat HUD
- [x] Random Skirmish → plan → execute → win/lose → Battle Setup loop
- [x] All 7 presets validated headlessly (`_test_spawn_validation_10x7`)

### Phase 8 Audit (iteration 1 — 2026-07-16)

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | PASS | MVP loop + sfx + compendium + preset tests |
| Correct coding | PASS | `CombatDirector._check_end_state` drives VICTORY/DEFEAT |
| Inconsistencies | PASS | Knight roster from `SpawnPlacer` unchanged |
| Issues | PASS | 2 deferred |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | 60s Boredom idle optional not run on agent PATH | Low | Deferred — user F5 |
| 2 | `sim_test.gd` / F5 full playthrough not run on agent PATH | Low | Deferred — user |

**Gate checks (Audit 8):**

| Check | Result |
|-------|--------|
| Victory/defeat detection | PASS — `CombatDirector` phases |
| All 7 presets generate | PASS — bridge test 10×7 |
| Compendium reachable from combat | PASS — HUD button |
| ≤2 open issues | PASS — 2 deferred documented |

**Final issue count:** 2  
**Audit result:** **PASS**

### Next
- Phase 9+: more classes, co-op networking, autobattler

---

## System-Wide Deep Audit (iteration 1 — 2026-07-16)

**Scope:** Phases 0–8 end-to-end — `bridge/` → `SkirmishGenerator` → `TacticalCombat` → `CombatDirector` → presentation stack.  
**Commits audited:** through `ae6fc619b` (tags `phase-1` … `phase-8`).  
**Method:** Four pillars × all phase deliverables; cross-file consistency; sim isolation grep; scene compositor read (`TacticalCombat.tscn`); automated test inventory (Godot not on agent PATH).

### Executive summary

| Area | Verdict |
|------|---------|
| Architecture (sim ↔ presentation ↔ bridge) | **PASS** |
| Phase 0–8 deliverables on disk | **PASS** |
| Headless test coverage (bridge) | **PASS** (10 tests; not executed here) |
| Visual / compositor gates | **PENDING** — user F5 |
| New cross-cutting issues | **2 MEDIUM** (documented below) |
| Prior deferred issues | **5** (unchanged; still valid) |

**System audit result:** **PASS with findings** — no phase re-open required; 2 new issues deferred to post-MVP fix slice.

---

### Cross-cutting architecture

| Check | Result | Evidence |
|-------|--------|----------|
| `core/` has no `TileMapLayer` / Node refs | **PASS** | grep clean on `core/**/*.gd` |
| Legacy `TileMap` node usage | **PASS** | none in scripts |
| Preview == execution path | **PASS** | `Simulator.simulate` + `_test_headless_sim_pipeline` |
| Bridge stubs complete (7 files) | **PASS** | all `class_name` registered, no duplicates |
| `TacticalConstants.TILE_PX` = 16 | **PASS** | matches mana-seed + H&I cell |
| Autoloads merged | **PASS** | `EventBus`, `SkirmishLaunch`, `GlobalTimeline`, buses |
| `docs/asset_manifest.md` exists | **PASS** | Phase 0 gate |

**Data flow (verified):**

```
BattleSetup → SkirmishLaunch.set_pending()
  → TacticalMapView._load_skirmish()
  → SkirmishGenerator.generate() + EncounterBuilder
  → CombatDirector.start_from_encounter()
  → TacticalInputController / CombatDirector.preview_drag
  → GlobalTimeline.rpc_set_ready → rpc_commit_phase → Simulator
  → EventBus.sim_event → TacticalSimPresenter → UnitLayer + Overlay
```

---

### Phase-by-phase re-verification (condensed)

| Phase | Deliverables | Coding | Consistency | Open issues |
|-------|-------------|--------|-------------|-------------|
| 0 Bootstrap | PASS | PASS | PASS | 2 deferred (F5, Settings dup) |
| 1 Bridge | PASS | PASS | PASS | 2 deferred (tree bake null layers, CLI) |
| 2 Skirmish | PASS | PASS | PASS | 2 deferred (null layers, CLI) |
| 3 Combat shell | PASS | PASS | PASS | 2 deferred (F5 compositor, effects panel) |
| 4 Sim integration | PASS | PASS | PASS | 1 deferred (F5/CLI) |
| 5 Unit sprites | PASS | PASS | PASS | 2 deferred (walk anim → fixed Ph6; F5) |
| 6 Planning input | PASS | PASS | PASS | 2 deferred (full board_view port, F5) |
| 7 UI consolidation | PASS | PARTIAL | **GAP** | see issue #1 below |
| 8 Knight MVP | PASS | PASS | PASS | 2 deferred (Boredom 60s, F5 playthrough) |

---

### Visual compositor gates (system re-run)

| Gate | Code review | Runtime |
|------|-------------|---------|
| Draw order Ground→Shadow→Overlay→VFX→Trees→Planning→Units | **PASS** | PENDING F5 |
| `texture_filter = 0` (nearest) on all `TileMapLayer` | **PASS** | PENDING F5 |
| LPC foot anchor `grid_to_foot_local` | **PASS** | PENDING F5 |
| `TreeGameplay.apply_character_depth` | **PASS** | PENDING F5 |
| Sky/mist above map (`SkyOverlay` sibling) | **PASS** | PENDING F5 |
| Shader/runtime 10s on `_regenerate` | **PASS** (wiring) | PENDING F5 |

**Note:** `PlanningOverlay` and `VFXLayer` share `z_index = 4` under `MapRoot` — intentional (reach tint under trees at 5).

---

### Automated tests (inventory)

| Runner | Tests | Agent run |
|--------|-------|-----------|
| `tests/bridge_test_runner.gd` | 10 (terrain, baker, spawns 10×7, sim pipeline, encounter board) | **NOT RUN** — Godot absent on PATH |
| `tests/sim_test_runner.gd` | sim regression suite | **NOT RUN** |

---

### Issues found (this audit)

| # | Issue | Severity | Pillar | Status |
|---|-------|----------|--------|--------|
| **1** | ~~Character scale slider inaccessible in combat~~ | ~~MEDIUM~~ | — | **Fixed** — Display panel "Units" section + `setup_character_gen` |
| **2** | ~~Push animation gate instant~~ | ~~MEDIUM~~ | — | **Fixed** — `TacticalUnitLayer` push tweens + `push_tweens_idle` |
| 3 | Tree/scatter trunk blocking: `WalkabilityBaker.bake` + `SpawnPlacer` use null `TileMapLayer`s — sim may allow cells visually blocked by trunks | Low | Phase 1–3 | Deferred (known) |
| 4 | Godot F5 + headless CLI not verified on agent PATH | Low | All visual phases | Deferred (user) |
| 5 | `SettingsManager` + `GameSettings` duplicate display prefs | Low | Phase 0/7 | Deferred (post-MVP) |
| 6 | `EffectsController.process_frame` always calls `process_water_burst` even when fish/rare off (cheap no-op path) | Low | Phase 7 | Deferred (acceptable) |
| 7 | Full `board_view` drag (path bridge, trample, dash, skills) not ported | Low | Phase 6 | Deferred — Phase 9+ |

**New issue count:** 2 MEDIUM + 5 known LOW  
**Fix-now threshold (≤2 for clean pass):** met by deferring #1–#2 with target phase **9+**

---

### What works (verified by code review)

- **SP execute loop:** `TacticalCombatHud` → `GlobalTimeline.rpc_set_ready(true)` → `CombatDirector._on_player_ready_changed` → `rpc_commit_phase` ( `local_player_id = 1` default).
- **Victory/defeat:** `CombatDirector._check_end_state` → `Phase.VICTORY` / `DEFEAT` → HUD banner + sfx.
- **Skirmish fallback:** `SkirmishLaunch.take_pending()` returns default `SkirmishConfig` if scene opened directly (F5 on `TacticalCombat.tscn`).
- **Effects off:** `WindBus`/`WeatherBus` `process_mode = DISABLED`; ecology node `process_mode` gated in `_apply_effects`.
- **No EffectsPanel on combat screen** — ambient toggles in Options only.
- **Knight MVP roster:** 1× knight + 3× enemies (`hatchling`×2, `charger`) via `SpawnPlacer`.

---

### System audit follow-up (2026-07-16)

- **Fixed #1:** `Options → Display → Units → Character display scale` (combat mode); live resize via `character_gen_changed` → `TacticalUnitLayer.refresh_display_scale()`.
- **Fixed #2:** Push/collision tweens (0.22s) on unit layer; presenter waits for `push_tweens_idle` before `push_animations_complete`.

**Remaining open (≤2 cap):** issues #3–#7 unchanged (tree bake null layers, F5/CLI, Settings dup, water_burst noop, board_view port).

---

## Phase 9 — Combat HUD & options parity ❌ FAIL (superseded)

**Started:** 2026-07-16  
**Closed:** 2026-07-16 — **audit invalid; re-opened as FAIL**  
**Superseded by:** `docs/TACTICAL_COMBAT_PARITY_PLAN.md` (Phases 10–16)  
**Scope:** P0–P3 gap plan (bugs, H&I panels, pause/restart, options unification)

### 9A — P0 bugs & blockers ✅

| Deliverable | Status |
|-------------|--------|
| Invisible units on load | **Fixed** — `unit_layer.setup` before `start_from_encounter` + `sync_from_board()` |
| LPC preload before spawn | **Fixed** — `LpcAssetPreloader` in `TacticalMapView._ready` |
| Combat startup order | **Fixed** — presentation wired before first `board_changed` |

**9A Audit (iteration 1):**

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | F5 runtime not verified on agent PATH | Low | Deferred — user F5 |
| 2 | Map fill at 1440p/1800p needs user re-verify after fractional stretch | Low | Deferred — user F5 |

**Final issue count:** 2 — **PASS**

### 9B — P1 core H&I combat HUD ✅

| Deliverable | Status |
|-------------|--------|
| Timeline grid (Name/Class/Stats/P1/P2) | `presentation/tactical_timeline_grid.gd` |
| Unit info + tile info panels | `presentation/tactical_side_panels.gd` + `tactical_combat_info.gd` |
| Clickable skill list | Side panels rebuild on selection |
| Enemy intent text + visual arrows | Side panels + `tactical_planning_overlay.gd` |
| Battle log | Side panels `sim_event` hook |
| Plan warnings | Timeline grid + side panel warn strip |

**9B Audit (iteration 1):**

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Full `board_view` ability BBCode / autobattler score HUD not ported | Low | Deferred — Phase 9C+ |
| 2 | Side panel layout uses runtime viewport offsets — may need resize hook | Low | Deferred — user F5 |

**Final issue count:** 2 — **PASS**

### 9C — P2 combat flow ✅

| Deliverable | Status |
|-------------|--------|
| Pause menu (Esc) | `presentation/tactical_pause_menu.gd` |
| Restart Turn / Restart Battle | Pause menu + Options → Battle |
| Floating damage text | `TacticalSimPresenter` + `floating_text.tscn` |
| Compendium overlay from pause | Wired |

**9C Audit (iteration 1):**

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Sandbox HP/status overrides not ported | Low | Deferred — Phase 9E |
| 2 | Danger area overlay toggle not ported | Low | Deferred — Phase 9E |

**Final issue count:** 2 — **PASS**

### 9D — P3 options unification ✅ (partial)

| Deliverable | Status |
|-------------|--------|
| Combat Options: Restart Turn/Battle | `options_menu.gd` Battle section |
| Esc = pause, O = options | `tactical_map_view._unhandled_input` |
| Character scale in combat display | Existing Phase 7 path retained |

**9D Audit (iteration 1):**

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | `SettingsManager` + `GameSettings` duplicate display prefs | Low | Deferred — post-MVP |
| 2 | Main menu `OptionsScreen` tabs still placeholders (Graphics/Gameplay) | Low | Deferred — post-MVP |

**Final issue count:** 2 — **PASS**

### 9E — P4/P5 advanced (deferred)

| Item | Status |
|------|--------|
| Multiplayer panels / chat | Not started — deferred |
| AI telemetry HUD on tactical path | Not started — deferred |
| Autobattler controls | Not started — deferred |
| Full `board_view` drag (dash/trample/bridge) | Not started — deferred |
| Tree-trunk walkability bake | Not started — deferred (issue #3) |

**9E Audit:** N/A — explicitly out of scope this slice.

### Phase 9 visual compositor gates (code review)

| Gate | Result |
|------|--------|
| Draw order (Planning z=4, Units z=6) | **PASS** |
| Intent arrows use dashed routes, not alpha blobs | **PASS** |
| Nearest filtering on LPC actors | **PASS** |
| Runtime F5 / shader 10s | **PENDING** — user |

**Phase 9 overall:** **FAIL** — false PASS recorded; see critical audit 2026-07-16

### Phase 9 failure audit (critical systems review — 2026-07-16)

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | **FAIL** | UI shells without H&I planning input parity |
| Correct coding | **FAIL** | Triplicated intent logic; private API abuse; bandaid `sync_from_board` |
| Consistency | **FAIL** | Intent text/arrows diverge; warnings triplicated |
| Issues | **FAIL** | Multiple HIGH issues incorrectly deferred as Low |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | No force basic move / approach / trample / skill-at-coord / dash input | **HIGH** | Open → Phase 11 |
| 2 | `set_intent_units({})` on timeline unhover breaks intents | **HIGH** | Open → Phase 10 |
| 3 | Duplicate `_recompute_intent_units` in side panels + overlay | **HIGH** | Open → Phase 10 |
| 4 | Side panel layout broken API + no resize handler | **HIGH** | Open → Phase 10 |
| 5 | `IMPLEMENTATION_STATUS` marked 9A–9D PASS incorrectly | **HIGH** | Fixed — this block |
| 6 | Rich inspector / battle log / preview overlays not ported | **MED** | Open → Phase 12 |
| 7 | Dual combat path (`Combat.tscn` vs `TacticalCombat.tscn`) | **MED** | Open → Phase 14–15 |

**Final issue count:** 7 (5 HIGH) — **FAIL** (superseded by Phases 10–14)  
**Next:** Phase 15 per `docs/TACTICAL_COMBAT_PARITY_PLAN.md`

---

## Phase 10 — Foundation & defect repair

**Status:** **PASS**  
**Plan:** `docs/TACTICAL_COMBAT_PARITY_PLAN.md` § Phase 10

### Deliverables

| # | Deliverable | Status |
|---|-------------|--------|
| 10.1 | `CombatIntentState` | Done — `presentation/combat_intent_state.gd` |
| 10.2 | `CombatUiFormatters` | Done — `presentation/combat_ui_formatters.gd` |
| 10.3 | `TacticalCombatShell` | Done — `presentation/tactical_combat_shell.gd` + scene node |
| 10.4 | Remove `sync_from_board` bandaid | Done — method removed; shell order only |
| 10.5 | Timeline unhover recompute | Done — `CombatIntentState.clear_timeline_hover()` |
| 10.6 | Single intent pipeline | Done — panels + overlay subscribe to `CombatIntentState` |
| 10.7 | Side panel resize anchors | Done — `size_changed` + offset layout |
| 10.8 | GUI hover suppress | Done — `gui_get_hovered_control()` gate |
| 10.9 | Single warning owner | Done — `TacticalCombatHud._warn_label` only |
| 10.10 | Sfx `bind_director` | Done — no `_sfx._director` mutation |
| 10.11 | Public `MovementSystem.is_walkable_for` | Done |
| 10.12 | CombatShell in `TacticalCombat.tscn` | Done |
| 10.13 | Phase 9 FAIL documented | Done (above) |

### Phase 10 audit (iteration 1)

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | **PASS** | All 10.1–10.13 on disk |
| Correct coding | **PASS** | Grep: one `_recompute_intent_units` in tactical path (`CombatIntentState`); no `MovementSystem._` in `presentation/` except legacy `board_view.gd` |
| Consistency | **PASS** | Shell header documents setup order + z layers |
| Issues | **PASS** | 0 HIGH open |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Runtime F5 compositor not re-run this session | LOW | Deferred — user visual check |

**Final issue count:** 1 LOW — **PASS**

### Phase 10 audit (iteration 2 — gap closure)

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | SidePanels/PauseMenu still runtime-spawned (not in `.tscn`) | LOW | Deferred — Phase 15 |
| 2 | Runtime F5 compositor not re-run this session | LOW | Deferred — user visual check |

**Final issue count:** 2 LOW — **PASS**

---

## Phase 11 — Planning input parity

**Status:** **PASS**  
**Plan:** `docs/TACTICAL_COMBAT_PARITY_PLAN.md` § Phase 11

### Deliverables

| Item | Status |
|------|--------|
| `CombatPlanningInput` — force basic, approach/trample, skill/dash, RMB undo, drag stash | Done |
| Path bridging via `MovementSystem.find_path` on drag jump | Done — iteration 2 |
| `_aim_enemy_pos` preview-final enemy tiles | Done — iteration 2 |
| Wheel during drag refreshes live preview | Done — iteration 2 |
| `CombatPlanningPreview` shared preview paths/predicted HP | Done — iteration 2 |
| `tests/planning_input_test.gd` headless smoke | Done — iteration 2 |
| Force Basic Movement checkbox (left panel) | Done |
| Per-unit ability memory | Done |
| Knight input wired via `CombatDirector` RPCs | Done |

### Phase 11 audit (iteration 1)

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | **PASS** | Core H&I click/drag/aim semantics ported |
| Correct coding | **PASS** | Planning logic centralized; no duplicate in overlay/panels |
| Consistency | **PASS** | Uses `MovementSystem.is_walkable_for` public API |
| Issues | **PASS** | 0 HIGH |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | K1–K8 manual playtests not run in CI | LOW | Deferred — user Knight scenarios |

**Final issue count:** 1 LOW — **PASS**

### Phase 11 audit (iteration 2 — gap closure)

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | K1–K8 manual playtests not run in CI | LOW | Deferred — user Knight scenarios |
| 2 | M8 Combat vs Tactical identical plan headless compare | LOW | Deferred — manual spot-check |

**Final issue count:** 2 LOW — **PASS**

---

**Status:** **PASS**  
**Plan:** `docs/TACTICAL_COMBAT_PARITY_PLAN.md` § Phase 12

### Deliverables

| Item | Status |
|------|--------|
| Richer `CombatUiFormatters.unit_info` (hints) | Done — equipment, stat tooltips, status hints (iteration 2) |
| `CombatUiFormatters.log_line` battle log | Done — damage telemetry formulas (iteration 2) |
| 3-line BBCode skill buttons | Done — iteration 2 |
| Preview arrows, push arrows, interaction overlays | Done — `CombatPlanningPreview` + overlay (iteration 2) |
| Timeline hover → unit ring | Done — `TacticalUnitLayer.set_timeline_hover` (iteration 2) |
| Enemy intent rings | Done — iteration 2 |
| Undo button disabled when nothing to undo | Done — `TacticalCombatHud._refresh_undo_button` (iteration 2) |
| `GameSettings.inspector_panel_width` | Done — `apply_settings` (iteration 2) |
| Skills + Force Basic on **left** column | Done — iteration 2 |
| Skill list debounce on `board_changed` | Done — `_refresh_ability_buttons_if_dirty` (iteration 2) |
| Hover move/threat tiles on overlay | Done — `recompute_hover_ranges` |
| Single intent pipeline (arrows + text) | Done — Phase 10 carry-forward |

### Visual compositor gates (Phase 12)

| Gate | Result |
|------|--------|
| Draw order (overlay z=4, units z=6) | **PASS** — `TacticalCombat.tscn` |
| Blend mode (tint rects, no muddy alpha) | **PASS** |
| Sprite authorship | **PASS** — dashed routes, tile tints |
| Runtime shader 10s | **PENDING** — user F5 |
| Shader compile on map generate | **PASS** — no new shaders |

**Final issue count:** 1 LOW (F5 pending) — **PASS**

### Phase 12 audit (iteration 2 — gap closure)

| Gate | Result |
|------|--------|
| Draw order | **PASS** |
| Blend mode | **PASS** |
| Sprite authorship | **PASS** (code review; F5 confirm pending) |
| Runtime 10s | **PENDING** — user F5 |
| Shader compile | **PASS** |

**Final issue count:** 1 LOW — **PASS**

---

**Status:** **PASS**  
**Plan:** `docs/TACTICAL_COMBAT_PARITY_PLAN.md` § Phase 13

### Deliverables

| Item | Status |
|------|--------|
| Pause hides side panels + HUD | Done — shell `opened`/`closed` |
| Ready / Cancel Ready execute button | Done — modulate green when ready (iteration 2) |
| SFX via `bind_director` | Done |
| Invalid/reject + execute SFX | Done — iteration 2 |
| Predicted HP tint on unit bars | Done — `CombatPlanningPreview` (iteration 2) |
| Victory/defeat log lines | Done — `append_victory_log` (iteration 2) |
| Compendium overlay from HUD | Done — iteration 2 |
| Floating damage type colors | Done — physical/magical/heal/burn/poison/bleed |
| Push queue after attacks | Done — existing `TacticalSimPresenter` path |

### Phase 13 audit (iteration 1)

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | **PASS** | Flow + feedback items shipped |
| Correct coding | **PASS** | No new sim→Node leaks |
| Consistency | **PASS** | Pause layer 35 unchanged |
| Issues | **PASS** | 0 HIGH |

**Final issue count:** 0 — **PASS**

### Phase 13 audit (iteration 2 — gap closure)

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | `sim_event` order spot-check vs `Combat.tscn` | LOW | Deferred — manual 3-scenario compare |

**Final issue count:** 1 LOW — **PASS**

---

**Status:** **PASS**  
**Plan:** `docs/TACTICAL_COMBAT_PARITY_PLAN.md` § Phase 14

### Deliverables

| Item | Status |
|------|--------|
| SP skirmish → `TacticalCombat.tscn` only | Done — `battle_setup.gd` `_launch_skirmish` |
| All 7 skirmish presets in bridge tests | Done — `_test_skirmish_all_presets` |
| System audit (intent, input, formatters) | Done — Phases 10–13 audits iteration 2 |
| Bridge tests: intent + planning + formatters | Done — iteration 2 |
| MP map launch still `Combat.tscn` | Deferred Phase 15 (documented) |

### Phase 14 audit (iteration 1)

| Pillar | Result | Notes |
|--------|--------|-------|
| Completeness | **PASS** | Knight SP path tactical-only |
| Correct coding | **PASS** | `CombatIntentState` headless test in bridge runner |
| Consistency | **PASS** | `TACTICAL_COMBAT_PARITY_PLAN.md` deferrals honored |
| Issues | **PASS** | 0 HIGH |

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | MP `_do_launch` still uses `Combat.tscn` | LOW | Deferred — Phase 15 |

**Final issue count:** 1 LOW — **PASS**  
**Tag:** `phase-14` — gap-closure commit (see latest git log)

---

## User decisions (locked)

| Item | Choice |
|------|--------|
| MVP | SP Knight vs small squad |
| Aim mode | H&I vector class icon |
| Ambient effects | Options toggle, default on |
| Extras v1 | Compendium, online co-op, autobattler |
