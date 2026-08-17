class_name CellularRegenerationScenarioTest
extends RefCounted

## Bible: Cellular Regeneration — HEAL 1 if 1+ adjacent enemies at turn start.
## [+] also gain +1 STR if 2+ adjacent enemies.
## Globals: passive turn-start hook; adjacent enemy count scaling.


static func run_all(failures: Array[String]) -> void:
	var board: BoardState = BruiserQaHarness.make_plain_board(Vector2i(8, 8))
	BruiserQaHarness.place_bruiser(
		board, 1, Vector2i(3, 3),
		BruiserQaHarness.with_single_passive(&"cellular_regeneration", false),
	)
	BruiserQaHarness.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser: UnitState = board.get_unit_by_id(1)
	bruiser.health.current_hp = bruiser.health.max_hp - 2
	var before: int = bruiser.health.current_hp
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, Timeline.new(), events)
	var after: UnitState = board.get_unit_by_id(1)
	BruiserQaHarness.assert_true(failures, "cellular_regeneration/registered", after != null)
	BruiserQaHarness.assert_true(
		failures, "cellular_regeneration/heal",
		after != null and after.health.current_hp > before,
		"turn-start Sanguine Regeneration must heal when an enemy is adjacent",
	)

