class_name BruiserScenarioRegistry
extends RefCounted

## Authoritative Bruiser factory-id → scenario runner map (P6 — not planning QA).


static func all_entries() -> Array[Dictionary]:
	return [
		_entry(&"bruiser_push_through", "push_through", "res://tests/skills/bruiser_push_through_scenario.gd"),
		_entry(&"bruiser_charge_strike", "charge_strike", "res://tests/skills/bruiser_charge_strike_scenario.gd"),
		_entry(&"bruiser_concussion_blow", "concussion_blow", "res://tests/skills/bruiser_concussion_blow_scenario.gd"),
		_entry(&"bruiser_cleave", "cleave", "res://tests/skills/bruiser_cleave_scenario.gd"),
		_entry(&"bruiser_suplex", "suplex", "res://tests/skills/bruiser_suplex_scenario.gd"),
		_entry(&"bruiser_adrenaline_surge", "adrenaline_surge", "res://tests/skills/bruiser_adrenaline_surge_scenario.gd"),
		_entry(&"bruiser_earthshatter", "earthshatter", "res://tests/skills/bruiser_earthshatter_scenario.gd"),
		_entry(&"bruiser_meat_shield", "meat_shield", "res://tests/skills/bruiser_meat_shield_scenario.gd"),
		_entry(&"bruiser_frenzy", "frenzy", "res://tests/skills/bruiser_frenzy_scenario.gd"),
		_entry(&"bruiser_guttural_roar", "guttural_roar", "res://tests/skills/bruiser_guttural_roar_scenario.gd"),
		_entry(&"bruiser_headbutt", "headbutt", "res://tests/skills/bruiser_headbutt_scenario.gd"),
		_entry(&"bruiser_blood_boil", "blood_boil", "res://tests/skills/bruiser_blood_boil_scenario.gd"),
		_entry(&"bruiser_violent_collision", "violent_collision", "res://tests/skills/bruiser_violent_collision_scenario.gd"),
		_entry(&"bruiser_crimson_whirlwind", "crimson_whirlwind", "res://tests/skills/bruiser_crimson_whirlwind_scenario.gd"),
		_entry(&"bruiser_belly_flop", "belly_flop", "res://tests/skills/bruiser_belly_flop_scenario.gd"),
		_entry(&"bruiser_breaching_dash", "breaching_dash", "res://tests/skills/bruiser_breaching_dash_scenario.gd"),
		_entry(&"cellular_regeneration", "cellular_regeneration", "res://tests/passives/cellular_regeneration_scenario.gd"),
		_entry(&"blood_for_blood", "blood_for_blood", "res://tests/passives/blood_for_blood_scenario.gd"),
		_entry(&"adrenaline_junkie", "adrenaline_junkie", "res://tests/passives/adrenaline_junkie_scenario.gd"),
		_entry(&"enraged", "enraged", "res://tests/passives/enraged_scenario.gd"),
		_entry(&"last_stand", "last_stand", "res://tests/passives/last_stand_scenario.gd"),
		_entry(&"colossal_mass", "colossal_mass", "res://tests/passives/colossal_mass_scenario.gd"),
		_entry(&"overwhelming_bulk", "overwhelming_bulk", "res://tests/passives/overwhelming_bulk_scenario.gd"),
		_entry(&"thrill_of_pain", "thrill_of_pain", "res://tests/passives/thrill_of_pain_scenario.gd"),
		_entry(&"momentum_of_titan", "momentum_of_titan", "res://tests/passives/momentum_of_titan_scenario.gd"),
		_entry(&"scar_tissue", "scar_tissue", "res://tests/passives/scar_tissue_scenario.gd"),
		_entry(&"momentum_transfer", "momentum_transfer", "res://tests/passives/momentum_transfer_scenario.gd"),
		_entry(&"crowd_breaker", "crowd_breaker", "res://tests/passives/crowd_breaker_scenario.gd"),
		_entry(&"juggernaut", "juggernaut", "res://tests/passives/juggernaut_scenario.gd"),
		_entry(&"battering_ram", "battering_ram", "res://tests/passives/battering_ram_scenario.gd"),
		_entry(&"unstoppable_force", "unstoppable_force", "res://tests/passives/unstoppable_force_scenario.gd"),
		_entry(&"reactive_adrenaline", "reactive_adrenaline", "res://tests/passives/reactive_adrenaline_scenario.gd"),
	]


static func run_scenario(script_path: String, failures: Array[String]) -> bool:
	if not ResourceLoader.exists(script_path):
		print("[BRUISER_QA] SKIP (PLANNED): %s" % script_path)
		return true
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		return false
	script.call("run_all", failures)
	return true


static func _entry(factory_id: StringName, name: String, script_path: String) -> Dictionary:
	return {"factory_id": factory_id, "name": name, "script_path": script_path}
