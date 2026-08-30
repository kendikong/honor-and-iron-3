# Settled Paint SSOT (range + blast)

**Status:** IMPLEMENTED (structural gates + settle seal)

## Model

Same pattern as hover preview carried SSOT:

1. **Settle** — `PlanningPreviewTiles.resolve_paint` computes range, blast, and stand data beside the slots; `CombatPlanningInput._store_intent_snapshot` seals both in `PlanningHoverPreview`.
2. **Display** — `TacticalPlanningOverlay` reads the sealed hover bundle only when its unit, cell, revision, and ability match (no paint recompute).
3. **Ratify** — commit copies the sealed hover slots; the same bundle remains the display truth for red/yellow tiles.

## Gates

- `scripts/qa/run_action_range_ssot_gate.ps1` — hover-bundle paint ownership + no `base_board` in range helpers
- `scripts/qa/run_footprint_ssot_gate.ps1` — blast tiles owned by `PlanningPreviewTiles` and carried by the hover bundle
- `scripts/qa/run_planning_ssot_gates.ps1` — runs all structural SSOT gates

## Drag = hover

`_process_unit_drop` routes through `_commit_at_interaction_cell` only (no drop-time waypoint injection, no direct `_commit_at_cell`).
