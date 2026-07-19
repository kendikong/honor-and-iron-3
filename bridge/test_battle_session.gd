class_name TestBattleSession
extends RefCounted

## Runtime config for the skill-testing arena.

const MAP_SIZE: Vector2i = Vector2i(6, 6)
const MAP_SEED: int = 9001
const DEFAULT_PLAYER_CLASS: StringName = &"knight"
const DEFAULT_PLAYER_CELL: Vector2i = Vector2i(2, 2)
const DEFAULT_DUMMY_CELL: Vector2i = Vector2i(4, 2)

var player_class_id: StringName = DEFAULT_PLAYER_CLASS
## passive_id -> enabled
var passive_enabled: Dictionary = {}
var dummy_coords: Array[Vector2i] = [DEFAULT_DUMMY_CELL]
var extra_player_coords: Array[Vector2i] = []
var unkillable_dummies: bool = true
var infinite_player_ap: bool = false


func reset_defaults() -> void:
	player_class_id = DEFAULT_PLAYER_CLASS
	passive_enabled.clear()
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


func enabled_passives_for(class_id: StringName) -> Array[PassiveData]:
	var def: UnitData = DataLibrary.get_unit(class_id)
	var out: Array[PassiveData] = []
	if def == null:
		return out
	for passive: PassiveData in def.passives:
		if passive_enabled.get(passive.id, true):
			out.append(passive)
	return out


func player_unit_config() -> Dictionary:
	var def: UnitData = DataLibrary.get_unit(player_class_id)
	return {
		"level": 99,
		"active_abilities": DataLibrary.build_training_abilities(def),
		"active_passives": enabled_passives_for(player_class_id),
	}


func add_dummy_at(coord: Vector2i) -> void:
	for existing: Vector2i in dummy_coords:
		if existing == coord:
			return
	dummy_coords.append(coord)


func add_player_at(coord: Vector2i) -> void:
	for existing: Vector2i in extra_player_coords:
		if existing == coord:
			return
	extra_player_coords.append(coord)
