# Settled Paint SSOT (move + range + blast)

**Status:** IMPLEMENTED (structural gates + settle seal)  
**Authority:** [`MOVE_PREVIEW_RULES.md`](MOVE_PREVIEW_RULES.md) — this plan implements that spec; on conflict MOVE_PREVIEW wins.

## Model

Same pattern as hover preview carried SSOT:

1. **Settle** — `PlanningPreviewTiles.resolve_paint` computes move tiles, range, blast, and stand data beside the slots; `CombatPlanningInput._store_intent_snapshot` seals all four in `PlanningHoverPreview`.
2. **Display** — `TacticalPlanningOverlay` reads the sealed hover bundle only when its unit, cell, revision, and ability match; an out-of-bounds cursor keeps the last sealed paint without recomputing it.
3. **Ratify** — commit copies the sealed hover slots; the same bundle remains the display truth for all planning tiles.

## Gates

- `scripts/qa/run_action_range_ssot_gate.ps1` — hover-bundle paint ownership + no `base_board` in range helpers
- `scripts/qa/run_footprint_ssot_gate.ps1` — blast tiles owned by `PlanningPreviewTiles` and carried by the hover bundle
- `scripts/qa/run_planning_ssot_gates.ps1` — runs all structural SSOT gates

Blue movement tiles follow the same rule: they are resolved during settle and carried
as `PlanningHoverPreview.move_tiles`; the selected-unit sealed-display branch does
not call live reachability again.

**MOVE_PREVIEW alignment (no separate “paint-only” doctrine):**

- Any hover where **click would ratify** must use full settle: slots + sim → seal → display → ratify (preview = commit).
- **Locked current-phase** red/blue from phase-entry stand (MOVE_PREVIEW § Tile colors) is not a partial settle — it is the locked field, not a `_noop` bundle.
- **Forbidden:** `_noop` / partial bundles that show commit-shaped intent (path, yellow footprint, walk corridor) without the same slots+sim the click path would ratify.
- When receipt context does not match the cursor: hold last sealed paint (out of bounds) or fix settle — **no overlay recompute** (see Display §2 above).

## Drag = hover

`_process_unit_drop` routes through `_commit_at_interaction_cell` only (no drop-time waypoint injection, no direct `_commit_at_cell`).
