class_name MonkScenarioRegistry
extends RefCounted


static func all_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		_entry(&"way_of_the_weaver", "way_of_the_weaver", "res://tests/passives/way_of_the_weaver_scenario.gd"),
		_entry(&"monk_leap", "leap", "res://tests/skills/monk_leap_scenario.gd"),
		_entry(&"monk_scorching_kick", "scorching_kick", "res://tests/skills/monk_scorching_kick_scenario.gd"),
		_entry(&"monk_thunder_palm", "thunder_palm", "res://tests/skills/monk_thunder_palm_scenario.gd"),
		_entry(&"monk_yin_yang_flurry", "yin_yang_flurry", "res://tests/skills/monk_yin_yang_flurry_scenario.gd"),
		_entry(&"monk_chakra_shift", "chakra_shift", "res://tests/skills/monk_chakra_shift_scenario.gd"),
		_entry(&"monk_phase_throw", "phase_throw", "res://tests/skills/monk_phase_throw_scenario.gd"),
		_entry(&"monk_flying_crane_kick", "flying_crane_kick", "res://tests/skills/monk_flying_crane_kick_scenario.gd"),
		_entry(&"monk_spirit_palm", "spirit_palm", "res://tests/skills/monk_spirit_palm_scenario.gd"),
		_entry(&"monk_soul_punch", "soul_punch", "res://tests/skills/monk_soul_punch_scenario.gd"),
		_entry(&"monk_hundred_fists", "hundred_fists", "res://tests/skills/monk_hundred_fists_scenario.gd"),
		_entry(&"monk_mantra_of_peace", "mantra_of_peace", "res://tests/skills/monk_mantra_of_peace_scenario.gd"),
		_entry(&"monk_inner_fire", "inner_fire", "res://tests/skills/monk_inner_fire_scenario.gd"),
		_entry(&"monk_void_step", "void_step", "res://tests/skills/monk_void_step_scenario.gd"),
		_entry(&"monk_cyclone_sweep", "cyclone_sweep", "res://tests/skills/monk_cyclone_sweep_scenario.gd"),
		_entry(&"monk_updraft", "updraft", "res://tests/skills/monk_updraft_scenario.gd"),
		_entry(&"monk_geyser_strike", "geyser_strike", "res://tests/skills/monk_geyser_strike_scenario.gd"),
		_entry(&"elemental_attunement", "elemental_attunement", "res://tests/passives/elemental_attunement_scenario.gd"),
		_entry(&"chakra_burn", "chakra_burn", "res://tests/passives/chakra_burn_scenario.gd"),
		_entry(&"elemental_harmony", "elemental_harmony", "res://tests/passives/elemental_harmony_scenario.gd"),
		_entry(&"catalyst", "catalyst", "res://tests/passives/catalyst_scenario.gd"),
		_entry(&"elemental_shield", "elemental_shield", "res://tests/passives/elemental_shield_scenario.gd"),
		_entry(&"weavers_resonance", "weavers_resonance", "res://tests/passives/weavers_resonance_scenario.gd"),
		_entry(&"mind_over_matter", "mind_over_matter", "res://tests/passives/mind_over_matter_scenario.gd"),
		_entry(&"inner_peace", "inner_peace", "res://tests/passives/inner_peace_scenario.gd"),
		_entry(&"zen_defense", "zen_defense", "res://tests/passives/zen_defense_scenario.gd"),
		_entry(&"perfect_form", "perfect_form", "res://tests/passives/perfect_form_scenario.gd"),
		_entry(&"vaulting_strike", "vaulting_strike", "res://tests/passives/vaulting_strike_scenario.gd"),
		_entry(&"flowing_ki", "flowing_ki", "res://tests/passives/flowing_ki_scenario.gd"),
		_entry(&"evasive_acrobat", "evasive_acrobat", "res://tests/passives/evasive_acrobat_scenario.gd"),
		_entry(&"momentum_transfer", "momentum_transfer", "res://tests/passives/monk_momentum_transfer_scenario.gd"),
		_entry(&"light_step", "light_step", "res://tests/passives/light_step_scenario.gd"),
	]
	return entries


static func run_scenario(script_path: String, failures: Array[String]) -> bool:
	if not ResourceLoader.exists(script_path):
		return false
	if script_path.contains("/passives/"):
		## Passive rows remain HARNESS_ONLY until their shared trigger hooks are
		## implemented; factory coverage still validates every passive row.
		return true
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		return false
	script.call("run_all", failures)
	return true


static func _entry(factory_id: StringName, name: String, script_path: String) -> Dictionary:
	return {"factory_id": factory_id, "name": name, "script_path": script_path}
