class_name LancerQaHarnessUpgrades
extends RefCounted

const H := preload("res://tests/lancer_qa_harness.gd")


static func run_upgrade_for(row_name: String, failures: Array[String]) -> void:
	var ability_id: StringName = StringName("lancer_%s" % row_name)
	var ability: AbilityData = H.factory_ability(ability_id)
	if ability == null:
		return
	if ability.upgraded_modules.is_empty():
		return
	H.assert_true(
		failures, "%s/upgrade/compiled" % ability_id,
		not ability.upgraded_modules.is_empty(),
	)
	match row_name:
		"piercing_charge", "glorious_charge", "push":
			H.run_push_synergy_smoke(failures)
		"sweeping_halberd":
			H.run_sweeping_halberd_footprint(failures)
		_:
			pass
