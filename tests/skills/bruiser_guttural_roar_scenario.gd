class_name BruiserGutturalRoarScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_guttural_roar(failures)

