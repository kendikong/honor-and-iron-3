extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _SETTLE_FRAMES: int = 8
const _DELTA_MS: int = 16
const _ACTOR_CELL := Vector2i(4, 5)


func test_live_monk_class_load_and_skill_registration(timeout := 120000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var scene := runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	if scene == null:
		return
	var session: TestBattleSession = scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"monk"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.set_all_passives_enabled(&"monk", true)
	session.set_all_skills_enabled(&"monk", true)
	session.dummy_coords = [Vector2i(6, 5)]
	session.unkillable_dummies = true
	scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var director := scene.get_node("CombatDirector") as CombatDirector
	var actor_id := _unit_id_at(director.base_board, _ACTOR_CELL)
	assert_int(actor_id).is_greater(-1)
	if actor_id < 0:
		return
	var actor := director.board.get_unit_by_id(actor_id)
	assert_object(actor).is_not_null()
	if actor == null:
		return
	assert_that(_ability_by_id(actor, &"monk_scorching_kick")).is_not_null()
	assert_that(_ability_by_id(actor, &"monk_leap")).is_not_null()


func _unit_id_at(board: BoardState, cell: Vector2i) -> int:
	var unit := board.get_unit_at(cell)
	return unit.id if unit != null else -1


func _ability_by_id(unit: UnitState, ability_id: StringName) -> AbilityData:
	for ability: AbilityData in unit.active_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null
