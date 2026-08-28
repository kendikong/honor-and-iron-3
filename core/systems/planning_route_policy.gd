class_name PlanningRoutePolicy
extends RefCounted

## Shared geometry for enemy-hover vs painted-corridor policy (presentation commit probe stays in CombatPlanningInput).


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
