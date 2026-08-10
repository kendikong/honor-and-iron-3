class_name LancerScenarioRegistry
extends RefCounted

## One authoritative entry per Lancer Bible row.
const SCENARIO_PATH := "res://tests/lancer_class_scenario.gd"

static func all_entries() -> Array[Dictionary]:
	return [
		_entry(&"lancer_push", "push", "res://tests/skills/lancer_push_scenario.gd"),
		_entry(&"lancer_piercing_charge", "piercing_charge", "res://tests/skills/lancer_piercing_charge_scenario.gd"),
		_entry(&"lancer_sweeping_halberd", "sweeping_halberd", "res://tests/skills/lancer_sweeping_halberd_scenario.gd"),
		_entry(&"lancer_vaulting_leap", "vaulting_leap", "res://tests/skills/lancer_vaulting_leap_scenario.gd"),
		_entry(&"lancer_run_down", "run_down", "res://tests/skills/lancer_run_down_scenario.gd"),
		_entry(&"lancer_rallying_cry", "rallying_cry", "res://tests/skills/lancer_rallying_cry_scenario.gd"),
		_entry(&"lancer_flanking_maneuver", "flanking_maneuver", "res://tests/skills/lancer_flanking_maneuver_scenario.gd"),
		_entry(&"lancer_brace", "brace", "res://tests/skills/lancer_brace_scenario.gd"),
		_entry(&"lancer_harpoon_toss", "harpoon_toss", "res://tests/skills/lancer_harpoon_toss_scenario.gd"),
		_entry(&"lancer_glorious_charge", "glorious_charge", "res://tests/skills/lancer_glorious_charge_scenario.gd"),
		_entry(&"lancer_pole_vault", "pole_vault", "res://tests/skills/lancer_pole_vault_scenario.gd"),
		_entry(&"lancer_line_breaker", "line_breaker", "res://tests/skills/lancer_line_breaker_scenario.gd"),
		_entry(&"lancer_spear_wall", "spear_wall", "res://tests/skills/lancer_spear_wall_scenario.gd"),
		_entry(&"lancer_meteor_drop", "meteor_drop", "res://tests/skills/lancer_meteor_drop_scenario.gd"),
		_entry(&"kinetic_charge", "kinetic_charge", "res://tests/passives/lancer_kinetic_charge_scenario.gd"),
		_entry(&"unstoppable_mass", "unstoppable_mass", "res://tests/passives/lancer_unstoppable_mass_scenario.gd"),
		_entry(&"canto", "canto", "res://tests/passives/lancer_canto_scenario.gd"),
		_entry(&"frontline_defense", "frontline_defense", "res://tests/passives/lancer_frontline_defense_scenario.gd"),
		_entry(&"flanking_strike", "flanking_strike", "res://tests/passives/lancer_flanking_strike_scenario.gd"),
		_entry(&"plunging_attack", "plunging_attack", "res://tests/passives/lancer_plunging_attack_scenario.gd"),
		_entry(&"crashing_impact", "crashing_impact", "res://tests/passives/lancer_crashing_impact_scenario.gd"),
		_entry(&"pole_plant", "pole_plant", "res://tests/passives/lancer_pole_plant_scenario.gd"),
		_entry(&"spear_drop", "spear_drop", "res://tests/passives/lancer_spear_drop_scenario.gd"),
		_entry(&"springboard", "springboard", "res://tests/passives/lancer_springboard_scenario.gd"),
		_entry(&"sweet_spot", "sweet_spot", "res://tests/passives/lancer_sweet_spot_scenario.gd"),
		_entry(&"reach_advantage", "reach_advantage", "res://tests/passives/lancer_reach_advantage_scenario.gd"),
		_entry(&"disengage", "disengage", "res://tests/passives/lancer_disengage_scenario.gd"),
		_entry(&"zone_of_control", "zone_of_control", "res://tests/passives/lancer_zone_of_control_scenario.gd"),
		_entry(&"leverage", "leverage", "res://tests/passives/lancer_leverage_scenario.gd"),
	]

static func run_scenario(script_path: String, failures: Array[String]) -> bool:
	if not ResourceLoader.exists(script_path):
		print("[LANCER_QA] SKIP (PLANNED): %s" % script_path)
		return true
	var script := load(script_path) as GDScript
	if script == null:
		return false
	script.call("run_all", failures)
	return true

static func _entry(factory_id: StringName, name: String, script_path: String) -> Dictionary:
	return {"factory_id": factory_id, "name": name, "script_path": script_path, "source_path": script_path}

