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

Recorded 2026-08-18 from `IntentSourceOfTruthGateTest` `[SOT-SIG]` (also dumped to Godot `user://intent_sot_signatures.txt`). Format: `_intent_slot_signature` = `pre_target|pre_waypoints|action_target_unit|ability|post_count|invalid`. Full-turn `_sim_result_signature` is `units=…||events=…`. Player-phase economy/stand is compared to `simulate_player_turn`, not the full-turn AP after `reset_for_turn`.

Helper note (not a production FAIL): `_intent_slot_signature` records **pre-move** waypoints and `action[0].ability`, not action-column waypoints. TRAMPLE-01 still asserts painted `EAST_THEN_NORTH` on the committed action. SWAP-01 slot string omits `knight_swap` because that journey’s slots encode the ally cell on pre-move; sim events still show the swap pair.

Exact slot strings (pipe-delimited; hover = click = timeline):

- **WALK-01** slot `(5, 5)|[(5, 5)]|-1||0|false` — path `[(4, 5), (5, 5)]`, stand `(4, 5)`, pos `(5, 5)` — sim units `1@5,5:ap1:mp3;2@7,5:ap0:mp0`
- **MOVE-SKILL-01** slot `(6, 5)|[(5, 5), (6, 5)]|2|knight_shield_bash|0|false` — path to `(6, 5)`, stand `(4, 5)`, pos `(6, 5)` — sim units `1@6,5:ap1:mp3;2@9,5:ap0:mp0`
- **PUSH-PULL-01/bash** same slot and sim units as MOVE-SKILL-01; enemy pushed `(7, 5)→(9, 5)`
- **PUSH-PULL-01/hook** slot `(-999, -999)|[]|2|knight_chain_hook|0|false` — stand/pos `(1, 3)`; enemy pulled to `(2, 3)` — sim units `1@1,3:ap1:mp3;2@2,3:ap0:mp0`
- **SWAP-01** slot `(4, 4)|[]|-1||0|false` — path `[(4, 5), (4, 4)]`, stand `(4, 5)` — sim units `1@4,4:ap1:mp3;2@4,5:ap1:mp3`
- **AWAIT-01** slot `(-999, -999)|[]|2|knight_chain_hook|0|false` — far hover rejected first; valid enemy matches hook
- **TRAMPLE-01** slot `(-999, -999)|[]|-1|knight_trampling_advance|0|false` — painted east-then-north; sim path `(5, 4)→(6, 3)` — sim units `1@6,3:ap1:mp3`
- **STALE-01** slot `(-999, -999)|[]|-1||0|true` — OOB invalid; commit false; timeline unchanged; Simulator must not run

Every valid row’s full-turn events include `ENEMY_PHASE_BEGAN`. Exact event strings are in the `[SOT-SIG]` dump.

## 6. CM-01–CM-12

| ID | Result | Evidence |
|----|--------|----------|
| CM-01 | **PASS** | Slice is characterization + proof only. Current F5 planning/commit/sim behavior **preserved**. Callers unchanged: `_build_commit_slots_at_cell` → `_finalize_commit_slots` → `commit_from_slots` → `Simulator`. Rollback: prior SoT commit `395c2374139e1d07b91ed4f688c010ea2050c403`. Improvement = recorded signatures + stale/mechanics/perf proof; safer than rewriting the owner. See §7. |
| CM-02 | **PASS** | `ROADMAP.md`: living-map + combat parity closed; design-suite active. `IMPLEMENTATION_STATUS.md` not advanced. No Extra Rules / RunState / class / map mix-in. QA contract: default `.\scripts\run_planning_qa_gate.ps1` (no `-LiveTier3`). Known non-blockers: Godot RID leak warnings at harness exit. |
| CM-03 | **PASS** | §2 call graph + §3 owner table. Seven journeys share one slot/commit/sim path. `ResolutionPipeline` in `_refresh_plan_core` classified **support**. |
| CM-04 | **PASS** | §5 fixture signatures from live gate output (not “PASS” placeholders). Slots derive path, stand, target, ability, invalidation; sim records displacement, economy, event order. |
| CM-05 | **PASS** | Hover signature == click signature (repeat hover too). WALK-01 requires non-empty `preview_paths` + blue move tiles. MOVE-SKILL-01 / PUSH-PULL-01/bash require non-empty path, red action-range tiles, and a cursor icon from the same slots. Stand from `CombatPlanningPreview.planning_latest_stand_cell`. |
| CM-06 | **PASS** | After `commit_from_slots`, `_intent_slot_signature_from_timeline` equals hover/click signature on every valid journey. STALE-01 / AWAIT far hover: commit returns false, timeline unchanged. |
| CM-07 | **PASS** | Comparison 4: player-turn positions/AP/MP vs projected board; `_sim_result_signature(simulate_committed)` recorded; full-turn events must contain `ENEMY_PHASE_BEGAN`. Slot strings are **not** required to equal sim strings. |
| CM-08 | **PASS** | STALE-01 OOB. Bundle `new_fails=0`: stale hover, bash hover-change, undo, drag-drop undo, ability-switch cache clear, drag-cleared enemy intent restore, stale drag route ignore, hover-order invariant, timeline ghost/snapshot, invalid slots block commit, enemy-skill hover ≠ move route, `StalePreMoveTest`, swap undo cascade (`PlanningInputTest._test_swap_undo_cascades_all_plans_after`). Existing identity already rejects stale promotion — no new identity system. |
| CM-09 | **PASS** | Bundle `new_fails=0` plus seven journeys: Pre/Post-Move origin, push-through premove, latest-stand action range, trample post-move painted route, bash sim determinism, swap dependency cancellation, awaiting hook (AWAIT-01), enemy replan marker on full-turn sim. |
| CM-10 | **PASS** | Tests + this evidence file only. No production `ability.id` branch, no UI-only authority, no second range rule, no global exception. |
| CM-11 | **PASS** (measure only; **no optimize**) | `[SOT-PERF]` Shield Bash hover cell: hover **7511 µs**, slot build **6061 µs**, `simulate_committed` **2662 µs** (averages; T3-mimic sample). Slot signature unchanged across the timing loop: `(6, 5)|[(5, 5), (6, 5)]|2|knight_shield_bash|0|false`. No cache / skip-sim / validation weaken. |
| CM-12 | **PASS** | `.\scripts\run_planning_qa_gate.ps1` default **PASS** 2026-08-18 (AOE + headless contracts + T3 mimic). SWAP-01 is inside that gate (and T3 mimic). Class gates / full regression **not run**: no factory, `Simulator`, or class-owner production change. Unresolved: owner Layer B (F5 pixels) not claimed; `-LiveTier3` not run. |

## 7. preserve / improve / defer

| Issue | Decision | Target |
|-------|----------|--------|
| Enforcement gap (helpers can reconstruct intent) | **improve** via characterization gate | Phase 1 **done** — seven rows + CM-08/09/11 proof; no production refactor |
| `ResolutionPipeline` clones in `_refresh_plan_core` | **preserve** as support | no Phase 2 (no FAIL) |
| Typed `PlanningResult` wrapper | **defer** — callers can consume existing slots/preview | Phase 3 not started |
| Stale identity strengthening | **preserve** existing reject/refresh paths (CM-08 `new_fails=0`) | no Phase 2 |
| Projection perf | **preserve** — measured, not optimized (CM-11) | Phase 4 only if a later hotspot is proven |
| `_intent_slot_signature` omits action-column waypoints | **defer** — trample waypoints asserted separately; changing the helper is not a SoT FAIL | later test-only turn |
| Stale “legacy” labels in `PLANNING_QA_GATE.md` | **defer** (plan forbids reconciling this slice) | later owner turn |

## 8. QA log

| Date | Command | Result | Notes |
|------|---------|--------|--------|
| 2026-08-18 | `.\scripts\run_planning_qa_gate.ps1` (default, no `-LiveTier3`) | **PASS** | Phase 1 seven journeys |
| 2026-08-18 | `.\scripts\run_planning_qa_gate.ps1` (default, no `-LiveTier3`) | **PASS** | CM-08/09/11 wired; `[SOT-SIG]` / `[SOT-PERF]` recorded |

Phase 1 → 2: all seven rows PASS and CM-01–CM-12 have named evidence. Do **not** refactor the source-of-truth path. Remaining risk: live TestBattle (`-LiveTier3`) was not run; owner F5 Layer B is not claimed. Direct `ResolutionPipeline` clones remain classified as support.
