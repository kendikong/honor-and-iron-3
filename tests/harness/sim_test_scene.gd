extends Node

## Purpose: One-click in-editor entry point for the Milestone 1 simulation checks.
## Open tests/SimTest.tscn and press "Run Current Scene" (F6); results print to the
## editor Output panel. Delegates to SimTestRunner so logic is shared with the CLI.

func _ready() -> void:
	SimTestRunner.new().run_all()
