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

## What stays manual (Layer B — ~3 min)

1. **FPS / hover stutter** — no headless FPS yet; watch top-right counter after perf changes.
2. **Pixel authorship** — arrow colors, dashed style, threat tile outlines, ghost feet alignment.
3. **Walk animation** — unit sprite follows path smoothly (data path is tested; tween timing is not).

## Perf optimization sign-off

- [ ] Agent: `run_planning_qa_gate.ps1` → PASS
- [ ] Owner: Layer B manual items above → PASS
- [ ] Commit hash recorded in changelog

See also: `BUG_REPORT.md` (regression contract), `tests/trampling_advance_e2e_test.gd` (Trampling deep suite).
