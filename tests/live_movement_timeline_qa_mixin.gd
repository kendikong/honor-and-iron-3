class_name LiveMovementTimelineQaMixin
extends RefCounted

## Live Tier-2: movement skills must commit PRE-MOVE or POST-MOVE legs + column contract.

const _HARNESS := preload("res://tests/movement_timeline_qa_harness.gd")
const _SETTLE_FRAMES: int = 8
const _DELTA_MS: int = 16


static func assert_committed(
	test_suite: GdUnitTestSuite,
	skill_id: StringName,
	director: CombatDirector,
	actor_id: int,
	ability: AbilityData,
	slots: Dictionary = {},
	input: CombatPlanningInput = null,
	overlay: TacticalPlanningOverlay = null,
	runner: GdUnitSceneRunner = null,
) -> void:
	if ability == null:
		return
	var actor: UnitState = director.board.get_unit_by_id(actor_id) if director != null else null
	var failures: Array[String] = _HARNESS.skill_timeline_qa_failures(
		String(skill_id), director, actor_id, ability, {}, actor,
	)
	test_suite.assert_bool(failures.is_empty()).override_failure_message(
		"%s: movement timeline QA failed: %s" % [skill_id, ", ".join(failures)],
	).is_true()
	if input != null:
		await assert_move_preview_origin_live(
			test_suite,
			runner,
			director,
			input,
			overlay,
			actor_id,
			ability,
			Vector2i(-999999, -999999),
			skill_id,
		)


static func assert_move_preview_origin_live(
	test_suite: GdUnitTestSuite,
	runner: GdUnitSceneRunner,
	director: CombatDirector,
	input: CombatPlanningInput,
	overlay: TacticalPlanningOverlay,
	actor_id: int,
	ability: AbilityData,
	hover_cell: Vector2i = Vector2i(-999999, -999999),
	skill_id: StringName = &"",
) -> void:
	if ability == null or not _HARNESS.ability_requires_movement_timeline_qa(ability):
		return
	var failures: Array[String] = []
	var fix: Dictionary = {
		"director": director,
		"input": input,
		"overlay": overlay,
		"board": director.board if director != null else null,
	}
	var label: String = String(skill_id) if skill_id != &"" else String(ability.id)
	_HARNESS.assert_move_preview_origin(
		failures, label, fix, actor_id, ability, hover_cell,
	)
	test_suite.assert_bool(failures.is_empty()).override_failure_message(
		"%s: move preview origin QA failed: %s" % [label, ", ".join(failures)],
	).is_true()
	if runner != null:
		await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)


static func commit_premove_run_if_needed(
	test_suite: GdUnitTestSuite,
	runner: GdUnitSceneRunner,
	director: CombatDirector,
	input: CombatPlanningInput,
	actor_id: int,
	ability: AbilityData,
	premove_cell: Vector2i,
	overlay: TacticalPlanningOverlay = null,
) -> void:
	if not _HARNESS.action_movement_needs_pre_or_post_leg(ability):
		return
	if _HARNESS.has_pre_or_post_leg(director, actor_id):
		return
	if premove_cell == Vector2i(-999999, -999999):
		return
	if director.get_planning_move_timing(actor_id) != GameEnums.MoveTiming.PRE_ACTION:
		return
	var actor: UnitState = director.board.get_unit_by_id(actor_id)
	if actor != null and actor.position == premove_cell:
		return
	await commit_universal_run(
		test_suite, runner, director, input, actor_id, premove_cell,
	)
	await assert_premove_run_preview_origin_live(
		test_suite, runner, director, input, overlay, actor_id, ability,
	)


static func commit_universal_run(
	test_suite: GdUnitTestSuite,
	runner: GdUnitSceneRunner,
	director: CombatDirector,
	input: CombatPlanningInput,
	actor_id: int,
	dest: Vector2i,
) -> Dictionary:
	director.select_unit(actor_id)
	var actor: UnitState = director.board.get_unit_by_id(actor_id)
	var run_idx: int = -1
	for i: int in range(actor.active_abilities.size()):
		var ab: AbilityData = actor.active_abilities[i] as AbilityData
		if ab != null and ab.is_universal_run():
			run_idx = i
			break
	if run_idx < 0:
		var run_ab: AbilityData = DataLibrary.get_universal_run()
		test_suite.assert_object(run_ab).override_failure_message(
			"universal Run missing for movement timeline QA leg",
		).is_not_null()
		return {"invalid": true}
	director.select_ability(run_idx)
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	director.select_unit(actor_id)
	input.set_qa_pointer_grid_cell(dest)
	if input._intent_state != null:
		input._intent_state.set_hover_coord(dest)
	var slots: Dictionary = input._final_commit_slots_for_click_at_cell(
		actor_id, dest, Vector2.ZERO,
	)
	test_suite.assert_bool(not bool(slots.get("invalid", false))).override_failure_message(
		"movement timeline Run leg invalid at %s: %s" % [dest, str(slots)],
	).is_true()
	if bool(slots.get("invalid", false)):
		return slots
	input.call("_paint_intent_slots_before_commit", actor_id, slots)
	test_suite.assert_bool(director.commit_from_slots(actor_id, slots)).override_failure_message(
		"movement timeline Run leg commit rejected: %s" % str(slots),
	).is_true()
	input.call("_promote_intent_preview_after_commit")
	director.flush_plan_refresh_signals_if_pending()
	input.clear_qa_pointer_override()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	return slots


static func assert_premove_run_preview_origin_live(
	test_suite: GdUnitTestSuite,
	runner: GdUnitSceneRunner,
	director: CombatDirector,
	input: CombatPlanningInput,
	overlay: TacticalPlanningOverlay,
	actor_id: int,
	ability: AbilityData,
	skill_id: StringName = &"",
) -> void:
	await assert_move_preview_origin_live(
		test_suite,
		runner,
		director,
		input,
		overlay,
		actor_id,
		ability,
		Vector2i(-999999, -999999),
		skill_id,
	)


static func default_premove_run_cell(actor_cell: Vector2i, target_cell: Vector2i) -> Vector2i:
	return _HARNESS.default_premove_run_cell(actor_cell, target_cell)


static func default_postmove_cell(actor_cell: Vector2i, target_cell: Vector2i) -> Vector2i:
	if actor_cell == target_cell:
		return actor_cell + Vector2i(-1, 0)
	var delta: Vector2i = target_cell - actor_cell
	var step := Vector2i(
		0 if delta.x == 0 else int(signf(float(delta.x))),
		0 if delta.y == 0 else int(signf(float(delta.y))),
	)
	return target_cell - step
