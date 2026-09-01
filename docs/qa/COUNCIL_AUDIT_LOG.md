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

```
## YYYY-MM-DD — <short title>

### Violations
| # | Type | Commits | What happened |

### Remediation / amendment council
| Layer | Commit | Council | Verdict | Gate |

### Resolution
```
