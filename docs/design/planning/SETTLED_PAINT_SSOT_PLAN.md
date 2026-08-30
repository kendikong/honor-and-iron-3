# Settled Paint SSOT (range + blast)

**Status:** IMPLEMENTED (structural gates + settle seal)

## Model

Same pattern as hover preview carried SSOT:

1. **Settle** — `CombatPlanningInput._store_intent_snapshot` seals `PlanningSettledPaint` alongside hover slots.
2. **Display** — `TacticalPlanningOverlay` reads sealed `stand_origin`, `action_range_tiles`, `blast_tiles` when hover matches bundle (no recompute).
3. **Ratify** — commit still uses sealed hover slots only; paint bundle is display truth for red/yellow tiles.

## Gates

- `scripts/qa/run_action_range_ssot_gate.ps1` — latest-stand paint bundle + no `base_board` in range helpers
- `scripts/qa/run_footprint_ssot_gate.ps1` — blast tiles sealed via `AbilitySystem.planning_blast_tiles_at_target`
- `scripts/qa/run_planning_ssot_gates.ps1` — runs all structural SSOT gates

## Drag = hover

`_process_unit_drop` routes through `_commit_at_interaction_cell` only (no drop-time waypoint injection, no direct `_commit_at_cell`).
