# Planning voluntary-walk gauntlet backlog

**Status:** RULE ABIDANCE COMPLETE (gauntlet round 31) — reopen only on regression or new bible gap.  
**Loop contract:** `docs/design/PLANNING_GAUNTLET_LOOP.md`  
**Owner bible:** `docs/design/MOVE_PREVIEW_RULES.md` · **Matrix:** `docs/design/PLANNING_REFACTOR_MATRIX.md`  
**Critic agent:** `.cursor/agents/gauntlet-critic.md` § Two-pass bible loop

Every critic round runs **Pass A** (verify every `OPEN` row here) then **Pass B** (fresh line-by-line bible audit). New Pass B gaps are appended with new IDs.

---

## How to use

| Pass | Critic must |
|------|-------------|
| **A — Regression** | For each row with `Status: OPEN` or `VERIFY`, read code and mark `FIXED` / `STILL_OPEN` / `REGRESSED` with file:line evidence. |
| **B — Fresh bible** | Re-read `MOVE_PREVIEW_RULES.md` (full) + matrix R1–R12. Any new HIGH gap → new row, `Status: OPEN`. |

**Overall RESULT:** `PASS` only when Pass A has **zero** `OPEN`/`STILL_OPEN`/`REGRESSED` **and** Pass B adds **zero** new HIGH gaps.

**Do not** replace Pass B with a narrow grep checklist. **Do not** skip Pass A because Pass B is clean.

---

## Open gaps (Pass A queue)

| ID | Severity | Bible / matrix ref | Gap | Status | Evidence (file:line) | Fixed commit | Verified round |
|----|----------|-------------------|-----|--------|----------------------|--------------|----------------|
| *(none — all HIGH/MED gaps closed through round 31)* |

---

## Closed gaps (reference)

| ID | Severity | Summary | Fixed commit | Verified round |
|----|----------|---------|--------------|----------------|
| GAP-001 | HIGH | Illegal movement-step hover must not sealed-restore blue path | `6aecc295e` | 27 |
| GAP-002 | HIGH | Input `_proj_origin` delegates `_phase_entry_stand` | `6aecc295e` | 27 |
| GAP-003 | MED | Overlay `_proj_origin` uses `forecast_stand_at_phase_entry` + preview | `edb324bdb` | 29 |
| GAP-004 | MED | Bible § invalid hover vs sealed restore | `6aecc295e` | 27 |
| GAP-005 | HIGH | Unified `planning_move_origin_cell` + `sealed_phase_entry_anchor` | `edb324bdb` | 29 |
| GAP-006 | HIGH | `anchor_preview_paths_to_latest_stand` sealed overwrite | `3ddabb40f` | 29 |
| GAP-007 | HIGH | `_seed_movement_origins` passes preview | `3ddabb40f` | 29 |
| GAP-008 | HIGH | Director `planning_live_preview` + waypoint pass-through | `3ddabb40f` | 29 |
| GAP-009 | MED | Blue flood / pathfinding fork: MOVE module used skill pathfinding while PRE/POST used basic walk | `a441018a3` | 31 |

---

## Verify queue (prior fixes — must re-prove each round)

| ID | Bible / matrix ref | Claimed fix | Status | Evidence | Verified round |
|----|-------------------|-------------|--------|----------|----------------|
| FIX-001 | Matrix symbols eliminated | Retired symbol names absent from `presentation/` | FIXED | grep matrix symbol list → 0 hits | 31 |
| FIX-002 | §88; size≥2 writes | `set_unit_preview_path` / `assign_preview_path_dict` reject `path.size() < 2`; illegal hover entry clear | FIXED | `combat_planning_preview.gd` ~43–55; `combat_planning_input.gd` ~5020+ | 31 |
| FIX-003 | PRE≡MOVE≡POST; matrix R7 | Orbit/trim/clamp use `active_movement_planning_step` + `get_planning_move_timing`; pathfinding via `_basic_walk_pathfinding_active` | FIXED | `_voluntary_walk_orbit_phase_open` ~4941+; `_basic_walk_pathfinding_active` ~4876+ (GAP-009) | 31 |
| FIX-004 | R6; movement-step sole owner | Sim paint gated on movement step | FIXED | `combat_planning_input.gd` movement-step early returns | 31 |
| FIX-005 | R8 | Player voluntary walk commit only via `_try_commit_voluntary_walk` → `_append_move_to_commit_slots` | FIXED | `TimelineAction.make_move` in input only at `_append_move_to_commit_slots` ~7035 | 31 |
| FIX-006 | R1/R4 paint+commit | Voluntary walk paint/commit use `_phase_entry_stand` | FIXED | `_assemble_voluntary_walk_preview_path`, `_append_move_to_commit_slots` | 31 |

---

## Round history

| Round | Commit | Regression (Pass A) | Bible (Pass B) | Score | Notes |
|-------|--------|---------------------|----------------|---------|-------|
| 25 | `006631aca` | not run as backlog | partial static grep only | 87 | **Invalid as full loop** — narrow BAR, no Pass B |
| 26 | `006631aca` | FIX-* not formalized | fresh audit | 52 FAIL | Seeded GAP-001–004; loop method flawed |
| 27 | `6aecc295e` | GAP-001–004 FIXED | GAP-005 HIGH new | 81 FAIL | First conforming two-pass |
| 28 | `edb324bdb` | GAP-005 REGRESSED | GAP-006–008 HIGH new | 72 FAIL | Origin API unified; merge paths still leaked |
| 30 | `0942e736` | all GAP/FIX PASS | no new HIGH | 86 PASS | `move_leg_origin_cell` SSOT; backlog/matrix synced |
| 31 | `64f67530a` | GAP-009 + FIX-001..006 FIXED | no new HIGH | 88 PASS | Unified pathfinding; gate = T3 mimic only; legacy PlanningQaGate archaeology |

---

## Changelog (backlog only)

| Date | Change |
|------|--------|
| 2026-08-29 | Created backlog; seeded from round 26 fresh audit; retracted round 25 as non-conforming loop |
| 2026-08-30 | Round 31: GAP-009 closed; FIX-001–006 re-verified; static two-pass PASS score 88 (`PLANNING_GAUNTLET_ROUND31.md`); legacy PlanningQaGate archaeology |
