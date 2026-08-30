class_name RogueScenarioRegistry
extends RefCounted


static func all_entries() -> Array[Dictionary]:
	return [
		_entry(&"pass", "pass", "res://tests/passives/pass_scenario.gd"),
		_entry(&"rogue_slip_past", "slip_past", "res://tests/skills/rogue_slip_past_scenario.gd"),
		_entry(&"rogue_shadow_step", "shadow_step", "res://tests/skills/rogue_shadow_step_scenario.gd"),
		_entry(&"rogue_kidney_strike", "kidney_strike", "res://tests/skills/rogue_kidney_strike_scenario.gd"),
		_entry(&"rogue_smoke_bomb", "smoke_bomb", "res://tests/skills/rogue_smoke_bomb_scenario.gd"),
		_entry(&"rogue_evasive_strike", "evasive_strike", "res://tests/skills/rogue_evasive_strike_scenario.gd"),
		_entry(&"rogue_grappling_hook", "grappling_hook", "res://tests/skills/rogue_grappling_hook_scenario.gd"),
		_entry(&"rogue_switcheroo", "switcheroo", "res://tests/skills/rogue_switcheroo_scenario.gd"),
		_entry(&"rogue_blindside", "blindside", "res://tests/skills/rogue_blindside_scenario.gd"),
		_entry(&"rogue_throat_slit", "throat_slit", "res://tests/skills/rogue_throat_slit_scenario.gd"),
		_entry(&"rogue_amnesia_dust", "amnesia_dust", "res://tests/skills/rogue_amnesia_dust_scenario.gd"),
		_entry(&"rogue_death_mark", "death_mark", "res://tests/skills/rogue_death_mark_scenario.gd"),
		_entry(&"rogue_lethal_flourish", "lethal_flourish", "res://tests/skills/rogue_lethal_flourish_scenario.gd"),
		_entry(&"rogue_shadow_swap", "shadow_swap", "res://tests/skills/rogue_shadow_swap_scenario.gd"),
		_entry(&"rogue_kidnap", "kidnap", "res://tests/skills/rogue_kidnap_scenario.gd"),
		_entry(&"rogue_shuriken_volley", "shuriken_volley", "res://tests/skills/rogue_shuriken_volley_scenario.gd"),
		_entry(&"rogue_poison_flask", "poison_flask", "res://tests/skills/rogue_poison_flask_scenario.gd"),
		_entry(&"backstab", "backstab", "res://tests/passives/backstab_scenario.gd"),
		_entry(&"blink_mastery", "blink_mastery", "res://tests/passives/blink_mastery_scenario.gd"),
		_entry(&"lethal_position", "lethal_position", "res://tests/passives/lethal_position_scenario.gd"),
		_entry(&"shadow_strike", "shadow_strike", "res://tests/passives/shadow_strike_scenario.gd"),
		_entry(&"killing_intent", "killing_intent", "res://tests/passives/killing_intent_scenario.gd"),
		_entry(&"shadow_clone", "shadow_clone", "res://tests/passives/shadow_clone_scenario.gd"),
		_entry(&"phase_shift", "phase_shift", "res://tests/passives/phase_shift_scenario.gd"),
		_entry(&"blink_strike", "blink_strike", "res://tests/passives/blink_strike_scenario.gd"),
		_entry(&"shadow_meld", "shadow_meld", "res://tests/passives/shadow_meld_scenario.gd"),
		_entry(&"shadow_slip", "shadow_slip", "res://tests/passives/shadow_slip_scenario.gd"),
		_entry(&"miasma_spreader", "miasma_spreader", "res://tests/passives/miasma_spreader_scenario.gd"),
		_entry(&"panic_cascade", "panic_cascade", "res://tests/passives/panic_cascade_scenario.gd"),
		_entry(&"debuff_overload", "debuff_overload", "res://tests/passives/debuff_overload_scenario.gd"),
		_entry(&"mind_static", "mind_static", "res://tests/passives/mind_static_scenario.gd"),
		_entry(&"board_scrambler", "board_scrambler", "res://tests/passives/board_scrambler_scenario.gd"),
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
