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

var health: HealthComponent
var movement: MovementComponent
var ability: AbilityComponent

var phase_1_action_used: bool = false
var phase_2_action_used: bool = false

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
		if config.has("active_abilities"):
			unit.active_abilities.assign(config.active_abilities)
		if config.has("active_passives"):
			unit.active_passives.assign(config.active_passives)
		if config.has("upgraded_abilities"):
			unit.upgraded_abilities.assign(config.upgraded_abilities)
		if config.has("upgraded_passives"):
			unit.upgraded_passives.assign(config.upgraded_passives)
	else:
		if p_team == GameEnums.Team.PLAYER and not def.is_construct:
			_roll_starting_passives(unit, def.passives)
		else:
			unit.active_passives = def.passives.duplicate()
		if p_team == GameEnums.Team.PLAYER and not def.is_construct:
			var basic_attack: AbilityData = null
			var class_abilities: Array[AbilityData] = []
			for ab in def.abilities:
				if DataLibrary.is_basic_ability(ab.id):
					basic_attack = ab
				else:
					class_abilities.append(ab)
			if basic_attack == null:
				basic_attack = DataLibrary._make_class_basic_attack(def.id)
			unit.active_abilities.append(basic_attack)
			if unit.level == 1:
				if not class_abilities.is_empty():
					var idx := randi() % class_abilities.size()
					unit.active_abilities.append(class_abilities[idx])
			else:
				unit.active_abilities.append_array(class_abilities)
		else:
			unit.active_abilities = def.abilities.duplicate()
		
	unit._recalculate_stats()
	return unit


static func _roll_starting_passives(unit: UnitState, pool: Array[PassiveData]) -> void:
	unit.active_passives.clear()
	if pool.is_empty():
		return
	var remaining: Array[PassiveData] = pool.duplicate()
	var count: int = mini(2, remaining.size())
	for _i: int in range(count):
		var idx: int = randi() % remaining.size()
		unit.active_passives.append(remaining[idx])
		remaining.remove_at(idx)


func is_ability_upgraded(ability_id: StringName) -> bool:
	return upgraded_abilities.has(ability_id)

func has_passive(passive_id: StringName) -> bool:
	for p in active_passives:
		if p.id == passive_id:
			return true
	return false

func is_passive_upgraded(passive_id: StringName) -> bool:
	return upgraded_passives.has(passive_id)

func _recalculate_stats() -> void:
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
		
	var level_bonus = (level - 1) * 2
	
	var base_str = definition.base_strength
	var base_mag = definition.base_magic
	var base_def = definition.base_defense
	
	if definition.preferred_stat == GameEnums.StatType.PHYSICAL:
		base_str += level_bonus
	elif definition.preferred_stat == GameEnums.StatType.MAGICAL:
		base_mag += level_bonus
	elif definition.preferred_stat == GameEnums.StatType.DEFENSE:
		base_def += level_bonus

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
	
	current_strength = maxi(0, base_str + w_str + stat_str)
	current_magic = maxi(0, base_mag + w_mag + stat_mag)
	current_defense = maxi(0, base_def + w_def + stat_def)
	health.max_hp = (definition.base_constitution * 5) + w_hp
	
	
	if has_status(GameEnums.StatusType.ROOT):
		movement.max_points = 0
		movement.points_left = 0
	elif has_status(GameEnums.StatusType.POLYMORPH):
		current_strength = 0
		current_magic = 0
		movement.max_points = 1
		movement.points_left = mini(movement.points_left, 1)
	else:
		movement.max_points = definition.move_points + w_mov + stat_mov

func has_status(type: int) -> bool:
	for s in active_statuses:
		if s.type == type:
			return true
	return false

func is_alive() -> bool:
	return health.is_alive()

func is_enemy() -> bool:
	return team == GameEnums.Team.ENEMY

func is_boss() -> bool:
	return definition != null and definition.is_boss

func reset_for_turn() -> void:
	movement.reset()
	ability.reset()
	phase_1_action_used = false
	phase_2_action_used = false
	armor = 0

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
	copy.phase_1_action_used = phase_1_action_used
	copy.phase_2_action_used = phase_2_action_used
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
	if has_status(GameEnums.StatusType.BLIND):
		return 1
	if is_ability_upgraded(ability_data.id) and ability_data.upgraded_range_tiles != -1:
		return ability_data.upgraded_range_tiles
	return ability_data.range_tiles
