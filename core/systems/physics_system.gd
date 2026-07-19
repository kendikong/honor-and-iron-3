class_name PhysicsSystem
extends RefCounted

## Purpose: Owns forced displacement (shove/push), collision, and the resulting
## collision damage delegation.
## Responsibilities: Move a unit tile-by-tile in a direction until blocked; on
##   hitting a wall/edge or another unit, stop and request collision damage from
##   CombatSystem (the owner of damage). Also performs position swaps. Hazard
##   landings are delegated to TerrainSystem.
## Dependencies: BoardState, UnitState, GridSystem, CombatSystem, TerrainSystem,
##   SimEvent.
## Lifecycle: stateless; only static functions.

## Cardinal direction from one tile toward another (dominant axis wins; ties
## resolve to the horizontal axis for determinism).
static func cardinal_from_to(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta := to - from
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(delta.x) >= absi(delta.y):
		return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))

## Unit-direction helpers (this system owns directional math; GameEnums stays
## pure data). Facing maps to the same cardinal vectors used everywhere else.
static func facing_to_vector(facing: GameEnums.Facing) -> Vector2i:
	match facing:
		GameEnums.Facing.NORTH:
			return Vector2i(0, -1)
		GameEnums.Facing.EAST:
			return Vector2i(1, 0)
		GameEnums.Facing.SOUTH:
			return Vector2i(0, 1)
		GameEnums.Facing.WEST:
			return Vector2i(-1, 0)
	return Vector2i(0, 1)

static func facing_from_vector(v: Vector2i) -> GameEnums.Facing:
	if absi(v.x) >= absi(v.y):
		if v.x > 0:
			return GameEnums.Facing.EAST
		if v.x < 0:
			return GameEnums.Facing.WEST
	if v.y < 0:
		return GameEnums.Facing.NORTH
	return GameEnums.Facing.SOUTH

## Counter-clockwise 90° from a cardinal dash direction (left of forward).
static func left_of_direction(direction: Vector2i) -> Vector2i:
	return Vector2i(-direction.y, direction.x)

## Unit step along a straight cardinal or diagonal line from `from` toward `to`.
## Returns Vector2i.ZERO when the target is not on a valid 8-way line.
static func straight_line_dir(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta := to - from
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if delta.x == 0:
		return Vector2i(0, signi(delta.y))
	if delta.y == 0:
		return Vector2i(signi(delta.x), 0)
	if absi(delta.x) == absi(delta.y):
		return Vector2i(signi(delta.x), signi(delta.y))
	return Vector2i.ZERO

## Tile count along a straight cardinal or diagonal line.
static func straight_line_distance(from: Vector2i, to: Vector2i) -> int:
	var delta := to - from
	if delta == Vector2i.ZERO:
		return 0
	if delta.x == 0:
		return absi(delta.y)
	if delta.y == 0:
		return absi(delta.x)
	if absi(delta.x) == absi(delta.y):
		return absi(delta.x)
	return 0

## True when the dasher will not take another step after entering `tile`.
static func _dash_ends_on_tile(board: BoardState, tile: Vector2i, direction: Vector2i, step_index: int, total_steps: int) -> bool:
	if step_index >= total_steps - 1:
		return true
	if GridSystem.is_hazard(board, tile):
		return true
	var beyond := tile + direction
	if GridSystem.stops_displacement(board, beyond) or not GridSystem.is_in_bounds(board, beyond):
		return true
	var blocker := board.get_unit_at(beyond)
	if blocker != null and _cannot_be_displaced(blocker):
		return true
	return false

static func _cannot_be_displaced(unit: UnitState) -> bool:
	if unit == null:
		return true
	var is_vulnerable := unit.has_status(GameEnums.StatusType.VULNERABLE)
	var has_stand_ground := unit.has_passive(&"stand_ground")
	return unit.has_status(GameEnums.StatusType.INVULNERABLE) or (
		not is_vulnerable and (
			unit.has_status(GameEnums.StatusType.ROOT)
			or unit.has_status(GameEnums.StatusType.STURDY)
			or has_stand_ground
		)
	)

## Bulldoze contact: collision damage (optional base bonus) on the victim, then PUSH.
static func apply_trample_contact(
	board: BoardState,
	mover: UnitState,
	victim: UnitState,
	coord: Vector2i,
	push_dir: Vector2i,
	push_distance: int,
	events: Array[SimEvent],
	ability_id: StringName = &"",
	collision_base_bonus: int = 0,
) -> void:
	if mover == null or victim == null or not victim.is_alive() or push_distance <= 0:
		return
	var immune_id := mover.id
	_emit_collision(
		board, victim, mover, coord, push_distance, 0, events, mover, ability_id, immune_id, collision_base_bonus
	)
	if push_dir != Vector2i.ZERO:
		push(board, victim, push_dir, push_distance, events, mover, ability_id, immune_id)

## Straight-line movement. TRAMPLE X: pass through enemies, flat ATK X, no push, restore
## enemies after the dasher leaves their tile. BULLDOZE X: pass through with collision
## base X + PUSH X (sideways while passing, axial when stopping on the victim).
static func dash(
	board: BoardState,
	unit: UnitState,
	direction: Vector2i,
	distance: int,
	events: Array[SimEvent],
	pusher: UnitState = null,
	ability_id: StringName = &"",
	trample_atk: int = 0,
	source_label: String = "",
	bulldoze: int = 0,
	caster_collision_immune: bool = false,
) -> void:
	if unit == null or not unit.is_alive() or direction == Vector2i.ZERO or distance <= 0:
		return
	
	var from := unit.position
	var traveled := 0
	var knight_on_board := true
	var use_bulldoze := bulldoze > 0
	var use_trample_atk := trample_atk > 0 and not use_bulldoze
	var immune_id := unit.id if caster_collision_immune else -1
	var path: Array[Vector2i] = []
	var trample_hit_ids: Dictionary = {}
	var trampled_restore: Dictionary = {}

	for step_i in range(distance):
		var next := unit.position + direction

		if GridSystem.stops_displacement(board, next) or not GridSystem.is_in_bounds(board, next):
			if not use_trample_atk and not use_bulldoze:
				_emit_collision(board, unit, null, next, distance, traveled, events, pusher, ability_id)
			break

		var occupant := board.get_unit_at(next)
		if occupant != null and _cannot_be_displaced(occupant):
			if not use_trample_atk and not use_bulldoze:
				_emit_collision(board, unit, occupant, next, distance, traveled, events, pusher, ability_id)
			break

		if use_bulldoze:
			if occupant != null and occupant.team != unit.team and not trample_hit_ids.has(occupant.id):
				trample_hit_ids[occupant.id] = true
				var hit_ev_start := events.size()
				var is_final_step := step_i == distance - 1
				var push_dir := direction if is_final_step else left_of_direction(direction)
				apply_trample_contact(
					board, unit, occupant, next, push_dir, bulldoze, events, ability_id, bulldoze
				)
				for ev_i in range(hit_ev_start, events.size()):
					var hit_ev: SimEvent = events[ev_i]
					if hit_ev.type in [
						GameEnums.SimEventType.COLLISION,
						GameEnums.SimEventType.MATH_TELEMETRY,
						GameEnums.SimEventType.UNIT_DAMAGED,
					]:
						hit_ev.data["dash_hit_step"] = traveled
				occupant = board.get_unit_at(next)
				if occupant != null and occupant.id != unit.id:
					break
		elif use_trample_atk:
			if occupant != null and occupant.team != unit.team and not trample_hit_ids.has(occupant.id):
				trample_hit_ids[occupant.id] = true
				var label := source_label if source_label != "" else "Trample"
				var ev_before := events.size()
				var scaled_atk := CombatSystem.calculate_scaled_damage(
					unit, trample_atk, GameEnums.StatType.PHYSICAL, board
				)
				CombatSystem.deal_damage_raw(
					board, unit, occupant, scaled_atk, GameEnums.StatType.PHYSICAL, events, label, trample_atk
				)
				for ev_i in range(ev_before, events.size()):
					if events[ev_i].type == GameEnums.SimEventType.UNIT_DAMAGED:
						events[ev_i].data["dash_hit_step"] = traveled
						break
				trampled_restore[next] = occupant.id
				GridSystem.set_occupant(board, next, -1)
			elif occupant != null and occupant.id != unit.id:
				break
		elif occupant != null:
			_emit_collision(board, unit, occupant, next, distance, traveled, events, pusher, ability_id)
			break

		if trampled_restore.has(unit.position):
			var restore_id: int = int(trampled_restore[unit.position])
			trampled_restore.erase(unit.position)
			GridSystem.set_occupant(board, unit.position, restore_id)

		var prev := unit.position
		if knight_on_board:
			GridSystem.set_occupant(board, prev, -1)
		unit.position = next
		traveled += 1
		path.append(next)

		var at_next := board.get_unit_at(next)
		if at_next == null:
			GridSystem.set_occupant(board, next, unit.id)
			knight_on_board = true
		elif at_next.team == unit.team:
			knight_on_board = false
		elif board.get_unit_at(next) == null:
			GridSystem.set_occupant(board, next, unit.id)
			knight_on_board = true
		else:
			knight_on_board = false

		if GridSystem.is_hazard(board, next):
			break

	for restore_coord: Vector2i in trampled_restore.keys():
		var restore_unit_id: int = int(trampled_restore[restore_coord])
		if board.get_unit_at(restore_coord) == null:
			GridSystem.set_occupant(board, restore_coord, restore_unit_id)
	
	if traveled == 0:
		if knight_on_board:
			GridSystem.set_occupant(board, from, unit.id)
		unit.position = from
		return
	
	if not knight_on_board and board.get_unit_at(unit.position) == null:
		GridSystem.set_occupant(board, unit.position, unit.id)
	elif not use_trample_atk and not use_bulldoze:
		var tile_occupant := board.get_unit_at(unit.position)
		if tile_occupant != null and tile_occupant.id != unit.id:
			if tile_occupant.team != unit.team:
				_emit_collision(board, unit, tile_occupant, unit.position, distance, traveled, events, pusher, ability_id)
			GridSystem.set_occupant(board, unit.position, tile_occupant.id)
		else:
			GridSystem.set_occupant(board, unit.position, unit.id)
	elif board.get_unit_at(unit.position) == null:
		GridSystem.set_occupant(board, unit.position, unit.id)
	
	for status in unit.active_statuses:
		if status.type == GameEnums.StatusType.BLEED:
			CombatSystem.deal_damage(board, unit, 3 * traveled, events, &"bleed", false, false, null, "Bleed (dash)", 3 * traveled)
	
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
		"actor": unit.id,
		"from": from,
		"to": unit.position,
		"steps": traveled,
		"path": path,
		"is_dash": true,
	}))
	TerrainSystem.apply_landing(board, unit, events)

static func push(board: BoardState, target: UnitState, direction: Vector2i, distance: int, events: Array[SimEvent], pusher: UnitState = null, ability_id: StringName = &"", collision_immune_id: int = -1) -> void:
	if target == null or not target.is_alive() or direction == Vector2i.ZERO or distance <= 0:
		return
		
	var is_vulnerable = target.has_status(GameEnums.StatusType.VULNERABLE)
	var has_stand_ground = target.has_passive(&"stand_ground")
	
	if target.has_status(GameEnums.StatusType.INVULNERABLE) or (not is_vulnerable and (target.has_status(GameEnums.StatusType.ROOT) or target.has_status(GameEnums.StatusType.STURDY) or has_stand_ground)):
		events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
			"actor": target.id, "reason": "push_prevented_by_status",
		}))
		if has_stand_ground and pusher != null and pusher.team != target.team:
			var atk_val := 2 if target.is_passive_upgraded(&"stand_ground") else 1
			CombatSystem.counter_attack(board, target, pusher, atk_val, events, "Stand Ground")
			events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
				"actor": pusher.id, "reason": "blocked_by_stand_ground", "target": target.id
			}))
		return

	var from := target.position
	var traveled := 0
	for _i in range(distance):
		var next := target.position + direction

		# Wall or board edge: stop and take collision damage.
		if GridSystem.stops_displacement(board, next) or not GridSystem.is_in_bounds(board, next):
			_emit_collision(board, target, null, next, distance, traveled, events, pusher, ability_id, collision_immune_id)
			break

		# Another unit: both take collision damage; neither moves further.
		var blocker := board.get_unit_at(next)
		if blocker != null:
			_emit_collision(board, target, blocker, next, distance, traveled, events, pusher, ability_id, collision_immune_id)
			break

		# Clear tile: advance one step.
		GridSystem.set_occupant(board, target.position, -1)
		target.position = next
		GridSystem.set_occupant(board, target.position, target.id)
		traveled += 1

		# A hazard tile catches displaced units: stop here so the shove "lands"
		# in the pit instead of sliding past it.
		if GridSystem.is_hazard(board, target.position):
			break

	if traveled > 0:
		for status in target.active_statuses:
			if status.type == GameEnums.StatusType.BLEED:
				CombatSystem.deal_damage(board, target, 3 * traveled, events, &"bleed", false, false, null, "Bleed (push)", 3 * traveled)
				
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_PUSHED, {
			"unit": target.id,
			"from": from,
			"to": target.position,
			"distance": traveled,
		}))
		# Terrain stage: resolve any hazard on the tile we ended up on.
		TerrainSystem.apply_landing(board, target, events)

static func _emit_collision(
	board: BoardState,
	target: UnitState,
	blocker: UnitState,
	coord: Vector2i,
	push_distance: int,
	tiles_moved: int,
	events: Array[SimEvent],
	pusher: UnitState,
	ability_id: StringName,
	collision_immune_id: int = -1,
	collision_base_bonus: int = 0,
) -> void:
	assert(pusher != null, "Collision requires an instigating pusher")
	var excess := maxi(0, push_distance - tiles_moved)
	var against: Variant = "wall"
	var against_unit := -1
	if blocker != null:
		against = blocker.id
		against_unit = blocker.id
	events.append(SimEvent.make(GameEnums.SimEventType.COLLISION, {
		"unit": target.id,
		"against": against,
		"against_unit": against_unit,
		"coord": coord,
		"push_distance": push_distance,
		"tiles_moved": tiles_moved,
		"excess_push": excess,
		"pusher_id": pusher.id,
	}))
	if pusher != null and pusher != target:
		var stun_on_hit := pusher.has_passive(&"spiked_barricade")
		if blocker == null:
			stun_on_hit = stun_on_hit or (ability_id == &"knight_shield_bash" and pusher.is_ability_upgraded(&"knight_shield_bash"))
		elif ability_id == &"knight_shield_bash" and pusher.is_ability_upgraded(&"knight_shield_bash"):
			stun_on_hit = true
		if stun_on_hit:
			target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STUN, 1))
		if pusher.has_passive(&"spiked_barricade") and pusher.is_passive_upgraded(&"spiked_barricade"):
			target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, -1))
	if blocker != null:
		if blocker.has_passive(&"collision_retaliator") and blocker.team != target.team:
			if target.id != collision_immune_id:
				CombatSystem.deal_collision_damage(
					board, pusher, target, push_distance, tiles_moved, events,
					CombatSystem.COLLISION_RETALIATOR_BASE_BONUS,
				)
			if blocker.is_passive_upgraded(&"collision_retaliator"):
				var push_dir := cardinal_from_to(blocker.position, target.position)
				push(board, target, push_dir, 1, events, blocker, ability_id, collision_immune_id)
		else:
			if target.id != collision_immune_id:
				CombatSystem.deal_collision_damage(
					board, pusher, target, push_distance, tiles_moved, events, collision_base_bonus
				)
			if blocker.id != collision_immune_id:
				CombatSystem.deal_collision_damage(
					board, pusher, blocker, tiles_moved, tiles_moved, events, collision_base_bonus
				)
	else:
		if target.id != collision_immune_id:
			CombatSystem.deal_collision_damage(
				board, pusher, target, push_distance, tiles_moved, events, collision_base_bonus
			)

## Swap two units' positions. Used by the SWAP effect; deals no collision damage.
## Both ends trigger terrain landings (you can swap a unit onto a hazard).
static func swap(board: BoardState, a: UnitState, b: UnitState, events: Array[SimEvent]) -> void:
	if a == null or b == null or not a.is_alive() or not b.is_alive() or a.id == b.id:
		return
	var pa := a.position
	var pb := b.position
	GridSystem.set_occupant(board, pa, -1)
	GridSystem.set_occupant(board, pb, -1)
	a.position = pb
	b.position = pa
	GridSystem.set_occupant(board, a.position, a.id)
	GridSystem.set_occupant(board, b.position, b.id)
	
	var dist := GridSystem.manhattan(pa, pb)
	for status in a.active_statuses:
		if status.type == GameEnums.StatusType.BLEED:
			CombatSystem.deal_damage(board, a, 3 * dist, events, &"bleed", false, false, null, "Bleed (swap)", 3 * dist)
	for status in b.active_statuses:
		if status.type == GameEnums.StatusType.BLEED:
			CombatSystem.deal_damage(board, b, 3 * dist, events, &"bleed", false, false, null, "Bleed (swap)", 3 * dist)
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_PUSHED, {
		"unit": a.id, "from": pa, "to": a.position, "distance": GridSystem.manhattan(pa, pb),
	}))
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_PUSHED, {
		"unit": b.id, "from": pb, "to": b.position, "distance": GridSystem.manhattan(pa, pb),
	}))
	TerrainSystem.apply_landing(board, a, events)
	TerrainSystem.apply_landing(board, b, events)
