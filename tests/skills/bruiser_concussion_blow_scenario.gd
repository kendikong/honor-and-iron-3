class_name BruiserConcussionBlowScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_concussion_blow(failures)
	_Scenarios.run_concussion_blow_upgrade(failures)

