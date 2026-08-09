class_name MovementPlanningSmokeRegistry
extends RefCounted

## Global movement/premove planning smoke — every class, every movement-timeline skill.

const _Lib := preload("res://tests/movement_planning_smoke_lib.gd")
const _MovementTimeline := preload("res://tests/movement_timeline_qa_harness.gd")
const _Checklist := preload("res://tests/planning_checklist_harness.gd")


static func has_entry(factory_id: StringName) -> bool:
	return _entries().has(factory_id)


static func run_for_factory_id(failures: Array[String], factory_id: StringName) -> void:
	var entry: Dictionary = _entries().get(factory_id, {})
	if entry.is_empty():
		return
	if not _MovementTimeline.ability_requires_movement_timeline_qa(
		AoeFootprintQaHarness.find_ability_by_id(factory_id),
	):
		return
	print("[MOVEMENT_SMOKE] %s (%s)" % [factory_id, entry.get("class_id", &"")])
	_Lib.run_entry(failures, entry)


static func run_all_for_class(failures: Array[String], class_id: StringName) -> void:
	for factory_id: StringName in _entries().keys():
		var entry: Dictionary = _entries()[factory_id]
		if entry.get("class_id", &"") != class_id:
			continue
		run_for_factory_id(failures, factory_id)


static func run_all(failures: Array[String]) -> void:
	for factory_id: StringName in _entries().keys():
		run_for_factory_id(failures, factory_id)


static func _entries() -> Dictionary:
	return {
		# --- Bruiser ---
		&"bruiser_push_through": {
			"class_id": &"bruiser",
			"factory_id": &"bruiser_push_through",
			"tag": "push_through",
			"mode": "ally",
			"actor_pos": Vector2i(4, 5),
			"ally_pos": Vector2i(5, 5),
			"commit_cell": Vector2i(5, 5),
		},
		&"bruiser_charge_strike": {
			"class_id": &"bruiser",
			"factory_id": &"bruiser_charge_strike",
			"tag": "charge_strike",
			"mode": "click",
			"actor_pos": Vector2i(1, 3),
			"enemy_pos": Vector2i(3, 3),
			"commit_cell": Vector2i(3, 3),
			"verify_no_jump": false,
			"premove_cell": Vector2i(2, 3),
		},
		&"bruiser_violent_collision": {
			"class_id": &"bruiser",
			"factory_id": &"bruiser_violent_collision",
			"tag": "violent_collision",
			"mode": "awaiting",
			"actor_pos": Vector2i(1, 3),
			"arm_cell": Vector2i(2, 3),
			"commit_cell": Vector2i(4, 3),
			"verify_no_jump": false,
			"premove_cell": Vector2i(2, 3),
		},
		&"bruiser_belly_flop": {
			"class_id": &"bruiser",
			"factory_id": &"bruiser_belly_flop",
			"tag": "belly_flop",
			"mode": "click",
			"actor_pos": Vector2i(2, 3),
			"enemy_pos": Vector2i(5, 4),
			"commit_cell": Vector2i(5, 3),
			"verify_no_jump": false,
			"premove_cell": Vector2i(3, 3),
		},
		&"bruiser_breaching_dash": {
			"class_id": &"bruiser",
			"factory_id": &"bruiser_breaching_dash",
			"tag": "breaching_dash",
			"mode": "awaiting",
			"actor_pos": Vector2i(3, 3),
			"arm_cell": Vector2i(4, 3),
			"commit_cell": Vector2i(5, 3),
			"verify_no_jump": false,
			"premove_cell": Vector2i(4, 3),
		},
		# --- Knight ---
		&"knight_swap": {
			"class_id": &"knight",
			"factory_id": &"knight_swap",
			"tag": "swap",
			"mode": "ally",
			"actor_pos": _Checklist.KNIGHT_START,
			"ally_pos": Vector2i(4, 4),
			"commit_cell": Vector2i(4, 4),
		},
		&"knight_bowling_charge": {
			"class_id": &"knight",
			"factory_id": &"knight_bowling_charge",
			"tag": "bowling_charge",
			"mode": "click",
			"actor_pos": _Checklist.KNIGHT_START,
			"commit_cell": Vector2i(8, 5),
			"enemy_pos": _Checklist.ENEMY_POS,
			"verify_no_jump": false,
			"premove_cell": Vector2i(5, 5),
		},
		&"knight_trampling_advance": {
			"class_id": &"knight",
			"factory_id": &"knight_trampling_advance",
			"tag": "trampling_advance",
			"mode": "awaiting",
			"actor_pos": _Checklist.TRAMPLE_START,
			"arm_cell": _Checklist.TRAMPLE_ROUTE[0],
			"commit_cell": _Checklist.TRAMPLE_ROUTE[1],
			"verify_no_jump": false,
			"premove_cell": _Checklist.TRAMPLE_ROUTE[0],
		},
		# --- Archer ---
		&"archer_sidestep": {
			"class_id": &"archer",
			"factory_id": &"archer_sidestep",
			"tag": "sidestep",
			"mode": "click",
			"actor_pos": Vector2i(4, 5),
			"enemy_pos": Vector2i(6, 5),
			"commit_cell": Vector2i(5, 5),
		},
		# --- Lancer ---
		&"lancer_push": {
			"class_id": &"lancer",
			"factory_id": &"lancer_push",
			"tag": "push",
			"mode": "ally",
			"actor_pos": Vector2i(4, 5),
			"ally_pos": Vector2i(5, 5),
			"commit_cell": Vector2i(5, 5),
		},
		&"lancer_piercing_charge": {
			"class_id": &"lancer",
			"factory_id": &"lancer_piercing_charge",
			"tag": "piercing_charge",
			"mode": "click",
			"actor_pos": Vector2i(8, 8),
			"enemy_pos": Vector2i(5, 5),
			"commit_cell": Vector2i(8, 6),
			"verify_no_jump": false,
			"premove_cell": Vector2i(8, 7),
		},
		&"lancer_flanking_maneuver": {
			"class_id": &"lancer",
			"factory_id": &"lancer_flanking_maneuver",
			"tag": "flanking_maneuver",
			"mode": "click",
			"actor_pos": Vector2i(8, 8),
			"enemy_pos": Vector2i(6, 6),
			"commit_cell": Vector2i(7, 6),
			"verify_no_jump": false,
			"premove_cell": Vector2i(8, 7),
		},
		&"lancer_glorious_charge": {
			"class_id": &"lancer",
			"factory_id": &"lancer_glorious_charge",
			"tag": "glorious_charge",
			"mode": "click",
			"actor_pos": Vector2i(5, 5),
			"ally_pos": Vector2i(4, 5),
			"enemy_pos": Vector2i(8, 5),
			"commit_cell": Vector2i(9, 5),
			"verify_no_jump": false,
			"premove_cell": Vector2i(6, 5),
		},
		&"lancer_pole_vault": {
			"class_id": &"lancer",
			"factory_id": &"lancer_pole_vault",
			"tag": "pole_vault",
			"mode": "click",
			"actor_pos": Vector2i(4, 4),
			"enemy_pos": Vector2i(5, 5),
			"commit_cell": Vector2i(6, 5),
			"verify_no_jump": false,
			"premove_cell": Vector2i(5, 4),
		},
		&"lancer_line_breaker": {
			"class_id": &"lancer",
			"factory_id": &"lancer_line_breaker",
			"tag": "line_breaker",
			"mode": "click",
			"actor_pos": Vector2i(4, 5),
			"enemy_pos": Vector2i(5, 5),
			"commit_cell": Vector2i(8, 5),
			"verify_no_jump": false,
			"premove_cell": Vector2i(5, 5),
		},
		&"lancer_meteor_drop": {
			"class_id": &"lancer",
			"factory_id": &"lancer_meteor_drop",
			"tag": "meteor_drop",
			"mode": "click",
			"actor_pos": Vector2i(2, 8),
			"enemy_pos": Vector2i(6, 4),
			"commit_cell": Vector2i(2, 6),
			"verify_no_jump": false,
			"premove_cell": Vector2i(2, 7),
		},
		# --- Cleric ---
		&"cleric_guardian_step": {
			"class_id": &"cleric",
			"factory_id": &"cleric_guardian_step",
			"tag": "guardian_step",
			"mode": "ally",
			"actor_pos": Vector2i(2, 2),
			"ally_pos": Vector2i(3, 2),
			"commit_cell": Vector2i(3, 2),
		},
		# --- Mage ---
		&"mage_blink": {
			"class_id": &"mage",
			"factory_id": &"mage_blink",
			"tag": "blink",
			"mode": "click",
			"actor_pos": Vector2i(4, 5),
			"enemy_pos": Vector2i(6, 5),
			"commit_cell": Vector2i(4, 4),
		},
		&"mage_teleport": {
			"class_id": &"mage",
			"factory_id": &"mage_teleport",
			"tag": "teleport",
			"mode": "click",
			"actor_pos": Vector2i(4, 5),
			"enemy_pos": Vector2i(6, 5),
			"commit_cell": Vector2i(4, 4),
			"verify_no_jump": false,
			"premove_cell": Vector2i(4, 4),
		},
	}
