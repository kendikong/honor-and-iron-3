extends SceneTree

## Headless entry: modular ability bridge + module authoring bar.
## Run: godot --headless --path . --script res://tests/run_ability_module_bridge_runner.gd
## Do NOT use --script res://tests/ability_module_bridge_runner.gd (RefCounted harness, not SceneTree).


func _initialize() -> void:
	DataLibrary.reset_cache()
	var result: Dictionary = AbilityModuleBridgeRunner.run_all()
	quit(0 if bool(result.get("passed", false)) else 1)
