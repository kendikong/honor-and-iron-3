# Planning refactor matrix (survives summarization)

**Status:** ACTIVE — read this **first** after any chat summarization before planning or combat input work.  
**Owner policy:** `docs/design/MOVE_PREVIEW_RULES.md` § **Timeline model**  
**Hard gate (owner):** **NO testing** (`tests/`, `run_*`, F5 QA) until an agent claims **100% rule abidance** on this matrix (every row `DONE`).

**Latest gauntlet (2026-08-29):** Round 1 score **61/100** (threshold 85) — **FAIL**. Round 2 in progress after R5/R6/R12 partial fixes. **100% claim not yet posted.**

---

## Canonical invariant (one paragraph)

A turn is a **timeline of phases** (premove → skill modules → postmove). **Forecast stand at phase entry** is the only origin for the **current** phase (walk, locked blue/red). **One voluntary-walk pipeline** (hover → paint → commit); **only action metadata** differs: timeline column/slot, `move_timing`, animate-on-commit (PRE during planning vs POST on Execute). Next-phase tiles use **forecast at hover** — same forecast system, different branch.

---

## Rule abidance matrix

Mark each row `TODO` | `WIP` | `DONE`. **100% claim** = all rows `DONE` + work packages `WP-*` `DONE`.

| ID | Rule | Target owner (code) | Drift to remove | Done when (no tests) | Status |
|----|------|---------------------|-----------------|----------------------|--------|
| R1 | Forecast stand at **phase entry** = walk + locked tile origin | `CombatPlanningPreview.forecast_stand_at_phase_entry` | ~~`_active_move_drag_origin`, `_awaiting_endpoint_origin`, duplicate POST branches~~ | All walk/corridor/drag call sites use R1 API only | `DONE` |
| R2 | Sealed leg = **lock** phase-entry anchor (`route[0]`), not second origin system | Same R1 API (sealed branch) | ~~Input-only `_sealed_painted_leg_origin` stack~~ | Sealed orbit uses R1; no separate origin ladder | `DONE` |
| R3 | Action range **delegates** to R1 (+ armed-tile lock only) | `action_range_intent_stand_cell` → R1 | Custom ladder, `live_path[-1]` for **locked** current-phase red | Locked aim/move origins match R1; exceptions documented | `WIP` |
| R4 | **Intent truth:** preview origin + path = commit origin + path | `_assemble_voluntary_walk_preview_path` + `_resolve_commit_move_waypoints` + `_append_move_to_commit_slots` | ~~`_proj_move_origin` on commit vs `_active_move_drag_origin` on paint~~ | Same R1 at paint and commit; no divergent helpers | `DONE` |
| R5 | **One timeline phase cursor** (where am I on the plan?) | `CombatDirector.planning_timeline_phase_kind` | Scattered `active_movement_planning_step`, `_post_move_basic_planning_open`, `_voluntary_walk_planning_active`, timing-only guesses | One read API; input/overlay/tiles consume it | `WIP` |
| R6 | **One voluntary-walk hover pipe** | `on_hover_moved` → single `_refresh_voluntary_walk_hover_preview` | `_selection_hover_corridor_paint_active`, parallel slot vs selection refresh | One hover refresh + `_voluntary_walk_hover_paint_applies` gate | `WIP` |
| R7 | **One corridor / paint geometry** | `CombatPlanningPreview.voluntary_walk_corridor_waypoints` + `PlanningRoutePolicy` | Per-PRE/POST/skill paint branches, `_post_move_corridor_orbit_active` as separate pipe | Corridor/paint gated by phase cursor + policy only | `WIP` |
| R8 | **One voluntary-walk commit entry** | `_try_commit_voluntary_walk` → `_build_commit_slots_at_cell` → `commit_from_slots` | `rpc_plan_move` bypass for player voluntary walk (audit autobattler separately) | Player walk always ratifies preview waypoints | `WIP` |
| R9 | Commit **metadata only:** slot / `move_timing` / animate-on-commit | `TimelineAction` + `_plan_for_timing` + `_move_commits_with_planning_anim` | New per-phase commit/preview forks | No new `if PRE` / `if POST` beyond metadata stamping | `DONE` |
| R10 | Tile layers: locked current phase from R1 | `PlanningPreviewTiles.resolve_layer_origins` | ~~`locked_move` vs `locked_aim` using different origin stacks~~ | Both locked origins = R1 | `DONE` |
| R11 | Next-phase hover = forecast at hover (not R1) | `predicted_stand_at_hover` | Confusing with phase-entry origin | Documented branch only; no second paint pipe | `DONE` |
| R12 | PRE ≡ MOVE-module voluntary walk (policy + geometry) | `PlanningRoutePolicy` + `voluntary_walk_corridor_waypoints` | Slot-labeled hover policy | Policy inputs have **no** PRE/MOVE/POST labels | `WIP` |

---

## By design (NOT matrix failures)

| Item | Why allowed |
|------|-------------|
| `move_timing` / timeline column on action | Metadata on same pipe (R9) |
| PRE animates on commit; POST on Execute | `_move_commits_with_planning_anim` from timing |
| Armed tile-target range lock | In-phase sub-state (R3 exception) |
| Teleport/blink hop line | Movement **kind**, not voluntary walk corridor |
| Forced push/pull UI | Not voluntary walk |
| `_try_finalize_awaiting_from_slots` | Skill finalize wrapper — waypoints must still match preview (R4) |
| `rpc_plan_move` | Autobattler / network batch only — **not** player voluntary-walk SSOT (R8 by design) |
| `_drag_route` extend in `on_hover_moved` | Input buffer staging — preview write must still ratify via voluntary-walk refresh (R6) |

---

## Work packages (execution order)

| ID | Depends | Scope | Primary files | Status |
|----|---------|-------|---------------|--------|
| WP-1 | — | **R1 + R2:** Add `forecast_stand_at_phase_entry`; wire sealed `[0]`; delete input origin stacks | `combat_planning_preview.gd`, `combat_planning_input.gd` | `DONE` |
| WP-2 | WP-1 | **R4:** Commit path uses R1; remove `_proj_move_origin` from walk commit | `combat_planning_input.gd` | `DONE` |
| WP-3 | WP-1 | **R3 + R10:** Range + tile layers delegate to R1 | `combat_planning_input.gd`, `planning_preview_tiles.gd`, `tactical_planning_overlay.gd` | `WIP` |
| WP-4 | — | **R5:** Phase cursor owner + migrate gates | `combat_director.gd`, `combat_planning_input.gd` | `WIP` |
| WP-5 | WP-4 | **R6 + R7:** Single hover refresh; collapse selection/slot/post orbit forks | `combat_planning_input.gd` | `WIP` |
| WP-6 | WP-2 | **R8:** Audit commit paths; route player voluntary walk through slots | `combat_planning_input.gd`, `combat_director.gd` | `WIP` |
| WP-7 | WP-1–6 | **R12:** Fix known orbit divergence in **production** (equivalence cause, not test edits) | `combat_planning_input.gd`, `planning_route_policy.gd`, `combat_planning_preview.gd` | `TODO` |
| WP-8 | WP-1–7 | **Claim 100%:** Agent walks R1–R12 + WP table; update Status column to `DONE` | This file | `TODO` |
| WP-9 | WP-8 + owner OK | **Testing phase only after WP-8:** planning gate, regressions, test realignment | `tests/`, `scripts/run_*` | `BLOCKED` |

---

## Gauntlet blockers (round 1 — must clear for WP-8)

1. **R6:** `on_hover_moved` inline `_extend_drag_route` / `_sync_painted_drag_route_to_preview_paths` parallel to `_refresh_voluntary_walk_hover_preview`.
2. **R5:** `get_planning_move_timing` / `_post_move_basic_planning_open` still dominate over `planning_timeline_phase_kind` at many call sites.
3. **R7:** `_voluntary_walk_postmove_open`, `_postmove_painted_drag_trim_active`, `_per_hover_corridor_overrides_drag_paint` — POST-named geometry forks.
4. **R3:** `live_path[-1]` in `action_range_intent_stand_cell` during movement step — documented exception; matrix DONE requires locked-red never uses it.
5. **R12 / WP-7:** PRE vs MOVE-module sealed orbit divergence (MOVE_PREVIEW_RULES passes 26–28).

---

## File touch map (quick grep anchors)

| File | Role after refactor |
|------|---------------------|
| `presentation/combat_planning_preview.gd` | R1 forecast stand; corridor geometry |
| `presentation/combat_planning_input.gd` | Thin delegate; one hover pipe; commit ratify |
| `presentation/combat_director.gd` | R5 phase cursor; timeline metadata on add |
| `presentation/planning_preview_tiles.gd` | R10 locked origins via R1 |
| `presentation/tactical_planning_overlay.gd` | Delegate stand/range; no origin math |
| `core/systems/planning_route_policy.gd` | Sealed hover modes (no slot labels) |
| `docs/design/MOVE_PREVIEW_RULES.md` | Owner spec (already tightened) |

---

## Symbols to eliminate (grep checklist)

When refactor is complete, these should be **gone or thin delegates** only:

- `_active_move_drag_origin` → R1
- `_awaiting_endpoint_origin` → R1
- `_sealed_painted_leg_origin` → R1 sealed branch
- `_proj_move_origin` for **walk** (may remain for non-walk sim helpers — audit each call)
- `_post_move_corridor_orbit_active` as separate pipe → phase cursor
- `_selection_hover_corridor_paint_active` → merged into voluntary-walk gate
- `_movement_slot_hover_preview_applies` / `_refresh_movement_slot_hover_preview` → merged into `_voluntary_walk_hover_paint_applies` / `_refresh_voluntary_walk_hover_preview`

---

## 100% claim protocol (agent)

Before **any** test or `tests/` edit:

1. Set every **R1–R12** row to `DONE` with one-line evidence (function name, not “seems fixed”).
2. Set every **WP-1–WP-8** to `DONE`.
3. Grep symbols-to-eliminate — zero walk-origin logic outside R1.
4. Post in chat: **“100% rule abidance claimed per PLANNING_REFACTOR_MATRIX.md”** + commit hash.
5. **Only then** WP-9 (owner must not have forbidden testing earlier).

If any row is not `DONE`, claim is **forbidden**.

---

## Known open behavior (fix in WP-7, not tests)

Documented in `MOVE_PREVIEW_RULES.md` passes 26–28:

- PRE vs MOVE-module sealed orbit divergence on some cells
- `painted_landing_hover` frozen landing vs corridor-orbit dual owner
- `charge_strike_composite` armed + sealed expectations

---

## Changelog (matrix only)

| Date | Change |
|------|--------|
| 2026-08-29 | WP-1/2/4 partial: `forecast_stand_at_phase_entry`, `_phase_entry_stand`, eliminated origin stacks; `planning_timeline_phase_kind` added |
| 2026-08-29 | Gauntlet round 1: score 61/100 FAIL. Merged `_movement_slot_hover_preview_applies` → `_voluntary_walk_hover_paint_applies`; `_movement_planning_excluding_autorun` uses phase cursor; removed duplicate corridor function; R8 rpc comment. R6/R7/R8 still WIP. |
