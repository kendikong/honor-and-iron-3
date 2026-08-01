# Planning QA Gate

**Mandatory** after any planning/commit/preview/undo gameplay change — see `.cursor/rules/qa-after-gameplay-changes.mdc`.

**Owner skill checklist (7 phases, move preview = truth):** [PLANNING_SKILL_QA_CHECKLIST.md](PLANNING_SKILL_QA_CHECKLIST.md) — use for every skill manual test and for what automated tests must eventually cover.

Automated mirror of the owner's manual planning checklist (Skill Arena / TestBattle).
Use this gate **before and after every change** that touches planning,
preview, commit slots, overlay draw, hover sim, or `CombatDirector` refresh — not only perf work.

## Three tiers

| Tier | Runner | QA gate status |
|------|--------|----------------|
| **1 — Simulation/economy** | fast fixture suites | **Legacy — disabled** (drifted from F5) |
| **2 — Planning contracts** | `tests/run_planning_qa_gate.gd` | **Legacy — disabled** (drifted from F5) |
| **3 — TestBattle acceptance** | `tests/live_planning_scene_test.gd` through GdUnit4 | **Required** — actual `TestBattle.tscn`, production input, frames, live overlay |
| **Manual visual** | Owner F5 review | Required for pixel/animation/FPS |

**Only Tier 3 blocks the planning QA gate.** Tier 1/2 remain in the repo for optional local archaeology (`-IncludeLegacyTier12`); failures there are expected and ignored.

### Tier 1/2 suites (legacy — not gate-blocking)

| Suite | Script | What it catches |
|-------|--------|-----------------|
| **Skill scenarios (checklist)** | `tests/planning_skill_scenarios_test.gd` | **7-phase owner checklist** per skill: blue/red, preview, cursor, slots, economy, sim — production commit path |
| **Drag E2E** | `tests/planning_drag_e2e_test.gd` | Production path: `_begin_drag` → `update_drag` → `on_left_release` → `board_changed` → undo |
| **Planning input** | `tests/planning_input_test.gd` | Cursor/slots parity, drop route, undo, awaiting refresh |
| **Trample E2E** | `tests/trampling_advance_e2e_test.gd` | Painted waypoint order through commit + sim |
| **Action-range regression** | `tests/action_range_regression_test.gd` | Red tile visibility + overlay parity |
| **Checklist mirror** | `tests/planning_qa_gate_test.gd` | Manual Skill Arena checklist APIs (slots, sim, click/drop parity) |

**Coverage honesty:** Every suite in this table is a Tier 1/2 fixture contract. It is
valuable regression coverage, but it is not F5 proof: these suites use
`PlanningDragE2EHarness`, mock map/viewport objects, QA pointer overrides, or direct
planning APIs. Skill scenarios (`tests/skills/*_scenario.gd`) remain the canonical
deterministic checklist contract; slot-only rows do not replace drag E2E.

### Tier 3 TestBattle acceptance

`tests/live_planning_scene_test.gd` boots the actual `TestBattle.tscn` **once** through
GdUnit4 and runs `test_live_planning_bible_multi_knight_session`. It pins a
four-knight / two-dummy training layout, uses real mouse move/press/release events,
advances production frames, inspects overlay tile collections and preview/commit
state, then presses Ready → Execute and verifies final unit positions.

#### Tier 3 profiles (`LIVE_QA_PROFILE`)

| Profile | Set via | Behavior |
|---------|---------|----------|
| **fast** (default) | unset or `LIVE_QA_PROFILE=fast` | Project viewport size (`project.godot`); checkpoint PNGs only; `qa_static_overlay` + ambient VFX off; hop probes; K1/K3 drag-only, K2 tap-only, K4 drag-only; tighter frame settles |
| **full** | `LIVE_QA_PROFILE=full` | Legacy 1920×1080; every step PNG; selection + drag parity on K1–K3; mouse sweep probes |

`run_planning_scene_acceptance.ps1` sets `LIVE_QA_PROFILE=fast` before launch. JSON trace
assertions (blue/red tiles, paths, commit slots, K4 run economy) run in both profiles.

**Single-session journeys (all in one boot):**

| Knight | Skill | Live checks |
|--------|-------|-------------|
| K1 `(4,5)` | Shield Bash | phases 1–5: blue/red, walk ghost + `preview_paths`, enemy approach path, push preview, cursor glyphs, pre-move `target_coord`, commit, red-off at 0 AP |
| K2 `(1,3)` | Chain Hook | in-range red, walk ghost + path, pull preview, commit, projected enemy cell |
| K3 `(5,4)` | Trampling Advance | arm awaiting, red while awaiting, per-step `get_drag_route()` + `preview_paths` paint (E→N), committed waypoints |
| K4 `(4,1)` | Run → Bowling | **Drag:** detour loop E→N→W to `(4,2)` (walk, red **on**, AP 1), then west to `(3,2)` with `auto_run` (run required, red **off**, display AP 0); commit; post-commit bowling red hidden. **Fast profile:** drag only (selection + parity in `full` only). |
| All | Execute | `GlobalTimeline` ready → sim; knight + dummy final cells match commit |
| Reset | Scroll + undo | wheel changes ability; run drag + right-click clears pre-move |

Click-versus-drag slot parity remains Tier 2 coverage: the live movement UI commits by
drag for runs/trample corridors, while enemy-target skills commit by click on the dummy.

Click-versus-drag slot parity remains Tier 2 coverage: the live movement UI only
commits by drag, while `PlanningDragE2ETest` compares that real release path against
the canonical click-slot builder without inventing a non-existent click-to-move scene
interaction.

Run Tier 3 alone (owner debugging only — **not** in addition to the gate):

```powershell
.\scripts\run_planning_scene_acceptance.ps1
```

Prove that this journey can fail (the source is restored even if the assertion fails):

```powershell
.\scripts\validate_live_planning_mutation.ps1
```

**Training Arena defaults:** Knight **1 AP / 3 MP** (`knight_factory` `action_points = 1`, `move_points = 3`). All knight class skills: **`action_point_cost = 1`** in `knight_factory.gd`. Headless `_planning_fixture` deliberately mirrors these data defaults but does **not** establish F5 parity. Slot-only tests (`_final_commit_slots_for_drop_at_cell`) do **not** replace drag E2E. The drag suite uses `QaPlanningMapStub` + `on_left_release` so stash lifecycle and deferred `board_changed` bugs are caught.

## Run (planning gate — Tier 3 only)

**One command, one Tier 3 boot.**

```powershell
.\scripts\run_planning_qa_gate.ps1
```

Optional local archaeology for disabled Tier 1/2 fixtures (failures ignored):

```powershell
.\scripts\run_planning_qa_gate.ps1 -IncludeLegacyTier12
```

Do **not** also run `run_planning_scene_acceptance.ps1` in the same QA turn — that doubles the live TestBattle session.

Tier 3 alone (owner debugging):

```powershell
.\scripts\run_planning_scene_acceptance.ps1
```

Sim/bridge regression (no planning fixtures):

```powershell
.\scripts\run_regression_tests.ps1 -GodotPath "<godot.exe>"
```

Full QA (Tier 3 planning gate + sim/bridge regression):

```powershell
.\scripts\run_full_qa.ps1 -GodotPath "<godot.exe>"
```

## Checklist mapping

### 1. Movement

| Manual check | Automated test | API asserted |
|--------------|----------------|--------------|
| 1A Blue move tiles on walk select | `_test_blue_move_tiles_on_walk_select` | `TacticalPlanningOverlay.is_hover_move_tile` |
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

## What stays manual (visual review — ~3 min)

1. **FPS / hover stutter** — no headless FPS yet; watch top-right counter after perf changes.
2. **Pixel authorship** — arrow colors, dashed style, threat tile outlines, ghost feet alignment.
3. **Walk animation** — unit sprite follows path smoothly (data path is tested; tween timing is not).

## Perf optimization sign-off

- [ ] Agent: `run_planning_qa_gate.ps1` → Tier 3 PASS (Tier 1/2 legacy optional only)
- [ ] Agent: `validate_qa_mutations.ps1` → all mutations CAUGHT (22 unfixes, ~90% gate coverage)
- [ ] Owner: visual-review items above → PASS
- [ ] Commit hash recorded in changelog

## Mutation validation (~90% gate coverage)

Run after adding or changing QA tests:

```powershell
.\scripts\validate_qa_mutations.ps1
```

**22 temporary unfixes** (6 original + 16 expanded) each break one production path; the gate must **fail** for every mutation, then **PASS** after revert. Report: `tests/qa_mutation_report.json`.

| # | Unfix | Primary suites caught |
|---|--------|------------------------|
| 1 | Red tiles always visible | action_range, run_economy, scenarios |
| 2 | Bash/hook no approach tile | drag, scenarios, gate approach |
| 3 | CLASS_SKILL AP not spent | execute AP, player_turn AP, scenarios |
| 4 | Skip post-commit promote | bash_promote_ghost, scenario phase5 |
| 5 | Push direction reversed | bash push, hook pull, sim |
| 6 | Hook in-range wrong stand | hook_in_range, scenario |
| 7 | `preview_commit_valid` ignores sim failure | invalid commit, OOB |
| 8 | Undo clears pre-move | undo keeps premove |
| 9 | Empty cursor glyphs | cursor parity, scenarios phase3 |
| 10 | No blue move tiles | phase1 blue, drag walk |
| 11 | `find_awaiting_action` always null | trample e2e + scenario |
| 12 | `_append_route_tile` no-op | waypoint order, trample paint |
| 13 | Click slots always invalid | hover/click/drop parity |
| 14 | Walk sim steps skipped | sim path, trample sim |
| 15 | Ability select skips cache clear | ability_switch cache |
| 16 | Timeline ghost always on | timeline_ghost tests |
| 17 | Strip waypoints on commit | trample waypoint commit |
| 18 | `movement_requires_run` always false | run_economy, auto_run gate |
| 19 | OOB slots not marked invalid | OOB invalid, slot reject |
| 20 | `drag_corridor_path` teleports to goal | jump drag autocorrect |
| 21 | Drop slots always invalid | drag-drop parity |
| 22 | `planning_display_mp_left` returns max MP | MP display tests |

**Not mutation-covered (manual visual review):** pixel draw, FPS, walk animation tweens, dashed-line rendering.

See also: `BUG_REPORT.md` (regression contract), `tests/trampling_advance_e2e_test.gd` (Trampling deep suite).
