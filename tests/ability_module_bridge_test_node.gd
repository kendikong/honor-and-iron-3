extends Node

## Scene runner for AbilityModuleBridgeTest.tscn (F5 / QA scenes with autoloads).

const _Runner := preload("res://tests/ability_module_bridge_runner.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DataLibrary.reset_cache()
	var result: Dictionary = _Runner.call("run_all") as Dictionary
	get_tree().quit(0 if bool(result.get("passed", false)) else 1)
