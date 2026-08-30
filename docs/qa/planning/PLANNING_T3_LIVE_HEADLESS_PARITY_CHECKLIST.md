# T3 Live → Headless Parity Checklist

Authoritative mapping: every checkpoint in `tests/live_planning_scene_test.gd` must have a headless fixture twin in `PlanningLiveParityHarness` (runner: `planning_t3_live_headless_checklist_test.gd`).

**Not mirrored in headless (TestBattle-only):** sprite tween positions (`_assert_actor_on_cell`), PNG trace screenshots, frame settle timing. Headless uses `flush_planning` / `settle_ability_hover` on the same production APIs.

**Runner:** `godot --headless --script res://tests/run_t3_mimic_headless.gd` includes `[SUITE] t3_live_headless_checklist`.

## Bible session — `test_live_planning_bible_multi_knight_session`

| ID | Live source | Headless owner |
|----|-------------|----------------|
| UNDO-01 | `_journey_undo_sprite_smoke` drag writes pre-move | `run_undo_sprite_smoke` |
| UNDO-02 | undoable after drag walk | `run_undo_sprite_smoke` |
| UNDO-03 | undo clears plan + home cell | `undo_until_unit_clear` |
| K1-01 | k1 1 AP / 3 MP pools | `run_k1_journey_mirror` |
| K1-02 | phase1 stand probe | `_Probe.probe_cell` K1-02/stand |
| K1-03 | hover edges (enemy/off-blue/off-map) | `probe_k1_hover_edges` |
| K1-04 | walk hover probe | K1-04/walk |
| K1-05 | enemy approach probe | K1-05/approach |
| K1-06 | push preview east | K1-06 |
| K1-07 | selection tap commit + bash committed | `run_k1_bash_live_parity` (selection) |
| K1-08 | selection post_commit red off + enemy live | parity harness |
| K1-09 | waypoint drag + waypoints on pre-move | `run_k1_bash_live_parity` (waypoint) |
| K1-10 | mode commit parity selection vs waypoint | `assert_mode_commit_parity` |
| K1-11 | committed display path ratifies pre-commit | `assert_committed_display_ratifies_pre_commit` |
| K1-12 | waypoint post_commit probes | parity harness |
| K2-01 | hook stand probe | `run_k2_journey_mirror` |
| K2-02 | hook walk probe | K2-02/walk |
| K2-03 | hook enemy + pull preview | K2-03/enemy |
| K2-04 | selection tap commit | `assert_k2_hook_committed` |
| K2-05 | undo clear | `undo_until_unit_clear` |
| K2-06 | drag commit | `commit_painted_drop_on_cell` |
| K2-07 | mode parity selection vs drag | `assert_mode_commit_parity` |
| K2-08 | AP 0 + pull west | K2-07 / K2-08 |
| K3-01 | trample stand probe | `run_k3_journey_mirror` |
| K3-02 | arm awaiting + awaiting active | K3-02 |
| K3-03 | hover east corridor | K3-03/hover_east |
| K3-04 | hover end probe | K3-04/hover_end |
| K3-05 | selection tap commit | `assert_k3_trample_committed` |
| K3-06 | undo clear | undo |
| K3-07 | drag paint commit + waypoints | `assert_k3_trample_committed` drag |
| K3-08 | drag post_commit red off | `assert_red_contract` |
| K3-09 | post-trample stand basic move | K3-09/post_stand |
| K3-10 | post hover east | K3-10/post_hover_east |
| K3-11 | post hover dest path | K3-11/post_hover_dest |
| K3-12 | post-trample drag commit | `assert_k3_post_move_committed` |
| K3-13 | post after_commit red off | K3-13/post_after_commit |
| K4-01 | k4 3 MP for run bible | `run_k4_journey_mirror` |
| K4-02 | k4 stand probe | K4-02/stand |
| K4-03 | selection route step probes + walk loop (4,2) | `run_k4_selection_route` |
| K4-04 | run trigger loop (requires Run, AP 0, red off) | `assert_k4_run_loop_preview` |
| K4-05 | selection commit + uses_run | `assert_k4_run_committed` |
| K4-06 | drag route step probes | `run_k4_drag_route` |
| K4-07 | drag commit + mode parity | `run_k4_run_live_parity` |
| K4-08 | drag post_commit red off | `assert_red_contract` |
| EXEC-01 | simulate committed final cells | `run_execute_all_plans` |

## Swap session — `test_live_swap_session`

| ID | Live source | Headless owner |
|----|-------------|----------------|
| SWAP-01 | adjacent swap hover ally | `run_swap_adjacent_premove_mirror` |
| SWAP-02 | swap commit | SWAP-02 |
| SWAP-03 | after_swap board layers | `assert_swap_board_layers` |
| SWAP-04 | L-route premove drag | SWAP-04 |
| SWAP-05 | two pre-moves after premove | SWAP-05 |
| SWAP-06 | walk-swap out-of-range hover | `run_swap_out_of_range_parity_mirror` |
| SWAP-07 | out-of-range click slots valid + commit | SWAP-07 |
| SWAP-08 | k1 stays selected | SWAP-08 |
| SWAP-09 | walk + swap pre-move types | SWAP-09 |
| SWAP-10 | board layers after click ally | SWAP-10 |
| SWAP-11 | walk-then-swap walk drag | `run_swap_walk_then_swap_mirror` |
| SWAP-12 | swap click after walk | SWAP-12 |
| SWAP-13 | two pre-moves | SWAP-13 |
| SWAP-14 | final board layers | SWAP-14 |

## Training economy (both suites)

| ID | Rule | Owner |
|----|------|--------|
| TRAIN-01 | Player units 1 AP / factory MP on training board | `TestBattleEncounterBuilder._apply_training_modifiers` |

## Gate relationship

- **Headless PASS** on this checklist = fixture parity with live **assert semantics** (not F5 pixels).
- **T3 live** (`run_planning_scene_acceptance.ps1`) still required for TestBattle boot, tweens, and settle timing.
- Default `run_planning_qa_gate.ps1` runs headless fixtures; use `-LiveTier3` for live bible.
