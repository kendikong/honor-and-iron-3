# Move preview — implementation log (agents only)

**This is not the owner rules.** Do not treat Pass notes or symbol tables as policy.

**Owner rules (short):** [`MOVE_PREVIEW_RULES.md`](MOVE_PREVIEW_RULES.md)  
**Intent truth (absolute):** `.cursor/rules/move-preview-intent-truth.mdc`

Archived build diary moved out of the rules doc on 2026-08-30 so global rules stay short and code stays one-path.

---

## Implementation SSOT (code owners)

| Concern | Owner |
|---------|--------|
| **Timeline phase + forecast stand at phase entry** | `CombatPlanningPreview.planning_move_origin_cell` / `planning_move_origin_cell_for_timing` (+ sealed leg `preview_paths[unit][0]`). Input/overlay **delegate** — no second origin stack. |
| Planning phase kind (movement / non-move / wait) | `PlanningPreviewTiles.planning_phase` |
| Two-range tile origins + yellow blast | `PlanningPreviewTiles.resolve_layer_origins` (`show_action_range` gates red/yellow once) |
| Voluntary walk pipeline (preview → commit) | One path: hover paint → `_try_commit_voluntary_walk` → `commit_from_slots` → `_plan_for_timing` / `timeline_column` metadata only |
| Voluntary walk path write (hover) | `CombatPlanningInput._write_voluntary_walk_preview_path` → `CombatPlanningPreview.set_unit_preview_path` |
| Sealed-leg hover policy | `PlanningRoutePolicy` (no PRE/MOVE/POST labels) |
| Painted leg seal | `CombatPlanningPreview.painted_leg_sealed` / `seal_painted_leg` |
| Route read (live + frozen + committed legs) | `CombatPlanningInput.display_*_route_cells` / `preview_board_for_display` |
| Painted drag → `preview_paths` | `_apply_voluntary_walk_drag_preview` → `_write_voluntary_walk_preview_path` |
| Sim / commit path merge | `apply_result`: `build_preview_paths` (sim events) + `ensure_movement_intent_from_actions` via `_commit_preview_path`; hover authoritative restore via `authoritative_paths` |
| Movement-step authority gate | `CombatPlanningInput._movement_hover_path_authoritative` |
| Painted route lock predicate | `CombatPlanningInput._painted_drag_route_matches_leg` |
| Path display (read) | `CombatPlanningPreview.display_route_cells_from_preview` / `display_committed_action_route_cells` via `CombatPlanningInput.display_move_route_cells` |
| Path data store | `CombatPlanningPreview.preview_paths` |
| Bulk route geometry copy | `CombatPlanningPreview.sync_route_geometry_from` |
| Commit-animation path read stub | `CombatPlanningPreview.preview_read_stub` |
| Tile layers (one entry + one apply) | `_recompute_hover_ranges_from_inputs` → `TacticalPlanningOverlay._apply_planning_tile_layers` |
| Action-range stand (aim origin) | Delegates to **Timeline phase + forecast stand** row — `action_range_intent_stand_cell` / `_intent_stand_origin` must not fork origin logic |
| Targeting intent arrow (live hover) | `CombatPlanningInput.targeting_intent_arrow_cells` (overlay delegates) |
| Post-commit hover/range/cursor truth | `CombatPlanningInput._apply_post_commit_hover_truth` (sole owner; called from `_promote_intent_preview_after_commit` after `preview_board = null`) |
| In-place attack stand anchor (not walk) | `CombatPlanningPreview.set_unit_stand_anchor_path` — size-1 `[stand]` only; **not** `set_unit_preview_path` (voluntary-walk size≥2 guard) |

### Architecture audit (2026-08-26 pass 5)

**Write paths (honest):**
- Live hover/drag voluntary-walk (input): `_write_voluntary_walk_preview_path` → `set_unit_preview_path` (paths require size≥2; illegal hover clears) + overlay sync.
- In-range attack hover at stand (no approach): `set_unit_stand_anchor_path` (size-1 stand anchor; not a walk route).
- Intent/swap/anchor merge (preview): `_commit_preview_path` → `set_unit_preview_path` only.
- Post-commit hover truth (input): `_promote_intent_preview_after_commit` → `_apply_post_commit_hover_truth` (restore display → recompute ranges → refresh interaction → `_flush_hover_heavy_sync` → cursor).
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
- `_write_voluntary_walk_preview_path` always syncs overlay (`_live_preview` mirror).
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
- Drag/hover preview trim, `_write_voluntary_walk_preview_path`, `_route_pathfinding_ability`, `_should_strip_action_from_basic_postmove_slots` — use POST-open / painted-leg predicates instead of `force_basic_movement`.

**Pass 25 (Wave E6b — compile fix + hover-flush clamp — 2026-08-29):**
- `_extend_drag_route` / `_can_move_to` — restore `mt` (`unit.definition.movement_type`) removed during E4 sanitize; fixes headless compile cascade (bruiser/swap/CM-11 fixture failures).
- `_run_hover_sim_refresh` postmove drag clamp uses `_post_move_basic_planning_open` (missed E6 site).
- `_movement_preview_resync_after_sim_allowed` uses `_post_move_basic_planning_open` instead of `force_basic_movement`.

**Pass 26 (Wave E6b — economy recursion + awaiting corridor legality — 2026-08-29):**
- `_voluntary_walk_economy_open` — breaks `_basic_move_allowed` ↔ `_post_move_basic_planning_open` stack overflow; economy gate is awaiting-target-pick + dash only.
- `_awaiting_voluntary_walk_corridor_active` hover paint / applies — require `_can_move_to` before corridor (armed_move_hover stand-only when illegal).
- `_drag_route_commits_active` — leg-matched sealed painted route stays active during MOVE-module awaiting (painted orbit commit parity).
- `_route_pathfinding_ability` — sealed painted leg orbit uses basic walk (`null` ability), not trample pathfind, when not dragging.
- `_refresh_movement_slot_hover_preview` — awaiting stand fallback when `!_can_move_to` (stand tile, not stale corridor).
- **Closed (2026-08-29):** `painted_landing_hover` requires frozen `fixed_route` on the same armed+sealed state (conflicting orbit expectations). **Fixed (2026-08-29):** sealed leg always uses basic-walk in `_basic_walk_pathfinding_active`, `_route_pathfinding_ability`, and `_corridor_waypoints_to_cell` — PRE ≡ MOVE-module pathfinding.

**Pass 27 (Wave E7 — remove Force Basic Movement + voluntary-walk owners — 2026-08-29):**
- **Removed:** `force_basic_movement` var, drag-time force-basic toggles, `GameSettings.planning_force_basic`, left-panel **Force Basic Movement** checkbox (`tactical_side_panels.gd`).
- **Added:** `_voluntary_walk_planning_active()` (timeline movement-step truth), `_movement_planning_excluding_autorun()` (breaks auto-run ↔ movement-step recursion), `_skill_commit_path_active()` (armed-skill commit path; replaces `not force_basic` on enemy/ally/skill slots).
- **Unified:** `_voluntary_walk_corridor_paint_active()` single corridor gate; `_post_move_corridor_orbit_active()` for POST-only orbit; sealed hover may fall through when corridor paint is active.
- **Tests:** stripped `force_basic_movement = …` from harnesses; `live_movement_timeline_qa_mixin` deselects skill (`selected_ability_index = -1`) for basic-walk legs; removed `_test_force_basic_flag`.
- **Closed (2026-08-29):** `charge_strike_composite` / `painted_landing_hover` orbit modes unified under `_refresh_voluntary_walk_hover_preview` + `PlanningRoutePolicy`; sealed-leg pathfinding unified (pass 26–27). Legacy `PlanningQaGate.tscn` checklist rows may still drift — gate uses T3 mimic parity suite only.

**Pass 28 (Sealed-leg hover policy owner — 2026-08-29):**
- **Policy API:** `PlanningRoutePolicy.sealed_leg_hover_mode(is_sealed, route_len, voluntary_walk_paint, is_hover_move_tile, is_hover_attack_target)` → `NONE | FREEZE_LANDING | RESTORE_ONLY | EXTEND_CORRIDOR`. Helpers: `hover_rewrite_allowed`, `should_restore_locked_route`, `use_basic_walk_corridor_legality`, `allows_awaiting_relocation_hop`.
- **Inputs only:** sealed route length, voluntary-walk corridor paint active (`_voluntary_walk_corridor_paint_active`), walk-geometry intent (`_hover_extends_walk_geometry` — not `_is_hover_move_cell`; legality stays in `_can_move_to`), enemy-at-cell intent. No ability id, skill names, or PRE/MOVE/POST slot labels.
- **Geometry SSOT:** `CombatPlanningPreview.voluntary_walk_corridor_waypoints` — PRE unarmed premove and MOVE-module awaiting share one `corridor_waypoints_to_cell` builder (basic walk, `ability = null`).
- **Wired:** `_sealed_leg_hover_mode`, `_sealed_leg_hover_restore_if_blocked`, `live_move_hover_rewrite_applies`, `_refresh_hover_interaction_preview`, `_sync_movement_preview_after_hover_sim`, `on_hover_moved` (cell-changed paint/restore), `_refresh_movement_slot_hover_preview` / `_movement_slot_hover_preview_applies`, `_write_movement_hover_preview_paths` (relocation hop), `_assemble_voluntary_walk_preview_path`, `_corridor_waypoints_to_cell`, `_route_pathfinding_ability`, `_can_move_to` sealed-orbit legality.
- **Removed:** sealed-orbit `MovementSystem.find_path` shortcut in `_corridor_waypoints_to_cell`; E7 band-aids (`not voluntary_walk` + sealed-route-size checks blocking relocation hop); duplicate restore blocks (`painted_move_route_locked` + `_sealed_painted_preview_active` parallel paths); `live_move_hover_rewrite_applies` unconditional sealed+voluntary_walk `return true`; `frozen_landing_required` policy parameter (folded into `not voluntary_walk_corridor_paint` → `FREEZE_LANDING`).
- **PRE ≡ MOVE-module:** by construction — same policy mode + same `voluntary_walk_corridor_waypoints` for corridor extend; timeline/slot only changes execution order.
- **Pass 28b (completion):** `_sealed_leg_structurally_locked` + `painted_move_route_locked(unit, cell)` delegates per-cell block to policy; `_voluntary_walk_hover_paint_applies` unifies PRE/MOVE-module/POST hover paint eligibility; `on_hover_moved` `allow_hover_paint` uses `painted_move_route_locked(p_unit, cell)`.

**Pass 32 (final MED gap close — 2026-08-30):**
- **Removed:** `_planning_phase_allows_live_path_stand` (PRE/POST/SKILL_AWAITING label fork). `_voluntary_walk_planning_active`, `_basic_move_allowed`, `_movement_preview_resync_after_sim_allowed` now gate on `active_movement_planning_step` only.
- **Fixed:** `action_range_intent_stand_cell` live-path tail (`move_intent_destination`) requires `active_movement_planning_step`.
- **Fixed:** `adjust_swap_intent_actor_pose` uses `preview_board` for swap approach (not `base_board`).
- **Unified:** sealed landing on hover uses movement-step gate for all timings (not PREMOVE-only).
- **Tests:** `trampling_advance_e2e_test` uses `_phase_entry_stand` (retired `_active_move_drag_origin`).
- **Note:** Historical pass notes above may name removed symbols; current owner is `_refresh_voluntary_walk_hover_preview`.

**Pass 33 (post-commit hover truth — 2026-08-30, gauntlet round 33):**
- **Removed:** `_suppress_post_commit_hover_refresh` defer flag (bandaid). No hover side effects in `_final_commit_slots_for_interaction`.
- **Added:** `_apply_post_commit_hover_truth` — sole post-commit owner: `restore_committed_display` → `_recompute_hover_ranges_from_inputs` → `_refresh_hover_interaction_preview` → `_flush_hover_heavy_sync` → `refresh_mouse_cursor`; wired from `_promote_intent_preview_after_commit`.
- **Stand anchor:** `set_unit_stand_anchor_path` — in-range enemy attack at stand (no approach); size-1 `[stand]`; not voluntary-walk `set_unit_preview_path`.
- **Throttle:** `_begin_hover_sim_throttled_flush` timer defer is overlay-only; sim on zero-wait path and `_flush_hover_heavy_sync` before commit.

### Action-range economy gate

`CombatPlanningInput.action_range_visible_for_hover` hides red/yellow when the selected skill cannot be planned from the hover/projected stand. `resolve_layer_origins` still owns tile geometry; this gate owns legality.

---

## Attempt 7 — 2026-08-30 — Exact settlement context and receipt boundary

**Status:** OPEN — implementation pass started; 100% compliance is not claimed.

**Baseline:** The previous iteration 6 / gauntlet round 33 claims were superseded by a fresh audit. The audit found that paint was resolved before the fresh simulation board was applied, the stored receipt was externally mutable, and approved scheduling callbacks did not all validate an interaction/revision key.

**Changes in this attempt:**
- `PlanningPreviewTiles.resolve_paint` now accepts the settled simulation board and uses it for settled actor, movement, action-range, and blast geometry.
- `CombatPlanningInput._store_intent_snapshot` passes `preview_result.temp_board` into the paint resolver before sealing.
- `PlanningHoverPreview` requires a settled preview board and provides `duplicate_receipt`; `get_settled_hover_preview` returns a defensive copy.
- Click and drop interaction now pass through `on_hover_moved(cell)` before ratification when not dragging, while `_commit_at_cell` remains ratify-only.
- Ability, planning-refresh, and drag-preview callbacks capture and validate a planning interaction/revision key; bounded scheduling remains enabled under the owner-approved exception.
- The settled route snapshot is carried on the same preview result as `temp_board`; `CombatPlanningPreview.apply_result` preserves that route instead of running action-based route reconciliation over it.

**Still open for Attempt 7:** Route construction still has to be audited and consolidated so simulation-event paths, slot-derived paths, and post-commit promotion do not reconcile the same intent through separate writers.

**Verification:** Static code review only. QA remains suspended by owner mandate.
