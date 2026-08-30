class_name ShamanScenarioAdapter
extends RefCounted


const _H := preload("res://tests/shaman_qa_harness.gd")


static func run_active(ability_id: StringName, failures: Array[String]) -> void:
	_H.run_single_ability(ability_id, failures)


static func run_passive(passive_id: StringName, failures: Array[String]) -> void:
	_H.run_passive_factory(passive_id, failures)
