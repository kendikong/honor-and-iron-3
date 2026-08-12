class_name LiveBeastRiderClassTest
extends GdUnitTestSuite

const _ABILITY_IDS: Array[StringName] = [
	&"beast_reposition", &"beast_pounce", &"beast_feral_drag", &"beast_maul",
	&"beast_bestial_roar", &"beast_raking_claws", &"beast_rest_recover",
	&"beast_intimidate", &"beast_fetch", &"beast_savage_bite", &"beast_run_down",
	&"beast_thrash", &"beast_defensive_posture", &"beast_airlift",
	&"beast_tail_swipe", &"beast_meteor_drop",
]


func test_live_beast_rider_factory_loads_every_skill(timeout := 120000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(12, 16)
	var scene := runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	if scene == null:
		return
	var session: TestBattleSession = scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"beast_rider"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.set_all_passives_enabled(&"beast_rider", true)
	session.set_all_skills_enabled(&"beast_rider", true)
	scene.apply_training_board()
	await runner.simulate_frames(12, 16)
	var director := scene.get_node("CombatDirector") as CombatDirector
	assert_object(director).is_not_null()
	if director == null:
		return
	var actor := _first_player(director.base_board)
	assert_object(actor).is_not_null()
	if actor == null:
		return
	for ability_id: StringName in _ABILITY_IDS:
		assert_object(_ability_by_id(actor, ability_id)).override_failure_message(
			"Beast Rider live factory missing %s" % ability_id,
		).is_not_null()


func _first_player(board: BoardState) -> UnitState:
	if board == null:
		return null
	for unit: UnitState in board.units:
		if unit != null and unit.team == GameEnums.Team.PLAYER:
			return unit
	return null


func _ability_by_id(unit: UnitState, ability_id: StringName) -> AbilityData:
	if unit == null:
		return null
	for ability: AbilityData in unit.active_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null
