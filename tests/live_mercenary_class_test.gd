extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"


const _OVERLAY_QA := preload("res://tests/live_overlay_qa_mixin.gd")
const _MOVEMENT_QA := preload("res://tests/live_movement_timeline_qa_mixin.gd")
const _CASES: Array[StringName] = [
	&"mercenary_pullback", &"mercenary_swift_strike", &"mercenary_defense_strike",
	&"mercenary_blade_storm", &"mercenary_caltrop_toss", &"mercenary_feint",
	&"mercenary_riposte_strike", &"mercenary_sever", &"mercenary_second_wind",
	&"mercenary_tactical_retreat", &"mercenary_executioners_blade",
	&"mercenary_precision_strike", &"mercenary_flank_and_run",
	&"mercenary_hamstring", &"mercenary_acrobatic_vault",
	&"mercenary_duelists_challenge",
]


func test_live_mercenary_every_skill(timeout := 300000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(8, 16)
	var scene := runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	if scene == null:
		return
	var session: TestBattleSession = scene.get_session()
	for ability_id: StringName in _CASES:
		session.reset_defaults()
		session.player_class_id = &"mercenary"
		session.player_level = TestBattleSession.TRAINING_LEVEL
		session.passive_enabled.clear()
		session.skill_enabled.clear()
		session.set_all_passives_enabled(&"mercenary", true)
		session.set_all_skills_enabled(&"mercenary", true)
		session.dummy_coords = [Vector2i(6, 5), Vector2i(7, 5)]
		session.unkillable_dummies = true
		scene.apply_training_board()
		await runner.simulate_frames(8, 16)
		var director := scene.get_node("CombatDirector") as CombatDirector
		var shell := scene.get_node("CombatShell") as TacticalCombatShell
		var input: CombatPlanningInput = shell.planning_input
		input.auto_use_skill_after_move = true
		var overlay: TacticalPlanningOverlay = scene.get_node(
			"WorldModulate/MapRoot/PlanningOverlay",
		) as TacticalPlanningOverlay
		var actor_id := _unit_id_at(director.base_board, Vector2i(4, 5))
		assert_int(actor_id).override_failure_message(
			"%s: missing live Mercenary actor" % ability_id,
		).is_greater(-1)
		if actor_id < 0:
			continue
		var actor := director.board.get_unit_by_id(actor_id)
		var ability := _ability_by_id(actor, ability_id)
		assert_object(ability).override_failure_message(
			"%s: missing live Mercenary ability" % ability_id,
		).is_not_null()
		if ability == null:
			continue
		actor.ability.points_left = maxi(actor.ability.points_left, 1)
		actor.movement.points_left = maxi(actor.movement.points_left, 8)
		var target := _target_for(ability_id, ability)
		if _needs_premove(ability, actor, target):
			await _MOVEMENT_QA.commit_universal_run(
				self, runner, director, input, actor_id, Vector2i(5, 5),
			)
		director.select_unit(actor_id)
		director.select_ability(_ability_index(actor, ability))
		await runner.simulate_frames(2, 16)
		await _OVERLAY_QA.assert_live_overlay_parity(
			self, runner, overlay, input, director, actor_id, ability, target, ability_id,
		)
		var slots := await _commit_live_click(
			runner, director, input, actor_id, ability, target,
		)
		assert_bool(_slots_invalid(slots)).override_failure_message(
			"%s: preview rejected a Bible-valid target: %s" % [ability_id, str(slots)],
		).is_false()
		await _MOVEMENT_QA.assert_committed(
			self, ability_id, director, actor_id, ability, slots, input, overlay, runner,
		)


func _ability_by_id(actor: UnitState, ability_id: StringName) -> AbilityData:
	for ability: AbilityData in actor.active_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


func _ability_index(actor: UnitState, ability: AbilityData) -> int:
	for index: int in range(actor.active_abilities.size()):
		var candidate: AbilityData = actor.active_abilities[index]
		if candidate == ability or (
			candidate != null and ability != null and candidate.id == ability.id
		):
			return index
	return -1


func _unit_id_at(board: BoardState, coord: Vector2i) -> int:
	var unit := board.get_unit_at(coord)
	return unit.id if unit != null else -1


func _slots_invalid(slots: Dictionary) -> bool:
	var invalid: Variant = slots.get("invalid", false)
	if invalid is bool:
		return invalid
	if invalid is String:
		return not (invalid as String).is_empty()
	return not is_zero_approx(float(invalid))


func _commit_live_click(
	runner: GdUnitSceneRunner,
	director: CombatDirector,
	input: CombatPlanningInput,
	actor_id: int,
	ability: AbilityData,
	cell: Vector2i,
) -> Dictionary:
	director.select_unit(actor_id)
	var awaiting := director.find_awaiting_action(actor_id)
	if awaiting != null and awaiting.ability != null:
		var actor := director.board.get_unit_by_id(actor_id)
		director.select_ability(_ability_index(actor, awaiting.ability))
	input.set_qa_pointer_grid_cell(cell)
	input._intent_state.set_hover_coord(cell)
	input.on_hover_moved(cell)
	input._flush_hover_heavy_sync()
	var actor := director.board.get_unit_by_id(actor_id)
	var should_arm := (
		awaiting == null
		and AbilitySystem.planning_commit_flow(actor, ability)
			== GameEnums.PlanningCommitFlow.AWAITING_TARGET
	)
	var slots: Dictionary
	if should_arm:
		slots = input._final_commit_slots_for_click_at_cell(
			actor_id, actor.position, Vector2.ZERO,
		)
		if _slots_invalid(slots):
			return slots
		input.call("_paint_intent_slots_before_commit", actor_id, slots)
		var armed_ok := director.commit_from_slots(actor_id, slots)
		if not armed_ok:
			return {"invalid": "initial target arm rejected"}
		await runner.simulate_frames(2, 16)
	if director.find_awaiting_action(actor_id) != null:
		slots = input._build_commit_slots_at_cell(actor_id, cell)
	else:
		slots = input._final_commit_slots_for_click_at_cell(
			actor_id, cell, Vector2.ZERO,
		)
	if _slots_invalid(slots):
		return slots
	input.call("_paint_intent_slots_before_commit", actor_id, slots)
	if not director.commit_from_slots(actor_id, slots):
		var actions: Array[TimelineAction] = []
		for column: String in ["pre", "action", "post"]:
			for raw: Variant in slots.get(column, []):
				if raw is TimelineAction:
					actions.append(raw as TimelineAction)
		return {
			"invalid": "commit rejected preview slots: %s"
				% director.preview_commit_valid(actor_id, actions),
			"debug": str(slots),
		}
	input.call("_promote_intent_preview_after_commit")
	director.flush_plan_refresh_signals_if_pending()
	input.clear_qa_pointer_override()
	await runner.simulate_frames(2, 16)
	return slots


func _target_for(ability_id: StringName, ability: AbilityData) -> Vector2i:
	if ability.targeting_flags & GameEnums.TargetingFlags.SELF:
		return Vector2i(4, 5)
	match ability_id:
		&"mercenary_pullback":
			return Vector2i(3, 5)
		&"mercenary_tactical_retreat":
			return Vector2i(2, 5)
		&"mercenary_flank_and_run":
			return Vector2i(5, 4)
		_:
			return Vector2i(6, 5)


func _needs_premove(
	ability: AbilityData,
	actor: UnitState,
	target: Vector2i,
) -> bool:
	return (
		ability != null
		and actor != null
		and not AbilitySystem.ability_has_movement_effect(ability, actor)
		and ability.targeting_flags & GameEnums.TargetingFlags.ENEMY
		and GridSystem.manhattan(actor.position, target) > ability.range_tiles
	)
