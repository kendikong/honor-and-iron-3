class_name BruiserPlanningSmokeRegistry
extends RefCounted

## Bruiser planning smoke — delegates to global movement registry.

const _Global := preload("res://tests/movement_planning_smoke_registry.gd")


static func run_for_factory_id(failures: Array[String], factory_id: StringName) -> void:
	_Global.run_for_factory_id(failures, factory_id)
