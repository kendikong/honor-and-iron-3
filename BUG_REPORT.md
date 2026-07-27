# Bug Report Contract

Use this format when reporting a gameplay bug. Plain language is enough; do not
diagnose code or suggest an implementation.

## Report

1. **Setup:** map, unit/class, relevant selected skill, and any committed actions.
2. **Steps:** the exact clicks or drag route, including each tile in order.
3. **Expected:** one sentence stating the intended player-facing rule.
4. **Actual:** what differed (path, facing, AP/MP, target, damage, overlay, animation).
5. **Evidence (optional):** screenshot, console error, or short video.

## Example

1. **Setup:** Knight at `(6,3)`, Trampling Advance selected.
2. **Steps:** paint `(7,3)` then `(7,2)` and commit the skill.
3. **Expected:** the preview arrow, committed action, and executed walk all go east then north.
4. **Actual:** arrow goes east then north; execution goes north then east.

## Verification policy

For every confirmed mechanical bug, the fix must add or extend a deterministic
test under `tests/`. The test runs the production planning, movement, or
simulation API and asserts the exact result. Visual feel and pixel-art
authorship still require a user runtime check.

## Run the regression suite

```powershell
.\scripts\run_regression_tests.ps1 `
  -GodotPath "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
```

Trampling-only (fast):

```powershell
& "<godot.exe>" --headless --path . --script res://tests/run_trampling_only.gd
```

The command prints the complete result and returns a nonzero exit code when any
assertion fails. The raw report is saved outside the repository at
`user://regression_test_result.txt`.

## Trampling Advance path regression

`tests/trampling_advance_e2e_test.gd` mirrors TestBattle:

1. Select real `knight_trampling_advance` from `DataLibrary`
2. Arm awaiting on the Knight tile
3. Drag `(5,4) -> (6,4) -> (6,3)` (east then north)
4. Commit, then assert waypoints, painted preview path, overlay route leg,
   director skill-walk waypoints, simulator `UNIT_MOVED` order, and optional
   post-move continuation

If this file passes but the game still looks wrong, the bug is in presentation
animation or overlay draw timing — not in commit-slot data.
