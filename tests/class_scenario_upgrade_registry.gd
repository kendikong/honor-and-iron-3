class_name ClassScenarioUpgradeRegistry
extends RefCounted

## Dispatches `[+]` sim tier to per-class upgrade harnesses (CLASS_QA_BIBLE.md §3 Layer B).

const _BruiserUpgrades := preload("res://tests/bruiser_qa_harness_upgrades.gd")
const _ArcherUpgrades := preload("res://tests/archer_qa_harness_upgrades.gd")
const _LancerUpgrades := preload("res://tests/lancer_qa_harness_upgrades.gd")
const _MageHarness := preload("res://tests/mage_qa_harness.gd")
const _ClericUpgrades := preload("res://tests/cleric_qa_harness_upgrades.gd")
const _AoeHarness := preload("res://tests/aoe_footprint_qa_harness.gd")


static func run_for_factory(failures: Array[String], factory_id: StringName) -> void:
	var ability: AbilityData = _AoeHarness.find_ability_by_id(factory_id)
	if ability == null:
		return
	if ability.upgraded_effects.is_empty() and ability.upgraded_description.is_empty():
		return
	var class_id: String = String(factory_id).split("_")[0]
	var row_name: String = String(factory_id).substr(class_id.length() + 1)
	match class_id:
		"bruiser":
			_BruiserUpgrades.run_upgrade_for(row_name, failures)
		"archer":
			_ArcherUpgrades.run_upgrade_for(row_name, failures)
		"lancer":
			_LancerUpgrades.run_upgrade_for(row_name, failures)
		"mage":
			_MageHarness.run_upgrade_sim_for(factory_id, failures)
		"cleric":
			_ClericUpgrades.run_upgrade_for(row_name, failures)
		_:
			pass
