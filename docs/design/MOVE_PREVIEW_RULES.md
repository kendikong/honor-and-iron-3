# Planning preview UI (owner spec)

**Status:** ACTIVE — canonical player-facing behavior for planning overlays (paths, tiles, lines).  
**Related:** `class_abilities.txt`, `PLANNING_SKILL_QA_CHECKLIST.md`, `ACTION_RANGE_LATEST_STAND.md`.

Plain-language rules. No parallel preview logic.

---

## Design principle (why this stays simple)

**Fewer global rules → fewer branches → one canonical path → fewer bugs → easier debug.**

- One rule for every **voluntary walk** (premove, MOVE module, postmove): same blue preview, same paint, same commit shape — only slot and execution order differ.
- One rule for **what preview means**: shown path = walked path.
- **Exceptions are rare and explicit** (forced push/pull UI, teleport hop) — not per-skill `if` trees.
- Do not invent a second hover, route, or preview pipeline when the global path can carry the case.

---

## What move preview is

**Move preview** = the path this character **walks** (tile to tile) to reach their **chosen destination**.

- Blue tiles, path arrow, painted route — all of that is move preview.
- **Source of truth:** what is shown is what they walk on Execute.

**Not move preview** (different UI):

- **Forced movement** on another unit — push, pull, knockback, slide, etc.
- Those use their own arrows / markers; do not mix them into the walker's blue move path.

**Teleport / blink:** Not a walked path — direct line from start tile to landing (hop). Still the character's own relocation, not push/pull UI.

---

## The one rule

**Movement step** (premove, skill MOVE module, or postmove):

- Live walk preview from **latest predicted stand** to the mouse (or along a **painted drag route** to the hovered tile).

**Any other step** (damage, target pick, wait, etc.):

- **No** live walk from the mouse.
- **No blue walk tiles** — if blue tiles appear here, that is a bug.
- **Do** keep showing **committed** walks that are not cleared yet (frozen full path).

**Modular skills** = chained mini-skills on one ability/AP. Each module finishes and hands off **stand** to the next. A damage module does not redraw or replace a walk that was already committed.

---

## Live vs frozen (planning only)

| Situation | What you see |
|-----------|----------------|
| Choosing a walk | Live path: stand → mouse (or painted route) |
| Committed a walk, now on a non-move step | **Frozen** full committed path — mouse does not draw a new one |
| Invalid hover for this movement step | **No** move preview for that step (invalid cursor only) |
| Undo a committed walk | Frozen path goes away; on a movement step again → live preview works |

**Frozen** = show the locked path, not hidden. Not live from cursor.

---

## When previews clear

All committed move previews stay visible through planning until:

1. **Ready to Execute** is pressed, or  
2. That walk **starts animating / executing**.

**Execution phase:** **Zero planning UI** — no blue tiles, no hover paths, no planning overlays. Only the actual turn playing out.

Do not add extra clear rules beyond this.

---

## Movement steps (same behavior, different slot)

**Simple rule:** If the character **moves to another tile**, that is a **blue move preview** — same look, same paint, same path truth. Only **when it commits** and **when it runs** on Execute differ.

| Step | Same as premove? | Only difference |
|------|------------------|-----------------|
| **Premove** | — | Commits to PRE slot; runs before the action |
| **MOVE module** | Same preview | Commits to the skill's MOVE leg; stand/handoff for next module |
| **Postmove** | **Exactly like premove** | Commits to POST slot; runs after the action |

**Painted routes:** Drag through blue tiles to build a path; preview follows that route to the hover tile.

**Run:** No change to current behavior — run icon already signals when Run is used.

**Teleport / blink:** Not a real walk. Preview is a **direct line** from start tile to landing tile (hop), not a stepped corridor.

---

## Latest predicted stand

Where the unit stands **after everything already committed** this turn — not necessarily turn-start. Walk preview, **blue tiles**, and **red tiles** all measure from this stand unless a rule below says otherwise.

---

## Tile colors (global)

**Two range fields** during planning (except **Wait**). Same rules everywhere.

### 1 — Current phase (locked)

The **current** module/phase range, from the stand **when this phase started**:

| Current phase | Color |
|---------------|--------|
| **Movement** (premove, MOVE module, postmove) | **Blue** — legal walk this phase |
| **Non-movement** (damage, target pick, etc.) | **Red** — where this phase can aim from that start stand |

Locked until the phase ends. Does not follow the mouse.

### 2 — Next phase (on hover)

If there **is** a next phase **and** it is **possible** from the hover tile, show that phase's range from **predicted stand at hover**:

| Next phase | Color |
|------------|--------|
| **Movement** | **Blue** |
| **Non-movement** | **Red** |

No next phase, or not possible from that tile → **no second range**.

**Faint outline** on the hover tile when it sits inside a blue or red field.

### Yellow — hover selection (Triangle Strategy style)

**Yellow** = what your **click would affect** at the current hover — movement destination tile **or** skill target footprint.

- **AOE:** show the **full affected tile set** at hover (not just the cursor cell).  
- **Non-AOE:** the single target tile.  
- **Hover only** — does **not** freeze or persist after commit; move the mouse → yellow updates.  
- **Invalid tile** — **no** yellow (invalid cursor only).

### Wait

Last planning phase before Execute. **All tiles off** — no blue, red, or yellow.

---

## Lines and arrows (global)

| What | UI |
|------|-----|
| **Voluntary walk** (premove / MOVE module / postmove) | Solid path — move preview; path = walked path |
| **Teleport / blink** | Direct **dashed** line start → landing (hop, not a walked corridor) |
| **Push / pull / forced displacement** on another unit | **Separate** UI — not blue walk path, not yellow blast |
| **Targeting intent** (e.g. strike arrow to enemy) | Separate from walk path; does not replace move preview |

---

## Co-op

Everyone sees all units' move previews. Option to hide others' previews may come later.

---

## Common bugs (do not ship)

| Symptom | Wrong because |
|---------|----------------|
| New walk arrows on damage / target step | Not a movement step |
| Blue walk tiles during non-move module | Only movement steps get blue **range** |
| Red tiles showing walk range | Red is next **non-move** module only |
| Yellow on wrong tile | Yellow = **hover-only** click footprint (AOE = full blast) |
| Yellow on invalid hover | No yellow — invalid cursor only |
| Yellow frozen after commit | Yellow does **not** freeze |
| Hover tile blends into blue/red field | Missing faint outline |
| Path on screen ≠ path walked | Preview is not truth |
| Push/pull/knockback shown as blue walk path | Forced displacement is different UI |
| Old premove ghost affects later module | Module handoff / stand wrong |
| Planning UI visible during execution | Execution = zero planning UI |

---

## Acceptance examples

- **Any walk leg:** Blue move preview — character moves tile to tile → same preview rules.  
- **Postmove:** Same as premove; only commit slot and execution order differ.  
- **Teleport:** Straight hop line, not a walked path.  
- **Tiles:** Locked field = current phase (blue move / red aim). Hover may add **next** phase field from predicted stand. Yellow = hover selection. Wait = all off.

---

## Resolved (owner 2026-08-26)

- Two ranges: **current** (locked at phase-start stand) + **next** (from hover predicted stand, if any).  
- Yellow = hover-only click footprint (AOE = full blast; Triangle Strategy style). No yellow on invalid. Does not freeze.  
- Wait = last phase; all tiles off.

---

## Implementation SSOT (code owners)

| Concern | Owner |
|---------|--------|
| Planning phase (movement / non-move / wait) | `PlanningPreviewTiles.planning_phase` |
| Two-range tile origins + yellow blast | `PlanningPreviewTiles.resolve_layer_origins` (`show_action_range` gates red/yellow once) |
| Voluntary walk path write (hover) | `CombatPlanningInput._set_preview_path` → `CombatPlanningPreview.set_unit_preview_path` |
| Painted leg seal | `CombatPlanningPreview.painted_leg_sealed` / `seal_painted_leg` |
| Route read (live + frozen + committed legs) | `CombatPlanningInput.display_*_route_cells` / `preview_board_for_display` |
| Painted drag → `preview_paths` | `_sync_painted_drag_route_to_preview_paths` → `_set_preview_path` |
| Sim / commit path merge | `apply_result`: `build_preview_paths` (sim events) + `ensure_movement_intent_from_actions` via `_commit_preview_path`; hover authoritative restore via `authoritative_paths` |
| Movement-step authority gate | `CombatPlanningInput._movement_hover_path_authoritative` |
| Painted route lock predicate | `CombatPlanningInput._painted_drag_route_matches_leg` |
| Path display (read) | `CombatPlanningPreview.display_route_cells_from_preview` / `display_committed_action_route_cells` via `CombatPlanningInput.display_move_route_cells` |
| Path data store | `CombatPlanningPreview.preview_paths` |
| Bulk route geometry copy | `CombatPlanningPreview.sync_route_geometry_from` |
| Commit-animation path read stub | `CombatPlanningPreview.preview_read_stub` |
| Tile layers (one entry + one apply) | `_recompute_hover_ranges_from_inputs` → `TacticalPlanningOverlay._apply_planning_tile_layers` |
| Action-range stand (aim origin) | `CombatPlanningInput.action_range_intent_stand_cell` (overlay `_intent_stand_origin` delegates) |
| Targeting intent arrow (live hover) | `CombatPlanningInput.targeting_intent_arrow_cells` (overlay delegates) |

### Architecture audit (2026-08-26 pass 5)

**Write paths (honest):**
- Live hover/drag/stand-stub (input): `_set_preview_path` → `set_unit_preview_path` + overlay sync.
- Intent/swap/anchor merge (preview): `_commit_preview_path` → `set_unit_preview_path` only.
- Sim timeline (preview): `build_preview_paths` from `UNIT_MOVED` events (rebuilds dict; not hover intent).
- Post-commit trim: `trim_committed_paths_after_slot_promote` → `anchor_preview_paths_to_latest_stand` → `set_unit_preview_path`.
- Overlay mirror: `apply_preview_paths_only` → `set_unit_preview_path` on `_live_preview`.

**Read paths:**
- On-screen walk routes (live + frozen committed preview): `display_move_route_cells` → `display_route_cells_from_preview`.
- Committed timeline chevrons: `display_committed_action_route_cells` only.

**Removed parallel paths (pass 5):**
- Overlay hover tile cache keyed on `_intent_stand_origin` (stale two-range risk).
- `set_hover_coord` → `_refresh_cursor_action_tiles` fork (second tile entry).
- Overlay `_intent_stand_origin` live-board duplicate (delegates to input stand SSOT).

**Pass 6 (gauntlet loop):**
- `_apply_preview_result_preserving_hover_paths` — snapshot/restore authoritative movement hover paths across `build_preview_paths` `paths.clear()`.
- `CombatPlanningPreview.set_unit_preview_path` — shared path assign for input + committed promote.
- `on_hover_moved` — single movement hover pipeline via `_refresh_movement_slot_hover_preview`.
- `tactical_side_panels` — tile refresh via `_recompute_hover_ranges_from_inputs` only.

**Pass 9 (gauntlet loop — cold-audit response):**
- Removed duplicate merge/anchor/swap from `_ensure_live_movement_intent_from_preview_actions` (merge owner is `apply_result` only).
- `_set_preview_path` always syncs overlay (`_live_preview` mirror).
- Committed ability route draw uses `display_route_cells_from_preview` first.
- Side panel tile refresh: `on_hover_moved` only (no double recompute).

**Pass 10 (gauntlet loop — critic HIGH fixes):**
- Removed `_can_show_action_range_tiles` (blast gated only by `resolve_layer_origins` `show_blast`).
- Post-commit path trim: `trim_committed_paths_after_slot_promote` only (no preview_state anchor before copy).
- Hover tile recompute: `set_hover_coord` only; `_run_hover_overlay_refresh` no longer duplicates.

**Pass 11 (awaiting / arrow SSOT):**
- `AbilitySystem.planning_awaiting_enemy_pick_active`, `planning_awaiting_target_pick_open`, `planning_modular_post_move_open` — single awaiting-module resolution for hover target, arrows, post-move open.
- `CombatPlanningInput.targeting_intent_arrow_cells` — one enemy-pick append path; `_awaiting_ability_for` / `_awaiting_action_for` / `_awaiting_permits_hover_unit_target` replace inline phase branches in `_resolve_hover_attack_target`.
- Overlay `targeting_intent_arrow_cells` delegates to input; movement-endpoint ghosts use `awaiting_movement_endpoint_ghost_visible` (not `action_range_visible_for_hover`).
- Removed `presentation/*.gd.wip` scratch copies.

**Pass 12 (path write / read closure):**
- `assign_preview_path_dict` + `set_unit_preview_path` — sole assign API for intent/anchor/swap merge writes (`_commit_preview_path` in preview).
- `build_preview_paths` remains sim-event builder only (clears + rebuilds from `UNIT_MOVED` events); `preview_post_splits` owned here only (POST_ACTION index).
- `display_committed_action_route_cells` — sole committed chevron read (overlay no longer chains `movement_intent_cells` locally).
- `apply_preview_paths_only` mirrors via `set_unit_preview_path` (no direct `_live_preview.preview_paths[…]` write).

**Pass 13 (residual SSOT closure):**
- `sync_route_geometry_from` — sole bulk route copy (promote, awaiting restore, `copy_from` route half); replaces scattered `preview_paths = …` dict assigns.
- `preview_read_stub` — sole commit-animation read stub for `CombatDirector._finalize_planning_commit_move_event`.
- `assign_preview_path_dict` no longer accepts `post_splits` (removed footgun).
- `display_committed_action_route_cells` — frozen preview → `committed_action_route_leg` → plan `waypoints` only (no ability-movement heuristic fallback).
- Hover tile faint outline only when cell is inside blue/red/yellow field (`_draw_hover_tile_on`).
- Execution phase: no `_route` fallback draw outside planning (`_draw`).
- **Perf deferrals retained (approved):** `_deferred_preview_pending`, `_hover_preview_lru`, `_hover_recompute_pending` — overlay batching only, not alternate preview truth.

**Pass 14 (read-path closure):**
- `CombatPlanningInput` owns route **reads**: `display_move_route_cells`, `display_committed_move_route_leg`, `display_frozen_route_cells`, `preview_board_for_display`, `clear_hover_route_preview`.
- Overlay route draw delegates to input; `_active_preview()` retained for intents/live_intents only.
- `painted_leg_sealed` on `CombatPlanningPreview` replaces parallel `_frozen_painted_leg_routes` buffer.
- `sync_route_paths_from` — path-only bulk copy; `restore_committed_display` **clears** live route geometry (does not mirror committed paths into live/input).
- `painted_move_route_locked` only during `active_movement_planning_step`; sealed-leg restore runs before stand-restore in `_refresh_selected_interaction_preview`.
- `committed_move_route_leg` / `display_committed_action_route_cells` — preview slice only (no geometry fallback).
- Overlay `_route` storage removed; drag SSOT is `CombatPlanningInput._drag_route`.
- `action_range_visible_for_hover` documented as economy gate (below).

**Pass 15 (display read APIs + commit ratify):**
- `CombatPlanningInput.display_committed_action_route_cells`, `display_units_with_route_preview`, `preview_push_draw_sources` — overlay reads routes/pushes through input only.
- `display_frozen_route_cells` always reads committed preview (no live bleed on other-unit dashed routes).
- `display_move_route_cells` gates live corridor to `active_movement_planning_step` only.
- `CombatPlanningPreview.clear_unit_preview_path` — single erase owner for stale painted routes.
- `_skip_committed_move_leg_draw` only hides frozen legs during active movement step (frozen visible on DAMAGE/targeting).
- `_drag_route_commits_active` includes `_drag_drop_finishing`; `_ratify_painted_route_on_commit_slots` + painted-route trust in `_append_move_to_commit_slots` — commit ratifies preview waypoints/run (no silent `find_path`).
- `CombatDirector._finalize_planning_commit_move_event` uses `action.waypoints` before pathfind fallback.
- Removed dead `sync_preview_state_from_committed`, `_active_preview()`.

### Action-range economy gate

`CombatPlanningInput.action_range_visible_for_hover` hides red/yellow when the selected skill cannot be planned from the hover/projected stand. `resolve_layer_origins` still owns tile geometry; this gate owns legality.
