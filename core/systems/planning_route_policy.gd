class_name PlanningRoutePolicy
extends RefCounted

## Sealed-leg hover + voluntary-walk corridor policy (presentation commit probe stays in CombatPlanningInput).

enum SealedLegHoverMode {
	NONE = 0,
	RESTORE_ONLY = 1,
	FREEZE_LANDING = 2,
	EXTEND_CORRIDOR = 3,
}


## Sealed painted leg + hover intent — no ability id, skill names, or timeline slot labels.
## voluntary_walk_corridor_paint: movement-step voluntary-walk corridor paint is active.
## is_hover_move_tile: hover extends walk geometry (premove blue, MOVE-module dest, postmove orbit).
## is_hover_attack_target: enemy under cursor — restore sealed route, do not corridor-extend.
static func sealed_leg_hover_mode(
	is_painted_leg_sealed: bool,
	sealed_route_len: int,
	voluntary_walk_corridor_paint: bool,
	is_hover_move_tile: bool,
	is_hover_attack_target: bool,
) -> int:
	if not is_painted_leg_sealed or sealed_route_len < 2:
		return SealedLegHoverMode.NONE
	if not voluntary_walk_corridor_paint:
		return SealedLegHoverMode.FREEZE_LANDING
	if is_hover_move_tile:
		return SealedLegHoverMode.EXTEND_CORRIDOR
	if is_hover_attack_target:
		return SealedLegHoverMode.RESTORE_ONLY
	return SealedLegHoverMode.RESTORE_ONLY


static func hover_rewrite_allowed(mode: int) -> bool:
	return mode == SealedLegHoverMode.EXTEND_CORRIDOR


static func should_restore_locked_route(mode: int) -> bool:
	return (
		mode == SealedLegHoverMode.FREEZE_LANDING
		or mode == SealedLegHoverMode.RESTORE_ONLY
	)


## Sealed-leg orbit extension uses basic-walk corridor legality, not armed MOVE-endpoint probes.
static func use_basic_walk_corridor_legality(mode: int) -> bool:
	return mode == SealedLegHoverMode.EXTEND_CORRIDOR


## Awaiting direct-relocation hop is allowed only when policy is not corridor-extend.
static func allows_awaiting_relocation_hop(mode: int) -> bool:
	return mode != SealedLegHoverMode.EXTEND_CORRIDOR


static func enemy_hover_respects_painted_corridor(
	actor: UnitState,
	enemy: UnitState,
	ability: AbilityData,
	route_waypoints: Array[Vector2i],
	move_origin: Vector2i,
	in_range_from_live_stand: bool,
	stand_in_range: bool,
	approach_tile: Vector2i,
	dragging: bool,
	can_pair_run: bool,
) -> bool:
	if actor == null or enemy == null or route_waypoints.is_empty() or ability == null:
		return false
	var stand: Vector2i = route_waypoints.back()
	if stand == move_origin:
		return false
	var ability_range: int = AbilitySystem.active_range_tiles(actor, ability)
	# Range 2+: respect deliberate premove only when out of range from the live stand.
	# In-range enemy hover is always a stationary shot — painted corridors are ignored.
	if ability_range > 1:
		if in_range_from_live_stand:
			return false
		if not stand_in_range:
			return false
	if not can_pair_run:
		return false
	if not in_range_from_live_stand:
		if not stand_in_range:
			if approach_tile.x > -900000 and stand != approach_tile:
				return false
		elif route_waypoints.size() <= 1 and approach_tile.x > -900000 and stand != approach_tile:
			return false
	if in_range_from_live_stand:
		if not dragging and route_waypoints.size() <= 1 and GridSystem.manhattan(move_origin, stand) <= 1:
			return false
	return true
