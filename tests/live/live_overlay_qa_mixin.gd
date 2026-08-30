class_name LiveOverlayQaMixin
extends RefCounted

## Shared Tier-2 overlay parity for live class tests (exact tile set + count).

const _AOE := preload("res://tests/aoe_footprint_qa_harness.gd")


static func sync_attack_hover(
	runner: GdUnitSceneRunner,
	input: CombatPlanningInput,
	overlay: TacticalPlanningOverlay,
	director: CombatDirector,
	cell: Vector2i,
	delta_ms: int = 16,
) -> void:
	input.set_qa_pointer_grid_cell(cell)
	if input._intent_state != null:
		input._intent_state.set_hover_coord(cell)
	overlay.set_hover_coord(cell, false)
	input.on_hover_moved(cell)
	input._flush_hover_heavy_sync()
	input.call("_refresh_selected_interaction_preview")
	overlay._recompute_hover_ranges_from_inputs()
	director.flush_plan_refresh_signals_if_pending()
	await runner.simulate_frames(3, delta_ms)


static func assert_live_overlay_parity(
	test_suite: Variant,
	runner: GdUnitSceneRunner,
	overlay: TacticalPlanningOverlay,
	input: CombatPlanningInput,
	director: CombatDirector,
	actor_id: int,
	ability: AbilityData,
	target_cell: Vector2i,
	label: StringName,
	delta_ms: int = 16,
) -> void:
	if not _AOE.ability_requires_footprint_qa(ability):
		return
	director.select_unit(actor_id)
	var actor := director.board.get_unit_by_id(actor_id)
	if actor == null or overlay == null:
		return
	if ability != null:
		var idx := actor.active_abilities.find(ability)
		if idx >= 0:
			director.select_ability(idx)
	## TILE AOE blast parity is an aim check. Unarmed hover on an empty walk tile
	## is premove (Volley range covers Archer MP), so arm TARGET_PICK for the
	## overlay snapshot only — restore afterward so later clicks still arm.
	var armed_for_parity: bool = false
	if (
		ability != null
		and director.find_awaiting_action(actor_id) == null
		and AbilitySystem.planning_commit_flow(actor, ability)
			== GameEnums.PlanningCommitFlow.AWAITING_TARGET
		and not AbilitySystem.ability_has_movement_effect(ability, actor)
		and (
			AbilitySystem.active_targeting_flags(actor, ability)
			& GameEnums.TargetingFlags.TILE
		) != 0
	):
		director.set_awaiting_action(actor_id, ability)
		armed_for_parity = true
		if director.has_method("flush_plan_refresh_signals_if_pending"):
			director.flush_plan_refresh_signals_if_pending()
	await sync_attack_hover(runner, input, overlay, director, target_cell, delta_ms)
	var plan_board: BoardState = director.board
	if director.projected_state != null:
		plan_board = director.projected_state
	var proj_actor := plan_board.get_unit_by_id(actor_id)
	if proj_actor == null:
		proj_actor = actor
	var stand: Vector2i = proj_actor.position
	var intent_stand: Vector2i = input.action_range_intent_stand_cell(actor_id)
	if intent_stand.x > -900:
		stand = intent_stand
	var expected: Array[Vector2i] = _AOE.expected_blast_tiles(
		plan_board, proj_actor, ability, stand, target_cell,
	)
	if expected.is_empty():
		if armed_for_parity:
			director.clear_awaiting_action(actor_id)
		return
	var err: String = _AOE.overlay_parity_error(overlay, expected, String(label))
	test_suite.assert_bool(err.is_empty()).override_failure_message(err).is_true()
	if armed_for_parity:
		director.clear_awaiting_action(actor_id)
