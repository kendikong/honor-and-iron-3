## Tier 2 live Knight acceptance.
##
## Every authored Knight active is loaded through TestBattle. Shaped self-AOEs
## additionally prove the production overlay uses the shared AOE footprint.
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


func test_live_knight_defensive_formation_overlay_uses_shared_geometry(
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
	session.extra_player_coords = [Vector2i(5, 4)]
	session.dummy_coords = [Vector2i(3, 4), Vector2i(8, 4)]
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
	var ability := _ability_by_id(actor, &"knight_defensive_formation")
	assert_object(ability).is_not_null()
	if ability == null:
		return
	actor.upgraded_abilities = [ability.id]
	var live_actor := director.board.get_unit_by_id(actor.id)
	if live_actor != null:
		live_actor.upgraded_abilities = [ability.id]
	director.select_unit(actor.id)
	director.select_ability(_ability_index(actor, ability))
	await _OVERLAY_QA.assert_live_overlay_parity(
		self, runner, overlay, input, director, actor.id, ability, actor.position,
		&"knight_defensive_formation",
	)
	var slots: Dictionary = input._final_commit_slots_for_click_at_cell(
		actor.id, actor.position, Vector2.ZERO,
	)
	assert_bool(bool(slots.get("invalid", false))).override_failure_message(
		"knight_defensive_formation: preview slots invalid %s" % slots,
	).is_false()
	if bool(slots.get("invalid", false)):
		return
	input.call("_paint_intent_slots_before_commit", actor.id, slots)
	assert_bool(director.commit_from_slots(actor.id, slots)).override_failure_message(
		"knight_defensive_formation: commit_from_slots rejected preview %s" % slots,
	).is_true()
	input.call("_promote_intent_preview_after_commit")
	director.flush_plan_refresh_signals_if_pending()
	input.clear_qa_pointer_override()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var committed := _committed_action_for_ability(director, actor.id, ability.id)
	assert_object(committed).override_failure_message(
		"knight_defensive_formation: committed plan lost preview ability",
	).is_not_null()
	if committed == null:
		return
	assert_that(committed.target_coord).override_failure_message(
		"knight_defensive_formation: committed target drifted from self target",
	).is_equal(actor.position)
	var ally := _ally_in_formation_range(director.base_board, actor, ability)
	assert_object(ally).override_failure_message(
		"knight_defensive_formation: training board has no nearby ally",
	).is_not_null()
	if ally == null:
		return
	var sim_board: BoardState = director.base_board.clone()
	var sim_ally_before_armor: int = sim_board.get_unit_by_id(ally.id).armor
	var sim_caster_before_armor: int = sim_board.get_unit_by_id(actor.id).armor
	var sim_events: Array[SimEvent] = []
	Simulator.simulate_player_turn(sim_board, director.get_player_plan(), sim_events)
	var sim_ally := sim_board.get_unit_by_id(ally.id)
	var sim_caster := sim_board.get_unit_by_id(actor.id)
	var sim_def := _status_by_type(sim_ally, GameEnums.StatusType.STAT_BUFF_DEF)
	var sim_sturdy := _status_by_type(sim_ally, GameEnums.StatusType.STURDY)
	assert_bool(
		sim_ally != null and sim_ally.has_status(GameEnums.StatusType.STAT_BUFF_DEF),
	).override_failure_message(
		"knight_defensive_formation: committed simulation missed ally DEF buff",
	).is_true()
	assert_bool(
		sim_ally != null and sim_ally.has_status(GameEnums.StatusType.STURDY),
	).override_failure_message(
		"knight_defensive_formation: committed simulation missed ally STURDY",
	).is_true()
	assert_object(sim_def).override_failure_message(
		"knight_defensive_formation: committed simulation missed DEF status data",
	).is_not_null()
	if sim_def != null:
		assert_int(sim_def.value).override_failure_message(
			"knight_defensive_formation: live DEF magnitude drifted",
		).is_equal(2)
	assert_object(sim_sturdy).override_failure_message(
		"knight_defensive_formation: committed simulation missed STURDY data",
	).is_not_null()
	if sim_sturdy != null:
		assert_int(sim_sturdy.duration).override_failure_message(
			"knight_defensive_formation: live STURDY duration drifted",
		).is_equal(1)
	assert_int(sim_ally.armor - sim_ally_before_armor).override_failure_message(
		"knight_defensive_formation: committed simulation missed upgraded ARMOR_UP",
	).is_equal(2)
	assert_int(sim_caster.armor).override_failure_message(
		"knight_defensive_formation: upgraded simulation changed caster armor",
	).is_equal(sim_caster_before_armor)
	assert_bool(
		sim_caster == null or not sim_caster.has_status(GameEnums.StatusType.STAT_BUFF_DEF),
	).override_failure_message(
		"knight_defensive_formation: committed simulation buffed caster DEF",
	).is_true()
	assert_bool(
		sim_caster == null or not sim_caster.has_status(GameEnums.StatusType.STURDY),
	).override_failure_message(
		"knight_defensive_formation: committed simulation buffed caster STURDY",
	).is_true()


func _find_knight(board: BoardState) -> UnitState:
	for unit: UnitState in board.units:
		if unit != null and unit.definition != null and unit.definition.id == &"knight":
			return unit
	return null


func _ability_index(unit: UnitState, ability: AbilityData) -> int:
	if unit == null or ability == null:
		return -1
	for index: int in unit.active_abilities.size():
		if unit.active_abilities[index] == ability:
			return index
	return -1


func _committed_action_for_ability(
	director: CombatDirector,
	actor_id: int,
	ability_id: StringName,
) -> TimelineAction:
	for action: TimelineAction in director.get_player_plan().entries:
		if (
			action.actor_id == actor_id
			and action.ability != null
			and action.ability.id == ability_id
			and not action.awaiting_target
		):
			return action
	return null


func _ally_in_formation_range(
	board: BoardState,
	actor: UnitState,
	ability: AbilityData,
) -> UnitState:
	var footprint := GridSystem.get_affected_tiles(
		board, actor.position, actor.position, ability.target_shape, ability.target_shape_size,
	)
	for unit: UnitState in board.units:
		if (
			unit != null
			and unit.id != actor.id
			and unit.is_alive()
			and unit.team == actor.team
			and footprint.has(unit.position)
		):
			return unit
	return null


func _status_by_type(unit: UnitState, status_type: GameEnums.StatusType) -> StatusData:
	if unit == null:
		return null
	for status: StatusData in unit.active_statuses:
		if status != null and status.type == status_type:
			return status
	return null


func _ability_by_id(unit: UnitState, ability_id: StringName) -> AbilityData:
	if unit == null:
		return null
	for ability: AbilityData in unit.active_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null
