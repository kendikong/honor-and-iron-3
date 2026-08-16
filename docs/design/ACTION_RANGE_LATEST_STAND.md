# Action range latest-stand — failure log

**Always-on rule:** `.cursor/rules/action-range-latest-stand.mdc`

This file is a **permanent record**. Append. Never delete past entries. The next agent who “fixes red tiles on the old cell” must read this **before** writing code.

Owner-visible symptom: unit already walked (ghost / sprite at the new tile), but **red skill tiles still bloom around the turn-start cell**.

---

## How to use this log

1. Read every entry below. The last one is what just failed.
2. Do **not** repeat a listed mistake (especially `base_board` as range origin).
3. Add a test that would have failed **that** commit.
4. If you ship another broken attempt, **append an entry** with the commit hash, the shortcut you took, and why the existing tests did not catch it.

---

## Failure log

### 2026-08-15 — `37b3879d591ba3907edf48e0c0c152c19a0e9053` — BUG-20260815T183841-612

**What the player did:** Bruiser pre-moved `(5,3) → (7,3)`, then armed Charge Strike (awaiting MOVE module). Sprite at `(7,3)`. Red diamond still centered on `(5,3)`.

**What the agent was trying to fix:** modular Charge Strike — lock MOVE while a later NEW_AIM awaits; stop dest-commit from stealing walk tiles; apply MOVE prefix in sim.

**The shortcut that broke red tiles:** In `presentation/tactical_planning_overlay.gd` `_planning_action_range_tiles_for_unit`, awaiting skills called:

`AbilitySystem.planning_module_range_tiles(director.base_board, awaiting, module_index)`

Reasoning at the time: “don’t double-apply the MOVE prefix on already-projected state.” That is **wrong**. Double-apply is already `_prefix_already_applied`. `base_board` is turn start. After a **walk pre-move** (no skill prefix yet), module 0 range from `base_board` is MOVE 1–2 around `(5,3)`.

The overlay **already had** the correct origin (`_intent_stand_origin` / `action_range_intent_stand_cell` = `(7,3)`). The awaiting branch **threw it away**.

**Why existing tests did not catch it:**

- `ActionRangeRegressionTest` “red follows stand” cases used `planning_action_range_tiles(..., origin)` for **selected, not awaiting-module** Charge Strike. They never took the awaiting `base_board` branch.
- `PlanningInputTest._test_committed_move_prefix_while_later_aim_awaits` even **copied the bug**: it asked `planning_module_range_tiles(director.base_board, …)` and still found the dummy because prefix sim from turn start happened to land correctly for **module 1**. Module 0 after a **walk** pre-move was untested.

**Lesson (do not forget):** Never substitute `base_board` as a range board. Pass **projected / latest-stand board** plus the **intent-stand origin**. Prefix guard is `_prefix_already_applied`, not a second board.

**Regression that must keep failing `37b3879`:** `ActionRangeRegressionTest._test_awaiting_module_range_after_committed_premove` — walk `(5,3)→(7,3)`, arm Charge Strike, red includes a tile only in range from `(7,3)`, excludes a tile only in range from `(5,3)`.

### Earlier related attempts (same owner-visible class of bug)

These did not all use `base_board`, but they are the same **stale origin** class. `tests/action_range_regression_test.gd` exists because the owner kept reporting red tiles on the old cell. That file is **not** a complete lock — a new origin path (awaiting module range) slipped through.

| Commit (short) | What it thought it fixed | Why it did not end the class of bug |
|----------------|--------------------------|-------------------------------------|
| `eec906594` | Paint hover red from ability geometry so tiles follow the cursor | Hover geometry ≠ awaiting-module board. A later branch can still ignore origin. |
| `9140211ea` | Draw blue/red tiles on the overlay child so they appear | Visibility, not origin. |
| `tests/action_range_regression_test.gd` (ongoing) | Pin “red anchors on stand, not knight start” | Cases used full-ability `planning_action_range_tiles` + hover, not awaiting `planning_module_range_tiles(base_board)`. |

If you are about to add **another** range origin, you are probably about to write the next row of this table. Stop. Use `_intent_stand_origin`.

---

## Next attempt checklist (mandatory)

- [ ] I read every failure-log entry above.
- [ ] I am not passing `base_board` into module/action range for overlay red tiles.
- [ ] Overlay awaiting path uses the same `origin` as `_intent_stand_origin`.
- [ ] I added or extended a test that fails the last broken hash if that shortcut returns.
- [ ] If this attempt also fails in F5, I will **append** a new dated entry with the new hash instead of rewriting history.
