class_name UnitState
extends RefCounted

## Purpose: The live state of one unit during a battle. Single source of truth for
## that unit's HP, position, facing, and remaining points.
## Responsibilities: Hold runtime state assembled from components; clone itself.
## Dependencies: UnitData (shared template), HealthComponent, MovementComponent,
##   AbilityComponent, GameEnums.
## Lifecycle: created from a UnitData; deep-copied for every preview; discarded
##   when the battle ends.

var id: int = -1
var definition: UnitData
var team: GameEnums.Team = GameEnums.Team.PLAYER
var controlling_player_id: int = 1
var position: Vector2i = Vector2i.ZERO
var facing: GameEnums.Facing = GameEnums.Facing.SOUTH

var health: HealthComponent = HealthComponent.new()
var movement: MovementComponent = MovementComponent.new()
var ability: AbilityComponent = AbilityComponent.new()

## True after this unit uses their one skill/basic attack this turn (1-phase turn system).
var turn_action_used: bool = false
## Set when a phase-1 (pre-action) move resolves; blocks post-action move unless CANTO.
var pre_move_used_this_turn: bool = false
## Extra MP granted by universal Run this turn only (not a status effect).
var run_boost_amount: int = 0
var turn_start_movement_points: int = 0
var movement_points_spent_this_turn: int = 0
var continuous_straight_tiles_this_turn: int = 0
var continuous_straight_direction: Vector2i = Vector2i.ZERO

var armor: int = 0

## Tracks how many times an ability has been used (ability_index -> count).
var ability_uses: Dictionary = {}

## Generated resource used for potential scoring (Engineer).
var scrap: int = 0

var active_statuses: Array[StatusData] = []
var active_abilities: Array[AbilityData] = []
var active_passives: Array[PassiveData] = []

var upgraded_passives: Array[StringName] = []
var upgraded_abilities: Array[StringName] = []

var passive_flags: Dictionary = {}

var level: int = 1
var current_strength: int = 1
var current_magic: int = 1
var current_defense: int = 1

static func create(p_id: int, def: UnitData, p_team: GameEnums.Team, coord: Vector2i, config: Dictionary = {}) -> UnitState:
	assert(def != null, "UnitState.create requires a UnitData definition")
	var unit := UnitState.new()
	unit.id = p_id
	
	if config.has("weapon"):
		unit.definition = def.duplicate()
		unit.definition.equipped_weapon = config.weapon
	else:
		unit.definition = def
		
	unit.team = p_team
	unit.position = coord
	unit.health = HealthComponent.new(def.base_constitution * 5)
	unit.movement = MovementComponent.new(def.move_points)
	unit.ability = AbilityComponent.new(def.action_points)
	
	if config.has("level"):
		unit.level = config.level
	else:
		unit.level = def.level
	
	if config.size() > 0:
		unit.active_passives.assign(def.innate_passives)
		if config.has("active_abilities"):
			unit.active_abilities.assign(config.active_abilities)
		if config.has("active_passives"):
			unit.active_passives.append_array(config.active_passives)
		if config.has("upgraded_abilities"):
			unit.upgraded_abilities.assign(config.upgraded_abilities)
		if config.has("upgraded_passives"):
			unit.upgraded_passives.assign(config.upgraded_passives)
	else:
		unit.active_passives = def.innate_passives.duplicate()
		if p_team == GameEnums.Team.PLAYER and not def.is_construct:
			unit.active_passives.append_array(_roll_starting_passives(def.passives))
		else:
			unit.active_passives.append_array(def.passives)
		if p_team == GameEnums.Team.PLAYER and not def.is_construct:
			unit.active_abilities = DataLibrary.build_player_active_abilities(def, unit.level)
		else:
			unit.active_abilities = def.abilities.duplicate()
		
	unit._recalculate_stats()
	unit.health.current_hp = unit.health.max_hp
	unit.turn_start_movement_points = unit.movement.max_points
	return unit


static func _roll_starting_passives(pool: Array[PassiveData]) -> Array[PassiveData]:
	var selected: Array[PassiveData] = []
	if pool.is_empty():
		return selected
	var remaining: Array[PassiveData] = pool.duplicate()
	var count: int = mini(2, remaining.size())
	for _i: int in range(count):
		var idx: int = randi() % remaining.size()
		selected.append(remaining[idx])
		remaining.remove_at(idx)
	return selected


func is_ability_upgraded(ability_id: StringName) -> bool:
	return upgraded_abilities.has(ability_id)

func has_passive(passive_id: StringName) -> bool:
	for p in active_passives:
		if p != null and p.id == passive_id:
			return true
	return false

func is_passive_upgraded(passive_id: StringName) -> bool:
	return upgraded_passives.has(passive_id)

func _recalculate_stats(board: BoardState = null) -> void:
	var w_str := 0
	var w_mag := 0
	var w_def := 0
	var w_hp := 0
	var w_mov := 0
	if definition.equipped_weapon != null:
		w_str = definition.equipped_weapon.bonus_strength
		w_mag = definition.equipped_weapon.bonus_magic
		w_def = definition.equipped_weapon.bonus_defense
		w_hp = definition.equipped_weapon.bonus_max_hp
		w_mov = definition.equipped_weapon.bonus_move
		
	var growth: Dictionary = UnitLevelGrowth.compute(definition, level)
	var base_str: int = definition.base_strength + int(growth.str)
	var base_mag: int = definition.base_magic + int(growth.mag)
	var base_def: int = definition.base_defense + int(growth.def)
	var level_con: int = int(growth.con)

	var stat_str := 0
	var stat_mag := 0
	var stat_def := 0
	var stat_mov := 0

	for status in active_statuses:
		match status.type:
			GameEnums.StatusType.STAT_BUFF_STR:
				stat_str += status.value
			GameEnums.StatusType.STAT_BUFF_MAG:
				stat_mag += status.value
			GameEnums.StatusType.STAT_BUFF_MP, GameEnums.StatusType.STAT_BUFF_MOV:
				stat_mov += status.value
			GameEnums.StatusType.STAT_BUFF_DEF:
				stat_def += status.value
			GameEnums.StatusType.STAT_DEBUFF_DEF:
				stat_def -= status.value
			GameEnums.StatusType.STAT_DEBUFF_MOV:
				stat_mov -= status.value
			GameEnums.StatusType.WEAKEN:
				stat_str -= 2
				stat_mag -= 2
				
	health.max_hp = (definition.base_constitution + level_con) * 5 + w_hp
	
	if has_passive(&"adrenaline_junkie"):
		var missing_pct = (health.max_hp - health.current_hp) / float(health.max_hp)
		stat_mov += floori(missing_pct / 0.10)
		
	if is_passive_upgraded(&"enraged"):
		stat_mov += CombatSystem.count_enraged_debuff_hazard_sources(board, self)

	if board != null:
		for source: UnitState in board.units:
			if (
				source == null
				or not source.is_alive()
				or source.team != team
			):
				continue
			for passive: PassiveData in source.active_passives:
				if (
					passive == null
					or not passive.modifiers.has("aura_range")
					or GridSystem.manhattan(source.position, position)
						> int(passive.modifiers["aura_range"])
				):
					continue
				stat_mag += int(passive.modifiers.get("aura_mag", 0))
				stat_str += int(passive.modifiers.get("aura_str", 0))
				if source.is_passive_upgraded(passive.id):
					stat_def += int(passive.modifiers.get("upgraded_aura_def", 0))

	current_strength = maxi(0, base_str + w_str + stat_str)
	current_magic = maxi(0, base_mag + w_mag + stat_mag)
	current_defense = maxi(0, base_def + w_def + stat_def)
	
	
	if has_status(GameEnums.StatusType.ROOT):
		movement.max_points = 0
		movement.points_left = 0
	elif has_status(GameEnums.StatusType.POLYMORPH):
		current_strength = 0
		current_magic = 0
		movement.max_points = 1
		movement.points_left = mini(movement.points_left, 1)
	elif has_status(GameEnums.StatusType.BRACED):
		movement.max_points = 0
		movement.points_left = 0
	else:
		movement.max_points = definition.move_points + w_mov + stat_mov
		if run_boost_amount > 0:
			movement.max_points += run_boost_amount

func has_run_boost() -> bool:
	return run_boost_amount > 0


func apply_run_boost(bonus: int) -> void:
	if bonus <= 0 or run_boost_amount > 0:
		return
	run_boost_amount = bonus
	movement.max_points += bonus
	movement.points_left += bonus


func clear_run_boost() -> void:
	if run_boost_amount <= 0:
		return
	movement.max_points = maxi(0, movement.max_points - run_boost_amount)
	movement.points_left = mini(movement.points_left, movement.max_points)
	run_boost_amount = 0


func _strip_legacy_running_status() -> void:
	for i: int in range(active_statuses.size() - 1, -1, -1):
		if active_statuses[i].type == GameEnums.StatusType.RUNNING:
			active_statuses.remove_at(i)

func has_status(type: int) -> bool:
	for s in active_statuses:
		if s.type == type:
			return true
	return false

func is_alive() -> bool:
	return health.is_alive()

func is_enemy() -> bool:
	return team == GameEnums.Team.ENEMY


func has_unlimited_training_actions() -> bool:
	return bool(passive_flags.get("training_unlimited_actions", false))


func has_used_turn_action() -> bool:
	return turn_action_used and not has_unlimited_training_actions()


## True when this unit may still commit a class skill, basic attack, or Wait (Action column).
## Run is PRE_MOVE only — it spends AP but never consumes this slot.
func can_use_action_slot() -> bool:
	if has_unlimited_training_actions():
		return ability.points_left > 0
	return not turn_action_used


func is_boss() -> bool:
	return definition != null and definition.is_boss


func record_movement(
	route: Array[Vector2i],
	spent: int,
	start: Vector2i = Vector2i(-1, -1),
) -> void:
	if route.is_empty():
		return
	movement_points_spent_this_turn += maxi(0, spent)
	var route_direction := Vector2i.ZERO
	var previous := start if start.x >= 0 and start.y >= 0 else position
	for step: Vector2i in route:
		var direction := step - previous
		if absi(direction.x) + absi(direction.y) != 1:
			continuous_straight_tiles_this_turn = 0
			continuous_straight_direction = Vector2i.ZERO
			return
		if route_direction == Vector2i.ZERO:
			route_direction = direction
		elif route_direction != direction:
			continuous_straight_tiles_this_turn = 0
			continuous_straight_direction = Vector2i.ZERO
			return
		previous = step
	if continuous_straight_direction == route_direction:
		continuous_straight_tiles_this_turn += route.size()
	else:
		continuous_straight_direction = route_direction
		continuous_straight_tiles_this_turn = route.size()


func moved_max_movement_this_turn() -> bool:
	return (
		turn_start_movement_points > 0
		and movement_points_spent_this_turn >= turn_start_movement_points
	)


func reset_for_turn() -> void:
	_strip_legacy_running_status()
	clear_run_boost()
	movement.reset()
	turn_start_movement_points = movement.max_points
	movement_points_spent_this_turn = 0
	continuous_straight_tiles_this_turn = 0
	continuous_straight_direction = Vector2i.ZERO
	ability.reset()
	turn_action_used = false
	pre_move_used_this_turn = false
	armor = 0
	passive_flags.erase("collision_refunded_this_turn")
	passive_flags.erase("adrenaline_surge_active")
	passive_flags.erase("frenzy_on_kill_ap")
	passive_flags.erase("meat_shield_intercept_str")
	passive_flags.erase("violent_collision_recast_used")
	passive_flags.erase("push_used_this_turn")
	passive_flags.erase("jumped_or_teleported_this_turn")
	passive_flags.erase("plunging_attack_consumed")
	passive_flags.erase("suppress_melee_counter")
	passive_flags.erase("next_attack_pierce")
	passive_flags.erase("root_immune_this_turn")
	passive_flags.erase("vaulted_target_id")
	passive_flags.erase("frontline_shield_granted")
	passive_flags.erase("zone_attack_used_this_round")
	passive_flags.erase("overwatch_used")
	passive_flags.erase("corpse_move_empowered")
	passive_flags.erase("springboard_pending_coord")
	passive_flags.erase("springboard_ap_used")
	passive_flags.erase("line_breaker_passed")
	for key: Variant in passive_flags.keys():
		if String(key).begins_with("ability_used_once:"):
			passive_flags.erase(key)

func clone() -> UnitState:
	var copy := UnitState.new()
	copy.id = id
	copy.definition = definition  # shared immutable template; never cloned
	copy.team = team
	copy.controlling_player_id = controlling_player_id
	copy.position = position
	copy.facing = facing
	copy.health = health.clone()
	copy.movement = movement.clone()
	copy.ability = ability.clone()
	copy.turn_action_used = turn_action_used
	copy.pre_move_used_this_turn = pre_move_used_this_turn
	copy.run_boost_amount = run_boost_amount
	copy.turn_start_movement_points = turn_start_movement_points
	copy.movement_points_spent_this_turn = movement_points_spent_this_turn
	copy.continuous_straight_tiles_this_turn = continuous_straight_tiles_this_turn
	copy.continuous_straight_direction = continuous_straight_direction
	copy.armor = armor
	copy.level = level
	copy.scrap = scrap
	copy.ability_uses = ability_uses.duplicate()
	copy.active_statuses = []
	for status in active_statuses:
		copy.active_statuses.append(status.clone())
	copy.active_passives = active_passives.duplicate(true)
	copy.active_abilities = active_abilities.duplicate(true)
	copy.passive_flags = passive_flags.duplicate(true)
	
	copy.upgraded_abilities = upgraded_abilities.duplicate(true)
	copy.upgraded_passives = upgraded_passives.duplicate(true)
	copy.current_strength = current_strength
	copy.current_magic = current_magic
	copy.current_defense = current_defense
	return copy

func get_ability_range(ability_data: AbilityData) -> int:
	if ability_data == null:
		return 0
	if has_status(GameEnums.StatusType.BLIND):
		return 1
	var authored_range := ability_data.range_tiles
	if (
		ability_data != null
		and (
			ability_data.has_tag(AbilityModuleBridge.TAG_ATTACK)
			or DataLibrary.is_basic_ability(ability_data.id)
		)
		and movement_points_spent_this_turn == 0
	):
		for passive: PassiveData in active_passives:
			if passive == null:
				continue
			var range_bonus := int(passive.modifiers.get("zero_move_attack_range", 0))
			if passive.modifiers.has("steady_aim_range"):
				range_bonus = int(passive.modifiers["steady_aim_range"])
				if (
					is_passive_upgraded(passive.id)
					and passive.modifiers.has("upgraded_steady_aim_range")
				):
					range_bonus = int(passive.modifiers["upgraded_steady_aim_range"])
			if range_bonus > 0:
				authored_range += range_bonus
				break
	if is_ability_upgraded(ability_data.id) and ability_data.upgraded_range_tiles != -1:
		return ability_data.upgraded_range_tiles
	return authored_range

func get_ability_by_id(ability_id: StringName) -> AbilityData:
	if DataLibrary.is_universal_run(ability_id):
		return DataLibrary.get_universal_run()
	if DataLibrary.is_universal_wait(ability_id):
		return DataLibrary.get_universal_wait()
	for ab in active_abilities:
		if ab.id == ability_id:
			return ab
	return null
