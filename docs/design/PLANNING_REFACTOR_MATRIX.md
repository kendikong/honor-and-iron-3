# Planning refactor matrix (survives summarization)

**Status:** ACTIVE — read this **first** after any chat summarization before planning or combat input work.  
**Owner policy:** `docs/design/MOVE_PREVIEW_RULES.md` § **Timeline model**  
**Hard gate (owner):** **NO testing** (`tests/`, `run_*`, F5 QA) until an agent claims **100% rule abidance** on this matrix (every row `DONE`).

**Latest gauntlet (2026-08-29):** Round 25 — **PASS 87/100** (threshold 85). Owner-rule §88 static closure. **Static rule abidance claimed** — WP-9 runtime QA still owner-run.

---

## Canonical invariant (one paragraph)

A turn is a **timeline of phases** (premove → skill modules → postmove). **Forecast stand at phase entry** is the only origin for the **current** phase (walk, locked blue/red). **One voluntary-walk pipeline** (hover → paint → commit); **only action metadata** differs: timeline column/slot, `move_timing`, animate-on-commit (PRE during planning vs POST on Execute). Next-phase tiles use **forecast at hover** — same forecast system, different branch.

---

## Rule abidance matrix

| ID | Rule | Target owner (code) | Status | Evidence (round 7) |
|----|------|---------------------|--------|-------------------|
| R1 | Forecast stand at **phase entry** = walk + locked tile origin | `CombatPlanningPreview.forecast_stand_at_phase_entry` | `DONE` | `_phase_entry_stand` / `phase_entry_stand_cell` at all walk/corridor/drag sites |
| R2 | Sealed leg = **lock** phase-entry anchor (`route[0]`) | R1 sealed branch | `DONE` | `is_painted_leg_sealed` + `route[0]` via R1 |
| R3 | Action range **delegates** to R1 (+ documented exceptions) | `action_range_intent_stand_cell` | `DONE` | No `live_path[-1]`; hover extend via `move_intent_destination`; module handoff + armed-tile lock documented |
| R4 | **Intent truth:** preview origin + path = commit origin + path | `_resolve_commit_move_waypoints` + `_append_move_to_commit_slots` | `DONE` | `_phase_entry_stand` at paint and commit |
| R5 | **One timeline phase cursor** | `CombatDirector.planning_timeline_phase_kind` | `DONE` | `_movement_planning_excluding_autorun` branches on `phase_kind`; `_voluntary_walk_postmove_slot_open` = POSTMOVE/modular exception only; overlay uses `route_pathfinding_ability_for_hover` |
| R6 | **One voluntary-walk hover pipe** | `_refresh_voluntary_walk_hover_preview` | `DONE` | Entries: refresh (hover), `_apply_voluntary_walk_drag_preview` (drag), `_restore_sealed_voluntary_walk_preview` (sealed preserve); `_write_*` internal only |
| R7 | **One corridor / paint geometry** | `voluntary_walk_corridor_waypoints` + `PlanningRoutePolicy` | `DONE` | `_corridor_waypoints_to_cell`; sealed → basic-walk; orbit via `_voluntary_walk_orbit_phase_open` (phase cursor) |
| R8 | **One voluntary-walk commit entry** | `_try_commit_voluntary_walk` → `commit_from_slots` | `DONE` | `TimelineAction.make_move` only in `_append_move_to_commit_slots`; player never calls `rpc_plan_move` (autobattler only) |
| R9 | Commit **metadata only** | `TimelineAction` + `_plan_for_timing` | `DONE` | No new PRE/POST commit forks |
| R10 | Tile layers: locked current phase from R1 | `PlanningPreviewTiles.resolve_layer_origins` | `DONE` | `phase_entry_stand_cell` for locked origins |
| R11 | Next-phase hover = forecast at hover | `predicted_stand_at_hover` | `DONE` | Separate branch only |
| R12 | PRE ≡ MOVE-module voluntary walk | `PlanningRoutePolicy` + corridor builder | `DONE` | Sealed: `_basic_walk_pathfinding_active`, `_route_pathfinding_ability`, `_corridor_waypoints_to_cell` all force basic-walk; MOVE_PREVIEW_RULES pass 26–27 updated |

---

## Work packages

| ID | Status | Notes |
|----|--------|-------|
| WP-1 | `DONE` | R1+R2 origin SSOT |
| WP-2 | `DONE` | R4 commit R1 |
| WP-3 | `DONE` | R3+R10 |
| WP-4 | `DONE` | R5 phase cursor |
| WP-5 | `DONE` | R6+R7 single pipe |
| WP-6 | `DONE` | R8 commit audit |
| WP-7 | `DONE` | R12 sealed PRE≡MOVE pathfinding |
| WP-8 | `DONE` | Gauntlet round 24 — §88 illegal-hover clear, movement-step sole voluntary-walk owner |
| WP-9 | `UNBLOCKED` | Owner may run QA when ready (static gauntlet PASS; runtime QA not run per owner policy) |

---

## Symbols eliminated (grep checklist) — `presentation/` clean

- `_active_move_drag_origin`, `_awaiting_endpoint_origin`, `_sealed_painted_leg_origin`, `_proj_move_origin` (walk)
- `_post_move_corridor_orbit_active`, `_selection_hover_corridor_paint_active`
- `_movement_slot_hover_preview_applies`, `_refresh_movement_slot_hover_preview`
- `_sync_painted_drag_route_to_preview_paths` → `_apply_voluntary_walk_drag_preview` (delegates to refresh)

---

## Changelog (matrix only)

| Date | Change |
|------|--------|
| 2026-08-29 | Gauntlet rounds 1–7: merged hover gates, phase cursor migration, drag staging extract, sealed PRE≡MOVE pathfinding, single preview pipe |
| 2026-08-29 | Round 24: §88 illegal-hover clear; unified orbit/trim; preview SSOT size>=2; movement-step voluntary-walk sole owner (no parallel sim paint) |
