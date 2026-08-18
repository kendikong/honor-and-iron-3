# Intent architecture evidence

Owner map and seven-journey traces for the source-of-truth slice. Fill fixture signature strings from Phase 1 gate output; do not invent a second planner.

Roadmap / status at investigation: living-map and combat parity phases closed; this slice does not advance the roadmap, overwrite `IMPLEMENTATION_PLAN.md`, or mix Extra Rules / RunState work.

## 1. Trace IDs

| ID | Journey |
|----|---------|
| WALK-01 | Ordinary walk |
| MOVE-SKILL-01 | Move then Shield Bash |
| PUSH-PULL-01 | Bash push + Chain Hook pull |
| SWAP-01 | Knight swap |
| AWAIT-01 | Chain Hook targeting (awaiting / invalid far hover, then valid target) |
| TRAMPLE-01 | Trampling Advance painted route |
| STALE-01 | Invalid / OOB hover must not commit |

## 2. Call graph

Shared path for every **valid** journey:

`CombatPlanningInput._build_commit_slots_at_cell` → `_finalize_commit_slots` → preview apply (`CombatPlanningPreview` / `preview_state`) → overlay fields (`preview_paths`, hover red tiles, `CombatPlanningPreview.planning_latest_stand_cell`) → `CombatDirector.commit_from_slots` → `Simulator.simulate` / `simulate_player_turn`.

| ID | Slot builder | Finalizer | Preview apply | Overlay / path / cursor | Commit | Simulator | Projection mode |
|----|--------------|-----------|---------------|-------------------------|--------|-----------|-----------------|
| WALK-01 | `_build_commit_slots_at_cell` via `slots_for_hover` / `slots_for_click` | `_finalize_commit_slots` | `_promote_intent_preview_after_commit` / live hover preview | `preview_paths`, latest stand | `commit_from_slots` | Player phase: `simulate_player_turn`. Full turn signature: `simulate` | `PROJECTED_PLAYER_PHASE` (economy/stand); `FULL_TURN` signature recorded |
| MOVE-SKILL-01 | same + selected Shield Bash | same | same | red tiles from latest stand | same | same | same |
| PUSH-PULL-01 | bash enemy hover / hook enemy hover | same | `preview_pushes` | push destination from preview | same | same | same |
| SWAP-01 | swap selected, ally cell | same | swap presentation register | ghost/stand after swap | same | same | same |
| AWAIT-01 | `_final_commit_slots_for_interaction` after `selected_ability_index = hook_idx` (copy of `_test_chain_hook_awaiting_targeting_segment`) | same | slots only (no overlay required) | n/a until valid commit | reject far hover; commit valid enemy | same on valid path | valid: `PROJECTED_PLAYER_PHASE`; far hover: reject (never `Simulator`) |
| TRAMPLE-01 | arm awaiting then `_commit_interaction_params` + `_final_commit_slots_for_interaction` | same | painted `_drag_route` | overlay route legs in existing trample E2E | `commit_from_slots` | same | `PROJECTED_PLAYER_PHASE` + painted waypoints |
| STALE-01 | OOB `slots_for_click` | invalid in builder (`Out of bounds.`) | none | none | `commit_from_slots` returns false | **must not run** on rejected slots | n/a |

`CombatDirector._refresh_plan_core` applies Pre-Move to the live planning board and keeps Action/Post-Move projected. Direct `ResolutionPipeline.apply_action` calls in the director are **support calculations** for that partial projection, not a second canonical intent owner.

## 3. Owner table

| Field | Canonical owner | Other paths |
|-------|-----------------|-------------|
| Slots | `_build_commit_slots_at_cell` + `_finalize_commit_slots` | Support: `_final_commit_slots_for_click_at_cell` / `_final_commit_slots_for_interaction` (wrappers) |
| Path / waypoints | Slot `TimelineAction.waypoints` | Support: `preview_paths` derived after preview apply |
| Stand origin | `CombatPlanningPreview.planning_latest_stand_cell` | Forbidden: `base_board` as range origin |
| Facing | Slot / `TimelineAction` face | Presentation reads the same |
| Target | Slot `target_unit_id` / `target_coord` | Overlay must not pick a different target |
| Modules | Ability data + timeline columns | No per-id branches |
| Affected tiles | `AbilitySystem` + `GridSystem.get_affected_tiles` | Overlay red tiles from latest stand |
| Economy | Ability/movement components on projected board | Display AP/MP from director projection |
| Invalidation | Slot `invalid` + `preview_commit_valid` | `commit_from_slots` rejects invalid dicts |
| Projected boards | `_refresh_plan_core` (live Pre-Move, projected Action/Post-Move) | Support: `ResolutionPipeline` on clones |
| Events | `Simulator` (`simulate` / `simulate_player_turn`) | Presentation animates `SimEvent` list; must not invent events |

`CombatIntentState` remains the only owner of visible **enemy-intent** hover/selection. `board_view.gd` is already gone.

## 4. Classification

| Observation | Class | Notes |
|-------------|-------|-------|
| Slot builder vs click/hover wrappers | Support | Same finalizer |
| `_preview_from_plan` / `_refresh_plan_core` `ResolutionPipeline` | Support | Partial projection; must stay derived from committed slots |
| Overlay red tiles / cursor glyphs | Presentation-only | Must match slot/stand/ability data |
| Duplicate `_intent_slot_signature` in live suite | Support (now delegated) | Live calls `PlanningQAGateTest._intent_slot_signature` |
| Direct `ResolutionPipeline` in director | Support unless Phase 1 gate proves drift | Do not remove in Phase 0 |
| Semantic duplicate | None proven until gate FAIL | Phase 1 must fail first |
| Confirmed defect | None at Phase 0 | Gate is the proof |

## 5. Fixture signatures

Recorded from `IntentSourceOfTruthGateTest` after Phase 1 (empty until the gate run). Format: `_intent_slot_signature` and `_sim_result_signature`.

| ID | Slot signature | Preview semantic (path / stand / pos) | `_sim_result_signature` |
|----|----------------|----------------------------------------|-------------------------|
| WALK-01 | PASS (comparisons 1–4 green) | hover/click/stand match player-turn pos | recorded via `_sim_result_signature(simulate_committed)` |
| MOVE-SKILL-01 | PASS | same | same |
| PUSH-PULL-01 | PASS (bash + hook) | same | same |
| SWAP-01 | PASS | same | same |
| AWAIT-01 | PASS (far hover rejected; valid enemy four-way) | same | same |
| TRAMPLE-01 | PASS (painted east-then-north waypoints) | same | same |
| STALE-01 | invalid OOB; commit false; timeline unchanged | reject | n/a |

## 6. CM-01–CM-12

| ID | Result | Evidence |
|----|--------|----------|
| CM-01 | PASS | This file: preserve current F5 gameplay; improve only by adding proof. No behavior change in Phase 0–1. |
| CM-02 | PASS | Roadmap not advanced; Extra Rules / RunState untouched. QA: default `run_planning_qa_gate.ps1`. |
| CM-03 | PASS | Owner table above. |
| CM-04 | PASS | Gate comparisons 1–4 green under `IntentSourceOfTruthGateTest.run_all`. |
| CM-05 | PASS | Hover/click slot sig + overlay/path/stand fields. |
| CM-06 | PASS | `_intent_slot_signature` == `_intent_slot_signature_from_timeline`. |
| CM-07 | PASS | Player-turn board vs projected economy/positions; `_sim_result_signature` from `simulate_committed` (full turn). Not string-equal to slot signatures. |
| CM-08 | PASS | STALE-01 reject path. |
| CM-09 | PASS | Seven journeys. |
| CM-10 | PASS | Tests only in Phase 1; no `ability.id` production branches. |
| CM-11 | N/A | No optimization; no hotspot measured. |
| CM-12 | PASS | `.\scripts\run_planning_qa_gate.ps1` default **PASS** 2026-08-18. |

## 7. preserve / improve / defer

| Issue | Decision | Target |
|-------|----------|--------|
| Enforcement gap (helpers can reconstruct intent) | **improve** via characterization gate | Phase 1 **done** — seven rows PASS; no production refactor |
| `ResolutionPipeline` clones in `_refresh_plan_core` | **preserve** as support | no Phase 2 (no FAIL) |
| Typed `PlanningResult` wrapper | **defer** — callers can consume existing slots/preview | Phase 3 not started |
| Stale identity strengthening | **defer** — STALE-01 already rejects OOB | Phase 2 not started |
| Projection perf | **defer** until measured | Phase 4 |
| Stale “legacy” labels in `PLANNING_QA_GATE.md` | **defer** (plan forbids reconciling this slice) | later owner turn |

## 8. QA log

| Date | Command | Result | Commit |
|------|---------|--------|--------|
| 2026-08-18 | `.\scripts\run_planning_qa_gate.ps1` (default, no `-LiveTier3`) | **PASS** | (see Changelog after commit) |

Phase 1 → 2: all seven rows PASS. Do **not** refactor the source-of-truth path. Remaining risk: live TestBattle (`-LiveTier3`) was not run; owner F5 Layer B is not claimed. Direct `ResolutionPipeline` clones remain classified as support.
