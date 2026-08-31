# Hover Preview Carried SSOT — Plan & Goals

**Date:** 2026-08-30  
**Status:** IMPLEMENTED — ratify-only commit, structural gate enforced  
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

Not slots alone, not `preview_paths` alone. The **settled hover preview bundle** (paths + slots + facing + projected board + move/range/blast paint) is the only intent. Every layer **carries** it:

```
settle → display (read-only) → ratify (copy) → timeline → execute
```

If commit needs geometry the hover did not show → **fix settle**, never patch at commit.

---

## Carried bundle

`PlanningHoverPreview` (`presentation/planning_hover_preview.gd`):

- Born only when hover **settles** (`_preview_from_commit_slots_at_cell` / `settle_hover_preview_at_cell`)
- Holds: slots, `preview_paths` snapshot, projected board, hover cell, unit id, facing, revision key, and settled move/range/blast tiles
- Paint-only settle is explicit and non-ratifiable: it carries display paint when no timeline action is legal, while click still rejects because the bundle has no actions.
- **Sealed** after settle (`is_sealed`); `validate_geometry()` asserts slots waypoints == `preview_paths` leg
- **Ratify** = `commit_from_slots(duplicate(bundle.slots))` — no waypoints args, no fill-at-commit

Public read API: `CombatPlanningInput.get_settled_hover_preview()`.

Settle builds matching `preview_paths` via `_preview_paths_snapshot_for_settle` before seal (same owner as slots — not paint-first).

Click path: `_commit_at_interaction_cell` calls `on_hover_moved(commit_cell)` then `_commit_at_cell` ratifies bundle only.

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
3. **Grep gate** — CI fails on forbidden symbols + paint-before-settle comment + click rebuild
4. **Loud geometry assert** — `SSOT BREAK: preview_paths leg … != slots waypoints …`
5. **Harness reads bundle** — `slots_for_hover` / `slots_for_click` use `get_settled_hover_preview()` only
6. **Dead commit mutators deleted** — no `_ensure_move_*` / `_ratify_painted_route_*` at commit

---

## Forbidden (gate enforces)

- Paint-before-settle in voluntary walk (`## Paint preview_paths in memory first`)
- `_apply_preview_result_preserving_hover_paths` / `_authoritative_move_hover_paths_payload`
- Commit rebuild on click (`_final_commit_slots_for_interaction` in `_commit_at_cell` or `_commit_at_interaction_cell`)
- `_ensure_move_waypoints_on_commit_slots` / `_ensure_movement_waypoints_on_commit_slots`
- `_ratify_painted_route_on_commit_slots`
- `_apply_facing_to_slots` on click (facing sealed at settle)
- Post-click geometry refresh (`_refresh_hover_interaction_preview` after commit)
- Harness `[]` waypoints rebuild fallback

---

## Rollout

| Step | Status |
|------|--------|
| 1. `PlanningHoverPreview` + SSOT gate script | ✅ |
| 2. Ratify snapshot-only commit | ✅ |
| 3. Voluntary walk settle-only (no paint-first) | ✅ |
| 4. Harness → `get_settled_hover_preview()` | ✅ |
| 5. SOT geometry row in `intent_source_of_truth_gate_test.gd` | ✅ |
| 6. Click path finish — no rebuild at `_commit_at_interaction_cell` | ✅ |

---

## QA order (do not invert)

1. `run_hover_preview_ssot_gate.ps1` — structural
2. `intent_source_of_truth_gate_test` — geometry + four-way
3. `run_planning_qa_gate.ps1` — regression alarm only

On FAIL after (1–2) green: **delete branch or fix toxic test** — never commit fallback.
