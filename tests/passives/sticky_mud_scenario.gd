class_name StickyMudScenarioTest
extends RefCounted

const _Passives := preload("res://tests/archer_qa_harness_passives.gd")


static func run_all(failures: Array[String]) -> void:
	_sim_trigger(failures)


static func _sim_trigger(failures: Array[String]) -> void:
		_Passives.run_sticky_mud(failures)
