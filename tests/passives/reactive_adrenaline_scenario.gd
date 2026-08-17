class_name ReactiveAdrenalineScenarioTest
extends RefCounted

const _Upgrades := preload("res://tests/bruiser_qa_harness_upgrades.gd")

## Bible: Reactive Adrenaline — adjacent enemies convert Sanguine Regeneration
## into SHIELD and grant +1 STR per adjacent enemy, capped at +3.
## [+] also grants +1 DEF per adjacent enemy.
## Globals: turn-start passive system and shared status/armor resolution.


static func run_all(failures: Array[String]) -> void:
	_run_trigger(failures, false)
	_run_trigger(failures, true)
	_Upgrades.run_reactive_adrenaline_upgrade(failures)


static func _run_trigger(failures: Array[String], upgraded: bool) -> void:
	var cfg: Dictionary = BruiserQaHarness.with_single_passive(
		&"reactive_adrenaline", upgraded,
	)
	var board: BoardState = BruiserQaHarness.make_plain_board(Vector2i(8, 8))
	BruiserQaHarness.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	BruiserQaHarness.place_dummy(board, 2, Vector2i(4, 3))
	BruiserQaHarness.place_dummy(board, 3, Vector2i(3, 4))
	var bruiser: UnitState = board.get_unit_by_id(1)
	bruiser.health.current_hp = bruiser.health.max_hp - 2
	var before: int = bruiser.health.current_hp
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, Timeline.new(), events)
	var after: UnitState = board.get_unit_by_id(1)
	BruiserQaHarness.assert_true(failures, "reactive_adrenaline/registered", after != null)
	BruiserQaHarness.assert_eq_int(
		failures, "reactive_adrenaline/no_heal", after.health.current_hp, before,
	)
	BruiserQaHarness.assert_true(
		failures, "reactive_adrenaline/shield", after.armor > 0,
		"adjacent enemies convert the Sanguine heal into SHIELD",
	)
	BruiserQaHarness.assert_true(
		failures, "reactive_adrenaline/strength",
		BruiserQaHarness.has_status(after, GameEnums.StatusType.STAT_BUFF_STR),
	)
	if upgraded:
		BruiserQaHarness.assert_true(
			failures, "reactive_adrenaline/defense",
			BruiserQaHarness.has_status(after, GameEnums.StatusType.STAT_BUFF_DEF),
		)
