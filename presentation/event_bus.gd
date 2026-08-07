extends Node

## Purpose: Global signal hub for the presentation layer. Managers and the view
## communicate ONLY through these signals (constitution: "signals up, never down";
## CombatManager should not know which systems listen). The simulation never
## touches this; it is pure and headless.
## Responsibilities: Declare cross-layer signals. No state, no logic.
## Dependencies: SimResult, SimEvent, BoardState, Timeline (types only).
## Lifecycle: registered as the `EventBus` autoload; lives for the whole app.

# These signals are emitted/consumed from other scripts, which the per-file checker
# can't see; silence the false "unused signal" warnings.
@warning_ignore_start("unused_signal")

## The turn state machine changed phase. Payload: GameEnums-like CombatDirector.Phase.
signal turn_phase_changed(phase: int)

## The real board was adopted/replaced (start of turn, or after execute).
signal board_changed(board: BoardState)

## A fresh ghost preview is available. final_state is read for ghosts, then discarded.
signal preview_updated(result: SimResult)

## The player's planned timeline was edited. `statuses` is parallel to the
## timeline entries: "" means the action is valid, otherwise a failure reason code.
signal timeline_changed(timeline: Timeline, statuses: PackedStringArray)

## The currently selected player unit changed (-1 == none).
signal selection_changed(unit_id: int)

## The active ability slot for the selected unit changed (index into its abilities).
signal ability_selected(index: int)

## One ordered simulation event, emitted during execution for animation/SFX.
signal sim_event(event: SimEvent)

## An attempted plan edit was rejected before being added (e.g. illegal move).
## Payload is a short reason code; the view shows a single transient warning.
signal action_rejected(reason: String)

## Emitted when the Autobattler finishes scoring a Team Vector, containing deep telemetry.
signal ai_telemetry_generated(telemetry: Dictionary)

## Phase-1 immediate move/face status changed (view refreshes undo + route markers).
signal phase1_status_changed()

## A planning-phase move with side effects (trample push/damage) was committed;
## the view should animate move then forced displacement before snapping visuals.
signal planning_commit_events(events: Array)

## Emitted by the tactical presentation once all push/displacement tweens from
## a batch have finished.
signal push_animations_complete

## Interface sliders (UI/text scale, panel width) saved live â€” combat hosts reload + apply.
signal interface_settings_changed()

@warning_ignore_restore("unused_signal")
