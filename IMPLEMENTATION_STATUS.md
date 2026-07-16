# Implementation Status — Honor & Iron 3

**Current phase:** 0 (bootstrap)  
**Last updated:** 2026-07-15

---

## Phase 0 — Bootstrap

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
**Expected debt (not counted):** legacy `board_view.gd` CELL=56 replaced in Phase 6.

**Audit result:** **PASS** (pending user F5 MainMenu)

### Next
- Phase 1: `WalkabilityBaker` tests + headless `Simulator` on generated encounter

---

## User decisions (locked)

| Item | Choice |
|------|--------|
| MVP | SP Knight vs small squad |
| Aim mode | H&I vector class icon |
| Ambient effects | Options toggle, default on |
| Extras v1 | Compendium, online co-op, autobattler |
