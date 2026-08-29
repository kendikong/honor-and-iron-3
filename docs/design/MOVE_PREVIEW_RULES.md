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

**Pass 16 (MOVE module arrow suppression + blue-tile SSOT):**
- `targeting_intent_arrow_cells` — `attack_target_id` branch suppresses diagonal aim arrow during MOVE leg (`_is_awaiting_movement_endpoint` or `active_movement_planning_step` without active damage enemy-pick); DAMAGE module enemy hover still draws arrow.
- Blue move-tile extension reads `painted_corridor_waypoints_for_blue_tiles` → `display_move_route_cells` (preview_paths), not `_drag_route` peek.
- Headless contract `movement_module_hover` extended with live charge-strike MOVE module hover (enemy + dest orbit).

**Pass 17 (hover refresh SSOT + route policy + commit pathfind gate):**
- `_refresh_hover_interaction_preview(cell)` — sole **full** hover interaction owner; `_refresh_selected_interaction_preview` delegates via `_run_hover_sim_refresh`. `_sync_movement_preview_after_hover_sim` post-sim resyncs MOVE-leg corridor after sim (composite skills). `_refresh_movement_slot_hover_preview` is corridor-only inside those owners.
- `PlanningRoutePolicy.enemy_hover_respects_painted_corridor` — shared enemy-hover vs painted-corridor geometry; `CombatPlanningInput._enemy_hover_respects_painted_route` adds commit-validity probe only.
- `_append_move_to_commit_slots` — `trust_painted_route` skips `find_path` rewrite; ratifies painted waypoints.
- `CombatDirector._finalize_planning_commit_move_event` — `find_path` only when no waypoints and no stashed commit preview path for the actor.

**Pass 17 audit closure (2026-08-27):**
- **6-row SSOT:** single hover owner (`_refresh_hover_interaction_preview`); one commit ratify path (`trust_painted_route` + director painted-intent gate); no per-skill branches; overlay reads input/display APIs only; `PlanningRoutePolicy` reusable geometry; inline enemy-hover geometry removed from input.
- **Sequenced hook (not parallel truth):** `_sync_movement_preview_after_hover_sim` runs after sim refresh for composite MOVE-leg corridor — required for charge/bash frozen landing; headless `charge_strike_composite` fails if removed.
- **QA:** `run_planning_qa_gate.ps1` PASS · `run_planning_scene_acceptance.ps1` PASS (live bible session).

**Pass 18 (remove commit-time pathfind band-aids):**
- `_append_move_to_commit_slots` — no `find_path` rewrite; invalid or empty waypoints → `slots["invalid"]` (fail loud).
- `_resolve_commit_move_waypoints` — sole commit leg resolver: drag route, `destination_cells_from_route(preview, stand, dest)`, or corridor builder (never full stale preview tail).
- `_ensure_move_waypoints_on_commit_slots` — MOVE slots filled via `_resolve_commit_move_waypoints` before commit.
- `CombatDirector._finalize_planning_commit_move_event` — no `find_path` or adjacent-step invent; replays `action.waypoints` only.

**Pass 19 (MOVE preview SSOT unification — 2026-08-27):**
- `_assemble_voluntary_walk_preview_path` + `_write_movement_hover_preview_paths` — PRE / MOVE module / POST share one stand→hover assembler (forbidden trim); post-only write block removed.
- `_try_commit_voluntary_walk` — sole voluntary-walk commit entry; post early exit and general premove branch both delegate here.
- `_route_waypoints_for_commit` — delegates to `_resolve_commit_move_waypoints` (leg slice, never full preview tail).
- `_finish_movement_hover_preview_after_sim` — sequenced tail of `_refresh_hover_interaction_preview` (replaces parallel `_sync_movement_preview_after_hover_sim` callers).
- Drag illegal walk: `_sanitize_drag_route_context` corrects via `find_path` to painted destination when the leg is illegal, else trims tail (no commit-time invent).
- `_can_move_to` — legality probe only (`find_path` + forbidden trim); preview paint uses `_assemble_voluntary_walk_preview_path`.

**Pass 20 (MOVE preview waves A–C — 2026-08-28):**
- **Wave A:** Deleted post-only corridor helpers; unified `_per_hover_walk_corridor_active` for PRE/MOVE/POST orbit.
- **Wave B:** `_seal_painted_preview_landing_if_needed` seals from drag→preview sync; post-move drag-only `painted_move_route_locked`; `_discard_drag_buffer_when_preview_route_locked`.
- **Wave C:** Skill-armed premove/MOVE-leg walk hovers use `_movement_slot_hover_preview_applies` → `_hover_paint_waypoints_for_cell`; `_hover_walk_waypoints_for_skill` delegates walk legs to that owner; `preview_waypoints_for_hover` kept for enemy approach commits only.
- **Wave D:** `_can_move_to` MOVE-module legs use `CombatPlanningPreview.corridor_waypoints_to_cell` (same corridor owner as hover paint); drag-buffer `find_path` sanitize retained until waypoint paint uses corridor repath.

**Pass 21 (Wave E — premove/MOVE-module painted orbit parity — 2026-08-29):**
- **Wave E1:** `painted_move_route_locked` — sealed-leg only (not open-drag paint).
- **Wave E2:** Sealed painted leg survives `_end_drag_interaction` / `clear_hover_route_preview` / invalid sim preview; `_sealed_painted_preview_active` restore hooks.
- **Wave E3:** `_awaiting_voluntary_walk_corridor_active` — armed MOVE-module voluntary-walk corridor owner; skill hover delegates to `_refresh_movement_slot_hover_preview`; `_hover_paint_waypoints_for_cell` paints corridor on `is_hover_move_tile` for awaiting legs; authoritative movement hover skips sim stomp when `_movement_hover_path_authoritative`.
- **Gate:** `painted_route_premove_vs_move_equivalence` re-enabled in `planning_qa_gate_test.gd`.

**Pass 22 (Wave E4 — drag sanitize corridor SSOT — 2026-08-29):**
- `_sanitize_drag_route_context` — illegal painted drag repaths via `CombatPlanningPreview.corridor_waypoints_to_cell` (axis-first corridor owner); `MovementSystem.find_path` band-aid removed from drag sanitize.
- `_voluntary_walk_corridor_paint_active` — single predicate for PRE/POST orbit + MOVE-module awaiting corridor paint; `_corridor_waypoints_to_cell` painted-drag peek uses it.

**Pass 23 (Wave E5 — PRE corridor unification, drop force_basic paint gates — 2026-08-29):**
- `_post_move_basic_planning_open` / `_per_hover_walk_corridor_active` — no longer gated on `force_basic_movement`; POST openness uses timeline/modular checks only.
- `_pre_move_voluntary_walk_corridor_active` — PRE open-leg orbit corridor owner (unarmed premove + `PRE_ACTION` timing); folded into `_voluntary_walk_corridor_paint_active`.
- `active_movement_planning_step` — POST armed fallback uses `_post_move_basic_planning_open` instead of `force_basic_movement`.
- `_selection_hover_corridor_paint_active` — unarmed premove corridor via `active_movement_planning_step`, not `force_basic_movement`.

**Pass 24 (Wave E6 — preview paint no longer gated on force_basic — 2026-08-29):**
- `_basic_walk_pathfinding_active` / `_postmove_painted_drag_trim_active` — timeline-based helpers replace `force_basic_movement` in corridor pathfinding, postmove prior-leg trim, and drag preview snap.
- `_basic_move_allowed` — phase-exhaustion skip uses `_post_move_basic_planning_open`, not `force_basic_movement`.
- Premove orbit guards (`_basic_painted_drag_orbit_guard_active`, `_painted_premove_orbit_sealed`) — unarmed premove only; POST excluded via `_post_move_basic_planning_open`.
- Drag/hover preview trim, `_set_preview_path`, `_route_pathfinding_ability`, `_should_strip_action_from_basic_postmove_slots` — use POST-open / painted-leg predicates instead of `force_basic_movement`.

### Action-range economy gate

`CombatPlanningInput.action_range_visible_for_hover` hides red/yellow when the selected skill cannot be planned from the hover/projected stand. `resolve_layer_origins` still owns tile geometry; this gate owns legality.
