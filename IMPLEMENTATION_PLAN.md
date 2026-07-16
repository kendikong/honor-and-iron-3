# Honor & Iron 3 — Implementation Plan

**Repo:** `honor-and-iron-3` (new; `mana-seed-test` + `honor-and-iron` are read-only backups)  
**Base:** mana-seed-test visuals/world + honor-and-iron tactics simulation  
**Target:** Godot 4.7

---

## Non-Negotiables

| Rule | Detail |
|------|--------|
| One tile = 16px | Mana-seed tile = one H&I tactics cell |
| Sim is truth | `Simulator.simulate()` — preview == execution |
| No frankenstein | Adapter layer (`bridge/`) resolves conflicts; no scale hacks |
| Camera | **Middle-mouse hold = pan**; **Ctrl+scroll = dynamic zoom** (`MapCameraController`) |
| Phase audit | After every phase: audit until ≤2 issues; fix properly, no bandaids |
| Source repos | Never edit `mana-seed-test/` or `honor-and-iron/` |

---

## Architecture

```
PRESENTATION (mana-seed ground)
  TileMapLayers + EffectsController + LPC sprites + HUD
        ↑ EventBus (one way)
SIMULATION (H&I core/)
  CombatDirector → Simulator → BoardState
        ↑ one-time at load
BRIDGE (bridge/)
  SkirmishGenerator → WalkabilityBaker → EncounterBuilder
```

---

## Camera Controls (all map scenes)

`presentation/map_camera_controller.gd` — shared by sandbox dev + tactical combat:

| Input | Behavior |
|-------|----------|
| **Middle mouse hold + drag** | Pan (`pan_offset`) when map exceeds viewport |
| **Ctrl + scroll up/down** | Session dynamic zoom multiplier (0.25×–4×) |
| Options → Display | Base zoom mode + character scale slider (combat) |

---

## UI Consolidation (combat)

**On screen:** map + bottom/top combat HUD only  
**ESC → Options:** all Effects panel toggles, map dev tools, character gen, display settings

---

## Random Skirmish

Single battle mode. Size presets (tiles): **16×8, 20×10, 24×12, 28×14, 32×16, 36×18, 40×20**  
Players: left third, near vertical center. Enemies: right third.

**MVP:** SP Knight vs small enemy squad.

---

## Phases

### Phase overview (what each phase is for)

| Phase | Purpose |
|-------|---------|
| **0 — Bootstrap** | Merge the two repos into one Godot project: folder layout, autoloads, bridge stubs, camera controller, smoke tests. Proves the project opens and parses. |
| **1 — Unified constants & bridge** | Wire mana-seed tiles to H&I simulation: terrain mapping, walkability bake, encounter builder, headless `Simulator` pipeline. Proves tactics can run on generated grid data without the editor. |
| **2 — Skirmish generation** | Procedural random battles: map presets, left/right spawn bands, guaranteed walkable spawns. Proves every skirmish size produces a valid encounter. |
| **3 — Tactical combat scene shell** | First playable combat **scene**: living map visuals (sky, effects, TileMapLayers) without dev side panels; BattleSetup launches Random Skirmish. Proves the merged world **looks** right and camera works on large maps. |
| **4 — Simulation integration** | Hook `CombatDirector`, timeline HUD, planning/commit loop on generated encounters. Proves preview == execution in the real scene. |
| **5 — Unit sprites & health bars** | LPC unit visuals on the tactical grid: scale, y-sort, foot anchor, HP bars. Proves units read correctly on the mana-seed map. |
| **6 — Planning input & animations** | Split legacy `board_view.gd`; drag-to-move, aim mode, class icons, overlay z-order. Proves a full Knight turn is playable on the new map. |
| **7 — UI consolidation** | Move effects/dev tools to ESC → Options only; toggles stop ecology CPU when off. Proves combat screen stays clean. |
| **8 — Knight MVP** | Victory/defeat, sfx, all presets playtested, compendium link. Proves shippable single-player skirmish loop. |
| **9+ — Post-MVP** | More classes, co-op networking, autobattler on `EncounterBuilder`. |

---

### Phase 0 — Bootstrap ✅
- Copy repos → merged `project.godot`, autoloads, folder layout
- `bridge/` stubs + `TacticalConstants` + `MapCameraController`
- `tests/bridge_test_runner.gd` smoke test
- **Audit 0:** project opens; no duplicate `class_name`; bridge stubs parse

### Phase 1 — Unified constants & bridge ✅
- `TileIdToTerrain` complete mapping
- `WalkabilityBaker` + unit tests
- `EncounterBuilder` → `BoardFactory` → headless `Simulator`
- **Audit 1:** determinism smoke test; static typing; no sim→Node refs

### Phase 2 — Skirmish generation ✅
- `SkirmishGenerator` + `SpawnPlacer` (left/right bands)
- All 7 size presets; walkable spawns guaranteed
- **Audit 2:** 10 seeds × 7 sizes; spawn validation

### Phase 3 — Tactical combat scene shell ✅
- `scenes/TacticalCombat.tscn` (MapRoot + sky + effects)
- `TacticalMapView` (extracted from `test_map.gd`)
- BattleSetup → Random Skirmish size picker
- `MapCameraController` wired (no side panels in combat)
- **Audit 3:** visual compositor gates; shader errors; camera pan/zoom on large maps

### Phase 4 — Simulation integration ✅
- `CombatDirector` on generated encounters
- `TacticalCombatHud` (timeline, phase commit)
- **Audit 4:** preview == execution; `sim_test_runner` green

### Phase 5 — Unit sprites & health bars ✅
- `TacticalUnitLayer` + `UnitVisualFactory`
- Character scale: 1.5 tiles × user slider
- **Audit 5:** y-sort vs trees; foot anchor; scale bounds

### Phase 6 — Planning input & animations ✅
- Split `board_view.gd` → input overlay + unit layer
- Drag: LPC walk/slash/spellcast (no emoji cursors)
- Aim: vector class icon, rescaled
- **Audit 6:** full Knight turn playable; overlay z-order

### Phase 7 — UI consolidation ✅
- Effects/inspector → Options only
- ESC blocks combat input
- **Audit 7:** toggle off = zero ecology CPU

### Phase 8 — Knight MVP ✅
- Victory/defeat, sfx, all size presets playtest
- Compendium link
- **Audit 8:** Boredom-style 60s idle optional; ≤2 open issues

### Phase 9+ (post-MVP)
- Bruiser, Cavalier; local/online co-op; autobattler on `EncounterBuilder`

---

## Phase Audit Protocol

**No phase closes without a recorded audit.** After implementation:

1. Run all **four audit pillars** (see `.cursor/rules/phase-audit.mdc`):
   - **Completeness** — deliverables + exit criteria vs `IMPLEMENTATION_PLAN.md`
   - **Correct coding** — static types, patterns, automated tests
   - **Inconsistencies** — cross-file/layer drift (constants, walkability, sim isolation)
   - **Issues** — numbered list with severity
2. Run automated tests (`tests/`) — `bridge_test.gd`, `sim_test.gd` as applicable
3. Fix until **≤2 issues** remain (deferred items documented with target phase)
4. Record full audit block in `IMPLEMENTATION_STATUS.md` (pillars + issues table)
5. Git commit: full playable backup + `phase-N` tag
6. Only then begin the next phase

**Visual phases (3, 5, 6):** also verify draw order, nearest filter, runtime shader errors.

---

## `board_view.gd` Decomposition (Phase 6)

| New module | Responsibility |
|------------|----------------|
| `tactical_map_view.gd` | MapRoot, effects, camera |
| `tactical_planning_overlay.gd` | Range tints, ghosts, arrows |
| `tactical_unit_layer.gd` | LPC sprites, HP bars, animation |
| `tactical_combat_hud.gd` | Timeline, abilities, log |
| `tactical_input_controller.gd` | Drag, aim, grid pick |
| `class_icon_drawer.gd` | Vector icons for aim mode |

**Delete:** `_draw_tiles()` and procedural terrain (~1500 lines).

---

## Anti-Patterns (from honor-and-iron-2)

- ❌ `CELL=56` with LPC scale `16/56`
- ❌ Duplicate `random_map.gd` fork of `test_map.gd`
- ❌ Sim reading TileMapLayer at runtime
- ❌ Effects panel on combat screen
- ❌ Emoji drag cursors instead of sprite anims
