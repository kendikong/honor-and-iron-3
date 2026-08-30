# Hover Preview Carried SSOT — Plan & Goals

**Date:** 2026-08-30  
**Status:** ACTIVE — Phase 2 complete (settle-only + structural gate + step-6 regression run)  
**Rules:** [`MOVE_PREVIEW_RULES.md`](MOVE_PREVIEW_RULES.md)  
**Gate:** `.\scripts\run_hover_preview_ssot_gate.ps1` (first step before planning QA)

## One sentence

The **hover preview** is born once at **settle**, carried in a **sealed bundle** through display and click; **ratify** copies it — no second geometry path.

---

## Why this exists

| Problem | What went wrong |
|---------|-----------------|
| QA overfitting | Agents added commit-time `if`/fallbacks to green tests instead of fixing architecture |
| Multiple truths | Hover painted paths, slots built separately, merge functions papered over gaps |
| False compliance | Milestones/grep passed while commit still rebuilt intent |
| Owner rule ignored | "Hover paints intent. Click freezes it." was documented but not structurally enforced |

**Goal:** Make preview≠commit **hard to ship** — not more scenario QA, not longer rules.

---

## What SSOT means here

Not slots alone, not `preview_paths` alone. The **settled hover preview bundle** (paths + slots + facing + sim board) is the only intent. Every layer **carries** it:

```
settle → display (read-only) → ratify (copy) → timeline → execute
```

If commit needs geometry the hover did not show → **fix settle**, never patch at commit.

---

## Carried bundle

`PlanningHoverPreview` (`presentation/planning_hover_preview.gd`):

- Born only when hover **settles** (`_preview_from_commit_slots_at_cell` / `settle_hover_preview_at_cell`)
- Holds: slots, `preview_paths` snapshot, hover cell, unit id, facing, revision key
- **Sealed** after settle (`is_sealed`); `validate_geometry()` asserts slots waypoints == `preview_paths` leg
- **Ratify** = `commit_from_slots(duplicate(bundle.slots))` — no waypoints args, no fill-at-commit

Public read API: `CombatPlanningInput.get_settled_hover_preview()`.

Settle builds matching `preview_paths` via `_preview_paths_snapshot_for_settle` before seal (same owner as slots — not paint-first).

---

## Settle modes

| Mode | When | Commit |
|------|------|--------|
| **LIVE** | Movement step, legal hover | Ratify sealed bundle |
| **FROZEN_REPLAY** | Non-move / sealed restore | Display only |
| **NONE** | Invalid movement hover | Reject |

Exceptions (separate UI, not voluntary-walk settle): teleport hop, forced push/pull.

---

## Structural protection (hard to break / obvious when cheated)

1. **Tiny ratify** — `_commit_at_cell` rejects if no sealed bundle (no rebuild `else`)
2. **One settle owner** — all hover paths → `_preview_from_commit_slots_at_cell`
3. **Grep gate** — CI fails on forbidden symbols + paint-before-settle comment
4. **Loud geometry assert** — `SSOT BREAK: preview_paths leg … != slots waypoints …`
5. **Harness reads bundle** — `slots_for_hover` uses `get_settled_hover_preview()`, not `[]` waypoints rebuild
6. **Dead commit mutators deleted** — no `_ensure_move_*` / `_ratify_painted_route_*` at commit

---

## Forbidden (gate enforces)

- Paint-before-settle in voluntary walk (`## Paint preview_paths in memory first`)
- `_apply_preview_result_preserving_hover_paths` / `_authoritative_move_hover_paths_payload`
- Commit rebuild on click (`_final_commit_slots_for_interaction` in `_commit_at_cell`)
- `_ensure_move_waypoints_on_commit_slots` / `_ensure_movement_waypoints_on_commit_slots`
- `_ratify_painted_route_on_commit_slots`
- `_apply_facing_to_slots` on click (facing sealed at settle)
- Post-click geometry refresh (`_refresh_hover_interaction_preview` after commit)

---

## Rollout

| Step | Status |
|------|--------|
| 1. `PlanningHoverPreview` + SSOT gate script | ✅ |
| 2. Ratify snapshot-only commit | ✅ |
| 3. Voluntary walk settle-only (no paint-first) | ✅ |
| 4. Harness → `get_settled_hover_preview()` | ✅ |
| 5. SOT geometry row in `intent_source_of_truth_gate_test.gd` | ✅ |
| 6. Full planning gate once | ✅ run 2026-08-30 — see results below |

**Scope freeze lifted** for WALK-01 / MOVE-SKILL-01 (intent SOT signatures green). Remaining T3 parity fails are tracked separately — not commit-fallback scope.

### Step 6 gate results (2026-08-30)

| Suite | Result |
|-------|--------|
| `run_hover_preview_ssot_gate.ps1` | **PASS** |
| AOE footprint contract | **PASS** |
| Intent SOT — WALK-01, MOVE-SKILL-01, PUSH-PULL, SWAP, AWAIT, TRAMPLE, STALE | **PASS** (SOT-SIG rows) |
| T3 mimic fixture parity | **FAIL** — 5 rows (pre-existing / ratify-only fallout; no SSOT BREAK spam after settle-path fix) |

T3 `[FAIL]` lines (fix in follow-up — do **not** add commit rebuild):

- `ActionRangeRegression bowling_awaiting_occupied_end`
- `ActionRangeRegression awaiting_module_range_after_premove`
- `PlanningQAGate drag_drop_undo`
- `PlanningQAGate hover order`
- `PlanningQAGate move_preview_origin`

CM-08 stale-waypoints harness hits script OOB at `planning_qa_gate_test.gd:1642` when bundle ratify rejects stale hover — harness must read bundle, not assume rebuild.

---

## QA order (do not invert)

1. `run_hover_preview_ssot_gate.ps1` — structural
2. `intent_source_of_truth_gate_test` — geometry + four-way
3. `run_planning_qa_gate.ps1` — once, regression alarm only

On FAIL after (1–2) green: **delete branch or fix toxic test** — never commit fallback.
