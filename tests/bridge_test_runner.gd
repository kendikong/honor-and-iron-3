class_name BridgeTestRunner
extends RefCounted

## Headless smoke tests for bridge layer (Phase 1 expands coverage).

static func run_all() -> Dictionary:
	var failures: Array[String] = []
	_test_skirmish_preset(failures)
	_test_encounter_builder(failures)
	return {"passed": failures.is_empty(), "failures": failures}


static func _test_skirmish_preset(failures: Array[String]) -> void:
	var idx: int = SkirmishGenerator.preset_index_for_size(Vector2i(32, 16))
	if idx < 0:
		failures.append("Skirmish preset 32x16 not registered")


static func _test_encounter_builder(failures: Array[String]) -> void:
	var config := SkirmishGenerator.SkirmishConfig.new()
	config.size_preset = Vector2i(16, 8)
	config.map_seed = 12345
	var skirmish: SkirmishGenerator.SkirmishResult = SkirmishGenerator.generate(config)
	if skirmish.grid.width != 16 or skirmish.grid.height != 8:
		failures.append("SkirmishGenerator size mismatch")
	var encounter: EncounterData = EncounterBuilder.build_from_player_grid(
		skirmish.grid, {}, [], [],
	)
	if encounter.grid_size != Vector2i(16, 8):
		failures.append("EncounterBuilder grid_size mismatch")
