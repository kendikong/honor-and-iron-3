## Tier 2 live Archer acceptance.
##
## Four Archers act in parallel batches. Each case validates the authored
## range/targeting/shape contract and commits through the real preview slots.
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _ACTOR_CELL := Vector2i(4, 5)
const _SETTLE_FRAMES := 8
const _DELTA_MS := 16
const _COMPLEX_SECOND_ARCHER_CELL := Vector2i(2, 8)
const _COMPLEX_VOLLEY_AIM := Vector2i(6, 5)
const _COMPLEX_SIDESTEP_DEST := Vector2i(3, 8)
const _COMPLEX_POWER_TARGET := Vector2i(6, 8)
const _COMPLEX_POST_MOVE_DEST := Vector2i(4, 8)
const _OVERLAY_QA := preload("res://tests/live_overlay_qa_mixin.gd")
const _MOVEMENT_QA := preload("res://tests/live_movement_timeline_qa_mixin.gd")

const _CASES: Array[Dictionary] = [
	{"id": &"archer_sidestep", "range": 1, "flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.MOVE,
		"amount": 1, "kind": &"tile", "actor": Vector2i(1, 5), "target": Vector2i(0, 5),
		"observe": &"movement"},
	{"id": &"archer_basic", "range": 2, "flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 1, "kind": &"enemy", "actor": Vector2i(4, 5), "target": Vector2i(6, 5),
		"observe": &"damage"},
	{"id": &"archer_power_shot", "range": 5, "flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 3, "kind": &"enemy", "actor": Vector2i(2, 2), "target": Vector2i(6, 2),
		"observe": &"damage"},
	{"id": &"archer_volley", "range": 4, "flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.AOE_SQUARE, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 1, "kind": &"tile", "actor": Vector2i(2, 8), "target": Vector2i(5, 8),
		"observe": &"damage"},
	{"id": &"archer_pinning_arrow", "range": 4, "flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 1, "kind": &"enemy", "actor": Vector2i(8, 8), "target": Vector2i(8, 6),
		"observe": &"status"},
	{"id": &"archer_piercing_shot", "range": 4,
		"flags": GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.LINE, "size": 4, "type": GameEnums.EffectType.DAMAGE,
		"amount": 2, "kind": &"enemy", "actor": Vector2i(4, 5), "target": Vector2i(8, 5),
		"observe": &"damage"},
	{"id": &"archer_toxic_spore_arrow", "range": 5, "flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 1, "kind": &"enemy", "actor": Vector2i(2, 2), "target": Vector2i(6, 2),
		"observe": &"status"},
	{"id": &"archer_grapple_arrow", "range": 4,
		"flags": GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.PULL,
		"amount": 1, "kind": &"tile", "actor": Vector2i(2, 8), "target": Vector2i(6, 8),
		"observe": &"ability"},
	{"id": &"archer_explosive_arrow", "range": 4,
		"flags": GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.AOE_CROSS, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 2, "kind": &"tile", "actor": Vector2i(8, 8), "target": Vector2i(8, 6),
		"observe": &"damage"},
	{"id": &"archer_hunters_mark", "range": 5, "flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.ADD_STATUS,
		"amount": 1, "kind": &"enemy", "actor": Vector2i(4, 5), "target": Vector2i(6, 5),
		"observe": &"status"},
	{"id": &"archer_repelling_shot", "range": 2,
		"flags": GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 1, "kind": &"enemy", "actor": Vector2i(2, 4), "target": Vector2i(5, 4),
		"observe": &"damage"},
	{"id": &"archer_bear_trap", "range": 3, "flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.CREATE_HAZARD,
		"amount": 3, "kind": &"tile", "actor": Vector2i(2, 8), "target": Vector2i(5, 8),
		"observe": &"terrain"},
	{"id": &"archer_suppressing_fire", "range": 4, "flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.ARC, "size": 1, "type": GameEnums.EffectType.CREATE_HAZARD,
		"amount": 1, "kind": &"tile", "actor": Vector2i(8, 8), "target": Vector2i(8, 5),
		"observe": &"terrain"},
	{"id": &"archer_caltrop_trap", "range": 3, "flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.CREATE_HAZARD,
		"amount": 1, "kind": &"tile", "actor": Vector2i(4, 5), "target": Vector2i(5, 5),
		"observe": &"terrain"},
	{"id": &"archer_parting_shot", "range": 3, "flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 2, "kind": &"enemy", "actor": Vector2i(2, 2), "target": Vector2i(5, 2),
		"observe": &"damage"},
	{"id": &"archer_scouts_eye", "range": 5, "flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.PURGE,
		"amount": 0, "kind": &"enemy", "actor": Vector2i(8, 8), "target": Vector2i(8, 5),
		"observe": &"ability"},
]

const _BATCHES: Array[Array] = [
	[&"archer_basic", &"archer_power_shot", &"archer_volley", &"archer_pinning_arrow"],
	[&"archer_piercing_shot", &"archer_toxic_spore_arrow", &"archer_grapple_arrow", &"archer_explosive_arrow"],
	[&"archer_hunters_mark", &"archer_repelling_shot", &"archer_bear_trap", &"archer_suppressing_fire"],
	[&"archer_caltrop_trap", &"archer_parting_shot", &"archer_scouts_eye"],
	[&"archer_sidestep"],
]

var _scene: TestBattleMapView
var _director: CombatDirector
var _input: CombatPlanningInput
var _overlay: TacticalPlanningOverlay


func test_live_archer_every_skill(timeout := 240000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_scene = runner.scene() as TestBattleMapView
	assert_object(_scene).is_not_null()
	if _scene == null:
		return
	for batch: Array in _BATCHES:
		await _run_live_batch(runner, batch)


func test_live_second_archer_complex_turn_after_volley(timeout := 240000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_scene = runner.scene() as TestBattleMapView
	assert_object(_scene).is_not_null()
	if _scene == null:
		return
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"archer"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.passive_enabled.clear()
	session.skill_enabled.clear()
	session.set_all_passives_enabled(&"archer", false)
	session.set_all_skills_enabled(&"archer", true)
	session.extra_player_coords = [_COMPLEX_SECOND_ARCHER_CELL]
	session.dummy_coords = [
		_COMPLEX_VOLLEY_AIM,
		Vector2i(6, 4),
		Vector2i(7, 5),
		_COMPLEX_POWER_TARGET,
		Vector2i(7, 8),
	]
	session.unkillable_dummies = true
	_scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)

	_director = _scene.get_node("CombatDirector") as CombatDirector
	var shell := _scene.get_node("CombatShell") as TacticalCombatShell
	_input = shell.planning_input
	_overlay = _scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	assert_object(_input._planning).override_failure_message(
		"complex turn: CombatPlanningInput planning owner missing",
	).is_not_null()
	var unit_layer := _scene.get_node(
		"WorldModulate/MapRoot/UnitLayer",
	) as TacticalUnitLayer
	var first_id: int = _unit_id_at(_director.base_board, _ACTOR_CELL)
	var second_id: int = _unit_id_at(_director.base_board, _COMPLEX_SECOND_ARCHER_CELL)
	var volley_enemy_id: int = _unit_id_at(_director.base_board, _COMPLEX_VOLLEY_AIM)
	var power_enemy_id: int = _unit_id_at(_director.base_board, _COMPLEX_POWER_TARGET)
	assert_int(first_id).override_failure_message("complex turn: first Archer missing").is_greater(0)
	assert_int(second_id).override_failure_message("complex turn: second Archer missing").is_greater(0)
	assert_int(volley_enemy_id).override_failure_message(
		"complex turn: Volley target dummy missing",
	).is_greater(0)
	assert_int(power_enemy_id).override_failure_message(
		"complex turn: Power Shot target dummy missing",
	).is_greater(0)
	if first_id < 0 or second_id < 0 or volley_enemy_id < 0 or power_enemy_id < 0:
		return

	var first: UnitState = _director.board.get_unit_by_id(first_id)
	var second: UnitState = _director.board.get_unit_by_id(second_id)
	var volley: AbilityData = _ability_by_id(first, &"archer_volley")
	var sidestep: AbilityData = _ability_by_id(second, &"archer_sidestep")
	var power_shot: AbilityData = _ability_by_id(second, &"archer_power_shot")
	assert_object(volley).override_failure_message(
		"complex turn: first Archer Volley missing",
	).is_not_null()
	assert_object(sidestep).override_failure_message(
		"complex turn: second Archer Sidestep missing",
	).is_not_null()
	assert_object(power_shot).override_failure_message(
		"complex turn: second Archer Power Shot missing",
	).is_not_null()
	if volley == null or sidestep == null or power_shot == null:
		return

	# First Archer: commit the AOE that must remain visible after selection changes.
	_director.select_unit(first_id)
	_director.select_ability(_ability_index(first, volley))
	await runner.simulate_frames(2, _DELTA_MS)
	await _OVERLAY_QA.assert_live_overlay_parity(
		self,
		runner,
		_overlay,
		_input,
		_director,
		first_id,
		volley,
		_COMPLEX_VOLLEY_AIM,
		&"complex/volley_hover",
	)
	var volley_slots: Dictionary = await _commit_live_click(
		runner, first_id, _COMPLEX_VOLLEY_AIM,
	)
	assert_bool(_slots_invalid(volley_slots)).override_failure_message(
		"complex/volley_commit rejected: %s" % _slots_debug(volley_slots),
	).is_false()
	assert_bool(_plan_has_ability(&"archer_volley")).override_failure_message(
		"complex/volley_commit did not write Volley",
	).is_true()
	var committed_immediately: CombatPlanningForecast = (
		_overlay.get_committed_preview().forecast
	)
	assert_object(committed_immediately).override_failure_message(
		"complex/after_volley immediate committed forecast missing",
	).is_not_null()
	await _assert_projection_matches_player_sim(runner, "complex/after_volley")
	var committed_after_volley: CombatPlanningForecast = (
		_overlay.get_committed_preview().forecast
	)
	assert_object(committed_after_volley).override_failure_message(
		"complex/after_volley committed forecast missing",
	).is_not_null()
	if committed_after_volley != null:
		assert_bool(committed_after_volley.damage_hp(volley_enemy_id) > 0).override_failure_message(
			"complex/after_volley committed HP damage disappeared",
		).is_true()
		var bar_after_volley: CombatPlanningForecast = unit_layer._bar_display_forecast()
		assert_object(bar_after_volley).override_failure_message(
			"complex/after_volley HP bar forecast missing",
		).is_not_null()
		if bar_after_volley != null:
			assert_bool(bar_after_volley.damage_hp(volley_enemy_id) > 0).override_failure_message(
				"complex/after_volley HP bar lost committed Volley damage",
			).is_true()

	# Second Archer: select after Volley, then commit PRE_MOVE -> ACTION -> POST_MOVE.
	_director.select_unit(second_id)
	await runner.simulate_frames(2, _DELTA_MS)
	var bar_after_selection: CombatPlanningForecast = unit_layer._bar_display_forecast()
	assert_object(bar_after_selection).override_failure_message(
		"complex/second_select committed forecast missing",
	).is_not_null()
	if bar_after_selection != null:
		assert_bool(bar_after_selection.damage_hp(volley_enemy_id) > 0).override_failure_message(
			"complex/second_select cleared the first Archer's Volley damage",
		).is_true()

	_director.select_ability(_ability_index(second, sidestep))
	await runner.simulate_frames(2, _DELTA_MS)
	var sidestep_slots: Dictionary = await _commit_live_click(
		runner, second_id, _COMPLEX_SIDESTEP_DEST,
	)
	assert_bool(_slots_invalid(sidestep_slots)).override_failure_message(
		"complex/sidestep_commit rejected: %s" % _slots_debug(sidestep_slots),
	).is_false()
	await _MOVEMENT_QA.assert_committed(
		self,
		&"archer_sidestep",
		_director,
		second_id,
		sidestep,
		sidestep_slots,
		_input,
		_overlay,
		runner,
	)
	var projected_after_sidestep: UnitState = _director.projected_state.get_unit_by_id(second_id)
	assert_that(projected_after_sidestep.position).override_failure_message(
		"complex/sidestep projected landing",
	).is_equal(_COMPLEX_SIDESTEP_DEST)

	_director.select_unit(second_id)
	_director.select_ability(_ability_index(second, power_shot))
	await _OVERLAY_QA.sync_attack_hover(
		runner, _input, _overlay, _director, _COMPLEX_POWER_TARGET,
	)
	var live_power_preview: CombatPlanningPreview = _overlay.get_live_preview()
	assert_object(live_power_preview.forecast).override_failure_message(
		"complex/power_shot hover forecast missing",
	).is_not_null()
	if live_power_preview.forecast != null:
		assert_bool(live_power_preview.forecast.damage_hp(power_enemy_id) > 0).override_failure_message(
			"complex/power_shot hover forecast missing target damage",
		).is_true()
	var power_slots: Dictionary = await _commit_live_click(
		runner, second_id, _COMPLEX_POWER_TARGET,
	)
	assert_bool(_slots_invalid(power_slots)).override_failure_message(
		"complex/power_shot_commit rejected: %s" % _slots_debug(power_slots),
	).is_false()
	assert_bool(_plan_has_ability(&"archer_power_shot")).override_failure_message(
		"complex/power_shot_commit did not write Power Shot",
	).is_true()

	var post_slots: Dictionary = await _MOVEMENT_QA.commit_universal_run(
		self,
		runner,
		_director,
		_input,
		second_id,
		_COMPLEX_POST_MOVE_DEST,
		true,
	)
	assert_bool(_slots_invalid(post_slots)).override_failure_message(
		"complex/post_move rejected: %s" % _slots_debug(post_slots),
	).is_false()
	var committed_post: TimelineAction = _committed_post_move_for_unit(second_id)
	assert_object(committed_post).override_failure_message(
		"complex/post_move action missing",
	).is_not_null()
	if committed_post != null:
		assert_that(committed_post.target_coord).override_failure_message(
			"complex/post_move target",
		).is_equal(_COMPLEX_POST_MOVE_DEST)
	await _assert_projection_matches_player_sim(runner, "complex/final")
	var final_second: UnitState = _director.projected_state.get_unit_by_id(second_id)
	assert_that(final_second.position).override_failure_message(
		"complex/final second Archer position",
	).is_equal(_COMPLEX_POST_MOVE_DEST)
	assert_bool(_plan_has_ability(&"archer_volley")).is_true()
	assert_bool(_plan_has_ability(&"archer_power_shot")).is_true()
	assert_int(_director.get_player_plan().entries.size()).override_failure_message(
		"complex/final timeline action count",
	).is_greater_equal(4)


func test_live_selection_after_committed_archer_actions(timeout := 240000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_scene = runner.scene() as TestBattleMapView
	assert_object(_scene).is_not_null()
	if _scene == null:
		return
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"archer"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.passive_enabled.clear()
	session.skill_enabled.clear()
	session.set_all_passives_enabled(&"archer", false)
	session.set_all_skills_enabled(&"archer", true)
	session.extra_player_coords = [_COMPLEX_SECOND_ARCHER_CELL]
	session.dummy_coords = [
		_COMPLEX_VOLLEY_AIM,
		Vector2i(6, 4),
		Vector2i(7, 5),
		_COMPLEX_POWER_TARGET,
	]
	session.unkillable_dummies = true
	_scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)

	_director = _scene.get_node("CombatDirector") as CombatDirector
	var shell := _scene.get_node("CombatShell") as TacticalCombatShell
	_input = shell.planning_input
	_overlay = _scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	var first_id: int = _unit_id_at(_director.base_board, _ACTOR_CELL)
	var second_id: int = _unit_id_at(_director.base_board, _COMPLEX_SECOND_ARCHER_CELL)
	var enemy_id: int = _unit_id_at(_director.base_board, _COMPLEX_VOLLEY_AIM)
	assert_int(first_id).override_failure_message(
		"selection regression: first Archer missing",
	).is_greater(0)
	assert_int(second_id).override_failure_message(
		"selection regression: second Archer missing",
	).is_greater(0)
	assert_int(enemy_id).override_failure_message(
		"selection regression: enemy missing",
	).is_greater(0)
	if first_id < 0 or second_id < 0 or enemy_id < 0:
		return

	var first: UnitState = _director.board.get_unit_by_id(first_id)
	var volley: AbilityData = _ability_by_id(first, &"archer_volley")
	assert_object(volley).override_failure_message(
		"selection regression: Volley missing",
	).is_not_null()
	if volley == null:
		return

	# Commit Archer 1 through the existing slot fixture, then use real clicks
	# for the selection sequence that previously required enemy → Archer 2.
	_director.select_unit(first_id)
	_director.select_ability(_ability_index(first, volley))
	await runner.simulate_frames(2, _DELTA_MS)
	var volley_slots: Dictionary = await _commit_live_click(
		runner, first_id, _COMPLEX_VOLLEY_AIM,
	)
	assert_bool(_slots_invalid(volley_slots)).override_failure_message(
		"selection regression: Volley commit rejected",
	).is_false()
	var first_mp: int = _director.projected_state.get_unit_by_id(first_id).movement.points_left
	var second_mp: int = _director.projected_state.get_unit_by_id(second_id).movement.points_left

	await _actual_click_cell(runner, _COMPLEX_VOLLEY_AIM)
	assert_int(_director.selected_unit_id).override_failure_message(
		"selection regression: enemy click did not select committed target",
	).is_equal(enemy_id)
	await _actual_click_cell(runner, _COMPLEX_SECOND_ARCHER_CELL)
	assert_int(_director.selected_unit_id).override_failure_message(
		"selection regression: enemy → second Archer click failed",
	).is_equal(second_id)
	_assert_projected_mp_unchanged(first_id, first_mp, "after enemy → second Archer")
	_assert_projected_mp_unchanged(second_id, second_mp, "after enemy → second Archer")


func _run_live_batch(runner: GdUnitSceneRunner, skill_ids: Array) -> void:
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"archer"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.passive_enabled.clear()
	session.skill_enabled.clear()
	session.set_all_passives_enabled(&"archer", false)
	session.set_all_skills_enabled(&"archer", true)
	session.extra_player_coords = _extra_players(skill_ids)
	session.dummy_coords = _dummies(skill_ids)
	session.unkillable_dummies = true
	_scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_director = _scene.get_node("CombatDirector") as CombatDirector
	var shell := _scene.get_node("CombatShell") as TacticalCombatShell
	_input = shell.planning_input
	_overlay = _scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	_director.auto_run = false
	for skill_id: StringName in skill_ids:
		var case := _case(skill_id)
		var actor_id := _unit_id_at(_director.base_board, case.actor)
		assert_int(actor_id).override_failure_message(
			"%s: missing four-Archer actor at %s" % [skill_id, case.actor],
		).is_greater(0)
		if actor_id < 0:
			continue
		var actor := _director.board.get_unit_by_id(actor_id)
		var ability := _ability_by_id(actor, skill_id)
		_assert_contract(ability, case)
		if ability == null:
			continue
		_director.select_unit(actor_id)
		await _MOVEMENT_QA.commit_premove_run_if_needed(
			self,
			runner,
			_director,
			_input,
			actor_id,
			ability,
			_MOVEMENT_QA.default_premove_run_cell(case.actor, case.target),
			_overlay,
		)
		_director.select_ability(_ability_index(actor, ability))
		await runner.simulate_frames(2, _DELTA_MS)
		await _OVERLAY_QA.assert_live_overlay_parity(
			self, runner, _overlay, _input, _director, actor_id, ability, case.target, skill_id,
		)
		var slots := await _commit_live_click(
			runner,
			actor_id,
			case.target,
		)
		if _slots_invalid(slots) or _plan_has_awaiting(actor_id):
			var follow_up: Vector2i = case.target
			if skill_id == &"archer_parting_shot":
				follow_up = _parting_shot_retreat_cell(case.actor, case.target)
			slots = await _commit_live_click(runner, actor_id, follow_up)
		assert_bool(_slots_invalid(slots)).override_failure_message(
			"%s: preview rejected a Bible-valid target: %s" % [skill_id, _slots_debug(slots)],
		).is_false()
		assert_bool(_plan_has_ability(skill_id)).override_failure_message(
			"%s: commit did not write the ability; plan=%s" % [skill_id, _plan_debug()],
		).is_true()
		await _MOVEMENT_QA.assert_committed(
			self, skill_id, _director, actor_id, ability, slots, _input, _overlay, runner,
		)
	var result: SimResult = Simulator.simulate(_director.base_board, _director.get_player_plan())
	for skill_id: StringName in skill_ids:
		var case := _case(skill_id)
		var actor_id := _unit_id_at(_director.base_board, case.actor)
		_assert_live_result(result, case, actor_id)


func _assert_contract(ability: AbilityData, case: Dictionary) -> void:
	assert_object(ability).override_failure_message(
		"%s: ability missing from live Archer loadout" % case.id,
	).is_not_null()
	if ability == null:
		return
	var module := AbilitySystem.active_module_for_index(null, ability, 0)
	assert_object(module).override_failure_message(
		"%s: missing authored primary module" % case.id,
	).is_not_null()
	if module == null:
		return
	assert_int(module.max_range).is_equal(int(case.range))
	assert_int(AbilitySystem.active_targeting_flags(null, ability)).is_equal(int(case.flags))
	assert_that(module.target_shape).is_equal(case.shape)
	assert_int(module.target_shape_size).is_equal(int(case.size))
	assert_that(module.primary_type).is_equal(case.type)
	assert_int(module.amount).is_equal(int(case.amount))
	if case.id != &"archer_basic":
		assert_bool(not ability.upgraded_modules.is_empty()).is_true()


func _assert_live_result(result: SimResult, case: Dictionary, actor_id: int) -> void:
	var used := false
	var observed := false
	for event: SimEvent in result.events:
		if (
			event.type == GameEnums.SimEventType.ACTION_FAILED
			and int(event.data.get("actor", -1)) == actor_id
		):
			assert_that("").override_failure_message(
				"%s: Simulator rejected the committed intent: %s" % [case.id, event.data],
			).is_equal("never")
		if (
			event.type == GameEnums.SimEventType.ABILITY_USED
			and event.data.get("ability", &"") == case.id
			and int(event.data.get("actor", -1)) == actor_id
		):
			used = true
		if case.observe == &"damage" and event.type == GameEnums.SimEventType.UNIT_DAMAGED:
			observed = true
		if case.observe == &"status" and event.type == GameEnums.SimEventType.STATUS_APPLIED:
			observed = true
		if case.observe == &"terrain" and event.type == GameEnums.SimEventType.TERRAIN_CHANGED:
			observed = true
		if case.observe == &"displacement" and event.type == GameEnums.SimEventType.UNIT_PUSHED:
			observed = true
		if (
			case.observe == &"displacement"
			and event.type == GameEnums.SimEventType.UNIT_MOVED
			and int(event.data.get("unit", -1)) != actor_id
		):
			observed = true
		if (
			case.observe == &"movement"
			and event.type == GameEnums.SimEventType.UNIT_MOVED
			and int(event.data.get("unit", -1)) == actor_id
		):
			observed = true
	if case.observe == &"ability":
		observed = used
	assert_bool(used).override_failure_message(
		"%s: committed skill never resolved; plan=%s" % [case.id, _plan_debug()],
	).is_true()
	if case.observe == &"movement":
		var final_actor: UnitState = result.final_state.get_unit_by_id(actor_id)
		if final_actor != null and final_actor.position == case.target:
			observed = true
	assert_bool(observed).override_failure_message(
		"%s: authored effect was not observed in live simulation" % case.id,
	).is_true()


func _parting_shot_retreat_cell(actor_cell: Vector2i, enemy_cell: Vector2i) -> Vector2i:
	## Bible: after the RANGE 3 shot, MOVE 2 onto an empty tile — not the enemy cell.
	var candidates: Array[Vector2i] = [
		actor_cell + Vector2i(0, 2),
		actor_cell + Vector2i(0, -2),
		actor_cell + Vector2i(-2, 0),
		actor_cell + Vector2i(2, 0),
	]
	for cell: Vector2i in candidates:
		if cell != enemy_cell and _director.board.is_in_bounds(cell):
			var occ: UnitState = _director.board.get_unit_at(cell)
			if occ == null:
				return cell
	return actor_cell + Vector2i(0, 2)


func _commit_live_click(
	runner: GdUnitSceneRunner,
	unit_id: int,
	cell: Vector2i,
) -> Dictionary:
	_director.select_unit(unit_id)
	var awaiting := _director.find_awaiting_action(unit_id)
	if awaiting != null and awaiting.ability != null:
		var actor := _director.board.get_unit_by_id(unit_id)
		_director.select_ability(_ability_index(actor, awaiting.ability))
	_input.set_qa_pointer_grid_cell(cell)
	_input._intent_state.set_hover_coord(cell)
	var actor := _director.board.get_unit_by_id(unit_id)
	var ability := CombatDirector.resolve_selected_ability(
		actor, _director.selected_ability_index,
	)
	var should_arm := (
		_director.find_awaiting_action(unit_id) == null
		and actor != null
		and ability != null
		and AbilitySystem.planning_commit_flow(actor, ability)
			== GameEnums.PlanningCommitFlow.AWAITING_TARGET
	)
	var slots: Dictionary
	if should_arm:
		slots = _input._final_commit_slots_for_click_at_cell(
			unit_id, actor.position, Vector2.ZERO,
		)
		if _slots_invalid(slots):
			return slots
		_input.call("_paint_intent_slots_before_commit", unit_id, slots)
		assert_bool(_director.commit_from_slots(unit_id, slots)).is_true()
		await runner.simulate_frames(2, _DELTA_MS)
	if _plan_has_awaiting(unit_id):
		slots = _input._build_commit_slots_at_cell(unit_id, cell)
	else:
		slots = _input._final_commit_slots_for_click_at_cell(unit_id, cell, Vector2.ZERO)
	if _slots_invalid(slots):
		return slots
	_input.call("_paint_intent_slots_before_commit", unit_id, slots)
	assert_bool(_director.commit_from_slots(unit_id, slots)).is_true()
	_input.call("_promote_intent_preview_after_commit")
	_director.flush_plan_refresh_signals_if_pending()
	_input.clear_qa_pointer_override()
	await runner.simulate_frames(2, _DELTA_MS)
	return slots


func _actual_click_cell(runner: GdUnitSceneRunner, cell: Vector2i) -> void:
	_input.set_qa_pointer_grid_cell(cell)
	_input.on_hover_moved(cell)
	await runner.simulate_frames(2, _DELTA_MS)
	var local: Vector2 = _input._mouse_local_for_facing()
	_input.on_left_press(local)
	await runner.simulate_frames(2, _DELTA_MS)
	_input.on_left_release(local)
	_director.flush_plan_refresh_signals_if_pending()
	_input.clear_qa_pointer_override()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)


func _assert_projected_mp_unchanged(unit_id: int, expected: int, label: String) -> void:
	var unit: UnitState = _director.projected_state.get_unit_by_id(unit_id)
	assert_object(unit).override_failure_message(
		"%s: unit %d projected state missing" % [label, unit_id],
	).is_not_null()
	if unit != null:
		assert_int(unit.movement.points_left).override_failure_message(
			"%s: unit %d MP changed during selection %d -> %d"
			% [label, unit_id, expected, unit.movement.points_left],
		).is_equal(expected)


func _case(skill_id: StringName) -> Dictionary:
	for item: Dictionary in _CASES:
		if item.id == skill_id:
			return item
	return {}


func _extra_players(skill_ids: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for skill_id: StringName in skill_ids:
		var position: Vector2i = _case(skill_id).actor
		if position != _ACTOR_CELL:
			result.append(position)
		if skill_id == &"archer_repelling_shot":
			continue
	if result.size() < 3:
		result.append(Vector2i(2, 8))
	return result


func _dummies(skill_ids: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for skill_id: StringName in skill_ids:
		var item := _case(skill_id)
		if item.kind == &"enemy":
			result.append(item.target)
	result.append_array([Vector2i(5, 6), Vector2i(7, 7)])
	return result


func _slots_invalid(slots: Dictionary) -> bool:
	var invalid: Variant = slots.get("invalid", false)
	return invalid is String or invalid == true


func _plan_has_ability(skill_id: StringName) -> bool:
	for action: TimelineAction in _director.get_player_plan().entries:
		if action.type == GameEnums.ActionType.ABILITY and action.ability != null:
			if action.ability.id == skill_id and not action.awaiting_target:
				return true
	return false


func _committed_post_move_for_unit(unit_id: int) -> TimelineAction:
	for action: TimelineAction in _director.plan_post_move.entries:
		if action != null and action.actor_id == unit_id and not action.awaiting_target:
			return action
	return null


func _assert_projection_matches_player_sim(
	runner: GdUnitSceneRunner,
	label: String,
) -> void:
	_director.flush_plan_refresh_signals_if_pending()
	await runner.simulate_frames(2, _DELTA_MS)
	var expected: BoardState = _director.base_board.clone()
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(expected, _director.get_player_plan(), events)
	var actual: BoardState = _director.projected_state
	assert_object(actual).override_failure_message(
		"%s: projected board missing" % label,
	).is_not_null()
	if actual == null:
		return
	for expected_unit: UnitState in expected.units:
		var actual_unit: UnitState = actual.get_unit_by_id(expected_unit.id)
		assert_object(actual_unit).override_failure_message(
			"%s: projected unit %d missing" % [label, expected_unit.id],
		).is_not_null()
		if actual_unit == null:
			continue
		assert_that(actual_unit.position).override_failure_message(
			"%s: unit %d position" % [label, expected_unit.id],
		).is_equal(expected_unit.position)
		assert_int(actual_unit.health.current_hp).override_failure_message(
			"%s: unit %d HP" % [label, expected_unit.id],
		).is_equal(expected_unit.health.current_hp)
		assert_int(actual_unit.armor).override_failure_message(
			"%s: unit %d armor" % [label, expected_unit.id],
		).is_equal(expected_unit.armor)
		assert_int(actual_unit.movement.points_left).override_failure_message(
			"%s: unit %d MP" % [label, expected_unit.id],
		).is_equal(expected_unit.movement.points_left)
		assert_int(actual_unit.ability.points_left).override_failure_message(
			"%s: unit %d AP" % [label, expected_unit.id],
		).is_equal(expected_unit.ability.points_left)


func _plan_has_awaiting(actor_id: int) -> bool:
	for action: TimelineAction in _director.get_player_plan().entries:
		if action.actor_id == actor_id and action.awaiting_target:
			return true
	return false


func _plan_debug() -> String:
	var ids: Array[String] = []
	for action: TimelineAction in _director.get_player_plan().entries:
		ids.append(
			"%s@%d%s" % [
				action.ability.id if action.ability != null else str(action.type),
				action.actor_id,
				":awaiting" if action.awaiting_target else "",
			],
		)
	return ",".join(ids)


func _slots_debug(slots: Dictionary) -> String:
	var result: Array[String] = []
	for column: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(column, []):
			if raw is TimelineAction:
				var action: TimelineAction = raw as TimelineAction
				result.append("%s=%s" % [column, action.ability.id if action.ability != null else str(action.type)])
	return ",".join(result)


func _ability_by_id(unit: UnitState, skill_id: StringName) -> AbilityData:
	if unit == null:
		return null
	for ability: AbilityData in unit.active_abilities:
		if ability != null and ability.id == skill_id:
			return ability
	return null


func _ability_index(unit: UnitState, ability: AbilityData) -> int:
	if unit == null or ability == null:
		return -1
	for index: int in range(unit.active_abilities.size()):
		var entry: AbilityData = unit.active_abilities[index]
		if entry != null and (entry == ability or entry.id == ability.id):
			return index
	return -1


func _unit_id_at(board: BoardState, cell: Vector2i) -> int:
	if board == null:
		return -1
	for unit: UnitState in board.units:
		if unit != null and unit.position == cell:
			return unit.id
	return -1


func test_live_volley_selected_allows_empty_tile_premove(timeout := 240000) -> void:
	## Player path: select Volley, then click an empty blue tile. Must walk, not steal aim.
	## `_commit_live_click` arms on self first, so it cannot catch this.
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_scene = runner.scene() as TestBattleMapView
	assert_object(_scene).is_not_null()
	if _scene == null:
		return
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"archer"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.passive_enabled.clear()
	session.skill_enabled.clear()
	session.set_all_passives_enabled(&"archer", false)
	session.set_all_skills_enabled(&"archer", true)
	session.extra_player_coords = []
	session.dummy_coords = [Vector2i(8, 5)]
	session.unkillable_dummies = true
	_scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)

	_director = _scene.get_node("CombatDirector") as CombatDirector
	var shell := _scene.get_node("CombatShell") as TacticalCombatShell
	_input = shell.planning_input
	_overlay = _scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	var archer_id: int = _unit_id_at(_director.base_board, _ACTOR_CELL)
	assert_int(archer_id).override_failure_message(
		"volley selected premove: Archer missing at %s" % _ACTOR_CELL,
	).is_greater(0)
	var archer: UnitState = _director.board.get_unit_by_id(archer_id)
	var volley: AbilityData = _ability_by_id(archer, &"archer_volley")
	assert_object(volley).override_failure_message(
		"volley selected premove: Volley missing",
	).is_not_null()
	if volley == null:
		return
	var walk_cell := Vector2i(5, 5)
	_director.select_unit(archer_id)
	_director.select_ability(_ability_index(archer, volley))
	await runner.simulate_frames(2, _DELTA_MS)
	assert_object(_director.find_awaiting_action(archer_id)).override_failure_message(
		"volley selected premove: selecting Volley must not auto-arm TARGET_PICK",
	).is_null()
	_input.set_qa_pointer_grid_cell(walk_cell)
	_input.on_hover_moved(walk_cell)
	await runner.simulate_frames(4, _DELTA_MS)
	assert_bool(_overlay.is_hover_move_tile(walk_cell)).override_failure_message(
		"volley selected premove: empty walk tile %s must stay blue with Volley selected"
		% walk_cell,
	).is_true()
	assert_bool(_input._is_hover_move_cell(archer, walk_cell)).override_failure_message(
		"volley selected premove: empty walk tile must count as a move hover",
	).is_true()
	await _actual_click_cell(runner, walk_cell)
	assert_int(_director.plan_pre_move.entries.size()).override_failure_message(
		"volley selected premove: click empty blue tile must write a pre-move; plan=%s"
		% _plan_debug(),
	).is_greater(0)
	var projected: UnitState = _director.projected_state.get_unit_by_id(archer_id)
	assert_object(projected).is_not_null()
	if projected != null:
		assert_that(projected.position).override_failure_message(
			"volley selected premove: projected stand must be %s, got %s"
			% [walk_cell, projected.position],
		).is_equal(walk_cell)


func test_live_archer_stationary_power_shot_then_direct_post_move(timeout := 240000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_scene = runner.scene() as TestBattleMapView
	assert_object(_scene).is_not_null()
	if _scene == null:
		return
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"archer"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.passive_enabled.clear()
	session.skill_enabled.clear()
	session.set_all_passives_enabled(&"archer", false)
	session.set_all_skills_enabled(&"archer", true)
	session.extra_player_coords = []
	session.dummy_coords = [Vector2i(7, 5)]
	session.unkillable_dummies = true
	_scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)

	_director = _scene.get_node("CombatDirector") as CombatDirector
	var shell := _scene.get_node("CombatShell") as TacticalCombatShell
	_input = shell.planning_input
	_overlay = _scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	var archer_id: int = _unit_id_at(_director.base_board, _ACTOR_CELL)
	var dummy_id: int = _unit_id_at(_director.base_board, Vector2i(7, 5))
	assert_int(archer_id).is_greater(0)
	assert_int(dummy_id).is_greater(0)

	var archer: UnitState = _director.board.get_unit_by_id(archer_id)
	var power_shot: AbilityData = _ability_by_id(archer, &"archer_power_shot")
	assert_object(power_shot).is_not_null()

	# 1. Select Power Shot and shoot Dummy at (7, 5) from stand (4, 5) without moving
	_director.select_unit(archer_id)
	_director.select_ability(_ability_index(archer, power_shot))
	await runner.simulate_frames(2, _DELTA_MS)
	await _actual_click_cell(runner, Vector2i(7, 5))

	assert_int(_director.plan_action.entries.size()).override_failure_message(
		"Power Shot should be committed in action column",
	).is_equal(1)
	assert_int(_director.plan_pre_move.entries.size()).override_failure_message(
		"Pre-move should be empty for stationary shot",
	).is_equal(0)

	# 2. Hover over (2, 5) (2 tiles west) and check live preview & MP display
	_input.set_qa_pointer_grid_cell(Vector2i(2, 5))
	_input.on_hover_moved(Vector2i(2, 5))
	await runner.simulate_frames(4, _DELTA_MS)
	var mp_left_hover: int = _input.planning_display_mp_left(archer_id)
	assert_int(mp_left_hover).override_failure_message(
		"Hovering 2 tiles away should deduct 2 MP (4 -> 2)",
	).is_equal(2)

	# 3. Direct click on empty ground tile (2, 5) for post-move
	await _actual_click_cell(runner, Vector2i(2, 5))

	assert_int(_director.plan_post_move.entries.size()).override_failure_message(
		"Direct click on empty tile should commit post-move",
	).is_equal(1)
	var post_action: TimelineAction = _director.plan_post_move.entries[0]
	assert_object(post_action).is_not_null()
	assert_that(post_action.target_coord).is_equal(Vector2i(2, 5))
	assert_int(post_action.move_timing).is_equal(GameEnums.MoveTiming.POST_ACTION)

	# 4. Verify projected board state and simulate whole turn
	await _assert_projection_matches_player_sim(runner, "archer_stationary_powershot_then_post_move")
	var proj_archer: UnitState = _director.projected_state.get_unit_by_id(archer_id)
	assert_that(proj_archer.position).is_equal(Vector2i(2, 5))
	assert_int(proj_archer.movement.points_left).is_equal(2)


func test_live_archer_steady_aim_auto_activates_on_extra_range(timeout := 240000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_scene = runner.scene() as TestBattleMapView
	assert_object(_scene).is_not_null()
	if _scene == null:
		return
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"archer"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.passive_enabled.clear()
	session.skill_enabled.clear()
	session.set_all_passives_enabled(&"archer", false)
	session.passive_enabled[&"lightfoot"] = true
	session.set_all_skills_enabled(&"archer", true)
	session.extra_player_coords = []
	session.dummy_coords = [Vector2i(7, 5)]
	session.unkillable_dummies = true
	_scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)

	_director = _scene.get_node("CombatDirector") as CombatDirector
	var shell := _scene.get_node("CombatShell") as TacticalCombatShell
	_input = shell.planning_input
	_overlay = _scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	var archer_id: int = _unit_id_at(_director.base_board, _ACTOR_CELL)
	assert_int(archer_id).is_greater(0)
	var archer: UnitState = _director.board.get_unit_by_id(archer_id)
	var snap: AbilityData = _ability_by_id(archer, &"archer_basic")
	assert_object(snap).is_not_null()
	_director.select_unit(archer_id)
	_director.select_ability(_ability_index(archer, snap))
	await runner.simulate_frames(2, _DELTA_MS)

	_input.set_qa_pointer_grid_cell(Vector2i(7, 5))
	_input.on_hover_moved(Vector2i(7, 5))
	_input._flush_hover_heavy_sync()
	await runner.simulate_frames(4, _DELTA_MS)
	var hover_icon: String = _input.compute_hover_action_icon(Vector2i(7, 5))
	assert_bool(hover_icon.find(PlanningIcons.GLYPH_RANGE) >= 0).override_failure_message(
		"Steady Aim extra-range hover cursor %s must show bow" % hover_icon,
	).is_true()
	var hover_slots: Dictionary = _input._intent_snapshot_slots
	var slot_icon: String = _input._cursor_icon_from_commit_slots(hover_slots, archer)
	assert_that(hover_icon).override_failure_message(
		"Steady Aim hover cursor %s != commit-slot cursor %s" % [hover_icon, slot_icon],
	).is_equal(slot_icon)
	assert_int(_input.planning_display_mp_left(archer_id)).override_failure_message(
		"Steady Aim extra-range hover must spend displayed MOV",
	).is_equal(0)

	await _actual_click_cell(runner, Vector2i(7, 5))
	assert_int(_director.plan_action.entries.size()).is_equal(1)
	var committed: TimelineAction = _director.plan_action.entries[0]
	assert_bool(committed.uses_steady_aim).override_failure_message(
		"Committed Snap Shot slot must keep Steady Aim marker",
	).is_true()
	var proj: UnitState = _director.projected_state.get_unit_by_id(archer_id)
	assert_int(proj.movement.points_left).override_failure_message(
		"Committed Steady Aim must leave 0 MOV",
	).is_equal(0)
	assert_bool(bool(proj.passive_flags.get("steady_aim_triggered", false))).is_true()
	assert_int(_input.planning_display_mp_left(archer_id)).is_equal(0)

