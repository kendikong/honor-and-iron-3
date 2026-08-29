# Planning voluntary-walk gauntlet backlog

**Status:** ACTIVE — living gap list for the planning refactor gauntlet.  
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
| GAP-001 | HIGH | MOVE_PREVIEW_RULES §88 (L88); Live vs frozen table | On **illegal movement-step hover**, sealed-leg restore (`_sealed_leg_hover_restore_if_blocked` / `should_restore_locked_route`) can **re-show blue walk path** instead of **no preview** | OPEN | `combat_planning_input.gd` ~2202–2216, ~5015–5025; `planning_route_policy.gd` ~40–44 | — | — |
| GAP-002 | HIGH | MOVE_PREVIEW_RULES § Stand/origin (L36–46); matrix R1 | Parallel walk-related origin stack: `_proj_origin()` in input (skill/awaiting geometry) vs canonical `_phase_entry_stand` / `forecast_stand_at_phase_entry` | OPEN | `combat_planning_input.gd` `_proj_origin` ~6652+; 15+ call sites | — | — |
| GAP-003 | MED | MOVE_PREVIEW_RULES architecture table (L250); matrix R1/R3 | Overlay `_proj_origin` uses `planning_latest_stand_cell` — can diverge from `phase_entry_stand_cell` when sealed leg exists | OPEN | `tactical_planning_overlay.gd` ~2545–2548 | — | — |
| GAP-004 | MED | MOVE_PREVIEW_RULES §88 vs Pass 28 sealed survival | Doc tension: §88 says invalid hover = no preview; Pass 28 / sealed policy allows restore on non-extend hovers — **owner must pick one rule** or split “frozen sealed” vs “illegal hover” explicitly in bible | OPEN | `MOVE_PREVIEW_RULES.md` L88 vs L367/L408; `planning_route_policy.gd` | — | — |

---

## Verify queue (prior fixes — must re-prove each round)

Rows that a prior round claimed fixed. Pass A must confirm still true; mark `REGRESSED` if not.

| ID | Bible / matrix ref | Claimed fix | Status | Evidence | Verified round |
|----|-------------------|-------------|--------|----------|----------------|
| FIX-001 | Matrix symbols eliminated | Retired symbol names absent from `presentation/` | VERIFY | grep matrix symbol list → 0 hits | 26 |
| FIX-002 | §88; size≥2 writes | `set_unit_preview_path` / `assign_preview_path_dict` reject `path.size() < 2`; illegal hover entry clear in `_refresh_voluntary_walk_hover_preview` | VERIFY | `combat_planning_preview.gd` ~43–55; `combat_planning_input.gd` ~5015+ | 26 |
| FIX-003 | PRE≡MOVE≡POST; matrix R7 | Orbit/trim/clamp use `active_movement_planning_step` + `get_planning_move_timing`, not POST-only | VERIFY | `_voluntary_walk_orbit_phase_open` ~4930+; `_voluntary_walk_drag_trim_active` ~4879+ | 26 |
| FIX-004 | R6; movement-step sole owner | Sim paint gated on movement step: `_apply_live_preview`, `_refresh_drag_preview_now`, `refresh_live_preview`, `_refresh_live_interaction_preview`, `on_hover_moved`, `_flush_hover_heavy_sync`, `_should_run_hover_sim_sync` | VERIFY | `combat_planning_input.gd` movement-step early returns | 26 |
| FIX-005 | R8 | Player voluntary walk commit only via `_try_commit_voluntary_walk` → `_append_move_to_commit_slots` | VERIFY | `TimelineAction.make_move` in input only at `_append_move_to_commit_slots` | 26 |
| FIX-006 | R1/R4 paint+commit | Voluntary walk paint/commit use `_phase_entry_stand` at assembler and commit | VERIFY | `_assemble_voluntary_walk_preview_path`, `_append_move_to_commit_slots` | 26 |

---

## Round history

| Round | Commit | Regression (Pass A) | Bible (Pass B) | Score | Notes |
|-------|--------|---------------------|----------------|---------|-------|
| 25 | `006631aca` | not run as backlog | partial static grep only | 87 | **Invalid as full loop** — narrow BAR, no Pass B |
| 26 | `006631aca` | FIX-* not formalized | fresh audit | 52 FAIL | Seeded GAP-001–004; loop method flawed |

---

## Changelog (backlog only)

| Date | Change |
|------|--------|
| 2026-08-29 | Created backlog; seeded from round 26 fresh audit; retracted round 25 as non-conforming loop |
