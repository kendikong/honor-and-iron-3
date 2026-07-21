class_name TestBattleSession
extends RefCounted

## Runtime config for the skill-testing arena.

const MAP_SIZE: Vector2i = Vector2i(10, 10)
const MAP_SEED: int = 9001
const TRAINING_LEVEL: int = 99
const DEFAULT_PLAYER_CLASS: StringName = &"knight"
const DEFAULT_PLAYER_CELL: Vector2i = Vector2i(4, 5)
const DEFAULT_DUMMY_CELL: Vector2i = Vector2i(7, 5)

var player_class_id: StringName = DEFAULT_PLAYER_CLASS
var player_level: int = TRAINING_LEVEL
## passive_id -> enabled
var passive_enabled: Dictionary = {}
## ability_id -> enabled (defaults to true — all skills on unless explicitly disabled)
var skill_enabled: Dictionary = {}
var dummy_coords: Array[Vector2i] = [DEFAULT_DUMMY_CELL]
var extra_player_coords: Array[Vector2i] = []
var unkillable_dummies: bool = true
var infinite_player_ap: bool = false


func reset_defaults() -> void:
	player_class_id = DEFAULT_PLAYER_CLASS
	player_level = TRAINING_LEVEL
	passive_enabled.clear()
	skill_enabled.clear()
	set_all_passives_enabled(player_class_id, false)
	set_all_skills_enabled(player_class_id, true)
	dummy_coords = [DEFAULT_DUMMY_CELL]
	extra_player_coords.clear()
	unkillable_dummies = true
	infinite_player_ap = false


func set_all_passives_enabled(class_id: StringName, enabled: bool) -> void:
	var def: UnitData = DataLibrary.get_unit(class_id)
	if def == null:
		return
	for passive: PassiveData in def.passives:
		passive_enabled[passive.id] = enabled


func set_all_skills_enabled(class_id: StringName, enabled: bool) -> void:
	var def: UnitData = DataLibrary.get_unit(class_id)
	if def == null:
		return
	for ability: AbilityData in def.abilities:
		skill_enabled[ability.id] = enabled


func enabled_passives_for(class_id: StringName) -> Array[PassiveData]:
	var def: UnitData = DataLibrary.get_unit(class_id)
	var out: Array[PassiveData] = []
	if def == null:
		return out
	for passive: PassiveData in def.passives:
		if passive_enabled.get(passive.id, false):
			out.append(passive)
	return out


func enabled_skills_for(class_id: StringName) -> Array[AbilityData]:
	var def: UnitData = DataLibrary.get_unit(class_id)
	var out: Array[AbilityData] = []
	if def == null:
		return out
	for ability: AbilityData in def.abilities:
		if skill_enabled.get(ability.id, true):
			out.append(ability)
	return out


func player_unit_config() -> Dictionary:
	var def: UnitData = DataLibrary.get_unit(player_class_id)
	var all_abilities: Array[AbilityData] = DataLibrary.build_player_active_abilities(def, player_level)
	var active_abilities: Array[AbilityData] = []
	for ability: AbilityData in all_abilities:
		if skill_enabled.get(ability.id, true):
			active_abilities.append(ability)
	return {
		"level": player_level,
		"active_abilities": active_abilities,
		"active_passives": enabled_passives_for(player_class_id),
	}


static func is_in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < MAP_SIZE.x and coord.y < MAP_SIZE.y


func is_reserved_coord(coord: Vector2i) -> bool:
	if coord == DEFAULT_PLAYER_CELL:
		return true
	for existing: Vector2i in dummy_coords:
		if existing == coord:
			return true
	for existing: Vector2i in extra_player_coords:
		if existing == coord:
			return true
	return false


func is_cell_available(board: BoardState, coord: Vector2i) -> bool:
	if not is_in_bounds(coord):
		return false
	if is_reserved_coord(coord):
		return false
	if board != null:
		for unit: UnitState in board.units:
			if unit.is_alive() and unit.position == coord:
				return false
	return true


func find_free_cell_near(board: BoardState, preferred: Vector2i) -> Vector2i:
	if is_cell_available(board, preferred):
		return preferred
	for radius: int in range(1, MAP_SIZE.x + MAP_SIZE.y):
		for dx: int in range(-radius, radius + 1):
			for dy: int in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var candidate := preferred + Vector2i(dx, dy)
				if is_cell_available(board, candidate):
					return candidate
	return Vector2i(-1, -1)


func try_add_dummy_at(board: BoardState, coord: Vector2i) -> Dictionary:
	var target: Vector2i = find_free_cell_near(board, coord)
	if target.x < 0:
		return {"ok": false, "coord": coord, "reason": "No free cell for training dummy"}
	for existing: Vector2i in dummy_coords:
		if existing == target:
			return {"ok": false, "coord": target, "reason": "Training dummy already at %s" % target}
	dummy_coords.append(target)
	return {"ok": true, "coord": target, "reason": ""}


func try_add_player_at(board: BoardState, coord: Vector2i) -> Dictionary:
	var target: Vector2i = find_free_cell_near(board, coord)
	if target.x < 0:
		return {"ok": false, "coord": coord, "reason": "No free cell for ally"}
	if target == DEFAULT_PLAYER_CELL:
		return {"ok": false, "coord": target, "reason": "Primary player slot is occupied"}
	for existing: Vector2i in extra_player_coords:
		if existing == target:
			return {"ok": false, "coord": target, "reason": "Ally already at %s" % target}
	extra_player_coords.append(target)
	return {"ok": true, "coord": target, "reason": ""}
