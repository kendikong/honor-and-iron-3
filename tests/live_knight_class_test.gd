## Tier 2 live Knight acceptance.
##
## Every authored Knight active is loaded through TestBattle. Seismic Stomp
## additionally proves the production overlay uses the shared AOE footprint.
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _SETTLE_FRAMES: int = 8
const _DELTA_MS: int = 16
const _OVERLAY_QA := preload("res://tests/live_overlay_qa_mixin.gd")
const _AOE_QA := preload("res://tests/aoe_footprint_qa_harness.gd")
const _IDS: Array[StringName] = [
	&"knight_swap",
	&"knight_shield_bash",
	&"knight_phalanx_stance",
	&"knight_taunting_strike",
	&"knight_seismic_stomp",
	&"knight_fortify",
	&"knight_bowling_charge",
	&"knight_iron_grip",
	&"knight_redirect_strike",
	&"knight_indomitable_will",
	&"knight_retaliation_protocol",
	&"knight_shield_slam",
	&"knight_defensive_formation",
	&"knight_chain_hook",
	&"knight_trampling_advance",
]


func test_live_knight_factory_loads_every_active(timeout := 120000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var scene := runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	if scene == null:
		return
	var session: TestBattleSession = scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"knight"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.set_all_passives_enabled(&"knight", true)
	session.set_all_skills_enabled(&"knight", true)
	scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var director := scene.get_node("CombatDirector") as CombatDirector
	var actor := _find_knight(director.base_board)
	assert_object(actor).is_not_null()
	if actor == null:
		return
	for ability_id: StringName in _IDS:
		assert_object(_ability_by_id(actor, ability_id)).override_failure_message(
			"Knight live factory missing %s" % ability_id,
		).is_not_null()


func test_live_knight_seismic_stomp_overlay_uses_shared_geometry(
	timeout := 120000,
) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var scene := runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	if scene == null:
		return
	var session: TestBattleSession = scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"knight"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.set_all_passives_enabled(&"knight", true)
	session.set_all_skills_enabled(&"knight", true)
	session.dummy_coords = [Vector2i(5, 4), Vector2i(8, 4)]
	session.unkillable_dummies = true
	scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var director := scene.get_node("CombatDirector") as CombatDirector
	var shell := scene.get_node("CombatShell") as TacticalCombatShell
	var input: CombatPlanningInput = shell.planning_input
	var overlay := scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	var actor := _find_knight(director.base_board)
	assert_object(actor).is_not_null()
	if actor == null:
		return
	var ability := _ability_by_id(actor, &"knight_seismic_stomp")
	assert_object(ability).is_not_null()
	if ability == null:
		return
	await _OVERLAY_QA.sync_attack_hover(
		runner, input, overlay, director, actor.position, _DELTA_MS,
	)
	var expected := _AOE_QA.expected_self_aoe_tiles(
		director.board, actor, ability, actor.position,
	)
	expected.erase(actor.position)
	var parity_error := _AOE_QA.overlay_parity_error(
		overlay, expected, &"knight_seismic_stomp",
	)
	assert_bool(parity_error.is_empty()).override_failure_message(parity_error).is_true()


func _find_knight(board: BoardState) -> UnitState:
	for unit: UnitState in board.units:
		if unit != null and unit.definition != null and unit.definition.id == &"knight":
			return unit
	return null


func _ability_by_id(unit: UnitState, ability_id: StringName) -> AbilityData:
	if unit == null:
		return null
	for ability: AbilityData in unit.active_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null
