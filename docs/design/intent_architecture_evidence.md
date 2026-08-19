# Intent architecture evidence

Owner map and seven recorded core-journey traces for the source-of-truth
slice, plus explicitly marked extended checklist IDs. Fill fixture signature
strings from gate output; do not invent a second planner.

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
| BASH-POST-01 | Walk + Shield Bash + POST move origin |
| TRAMPLE-POST-01 | Trampling painted-route POST continuation |

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

Recorded 2026-08-18 from `IntentSourceOfTruthGateTest` `[SOT-SIG]`. Format: `_intent_slot_signature` = `pre_target|pre_waypoints|action_target_unit|ability|action_waypoints|post_count|invalid`. Ability falls back to the pre-move column when the action column has no ability (Swap). Full-turn `_sim_result_signature` is `units=…||events=…`. Player-phase economy/stand is compared to `simulate_player_turn`, not the full-turn AP after `reset_for_turn`.

Exact slot strings (pipe-delimited; hover = click = timeline):

- **WALK-01** `(5, 5)|[(5, 5)]|-1||[]|0|false` — path `[(4, 5), (5, 5)]`, stand `(4, 5)`, pos `(5, 5)` — sim units `1@5,5:ap1:mp3;2@7,5:ap0:mp0`
- **MOVE-SKILL-01** `(6, 5)|[(5, 5), (6, 5)]|2|knight_shield_bash|[(5, 5), (6, 5)]|0|false` — pos `(6, 5)` — sim units `1@6,5:ap1:mp3;2@9,5:ap0:mp0`
- **PUSH-PULL-01/bash** same as MOVE-SKILL-01; enemy pushed `(7, 5)→(9, 5)`
- **PUSH-PULL-01/hook** `(-999, -999)|[]|2|knight_chain_hook|[]|0|false` — stand/pos `(1, 3)`; enemy pulled to `(2, 3)` — sim units `1@1,3:ap1:mp3;2@2,3:ap0:mp0`
- **SWAP-01** `(4, 4)|[]|-1|knight_swap|[]|0|false` — path `[(4, 5), (4, 4)]` — sim units `1@4,4:ap1:mp3;2@4,5:ap1:mp3`
- **AWAIT-01** `(-999, -999)|[]|2|knight_chain_hook|[]|0|false` — far `(11,11)` hover rejected first; valid enemy `(4,3)` matches hook
- **TRAMPLE-01** `(-999, -999)|[]|-1|knight_trampling_advance|[(6, 4), (6, 3)]|0|false` — painted east-then-north in the **action** waypoint field; sim path `(5, 4)→(6, 3)` — sim units `1@6,3:ap1:mp3`
- **STALE-01** `(-999, -999)|[]|-1||[]|0|true` — OOB invalid; commit false; Simulator must not run

Extended post-move rows are checklist requirements until their complete slot and
Simulator signatures are recorded:

- **BASH-POST-01** — `planning_qa_gate_test.gd::_test_move_preview_origin_premove_and_postmove`
  proves the action-end origin; full committed POST route parity remains a
  checklist requirement.
- **TRAMPLE-POST-01** — `planning_qa_gate_test.gd::_test_trample_post_move_preview_commit_sim`
  delegates to `trampling_advance_e2e_test.gd::_test_post_move_sim_preview_keeps_trample_paint_order`
  and proves the painted Trampling POST continuation through the planning gate.

Every valid row’s full-turn events include `ENEMY_PHASE_BEGAN`.

## 6. CM-01–CM-12

| ID | Result | Evidence |
|----|--------|----------|
| CM-01 | **PASS** | Slice is characterization + proof only. Current F5 planning/commit/sim behavior **preserved**. Callers unchanged: `_build_commit_slots_at_cell` → `_finalize_commit_slots` → `commit_from_slots` → `Simulator`. Rollback: prior SoT commit `395c2374139e1d07b91ed4f688c010ea2050c403`. Improvement = recorded signatures + stale/mechanics/perf proof; safer than rewriting the owner. See §7. |
| CM-02 | **PASS** | `ROADMAP.md`: living-map + combat parity closed; design-suite active. `IMPLEMENTATION_STATUS.md` not advanced. No Extra Rules / RunState / class / map mix-in. QA contract: default `.\scripts\run_planning_qa_gate.ps1` (no `-LiveTier3`). Known non-blockers: Godot RID leak warnings at harness exit. |
| CM-03 | **PASS** | §2 call graph + §3 owner table. Seven journeys share one slot/commit/sim path. `ResolutionPipeline` in `_refresh_plan_core` classified **support**. |
| CM-04 | **PASS** | §5 fixture signatures from live gate output (not “PASS” placeholders). Slots derive path, stand, target, ability, invalidation; sim records displacement, economy, event order. |
| CM-05 | **PASS** | Hover signature == click signature (repeat hover too). WALK-01 requires non-empty `preview_paths` + blue move tiles. MOVE-SKILL-01 / PUSH-PULL-01/bash require non-empty path, red action-range tiles, and a cursor icon from the same slots. Stand from `CombatPlanningPreview.planning_latest_stand_cell`. Pending timeline identity now also includes waypoints, facing, module targets, and reaction metadata; ghost visibility follows valid preview state rather than a skill-mode UI flag. |
| CM-06 | **PASS** | After `commit_from_slots`, `_intent_slot_signature_from_timeline` equals hover/click signature on every valid journey. Valid enemy-hover QA now drives `on_left_press` with the QA mouse pointer; `_commit_at_interaction_cell` ratifies the captured finalized snapshot instead of rebuilding it. STALE-01 / AWAIT far hover: commit returns false, timeline unchanged. |
| CM-07 | **PASS** | Comparison 4: player-turn positions/AP/MP vs projected board; `_sim_result_signature(simulate_committed)` recorded; full-turn events must contain `ENEMY_PHASE_BEGAN`. Slot strings are **not** required to equal sim strings. |
| CM-08 | **PASS** | STALE-01 OOB. Bundle `new_fails=0`: stale hover, bash hover-change, undo, drag-drop undo, ability-switch cache clear, drag-cleared enemy intent restore, stale drag route ignore, hover-order invariant, timeline ghost/snapshot, invalid slots block commit, enemy-skill hover ≠ move route, `StalePreMoveTest`, swap undo cascade (`PlanningInputTest._test_swap_undo_cascades_all_plans_after`). Existing identity already rejects stale promotion — no new identity system. |
| CM-09 | **PASS** | Bundle `new_fails=0` plus seven journeys: Pre/Post-Move origin, push-through premove, latest-stand action range, trample post-move painted route, bash sim determinism, swap dependency cancellation, awaiting hook (AWAIT-01), enemy replan marker on full-turn sim. |
| CM-10 | **PASS** | Production selection re-emits the existing `ability_selected` signal for same-index re-arming; the planning walk trace records `start` separately from destination `actual_cells`; live assertions derive the exact movement leg through `CombatPlanningPreview.destination_cells_from_route`. No production `ability.id` branch, no UI-only authority, no second range rule, no global exception. |
| CM-11 | **PASS** (measure only; **no optimize**) | `[SOT-PERF]` Shield Bash: hover **7520 µs**, slot build **6091 µs**, `simulate_committed` **2686 µs**. Slot signature unchanged across the timing loop. No cache / skip-sim / validation weaken. |
| CM-12 | **PASS** | Two separate proofs **PASS**: default `.\scripts\run_planning_qa_gate.ps1` covers headless planning/SoT contracts, while live `.\scripts\run_swap_planning_acceptance.ps1` covers `test_live_swap_session` with strict canonical movement-leg equality and painted-slot signature equality. The headless gate does not execute the live assertion. Class gates / full regression **not run**: no factory or `Simulator` production change. Owner Layer B (F5 pixels) not claimed. |

## 7. preserve / improve / defer

| Issue | Decision | Target |
|-------|----------|--------|
| Enforcement gap (helpers can reconstruct intent) | **improve** via characterization gate | Phase 1 **done** |
| `ResolutionPipeline` clones in `_refresh_plan_core` | **preserve** as support | Phase 2 **closed** — no semantic duplication proven |
| Typed `PlanningResult` wrapper | **defer / not started** — callers already consume slots/preview | Phase 3 skipped (Phase 2 did not prove multiple callers lack a shared result) |
| Stale identity strengthening | **preserve** existing reject/refresh (CM-08 `new_fails=0`) | Phase 2 **closed** — no stale-promotion FAIL |
| Projection perf | **preserve** — measured, not optimized (CM-11) | Phase 4 skipped (no hotspot large enough to justify a result-changing optimize) |
| Slot signature completeness | **improve** (test helper only) | Action waypoints + pre-column ability now in `_intent_slot_signature` |
| Stale “legacy” labels in `PLANNING_QA_GATE.md` | **defer** (plan forbids reconciling this slice) | later owner turn |

## 8. QA log

| Date | Command | Result | Notes |
|------|---------|--------|--------|
| 2026-08-18 | `.\scripts\run_planning_qa_gate.ps1` (default) | **PASS** | Phase 1 seven journeys |
| 2026-08-18 | `.\scripts\run_planning_qa_gate.ps1` (default) | **PASS** | CM-08/09/11; commit `6452d2d0d74fae4ee665b76f401eb27619b4393a` |
| 2026-08-18 | `.\scripts\run_planning_qa_gate.ps1` (default) | **PASS** | Complete slot signatures + live timeline twin; commit `e9e7c44210b841921a119746ca8a371063ed3c78` |
| 2026-08-18 | `.\scripts\run_swap_planning_acceptance.ps1` | **FAIL** | Live `test_live_swap_session`: 8 failures. Hover paths expected turn-start `(4, 5)` after swap; animation traces included latest stand while drop-time preview did not; walk-then-swap commit raced because `_assert_commit_ratifies_preview` was not awaited. |
| 2026-08-18 | `.\scripts\run_swap_planning_acceptance.ps1` | **PASS** | GdUnit `test_live_swap_session` PASSED (1 case, 0 failures, 9.3s). Wrapper printed `[INCOMPLETE]` because the Godot process exit code was unavailable; GdUnit `Exit code: 0` is the result. |
| 2026-08-18 | `.\scripts\run_planning_qa_gate.ps1` (default) | **PASS** | After live-swap test fix. AOE + headless contracts + T3 mimic. |
| 2026-08-18 | `.\scripts\run_swap_planning_acceptance.ps1` | **FAIL** | Strict critic follow-up rejected route normalization: the direct slot helper captured preview before painting finalized slots, exposing a stale `[ (3, 4) ]` path against event `[ (3, 5), (3, 4) ]`. |
| 2026-08-18 | `.\scripts\run_swap_planning_acceptance.ps1` | **PASS** | After removing route normalization, separating production trace origin from destination cells, re-emitting same-index ability selection through `CombatDirector`, and capturing painted slots before commit: 1 case, 0 failures. |
| 2026-08-18 | `.\scripts\run_planning_qa_gate.ps1` (default) | **PASS** | After strict route and same-index re-arm fixes. AOE + headless contracts + T3 mimic. |
| 2026-08-18 | `.\scripts\run_swap_planning_acceptance.ps1` | **PASS** | Replaced remaining preview-prefix slicing with `CombatPlanningPreview.destination_cells_from_route(preview, event.from, event.to)`; 1 case, 0 failures. |
| 2026-08-18 | `.\scripts\run_planning_qa_gate.ps1` (default) | **PASS** | After canonical movement-leg assertion fix. AOE + headless contracts + T3 mimic. |
| 2026-08-18 | `.\scripts\run_planning_headless_contracts.ps1` | **PASS** | Added `waypoint_premove_enemy_hover_full_truth`: three side-flanking four-step routes exhaust MP, then simulated mouse hover over an out-of-range enemy. Each case checks hover path/stand/damage, finalized slots, pulsing timeline ghost, click-slot parity, and Simulator movement + damage. |
| 2026-08-18 | `.\scripts\run_planning_qa_gate.ps1` (default) | **PASS** | Enemy-hover regression now uses the real headless `on_hover_moved` → `on_left_press` path. Valid hover slots are captured with unit/cell/target identity and committed without recomputation; pending ghost comparison includes full route metadata. |
| 2026-08-18 | `.\scripts\run_planning_headless_contracts.ps1` | **PASS** | Expanded the checklist with three full-MP sideflanking premoves for Power Shot and Volley, three exhausted-MP Sidestep enemy-hover rejection cases, and two valid Sidestep post-premove cases. Each valid case checks path, latest stand, target/ability, facing semantics, affected tiles where applicable, blue/red tiles, cursor parity, finalized slots, pulsing ghost, real click ratification, and Simulator outcome. |
| 2026-08-18 | `.\scripts\run_planning_qa_gate.ps1` (default) | **PASS** | Final headless-only gate: AOE footprint contract, PlanningQaGate, and T3 fixture parity all pass. No live TestBattle/F5 runner was used. |

## 8.1 Headless planning acceptance checklist — category contract

The default planning gate must retain every item below; removing any one is a
regression. `[defined]` records that the category exists in the checklist;
it does **not** claim that every atomic row below is already executable.

- [defined] Valid hover produces finalized slot data and a faded/flashing timeline ghost.
- [defined] Preview path, latest stand, approach route, target, ability, facing semantics, and affected footprint match the finalized slots.
- [defined] Blue movement tiles, red action-range tiles, and cursor/icon state are checked from the same intent.
- [defined] Real pointer hover → real pointer click commits the captured hover intent without rebuilding it.
- [defined] Committed timeline signature and `Simulator` result match the hovered intent.
- [defined] **Before commit:** every premove route, waypoint, stand, approach, facing, target, ability, affected tile set, economy result, and action metadata equals the last valid move preview.
- [defined] **At commit:** click only ratifies the captured finalized slots; it never rebuilds, corrects, normalizes, or reinterprets the displayed premove.
- [defined] **After commit:** committed timeline entries preserve the exact preview signature, including all premove waypoints and paired action metadata.
- [defined] **During execution:** `Simulator` movement, facing, target resolution, affected tiles, damage, displacement, statuses, terrain, AP/MP consumption, and event order equal the preview prediction.
- [defined] **No heuristic divergence:** any preview → slots → timeline → Simulator mismatch fails immediately; “close enough” final-state checks do not pass.
- [defined] Invalid hover clears/rejects intent and cannot turn a Sidestep hover into an unrelated ranged attack.
- [defined] Three sideflanking, full-MP waypoint premoves are followed by real enemy hover for ranged attack and tile AOE.
- [defined] Trampling Advance is the minimum movement-ability bar: alternate painted waypoint orders and post-move continuations must ratify exactly. Sidestep remains a separate tile-target regression, not the movement-family bar.
- [defined] Re-hover, ability switching, premoves, ranged approaches, tile targeting, and enemy-hover transitions remain covered by the existing suite.

### Atomic per-scenario expansion requirement

The category checklist above is not the executable depth target by itself. Each
complex scenario must expand into **17 state checkpoints × 40 independently
named behaviors = 680 atomic checklist items**. The atomic rows are requirements
until the executable harness asserts them; they must not be reported as PASS
merely because the category gate is green.

Required scenario instances:

- `PS-R1`, `PS-R2`, `PS-R3` — three full-MP, sideflanking Power Shot routes.
- `VO-R1`, `VO-R2`, `VO-R3` — three full-MP, sideflanking Volley routes.
- `SS-E1`, `SS-E2`, `SS-E3` — three exhausted-MP Sidestep enemy-hover rejection routes.
- `SS-V1`, `SS-V2` — two valid Sidestep post-premove tile-target routes.
- `PS-R-INVALID` — full-MP route that remains out of ranged attack distance.
- `WALK-01`, `MOVE-SKILL-01`, `PUSH-PULL-01`, `SWAP-01`, `AWAIT-01`,
  `TRAMPLE-01`, `TRAMPLE-REPATH-01`, `BASH-POST-01`, `TRAMPLE-POST-01`, `RUN-WAIT-01`, `DRAG-DROP-01`,
  `TELEPORT-01` — shared movement, targeting, dependency, economy, and input
  families.
- `I-T01-01`…`I-T10-01` — ten explicit hover/drag/ability/undo/replan
  transition scenarios.
- `N-OOB-01`, `N-OCCUPIED-01`, `N-RANGE-01`, `N-AWAIT-FAR-01`,
  `N-VOLLEY-TILE-01`, `N-SILENCE-01`, `N-SNAPSHOT-01` — seven explicit
  rejection scenarios.

Each instance must check the full behavior set at setup, selection, initial
hover, route progress, final waypoint, target transition, settled target hover,
snapshot capture, pre-click slots, click ratification, committed timeline,
post-commit presentation, Simulator resolution, final parity, and replan from
the latest projected stand. The required per-scenario minimum is **680 atomic
items**, not one summary assertion.

### Atomic coverage ledger

The canvas matrix is the checklist ledger. Every scenario must have a traceable
row for each atomic item; a mechanical row count without an executable owner is
not evidence.

| Scenario family | Required instances | Atomic minimum each | Current checklist status |
|---|---|---:|---|
| Power Shot ranged approach | `PS-R1`…`PS-R3` | 680 | Required — bind every row to executable assertions |
| Volley tile AOE | `VO-R1`…`VO-R3` | 680 | Required — bind every row to executable assertions |
| Sidestep exhausted enemy hover | `SS-E1`…`SS-E3` | 680 | Required — bind every row to executable assertions |
| Sidestep valid tile movement | `SS-V1`…`SS-V2` | 680 | Required — bind every row to executable assertions |
| Power Shot invalid full-MP route | `PS-R-INVALID` | 680 | Required — explicit invalid/empty expectations |
| Shared journey families | `WALK-01`…`TELEPORT-01` | 680 | Required — each family gets its own atomic expansion |
| Explicit transitions | `I-T01-01`…`I-T10-01` | 680 | Required — each transition gets its own atomic expansion |
| Explicit rejection paths | `N-OOB-01`…`N-SNAPSHOT-01` | 680 | Required — each rejection gets invalid/empty/n/a expectations |

The canvas currently contains **41 atomic scenarios × 680 = 27,880 listed
items**. Each item must eventually acquire an executable `file::function`
owner; rows without one remain requirements and cannot contribute to PASS.
`N-RANGE-01` is an explicit rejection-path alias of `PS-R-INVALID` and must
inherit its route facts from that single source; it is not an independent
fixture.

### Phase and journey completeness requirements

Every scenario family must explicitly cover all seven phases from
`PLANNING_SKILL_QA_CHECKLIST.md`: select/rest, empty hover, drag/waypoints,
enemy hover, commit, execute, and replan from the new projected stand. The
phase matrix must name all applicable layers: preview board/path, blue tiles,
red tiles, arrows, cursor, economy/timeline, ghosts, and commit/Simulator.

The 17 checkpoints map explicitly to the seven phases:

- **P1 select/rest:** `setup`, `select-unit`, `select-ability`.
- **P2 empty hover:** `initial-hover`, `route-begin`, `route-progress`.
- **P3 drag/waypoints:** `route-final`.
- **P4 enemy/target hover:** `enemy-transition`, `target-settled`,
  `snapshot-captured`, `pre-click`.
- **P5 commit:** `click-ratified`, `timeline-written`, `post-commit`.
- **P6 execute:** `sim-resolution`, `final-parity`.
- **P7 replan:** `replan-from-stand` (re-enters P2–P6; it does not reuse old
  execution values).

The checklist must also contain scenario-applicable rows for:

- WALK, MOVE-SKILL, PUSH/PULL, SWAP, AWAIT, TRAMPLE + post-move, RUN/WAIT,
  and click/drop parity.
- Mid-route waypoint changes, enemy A→B switching, pointer leave, ability
  switching, same-index re-arm, drag cancellation, right-click undo, undo
  dependency removal, invalid click, and post-commit re-hover.
- Out-of-bounds, occupied endpoint, still-out-of-range, far awaiting target,
  illegal AOE tile, AP/MP/state-blocked action, and stale snapshot rejection.

### Traceability rule

No row may be labeled `PASS — existing suite` without a concrete
`file::function`, journey ID, or scenario ID. Any row lacking an executable
owner remains `CHECKLIST — required`, not PASS.

## 9. Slice close

The category contract and atomic checklist structure are present. The
executable 680-row-per-scenario harness expansion remains required before this
checklist can be called an ironclad automated regression barrier.

Phases 0–1 done. Phase 2 closed with the smallest owner fixes required by strict live evidence: same-index ability re-arm now uses the existing selection signal, and animation diagnostics distinguish the route origin from destination cells. Phase 3 (`PlanningResult`) and Phase 4 (optimize) were not started because the gate found no need for a new result abstraction or result-changing optimization.

The planning behavior now explicitly ratifies the last valid hover snapshot: a displayed move-plus-attack route cannot be replaced by a rebuilt ranged-only action at click time. Pending timeline ghosts compare the complete `TimelineAction` intent, including route metadata, so a valid changed waypoint preview remains visible and pulsing. The default planning gate (**PASS**) proves the currently implemented headless contracts; it does not yet prove the full 680-row-per-scenario expansion. The live swap suite (**PASS**) separately proves TestBattle route parity with strict assertions. Owner F5 Layer B remains the owner’s visual check.

### Deferred (explicit, not silent)

| Item | Why deferred | Target |
|------|----------------|--------|
| Live bible (`-LiveTier3` / `run_planning_scene_acceptance.ps1`) | Not in the failing set this turn. Default planning gate is headless fixtures (**PASS**). Swap live **PASS**. | Only if the owner asks for F5-parity bible |
| Stale “legacy” labels in `PLANNING_QA_GATE.md` | Plan forbids reconciling this slice | later owner turn |
| Godot RID/object leak warnings at harness exit | Pre-existing; not `[FAIL]` | ignore unless they become gate-blocking |

Remaining risks that are **not** blockers for this slice: support-class `ResolutionPipeline` clones in `_refresh_plan_core`; owner F5 pixels.
