extends SceneTree

## Purpose: Command-line entry point for the Milestone 1 simulation checks.
## Run from the project root with:
##   "<godot.exe>" --headless --path . --script res://tests/harness/sim_test.gd
## Delegates all logic to SimTestRunner so the editor runner shares it.

func _initialize() -> void:
	var failures := SimTestRunner.new().run_all()
	quit(failures)
