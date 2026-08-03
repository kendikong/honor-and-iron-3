class_name KnightScenarioRegistry
extends RefCounted

## Authoritative Knight factory-id → scenario runner map (P3 — not planning QA).
## Uses runtime load() + script.call to avoid Callable(static) invalidity in headless --script.


static func all_entries() -> Array[Dictionary]:
	return [
		_entry(&"knight_swap", "knight_swap", "res://tests/skills/knight_swap_scenario.gd"),
		_entry(&"knight_shield_bash", "shield_bash", "res://tests/skills/shield_bash_scenario.gd"),
		_entry(&"knight_phalanx_stance", "phalanx_stance", "res://tests/skills/phalanx_stance_scenario.gd"),
		_entry(&"knight_taunting_strike", "taunting_strike", "res://tests/skills/taunting_strike_scenario.gd"),
		_entry(&"knight_seismic_stomp", "seismic_stomp", "res://tests/skills/seismic_stomp_scenario.gd"),
		_entry(&"knight_fortify", "fortify", "res://tests/skills/fortify_scenario.gd"),
		_entry(&"knight_bowling_charge", "bowling_charge", "res://tests/skills/bowling_charge_scenario.gd"),
		_entry(&"knight_iron_grip", "iron_grip", "res://tests/skills/iron_grip_scenario.gd"),
		_entry(&"knight_redirect_strike", "redirect_strike", "res://tests/skills/redirect_strike_scenario.gd"),
		_entry(&"knight_indomitable_will", "indomitable_will", "res://tests/skills/indomitable_will_scenario.gd"),
		_entry(&"knight_retaliation_protocol", "retaliation_protocol", "res://tests/skills/retaliation_protocol_scenario.gd"),
		_entry(&"knight_shield_slam", "shield_slam", "res://tests/skills/shield_slam_scenario.gd"),
		_entry(&"knight_defensive_formation", "defensive_formation", "res://tests/skills/defensive_formation_scenario.gd"),
		_entry(&"knight_chain_hook", "chain_hook", "res://tests/skills/chain_hook_scenario.gd"),
		_entry(&"knight_trampling_advance", "trampling_advance", "res://tests/skills/trampling_advance_scenario.gd"),
		_entry(&"collision_retaliator", "collision_retaliator", "res://tests/passives/collision_retaliator_scenario.gd"),
		_entry(&"thorny_carapace", "thorny_carapace", "res://tests/passives/thorny_carapace_scenario.gd"),
		_entry(&"concussive_shatter", "concussive_shatter", "res://tests/passives/concussive_shatter_scenario.gd"),
		_entry(&"kinetic_momentum", "kinetic_momentum", "res://tests/passives/kinetic_momentum_scenario.gd"),
		_entry(&"stand_ground", "stand_ground", "res://tests/passives/stand_ground_scenario.gd"),
		_entry(&"indestructible_bastion", "indestructible_bastion", "res://tests/passives/indestructible_bastion_scenario.gd"),
		_entry(&"shield_mastery", "shield_mastery", "res://tests/passives/shield_mastery_scenario.gd"),
		_entry(&"kinetic_armor", "kinetic_armor", "res://tests/passives/kinetic_armor_scenario.gd"),
		_entry(&"kinetic_converter", "kinetic_converter", "res://tests/passives/kinetic_converter_scenario.gd"),
		_entry(&"kinetic_redirection", "kinetic_redirection", "res://tests/passives/kinetic_redirection_scenario.gd"),
		_entry(&"bulwark", "bulwark", "res://tests/passives/bulwark_scenario.gd"),
		_entry(&"living_barricade", "living_barricade", "res://tests/passives/living_barricade_scenario.gd"),
		_entry(&"shield_wall", "shield_wall", "res://tests/passives/shield_wall_scenario.gd"),
		_entry(&"rallying_presence", "rallying_presence", "res://tests/passives/rallying_presence_scenario.gd"),
		_entry(&"intercept_tactics", "intercept_tactics", "res://tests/passives/intercept_tactics_scenario.gd"),
	]


static func economy_entry() -> Dictionary:
	return {
		"factory_id": &"run_economy",
		"name": "run_economy",
		"script_path": "res://tests/skills/run_economy_scenario.gd",
	}


static func run_scenario(script_path: String, failures: Array[String]) -> bool:
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		return false
	script.call("run_all", failures)
	return true


static func _entry(factory_id: StringName, name: String, script_path: String) -> Dictionary:
	return {"factory_id": factory_id, "name": name, "script_path": script_path}
