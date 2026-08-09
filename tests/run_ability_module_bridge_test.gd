extends SceneTree

## Headless entry: modular ability bridge + module authoring bar.
## Run: godot --headless --path . -s res://tests/run_ability_module_bridge_test.gd


func _initialize() -> void:
	DataLibrary.reset_cache()
	var runner: Script = load("res://tests/ability_module_bridge_runner.gd") as Script
	var result: Dictionary = runner.call("run_all") as Dictionary
	quit(0 if bool(result.get("passed", false)) else 1)
