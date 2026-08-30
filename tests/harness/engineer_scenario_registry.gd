class_name EngineerScenarioRegistry
extends RefCounted


static func all_entries() -> Array[Dictionary]:
	return [
		_entry(&"engineer_recall", "recall", "res://tests/skills/engineer_recall_scenario.gd"),
		_entry(&"engineer_dismantle", "dismantle", "res://tests/skills/engineer_dismantle_scenario.gd"),
		_entry(&"engineer_sludge_bomb", "sludge_bomb", "res://tests/skills/engineer_sludge_bomb_scenario.gd"),
		_entry(&"engineer_construct_turret", "construct_turret", "res://tests/skills/engineer_construct_turret_scenario.gd"),
		_entry(&"engineer_frag_bomb", "frag_bomb", "res://tests/skills/engineer_frag_bomb_scenario.gd"),
		_entry(&"engineer_magnetic_mine", "magnetic_mine", "res://tests/skills/engineer_magnetic_mine_scenario.gd"),
		_entry(&"engineer_tesla_barricade", "tesla_barricade", "res://tests/skills/engineer_tesla_barricade_scenario.gd"),
		_entry(&"engineer_flak_cannon", "flak_cannon", "res://tests/skills/engineer_flak_cannon_scenario.gd"),
		_entry(&"engineer_wrench_smack", "wrench_smack", "res://tests/skills/engineer_wrench_smack_scenario.gd"),
		_entry(&"engineer_emp_grenade", "emp_grenade", "res://tests/skills/engineer_emp_grenade_scenario.gd"),
		_entry(&"engineer_rocket_launcher", "rocket_launcher", "res://tests/skills/engineer_rocket_launcher_scenario.gd"),
		_entry(&"engineer_scrap_shield", "scrap_shield", "res://tests/skills/engineer_scrap_shield_scenario.gd"),
		_entry(&"engineer_manual_detonation", "manual_detonation", "res://tests/skills/engineer_manual_detonation_scenario.gd"),
		_entry(&"engineer_overdrive_injection", "overdrive_injection", "res://tests/skills/engineer_overdrive_injection_scenario.gd"),
		_entry(&"engineer_barbed_wire", "barbed_wire", "res://tests/skills/engineer_barbed_wire_scenario.gd"),
		_entry(&"blueprint_tread", "blueprint_tread", "res://tests/passives/blueprint_tread_scenario.gd"),
		_entry(&"turret_syndrome", "turret_syndrome", "res://tests/passives/turret_syndrome_scenario.gd"),
		_entry(&"automation", "automation", "res://tests/passives/automation_scenario.gd"),
		_entry(&"master_builder", "master_builder", "res://tests/passives/master_builder_scenario.gd"),
		_entry(&"reinforced_constructs", "reinforced_constructs", "res://tests/passives/reinforced_constructs_scenario.gd"),
		_entry(&"shield_generator", "shield_generator", "res://tests/passives/shield_generator_scenario.gd"),
		_entry(&"blast_shielding", "blast_shielding", "res://tests/passives/blast_shielding_scenario.gd"),
		_entry(&"explosive_expert", "explosive_expert", "res://tests/passives/explosive_expert_scenario.gd"),
		_entry(&"chain_reaction", "chain_reaction", "res://tests/passives/engineer_chain_reaction_scenario.gd"),
		_entry(&"shrapnel", "shrapnel", "res://tests/passives/shrapnel_scenario.gd"),
		_entry(&"expanded_blast", "expanded_blast", "res://tests/passives/expanded_blast_scenario.gd"),
		_entry(&"scrap_mechanic", "scrap_mechanic", "res://tests/passives/scrap_mechanic_scenario.gd"),
		_entry(&"recycling_protocol", "recycling_protocol", "res://tests/passives/recycling_protocol_scenario.gd"),
		_entry(&"overclock", "overclock", "res://tests/passives/overclock_scenario.gd"),
		_entry(&"overclocked_maintenance", "overclocked_maintenance", "res://tests/passives/overclocked_maintenance_scenario.gd"),
		_entry(&"field_technician", "field_technician", "res://tests/passives/field_technician_scenario.gd"),
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
