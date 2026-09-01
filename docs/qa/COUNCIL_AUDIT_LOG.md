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

```
## YYYY-MM-DD — <short title>

### Violations
| # | Type | Commits | What happened |

### Remediation / amendment council
| Layer | Commit | Council | Verdict | Gate |

### Resolution
```
