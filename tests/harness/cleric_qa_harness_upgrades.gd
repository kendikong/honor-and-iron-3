class_name ClericQaHarnessUpgrades
extends RefCounted

const Harness := preload("res://tests/cleric_qa_harness.gd")


static func run_upgrade_for(row_name: String, failures: Array[String]) -> void:
	Harness.run_upgrade_sim_for(StringName("cleric_%s" % row_name), failures)
