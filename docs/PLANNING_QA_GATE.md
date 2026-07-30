# Planning QA Gate

Automated mirror of the owner's manual planning checklist (Skill Arena / TestBattle).
Use this gate **before and after every performance optimization** that touches planning,
preview, commit slots, overlay draw, or hover sim.

## Two layers

| Layer | Who | What |
|-------|-----|------|
| **A — Headless (agent)** | Cursor agent / CI | `tests/planning_qa_gate_test.gd` |
| **B — Visual (owner)** | You, F5 in Skill Arena | Short checklist below — **only** items marked *manual* |

Layer A must pass. Layer B is still required for pixel/animation/FPS.

## Run (fast — planning gate only)

```powershell
.\scripts\run_planning_qa_gate.ps1
```

Or:

```powershell
& "<godot.exe>" --headless --path . --script res://tests/run_planning_qa_gate.gd
```

Full regression (includes this gate):

```powershell
.\scripts\run_regression_tests.ps1 -GodotPath "<godot.exe>"
```

## Checklist mapping

### 1. Movement

| Manual check | Automated test | API asserted |
|--------------|----------------|--------------|
| 1A Waypoint paint order | `_test_waypoint_paint_order_preserved_on_tile_drag` | `CombatPlanningInput._drag_route` |
| 1A Autocorrect on jump drag | `_test_jump_drag_autocorrect_preserves_painted_corridor` | `_extend_drag_route` keeps E-then-N corridor |
| 1A Stale hover / invalid waypoint | `_test_stale_hover_updates_commit_waypoints`, `_test_shield_bash_hover_change_clears_stale_approach` | `_final_commit_slots_for_interaction` |
| 1B Walk / run / composite cursor | `_test_cursor_walk_run_and_composite`, Shield Bash cursor test | `_cursor_icon_from_commit_slots` |
| Walk matches preview (data) | `_test_committed_walk_preview_matches_sim_path` | commit slots → `Simulator` `UNIT_MOVED` |
| *Walk animation on screen* | — | **Manual** |
| *Arrow color / dashed style* | — | **Manual** |

### 2A. Shield Bash (reference: knight `(4,5)`, dummy `(7,5)`, approach `(6,5)`)

| Manual check | Automated test | API asserted |
|--------------|----------------|--------------|
| Pre-move + action on enemy hover | `_test_shield_bash_enemy_hover_commit_slots` | pre → `(6,5)`, action → enemy |
| Orange push away from player | `_test_shield_bash_push_away_from_player` | `preview_pushes` segment `to.x > from.x` |
| Threat at predicted push position | `_test_shield_bash_enemy_lands_at_push_destination` | `preview_board` enemy at push dest |
| Walk+skill cursor on enemy | `_test_shield_bash_enemy_hover_composite_cursor` | composite glyph |
| Stale drag waypoint rejected | `_test_shield_bash_hover_change_clears_stale_approach` | approach not `(5,5)` on enemy hover |
| *Red tile draw / orange arrow pixels* | — | **Manual** |

### 2B. Chain Hook

| Manual check | Automated test | API asserted |
|--------------|----------------|--------------|
| Dashed blue player→enemy line | `_test_chain_hook_awaiting_targeting_segment` | `AWAITING_TARGET` flow + valid endpoint segment |
| Orange pull toward player | `_test_chain_hook_pull_toward_player` | `preview_pushes` `to.x < from.x` |
| *Dashed vs solid line rendering* | — | **Manual** |

### 2C. Trampling Advance (pre-move + arm + commit)

| Manual check | Automated test | API asserted |
|--------------|----------------|--------------|
| Pre-move on timeline, then arm | `_test_trampling_premove_then_arm_commit_flow` | `plan_pre_move` + awaiting + commit |
| Preview path after pre-move + trample | same | `preview_paths` full leg |
| Sim walk order | same | `Simulator` visited cells |
| *Immediate pre-move animation, armed UI* | — | **Manual** |

### 3. Integrity extensions (headless-only)

Beyond the manual checklist — game rules that must not regress during perf work.

| Integrity rule | Automated test | API asserted |
|----------------|----------------|--------------|
| Hover is deterministic | `_test_hover_slots_are_deterministic` | same cell → identical slot signature twice |
| Commit ratifies hover (preview = intent) | `_test_commit_plan_matches_hover_slots` | hover slots == post-commit plan slots |
| Undo removes action only, keeps pre-move | `_test_undo_action_keeps_premove` | `rpc_remove_last_for_unit` preserves `plan_pre_move` |
| Shield Bash full approach + push from start | `_test_shield_bash_full_approach_push_preview` | knight `(4,5)` → approach → push east |
| Committed hook approach uses pre column | `_test_committed_hook_approach_uses_premove` | committed action + approach hover → `pre` not `post` |
| Out-of-bounds hover rejected | `_test_out_of_range_hover_is_invalid` | `(-1,0)` → `invalid` |
| Trample painted route == live preview | `_test_trample_paint_preview_matches_route` | `preview_paths` matches E-then-N corridor |
| Trample commit keeps painted waypoints | `_test_trample_commit_preserves_east_then_north` | commit slots waypoints preserved |
| Simulator walks painted trample order | `_test_trample_sim_follows_painted_order` | `UNIT_MOVED` cell order |

### 4. Intent-truth pipeline (preview = slots = commit = sim)

| Integrity rule | Automated test | API asserted |
|----------------|----------------|--------------|
| Slots → preview board enemy at push dest | `_test_bash_slots_preview_board_parity` | `_preview_from_commit_slots_at_cell` |
| Hover slots == click slots == drop slots | `_test_hover_click_drop_slot_parity` | interaction vs `_final_commit_slots_for_click_at_cell` vs `_final_commit_slots_for_drop_at_cell` |
| Selection vs drop: Shield Bash enemy | `_test_click_drop_parity_bash_enemy` | click/drop slot signature parity |
| Selection vs drop: adjacent walk | `_test_click_drop_parity_walk_adjacent` | click/drop slot signature parity |
| Selection vs drop: bash approach tile | `_test_click_drop_parity_bash_approach` | click/drop slot signature parity |
| Selection vs drop: Chain Hook enemy | `_test_click_drop_parity_hook_enemy` | click/drop slot signature parity |
| Selection vs drop: OOB invalid | `_test_click_drop_parity_oob_invalid` | both modes block commit on `(-1,0)` |
| Selection vs drop: bash cursor | `_test_click_drop_cursor_parity_bash` | `_cursor_icon_from_commit_slots` |
| Selection vs drop: walk cursor | `_test_click_drop_cursor_parity_walk` | `_cursor_icon_from_commit_slots` |
| Selection vs drop: bash commit → sim | `_test_click_drop_commit_sim_bash` | `commit_from_slots` → `Simulator` |
| Selection vs drop: walk commit → sim | `_test_click_drop_commit_sim_walk` | `commit_from_slots` → `Simulator` |
| Painted drag walk == selection walk sim | `_test_click_drop_drag_walk_sim_parity` | `_paint_drag_route` + drop vs click |
| Painted drag bash on enemy == selection | `_test_click_drop_drag_bash_enemy_parity` | approach route + drop on enemy |
| Drag-drop commit then undo clears plan | `_test_drag_drop_commit_undo_clears_plan` | `_begin_drag` → commit → `rpc_remove_last_for_unit` |
| Hover cursor == slots cursor | `_test_cursor_equals_slots_on_hover` | `compute_hover_action_icon` |
| Bash commit → sim lands at preview push | `_test_bash_commit_sim_push` | `commit_from_slots` → `Simulator` |
| Hook commit → sim matches preview pull | `_test_hook_commit_sim_pull` | preview_board then `Simulator` |
| Invalid slots cannot commit | `_test_invalid_slots_block_commit` | OOB → `preview_commit_valid` + `commit_from_slots` |
| Full slot signature ratified on commit | `_test_full_slot_signature_on_commit` | waypoints, timing, ability id |
| Ability switch clears preview cache | `_test_ability_switch_clears_preview_cache` | `_on_ability_selected` |
| Trample paint → preview → commit → sim | `_test_trample_paint_commit_sim_chain` | end-to-end chain |
| Sim determinism (same plan twice) | `_test_bash_sim_determinism` | identical enemy final cell |
| Hover order stable (approach ↔ enemy) | `_test_hover_order_invariant` | `_intent_slot_signature` |
| Drag cancel restores bash enemy intent | `_test_drag_cleared_restores_canonical_bash_intent` | baseline vs restored slots |
| Approach+bash slots preview keeps push | `_test_approach_bash_slots_preview_keeps_push` | slots→preview `preview_pushes` |
| Timeline ghost clears when committed | `_test_timeline_ghost_clears_when_committed` | `timeline_ghost_slots` |

## What stays manual (Layer B — ~3 min)

1. **FPS / hover stutter** — no headless FPS yet; watch top-right counter after perf changes.
2. **Pixel authorship** — arrow colors, dashed style, threat tile outlines, ghost feet alignment.
3. **Walk animation** — unit sprite follows path smoothly (data path is tested; tween timing is not).

## Perf optimization sign-off

- [ ] Agent: `run_planning_qa_gate.ps1` → PASS
- [ ] Owner: Layer B manual items above → PASS
- [ ] Commit hash recorded in changelog

See also: `BUG_REPORT.md` (regression contract), `tests/trampling_advance_e2e_test.gd` (Trampling deep suite).
