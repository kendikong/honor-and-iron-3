# Milestone — Planning voluntary-walk refactor (gauntlet complete)

**Owner reference doc** — read this first if you suspect the refactor was faked, incomplete, or overstated.  
**Declared:** 2026-08-30 (UTC-7)  
**Pin commit (full milestone tree):** `0b610706be236ddbfebc1c1556fae27d91689f1d`  
**Code pin (GAP-010–012):** `39aea42b3d3252ed24d276445b190fa648f68054`  
**Round 31 doc pass pin:** `6edd482d679acaa202c617217e87be7ea36b35ed` · report `PLANNING_GAUNTLET_ROUND31.md`

---

## What was claimed (plain language)

The **planning voluntary-walk stack** (premove, MOVE-module walk legs, postmove) was refactored to **one pipeline**:

- **One origin:** forecast stand at phase entry (`_phase_entry_stand` / `forecast_stand_at_phase_entry`)
- **One hover paint owner:** `_refresh_voluntary_walk_hover_preview`
- **One commit path:** `_try_commit_voluntary_walk` → `_append_move_to_commit_slots`
- **One movement-step gate:** `active_movement_planning_step` (+ `_basic_walk_pathfinding_active` for blue flood)
- **Matrix R1–R12:** all rows `DONE` in `PLANNING_REFACTOR_MATRIX.md`
- **Gauntlet backlog:** GAP-001 through GAP-012 closed; FIX-001 through FIX-006 verified at round 31

**Gauntlet round 31** (static two-pass, **NO_QA**): `REGRESSION_PASS` + `BIBLE_PASS`, score **88/100**.  
**Round 32** (same day): independent audit found three MED gaps; fixed same session (GAP-010–012).

---

## What was NOT claimed (read before getting mad)

| Limitation | Meaning |
|------------|---------|
| **NO_QA on milestone close** | Owner explicitly waived automated + F5 runs for gauntlet rounds 31–32. Static grep/read only. |
| **WP-9 not done** | No owner F5 spot-check (sprites, settle timing, FPS). Listed as `OWNER` in matrix — not gate-blocking. |
| **Legacy `PlanningQaGate.tscn`** | ~300+ headless fixture failures expected; **demoted archaeology**. Default gate = T3 mimic + AOE only (`run_planning_qa_gate.ps1`). |
| **Round 31 self-grade** | Independent harsh re-critique (before round 32 fixes) scored **79/100** and called “100%” **overstated** due to label forks — those forks were then closed in round 32. |
| **Class kits** | This milestone is **planning voluntary-walk only**, not full class QA / Bible LOCK. |
| **Historical pass notes** | Archived in `MOVE_PREVIEW_IMPLEMENTATION_LOG.md` — not owner rules. |

If gameplay feels wrong in F5, that is **not** disproven by this milestone — it was never runtime-proven at close.

---

## Evidence chain (where the work lives)

| Artifact | Role |
|----------|------|
| [`MOVE_PREVIEW_RULES.md`](MOVE_PREVIEW_RULES.md) | Owner rules — short global behavior spec |
| [`MOVE_PREVIEW_IMPLEMENTATION_LOG.md`](MOVE_PREVIEW_IMPLEMENTATION_LOG.md) | Agent build diary — pass history, symbol tables (not rules) |
| [`PLANNING_REFACTOR_MATRIX.md`](PLANNING_REFACTOR_MATRIX.md) | R1–R12 rule matrix (survives chat summarization) |
| [`PLANNING_GAUNTLET_BACKLOG.md`](PLANNING_GAUNTLET_BACKLOG.md) | Every gap ID, fix commit, round history |
| [`PLANNING_GAUNTLET_LOOP.md`](PLANNING_GAUNTLET_LOOP.md) | Two-pass critic contract (regression + fresh bible) |
| [`PLANNING_GAUNTLET_ROUND31.md`](PLANNING_GAUNTLET_ROUND31.md) | Round 31 static critic report (score 88) |
| [`PLANNING_QA_GATE.md`](../qa/planning/PLANNING_QA_GATE.md) | Which test suites block vs archaeology |

**Primary code owners:**

- `presentation/combat_planning_input.gd` — hover, drag, commit, movement-step gates
- `presentation/combat_planning_preview.gd` — forecast stand, sealed leg, corridor SSOT
- `presentation/tactical_planning_overlay.gd` — red range (never `base_board` for action range)
- `presentation/combat_director.gd` — `planning_timeline_phase_kind` phase cursor
- `core/systems/planning_route_policy.gd` — sealed-leg hover policy

---

## All closed gaps (audit trail)

| ID | Sev | Summary | Commit |
|----|-----|---------|--------|
| GAP-001 | HIGH | Illegal movement-step hover must not sealed-restore blue path | `6aecc295e` |
| GAP-002 | HIGH | Input `_proj_origin` → `_phase_entry_stand` | `6aecc295e` |
| GAP-003 | MED | Overlay `_proj_origin` uses forecast + preview | `edb324bdb` |
| GAP-004 | MED | Bible § invalid hover vs sealed restore | `6aecc295e` |
| GAP-005 | HIGH | Unified `planning_move_origin_cell` + sealed anchor | `edb324bdb` |
| GAP-006 | HIGH | Sealed stand overwrite on sim merge | `3ddabb40f` |
| GAP-007 | HIGH | `_seed_movement_origins` passes preview | `3ddabb40f` |
| GAP-008 | HIGH | Director `planning_live_preview` wired | `3ddabb40f` |
| GAP-009 | MED | MOVE-module pathfinding unified with PRE/POST basic walk | `a441018a3` |
| GAP-010 | MED | Removed `_planning_phase_allows_live_path_stand` label fork | `39aea42b3` |
| GAP-011 | MED | Swap approach uses `preview_board` not `base_board` | `39aea42b3` |
| GAP-012 | MED | Action-range tail guarded by movement step | `39aea42b3` |

---

## Gauntlet round summary

| Round | Result | Score | Notes |
|-------|--------|-------|-------|
| 25 | **Invalid** | 87 | Narrow grep only — retracted |
| 26–28 | FAIL | 52–81 | Seeded backlog; first conforming two-pass from 27 |
| 30 | PASS | 86 | `move_leg_origin_cell` SSOT |
| **31** | **PASS** | **88** | Static two-pass; GAP-001–009 + FIX-*; NO_QA |
| **32** | **PASS** | **88** | Post-audit MED fixes GAP-010–012; NO_QA |

---

## How to re-verify if you think work was missed

Run these yourself (or ask an agent with **QA enabled**):

1. **Checkout pin:** `git checkout 0b610706be236ddbfebc1c1556fae27d91689f1d`
2. **Backlog regression:** Open `PLANNING_GAUNTLET_BACKLOG.md` — confirm zero open gaps; grep each GAP fix at cited commits.
3. **Matrix:** Walk R1–R12 in `PLANNING_REFACTOR_MATRIX.md` against code (owners listed above).
4. **Retired symbols:** `rg "force_basic_movement|_planning_phase_allows_live_path_stand|_active_move_drag_origin" presentation/` → expect **0 hits**.
5. **Movement-step gate:** `rg "PREMOVE_MOVEMENT|POSTMOVE_MOVEMENT" presentation/combat_planning_input.gd` → only **R5** phase-cursor / timing sites (not pathfinding/corridor).
6. **Automated gate (when you want proof):** `.\scripts\run_planning_qa_gate.ps1` (T3 mimic + AOE; not legacy PlanningQaGate).
7. **F5 parity (optional):** `.\scripts\run_planning_scene_acceptance.ps1` (WP-9 owner layer).
8. **Fresh harsh critic:** Handoff per `PLANNING_GAUNTLET_LOOP.md` with `NO_QA: no` if you want runtime BAR.

If step 6–7 fail after this pin, the milestone claim was wrong for **behavior** even if architecture docs were green.

---

## Changelog (milestone doc only)

| Date | Change |
|------|--------|
| 2026-08-30 | Created owner milestone record after gauntlet rounds 31–32 |
