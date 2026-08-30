# Planning gauntlet — Round 31 (static two-pass, NO_QA)

**Commit:** `64f67530a` (includes GAP-009 `a441018a3`)  
**Contract:** `docs/design/PLANNING_GAUNTLET_LOOP.md`  
**Handoff:** NO_QA — static read/grep only; no `run_*` / F5

---

## Pass A — Regression

| ID | Verdict | Evidence |
|----|---------|----------|
| GAP-001–009 | FIXED | Backlog closed; GAP-009 `_basic_walk_pathfinding_active` uses `active_movement_planning_step` (`combat_planning_input.gd` ~4876–4892) |
| FIX-001 | FIXED | Retired symbols absent from `presentation/` (grep 0 hits) |
| FIX-002 | FIXED | `combat_planning_preview.gd` `assign_preview_path_dict` / `set_unit_preview_path` reject `path.size() < 2` (~43–55) |
| FIX-003 | FIXED | Orbit/trim/corridor: `active_movement_planning_step`, `_voluntary_walk_orbit_phase_open`, `_basic_walk_pathfinding_active` (~4876+, ~4941+) |
| FIX-004 | FIXED | Sim paint early-returns gated on `active_movement_planning_step` throughout `on_hover_moved` / refresh paths |
| FIX-005 | FIXED | Player `TimelineAction.make_move` in input only at `_append_move_to_commit_slots` (~7035); director paths are AI/autobattler |
| FIX-006 | FIXED | `_phase_entry_stand` at paint (`_assemble_voluntary_walk_preview_path`) and commit (`_append_move_to_commit_slots`) |

**REGRESSION_PASS: PASS** (zero OPEN / STILL_OPEN / REGRESSED)

---

## Pass B — Fresh bible (MOVE_PREVIEW_RULES + matrix R1–R12)

| Check | Result |
|-------|--------|
| R1 forecast stand at phase entry | PASS — `forecast_stand_at_phase_entry` / `_phase_entry_stand` |
| R2 sealed leg anchor | PASS — `route[0]` via R1 + `seal_painted_leg` |
| R3 action range delegates R1 | PASS — `action_range_intent_stand_cell` |
| R4 intent truth paint = commit | PASS — `_resolve_commit_move_waypoints` + `_append_move_to_commit_slots` |
| R5 one phase cursor | PASS — `planning_timeline_phase_kind` + documented POSTMOVE/modular exceptions |
| R6 one voluntary-walk hover pipe | PASS — `_refresh_voluntary_walk_hover_preview` sole paint owner |
| R7 one corridor geometry | PASS — `voluntary_walk_corridor_waypoints` + `PlanningRoutePolicy` |
| R8 one commit entry | PASS — `_try_commit_voluntary_walk` |
| R9 commit metadata only | PASS — timing/slot via `TimelineAction` |
| R10 tile layers R1 | PASS — `PlanningPreviewTiles.resolve_layer_origins` |
| R11 next-phase forecast | PASS — `predicted_stand_at_hover` |
| R12 PRE ≡ MOVE-module walk | PASS — GAP-009 unified basic-walk pathfinding on movement steps |

**New HIGH gaps:** none  
**BIBLE_PASS: PASS**

---

## Infrastructure

**ADEQUATE** for static rule-abidance claim (NO_QA handoff). Runtime F5 proof deferred to WP-9 (owner).

Legacy `PlanningQaGate.tscn` / `run_planning_headless_contracts.ps1` explicitly **archaeology** — not gate-blocking; default gate uses T3 mimic only (`run_planning_qa_gate.ps1`).

---

## Score (harsh rubric, NO_QA)

| # | Category | Score |
|---|----------|-------|
| 1 | BAR / machine checks | 22/30 (static BAR only; NO_QA) |
| 2 | Goal completeness | 24/25 |
| 3 | Global rules | 19/20 |
| 4 | Artifact integrity | 14/15 |
| 5 | Quality & maintainability | 9/10 |
| 6 | Residual risk bonus | 3/10 |

**Total: 88/100** (threshold 85)

---

## RESULT

```
REGRESSION_PASS: PASS
BIBLE_PASS: PASS
SCORE: 88
RESULT: PASS
Infrastructure: ADEQUATE (static; WP-9 runtime deferred)
```

**100% planning voluntary-walk rule abidance claimed** (matrix R1–R12, backlog GAP/FIX clean). Runtime owner spot-check (WP-9) not required for this claim per NO_QA handoff.
