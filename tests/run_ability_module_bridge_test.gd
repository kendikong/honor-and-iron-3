extends SceneTree

## Legacy alias — prefer res://tests/run_ability_module_bridge_runner.gd
## Run: godot --headless --path . --script res://tests/run_ability_module_bridge_test.gd


func _initialize() -> void:
	DataLibrary.reset_cache()
	var result: Dictionary = AbilityModuleBridgeRunner.run_all()
	quit(0 if bool(result.get("passed", false)) else 1)
