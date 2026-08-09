class_name BruiserPlanningSmokeRegistry
extends RefCounted

## Per-active planning commit smoke cells — Knight Tier B parity (click path, no drag/undo).

const _Harness := preload("res://tests/bruiser_qa_harness.gd")


static func run_for_factory_id(failures: Array[String], factory_id: StringName) -> void:
	var entry: Dictionary = _entries().get(factory_id, {})
	if entry.is_empty():
		return
	var mode: String = String(entry.get("mode", "click"))
	var tag: String = String(entry.get("tag", factory_id))
	var bruiser_pos: Vector2i = entry.get("bruiser_pos", Vector2i.ZERO)
	var enemy_pos: Vector2i = entry.get("enemy_pos", Vector2i(-1, -1))
	if mode == "awaiting":
		_Harness.run_planning_awaiting_smoke(
			failures,
			factory_id,
			tag,
			bruiser_pos,
			entry.get("arm_cell", bruiser_pos),
			entry.get("commit_cell", Vector2i.ZERO),
			enemy_pos,
			bool(entry.get("verify_no_jump", true)),
		)
	elif mode == "ally":
		_Harness.run_planning_ally_smoke(
			failures,
			factory_id,
			tag,
			bruiser_pos,
			entry.get("ally_pos", Vector2i.ZERO),
			entry.get("commit_cell", Vector2i.ZERO),
		)
	else:
		_Harness.run_planning_commit_smoke(
			failures,
			factory_id,
			tag,
			entry.get("commit_cell", Vector2i.ZERO),
			bruiser_pos,
			enemy_pos,
			bool(entry.get("verify_no_jump", true)),
		)


static func _entries() -> Dictionary:
	return {
		&"bruiser_push_through": {
			"tag": "push_through",
			"mode": "ally",
			"bruiser_pos": Vector2i(4, 5),
			"ally_pos": Vector2i(5, 5),
			"commit_cell": Vector2i(5, 5),
		},
		&"bruiser_charge_strike": {
			"tag": "charge_strike",
			"mode": "click",
			"bruiser_pos": Vector2i(1, 3),
			"enemy_pos": Vector2i(3, 3),
			"commit_cell": Vector2i(3, 3),
			"verify_no_jump": false,
		},
		&"bruiser_concussion_blow": {
			"tag": "concussion_blow",
			"mode": "click",
			"bruiser_pos": Vector2i(2, 8),
			"enemy_pos": Vector2i(4, 8),
			"commit_cell": Vector2i(4, 8),
		},
		&"bruiser_cleave": {
			"tag": "cleave",
			"mode": "click",
			"bruiser_pos": Vector2i(8, 8),
			"enemy_pos": Vector2i(7, 8),
			"commit_cell": Vector2i(7, 8),
		},
		&"bruiser_suplex": {
			"tag": "suplex",
			"mode": "click",
			"bruiser_pos": Vector2i(4, 5),
			"enemy_pos": Vector2i(5, 5),
			"commit_cell": Vector2i(5, 5),
		},
		&"bruiser_adrenaline_surge": {
			"tag": "adrenaline_surge",
			"mode": "click",
			"bruiser_pos": Vector2i(2, 2),
			"enemy_pos": Vector2i(-1, -1),
			"commit_cell": Vector2i(2, 2),
		},
		&"bruiser_earthshatter": {
			"tag": "earthshatter",
			"mode": "click",
			"bruiser_pos": Vector2i(2, 8),
			"enemy_pos": Vector2i(3, 8),
			"commit_cell": Vector2i(3, 8),
		},
		&"bruiser_meat_shield": {
			"tag": "meat_shield",
			"mode": "ally",
			"bruiser_pos": Vector2i(8, 8),
			"ally_pos": Vector2i(7, 8),
			"commit_cell": Vector2i(7, 8),
		},
		&"bruiser_frenzy": {
			"tag": "frenzy",
			"mode": "click",
			"bruiser_pos": Vector2i(4, 5),
			"enemy_pos": Vector2i(5, 5),
			"commit_cell": Vector2i(5, 5),
		},
		&"bruiser_guttural_roar": {
			"tag": "guttural_roar",
			"mode": "click",
			"bruiser_pos": Vector2i(2, 2),
			"enemy_pos": Vector2i(-1, -1),
			"commit_cell": Vector2i(2, 2),
		},
		&"bruiser_headbutt": {
			"tag": "headbutt",
			"mode": "click",
			"bruiser_pos": Vector2i(2, 8),
			"enemy_pos": Vector2i(3, 8),
			"commit_cell": Vector2i(3, 8),
		},
		&"bruiser_blood_boil": {
			"tag": "blood_boil",
			"mode": "click",
			"bruiser_pos": Vector2i(8, 8),
			"enemy_pos": Vector2i(-1, -1),
			"commit_cell": Vector2i(8, 8),
		},
		&"bruiser_violent_collision": {
			"tag": "violent_collision",
			"mode": "awaiting",
			"bruiser_pos": Vector2i(2, 3),
			"enemy_pos": Vector2i(4, 3),
			"arm_cell": Vector2i(2, 3),
			"commit_cell": Vector2i(5, 3),
			"verify_no_jump": false,
		},
		&"bruiser_crimson_whirlwind": {
			"tag": "crimson_whirlwind",
			"mode": "click",
			"bruiser_pos": Vector2i(4, 5),
			"enemy_pos": Vector2i(-1, -1),
			"commit_cell": Vector2i(4, 5),
		},
		&"bruiser_belly_flop": {
			"tag": "belly_flop",
			"mode": "click",
			"bruiser_pos": Vector2i(3, 3),
			"enemy_pos": Vector2i(5, 4),
			"commit_cell": Vector2i(5, 3),
			"verify_no_jump": false,
		},
		&"bruiser_breaching_dash": {
			"tag": "breaching_dash",
			"mode": "awaiting",
			"bruiser_pos": Vector2i(4, 3),
			"enemy_pos": Vector2i(-1, -1),
			"arm_cell": Vector2i(4, 3),
			"commit_cell": Vector2i(5, 3),
			"verify_no_jump": false,
		},
	}
