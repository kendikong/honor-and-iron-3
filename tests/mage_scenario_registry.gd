class_name MageScenarioRegistry
extends RefCounted


static func all_entries() -> Array[Dictionary]:
	return [
		_entry(&"arcane_overchannel", "arcane_overchannel", "res://tests/passives/arcane_overchannel_scenario.gd"),
		_entry(&"mage_blink", "blink", "res://tests/skills/mage_blink_scenario.gd"),
		_entry(&"mage_fireball", "fireball", "res://tests/skills/mage_fireball_scenario.gd"),
		_entry(&"mage_ice_shard", "ice_shard", "res://tests/skills/mage_ice_shard_scenario.gd"),
		_entry(&"mage_chain_lightning", "chain_lightning", "res://tests/skills/mage_chain_lightning_scenario.gd"),
		_entry(&"mage_arcane_push", "arcane_push", "res://tests/skills/mage_arcane_push_scenario.gd"),
		_entry(&"mage_teleport", "teleport", "res://tests/skills/mage_teleport_scenario.gd"),
		_entry(&"mage_meteor", "meteor", "res://tests/skills/mage_meteor_scenario.gd"),
		_entry(&"mage_black_hole", "black_hole", "res://tests/skills/mage_black_hole_scenario.gd"),
		_entry(&"mage_time_warp", "time_warp", "res://tests/skills/mage_time_warp_scenario.gd"),
		_entry(&"mage_mana_shield", "mana_shield", "res://tests/skills/mage_mana_shield_scenario.gd"),
		_entry(&"mage_disintegrate", "disintegrate", "res://tests/skills/mage_disintegrate_scenario.gd"),
		_entry(&"mage_gravity_well", "gravity_well", "res://tests/skills/mage_gravity_well_scenario.gd"),
		_entry(&"mage_elemental_surge", "elemental_surge", "res://tests/skills/mage_elemental_surge_scenario.gd"),
		_entry(&"mage_earth_spike", "earth_spike", "res://tests/skills/mage_earth_spike_scenario.gd"),
		_entry(&"mage_density_shift", "density_shift", "res://tests/skills/mage_density_shift_scenario.gd"),
		_entry(&"mage_arcane_barrage", "arcane_barrage", "res://tests/skills/mage_arcane_barrage_scenario.gd"),
		_entry(&"elementalist", "elementalist", "res://tests/passives/elementalist_scenario.gd"),
		_entry(&"feedback", "feedback", "res://tests/passives/feedback_scenario.gd"),
		_entry(&"elemental_master", "elemental_master", "res://tests/passives/elemental_master_scenario.gd"),
		_entry(&"lasting_terrain", "lasting_terrain", "res://tests/passives/lasting_terrain_scenario.gd"),
		_entry(&"surface_syphoner", "surface_syphoner", "res://tests/passives/surface_syphoner_scenario.gd"),
		_entry(&"mana_leak", "mana_leak", "res://tests/passives/mana_leak_scenario.gd"),
		_entry(&"arcane_overdrive", "arcane_overdrive", "res://tests/passives/arcane_overdrive_scenario.gd"),
		_entry(&"mana_well", "mana_well", "res://tests/passives/mana_well_scenario.gd"),
		_entry(&"mana_siphon", "mana_siphon", "res://tests/passives/mana_siphon_scenario.gd"),
		_entry(&"overload", "overload", "res://tests/passives/overload_scenario.gd"),
		_entry(&"wild_magic", "wild_magic", "res://tests/passives/wild_magic_scenario.gd"),
		_entry(&"arcane_tether", "arcane_tether", "res://tests/passives/arcane_tether_scenario.gd"),
		_entry(&"arcane_mastery", "arcane_mastery", "res://tests/passives/arcane_mastery_scenario.gd"),
		_entry(&"arcane_attunement", "arcane_attunement", "res://tests/passives/arcane_attunement_scenario.gd"),
		_entry(&"gravity_anchor", "gravity_anchor", "res://tests/passives/gravity_anchor_scenario.gd"),
	]


static func run_scenario(script_path: String, failures: Array[String]) -> bool:
	if not ResourceLoader.exists(script_path):
		print("[MAGE_QA] SKIP (PLANNED): %s" % script_path)
		return true
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		return false
	script.call("run_all", failures)
	return true


static func _entry(factory_id: StringName, name: String, script_path: String) -> Dictionary:
	return {"factory_id": factory_id, "name": name, "script_path": script_path}
