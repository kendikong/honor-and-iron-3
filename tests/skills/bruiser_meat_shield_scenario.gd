class_name BruiserMeatShieldScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_meat_shield(failures)

