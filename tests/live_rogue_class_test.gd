extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _SETTLE_FRAMES: int = 8
const _DELTA_MS: int = 16
const _ACTOR_CELL := Vector2i(4, 5)
const _ROGUE_SKILLS: Array[StringName] = [
	&"rogue_slip_past", &"rogue_shadow_step", &"rogue_kidney_strike",
	&"rogue_smoke_bomb", &"rogue_evasive_strike", &"rogue_grappling_hook",
	&"rogue_switcheroo", &"rogue_blindside", &"rogue_throat_slit",
	&"rogue_amnesia_dust", &"rogue_death_mark", &"rogue_lethal_flourish",
	&"rogue_shadow_swap", &"rogue_kidnap", &"rogue_shuriken_volley",
	&"rogue_poison_flask",
]


func test_live_rogue_factory_loads_every_skill(timeout := 120000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var scene := runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	if scene == null:
		return
	var session := scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"rogue"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.set_all_passives_enabled(&"rogue", true)
	session.set_all_skills_enabled(&"rogue", true)
	scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var director := scene.get_node("CombatDirector") as CombatDirector
	var actor_id := _unit_id_at(director.base_board, _ACTOR_CELL)
	assert_int(actor_id).is_greater(-1)
	if actor_id < 0:
		return
	var actor := director.board.get_unit_by_id(actor_id)
	for skill_id: StringName in _ROGUE_SKILLS:
		assert_object(_ability_by_id(actor, skill_id)).override_failure_message(
			"Rogue live factory missing %s" % skill_id,
		).is_not_null()


func _unit_id_at(board: BoardState, coord: Vector2i) -> int:
	var unit := board.get_unit_at(coord)
	return unit.id if unit != null else -1


func _ability_by_id(unit: UnitState, ability_id: StringName) -> AbilityData:
	for ability: AbilityData in unit.active_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null
