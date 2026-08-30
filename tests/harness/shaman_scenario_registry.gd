class_name ShamanScenarioRegistry
extends RefCounted


const _H := preload("res://tests/shaman_qa_harness.gd")


static func all_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	entries.append(_entry(&"hexing_presence", "hexing_presence", "res://tests/passives/hexing_presence_scenario.gd"))
	for passive_id: StringName in [
		&"echoing_spirits", &"spiritual_offering", &"spiritual_guardian",
		&"miasma_resonance", &"voodoo_conduit", &"voodoo_doll", &"spirit_link",
		&"pain_sharing", &"sympathetic_magic", &"chain_reaction", &"soul_collector",
		&"hexing_touch", &"ritual_sacrifice", &"soul_burn", &"soul_weaver",
	]:
		entries.append(_entry(
			passive_id,
			String(passive_id),
			"res://tests/passives/%s_scenario.gd" % passive_id,
		))
	for ability_id: StringName in _H.ABILITY_IDS:
		entries.append(_entry(
			ability_id,
			String(ability_id),
			"res://tests/skills/%s_scenario.gd" % ability_id,
		))
	return entries


static func run_scenario(script_path: String, failures: Array[String]) -> bool:
	if not ResourceLoader.exists(script_path):
		print("[SHAMAN_QA] SKIP (PLANNED): %s" % script_path)
		return true
	var script := load(script_path) as GDScript
	if script == null:
		return false
	script.call("run_all", failures)
	return true


static func _entry(factory_id: StringName, name: String, script_path: String) -> Dictionary:
	return {"factory_id": factory_id, "name": name, "script_path": script_path}
