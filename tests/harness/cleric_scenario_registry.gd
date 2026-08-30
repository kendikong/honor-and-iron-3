class_name ClericScenarioRegistry
extends RefCounted


static func all_entries() -> Array[Dictionary]:
	return [
		_entry(&"selfless_siphon", "selfless_siphon", "res://tests/passives/selfless_siphon_scenario.gd"),
		_entry(&"cleric_guardian_step", "guardian_step", "res://tests/skills/cleric_guardian_step_scenario.gd"),
		_entry(&"cleric_holy_light", "holy_light", "res://tests/skills/cleric_holy_light_scenario.gd"),
		_entry(&"cleric_smite", "smite", "res://tests/skills/cleric_smite_scenario.gd"),
		_entry(&"cleric_cleansing_aura", "cleansing_aura", "res://tests/skills/cleric_cleansing_aura_scenario.gd"),
		_entry(&"cleric_sanctuary", "sanctuary", "res://tests/skills/cleric_sanctuary_scenario.gd"),
		_entry(&"cleric_blinding_ray", "blinding_ray", "res://tests/skills/cleric_blinding_ray_scenario.gd"),
		_entry(&"cleric_divine_hammer", "divine_hammer", "res://tests/skills/cleric_divine_hammer_scenario.gd"),
		_entry(&"cleric_life_link", "life_link", "res://tests/skills/cleric_life_link_scenario.gd"),
		_entry(&"cleric_prayer_of_fortitude", "prayer_of_fortitude", "res://tests/skills/cleric_prayer_of_fortitude_scenario.gd"),
		_entry(&"cleric_resurrection", "resurrection", "res://tests/skills/cleric_resurrection_scenario.gd"),
		_entry(&"cleric_consecrate_ground", "consecrate_ground", "res://tests/skills/cleric_consecrate_ground_scenario.gd"),
		_entry(&"cleric_holy_wrath", "holy_wrath", "res://tests/skills/cleric_holy_wrath_scenario.gd"),
		_entry(&"cleric_divine_guidance", "divine_guidance", "res://tests/skills/cleric_divine_guidance_scenario.gd"),
		_entry(&"cleric_shield_of_faith", "shield_of_faith", "res://tests/skills/cleric_shield_of_faith_scenario.gd"),
		_entry(&"cleric_martyrs_chains", "martyrs_chains", "res://tests/skills/cleric_martyrs_chains_scenario.gd"),
		_entry(&"blood_donation", "blood_donation", "res://tests/passives/blood_donation_scenario.gd"),
		_entry(&"sacred_shield", "sacred_shield", "res://tests/passives/sacred_shield_scenario.gd"),
		_entry(&"divine_blessing", "divine_blessing", "res://tests/passives/divine_blessing_scenario.gd"),
		_entry(&"frontline_medic", "frontline_medic", "res://tests/passives/frontline_medic_scenario.gd"),
		_entry(&"armor_of_faith", "armor_of_faith", "res://tests/passives/armor_of_faith_scenario.gd"),
		_entry(&"divine_overflow", "divine_overflow", "res://tests/passives/divine_overflow_scenario.gd"),
		_entry(&"divine_intervention", "divine_intervention", "res://tests/passives/divine_intervention_scenario.gd"),
		_entry(&"holy_ground", "holy_ground", "res://tests/passives/holy_ground_scenario.gd"),
		_entry(&"prayer", "prayer", "res://tests/passives/prayer_scenario.gd"),
		_entry(&"purity", "purity", "res://tests/passives/purity_scenario.gd"),
		_entry(&"martyrs_blood", "martyrs_blood", "res://tests/passives/martyrs_blood_scenario.gd"),
		_entry(&"divine_retribution", "divine_retribution", "res://tests/passives/divine_retribution_scenario.gd"),
		_entry(&"holy_radiance", "holy_radiance", "res://tests/passives/holy_radiance_scenario.gd"),
		_entry(&"retribution", "retribution", "res://tests/passives/retribution_scenario.gd"),
		_entry(&"zealous_protection", "zealous_protection", "res://tests/passives/zealous_protection_scenario.gd"),
	]


static func run_scenario(script_path: String, failures: Array[String]) -> bool:
	if not ResourceLoader.exists(script_path):
		print("[CLERIC_QA] SKIP (PLANNED): %s" % script_path)
		return true
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		return false
	script.call("run_all", failures)
	return true


static func _entry(factory_id: StringName, name: String, script_path: String) -> Dictionary:
	return {"factory_id": factory_id, "name": name, "script_path": script_path}
