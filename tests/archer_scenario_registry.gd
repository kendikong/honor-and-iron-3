class_name ArcherScenarioRegistry
extends RefCounted

const SCENARIO_PATH := "res://tests/archer_class_scenario.gd"

static func all_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for skill_id: StringName in [
		&"archer_power_shot", &"archer_volley", &"archer_pinning_arrow",
		&"archer_piercing_shot", &"archer_toxic_spore_arrow", &"archer_grapple_arrow",
		&"archer_explosive_arrow", &"archer_hunters_mark", &"archer_repelling_shot",
		&"archer_bear_trap", &"archer_suppressing_fire", &"archer_caltrop_trap",
		&"archer_parting_shot", &"archer_scouts_eye",
	]:
		entries.append(_entry(skill_id, "skill"))
	for passive_id: StringName in [
		&"lightfoot", &"overwatch", &"high_ground", &"patient_hunter", &"true_sight",
		&"piercing_momentum", &"camouflage", &"area_denial", &"caltrop_expert",
		&"zone_control", &"sticky_mud", &"fletching_hoarder", &"prey_sighted",
		&"barrage", &"target_painter", &"rapid_fire",
	]:
		entries.append(_entry(passive_id, "passive"))
	return entries


static func run_scenario(script_path: String, failures: Array[String]) -> bool:
	if not ResourceLoader.exists(script_path):
		return false
	var script := load(script_path) as GDScript
	if script == null:
		return false
	script.call("run_all", failures)
	return true


static func _entry(factory_id: StringName, category: String) -> Dictionary:
	return {
		"factory_id": factory_id,
		"name": "%s/%s" % [category, factory_id],
		"script_path": SCENARIO_PATH,
	}
