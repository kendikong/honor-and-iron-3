## Tier 2 live Monk acceptance — every active skill commits through preview slots.
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _OVERLAY_QA := preload("res://tests/live_overlay_qa_mixin.gd")
const _MOVEMENT_QA := preload("res://tests/live_movement_timeline_qa_mixin.gd")
const _CASES: Array[StringName] = [
	&"monk_leap",
	&"monk_scorching_kick",
	&"monk_thunder_palm",
	&"monk_yin_yang_flurry",
	&"monk_chakra_shift",
	&"monk_phase_throw",
	&"monk_flying_crane_kick",
	&"monk_spirit_palm",
	&"monk_soul_punch",
	&"monk_hundred_fists",
	&"monk_mantra_of_peace",
	&"monk_inner_fire",
	&"monk_void_step",
	&"monk_cyclone_sweep",
	&"monk_updraft",
	&"monk_geyser_strike",
]


func test_live_monk_every_skill(timeout := 600000) -> void:
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
		session.player_class_id = &"monk"
		session.player_level = TestBattleSession.TRAINING_LEVEL
		session.set_all_passives_enabled(&"monk", true)
		session.set_all_skills_enabled(&"monk", true)
		session.dummy_coords = _dummy_coords_for(ability_id)
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
		var actor_cell := _actor_cell_for(ability_id)
		var actor_id := _unit_id_at(director.base_board, actor_cell)
		assert_int(actor_id).override_failure_message(
			"%s: missing live Monk actor at %s" % [ability_id, actor_cell],
		).is_greater(-1)
		if actor_id < 0:
			continue
		var actor := director.board.get_unit_by_id(actor_id)
		var ability := _ability_by_id(actor, ability_id)
		assert_object(ability).override_failure_message(
			"%s: missing live Monk ability" % ability_id,
		).is_not_null()
		if ability == null:
			continue
		actor.ability.points_left = maxi(actor.ability.points_left, 1)
		actor.movement.points_left = maxi(actor.movement.points_left, 8)
		var target := _target_for(ability_id, ability, actor_cell)
		_prepare_live_board(director.base_board, ability_id, actor_cell, target)
		if director.board != director.base_board:
			_prepare_live_board(director.board, ability_id, actor_cell, target)
		var premove := _premove_cell_for(ability_id, actor_cell, target)
		if premove != Vector2i(-999999, -999999):
			await _MOVEMENT_QA.commit_universal_run(
				self, runner, director, input, actor_id, premove,
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


func _dummy_coords_for(ability_id: StringName) -> Array[Vector2i]:
	match ability_id:
		&"monk_leap":
			return [Vector2i(5, 5)]
		&"monk_phase_throw":
			return [Vector2i(5, 5)]
		&"monk_flying_crane_kick":
			return [Vector2i(7, 5)]
		&"monk_cyclone_sweep", &"monk_updraft", &"monk_geyser_strike":
			return [Vector2i(6, 5), Vector2i(7, 5)]
		_:
			return [Vector2i(6, 5)]


func _actor_cell_for(ability_id: StringName) -> Vector2i:
	match ability_id:
		&"monk_leap":
			return Vector2i(4, 5)
		&"monk_phase_throw":
			return Vector2i(4, 5)
		&"monk_flying_crane_kick":
			return Vector2i(2, 5)
		_:
			return Vector2i(4, 5)


func _premove_cell_for(
	ability_id: StringName,
	actor_cell: Vector2i,
	target: Vector2i,
) -> Vector2i:
	match ability_id:
		&"monk_leap":
			return Vector2i(-999999, -999999)
		_:
			if GridSystem.manhattan(actor_cell, target) > 1:
				return actor_cell + Vector2i(
					signi(target.x - actor_cell.x),
					signi(target.y - actor_cell.y),
				)
			return Vector2i(-999999, -999999)


func _prepare_live_board(
	board: BoardState,
	ability_id: StringName,
	actor_cell: Vector2i,
	target: Vector2i,
) -> void:
	match ability_id:
		&"monk_leap":
			var vault_cell := actor_cell + Vector2i(
				signi(target.x - actor_cell.x),
				signi(target.y - actor_cell.y),
			)
			if board.get_unit_at(vault_cell) == null:
				_spawn_dummy(board, vault_cell)
		&"monk_geyser_strike":
			board.set_tile_terrain(target, DataLibrary.get_terrain(&"water"))
		_:
			pass


func _spawn_dummy(board: BoardState, coord: Vector2i) -> void:
	if board.get_unit_at(coord) != null:
		return
	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	if dummy_def == null:
		return
	var unit_id := board.units.size() + 10
	var dummy := UnitState.create(unit_id, dummy_def, GameEnums.Team.ENEMY, coord)
	board.add_unit(dummy)
	GridSystem.set_occupant(board, coord, unit_id)


func _target_for(
	ability_id: StringName,
	ability: AbilityData,
	actor_cell: Vector2i,
) -> Vector2i:
	if ability.targeting_flags & GameEnums.TargetingFlags.SELF:
		return actor_cell
	match ability_id:
		&"monk_leap":
			return actor_cell + Vector2i(2, 0)
		&"monk_phase_throw":
			return actor_cell + Vector2i(1, 0)
		&"monk_flying_crane_kick":
			return actor_cell + Vector2i(3, 0)
		&"monk_void_step":
			return actor_cell + Vector2i(1, 0)
		&"monk_cyclone_sweep", &"monk_updraft":
			return actor_cell + Vector2i(2, 0)
		_:
			return actor_cell + Vector2i(2, 0)


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
