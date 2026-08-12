# ==============================================================================
# 🛑 WARNING TO AI AGENTS (HONOR & IRON ARCHITECTURE STRICT RULES) 🛑
# ==============================================================================
# DO NOT BRANCH ON `ability.id` IN THIS FILE. EVER.
# 
# Abilities are DATA, not engine code modifications. You are strictly forbidden
# from writing things like `if ability_id == "knight_shield_bash"` to
# inject mechanics. If an ability needs custom behavior (STAGGER on collision, 
# chain pushes, etc), you MUST add a new generic flag to `GameEnums.EffectType`
# or `GameEnums.StatusType`, assign it in the factory, and check for THAT flag.
# 
# VIOLATING THIS RULE WILL CAUSE THE AUTOMATED ARCHITECTURE TEST TO FAIL.
# ==============================================================================
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

## Shared pass-through contact for dash steps and path walks.
## Returns false when the mover must stop before entering `tile`.
static func resolve_pass_through_tile(
	board: BoardState,
	mover: UnitState,
	tile: Vector2i,
	move_dir: Vector2i,
	exit_dir: Vector2i,
	is_final_step: bool,
	trample_atk: int,
	bulldoze: int,
	trample_push: int,
	events: Array[SimEvent],
	ability_id: StringName,
	trample_hit_ids: Dictionary,
	trampled_restore: Dictionary,
	source_label: String = "",
) -> bool:
	var occupant := board.get_unit_at(tile)
	if occupant == null:
		return true
	if occupant.id == mover.id:
		return true
	if occupant.team == mover.team:
		return false
	if trample_hit_ids.has(occupant.id):
		return true
	if mover.has_status(GameEnums.StatusType.GHOST):
		if occupant != null and occupant.team != mover.team:
			if not is_final_step:
				trampled_restore[tile] = occupant.id
				GridSystem.set_occupant(board, tile, -1)
			return true
		return true
	if bulldoze > 0:
		trample_hit_ids[occupant.id] = true
		var push_dir := move_dir
		if not is_final_step and move_dir == exit_dir:
			push_dir = left_of_direction(move_dir)
		apply_trample_contact(board, mover, occupant, tile, push_dir, bulldoze, events, ability_id, bulldoze)
		occupant = board.get_unit_at(tile)
		return occupant == null or occupant.id == mover.id
	if trample_atk > 0:
		trample_hit_ids[occupant.id] = true
		var passed_count: int = int(mover.passive_flags.get("line_breaker_passed", 0))
		var pass_bonus := 0
		var source_ability := mover.get_ability_by_id(ability_id)
		if source_ability != null:
			pass_bonus = _ability_modifier_value(
				mover,
				source_ability,
				&"bonus_per_enemy_passed",
			)
		trample_atk += pass_bonus * (passed_count + 1)
		if pass_bonus > 0:
			mover.passive_flags["line_breaker_passed"] = passed_count + 1
		var label := source_label if source_label != "" else "Trample"
		var scaled_atk := CombatSystem.calculate_scaled_damage(
			mover, trample_atk, GameEnums.StatType.PHYSICAL, board
		)
		CombatSystem.deal_damage_raw(
			board, mover, occupant, scaled_atk, GameEnums.StatType.PHYSICAL, events, label, trample_atk
		)
		if trample_push > 0:
			var push_dir := move_dir
			if not is_final_step and move_dir == exit_dir:
				push_dir = left_of_direction(move_dir)
			push(board, occupant, push_dir, trample_push, events, mover, ability_id, mover.id)
			occupant = board.get_unit_at(tile)
			if occupant != null and occupant.id != mover.id:
				if is_final_step:
					return false
				trampled_restore[tile] = occupant.id
				GridSystem.set_occupant(board, tile, -1)
		else:
			if is_final_step:
				return false
			trampled_restore[tile] = occupant.id
			GridSystem.set_occupant(board, tile, -1)
		return true
	return false

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
	trample_push: int = 0,
) -> void:
	if unit == null or not unit.is_alive() or direction == Vector2i.ZERO or distance <= 0:
		return
	
	var from := unit.position
	var traveled := 0
	var unit_on_board := true
	var use_bulldoze := bulldoze > 0
	var use_trample_atk := trample_atk > 0 and not use_bulldoze
	var immune_id := unit.id if caster_collision_immune else -1
	var path: Array[Vector2i] = []
	var trample_hit_ids: Dictionary = {}
	var trampled_restore: Dictionary = {}
	var source_ability: AbilityData = null
	if pusher != null and ability_id != &"":
		source_ability = pusher.get_ability_by_id(ability_id)
	var create_trampled: bool = false
	var line_breaker: bool = false
	if source_ability != null:
		create_trampled = AbilitySystem.ability_has_modifier(
			source_ability,
			&"create_trampled_terrain",
			pusher,
		)
		line_breaker = AbilitySystem.ability_has_modifier(
			source_ability,
			&"line_breaker",
			pusher,
		)

	for step_i in range(distance):
		var step_emit_start: int = events.size()
		var next := unit.position + direction

		if GridSystem.stops_displacement(board, next) or not GridSystem.is_in_bounds(board, next):
			if not use_trample_atk and not use_bulldoze:
				_emit_collision(board, unit, null, next, distance, traveled, events, pusher, ability_id)
			tag_dash_hit_step(events, step_emit_start, step_i)
			break

		var occupant := board.get_unit_at(next)
		if occupant != null and _cannot_be_displaced(occupant) and not line_breaker:
			if not use_trample_atk and not use_bulldoze:
				_emit_collision(board, unit, occupant, next, distance, traveled, events, pusher, ability_id)
			tag_dash_hit_step(events, step_emit_start, step_i)
			break

		if use_bulldoze or use_trample_atk:
			if occupant != null and occupant.team != unit.team:
				var is_final_step := step_i == distance - 1
				if not resolve_pass_through_tile(
					board, unit, next, direction, direction, is_final_step,
					trample_atk if use_trample_atk else 0,
					bulldoze if use_bulldoze else 0,
					trample_push if use_trample_atk else 0,
					events, ability_id, trample_hit_ids, trampled_restore, source_label
				):
					tag_dash_hit_step(events, step_emit_start, step_i)
					break
				occupant = board.get_unit_at(next)
				if occupant != null and occupant.id != unit.id:
					tag_dash_hit_step(events, step_emit_start, step_i)
					break
		elif occupant != null:
			_emit_collision(board, unit, occupant, next, distance, traveled, events, pusher, ability_id)
			tag_dash_hit_step(events, step_emit_start, step_i)
			break

		if trampled_restore.has(unit.position):
			var restore_id: int = int(trampled_restore[unit.position])
			trampled_restore.erase(unit.position)
			GridSystem.set_occupant(board, unit.position, restore_id)

		var prev := unit.position
		if unit_on_board:
			GridSystem.set_occupant(board, prev, -1)
		unit.position = next
		traveled += 1
		path.append(next)
		if create_trampled:
			var trampled := DataLibrary.get_terrain(&"trampled")
			if trampled != null:
				board.set_tile_terrain(prev, trampled)
				events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
					"coord": prev,
					"terrain": &"trampled",
				}))

		var at_next := board.get_unit_at(next)
		var dash_tile := board.get_tile(next)
		if dash_tile != null and dash_tile.definition != null \
				and dash_tile.definition.id != &"plain":
			unit.passive_flags["passed_through_terrain"] = true
		if at_next == null:
			GridSystem.set_occupant(board, next, unit.id)
			unit_on_board = true
		elif at_next.team == unit.team:
			unit_on_board = false
		elif board.get_unit_at(next) == null:
			GridSystem.set_occupant(board, next, unit.id)
			unit_on_board = true
		else:
			unit_on_board = false

		tag_dash_hit_step(events, step_emit_start, step_i)
		if GridSystem.is_hazard(board, next):
			break

	# Rubber-band backwards if we halted on a trampled tile.
	while trampled_restore.has(unit.position):
		var back_step := unit.position - direction
		path.append(back_step)
		unit.position = back_step

	for restore_coord: Vector2i in trampled_restore.keys():
		var restore_unit_id: int = int(trampled_restore[restore_coord])
		if board.get_unit_at(restore_coord) == null:
			GridSystem.set_occupant(board, restore_coord, restore_unit_id)
	
	if traveled == 0:
		if unit_on_board:
			GridSystem.set_occupant(board, from, unit.id)
		unit.position = from
		return
	
	if not unit_on_board and board.get_unit_at(unit.position) == null:
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
	unit.record_movement(path, 0, from)
	
	var anim: int = GameEnums.PresentationAnim.SUPER_RUN
	if ability_id != &"":
		var source_unit := pusher if pusher != null else unit
		var ability: AbilityData = source_unit.get_ability_by_id(ability_id) if source_unit != null else null
		if ability != null and ability.presentation_anim != GameEnums.PresentationAnim.AUTO:
			anim = ability.presentation_anim
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
		"actor": unit.id,
		"from": from,
		"to": unit.position,
		"steps": traveled,
		"path": path,
		"presentation_anim": anim,
	}))
	TerrainSystem.apply_landing(board, unit, events)


## Tags pass-through / bulldoze side effects so presentation can interleave per dash step.
static func tag_dash_hit_step(events: Array, from_index: int, step_index: int) -> void:
	for tag_i: int in range(from_index, events.size()):
		var ev: SimEvent = events[tag_i] as SimEvent
		if ev != null and not ev.data.has("dash_hit_step"):
			ev.data["dash_hit_step"] = step_index

static func push(board: BoardState, target: UnitState, direction: Vector2i, distance: int, events: Array[SimEvent], pusher: UnitState = null, ability_id: StringName = &"", collision_immune_id: int = -1) -> void:
	if target == null or not target.is_alive() or direction == Vector2i.ZERO or distance <= 0:
		return

	var effective_distance: int = distance
	if pusher != null and pusher.has_passive(&"battering_ram"):
		effective_distance += 1
	if not target.passive_flags.get("no_push_mitigation", false):
		var mitigation_tiles := int(target.passive_flags.get("push_mitigation_tiles", 0))
		if mitigation_tiles > 0:
			effective_distance = maxi(0, effective_distance - mitigation_tiles)
		
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
	for _i in range(effective_distance):
		var next := target.position + direction

		# Wall or board edge: stop and take collision damage.
		if GridSystem.stops_displacement(board, next) or not GridSystem.is_in_bounds(board, next):
			_emit_collision(board, target, null, next, effective_distance, traveled, events, pusher, ability_id, collision_immune_id)
			if (
				pusher != null
				and pusher.has_passive(&"battering_ram")
				and pusher.is_passive_upgraded(&"battering_ram")
			):
				if not CombatSystem.try_resist_crowd_control(target, GameEnums.StatusType.STAGGER, events):
					target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAGGER, 1))
					target._recalculate_stats()
			break

		# Another unit: both take collision damage; neither moves further.
		var blocker := board.get_unit_at(next)
		if blocker != null:
			_emit_collision(board, target, blocker, next, effective_distance, traveled, events, pusher, ability_id, collision_immune_id)
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
		if pusher != null:
			pusher.passive_flags["push_used_this_turn"] = true
		for status in target.active_statuses:
			if status.type == GameEnums.StatusType.BLEED:
				CombatSystem.deal_damage(board, target, 3 * traveled, events, &"bleed", false, false, null, "Bleed (push)", 3 * traveled)
		if pusher != null and ability_id != &"":
			var ability: AbilityData = pusher.get_ability_by_id(ability_id)
			if ability != null:
				if AbilitySystem.ability_has_modifier(ability, &"buff_on_push", pusher):
					pusher.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, 1))
					pusher._recalculate_stats()
				if ability.movement_point_cost == 0:
					for passive: PassiveData in pusher.active_passives:
						if passive == null or not passive.modifiers.has("push_next_attack_pierce"):
							continue
						pusher.passive_flags["next_attack_pierce"] = true
						if passive.modifiers.has("push_mov"):
							pusher.movement.points_left = mini(
								pusher.movement.max_points,
								pusher.movement.points_left + int(passive.modifiers["push_mov"]),
							)
						if (
							pusher.is_passive_upgraded(passive.id)
							and passive.modifiers.has("upgraded_push_shield")
						):
							CombatSystem.add_armor(
								board,
								pusher,
								int(passive.modifiers["upgraded_push_shield"]),
								events,
							)
				
		var pushed_data: Dictionary = {
			"unit": target.id,
			"from": from,
			"to": target.position,
			"distance": traveled,
		}
		if pusher != null:
			pushed_data["pusher"] = pusher.id
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_PUSHED, pushed_data))
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
	var start_idx := events.size()
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
	
	var object_collision_stagger = false
	var enemy_collision_stagger_both = false
	var stagger_on_collision = false
	
	if ability_id != &"" and pusher != null:
		var ability: AbilityData = pusher.get_ability_by_id(ability_id)
		if ability != null:
			object_collision_stagger = AbilitySystem.ability_has_modifier(
				ability,
				&"object_collision_stagger",
				pusher,
			)
			enemy_collision_stagger_both = AbilitySystem.ability_has_modifier(
				ability,
				&"enemy_collision_stagger_both",
				pusher,
			)
			stagger_on_collision = AbilitySystem.ability_has_modifier(
				ability,
				&"stagger_on_collision",
				pusher,
			)

	if pusher != null and pusher != target:
		var stun_on_hit = stagger_on_collision
		if events.size() > 0 and not stun_on_hit:
			for e in events:
				if e.type == GameEnums.SimEventType.UNIT_PUSHED and e.data.get("unit", -1) == target.id:
					if e.data.has("stagger_on_collision"):
						stun_on_hit = e.data["stagger_on_collision"]
					break
		if stun_on_hit:
			if not CombatSystem.try_resist_crowd_control(target, GameEnums.StatusType.STAGGER, events):
				target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAGGER, 1))
				target._recalculate_stats()
			
	if blocker != null:
		if enemy_collision_stagger_both:
			if not CombatSystem.try_resist_crowd_control(target, GameEnums.StatusType.STAGGER, events):
				target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAGGER, 1))
				target._recalculate_stats()
			if not CombatSystem.try_resist_crowd_control(blocker, GameEnums.StatusType.STAGGER, events):
				blocker.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAGGER, 1))
				blocker._recalculate_stats()
		if (
			pusher != null
			and blocker.team != pusher.team
			and pusher.get_ability_by_id(ability_id) != null
		):
			var collision_ability := pusher.get_ability_by_id(ability_id)
			var collision_pierce: bool = AbilitySystem.ability_has_modifier(
				collision_ability,
				&"push_collision_pierce",
				pusher,
			)
			var collision_power: int = _ability_modifier_value(
				pusher,
				collision_ability,
				&"push_collision_damage",
			)
			if collision_power > 0:
				var collision_raw := CombatSystem.calculate_scaled_damage(
					pusher, collision_power, GameEnums.StatType.PHYSICAL, board,
				)
				CombatSystem.deal_damage(
					board, blocker, collision_raw, events, &"physical",
					collision_pierce, false, pusher, collision_ability.display_name,
					collision_raw,
				)
			
		if blocker.has_passive(&"collision_retaliator") and blocker.team != target.team:
			var collision_shield := 0
			var shockwave_damage := 0
			var shockwave_radius := 0
			var kinetic_dissipation_upgraded := false
			for passive: PassiveData in blocker.active_passives:
				if passive == null or not passive.modifiers.has("collision_grant_shield_def"):
					continue
				collision_shield = blocker.current_defense
				shockwave_damage = blocker.current_defense
				shockwave_radius = int(passive.modifiers.get("collision_shockwave_radius", 1))
				kinetic_dissipation_upgraded = blocker.is_passive_upgraded(passive.id)
				break
			if collision_shield > 0:
				CombatSystem.add_armor(board, blocker, collision_shield, events)
			if blocker.is_passive_upgraded(&"collision_retaliator"):
				CombatSystem.add_armor(board, blocker, 2, events)
			if shockwave_damage > 0:
				for direction: Vector2i in GridSystem.DIRECTIONS:
					var shockwave_target := board.get_unit_at(blocker.position + direction)
					if (
						shockwave_target != null
						and shockwave_target.team != blocker.team
						and GridSystem.manhattan(blocker.position, shockwave_target.position)
							<= shockwave_radius
					):
						CombatSystem.deal_damage(
							board,
							shockwave_target,
							shockwave_damage,
							events,
							&"physical",
							false,
							false,
							blocker,
							"Kinetic Dissipation",
							shockwave_damage,
						)
			if target.id != collision_immune_id:
				CombatSystem.deal_collision_damage(
					board, pusher, target, push_distance, tiles_moved, events,
					CombatSystem.COLLISION_RETALIATOR_BASE_BONUS,
				)
			if kinetic_dissipation_upgraded:
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
		if object_collision_stagger:
			if not CombatSystem.try_resist_crowd_control(target, GameEnums.StatusType.STAGGER, events):
				target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAGGER, 1))
				target._recalculate_stats()
			
		if target.id != collision_immune_id:
			CombatSystem.deal_collision_damage(
				board, pusher, target, push_distance, tiles_moved, events, collision_base_bonus
			)
	var collision_ability := pusher.get_ability_by_id(ability_id) \
		if pusher != null and ability_id != &"" else null
	var splash_damage := _ability_modifier_value(
		pusher, collision_ability, &"collision_splash_damage",
	)
	if splash_damage > 0:
		var splash_center := blocker.position if blocker != null else target.position
		for direction: Vector2i in GridSystem.DIRECTIONS:
			var splash_target := board.get_unit_at(splash_center + direction)
			if (
				splash_target == null
				or not splash_target.is_alive()
				or splash_target.team == pusher.team
			):
				continue
			var splash_raw := CombatSystem.calculate_scaled_damage(
				pusher, splash_damage, GameEnums.StatType.PHYSICAL, board,
			)
			CombatSystem.deal_damage(
				board, splash_target, splash_raw, events, &"physical", false,
				false, pusher, collision_ability.display_name, splash_raw,
			)
			if AbilitySystem.ability_has_modifier(
				collision_ability, &"collision_splash_weaken", pusher,
			):
				splash_target.active_statuses.append(DataLibrary.make_status(
					GameEnums.StatusType.WEAKEN, 1,
				))
				splash_target._recalculate_stats(board)
	for i: int in range(start_idx, events.size()):
		events[i].data["is_collision_side_effect"] = true


static func _ability_modifier_value(
	actor: UnitState,
	ability: AbilityData,
	key: StringName,
	default_value: int = 0,
) -> int:
	if actor == null or ability == null:
		return default_value
	var modules: Array[AbilityModule] = AbilitySystem.active_modules_for(actor, ability)
	if not modules.is_empty():
		return AbilityModuleBridge.modules_modifier_value(modules, key, default_value)
	for effect: EffectData in AbilitySystem.legacy_effects_for(actor, ability):
		var key_text: String = String(key)
		if effect != null and effect.modifiers.has(key_text):
			return int(effect.modifiers[key_text])
	return default_value


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
		"swap_displacement": true,
	}))
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_PUSHED, {
		"unit": b.id, "from": pb, "to": b.position, "distance": GridSystem.manhattan(pa, pb),
		"swap_displacement": true,
	}))
	TerrainSystem.apply_landing(board, a, events)
	TerrainSystem.apply_landing(board, b, events)
