class_name BloodForBloodScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_blood_for_blood(failures)

