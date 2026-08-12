class_name BeastRiderScenarioRegistry
extends RefCounted


static func all_entries() -> Array[Dictionary]:
	return [
		_entry(&"beast_reposition", "reposition", "res://tests/skills/beast_reposition_scenario.gd"),
		_entry(&"beast_pounce", "pounce", "res://tests/skills/beast_pounce_scenario.gd"),
		_entry(&"beast_feral_drag", "feral_drag", "res://tests/skills/beast_feral_drag_scenario.gd"),
		_entry(&"beast_maul", "maul", "res://tests/skills/beast_maul_scenario.gd"),
		_entry(&"beast_bestial_roar", "bestial_roar", "res://tests/skills/beast_bestial_roar_scenario.gd"),
		_entry(&"beast_raking_claws", "raking_claws", "res://tests/skills/beast_raking_claws_scenario.gd"),
		_entry(&"beast_rest_recover", "rest_recover", "res://tests/skills/beast_rest_recover_scenario.gd"),
		_entry(&"beast_intimidate", "intimidate", "res://tests/skills/beast_intimidate_scenario.gd"),
		_entry(&"beast_fetch", "fetch", "res://tests/skills/beast_fetch_scenario.gd"),
		_entry(&"beast_savage_bite", "savage_bite", "res://tests/skills/beast_savage_bite_scenario.gd"),
		_entry(&"beast_run_down", "run_down", "res://tests/skills/beast_run_down_scenario.gd"),
		_entry(&"beast_thrash", "thrash", "res://tests/skills/beast_thrash_scenario.gd"),
		_entry(&"beast_defensive_posture", "defensive_posture", "res://tests/skills/beast_defensive_posture_scenario.gd"),
		_entry(&"beast_airlift", "airlift", "res://tests/skills/beast_airlift_scenario.gd"),
		_entry(&"beast_tail_swipe", "tail_swipe", "res://tests/skills/beast_tail_swipe_scenario.gd"),
		_entry(&"beast_meteor_drop", "meteor_drop", "res://tests/skills/beast_meteor_drop_scenario.gd"),
		_entry(&"gallop", "gallop", "res://tests/passives/gallop_scenario.gd"),
		_entry(&"isolation_tactics", "isolation_tactics", "res://tests/passives/isolation_tactics_scenario.gd"),
		_entry(&"terminal_velocity", "terminal_velocity", "res://tests/passives/terminal_velocity_scenario.gd"),
		_entry(&"snatch_and_grab", "snatch_and_grab", "res://tests/passives/snatch_and_grab_scenario.gd"),
		_entry(&"safe_landing", "safe_landing", "res://tests/passives/safe_landing_scenario.gd"),
		_entry(&"aerial_superiority", "aerial_superiority", "res://tests/passives/aerial_superiority_scenario.gd"),
		_entry(&"mount_resilience", "mount_resilience", "res://tests/passives/mount_resilience_scenario.gd"),
		_entry(&"beasts_instinct", "beasts_instinct", "res://tests/passives/beasts_instinct_scenario.gd"),
		_entry(&"territorial", "territorial", "res://tests/passives/territorial_scenario.gd"),
		_entry(&"intimidating_presence", "intimidating_presence", "res://tests/passives/intimidating_presence_scenario.gd"),
		_entry(&"dive_bomber", "dive_bomber", "res://tests/passives/dive_bomber_scenario.gd"),
		_entry(&"pack_hunter", "pack_hunter", "res://tests/passives/pack_hunter_scenario.gd"),
		_entry(&"blood_scent", "blood_scent", "res://tests/passives/beast_blood_scent_scenario.gd"),
		_entry(&"vantage_striker", "vantage_striker", "res://tests/passives/vantage_striker_scenario.gd"),
		_entry(&"predatory_drive", "predatory_drive", "res://tests/passives/predatory_drive_scenario.gd"),
		_entry(&"furious_charge", "furious_charge", "res://tests/passives/furious_charge_scenario.gd"),
	]


static func run_scenario(script_path: String, failures: Array[String]) -> bool:
	if not ResourceLoader.exists(script_path):
		return false
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		return false
	script.call("run_all", failures)
	return true


static func _entry(factory_id: StringName, name: String, script_path: String) -> Dictionary:
	return {"factory_id": factory_id, "name": name, "script_path": script_path}
