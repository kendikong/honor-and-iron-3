class_name MassSimSkirmishSetup
extends RefCounted

const _C = preload("res://core/batch/mass_sim_constants.gd")

## Configurable skirmish rules for mass sim batches and epoch fingerprints.

var player_count: int = _C.SKIRMISH_PLAYER_COUNT
var enemy_count: int = _C.SKIRMISH_ENEMY_COUNT
var player_level: int = _C.SKIRMISH_PLAYER_LEVEL
var enemy_level: int = _C.SKIRMISH_ENEMY_LEVEL
var player_passive_count: int = _C.SKIRMISH_PLAYER_PASSIVE_COUNT
## -1 = all class skills; 0 = none (run/move/basic only); 1+ = random pick count.
var player_class_skill_count: int = -1


const PLAY_SETUP_PATH := "user://skirmish_play_setup.json"


static func load_last_saved() -> MassSimSkirmishSetup:
	return load_play_saved()


static func save_last(setup: MassSimSkirmishSetup) -> void:
	save_play(setup)


static func is_default_dict(data: Dictionary) -> bool:
	return from_dict(data).to_dict() == defaults().to_dict()


static func load_play_saved() -> MassSimSkirmishSetup:
	if not FileAccess.file_exists(PLAY_SETUP_PATH):
		return defaults()
	var file: FileAccess = FileAccess.open(PLAY_SETUP_PATH, FileAccess.READ)
	if file == null:
		return defaults()
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		file.close()
		return defaults()
	file.close()
	return from_dict(json.data as Dictionary)


static func save_play(setup: MassSimSkirmishSetup) -> void:
	var file: FileAccess = FileAccess.open(PLAY_SETUP_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(setup.to_dict()))
	file.close()


static func defaults() -> MassSimSkirmishSetup:
	return MassSimSkirmishSetup.new()


static func from_dict(data: Dictionary) -> MassSimSkirmishSetup:
	var s := MassSimSkirmishSetup.new()
	s.player_count = int(data.get("player_count", _C.SKIRMISH_PLAYER_COUNT))
	s.enemy_count = int(data.get("enemy_count", _C.SKIRMISH_ENEMY_COUNT))
	s.player_level = int(data.get("player_level", _C.SKIRMISH_PLAYER_LEVEL))
	s.enemy_level = int(data.get("enemy_level", _C.SKIRMISH_ENEMY_LEVEL))
	s.player_passive_count = int(data.get("player_passive_count", _C.SKIRMISH_PLAYER_PASSIVE_COUNT))
	s.player_class_skill_count = int(data.get("player_class_skill_count", -1))
	s.clamp()
	return s


func to_dict() -> Dictionary:
	return {
		"player_count": player_count,
		"enemy_count": enemy_count,
		"player_level": player_level,
		"enemy_level": enemy_level,
		"player_passive_count": player_passive_count,
		"player_class_skill_count": player_class_skill_count,
	}


func clamp() -> void:
	player_count = clampi(player_count, _C.SKIRMISH_MIN_PLAYER_COUNT, _C.SKIRMISH_MAX_PLAYER_COUNT)
	enemy_count = clampi(enemy_count, _C.SKIRMISH_MIN_ENEMY_COUNT, _C.SKIRMISH_MAX_ENEMY_COUNT)
	player_level = clampi(player_level, _C.SKIRMISH_MIN_LEVEL, _C.SKIRMISH_MAX_LEVEL)
	enemy_level = clampi(enemy_level, _C.SKIRMISH_MIN_LEVEL, _C.SKIRMISH_MAX_LEVEL)
	player_passive_count = clampi(player_passive_count, 0, _C.SKIRMISH_MAX_PASSIVE_COUNT)
	if player_class_skill_count < -1:
		player_class_skill_count = -1
	if player_class_skill_count > _C.SKIRMISH_MAX_CLASS_SKILL_COUNT:
		player_class_skill_count = _C.SKIRMISH_MAX_CLASS_SKILL_COUNT


func duplicate_setup() -> MassSimSkirmishSetup:
	return MassSimSkirmishSetup.from_dict(to_dict())


func skill_count_label() -> String:
	if player_class_skill_count < 0:
		return "all class skills"
	return "%d class skill(s)" % player_class_skill_count


func summary_label() -> String:
	return (
		"%d vs %d Â· player L%d (%d passives, %s) Â· enemy L%d"
		% [player_count, enemy_count, player_level, player_passive_count, skill_count_label(), enemy_level]
	)
