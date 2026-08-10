class_name ArcherScenarioRegistry
extends RefCounted


static func all_entries() -> Array[Dictionary]:
	return [
		_entry(&"archer_sidestep", "sidestep", "res://tests/skills/archer_sidestep_scenario.gd"),
		_entry(&"archer_power_shot", "power_shot", "res://tests/skills/archer_power_shot_scenario.gd"),
		_entry(&"archer_volley", "volley", "res://tests/skills/archer_volley_scenario.gd"),
		_entry(&"archer_pinning_arrow", "pinning_arrow", "res://tests/skills/archer_pinning_arrow_scenario.gd"),
		_entry(&"archer_piercing_shot", "piercing_shot", "res://tests/skills/archer_piercing_shot_scenario.gd"),
		_entry(&"archer_toxic_spore_arrow", "toxic_spore_arrow", "res://tests/skills/archer_toxic_spore_arrow_scenario.gd"),
		_entry(&"archer_grapple_arrow", "grapple_arrow", "res://tests/skills/archer_grapple_arrow_scenario.gd"),
		_entry(&"archer_explosive_arrow", "explosive_arrow", "res://tests/skills/archer_explosive_arrow_scenario.gd"),
		_entry(&"archer_hunters_mark", "hunters_mark", "res://tests/skills/archer_hunters_mark_scenario.gd"),
		_entry(&"archer_repelling_shot", "repelling_shot", "res://tests/skills/archer_repelling_shot_scenario.gd"),
		_entry(&"archer_bear_trap", "bear_trap", "res://tests/skills/archer_bear_trap_scenario.gd"),
		_entry(&"archer_suppressing_fire", "suppressing_fire", "res://tests/skills/archer_suppressing_fire_scenario.gd"),
		_entry(&"archer_caltrop_trap", "caltrop_trap", "res://tests/skills/archer_caltrop_trap_scenario.gd"),
		_entry(&"archer_parting_shot", "parting_shot", "res://tests/skills/archer_parting_shot_scenario.gd"),
		_entry(&"archer_scouts_eye", "scouts_eye", "res://tests/skills/archer_scouts_eye_scenario.gd"),
		_entry(&"lightfoot", "lightfoot", "res://tests/passives/lightfoot_scenario.gd"),
		_entry(&"overwatch", "overwatch", "res://tests/passives/overwatch_scenario.gd"),
		_entry(&"high_ground", "high_ground", "res://tests/passives/high_ground_scenario.gd"),
		_entry(&"patient_hunter", "patient_hunter", "res://tests/passives/patient_hunter_scenario.gd"),
		_entry(&"true_sight", "true_sight", "res://tests/passives/true_sight_scenario.gd"),
		_entry(&"piercing_momentum", "piercing_momentum", "res://tests/passives/piercing_momentum_scenario.gd"),
		_entry(&"camouflage", "camouflage", "res://tests/passives/camouflage_scenario.gd"),
		_entry(&"area_denial", "area_denial", "res://tests/passives/area_denial_scenario.gd"),
		_entry(&"caltrop_expert", "caltrop_expert", "res://tests/passives/caltrop_expert_scenario.gd"),
		_entry(&"zone_control", "zone_control", "res://tests/passives/zone_control_scenario.gd"),
		_entry(&"sticky_mud", "sticky_mud", "res://tests/passives/sticky_mud_scenario.gd"),
		_entry(&"fletching_hoarder", "fletching_hoarder", "res://tests/passives/fletching_hoarder_scenario.gd"),
		_entry(&"prey_sighted", "prey_sighted", "res://tests/passives/prey_sighted_scenario.gd"),
		_entry(&"barrage", "barrage", "res://tests/passives/barrage_scenario.gd"),
		_entry(&"target_painter", "target_painter", "res://tests/passives/target_painter_scenario.gd"),
		_entry(&"rapid_fire", "rapid_fire", "res://tests/passives/rapid_fire_scenario.gd"),
	]


static func run_scenario(script_path: String, failures: Array[String]) -> bool:
	if not ResourceLoader.exists(script_path):
		print("[ARCHER_QA] SKIP (PLANNED): %s" % script_path)
		return true
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		return false
	script.call("run_all", failures)
	return true


static func _entry(factory_id: StringName, name: String, script_path: String) -> Dictionary:
	return {"factory_id": factory_id, "name": name, "script_path": script_path}
