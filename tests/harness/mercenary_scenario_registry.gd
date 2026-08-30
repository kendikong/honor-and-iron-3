class_name MercenaryScenarioRegistry
extends RefCounted


const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")


static func all_entries() -> Array[Dictionary]:
	return [
		_entry(&"predatory_momentum", "predatory_momentum", "res://tests/passives/predatory_momentum_scenario.gd"),
		_entry(&"mercenary_pullback", "pullback", "res://tests/skills/mercenary_pullback_scenario.gd"),
		_entry(&"mercenary_swift_strike", "swift_strike", "res://tests/skills/mercenary_swift_strike_scenario.gd"),
		_entry(&"mercenary_defense_strike", "defense_strike", "res://tests/skills/mercenary_defense_strike_scenario.gd"),
		_entry(&"mercenary_blade_storm", "blade_storm", "res://tests/skills/mercenary_blade_storm_scenario.gd"),
		_entry(&"mercenary_caltrop_toss", "caltrop_toss", "res://tests/skills/mercenary_caltrop_toss_scenario.gd"),
		_entry(&"mercenary_feint", "feint", "res://tests/skills/mercenary_feint_scenario.gd"),
		_entry(&"mercenary_riposte_strike", "riposte_strike", "res://tests/skills/mercenary_riposte_strike_scenario.gd"),
		_entry(&"mercenary_sever", "sever", "res://tests/skills/mercenary_sever_scenario.gd"),
		_entry(&"mercenary_second_wind", "second_wind", "res://tests/skills/mercenary_second_wind_scenario.gd"),
		_entry(&"mercenary_tactical_retreat", "tactical_retreat", "res://tests/skills/mercenary_tactical_retreat_scenario.gd"),
		_entry(&"mercenary_executioners_blade", "executioners_blade", "res://tests/skills/mercenary_executioners_blade_scenario.gd"),
		_entry(&"mercenary_precision_strike", "precision_strike", "res://tests/skills/mercenary_precision_strike_scenario.gd"),
		_entry(&"mercenary_flank_and_run", "flank_and_run", "res://tests/skills/mercenary_flank_and_run_scenario.gd"),
		_entry(&"mercenary_hamstring", "hamstring", "res://tests/skills/mercenary_hamstring_scenario.gd"),
		_entry(&"mercenary_acrobatic_vault", "acrobatic_vault", "res://tests/skills/mercenary_acrobatic_vault_scenario.gd"),
		_entry(&"mercenary_duelists_challenge", "duelists_challenge", "res://tests/skills/mercenary_duelists_challenge_scenario.gd"),
		_entry(&"calculated_strike", "calculated_strike", "res://tests/passives/calculated_strike_scenario.gd"),
		_entry(&"weapon_master", "weapon_master", "res://tests/passives/weapon_master_scenario.gd"),
		_entry(&"dual_wield_momentum", "dual_wield_momentum", "res://tests/passives/dual_wield_momentum_scenario.gd"),
		_entry(&"precision_edge", "precision_edge", "res://tests/passives/precision_edge_scenario.gd"),
		_entry(&"duelists_focus", "duelists_focus", "res://tests/passives/duelists_focus_scenario.gd"),
		_entry(&"tactical_versatility", "tactical_versatility", "res://tests/passives/tactical_versatility_scenario.gd"),
		_entry(&"swift_feet", "swift_feet", "res://tests/passives/swift_feet_scenario.gd"),
		_entry(&"hit_and_run", "hit_and_run", "res://tests/passives/hit_and_run_scenario.gd"),
		_entry(&"evasive", "evasive", "res://tests/passives/evasive_scenario.gd"),
		_entry(&"flanking_maneuver", "flanking_maneuver", "res://tests/passives/flanking_maneuver_scenario.gd"),
		_entry(&"dirty_fighting", "dirty_fighting", "res://tests/passives/dirty_fighting_scenario.gd"),
		_entry(&"executioner", "executioner", "res://tests/passives/executioner_scenario.gd"),
		_entry(&"blood_scent", "blood_scent", "res://tests/passives/blood_scent_scenario.gd"),
		_entry(&"ruthless", "ruthless", "res://tests/passives/ruthless_scenario.gd"),
		_entry(&"coup_de_grace", "coup_de_grace", "res://tests/passives/coup_de_grace_scenario.gd"),
	]


static func run_scenario(
	factory_id: StringName,
	script_path: String,
	failures: Array[String],
) -> bool:
	if not ResourceLoader.exists(script_path):
		return false
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		return false
	script.call("run_all", failures)
	_Upgrades.run_for_factory(failures, factory_id)
	_Planning.run_for_factory(failures, factory_id)
	return true


static func _entry(factory_id: StringName, name: String, script_path: String) -> Dictionary:
	return {"factory_id": factory_id, "name": name, "script_path": script_path}
