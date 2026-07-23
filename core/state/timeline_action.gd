class_name TimelineAction
extends RefCounted

## Purpose: One ordered entry in a plan: either a move or an ability use.
## The SAME type is used for player timeline entries and locked enemy intents,
## so both flow through the identical resolution pipeline.
## Responsibilities: Describe one action's actor, kind, and target; clone itself.
## Dependencies: AbilityData (shared), GameEnums.
## Lifecycle: created during planning; cloned with the timeline; immutable once executed.

var actor_id: int = -1
var type: GameEnums.ActionType = GameEnums.ActionType.MOVE
## MOVE/FACE only: resolve before or after the unit's ability this turn.
var move_timing: GameEnums.MoveTiming = GameEnums.MoveTiming.PRE_ACTION

## MOVE: destination tile.
## ABILITY: target tile (used when target_unit_id is -1).
var target_coord: Vector2i = Vector2i.ZERO

## ABILITY only.
var ability: AbilityData
## Optional explicit target unit. -1 means resolve by target_coord at run time.
var target_unit_id: int = -1

## Desired final facing (GameEnums.Facing). -1 = derive from movement direction.
## Used by MOVE (override facing after moving) and FACE (turn in place).
var face_dir: int = -1

## MOVE only: explicit route the unit should walk (tiles to ENTER, excluding the
## start). Empty = let MovementSystem pathfind. Lets the player trace a detour.
var waypoints: Array[Vector2i] = []

## True when this action caused forced enemy movement or damage during planning
## (e.g. trample push) and cannot be undone.
var irreversible: bool = false

## MOVE only: apply universal Run boost immediately before this step resolves.
var uses_run: bool = false

## ABILITY only: armed for targeting (dash etc.) — shown in plan UI, not simulated until finalized.
var awaiting_target: bool = false


func is_simulatable() -> bool:
	return not awaiting_target


func is_run_boosted_pre_move() -> bool:
	return (
		type == GameEnums.ActionType.MOVE
		and uses_run
		and move_timing == GameEnums.MoveTiming.PRE_ACTION
	)

static func make_move(
	p_actor_id: int,
	p_target_coord: Vector2i,
	p_face_dir: int = -1,
	p_waypoints: Array[Vector2i] = [],
	p_move_timing: GameEnums.MoveTiming = GameEnums.MoveTiming.PRE_ACTION,
) -> TimelineAction:
	var action := TimelineAction.new()
	action.actor_id = p_actor_id
	action.type = GameEnums.ActionType.MOVE
	action.move_timing = p_move_timing
	action.target_coord = p_target_coord
	action.face_dir = p_face_dir
	action.waypoints = p_waypoints
	return action


static func make_run_move(
	p_actor_id: int,
	p_target_coord: Vector2i,
	p_face_dir: int = -1,
	p_waypoints: Array[Vector2i] = [],
	p_move_timing: GameEnums.MoveTiming = GameEnums.MoveTiming.PRE_ACTION,
) -> TimelineAction:
	var action := make_move(p_actor_id, p_target_coord, p_face_dir, p_waypoints, p_move_timing)
	action.uses_run = true
	return action

## Turn in place without moving (the destination is the unit's own tile).
static func make_face(
	p_actor_id: int,
	p_face_dir: int,
	p_move_timing: GameEnums.MoveTiming = GameEnums.MoveTiming.PRE_ACTION,
) -> TimelineAction:
	var action := TimelineAction.new()
	action.actor_id = p_actor_id
	action.type = GameEnums.ActionType.FACE
	action.move_timing = p_move_timing
	action.face_dir = p_face_dir
	return action

static func make_ability_awaiting(
	p_actor_id: int,
	p_ability: AbilityData,
	p_origin: Vector2i,
	p_waypoints: Array[Vector2i] = [],
) -> TimelineAction:
	var action := make_ability(p_actor_id, p_ability, p_origin, -1, GameEnums.MoveTiming.PRE_ACTION, p_waypoints)
	action.awaiting_target = true
	return action


static func make_ability(
	p_actor_id: int,
	p_ability: AbilityData,
	p_target_coord: Vector2i,
	p_target_unit_id: int = -1,
	p_move_timing: GameEnums.MoveTiming = GameEnums.MoveTiming.PRE_ACTION,
	p_waypoints: Array[Vector2i] = [],
) -> TimelineAction:
	var action := TimelineAction.new()
	action.actor_id = p_actor_id
	action.type = GameEnums.ActionType.ABILITY
	action.move_timing = p_move_timing
	action.ability = p_ability
	action.target_coord = p_target_coord
	action.target_unit_id = p_target_unit_id
	action.waypoints = p_waypoints
	return action

func clone() -> TimelineAction:
	var copy := TimelineAction.new()
	copy.actor_id = actor_id
	copy.type = type
	copy.move_timing = move_timing
	copy.target_coord = target_coord
	copy.ability = ability  # shared immutable definition
	copy.target_unit_id = target_unit_id
	copy.face_dir = face_dir
	copy.waypoints = waypoints.duplicate()
	copy.irreversible = irreversible
	copy.uses_run = uses_run
	copy.awaiting_target = awaiting_target
	return copy
