class_name EnemyPlanner
extends RefCounted

## Purpose: Turns the current board into locked, public enemy intents. Enemy AI
## thinks ONLY during planning; execution just replays the stored intent.
## Responsibilities: For each enemy, choose a destination and (optionally) an
##   attack, and package them as an Intent.
## Dependencies: BoardState, UnitState, Intent, TimelineAction, GridSystem,
##   MovementSystem, PhysicsSystem.
## Lifecycle: stateless; called once at the start of each planning phase.

## Build one locked intent per enemy, dispatched on its declared strategy. Adding
## a new archetype = one new strategy function here; no other system changes.
static func plan(board: BoardState) -> Array[Intent]:
	var intents: Array[Intent] = []
	for unit in board.units:
		if not unit.is_alive() or not unit.is_enemy():
			continue
		if unit.definition == null or unit.definition.behavior == null:
			continue
		intents.append(_plan_for(board, unit))
	return intents

static func _plan_for(board: BoardState, enemy: UnitState) -> Intent:
	match enemy.definition.behavior.strategy:
		&"charger":
			return _plan_charger(board, enemy)
		&"artillery":
			return _plan_artillery(board, enemy)
		&"shover":
			return _plan_shover(board, enemy)
		&"healer":
			return _plan_healer(board, enemy)
		&"protector":
			return _plan_protector(board, enemy)
		&"commander":
			return _plan_commander(board, enemy)
		&"bomber":
			return _plan_bomber(board, enemy)
		&"teleporter":
			return _plan_teleporter(board, enemy)
		&"summoner":
			return _plan_summoner(board, enemy)
		&"sentinel":
			return _plan_sentinel(board, enemy)
		&"flanker":
			return _plan_flanker(board, enemy)
		_:
			return _plan_melee_chase(board, enemy)

static func _get_enemy_attack(enemy: UnitState) -> AbilityData:
	if enemy == null or enemy.definition == null or enemy.definition.behavior == null:
		return null
	var preferred: AbilityData = enemy.definition.behavior.attack
	if preferred != null and enemy.ability.points_left >= preferred.action_point_cost:
		return preferred
	for ab in enemy.active_abilities:
		if ab.action_point_cost <= enemy.ability.points_left:
			return ab
	return null

static func _plan_melee_chase(board: BoardState, enemy: UnitState) -> Intent:
	var intent := Intent.new()
	intent.enemy_id = enemy.id

	var target := _nearest_player(board, enemy)
	if target == null:
		intent.summary = "%s waits" % enemy.definition.display_name
		return intent

	var attack := _get_enemy_attack(enemy)
	var dest := _best_destination_toward(board, enemy, target)
	if dest != enemy.position:
		intent.actions.append(TimelineAction.make_move(enemy.id, dest))

	if attack != null and GridSystem.manhattan(dest, target.position) <= attack.range_tiles:
		intent.actions.append(TimelineAction.make_ability(enemy.id, attack, target.position, target.id))
		intent.summary = "%s -> %s, attacks %s" % [
			enemy.definition.display_name, dest, target.definition.display_name,
		]
	else:
		intent.summary = "%s -> %s" % [enemy.definition.display_name, dest]
	return intent

## Charger: commit to a single cardinal lane toward the target and rush as far as
## movement allows (a telegraphed line), attacking if it ends in range.
static func _plan_charger(board: BoardState, enemy: UnitState) -> Intent:
	var intent := Intent.new()
	intent.enemy_id = enemy.id
	var target := _nearest_player(board, enemy)
	if target == null:
		intent.summary = "%s waits" % enemy.definition.display_name
		return intent

	# Rush only when aligned with the target and no walls block the path;
	# otherwise reposition to route around obstacles.
	var aligned := enemy.position.x == target.position.x or enemy.position.y == target.position.y
	var dest := enemy.position
	var charging := false
	if aligned:
		var dir := PhysicsSystem.cardinal_from_to(enemy.position, target.position)
		var is_clear := true
		var scan := enemy.position
		while scan != target.position:
			scan += dir
			if GridSystem.is_wall(board, scan):
				is_clear = false
				break
		if is_clear:
			dest = _line_advance(board, enemy.position, dir, enemy.movement.points_left)
			charging = true
		else:
			dest = _best_destination_toward(board, enemy, target)
	else:
		dest = _best_destination_toward(board, enemy, target)

	if dest != enemy.position:
		intent.actions.append(TimelineAction.make_move(enemy.id, dest))

	var attack := _get_enemy_attack(enemy)
	if attack != null and GridSystem.manhattan(dest, target.position) <= attack.range_tiles:
		intent.actions.append(TimelineAction.make_ability(enemy.id, attack, target.position, target.id))
		intent.summary = "%s charges %s, attacks %s" % [
			enemy.definition.display_name,
			_dir_name(PhysicsSystem.cardinal_from_to(enemy.position, target.position)),
			target.definition.display_name,
		]
	elif charging:
		intent.summary = "%s charges %s" % [
			enemy.definition.display_name, _dir_name(PhysicsSystem.cardinal_from_to(enemy.position, target.position)),
		]
	else:
		intent.summary = "%s repositions" % enemy.definition.display_name
	return intent

## Artillery: keep distance and fire. Attacks in place if already in range; steps
## back one tile if the target is adjacent; otherwise closes until in range.
static func _plan_artillery(board: BoardState, enemy: UnitState) -> Intent:
	var intent := Intent.new()
	intent.enemy_id = enemy.id
	var target := _nearest_player(board, enemy)
	var attack := _get_enemy_attack(enemy)
	if target == null or attack == null:
		intent.summary = "%s waits" % enemy.definition.display_name
		return intent

	var dist := GridSystem.manhattan(enemy.position, target.position)
	var dest := enemy.position
	if dist <= 1:
		# Cornered: retreat one tile directly away from the target.
		var away := PhysicsSystem.cardinal_from_to(target.position, enemy.position)
		dest = _line_advance(board, enemy.position, away, 1)
	elif dist > attack.range_tiles:
		dest = _best_destination_toward(board, enemy, target)

	if dest != enemy.position:
		intent.actions.append(TimelineAction.make_move(enemy.id, dest))

	if GridSystem.manhattan(dest, target.position) <= attack.range_tiles:
		intent.actions.append(TimelineAction.make_ability(enemy.id, attack, target.position, target.id))
		intent.summary = "%s fires at %s" % [enemy.definition.display_name, target.definition.display_name]
	else:
		intent.summary = "%s repositions" % enemy.definition.display_name
	return intent

## Shover: close in and use its (damage-free) push to displace a player. With a
## pit or edge behind the target this is a lethal threat the player must dodge.
static func _plan_shover(board: BoardState, enemy: UnitState) -> Intent:
	var intent := Intent.new()
	intent.enemy_id = enemy.id
	var target := _nearest_player(board, enemy)
	if target == null:
		intent.summary = "%s waits" % enemy.definition.display_name
		return intent

	var dest := _best_destination_toward(board, enemy, target)
	if dest != enemy.position:
		intent.actions.append(TimelineAction.make_move(enemy.id, dest))

	var attack := _get_enemy_attack(enemy)
	if attack != null and GridSystem.manhattan(dest, target.position) <= attack.range_tiles:
		intent.actions.append(TimelineAction.make_ability(enemy.id, attack, target.position, target.id))
		intent.summary = "%s shoves %s" % [enemy.definition.display_name, target.definition.display_name]
	else:
		intent.summary = "%s advances" % enemy.definition.display_name
	return intent

## Healer: finds the injured ally with the lowest HP percentage, moves toward them,
## and casts its heal ability if in range. Otherwise, stays near allies.
static func _plan_healer(board: BoardState, enemy: UnitState) -> Intent:
	var intent := Intent.new()
	intent.enemy_id = enemy.id
	
	var best_target: UnitState = null
	var lowest_hp_pct := 1.0
	var heal_ability := _get_enemy_attack(enemy)
	
	# 1. Find the most injured ally (excluding self for simplicity, or include self if desired)
	for unit in board.units:
		if not unit.is_alive() or not unit.is_enemy():
			continue
		var pct := float(unit.health.current_hp) / float(unit.health.max_hp)
		if pct < lowest_hp_pct or (pct == lowest_hp_pct and (best_target == null or unit.id < best_target.id)):
			lowest_hp_pct = pct
			best_target = unit
			
	# If everyone is at full HP, just follow a random ally or wait
	if lowest_hp_pct >= 1.0 or best_target == null:
		intent.summary = "%s waits" % enemy.definition.display_name
		return intent
		
	var dest := _best_destination_toward(board, enemy, best_target)
	if dest != enemy.position:
		intent.actions.append(TimelineAction.make_move(enemy.id, dest))
		
	if heal_ability != null and GridSystem.manhattan(dest, best_target.position) <= heal_ability.range_tiles:
		intent.actions.append(TimelineAction.make_ability(enemy.id, heal_ability, best_target.position, best_target.id))
		intent.summary = "%s mends %s" % [enemy.definition.display_name, best_target.definition.display_name]
	else:
		intent.summary = "%s repositions" % enemy.definition.display_name
	return intent

## Walk a single cardinal direction while tiles stay passable, up to max_steps.
## Returns the final reachable tile (the start tile if it cannot move).
static func _line_advance(board: BoardState, start: Vector2i, dir: Vector2i, max_steps: int) -> Vector2i:
	if dir == Vector2i.ZERO:
		return start
	var pos := start
	for _i in range(max_steps):
		var next := pos + dir
		if not GridSystem.is_passable(board, next):
			break
		pos = next
	return pos

static func _dir_name(dir: Vector2i) -> String:
	if dir == Vector2i(0, -1):
		return "north"
	if dir == Vector2i(0, 1):
		return "south"
	if dir == Vector2i(1, 0):
		return "east"
	if dir == Vector2i(-1, 0):
		return "west"
	return "in place"

static func _nearest_player(board: BoardState, enemy: UnitState) -> UnitState:
	var best: UnitState = null
	var best_dist := 1 << 30
	for unit in board.units:
		if not unit.is_alive() or unit.is_enemy():
			continue
		var dist := GridSystem.manhattan(enemy.position, unit.position)
		# Tie-break on lowest id so the choice is deterministic.
		if dist < best_dist or (dist == best_dist and (best == null or unit.id < best.id)):
			best_dist = dist
			best = unit
	return best

## Pick the reachable tile adjacent to the target that has the shortest path,
## then walk as far along it as movement points allow.
static func _best_destination_toward(board: BoardState, enemy: UnitState, target: UnitState) -> Vector2i:
	var best_path: Array[Vector2i] = []
	var found := false
	for dir in GridSystem.DIRECTIONS:
		var stand := target.position + dir
		if stand == enemy.position:
			return enemy.position  # already adjacent
		if not GridSystem.is_passable(board, stand):
			continue
		var path := MovementSystem.find_path(board, enemy.position, stand, 1 << 30)
		if path.is_empty():
			continue
		if not found or path.size() < best_path.size():
			best_path = path
			found = true

	if not found:
		return enemy.position
	var steps := mini(best_path.size(), enemy.movement.points_left)
	if steps <= 0:
		return enemy.position
	return best_path[steps - 1]

static func _plan_protector(board: BoardState, enemy: UnitState) -> Intent:
	var intent := Intent.new()
	intent.enemy_id = enemy.id
	var best_target: UnitState = null
	var lowest_hp_pct := 1.1
	
	for unit in board.units:
		if not unit.is_alive() or not unit.is_enemy() or unit.id == enemy.id:
			continue
		var pct := float(unit.health.current_hp) / float(unit.health.max_hp)
		if pct < lowest_hp_pct or (pct == lowest_hp_pct and (best_target == null or unit.id < best_target.id)):
			lowest_hp_pct = pct
			best_target = unit
			
	if best_target == null:
		intent.summary = "%s waits" % enemy.definition.display_name
		return intent
		
	var dest := _best_destination_toward(board, enemy, best_target)
	if dest != enemy.position:
		intent.actions.append(TimelineAction.make_move(enemy.id, dest))
		
	var ability := _get_enemy_attack(enemy)
	if ability != null and GridSystem.manhattan(dest, best_target.position) <= ability.range_tiles:
		intent.actions.append(TimelineAction.make_ability(enemy.id, ability, best_target.position, best_target.id))
		intent.summary = "%s shields %s" % [enemy.definition.display_name, best_target.definition.display_name]
	else:
		intent.summary = "%s protects %s" % [enemy.definition.display_name, best_target.definition.display_name]
	return intent

static func _plan_commander(board: BoardState, enemy: UnitState) -> Intent:
	var intent := Intent.new()
	intent.enemy_id = enemy.id
	
	var best_ally: UnitState = null
	var min_dist := 1 << 30
	for unit in board.units:
		if not unit.is_alive() or not unit.is_enemy() or unit.id == enemy.id:
			continue
		var dist := GridSystem.manhattan(enemy.position, unit.position)
		if dist < min_dist or (dist == min_dist and (best_ally == null or unit.id < best_ally.id)):
			min_dist = dist
			best_ally = unit
			
	var ability := _get_enemy_attack(enemy)
	var dest := enemy.position
	
	if best_ally != null:
		if min_dist > 3:
			dest = _best_destination_toward(board, enemy, best_ally)
		else:
			var player := _nearest_player(board, enemy)
			if player != null and GridSystem.manhattan(enemy.position, player.position) <= 1:
				var away := PhysicsSystem.cardinal_from_to(player.position, enemy.position)
				var candidate := _line_advance(board, enemy.position, away, 1)
				if GridSystem.manhattan(candidate, best_ally.position) <= 3:
					dest = candidate
	else:
		var player := _nearest_player(board, enemy)
		if player != null:
			var away := PhysicsSystem.cardinal_from_to(player.position, enemy.position)
			dest = _line_advance(board, enemy.position, away, enemy.movement.points_left)
			
	if dest != enemy.position:
		intent.actions.append(TimelineAction.make_move(enemy.id, dest))
		
	var target_ally = best_ally
	if target_ally != null and ability != null and GridSystem.manhattan(dest, target_ally.position) <= ability.range_tiles:
		intent.actions.append(TimelineAction.make_ability(enemy.id, ability, target_ally.position, target_ally.id))
		intent.summary = "%s commands %s" % [enemy.definition.display_name, target_ally.definition.display_name]
	else:
		intent.summary = "%s commands from safety" % enemy.definition.display_name
	return intent

static func _plan_bomber(board: BoardState, enemy: UnitState) -> Intent:
	var intent := Intent.new()
	intent.enemy_id = enemy.id
	
	var candidates := _find_reachable_unoccupied(board, enemy)
	var best_dest := enemy.position
	var max_players := -1
	var best_dist_to_player := 1 << 30
	
	var nearest_p := _nearest_player(board, enemy)
	
	for cand in candidates:
		var p_count := _count_adjacent_players(board, cand)
		var dist_to_p := GridSystem.manhattan(cand, nearest_p.position) if nearest_p != null else 0
		if p_count > max_players:
			max_players = p_count
			best_dest = cand
			best_dist_to_player = dist_to_p
		elif p_count == max_players:
			if dist_to_p < best_dist_to_player:
				best_dest = cand
				best_dist_to_player = dist_to_p
			elif dist_to_p == best_dist_to_player:
				if cand.x < best_dest.x or (cand.x == best_dest.x and cand.y < best_dest.y):
					best_dest = cand
					
	if best_dest != enemy.position:
		intent.actions.append(TimelineAction.make_move(enemy.id, best_dest))
		
	var attack := _get_enemy_attack(enemy)
	if attack != null and _count_adjacent_players(board, best_dest) > 0:
		intent.actions.append(TimelineAction.make_ability(enemy.id, attack, best_dest, enemy.id))
		intent.summary = "%s moves to %s and self-destructs!" % [enemy.definition.display_name, best_dest]
	else:
		intent.summary = "%s moves toward players (%s)" % [enemy.definition.display_name, best_dest]
	return intent

static func _plan_teleporter(board: BoardState, enemy: UnitState) -> Intent:
	var intent := Intent.new()
	intent.enemy_id = enemy.id
	
	var target := _farthest_player(board, enemy)
	if target == null:
		intent.summary = "%s waits" % enemy.definition.display_name
		return intent
		
	var dest := _find_backstab_tile(target)
	var can_teleport := GridSystem.is_in_bounds(board, dest) and not GridSystem.is_occupied(board, dest) and GridSystem.is_passable(board, dest)
	
	if not can_teleport:
		for dir in GridSystem.DIRECTIONS:
			var cand := target.position + dir
			if GridSystem.is_in_bounds(board, cand) and not GridSystem.is_occupied(board, cand) and GridSystem.is_passable(board, cand):
				dest = cand
				can_teleport = true
				break
				
	if can_teleport:
		if dest != enemy.position:
			intent.actions.append(TimelineAction.make_move(enemy.id, dest))
		var attack := _get_enemy_attack(enemy)
		if attack != null:
			intent.actions.append(TimelineAction.make_ability(enemy.id, attack, target.position, target.id))
			intent.summary = "%s teleports behind %s and attacks!" % [enemy.definition.display_name, target.definition.display_name]
	else:
		intent.summary = "%s waits (no landing tile)" % enemy.definition.display_name
		
	return intent

static func _plan_summoner(board: BoardState, enemy: UnitState) -> Intent:
	var intent := Intent.new()
	intent.enemy_id = enemy.id
	
	var behavior := enemy.definition.behavior
	if behavior == null or behavior.spawn_unit == null:
		intent.summary = "%s waits" % enemy.definition.display_name
		return intent
		
	var cap := behavior.max_spawns
	var current_count := board.count_living_by_definition(behavior.spawn_unit)
	
	var spawn_coord := Vector2i(-1, -1)
	if cap <= 0 or current_count < cap:
		for dir in GridSystem.DIRECTIONS:
			var cand := enemy.position + dir
			if GridSystem.is_in_bounds(board, cand) and not GridSystem.is_occupied(board, cand) and GridSystem.is_passable(board, cand):
				spawn_coord = cand
				break
				
	var player := _nearest_player(board, enemy)
	var dest := enemy.position
	if player != null and GridSystem.manhattan(enemy.position, player.position) <= 2:
		var away := PhysicsSystem.cardinal_from_to(player.position, enemy.position)
		dest = _line_advance(board, enemy.position, away, enemy.movement.points_left)
		
	if dest != enemy.position:
		intent.actions.append(TimelineAction.make_move(enemy.id, dest))
		if cap <= 0 or current_count < cap:
			spawn_coord = Vector2i(-1, -1)
			for dir in GridSystem.DIRECTIONS:
				var cand := dest + dir
				if GridSystem.is_in_bounds(board, cand) and not GridSystem.is_occupied(board, cand) and GridSystem.is_passable(board, cand):
					spawn_coord = cand
					break
					
	if spawn_coord != Vector2i(-1, -1):
		var spawn_ability := _get_enemy_attack(enemy)
		if spawn_ability != null:
			intent.actions.append(TimelineAction.make_ability(enemy.id, spawn_ability, spawn_coord, -1))
			intent.summary = "%s summons a Hatchling at %s" % [enemy.definition.display_name, spawn_coord]
		else:
			intent.summary = "%s waits" % enemy.definition.display_name
	else:
		if current_count >= cap:
			intent.summary = "%s waits (spawn cap reached)" % enemy.definition.display_name
		else:
			intent.summary = "%s waits (no space to spawn)" % enemy.definition.display_name
	return intent

static func _plan_sentinel(board: BoardState, enemy: UnitState) -> Intent:
	var intent := Intent.new()
	intent.enemy_id = enemy.id
	
	var attack := _get_enemy_attack(enemy)
	if attack == null:
		intent.summary = "%s active" % enemy.definition.display_name
		return intent
		
	var best_target: UnitState = null
	var best_dist := 1 << 30
	for unit in board.units:
		if not unit.is_alive() or unit.is_enemy():
			continue
		var dist := GridSystem.manhattan(enemy.position, unit.position)
		if dist <= attack.range_tiles:
			if dist < best_dist or (dist == best_dist and (best_target == null or unit.id < best_target.id)):
				best_dist = dist
				best_target = unit
				
	if best_target != null:
		intent.actions.append(TimelineAction.make_ability(enemy.id, attack, best_target.position, best_target.id))
		intent.summary = "%s targets player %s" % [enemy.definition.display_name, best_target.definition.display_name]
	else:
		intent.summary = "%s watching" % enemy.definition.display_name
	return intent

static func _plan_flanker(board: BoardState, enemy: UnitState) -> Intent:
	var intent := Intent.new()
	intent.enemy_id = enemy.id
	
	var target := _nearest_player(board, enemy)
	if target == null:
		intent.summary = "%s waits" % enemy.definition.display_name
		return intent
		
	var backstab_coord := _find_backstab_tile(target)
	var dest := enemy.position
	var path: Array[Vector2i] = []
	
	if GridSystem.is_passable(board, backstab_coord):
		path = MovementSystem.find_path(board, enemy.position, backstab_coord, 1 << 30)
		
	if not path.is_empty():
		var steps := mini(path.size(), enemy.movement.points_left)
		if steps > 0:
			dest = path[steps - 1]
	else:
		dest = _best_destination_toward(board, enemy, target)
		
	if dest != enemy.position:
		intent.actions.append(TimelineAction.make_move(enemy.id, dest))
		
	var attack := _get_enemy_attack(enemy)
	if attack != null and GridSystem.manhattan(dest, target.position) <= attack.range_tiles:
		intent.actions.append(TimelineAction.make_ability(enemy.id, attack, target.position, target.id))
		if dest == backstab_coord:
			intent.summary = "%s backstabs %s!" % [enemy.definition.display_name, target.definition.display_name]
		else:
			intent.summary = "%s strikes %s" % [enemy.definition.display_name, target.definition.display_name]
	else:
		intent.summary = "%s flanks %s" % [enemy.definition.display_name, target.definition.display_name]
		
	return intent

static func _farthest_player(board: BoardState, enemy: UnitState) -> UnitState:
	var best: UnitState = null
	var max_dist := -1
	for unit in board.units:
		if not unit.is_alive() or unit.is_enemy():
			continue
		var dist := GridSystem.manhattan(enemy.position, unit.position)
		if dist > max_dist or (dist == max_dist and (best == null or unit.id < best.id)):
			max_dist = dist
			best = unit
	return best

static func _find_backstab_tile(target: UnitState) -> Vector2i:
	return target.position - PhysicsSystem.facing_to_vector(target.facing)

static func _find_reachable_unoccupied(board: BoardState, enemy: UnitState) -> Array[Vector2i]:
	var list: Array[Vector2i] = [enemy.position]
	var max_dist := enemy.movement.points_left
	var min_x = clampi(enemy.position.x - max_dist, 0, board.grid_size.x - 1)
	var max_x = clampi(enemy.position.x + max_dist, 0, board.grid_size.x - 1)
	var min_y = clampi(enemy.position.y - max_dist, 0, board.grid_size.y - 1)
	var max_y = clampi(enemy.position.y + max_dist, 0, board.grid_size.y - 1)
	
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var pos := Vector2i(x, y)
			if pos == enemy.position:
				continue
			if GridSystem.is_occupied(board, pos) or not GridSystem.is_passable(board, pos):
				continue
			var path := MovementSystem.find_path(board, enemy.position, pos, max_dist)
			if not path.is_empty():
				list.append(pos)
	return list

static func _count_adjacent_players(board: BoardState, coord: Vector2i) -> int:
	var count := 0
	for dir in GridSystem.DIRECTIONS:
		var adj := coord + dir
		var occupant := board.get_unit_at(adj)
		if occupant != null and occupant.is_alive() and not occupant.is_enemy():
			count += 1
	return count

