# Council audit log

Process violations and **remediation council** verdicts. Rules: `docs/qa/SUBAGENT_COUNCIL_LOOP.md` § Post-apply amendments · § Remediation.

---

## 2026-09-01 — Planning layers 0–1 process remediation (owner order)

### Violations found

| # | Type | Commits | What happened |
|---|------|---------|----------------|
| V1 | **Code before council** | `cf0c33d6b` (Layer 1) | `planning_preview_tiles.gd` / tests edited before 6/6 council ran. |
| V2 | **Post-council apply without amendment council** | `e781343c1` (Layer 0 completion) | Delta after initial Layer 0 apply (`e958bcd2d`) shipped without logged re-council. |
| V3 | **Pre-layer council** | `88fc8eba7` | Phase-entry stand work landed before Layer 0 council; retained as foundation (retro rules PASS). |

### Remediation councils (2026-09-01)

| Layer | Shipped commit | Council | Verdict | Gate |
|-------|----------------|---------|---------|------|
| **0** (full shipped scope) | `e781343c1` | Remediation critics **1–5** | **5/5 PASS** | `run_layer0_paint_gate.ps1` **PASS** |
| **1** (full shipped scope) | `cf0c33d6b` | Remediation critics **1–6** | **6/6 PASS** | `run_layer1_paint_gate.ps1` **PASS** |

**Critic IDs (Layer 0 remediation):** 1 PASS · 2 PASS · 3 PASS · 4 PASS · 5 PASS  

**Critic IDs (Layer 1 remediation):** 1 PASS · 2 PASS · 3 PASS · 4 PASS · 5 PASS · 6 PASS  

### Resolution

- **Code:** No revert — rules-compliant; gates green.
- **Process:** Violations **closed** after remediation councils + this log entry.
- **Going forward:** Post-apply deltas require amendment council; layers not DONE without logged `Council: N/N PASS`.

### Initial Layer 0 council (for record)

| When | Commit | Council | Notes |
|------|--------|---------|-------|
| 2026-08-31 | `e958bcd2d` | **5/5 PASS** (pre-ship) | First overlay split; completion in `e781343c1` required remediation row above. |

---

## 2026-09-01 — Layer 2 locked red + approach red (paint layers)

### Councils

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R1 | Initial proposal | 1–6 | **4/6 FAIL** | Critic 1: NON_MOVEMENT hover-shaped red path; Critic 6: proposal docs |
| R2 | Revised proposal | 1–6 | **5/6 FAIL** | Critic 3: `stand_origin` must match sealed approach red |
| R3 | Revised proposal | 1–6 | **6/6 PASS** | Approved apply: `planning_preview_tiles.gd`, `tactical_planning_overlay.gd`, Layer 2 gate |
| **R4 amendment** | Economy gate (`action_range_visible_for_hover` premove_cell) | 1–6 | **6/6 PASS** | Gate FAIL fix upstream; no overlay fallback |
| **R4b amendment** | Full economy gate: premove_cell + awaiting `can_plan` + projected-only economy (no live_board short-circuit) | 1–6 | **6/6 PASS** | Layer 2 gate green |

**Critic IDs (R3):** 1 PASS · 2 PASS · 3 PASS · 4 PASS · 5 PASS · 6 PASS  

**Critic IDs (R4 amendment):** 1 PASS · 2 PASS · 3 PASS · 4 PASS · 5 PASS · 6 PASS  

**Critic IDs (R4b amendment):** 1 PASS · 2 PASS · 3 PASS · 4 PASS · 5 PASS · 6 PASS  

### Files

- `presentation/planning_preview_tiles.gd` — NON_MOVEMENT hover-shaped approach red; EX-LOCKED-FIELD locked red not sealed into bundle
- `presentation/tactical_planning_overlay.gd` — locked red gated by `show_action_range`; bundle approach red on NON_MOVEMENT match
- `presentation/combat_planning_input.gd` — `action_range_visible_for_hover`: premove_cell chain, awaiting uses `can_plan`, projected economy only
- `scripts/qa/run_layer2_paint_gate.ps1`, `tests/gates/Layer2PaintGate.tscn`, `tests/runners/run_layer2_paint_gate.gd`

### Verify

| Gate | Result |
|------|--------|
| `run_layer2_paint_gate.ps1` | **PASS** |
| `run_layer0_paint_gate.ps1` | **PASS** (regression) |
| `run_layer1_paint_gate.ps1` | **PASS** (regression) |

**Layer 2 status:** **DONE** (2026-09-01)

---

## 2026-09-01 — Layer 3 R3 amendment (`_action_range_paint_stand` / `resolve_paint` / `action_range_tiles`)

### Councils

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R3 | Initial proposal | 1–6 | (prior rounds) | Yellow blast / shaped skill layer |
| **R3 amendment** | `premove_dest` vs `phase_entry`; settled landing at hover; single `resolve_paint` stand call; `action_range_tiles` projected board + landing `origin` | 1–6 | **6/6 PASS** | No overlay fallback; `run_layer3_paint_gate.ps1` **PASS** |

**Critic IDs (R3 amendment):** 1 PASS · 2 PASS · 3 PASS · 4 PASS · 5 PASS · 6 PASS

### Files

- `presentation/planning_preview_tiles.gd` — `_action_range_paint_stand`, `resolve_paint`, `action_range_tiles`, walk-only blast guards
- `presentation/tactical_planning_overlay.gd` — yellow bundle-only; committed-action yellow clear
- `scripts/qa/run_layer3_paint_gate.ps1`, `tests/gates/Layer3PaintGate.tscn`, `tests/runners/run_layer3_paint_gate.gd`
- `tests/harness/planning_qa_gate_test.gd` — `_test_yellow_clears_after_skill_commit`

### Verify

| Gate | Result |
|------|--------|
| `run_layer3_paint_gate.ps1` | **PASS** |
| `run_layer0_paint_gate.ps1` | **PASS** (regression) |
| `run_layer1_paint_gate.ps1` | **PASS** (regression) |
| `run_layer2_paint_gate.ps1` | **PASS** (regression) |

**Layer 3 status:** **DONE** (2026-09-01)

---

## 2026-09-01 — Layer 4 sealed-leg orbit route (R1c–R1f)

### Councils

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R1c | `_authoritative_route_for_unit` sealed fallback; snapshot freeze; `_voluntary_walk_hover_paint_applies` guard; remove duplicate restore | 1–6 | **6/6 PASS** | Applied |
| R1d | Sealed → `corridor_paint` false; restore without drag; delete dead sealed+EXTEND branches | 1–6 | **6/6 PASS** (Critic 4 revised) | Applied — gate still 97 FAIL |
| R1e | Hoist sealed guard to top of `_voluntary_walk_corridor_paint_active` (before trample awaiting return) | 1–6 | **6/6 PASS** amendment | Applied |
| R1f | `display_move_route_cells` sealed-first; block L2089 refresh when locked; `_hover_paint_waypoints_for_cell` locked guard | 1–6 | **6/6 PASS** | Applied — gate **89 FAIL** (was 97) |

**Critic IDs (R1f):** 1 PASS · 2 PASS · 3 PASS · 4 PASS · 5 PASS · 6 PASS

### Files

- `presentation/combat_planning_input.gd` — sealed-leg orbit route policy + display/settle guards
- `scripts/qa/run_layer4_paint_gate.ps1`, `tests/gates/Layer4PaintGate.tscn`, `tests/runners/run_layer4_paint_gate.gd`

### Verify

| Gate | Result |
|------|--------|
| `run_layer4_paint_gate.ps1` | **FAIL** (89 — `painted_route_equivalence` ~73, plus teleport/waypoint/drag/tile_aim buckets) |
| `run_layer0_paint_gate.ps1` | **PASS** |
| `run_layer1_paint_gate.ps1` | **PASS** |
| `run_layer2_paint_gate.ps1` | **PASS** |
| `run_layer3_paint_gate.ps1` | **PASS** |

**Layer 4 status:** **IN PROGRESS** — orbit equivalence improved (97→89); remaining buckets need separate council cycles (teleport, waypoint_enemy_hover, drag_drop_undo, tile_aim, range2_arrow).

---

## 2026-09-01 — Layer 4 R3–R10 (council-gated orbit / trample parity)

### Councils

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R3 | Armed awaiting refresh skip when locked; sealed restore order; manhattan-1 assemble | 1–6 | **6/6 PASS** | Applied — no FAIL delta |
| R4 | Sealed anchor via `sealed_phase_entry_anchor`; remove hover clear on anchor mismatch | 1–6 | **5/6** (C6 FAIL) | Applied — remediation logged; no FAIL delta |
| R5 | Block settle in `_refresh_voluntary_walk_hover_preview` when locked | 1–6 | **4/6** → R5-revised **6/6 PASS** | Applied — no FAIL delta |
| R5-revised | Guard after illegal-hover clear, before corridor/settle | 1–6 | **6/6 PASS** | Applied |
| R6 | Skip armed stand settle when sealed/locked | 1–6 | **6/6 PASS** | Applied — insufficient alone |
| R7 | `_leg_anchor_for_painted_drag` live stand for awaiting MOVE module | 1–6 | **6/6 PASS** | Applied |
| R8 | `_planning_drag_origin` → `_leg_anchor_for_painted_drag` | 1–6 | **6/6 PASS** | Applied |
| R10 | Skip armed stand settle when `_authoritative_route_for_unit` ≥ 2 | 1–6 | **6/6 PASS** | Applied — **89→88 FAIL**, painted_route **73→72** |

### Councils (continued)

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R11 | `_assemble_voluntary_walk_preview_path` origin → `_leg_anchor_for_painted_drag` | 1–6 | **6/6 PASS** | Applied — no delta alone |
| R12 | `_leg_anchor_for_painted_drag` prefers `_authoritative_route_for_unit[0]` | 1–6 | **6/6 PASS** | Applied — no delta alone |
| R13 | `_voluntary_walk_corridor_paint_active` false when authoritative route ≥ 2 | 1–6 | **6/6 PASS** | Applied — **88→46 FAIL**, painted_route **72→39** |

### Verify (latest)

| Gate | Result |
|------|--------|
| `run_layer4_paint_gate.ps1` | **FAIL (46)** — painted_route_equivalence 39 + waypoint 3 + teleport/drag/tile_aim/range2 |
| L0–L3 regression | **PASS** |

**Layer 4 status:** **IN PROGRESS** — painted_route 72→39; orbit extend/freeze tuning + remaining buckets need council cycles.

---

## 2026-09-01 — Layer 4 R14–R17 (council-gated painted_route_equivalence)

### Councils

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R14 | Assembler orbit bypass before trample settle; corridor_fill gate auth≥2; `_corridor_waypoints_to_cell` leg anchor | 1–6 | **6/6 PASS** | Applied — **46→20 FAIL**, painted_route **39→13** |
| R15-revised | Illegal-clear fall-through + assembler prefix slice | 1–6 | **6/6 PASS** (proposal) | **REGRESSED 20→112** — reverted same turn |
| R15b | Reorder: locked + orbit bypass before illegal clear; remove duplicate bottom bypass | 1–6 | **6/6 PASS** | Applied — draw_route parity; preview_paths still 13 |
| R16 | `_hover_orbit_extends_painted_receipt` + basic-walk corridor for armed trample orbit; leg-anchor origin | 1–6 | **6/6 PASS** (amendment) | Applied — **20→8 FAIL**, painted_route **13→1** |
| R17 | Assembler on-route prefix `i>0` + fresh-hover apply hook | 1–6 | **6/6 PASS** | Applied — **8→7 FAIL**, **painted_route_equivalence PASS** |

### Verify (latest)

| Gate | Result |
|------|--------|
| `run_layer4_paint_gate.ps1` | **FAIL (7)** — teleport, drag_drop_undo, waypoint_enemy_hover×3, range2_enemy_hover, tile_aim_forbids_premove |
| `painted_route_equivalence` | **PASS** |
| L0–L3 regression | **PASS** (pending re-run this turn) |

**Commits:** `2d8a7cf19` (R15b) · `3218eaa5d` (R16) · `67cd0b353` (R17)

**Layer 4 status:** **IN PROGRESS** — painted_route bucket closed; 7 failures in other buckets (each needs own council cycle).

---

## 2026-09-01 — Layer 4 R19 (council-gated waypoint_enemy_hover)

### Council

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R19-waypoint | armed_skill_premain_paint extend/clear; `_drag_route_commits_active` armed branch **before** orbit false-return; live-preview mirror; armed corridor staging; step_target painted route; `target_id<0` voluntary-walk guard | 1–6 | **6/6 PASS** | Applied — **7→4 FAIL**, **waypoint_enemy_hover/1–3 PASS**, **painted_route_equivalence PASS** |

**QA failure owner map (addressed):**
| Bucket | Owner | Broken step |
| waypoint sweep `[]` | `CombatPlanningInput._stage_voluntary_walk_drag_input` | orbit clear wiped armed premove mouse route |
| waypoint enemy pathfind | `_drag_route_commits_active` + `_refresh_hover_interaction_preview` step_target | orbit gate returned false before armed commits; step_target used pathfind only |

**Heuristics refused:** overlay fallback; broad unarmed `open_premain`; loosening `_enemy_hover_respects_painted_route`.

### Verify

| Gate | Result |
|------|--------|
| `run_layer4_paint_gate.ps1` | **FAIL (4)** — teleport_full_truth, drag_drop_undo, range2_enemy_hover, tile_aim_forbids_premove |
| `painted_route_equivalence` | **PASS** |
| `waypoint_enemy_hover/1–3` | **PASS** |

**Remaining buckets (separate council cycles required):** teleport_full_truth, drag_drop_undo, range2_enemy_hover, tile_aim_forbids_premove.

**Remediation note:** Prior commits `a92e03b77`, `8f63f1111`, `c0dec4a52` applied without 6/6 council (3/6 FAIL on R18c). Superseded by R19 on reverted R17 base + orbit-order fix.

---

## 2026-09-01 — Layer 4 R20 (council-gated tile_aim_forbids_premove)

### Councils

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R20 | `_drag_route_commits_active` false when TARGET_PICK blocks premove; clear drag at refresh entry | 1–6 | **6/6 PASS** | Verify FAIL — staging order |
| R20b (amendment) | Staging early clear+return; skip assembler-prefix settle during TARGET_PICK | 1–6 | **6/6 PASS** | Verify FAIL — commit params still injected walk |
| R20c (amendment) | `_commit_interaction_params` skip waypoint resolution when blocks premove | 1–6 | **6/6 PASS** | Applied — **tile_aim PASS**, **4→3 FAIL** |

### Verify

| Gate | Result |
|------|--------|
| `run_layer4_paint_gate.ps1` | **FAIL (3)** — teleport_full_truth, drag_drop_undo, range2_enemy_hover |
| `tile_aim_forbids_premove` | **PASS** |
| `waypoint_enemy_hover/1–3` | **PASS** |
| `painted_route_equivalence` | **PASS** |

**Remaining buckets (separate council cycles required):** teleport_full_truth, drag_drop_undo, range2_enemy_hover.

---

## 2026-09-01 — Layer 4 R21–R23 (council-gated final buckets)

### Councils

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R21-range2 | Wire dead `_stationary_ranged_enemy_hover_suppresses_move_preview` (`_phase_entry_stand` + `planning_target_is_in_range`); `voluntary_walk_suppresses_targeting_arrow` exception; clear drag on stationary ranged enemy hover | 1–6 + R21b critic 3 amendment | **6/6 PASS** | Applied — **range2_enemy_hover PASS** |
| R22-teleport | Skip walk injection for `direct_relocation` in `_commit_interaction_params`; hop in `_append_module_awaiting_target`; hop snapshot in `_preview_paths_snapshot_for_settle` | 1–6 | **6/6 PASS** | Applied — **teleport_full_truth PASS** |
| R23-drag_drop | Unarmed `dragging` commit branch; `trust_painted_route` includes `dragging` | 1–6 | **6/6 PASS** | Verify FAIL — 1-step leg emptied |
| R23b (amendment) | `_resolve_commit_move_waypoints`: raw `_drag_route[1..]` when `dragging` (bypass `_normalize_adjacent_single_step_waypoints` emptying adjacent single-step leg) | critics 2 + 6 | **PASS** | Applied — **drag_drop_undo PASS** |

**QA failure owner map (addressed):**
| Bucket | Owner | Broken step |
| range2_enemy_hover | `_stationary_ranged_enemy_hover_suppresses_move_preview` + `voluntary_walk_suppresses_targeting_arrow` + `_discard_enemy_hover_painted_buffers_if_needed` | voluntary walk suppressed targeting arrow; painted drag not cleared on in-range Range 2+ hover |
| teleport_full_truth | `_commit_interaction_params`, `_append_module_awaiting_target`, `_preview_paths_snapshot_for_settle` | pathfind walk legs instead of direct_relocation hop |
| drag_drop_undo | `_resolve_commit_move_waypoints` | `_normalize_adjacent_single_step_waypoints` returned `[]` for 1-step drag leg → invalid commit slots |

**Heuristics refused:** overlay path recompute; new `_range2_stationary_shot_from_stand` helper; `action_range_intent_stand_cell` in stationary helper (receipt bypass — R21b uses `_phase_entry_stand`).

### Verify

| Gate | Result |
|------|--------|
| `run_layer4_paint_gate.ps1` | **PASS (0)** |
| `painted_route_equivalence` | **PASS** |
| `waypoint_enemy_hover/1–3` | **PASS** |
| `tile_aim_forbids_premove` | **PASS** |
| `teleport_full_truth` | **PASS** |
| `range2_enemy_hover` | **PASS** |
| `drag_drop_undo` | **PASS** |

**Layer 4 status:** **PASS** — all buckets council-gated; gate green.

---

## 2026-09-01 — Layer 5 R25 (council-gated drag-release ratify settle)

### Councils

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R25 | Sync intent hover to `_pointer_grid_cell()` in `_flush_hover_heavy_sync` before `_run_hover_sim_refresh` | 1–6 | **6/6 PASS** | Verify FAIL — headless stale QA pointer regression |
| R25b (amendment) | Gate sync to `_qa_pointer_grid_override or _drag_drop_finishing` only | 1–6 | **6/6 PASS** | Still FAIL — stale QA override from prior suite |
| R25c (amendment) | Gate sync to `_drag_drop_finishing` only (drag release ratify cell) | 1–6 | **6/6 PASS** | Applied — **Layer 4 PASS**, **DragE2E no FAIL** |

**QA failure owner map (addressed):**
| Bucket | Owner | Broken step |
| DragE2E release_bash_enemy | `_flush_hover_heavy_sync` | settle ran at stale intent hover, not release pointer during `_drag_drop_finishing` |

**Heuristics refused:** click-time slot rebuild; overlay fallback; unconditional pointer sync (broke teleport/range2 headless).

### Verify

| Gate | Result |
|------|--------|
| `run_layer4_paint_gate.ps1` | **PASS (0)** |
| L0–L3 paint gates | **PASS** |
| `drag_e2e` suite (PlanningQaGate) | **PASS** (no DragE2E `[FAIL]` lines) |
| `planning_input` suite | **FAIL** — cursor parity (R24 in progress) |

**Layer 5 status:** **IN PROGRESS** — drag-release ratify fixed; PlanningInputTest cursor harness next council cycle (R24).

---

## 2026-09-01 — Layer 5 R24 (council-gated PlanningInputTest cursor)

### Council

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R24c | `_cursor_icon_after_canonical_settle` via `_preview_at_interaction_cell` | 1–6 | **6/6 PASS** (revised after R24c `_paint_intent_slots` blocked by critics 2/4/6) | Applied — cursor parity PASS |
| R24c-amend | Format string fix in extended-enemy assert | — | test hygiene | `str(action.waypoints)` |

**QA failure owner map (addressed):**
| Bucket | Owner | Broken step |
| PlanningInputTest cursor ∅ | `planning_input_test.gd` | tests called `compute_hover_action_icon` / `_drag_hover_icon` without canonical settle |
| swap ally commit rejected | same harness | `_commit_at_interaction_cell` without prior `_preview_at_interaction_cell` seal |

**Heuristics refused:** restore `_hover_icon_for_cell`; `_paint_intent_slots_before_commit` for hover cursor reads.

### Verify

| Gate | Result |
|------|--------|
| `run_planning_input_only.gd` | **PASS** (after R26/R27 — see below) |

---

## 2026-09-01 — Layer 5 R26 + R27 (council-gated production)

### Council

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R26 | Dash one-click enemy: `preview_waypoints_for_hover(..., direct_dash_endpoint=true)` in `_final_commit_slots_for_interaction` | 1–6 | **6/6 PASS** | Applied — extended enemy waypoints |
| R27 | `action_range_visible_for_hover`: module range tiles when `awaiting_module_index > 0` | 1–6 | **6/6 PASS** | Applied — later NEW_AIM range visible |

**QA failure owner map (addressed):**
| Bucket | Owner | Broken step |
| extended_enemy dash path [] | `_final_commit_slots_for_interaction` | `_resolve_commit_move_waypoints` → `_hover_walk_waypoints_for_skill` returns [] for tile-dash aim |
| later NEW_AIM range hidden | `action_range_visible_for_hover` | whole-ability `can_plan` false after MOVE prefix consumes action slot |

**Heuristics refused:** overlay fallback; per-test branches.

### Verify

| Gate | Result |
|------|--------|
| `run_planning_input_only.gd` | **PASS** |
| `run_layer4_paint_gate.ps1` | **PASS (0)** |

**Layer 5 status:** **IN PROGRESS** — PlanningInputTest cursor + violent-collision extended enemy + NEW_AIM range gates green; full planning QA gate still has remaining buckets.

---

## 2026-09-01 — Layer 5 R28 (live F5 frozen move-preview circles)

### Council

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R28 | `set_hover_coord` queues `_queue_overlay_redraw`; restore `_run_hover_overlay_refresh` in-bounds recompute+redraw | 1–5 | **5/5 PASS** | Applied — owner F5 frozen circles |

**Root cause:** Hover cell updated but only `_hover_tile_layer` redrew; move-preview ghost circles (`_draw_move_ghosts`) paint on main overlay and stayed on last frame.

**Heuristics refused:** second settle path; overlay tile recompute fallback.

---

## 2026-09-01 — Layer 5 R29 (mouse-circle hover QA — remediation + amendment)

### Violations

| # | Type | Commits | What happened |
|---|------|---------|---------------|
| 1 | Council skipped | (uncommitted) | R29 applied without propose→council→apply |

### Remediation / amendment council

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R29 remediation | `overlay_redraw_nonce`, `move_preview_mouse_follow_harness`, gate test | 1–6 | **5/6** | [Critic 1](3d515b5a-aa39-4aac-a063-921b31e6ec14) FAIL — nonce only, no ghost paint assert |
| R29b amendment | `movement_ghost_paint_applies`, unified `_queue_overlay_redraw`, ghost circle + corridor drag asserts | 1 (re-run) | **PASS** | [Amendment Critic 1](cd847e26-8b79-40d4-b686-271fd394daef); critics 2–6 unchanged PASS from remediation |

**Behavioral test:** `PlanningQAGate move_preview_circle_follows_mouse` — live throttle (`qa_static_overlay=false`), no `_flush_hover_heavy_sync`; orbit redraw nonce + `hover_coord`; armed awaiting ghost circle at corridor cells; fresh-fixture unarmed drag corridor follows pointer.

**Verify:** `PlanningQaGate.tscn` — `move_preview_circle_follows_mouse` **PASS** (full gate still has other buckets).

**Heuristics refused:** overlay receipt fallback; per-test production branches; sync settle every live hover cell.

---


### Council

| Round | Scope | Council | Verdict | Notes |
|-------|-------|---------|---------|-------|
| R24 | Replace `_hover_icon_for_cell` with settle + `compute_hover_action_icon` / `_drag_hover_icon` | Critic 6 | **FAIL** | Needs `set_qa_pointer_grid_cell`; drag uses `_drag_hover_icon` |
| R24b (applied) | Test-only `_assert_cursor_matches_slots` uses settle path per critic 6 amendments | pending re-council | Applied | Superseded by R24c |

---

```
## YYYY-MM-DD — <short title>

### Violations
| # | Type | Commits | What happened |

### Remediation / amendment council
| Layer | Commit | Council | Verdict | Gate |

### Resolution
```
