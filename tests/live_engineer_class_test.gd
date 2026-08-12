## Tier 2 live Engineer acceptance.
## Active rows are loaded in TestBattle; shaped rows additionally compare the
## production overlay against GridSystem geometry at a scripted hover.
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _SETTLE_FRAMES: int = 8
const _DELTA_MS: int = 16
const _OVERLAY_QA := preload("res://tests/live_overlay_qa_mixin.gd")
const _IDS: Array[StringName] = [
	&"engineer_recall", &"engineer_dismantle", &"engineer_sludge_bomb",
	&"engineer_construct_turret", &"engineer_frag_bomb", &"engineer_magnetic_mine",
	&"engineer_tesla_barricade", &"engineer_flak_cannon", &"engineer_wrench_smack",
	&"engineer_emp_grenade", &"engineer_rocket_launcher", &"engineer_scrap_shield",
	&"engineer_manual_detonation", &"engineer_overdrive_injection", &"engineer_barbed_wire",
]


func test_live_engineer_factory_loads_every_row(timeout := 120000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var scene := runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	if scene == null:
		return
	var session: TestBattleSession = scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"engineer"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.set_all_passives_enabled(&"engineer", true)
	session.set_all_skills_enabled(&"engineer", true)
	scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var director := scene.get_node("CombatDirector") as CombatDirector
	var actor := _find_engineer(director.base_board)
	assert_object(actor).is_not_null()
	if actor == null:
		return
	for ability_id: StringName in _IDS:
		assert_object(_ability_by_id(actor, ability_id)).override_failure_message(
			"Engineer live factory missing %s" % ability_id,
		).is_not_null()
	assert_int(actor.active_passives.size()).is_greater_equal(16)


func test_live_engineer_shaped_overlay_uses_shared_geometry(timeout := 120000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var scene := runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	if scene == null:
		return
	var session: TestBattleSession = scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"engineer"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.set_all_passives_enabled(&"engineer", true)
	session.set_all_skills_enabled(&"engineer", true)
	session.dummy_coords = [Vector2i(6, 5), Vector2i(6, 6)]
	session.unkillable_dummies = true
	scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var director := scene.get_node("CombatDirector") as CombatDirector
	var shell := scene.get_node("CombatShell") as TacticalCombatShell
	var input: CombatPlanningInput = shell.planning_input
	var overlay := scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	var actor := _find_engineer(director.base_board)
	assert_object(actor).is_not_null()
	if actor == null:
		return
	var ability := _ability_by_id(actor, &"engineer_sludge_bomb")
	assert_object(ability).is_not_null()
	if ability == null:
		return
	director.select_unit(actor.id)
	director.select_ability(_ability_index(actor, ability))
	await _OVERLAY_QA.assert_live_overlay_parity(
		self, runner, overlay, input, director, actor.id, ability, Vector2i(6, 5),
		&"engineer_sludge_bomb",
	)


func _find_engineer(board: BoardState) -> UnitState:
	for unit: UnitState in board.units:
		if unit != null and unit.definition != null and unit.definition.id == &"engineer":
			return unit
	return null


func _ability_by_id(unit: UnitState, ability_id: StringName) -> AbilityData:
	if unit == null:
		return null
	for ability: AbilityData in unit.active_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


func _ability_index(unit: UnitState, ability: AbilityData) -> int:
	if unit == null or ability == null:
		return -1
	for index: int in unit.active_abilities.size():
		if unit.active_abilities[index] == ability:
			return index
	return -1
