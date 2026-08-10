class_name FletchingHoarderScenarioTest
extends RefCounted

const _Passives := preload("res://tests/archer_qa_harness_passives.gd")


static func run_all(failures: Array[String]) -> void:
	_Passives.run_fletching_hoarder(failures)
