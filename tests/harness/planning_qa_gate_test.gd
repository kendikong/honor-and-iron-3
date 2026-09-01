class_name PlanningQAGateTest
extends RefCounted

const HoverMatrix := preload("res://tests/harness/move_skill_hover_matrix_harness.gd")

## Automated mirror of the owner's manual planning QA checklist (Skill Arena / TestBattle).
## Asserts production planning, preview, commit-slot, cursor, and sim APIs — not pixel draw.

const KNIGHT_START := Vector2i(4, 5)
const ENEMY_POS := Vector2i(7, 5)
const BASH_APPROACH := Vector2i(6, 5)
const SHIELD_BASH_ID: StringName = &"knight_shield_bash"
const PHALANX_STANCE_ID: StringName = &"knight_phalanx_stance"
const CHAIN_HOOK_ID: StringName = &"knight_chain_hook"
const TRAMPLE_ID: StringName = &"knight_trampling_advance"
const BOWLING_CHARGE_ID: StringName = &"knight_bowling_charge"
const KNIGHT_SWAP_ID: StringName = &"knight_swap"
const ARCHER_SIDESTEP_ID: StringName = &"archer_sidestep"
const ARCHER_POWER_SHOT_ID: StringName = &"archer_power_shot"
const ARCHER_VOLLEY_ID: StringName = &"archer_volley"
const MAGE_TELEPORT_ID: StringName = &"mage_teleport"


static func run_all(failures: Array[String]) -> void:
	var tests: Array[Callable] = [
		_test_waypoint_paint_order_preserved_on_tile_drag,
		_test_jump_drag_autocorrect_preserves_painted_corridor,
		_test_stale_hover_updates_commit_waypoints,
		_test_cursor_walk_run_and_composite,
		_test_blue_move_tiles_on_walk_select,
		_test_locked_blue_stable_across_hovers,
		_test_locked_blue_visible_without_bundle,
		_test_bundle_mismatch_does_not_clear_locked_blue,
		_test_locked_blue_origin_after_premove,
		_test_locked_red_stable_across_hovers,
		_test_locked_red_visible_without_bundle,
		_test_bundle_mismatch_does_not_clear_locked_red,
		_test_planning_display_mp_left_contract,
		_test_committed_walk_preview_matches_sim_path,
		_test_shield_bash_enemy_hover_commit_slots,
		_test_shield_bash_push_away_from_player,
		_test_shield_bash_enemy_lands_at_push_destination,
		_test_shield_bash_enemy_hover_composite_cursor,
		_test_shield_bash_adjacent_painted_approach_hover,
		_test_shield_bash_hover_change_clears_stale_approach,
		_test_chain_hook_awaiting_targeting_segment,
		_test_chain_hook_pull_toward_player,
		_test_trampling_premove_then_arm_commit_flow,
		_test_trampling_unarmed_empty_hover_is_premove,
		_test_trampling_unarmed_hover_follows_mouse_waypoints,
		# Integrity extensions (headless-only; beyond manual checklist)
		_test_hover_slots_are_deterministic,
		_test_commit_plan_matches_hover_slots,
		_test_undo_action_keeps_premove,
		_test_premove_reposition_applies_live_board,
		_test_premove_beast_reposition_applies_live_board,
		_test_reposition_commit_clears_move_preview,
		_test_push_through_premove_moves_both_units,
		_test_push_through_hover_uses_shared_refresh_path,
		_test_push_through_repaths_off_expensive_walk,
		_test_move_preview_origin_premove_and_postmove,
		_test_charge_strike_composite_move_preview,
		_test_shield_bash_full_approach_push_preview,
		_test_committed_hook_approach_uses_premove,
		_test_out_of_range_hover_is_invalid,
		_test_trample_paint_preview_matches_route,
		_test_trample_commit_preserves_east_then_north,
		_test_trample_sim_follows_painted_order,
		_test_trample_repath_does_not_replace_painted_order,
		_test_trample_post_move_preview_commit_sim,
		_test_trample_full_preview_truth_click,
		_test_trample_full_phase_hover_matrix,
		_test_painted_route_premove_vs_move_equivalence,
		_test_teleport_full_preview_truth_click,
		# Intent-truth pipeline (preview = slots = commit = sim)
		_test_bash_slots_preview_board_parity,
		_test_hover_click_drop_slot_parity,
		_test_click_drop_parity_bash_enemy,
		_test_click_drop_parity_walk_adjacent,
		_test_click_drop_parity_bash_approach,
		_test_click_drop_parity_hook_enemy,
		_test_click_drop_parity_oob_invalid,
		_test_click_drop_cursor_parity_bash,
		_test_click_drop_cursor_parity_walk,
		_test_click_drop_commit_sim_bash,
		_test_click_drop_commit_sim_walk,
		_test_click_drop_drag_walk_sim_parity,
		_test_click_drop_drag_bash_enemy_parity,
		_test_k1_painted_route_enemy_click_keeps_waypoints,
		_test_drag_drop_commit_undo_clears_plan,
		_test_cursor_equals_slots_on_hover,
		_test_bash_commit_sim_push,
		_test_hook_commit_sim_pull,
		_test_invalid_slots_block_commit,
		_test_full_slot_signature_on_commit,
		_test_ability_switch_clears_preview_cache,
		_test_ability_select_refreshes_enemy_hover_path,
		_test_trample_paint_commit_sim_chain,
		_test_bash_sim_determinism,
		_test_hover_order_invariant,
		_test_drag_cleared_restores_canonical_bash_intent,
		_test_approach_bash_slots_preview_keeps_push,
		_test_timeline_ghost_clears_when_committed,
		_test_action_range_centered_on_live_stand,
		_test_action_range_hides_when_auto_run_blocks_skill_ap,
		_test_auto_run_stays_on_when_swap_armed,
		_test_action_range_hides_after_commit_run_icon,
		_test_action_range_shows_while_awaiting_trample,
		_test_action_range_shows_on_enemy_hover,
		_test_action_range_follows_cursor_on_move_hover,
		_test_enemy_skill_hover_not_movement_route,
		_test_self_skill_move_hover_no_attack_target,
		_test_enemy_bash_approach_move_leg,
		_test_bash_targeting_uses_pre_push_enemy_cell,
		_test_hook_pull_preview_keeps_attack_target,
		_test_class_skill_execute_spends_ap,
		_test_class_skill_player_turn_spends_ap,
		_test_bash_promote_locks_committed_ghost,
		_test_hook_in_range_approach_tile_is_actor_position,
		_test_hook_in_range_ignores_stale_drag_route,
		_test_hook_out_of_range_enemy_hover_invalid,
		_test_volley_awaiting_hover_damage_and_targeting_arrow,
		_test_volley_hover_damage_survives_board_changed,
		_test_undo_clears_stale_hover_damage_forecast,
		_test_selecting_unit_keeps_movement_points,
		_test_tile_targeting_forbids_premove,
		_test_selected_tile_aoe_allows_premove,
		_test_shaped_skill_red_range_yellow_blast,
		_test_zero_range_self_aoe_red_yellow_contract,
		_test_single_target_yellow_impact_tile,
		_test_bash_hover_keeps_targeting_arrow,
		_test_waypoint_premove_enemy_hover_full_truth,
		_test_sidestep_enemy_click_ratifies_move_preview,
		_test_sidestep_valid_tile_after_waypoint_premove,
		_test_waypoint_premove_then_tile_aoe_enemy_hover,
		_test_committed_premove_then_enemy_hover_click_preserves_intent,
		_test_painted_route_then_enemy_hover_click_preserves_intent,
		_test_range1_painted_route_enemy_hover_respects_waypoints,
		_test_movement_module_hover_uses_route_not_target_arrow,
		_test_planning_route_policy_enemy_hover_geometry,
		_test_out_of_range_enemy_hover_with_move_exhausted_shows_null_glyph_and_no_ghost,
		_test_post_move_after_variety_of_skills_contract,
		_test_steady_aim_auto_run_parity,
	]
	var names: PackedStringArray = [
		"waypoint_paint",
		"jump_autocorrect",
		"stale_hover",
		"cursor-glyphs",
		"blue_move_tiles",
		"mp_display_contract",
		"walk_sim",
		"bash_slots",
		"bash_push",
		"bash_threat",
		"bash_cursor",
		"bash_adjacent_painted",
		"bash_stale",
		"hook_segment",
		"hook_pull",
		"trample_flow",
		"trample_unarmed_hover",
		"trample_unarmed_hover_paint",
		"hover_deterministic",
		"commit_matches_hover",
		"undo_keeps_premove",
		"premove_live_board",
		"beast_reposition_live_board",
		"reposition_commit_clears_move_preview",
		"push_through_live_both",
		"push_through_hover_refresh",
		"push_through_repath",
		"move_preview_origin",
		"charge_strike_composite_preview",
		"bash_full_approach_push",
		"hook_committed_premove",
		"out_of_range_invalid",
		"trample_paint_preview",
		"trample_commit_wps",
		"trample_sim_order",
		"trample_repath_preserves_painted_order",
		"trample_post_move_truth",
		"trample_full_preview_truth_click",
		"trample_full_phase_hover_matrix",
		"painted_route_premove_vs_move_equivalence",
		"teleport_full_preview_truth_click",
		"bash_preview_board_parity",
		"hover_click_drop_parity",
		"click_drop_bash",
		"click_drop_walk",
		"click_drop_approach",
		"click_drop_hook",
		"click_drop_oob",
		"click_drop_cursor_bash",
		"click_drop_cursor_walk",
		"click_drop_sim_bash",
		"click_drop_sim_walk",
		"click_drop_drag_walk_sim",
		"click_drop_drag_bash",
		"k1_painted_click_waypoints",
		"drag_drop_undo",
		"cursor_equals_slots",
		"bash_commit_sim",
		"hook_commit_sim",
		"invalid_blocks_commit",
		"full_slot_signature",
		"ability_cache_clear",
		"ability_scroll_hover_path",
		"trample_full_chain",
		"bash_sim_determinism",
		"hover_order_invariant",
		"drag_cleared_intent",
		"approach_bash_push_preview",
		"timeline_ghost_commit",
		"action_range_live_stand",
		"action_range_auto_run_ap_gate",
		"auto_run_stays_on_when_swap_armed",
		"action_range_commit_run_icon_hide",
		"action_range_awaiting_trample",
		"action_range_enemy_hover",
		"action_range_move_hover_follows_cursor",
		"enemy_hover_not_move_route",
		"self_skill_move_no_target_arrow",
		"bash_enemy_approach_leg",
		"bash_target_pre_push_cell",
		"hook_pull_attack_target",
		"class_skill_execute_ap",
		"class_skill_player_turn_ap",
		"bash_promote_ghost",
		"hook_in_range_approach",
		"hook_in_range_no_stale_drag",
		"hook_out_of_range_null",
		"volley_hover_damage_arrow",
		"volley_hover_board_changed",
		"undo_clears_stale_damage",
		"selection_is_mp_read_only",
		"tile_aim_forbids_premove",
		"selected_tile_aoe_allows_premove",
		"shaped_skill_red_range_yellow_blast",
		"zero_range_self_aoe_red_yellow",
		"single_target_yellow_impact",
		"bash_hover_targeting_arrow",
		"waypoint_premove_enemy_hover_full_truth",
		"sidestep_enemy_click_ratifies_move",
		"sidestep_valid_tile_after_waypoint_premove",
		"waypoint_tile_aoe_enemy_hover",
		"committed_premove_enemy_click",
		"painted_route_enemy_click",
		"range1_painted_route_enemy_click",
		"movement_module_hover_route",
		"planning_route_policy_enemy_hover",
		"out_of_range_enemy_hover_exhausted",
		"post_move_after_skills",
		"steady_aim_auto_run_parity",
	]
	for i: int in range(tests.size()):
		print("[RUN] %s" % names[i])
		tests[i].call(failures)
		PlanningDragE2EHarness.cleanup_all()


static func _plain_board(size: Vector2i, units: Array[UnitState]) -> BoardState:
	var terrain := TerrainData.new()
	terrain.id = &"plain"
	terrain.blocks_movement = false
	var board := BoardState.new()
	board.grid_size = size
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, terrain)
	board.units = units
	for unit: UnitState in units:
		GridSystem.set_occupant(board, unit.position, unit.id)
	return board


static func _planning_fixture(
	knight_pos: Vector2i,
	enemy_pos: Vector2i = Vector2i(-1, -1),
) -> Dictionary:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var knight_def: UnitData = DataLibrary.get_unit(&"knight")
	var knight: UnitState = UnitState.create(1, knight_def, GameEnums.Team.PLAYER, knight_pos)
	knight.active_abilities = DataLibrary.build_training_abilities(knight_def)
	knight.movement.points_left = knight.movement.max_points
	knight.ability.points_left = 1
	knight.ability.max_points = 1
	var units: Array[UnitState] = [knight]
	if enemy_pos.x >= 0:
		var dummy_def: UnitData = DataLibrary.get_training_dummy()
		assert(dummy_def != null, "PlanningQAGate: training dummy definition missing")
		var enemy: UnitState = UnitState.create(
			2, dummy_def, GameEnums.Team.ENEMY, enemy_pos,
		)
		units.append(enemy)
	var board := _plain_board(Vector2i(12, 12), units)
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	input._director = director
	input.auto_use_skill_after_move = true
	var fix: Dictionary = {
		"input": input,
		"director": director,
		"board": board,
		"knight": knight,
		"enemy": units[1] if units.size() > 1 else null,
	}
	PlanningDragE2EHarness.track_raw_fixture(fix)
	return fix


static func _archer_volley_fixture(
	archer_pos: Vector2i,
	enemy_pos: Vector2i,
) -> Dictionary:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var volley: AbilityData = ArcherQaHarness.factory_ability(&"archer_volley")
	var archer_def: UnitData = ArcherQaHarness.archer_unit_data()
	var archer: UnitState = UnitState.create(1, archer_def, GameEnums.Team.PLAYER, archer_pos)
	archer.active_abilities = [volley]
	archer.movement.points_left = archer.movement.max_points
	archer.ability.points_left = maxi(1, archer.ability.max_points)
	archer.ability.max_points = maxi(1, archer.ability.max_points)
	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	var enemy: UnitState = UnitState.create(2, dummy_def, GameEnums.Team.ENEMY, enemy_pos)
	var units: Array[UnitState] = [archer, enemy]
	var board := _plain_board(Vector2i(12, 12), units)
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	director.selected_ability_index = 0
	input._director = director
	input.auto_use_skill_after_move = true
	var fix: Dictionary = {
		"input": input,
		"director": director,
		"board": board,
		"archer": archer,
		"knight": archer,
		"enemy": enemy,
		"volley": volley,
	}
	PlanningDragE2EHarness.track_raw_fixture(fix)
	return fix


static func _mage_teleport_fixture(start: Vector2i, target: Vector2i) -> Dictionary:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var mage_def: UnitData = FactoryTestHelpers.build_unit(&"mage")
	var mage: UnitState = UnitState.create(1, mage_def, GameEnums.Team.PLAYER, start)
	var teleport: AbilityData = null
	for ability: AbilityData in mage_def.abilities:
		if ability != null and ability.id == MAGE_TELEPORT_ID:
			teleport = ability
			break
	mage.active_abilities = [DataLibrary.get_universal_run(), teleport]
	mage.movement.points_left = mage.movement.max_points
	mage.ability.points_left = 1
	mage.ability.max_points = 1
	var board: BoardState = _plain_board(Vector2i(12, 12), [mage])
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = mage.id
	var teleport_idx: int = 1 if teleport != null else -1
	input._director = director
	input.auto_use_skill_after_move = true
	var fix: Dictionary = {
		"input": input,
		"director": director,
		"board": board,
		"mage": mage,
		"knight": mage,
		"teleport": mage.active_abilities[teleport_idx] if teleport_idx >= 0 else null,
		"teleport_idx": teleport_idx,
		"start": start,
		"target": target,
	}
	var wired: Dictionary = PlanningDragE2EHarness.wire_fixture(fix)
	if teleport_idx >= 0:
		director.select_ability(teleport_idx)
	return wired


static func _archer_power_shot_fixture(
	archer_pos: Vector2i,
	enemy_pos: Vector2i,
) -> Dictionary:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var power_shot: AbilityData = ArcherQaHarness.factory_ability(ARCHER_POWER_SHOT_ID)
	var archer_def: UnitData = ArcherQaHarness.archer_unit_data()
	var archer: UnitState = UnitState.create(
		1, archer_def, GameEnums.Team.PLAYER, archer_pos,
	)
	archer.active_abilities = [power_shot]
	archer.movement.points_left = archer.movement.max_points
	archer.ability.points_left = maxi(1, archer.ability.max_points)
	archer.ability.max_points = maxi(1, archer.ability.max_points)
	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	var enemy: UnitState = UnitState.create(2, dummy_def, GameEnums.Team.ENEMY, enemy_pos)
	var board: BoardState = _plain_board(Vector2i(12, 12), [archer, enemy])
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = archer.id
	director.selected_ability_index = 0
	input._director = director
	input.auto_use_skill_after_move = true
	var fix: Dictionary = {
		"input": input,
		"director": director,
		"board": board,
		"archer": archer,
		"knight": archer,
		"enemy": enemy,
		"power_shot": power_shot,
	}
	return PlanningDragE2EHarness.wire_fixture(fix)


static func _knight_shield_bash_fixture(
	knight_pos: Vector2i,
	enemy_pos: Vector2i,
) -> Dictionary:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var bash: AbilityData = KnightQaHarness.factory_ability(&"knight_shield_bash")
	var knight_def: UnitData = DataLibrary.get_unit(&"knight")
	var knight: UnitState = UnitState.create(
		1, knight_def, GameEnums.Team.PLAYER, knight_pos,
	)
	knight.active_abilities = [bash]
	knight.movement.max_points = 4
	knight.movement.points_left = 4
	knight.ability.points_left = maxi(1, knight.ability.max_points)
	knight.ability.max_points = maxi(1, knight.ability.max_points)
	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	var enemy: UnitState = UnitState.create(2, dummy_def, GameEnums.Team.ENEMY, enemy_pos)
	var board: BoardState = _plain_board(Vector2i(12, 12), [knight, enemy])
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = knight.id
	director.selected_ability_index = 0
	input._director = director
	input.auto_use_skill_after_move = true
	var fix: Dictionary = {
		"input": input,
		"director": director,
		"board": board,
		"archer": knight,
		"knight": knight,
		"enemy": enemy,
		"bash": bash,
		"power_shot": bash,
	}
	return PlanningDragE2EHarness.wire_fixture(fix)


static func _archer_skill_fixture(
	archer_pos: Vector2i,
	enemy_pos: Vector2i,
	ability_id: StringName,
) -> Dictionary:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var ability: AbilityData = ArcherQaHarness.factory_ability(ability_id)
	var archer_def: UnitData = ArcherQaHarness.archer_unit_data()
	var archer: UnitState = UnitState.create(
		1, archer_def, GameEnums.Team.PLAYER, archer_pos,
	)
	archer.active_abilities = [ability]
	archer.movement.points_left = archer.movement.max_points
	archer.ability.points_left = maxi(1, archer.ability.max_points)
	archer.ability.max_points = maxi(1, archer.ability.max_points)
	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	var enemy: UnitState = UnitState.create(2, dummy_def, GameEnums.Team.ENEMY, enemy_pos)
	var board: BoardState = _plain_board(Vector2i(12, 12), [archer, enemy])
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = archer.id
	director.selected_ability_index = 0
	input._director = director
	input.auto_use_skill_after_move = true
	return PlanningDragE2EHarness.wire_fixture({
		"input": input,
		"director": director,
		"board": board,
		"archer": archer,
		"knight": archer,
		"enemy": enemy,
		"ability": ability,
	})


static func _commit_slots_at(
	input: CombatPlanningInput,
	unit_id: int,
	cell: Vector2i,
	waypoints: Array[Vector2i] = [],
) -> Dictionary:
	var empty_legal: Array[Vector2i] = []
	return input._final_commit_slots_for_interaction(
		unit_id, cell, waypoints, empty_legal, Vector2i(-999999, -999999),
	)


static func _clear_drag_state(input: CombatPlanningInput) -> void:
	input.dragging = false
	input._drag_route.clear()
	input._drag_unit_id = -1
	input._drag_last_free = Vector2i(-999999, -999999)
	input._drag_unit_was_selected = false


static func _click_slots_at(
	input: CombatPlanningInput,
	unit_id: int,
	cell: Vector2i,
) -> Dictionary:
	return input._final_commit_slots_for_click_at_cell(unit_id, cell, Vector2.ZERO)


static func _drop_slots_at(
	input: CombatPlanningInput,
	unit_id: int,
	cell: Vector2i,
) -> Dictionary:
	var legal_moves: Array[Vector2i] = []
	if input._drag_route_commits_active():
		legal_moves = input._snapshot_drag_legal_move_tiles()
	return input._final_commit_slots_for_drop_at_cell(
		unit_id, cell, Vector2.ZERO, legal_moves,
	)


static func _assert_click_drop_signature_parity(
	failures: Array[String],
	label: String,
	input: CombatPlanningInput,
	unit_id: int,
	cell: Vector2i,
) -> void:
	var click_slots: Dictionary = _click_slots_at(input, unit_id, cell)
	var drop_slots: Dictionary = _drop_slots_at(input, unit_id, cell)
	if _intent_slot_signature(click_slots) != _intent_slot_signature(drop_slots):
		failures.append(
			"PlanningQAGate click/drop parity %s: selection vs drop slots differ %s vs %s"
			% [label, _intent_slot_signature(click_slots), _intent_slot_signature(drop_slots)],
		)


static func _sim_unit_position_after_slots_commit(
	director: CombatDirector,
	unit_id: int,
	slots: Dictionary,
) -> Vector2i:
	if _slots_invalid(slots):
		return Vector2i(-999999, -999999)
	if not director.commit_from_slots(unit_id, slots):
		return Vector2i(-999998, -999998)
	director.flush_plan_refresh_signals_if_pending()
	var result: SimResult = _simulate_committed_plan(director)
	var unit: UnitState = result.final_state.get_unit_by_id(unit_id)
	if unit == null:
		return Vector2i(-999997, -999997)
	return unit.position


static func _sim_enemy_position_after_slots_commit(
	director: CombatDirector,
	actor_id: int,
	enemy_id: int,
	slots: Dictionary,
) -> Vector2i:
	if _slots_invalid(slots):
		return Vector2i(-999999, -999999)
	if not director.commit_from_slots(actor_id, slots):
		return Vector2i(-999998, -999998)
	director.flush_plan_refresh_signals_if_pending()
	var result: SimResult = _simulate_committed_plan(director)
	var enemy: UnitState = result.final_state.get_unit_by_id(enemy_id)
	if enemy == null:
		return Vector2i(-999997, -999997)
	return enemy.position


static func _actions_from_slots(slots: Dictionary) -> Array[TimelineAction]:
	var actions: Array[TimelineAction] = []
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if raw is TimelineAction:
				actions.append(raw as TimelineAction)
	return actions


static func _arm_awaiting_at(
	input: CombatPlanningInput,
	director: CombatDirector,
	stand_cell: Vector2i,
) -> bool:
	var arm_slots: Dictionary = _commit_slots_at(input, 1, stand_cell)
	if bool(arm_slots.get("invalid", true)):
		return false
	if not director.commit_from_slots(1, arm_slots):
		return false
	director.flush_plan_refresh_signals_if_pending()
	return input.awaiting_targeting_active()


static func _slots_invalid(slots: Dictionary) -> bool:
	var flag: Variant = slots.get("invalid", false)
	if flag is bool:
		return flag
	if flag is String:
		return not (flag as String).is_empty()
	return bool(flag)


static func _slots_have_move(slots: Dictionary) -> bool:
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if raw is TimelineAction and (raw as TimelineAction).type == GameEnums.ActionType.MOVE:
				return true
	return false


static func _assert_hover_move_preview_contract(
	failures: Array[String],
	label: String,
	overlay: TacticalPlanningOverlay,
	actor: UnitState,
	expected_route: Array,
	suppress_target_arrow: bool = false,
	expected_stand: Vector2i = Vector2i(-999999, -999999),
) -> void:
	var live: CombatPlanningPreview = overlay.get_live_preview()
	if live == null:
		failures.append("%s: live preview missing" % label)
		return
	var preview_path: Array = live.preview_paths.get(actor.id, [])
	if preview_path != expected_route:
		failures.append(
			"%s: preview_paths %s expected %s"
			% [label, str(preview_path), str(expected_route)],
		)
	var draw_route: Array = overlay._interaction_move_route(actor.id, live, preview_path)
	if draw_route != expected_route:
		failures.append(
			"%s: drawn hover move route %s expected %s (preview_paths=%s arrow=%s)"
			% [
				label,
				str(draw_route),
				str(expected_route),
				str(preview_path),
				str(overlay.targeting_intent_arrow_cells()),
			],
		)
	for i: int in range(1, draw_route.size()):
		if GridSystem.manhattan(draw_route[i - 1], draw_route[i]) != 1:
			failures.append(
				"%s: drawn hover move route contains diagonal step %s"
				% [label, str(draw_route)],
			)
			break
	if suppress_target_arrow and not overlay.targeting_intent_arrow_cells().is_empty():
		failures.append(
			"%s: movement module must not draw targeting arrow %s"
			% [label, str(overlay.targeting_intent_arrow_cells())],
		)
	if expected_stand.x > -999999:
		var stand: Vector2i = overlay._intent_stand_origin(actor)
		if stand != expected_stand:
			failures.append(
				"%s: intent stand %s expected %s"
				% [label, stand, expected_stand],
			)


static func _orbit_hover_cells(
	board: BoardState,
	center: Vector2i,
	radius: int = 2,
	include_center: bool = false,
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen: Dictionary = {}
	if include_center:
		seen[center] = true
		out.append(center)
	for ring: int in range(1, radius + 1):
		for dx: int in range(-ring, ring + 1):
			for dy: int in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var cell: Vector2i = center + Vector2i(dx, dy)
				if seen.has(cell) or not board.is_in_bounds(cell):
					continue
				seen[cell] = true
				out.append(cell)
	return out


static func _assert_preview_route_cardinal_only(
	failures: Array[String],
	label: String,
	route: Array,
) -> void:
	for step_index: int in range(1, route.size()):
		var a: Vector2i = route[step_index - 1] as Vector2i
		var b: Vector2i = route[step_index] as Vector2i
		if GridSystem.manhattan(a, b) != 1:
			failures.append(
				"%s: preview route contains diagonal step %s -> %s in %s"
				% [label, a, b, str(route)],
			)
			return


static func _assert_path_excludes_bleed_cells(
	failures: Array[String],
	label: String,
	path: Array,
	forbidden_cells: Array[Vector2i],
) -> void:
	for forbidden: Vector2i in forbidden_cells:
		if path.has(forbidden):
			failures.append(
				"%s: path %s bleeds forbidden cell %s"
				% [label, str(path), forbidden],
			)


static func _assert_targeting_arrow_contract(
	failures: Array[String],
	label: String,
	overlay: TacticalPlanningOverlay,
	allow_arrow: bool,
	expected_from: Vector2i = Vector2i(-999999, -999999),
) -> void:
	var arrow_cells: Array[Vector2i] = overlay.targeting_intent_arrow_cells()
	if not allow_arrow:
		if not arrow_cells.is_empty():
			failures.append(
				"%s: must not draw targeting arrow %s"
				% [label, str(arrow_cells)],
			)
		return
	if arrow_cells.size() < 2:
		return
	var from_cell: Vector2i = arrow_cells[0] as Vector2i
	var to_cell: Vector2i = arrow_cells[1] as Vector2i
	if expected_from.x > -900000 and from_cell != expected_from:
		failures.append(
			"%s: targeting arrow origin %s expected %s (arrow=%s)"
			% [label, from_cell, expected_from, str(arrow_cells)],
		)
	if from_cell.x != to_cell.x and from_cell.y != to_cell.y:
		failures.append(
			"%s: targeting arrow is diagonal %s -> %s"
			% [label, from_cell, to_cell],
		)


static func _assert_slots_have_no_column_bleed(
	failures: Array[String],
	label: String,
	slots: Dictionary,
	forbidden_columns: Array[String],
) -> void:
	for column_name: String in forbidden_columns:
		var column_actions: Array = slots.get(column_name, []) as Array
		if not column_actions.is_empty():
			failures.append(
				"%s: slots leaked timeline column '%s' %s"
				% [label, column_name, str(column_actions)],
			)


static func _assert_charge_strike_hover_visual_contract(
	failures: Array[String],
	label: String,
	overlay: TacticalPlanningOverlay,
	input: CombatPlanningInput,
	actor: UnitState,
	allow_target_arrow: bool,
	expected_arrow_from: Vector2i = Vector2i(-999999, -999999),
) -> void:
	var live: CombatPlanningPreview = overlay.get_live_preview()
	var preview_path: Array = live.preview_paths.get(actor.id, []) if live != null else []
	var draw_route: Array = (
		overlay._interaction_move_route(actor.id, live, preview_path)
		if live != null else []
	)
	_assert_preview_route_cardinal_only(failures, label + "/preview_paths", preview_path)
	_assert_preview_route_cardinal_only(failures, label + "/draw_route", draw_route)
	_assert_targeting_arrow_contract(
		failures, label, overlay, allow_target_arrow, expected_arrow_from,
	)
	if preview_path.size() == 2:
		var seg_a: Vector2i = preview_path[0] as Vector2i
		var seg_b: Vector2i = preview_path[1] as Vector2i
		if seg_a.x != seg_b.x and seg_a.y != seg_b.y:
			failures.append(
				"%s: live preview is a diagonal shortcut %s -> %s"
				% [label, seg_a, seg_b],
			)
	if draw_route.size() == 2:
		var draw_a: Vector2i = draw_route[0] as Vector2i
		var draw_b: Vector2i = draw_route[1] as Vector2i
		if draw_a.x != draw_b.x and draw_a.y != draw_b.y:
			failures.append(
				"%s: drawn move route is a diagonal shortcut %s -> %s"
				% [label, draw_a, draw_b],
			)
	var input_path: Array = input.preview_state.preview_paths.get(actor.id, [])
	_assert_preview_route_cardinal_only(failures, label + "/input_preview_paths", input_path)


static func _diagonal_neighbor_cells(
	board: BoardState,
	center: Vector2i,
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for off: Vector2i in [
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]:
		var cell: Vector2i = center + off
		if board.is_in_bounds(cell):
			out.append(cell)
	return out


static func _probe_charge_strike_hover_orbit(
	failures: Array[String],
	fix: Dictionary,
	overlay: TacticalPlanningOverlay,
	input: CombatPlanningInput,
	actor: UnitState,
	label_prefix: String,
	orbit_cells: Array[Vector2i],
	phase: String,
	stand_cell: Vector2i,
	charge_route: Array[Vector2i],
	enemy_cell: Vector2i,
	pre_route: Array[Vector2i],
	post_route: Array[Vector2i],
	charge_strike_id: StringName,
	update_drag: bool = false,
) -> void:
	var premove_bleed_cells: Array[Vector2i] = pre_route.slice(0, pre_route.size() - 1)
	var charge_bleed_cells: Array[Vector2i] = charge_route.slice(0, charge_route.size() - 1)
	var postmove_only_bleed: Array[Vector2i] = post_route.slice(1)
	var post_full_bleed: Array[Vector2i] = []
	post_full_bleed.append_array(premove_bleed_cells)
	post_full_bleed.append_array(charge_bleed_cells)
	var previous: Vector2i = stand_cell
	for cell_index: int in range(orbit_cells.size()):
		var cell: Vector2i = orbit_cells[cell_index]
		PlanningChecklistHarness.sweep_to_cell(fix, cell, previous)
		if update_drag:
			input.update_drag(fix.map_stub.grid_to_local(cell))
		input._flush_hover_heavy_sync()
		PlanningChecklistHarness.flush_planning(fix)
		var probe_label: String = "%s/%s_orbit/%s" % [label_prefix, phase, cell]
		var live: CombatPlanningPreview = overlay.get_live_preview()
		var preview_path: Array = live.preview_paths.get(actor.id, []) if live != null else []
		var allow_arrow: bool = phase == "damage" and cell == enemy_cell
		var arrow_from: Vector2i = charge_route.back() if allow_arrow else Vector2i(-999999, -999999)
		_assert_charge_strike_hover_visual_contract(
			failures,
			probe_label,
			overlay,
			input,
			actor,
			allow_arrow,
			arrow_from,
		)
		var strike_ability: AbilityData = _ability_for_id(actor, charge_strike_id)
		var matrix_config: Dictionary = _charge_strike_matrix_config(
			phase,
			label_prefix,
			actor,
			strike_ability,
			stand_cell,
			charge_route,
			enemy_cell,
			post_route,
			update_drag,
			cell,
		)
		HoverMatrix.assert_hover_layers(
			failures, fix, probe_label, matrix_config, cell,
		)
		if phase == "move" or phase == "move_drag":
			if not update_drag and input._can_move_to(actor, cell):
				var expected_path: Array[Vector2i] = _expected_move_module_corridor_path(
					input, actor, cell, stand_cell,
				)
				if preview_path != expected_path:
					failures.append(
						"%s: MOVE module orbit preview %s expected corridor %s"
						% [probe_label, str(preview_path), str(expected_path)],
					)
				if not input.get_drag_route().is_empty():
					failures.append(
						"%s: MOVE module orbit must not accumulate hover drag route %s"
						% [probe_label, str(input.get_drag_route())],
					)
			_assert_path_excludes_bleed_cells(
				failures,
				probe_label + "/no_premove_bleed",
				preview_path,
				premove_bleed_cells,
			)
			_assert_path_excludes_bleed_cells(
				failures,
				probe_label + "/no_postmove_bleed",
				preview_path,
				postmove_only_bleed,
			)
			if not preview_path.is_empty():
				var path_start: Vector2i = preview_path[0] as Vector2i
				if path_start != stand_cell:
					failures.append(
						"%s: MOVE preview must start at module stand %s got %s"
						% [probe_label, stand_cell, path_start],
					)
			var hover_slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, cell)
			_assert_slots_have_no_column_bleed(
				failures, probe_label + "/slots", hover_slots, ["pre", "post"],
			)
			if cell == charge_route.back():
				_assert_hover_move_preview_contract(
					failures,
					probe_label,
					overlay,
					actor,
					charge_route,
					true,
					stand_cell,
				)
		elif phase == "damage":
			_assert_path_excludes_bleed_cells(
				failures,
				probe_label + "/no_premove_bleed",
				preview_path,
				premove_bleed_cells,
			)
			_assert_path_excludes_bleed_cells(
				failures,
				probe_label + "/no_charge_intermediate_bleed",
				preview_path,
				charge_bleed_cells,
			)
			_assert_path_excludes_bleed_cells(
				failures,
				probe_label + "/no_postmove_bleed",
				preview_path,
				postmove_only_bleed,
			)
			if not preview_path.is_empty() and preview_path != [charge_route.back()]:
				failures.append(
					"%s: DAMAGE preview must be frozen landing only %s got %s"
					% [probe_label, charge_route.back(), str(preview_path)],
				)
			var damage_slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, cell)
			_assert_slots_have_no_column_bleed(
				failures, probe_label + "/slots", damage_slots, ["pre", "post"],
			)
			if cell == enemy_cell:
				if preview_path != [charge_route.back()]:
					failures.append(
						"%s: DAMAGE enemy hover preview_paths %s expected [%s]"
						% [probe_label, str(preview_path), str(charge_route.back())],
					)
				var intent_stand: Vector2i = overlay._intent_stand_origin(actor)
				if intent_stand != charge_route.back():
					failures.append(
						"%s: DAMAGE enemy hover intent stand %s expected landing %s"
						% [probe_label, intent_stand, charge_route.back()],
					)
				if _slots_invalid(damage_slots):
					failures.append("%s: enemy hover slots invalid" % probe_label)
				else:
					var action: TimelineAction = _slot_action_with_ability(damage_slots, charge_strike_id)
					if action == null:
						failures.append("%s: enemy hover action missing" % probe_label)
					elif AbilitySystem.module_target_coord(action, 1) != enemy_cell:
						failures.append(
							"%s: enemy strike target %s expected %s"
							% [
								probe_label,
								AbilitySystem.module_target_coord(action, 1),
								enemy_cell,
							],
						)
		elif phase == "postmove" or phase == "postmove_drag":
			_assert_path_excludes_bleed_cells(
				failures,
				probe_label + "/no_charge_bleed",
				preview_path,
				charge_bleed_cells,
			)
			_assert_path_excludes_bleed_cells(
				failures,
				probe_label + "/no_premove_bleed",
				preview_path,
				premove_bleed_cells,
			)
			if not preview_path.is_empty():
				var post_start: Vector2i = preview_path[0] as Vector2i
				if post_start != post_route[0]:
					failures.append(
						"%s: postmove preview must start at action landing %s got %s"
						% [probe_label, post_route[0], post_start],
					)
			_assert_targeting_arrow_contract(
				failures, probe_label + "/post_arrow", overlay, false,
			)
			var post_slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, cell)
			_assert_slots_have_no_column_bleed(
				failures, probe_label + "/slots", post_slots, ["action"],
			)
			if cell == post_route.back():
				_assert_hover_move_preview_contract(
					failures,
					probe_label,
					overlay,
					actor,
					post_route,
					true,
					post_route[0],
				)
		previous = cell


static func _ability_for_id(actor: UnitState, ability_id: StringName) -> AbilityData:
	for raw: Variant in actor.active_abilities:
		var ability: AbilityData = raw as AbilityData
		if ability != null and ability.id == ability_id:
			return ability
	return null


static func _charge_strike_matrix_config(
	phase: String,
	label_prefix: String,
	actor: UnitState,
	ability: AbilityData,
	stand_cell: Vector2i,
	charge_route: Array[Vector2i],
	enemy_cell: Vector2i,
	post_route: Array[Vector2i],
	update_drag: bool,
	hover_cell: Vector2i,
) -> Dictionary:
	var config: Dictionary = {
		"label_prefix": label_prefix,
		"phase": phase,
		"actor": actor,
		"ability": ability,
		"stand_cell": stand_cell,
		"update_drag": update_drag,
		"suppress_target_arrow": true,
		"allow_target_arrow_at": Vector2i(-999999, -999999),
		"arrow_from": charge_route.back(),
	}
	match phase:
		"premove_hover", "premove_drag":
			config["ability"] = null
			config["expect_red"] = false
			config["expect_blue"] = true
			config["move_preview_kind"] = "drag_painted" if update_drag else "corridor"
			config["check_empty_drag_route"] = not update_drag
			config["check_module_stand"] = false
			config["expect_awaiting_move_route"] = false
		"move", "move_drag":
			config["expect_red"] = true
			config["expect_blue"] = true
			config["move_preview_kind"] = "drag_painted" if update_drag else "corridor"
			config["check_empty_drag_route"] = not update_drag
			config["check_module_stand"] = true
			config["expect_awaiting_move_route"] = not update_drag
		"damage":
			config["expect_red"] = true
			config["expect_blue"] = false
			config["move_preview_kind"] = "frozen_landing"
			config["frozen_cell"] = charge_route.back()
			config["allow_target_arrow_at"] = enemy_cell
			config["suppress_target_arrow"] = hover_cell != enemy_cell
			config["check_module_stand"] = false
			config["expect_awaiting_move_route"] = false
		"postmove", "postmove_drag":
			config["ability"] = null
			config["expect_red"] = false
			config["expect_blue"] = true
			config["move_preview_kind"] = "drag_painted" if update_drag else "postmove_corridor"
			config["post_start"] = post_route[0]
			config["check_module_stand"] = false
			config["expect_awaiting_move_route"] = false
		_:
			config["expect_red"] = false
			config["expect_blue"] = false
			config["move_preview_kind"] = "none"
	return config


static func _dedupe_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen: Dictionary = {}
	for cell: Vector2i in cells:
		if seen.has(cell):
			continue
		seen[cell] = true
		out.append(cell)
	return out


static func _hook_committed_approach_fixture() -> Dictionary:
	## Mirrors planning_input_test committed-action approach fixture (hook-only knight).
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var hook: AbilityData = _knight_ability(CHAIN_HOOK_ID)
	if hook == null:
		return {"input": null, "director": null, "knight": null, "enemy": null, "hook": null}
	var knight_def: UnitData = DataLibrary.get_unit(&"knight")
	var knight: UnitState = UnitState.create(1, knight_def, GameEnums.Team.PLAYER, Vector2i(0, 3))
	knight.active_abilities = [hook]
	knight.movement.points_left = 3
	knight.movement.max_points = 3
	knight.ability.points_left = 1
	knight.ability.max_points = 1
	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	var enemy: UnitState = UnitState.create(2, dummy_def, GameEnums.Team.ENEMY, Vector2i(4, 3))
	var units: Array[UnitState] = [knight, enemy]
	var board := _plain_board(Vector2i(10, 6), units)
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	director.selected_ability_index = 0
	director.plan_action.entries.append(
		TimelineAction.make_ability(
			1, hook, enemy.position, enemy.id, GameEnums.MoveTiming.PRE_ACTION, [],
		),
	)
	director.plan_affected_unit_ids = [1]
	director._refresh_plan()
	input._director = director
	input.auto_use_skill_after_move = true
	return {"input": input, "director": director, "knight": knight, "enemy": enemy, "hook": hook}


static func _ability_index(unit: UnitState, ability_id: StringName) -> int:
	for i: int in range(unit.active_abilities.size()):
		var ability: AbilityData = unit.active_abilities[i]
		if ability != null and ability.id == ability_id:
			return i
	return -1


static func _knight_ability(ability_id: StringName) -> AbilityData:
	var def: UnitData = DataLibrary.get_unit(&"knight")
	if def == null:
		return null
	for ability: AbilityData in def.abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


static func _preview_for_actions(
	director: CombatDirector,
	actions: Array[TimelineAction],
) -> CombatPlanningPreview:
	var preview := CombatPlanningPreview.new()
	var res: Dictionary = director.preview_actions(1, actions)
	preview.apply_result(res, director)
	return preview


static func _push_segment(pushes: Array) -> Array:
	if pushes.is_empty():
		return []
	var seg: Variant = pushes[pushes.size() - 1]
	return seg as Array if seg is Array else []


static func _pre_target(slots: Dictionary) -> Vector2i:
	var pre: Array = slots.get("pre", []) as Array
	if pre.is_empty():
		return Vector2i(-999, -999)
	var step: TimelineAction = pre[0] as TimelineAction
	return step.target_coord if step != null else Vector2i(-999, -999)


static func _action_target_unit(slots: Dictionary) -> int:
	var action_steps: Array = slots.get("action", []) as Array
	if action_steps.is_empty():
		return -1
	var step: TimelineAction = action_steps[0] as TimelineAction
	return step.target_unit_id if step != null else -1


static func _is_invalid(slots: Dictionary) -> bool:
	if not slots.has("invalid"):
		return false
	var inv: Variant = slots["invalid"]
	if typeof(inv) == TYPE_BOOL:
		return inv as bool
	if typeof(inv) == TYPE_STRING:
		return not (inv as String).is_empty()
	return true


static func _slot_signature(slots: Dictionary) -> String:
	return "%s|%s|%s" % [
		str(_pre_target(slots)),
		str(_action_target_unit(slots)),
		str(_is_invalid(slots)),
	]


static func _intent_slot_signature(slots: Dictionary) -> String:
	var pre_wps: String = "[]"
	var pre_ability: String = ""
	var pre: Array = slots.get("pre", []) as Array
	if not pre.is_empty() and pre[0] is TimelineAction:
		var pre_act: TimelineAction = pre[0] as TimelineAction
		pre_wps = str(pre_act.waypoints)
		if pre_act.ability != null:
			pre_ability = str(pre_act.ability.id)
	var action_ability: String = ""
	var action_wps: String = "[]"
	var action_steps: Array = slots.get("action", []) as Array
	if not action_steps.is_empty() and action_steps[0] is TimelineAction:
		var act: TimelineAction = action_steps[0] as TimelineAction
		action_ability = str(act.ability.id) if act.ability != null else ""
		action_wps = str(act.waypoints)
	if action_ability.is_empty():
		action_ability = pre_ability
	var post_count: int = (slots.get("post", []) as Array).size()
	return "%s|%s|%s|%s|%s|%d|%s" % [
		str(_pre_target(slots)),
		pre_wps,
		str(_action_target_unit(slots)),
		action_ability,
		action_wps,
		post_count,
		str(_slots_invalid(slots)),
	]


static func _preview_dict_from_cell(
	input: CombatPlanningInput,
	unit_id: int,
	cell: Vector2i,
) -> Dictionary:
	return input._preview_from_commit_slots_at_cell(
		unit_id, cell, [] as Array[Vector2i], [] as Array[Vector2i], Vector2i(-999999, -999999),
	)


static func _preview_from_dict(
	director: CombatDirector,
	preview_dict: Dictionary,
) -> CombatPlanningPreview:
	var preview := CombatPlanningPreview.new()
	preview.apply_result(preview_dict, director)
	return preview


static func _enemy_push_destination(preview: CombatPlanningPreview, enemy_id: int) -> Vector2i:
	var pushes: Array = preview.preview_pushes.get(enemy_id, [])
	var seg: Array = _push_segment(pushes)
	if seg.size() < 2:
		return Vector2i(-999999, -999999)
	return seg[1] as Vector2i


static func _simulate_committed_plan(director: CombatDirector) -> SimResult:
	var start_board: BoardState = director.base_board.clone()
	start_board.intents = []
	return Simulator.simulate(start_board, director.get_player_plan())


static func _bash_img1_ready(fix: Dictionary) -> int:
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		return -1
	fix.director.selected_ability_index = bash_idx
	return bash_idx


static func _wire_overlay(fix: Dictionary) -> TacticalPlanningOverlay:
	var intent := CombatIntentState.new()
	var overlay := TacticalPlanningOverlay.new()
	overlay.setup(null, fix.director, intent)
	overlay.qa_static_overlay = true
	overlay.set_board(fix.board)
	fix.input._planning = overlay
	fix.input._intent_state = intent
	overlay.bind_planning_input(fix.input)
	PlanningDragE2EHarness.track_overlay_fixture(fix, overlay)
	return overlay


static func _wire_click_drop_context(fix: Dictionary) -> void:
	_wire_overlay(fix)


static func _expected_move_module_corridor_path(
	input: CombatPlanningInput,
	actor: UnitState,
	cell: Vector2i,
	stand_cell: Vector2i,
) -> Array[Vector2i]:
	if actor == null or input == null:
		return []
	if cell == stand_cell:
		return [stand_cell]
	if not input._can_move_to(actor, cell):
		return [stand_cell]
	var waypoints: Array[Vector2i] = input._corridor_waypoints_to_cell(actor, cell)
	var path: Array[Vector2i] = [stand_cell]
	for wp: Vector2i in waypoints:
		path.append(wp)
	if path.size() == 1 and GridSystem.manhattan(stand_cell, cell) == 1:
		path.append(cell)
	return path


static func _test_trample_full_phase_hover_matrix(failures: Array[String]) -> void:
	## Mandatory regression bar: dense multi-hover on every Trampling Advance phase.
	## Each hover asserts red tiles, blue tiles, move-preview arrows, and corridor truth.
	TramplingAdvanceE2ETest._test_awaiting_hover_orbit_matches_corridor_not_paint(failures)
	TramplingAdvanceE2ETest._test_undo_during_awaiting_movement_clears_arm(failures)
	TramplingAdvanceE2ETest._test_undo_committed_move_module_while_skill_still_awaiting(failures)
	var fix: Dictionary = PlanningChecklistHarness.wire_trample_board()
	fix.director.auto_run = true
	_wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	const LABEL := "PlanningQAGate trample/matrix"
	if fix.trample_idx < 0:
		failures.append("%s: Trampling Advance missing" % LABEL)
		return
	var trample: AbilityData = unit.active_abilities[fix.trample_idx]
	var stand: Vector2i = TramplingAdvanceE2ETest.START_CELL
	var end_cell: Vector2i = TramplingAdvanceE2ETest.END_CELL
	var full_route: Array[Vector2i] = [
		stand, TramplingAdvanceE2ETest.EAST_THEN_NORTH[0], end_cell,
	]
	var sweep_cells: Array[Vector2i] = HoverMatrix.dense_hover_cells(
		fix.board, [stand, end_cell], HoverMatrix.ORBIT_RADIUS, true,
	)
	if not TramplingAdvanceE2ETest._arm_trample_awaiting(input, director, unit):
		failures.append("%s: arm awaiting failed" % LABEL)
		return
	# Phase 1 — armed MOVE module selection-hover (circle the pointer; no drag paint).
	HoverMatrix.probe_hover_sweep(failures, fix, {
		"label_prefix": LABEL,
		"phase": "armed_move_hover",
		"hover_cells": sweep_cells,
		"sweep_from": stand,
		"actor": unit,
		"ability": trample,
		"stand_cell": stand,
		"expect_red": true,
		"expect_blue": true,
		"move_preview_kind": "corridor",
		"check_empty_drag_route": true,
		"suppress_target_arrow": true,
		"check_module_stand": true,
		"expect_awaiting_move_route": true,
	})
	input._begin_drag(unit, fix.map_stub.grid_to_local(stand), true)
	HoverMatrix.probe_hover_sweep(failures, fix, {
		"label_prefix": LABEL,
		"phase": "armed_move_drag",
		"hover_cells": sweep_cells,
		"sweep_from": stand,
		"actor": unit,
		"ability": trample,
		"stand_cell": stand,
		"update_drag": true,
		"expect_red": true,
		"expect_blue": true,
		"move_preview_kind": "drag_painted",
		"suppress_target_arrow": true,
		"check_module_stand": true,
		"expect_awaiting_move_route": false,
	})
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, full_route, end_cell)
	input.dragging = false
	HoverMatrix.probe_hover_sweep(failures, fix, {
		"label_prefix": LABEL,
		"phase": "painted_landing_hover",
		"hover_cells": sweep_cells,
		"sweep_from": end_cell,
		"actor": unit,
		"ability": trample,
		"stand_cell": stand,
		"expect_red": true,
		"expect_blue": true,
		"move_preview_kind": "fixed_route",
		"fixed_route": full_route,
		"check_empty_drag_route": true,
		"suppress_target_arrow": true,
		"check_module_stand": true,
		"expect_awaiting_move_route": true,
	})
	# Commit trample MOVE leg — post-move planning must stay on landing stand.
	var slots: Dictionary = TramplingAdvanceE2ETest._commit_drag_route(input, director, end_cell)
	if slots.is_empty():
		failures.append("%s: trample commit failed" % LABEL)
		return
	director.selected_ability_index = -1
	input._clear_hover_drag_route()
	var post_start: Vector2i = end_cell
	var post_dest: Vector2i = PlanningChecklistHarness.TRAMPLE_POST_DEST
	var post_route: Array[Vector2i] = PlanningChecklistHarness.TRAMPLE_POST_ROUTE.duplicate()
	var post_sweep: Array[Vector2i] = HoverMatrix.dense_hover_cells(
		fix.board, [post_start, post_dest], HoverMatrix.ORBIT_RADIUS, true,
	)
	# Phase 4 — post-move hover (basic movement from trample landing).
	HoverMatrix.probe_hover_sweep(failures, fix, {
		"label_prefix": LABEL,
		"phase": "postmove_hover",
		"hover_cells": post_sweep,
		"sweep_from": post_start,
		"actor": unit,
		"ability": null,
		"stand_cell": post_start,
		"expect_red": false,
		"expect_blue": true,
		"move_preview_kind": "postmove_corridor",
		"post_start": post_start,
		"suppress_target_arrow": true,
	})
	# Phase 5 — post-move drag orbit.
	input._begin_drag(unit, fix.map_stub.grid_to_local(post_start), true)
	HoverMatrix.probe_hover_sweep(failures, fix, {
		"label_prefix": LABEL,
		"phase": "postmove_drag",
		"hover_cells": post_sweep,
		"sweep_from": post_start,
		"actor": unit,
		"ability": null,
		"stand_cell": post_start,
		"update_drag": true,
		"expect_red": false,
		"expect_blue": true,
		"move_preview_kind": "postmove_corridor",
		"post_start": post_start,
		"suppress_target_arrow": true,
	})
	# Landing hover on full post route after paint.
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, post_route, post_dest)
	input.dragging = false
	HoverMatrix.probe_hover_sweep(failures, fix, {
		"label_prefix": LABEL,
		"phase": "postmove_painted_hover",
		"hover_cells": post_sweep,
		"sweep_from": post_dest,
		"actor": unit,
		"ability": null,
		"stand_cell": post_start,
		"expect_red": false,
		"expect_blue": true,
		"move_preview_kind": "fixed_route",
		"fixed_route": post_route,
		"suppress_target_arrow": true,
	})


static func _rewire_trample_fixture(fix: Dictionary) -> void:
	PlanningDragE2EHarness.cleanup_all()
	var fresh: Dictionary = PlanningDragE2EHarness.wire_fixture(
		TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL),
	)
	_wire_overlay(fresh)
	for key: Variant in fresh.keys():
		fix[key] = fresh[key]
	fix["unit"] = fix.knight


static func _setup_unarmed_painted_premove(fix: Dictionary) -> void:
	_rewire_trample_fixture(fix)
	fix.director.selected_ability_index = -1
	fix.input._clear_hover_drag_route()
	PlanningChecklistHarness.flush_planning(fix)


static func _setup_trample_move_painted(fix: Dictionary) -> void:
	_rewire_trample_fixture(fix)
	if not TramplingAdvanceE2ETest._arm_trample_awaiting(fix.input, fix.director, fix.unit):
		return
	fix.input._clear_hover_drag_route()
	PlanningChecklistHarness.flush_planning(fix)


static func _paint_sealed_route(fix: Dictionary, route: Array[Vector2i]) -> void:
	PlanningDragE2EHarness.begin_drag_route(fix, route)
	fix.input.on_hover_moved(route.back())
	fix.input._end_drag_interaction(false, false)
	PlanningChecklistHarness.hover(fix, route.back())
	PlanningChecklistHarness.flush_planning(fix)


static func _test_painted_route_premove_vs_move_equivalence(failures: Array[String]) -> void:
	const LABEL := "PlanningQAGate painted_route_equivalence"
	var seed_fix: Dictionary = PlanningDragE2EHarness.wire_fixture(
		TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL),
	)
	_wire_overlay(seed_fix)
	var stand: Vector2i = TramplingAdvanceE2ETest.START_CELL
	var full_route: Array[Vector2i] = [
		stand, TramplingAdvanceE2ETest.EAST_THEN_NORTH[0], TramplingAdvanceE2ETest.END_CELL,
	]
	var orbit: Array[Vector2i] = HoverMatrix.dense_hover_cells(
		seed_fix.board, [stand, full_route.back()], HoverMatrix.ORBIT_RADIUS, true,
	)
	var fix: Dictionary = seed_fix.duplicate()
	HoverMatrix.assert_two_leg_painted_route_equivalence(
		failures,
		LABEL,
		fix,
		fix.unit,
		full_route,
		orbit,
		func(setup_fix: Dictionary) -> void:
			_setup_unarmed_painted_premove(setup_fix)
			_paint_sealed_route(setup_fix, full_route),
		func(setup_fix: Dictionary) -> void:
			_setup_trample_move_painted(setup_fix)
			_paint_sealed_route(setup_fix, full_route),
	)


static func _test_waypoint_paint_order_preserved_on_tile_drag(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate movement 1A: knight missing Trampling Advance")
		return
	TramplingAdvanceE2ETest._arm_trample_awaiting(input, fix.director, unit)
	input._drag_unit_id = unit.id
	input._drag_route = [TramplingAdvanceE2ETest.START_CELL]
	input._extend_drag_route(TramplingAdvanceE2ETest.EAST_THEN_NORTH[0])
	input._extend_drag_route(TramplingAdvanceE2ETest.EAST_THEN_NORTH[1])
	var painted: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	if input._drag_route != painted:
		failures.append(
			"PlanningQAGate movement 1A: tile drag must preserve paint order %s, got %s"
			% [str(painted), str(input._drag_route)],
		)


static func _test_jump_drag_autocorrect_preserves_painted_corridor(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate movement 1A autocorrect: missing Trampling Advance")
		return
	TramplingAdvanceE2ETest._arm_trample_awaiting(input, fix.director, unit)
	input._drag_unit_id = unit.id
	input._drag_route = [TramplingAdvanceE2ETest.START_CELL]
	input._extend_drag_route(TramplingAdvanceE2ETest.EAST_THEN_NORTH[0])
	input._extend_drag_route(TramplingAdvanceE2ETest.END_CELL)
	var painted: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.END_CELL,
	]
	if input._drag_route != painted:
		failures.append(
			"PlanningQAGate movement 1A autocorrect: jump drag must keep E-then-N corridor %s, got %s"
			% [str(painted), str(input._drag_route)],
		)


static func _test_stale_hover_updates_commit_waypoints(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate movement stale: knight missing Shield Bash")
		return
	director.selected_ability_index = bash_idx
	var enemy_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, [], [], Vector2i(-999999, -999999),
	)
	var approach_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, BASH_APPROACH, [], [], Vector2i(-999999, -999999),
	)
	var enemy_pre: Array = enemy_slots.get("pre", []) as Array
	var approach_pre: Array = approach_slots.get("pre", []) as Array
	if enemy_pre.is_empty():
		failures.append("PlanningQAGate movement stale: enemy hover must build pre-move")
		return
	if approach_pre.is_empty():
		failures.append("PlanningQAGate movement stale: approach hover must build pre-move")
		return
	var enemy_move: TimelineAction = enemy_pre[0] as TimelineAction
	var approach_move: TimelineAction = approach_pre[0] as TimelineAction
	if approach_move == null or approach_move.target_coord != BASH_APPROACH:
		failures.append(
			"PlanningQAGate movement stale: approach hover must target %s, got %s"
			% [str(BASH_APPROACH), str(approach_move.target_coord if approach_move != null else null)],
		)
	if enemy_move == null or enemy_move.target_coord != BASH_APPROACH:
		failures.append(
			"PlanningQAGate movement stale: enemy hover pre-move must target %s, got %s"
			% [str(BASH_APPROACH), str(enemy_move.target_coord if enemy_move != null else null)],
		)


static func _test_planning_display_mp_left_contract(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, Vector2i(-1, -1))
	fix.knight.movement.points_left = 2
	fix.knight.movement.max_points = 3
	var proj: UnitState = fix.director.projected_state.get_unit_by_id(1)
	if proj != null:
		proj.movement.points_left = 2
		proj.movement.max_points = 3
	var display_mp: int = fix.input.planning_display_mp_left(1)
	if display_mp != 2:
		failures.append(
			"PlanningQAGate MP display: committed budget must match points_left (got %d)" % display_mp,
		)


static func _test_blue_move_tiles_on_walk_select(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, Vector2i(-1, -1))
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	fix["overlay"] = overlay
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	director.selected_ability_index = -1
	PlanningChecklistHarness.hover(fix, KNIGHT_START)
	var blue: Array[Vector2i] = PlanningChecklistHarness.collect_blue_tiles(fix)
	if blue.is_empty():
		failures.append("PlanningQAGate blue tiles: walk select must show reachable move tiles")
		return
	var dest := Vector2i(5, 5)
	if not blue.has(dest):
		failures.append(
			"PlanningQAGate blue tiles: walk dest (5,5) must be reachable, got %s" % str(blue),
		)


static func _test_locked_blue_stable_across_hovers(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, Vector2i(-1, -1))
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	fix["overlay"] = overlay
	fix.director.selected_ability_index = -1
	var hover_a := Vector2i(5, 5)
	var hover_b := Vector2i(5, 4)
	PlanningChecklistHarness.hover(fix, hover_a)
	var blue_a: Array[Vector2i] = PlanningChecklistHarness.collect_blue_tiles(fix)
	PlanningChecklistHarness.hover(fix, hover_b)
	var blue_b: Array[Vector2i] = PlanningChecklistHarness.collect_blue_tiles(fix)
	if blue_a.is_empty() or blue_b.is_empty():
		failures.append(
			"PlanningQAGate locked blue stable: movement step must show blue tiles on both hovers",
		)
		return
	if blue_a != blue_b:
		failures.append(
			"PlanningQAGate locked blue stable: hover A vs B must match (got %d vs %d tiles)"
			% [blue_a.size(), blue_b.size()],
		)
	var phase_entry: Vector2i = fix.input.phase_entry_stand_cell(fix.director.selected_unit_id)
	if phase_entry != KNIGHT_START:
		failures.append(
			"PlanningQAGate locked blue stable: phase-entry stand must be turn start (got %s)"
			% str(phase_entry),
		)


static func _test_locked_blue_visible_without_bundle(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, Vector2i(-1, -1))
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	fix["overlay"] = overlay
	fix.director.selected_ability_index = -1
	var settled_cell := Vector2i(5, 5)
	var mismatch_cell := Vector2i(5, 4)
	PlanningChecklistHarness.hover(fix, settled_cell)
	if fix.input.get_settled_hover_preview() == null:
		failures.append("PlanningQAGate locked blue without bundle: expected settled hover bundle")
		return
	fix.input.set_qa_pointer_grid_cell(mismatch_cell)
	overlay._recompute_hover_ranges_from_inputs()
	var blue: Array[Vector2i] = PlanningChecklistHarness.collect_blue_tiles(fix)
	if blue.is_empty():
		failures.append(
			"PlanningQAGate locked blue without bundle: blue must paint when bundle mismatches pointer",
		)


static func _test_bundle_mismatch_does_not_clear_locked_blue(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, Vector2i(-1, -1))
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	fix["overlay"] = overlay
	fix.director.selected_ability_index = -1
	var settled_cell := Vector2i(5, 5)
	var mismatch_cell := Vector2i(5, 4)
	PlanningChecklistHarness.hover(fix, settled_cell)
	var blue_before: Array[Vector2i] = PlanningChecklistHarness.collect_blue_tiles(fix)
	fix.input.set_qa_pointer_grid_cell(mismatch_cell)
	overlay._recompute_hover_ranges_from_inputs()
	var blue_after: Array[Vector2i] = PlanningChecklistHarness.collect_blue_tiles(fix)
	if blue_before.is_empty():
		failures.append("PlanningQAGate bundle mismatch: baseline locked blue missing")
		return
	if blue_after.is_empty() or blue_after != blue_before:
		failures.append(
			"PlanningQAGate bundle mismatch: locked blue must not clear (before %d after %d)"
			% [blue_before.size(), blue_after.size()],
		)


static func _test_locked_blue_origin_after_premove(failures: Array[String]) -> void:
	const Trample := preload("res://tests/harness/trampling_advance_e2e_test.gd")
	var raw_fix: Dictionary = Trample._knight_fixture(Trample.START_CELL)
	var fix: Dictionary = PlanningDragE2EHarness.wire_fixture(raw_fix)
	var overlay: TacticalPlanningOverlay = fix.overlay
	if fix.trample_idx < 0:
		failures.append(
			"PlanningQAGate locked blue premove origin: Trampling Advance missing",
		)
		return
	PlanningChecklistHarness.set_unit_pools(fix, fix.unit.id, 1, 8)
	var pre_route: Array[Vector2i] = [
		Trample.START_CELL, Vector2i(6, 4), Vector2i(6, 3),
	]
	var pre_dest: Vector2i = pre_route.back()
	PlanningChecklistHarness.enter_basic_movement(fix)
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(fix, pre_route, pre_dest):
		failures.append(
			"PlanningQAGate locked blue premove origin: premove commit failed",
		)
		return
	var phase_entry: Vector2i = fix.input.phase_entry_stand_cell(fix.director.selected_unit_id)
	if phase_entry != pre_dest:
		failures.append(
			"PlanningQAGate locked blue premove origin: phase-entry stand %s expected %s"
			% [str(phase_entry), str(pre_dest)],
		)
		return
	if PlanningChecklistHarness.select_ability(fix, Trample.TRAMPLE_ID) < 0:
		failures.append(
			"PlanningQAGate locked blue premove origin: Trampling Advance selection failed",
		)
		return
	var projected_after_pre: UnitState = fix.director.projected_state.get_unit_by_id(fix.unit.id)
	if not Trample._arm_trample_awaiting(fix.input, fix.director, projected_after_pre):
		failures.append(
			"PlanningQAGate locked blue premove origin: trample arm failed after premove",
		)
		return
	PlanningChecklistHarness.hover(fix, Vector2i(7, 3))
	var blue: Array[Vector2i] = PlanningChecklistHarness.collect_blue_tiles(fix)
	if blue.is_empty():
		failures.append(
			"PlanningQAGate locked blue premove origin: blue flood missing during skill move step after premove",
		)
		return
	var locked_origin: Vector2i = fix.input.phase_entry_stand_cell(fix.unit.id)
	if locked_origin != pre_dest:
		failures.append(
			"PlanningQAGate locked blue premove origin: locked stand %s expected premove landing %s"
			% [str(locked_origin), str(pre_dest)],
		)
		return
	var expected: Array[Vector2i] = PlanningPreviewTiles.reachable_move_tiles(
		fix.director,
		fix.board,
		projected_after_pre,
		fix.director.selected_ability_index,
		fix.input,
		locked_origin,
	)
	if expected.is_empty():
		failures.append(
			"PlanningQAGate locked blue premove origin: expected flood empty at %s" % str(locked_origin),
		)
		return
	for cell: Vector2i in blue:
		if not expected.has(cell):
			failures.append(
				"PlanningQAGate locked blue premove origin: tile %s not in locked flood from %s"
				% [str(cell), str(locked_origin)],
			)
			return
	if expected.has(Trample.START_CELL) and not blue.has(Trample.START_CELL):
		failures.append(
			"PlanningQAGate locked blue premove origin: flood must use premove stand not turn-start",
		)


static func _test_locked_red_stable_across_hovers(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	fix["overlay"] = overlay
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate locked red stable: Shield Bash missing")
		return
	fix.director.selected_ability_index = bash_idx
	var hover_a := ENEMY_POS
	var hover_b := PlanningChecklistHarness.BASH_APPROACH
	PlanningChecklistHarness.hover(fix, hover_a)
	var red_a: Array[Vector2i] = PlanningChecklistHarness.collect_red_tiles(fix)
	PlanningChecklistHarness.hover(fix, hover_b)
	var red_b: Array[Vector2i] = PlanningChecklistHarness.collect_red_tiles(fix)
	if red_a.is_empty() or red_b.is_empty():
		failures.append(
			"PlanningQAGate locked red stable: skill step must show red tiles on both hovers",
		)
		return
	if red_a != red_b:
		failures.append(
			"PlanningQAGate locked red stable: hover A vs B must match (got %d vs %d tiles)"
			% [red_a.size(), red_b.size()],
		)


static func _test_locked_red_visible_without_bundle(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	fix["overlay"] = overlay
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate locked red without bundle: Shield Bash missing")
		return
	fix.director.selected_ability_index = bash_idx
	var settled_cell := ENEMY_POS
	var mismatch_cell := PlanningChecklistHarness.BASH_APPROACH
	PlanningChecklistHarness.hover(fix, settled_cell)
	if fix.input.get_settled_hover_preview() == null:
		failures.append("PlanningQAGate locked red without bundle: expected settled hover bundle")
		return
	fix.input.set_qa_pointer_grid_cell(mismatch_cell)
	overlay._recompute_hover_ranges_from_inputs()
	var red: Array[Vector2i] = PlanningChecklistHarness.collect_red_tiles(fix)
	if red.is_empty():
		failures.append(
			"PlanningQAGate locked red without bundle: red must paint when bundle mismatches pointer",
		)


static func _test_bundle_mismatch_does_not_clear_locked_red(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	fix["overlay"] = overlay
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate bundle mismatch red: Shield Bash missing")
		return
	fix.director.selected_ability_index = bash_idx
	var settled_cell := ENEMY_POS
	var mismatch_cell := PlanningChecklistHarness.BASH_APPROACH
	PlanningChecklistHarness.hover(fix, settled_cell)
	var red_before: Array[Vector2i] = PlanningChecklistHarness.collect_red_tiles(fix)
	fix.input.set_qa_pointer_grid_cell(mismatch_cell)
	overlay._recompute_hover_ranges_from_inputs()
	var red_after: Array[Vector2i] = PlanningChecklistHarness.collect_red_tiles(fix)
	if red_before.is_empty():
		failures.append("PlanningQAGate bundle mismatch red: baseline locked red missing")
		return
	if red_after.is_empty() or red_after != red_before:
		failures.append(
			"PlanningQAGate bundle mismatch red: locked red must not clear (before %d after %d)"
			% [red_before.size(), red_after.size()],
		)


static func _test_cursor_walk_run_and_composite(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	input.auto_use_skill_after_move = true
	var unit := UnitState.new()
	unit.id = 1
	var walk_slots: Dictionary = {
		"pre": [TimelineAction.make_move(1, Vector2i(2, 2))],
		"action": [],
		"post": [],
		"invalid": false,
	}
	var walk_icon: String = input._cursor_icon_from_commit_slots(walk_slots, unit)
	if walk_icon != PlanningIcons.GLYPH_WALK:
		failures.append(
			"PlanningQAGate cursor 1B: walk tile must show walk glyph, got %s" % walk_icon,
		)
	var run_slots: Dictionary = {
		"pre": [
			TimelineAction.make_run_move(
				1, Vector2i(5, 2), -1, [], GameEnums.MoveTiming.PRE_ACTION,
			),
		],
		"action": [],
		"post": [],
		"invalid": false,
	}
	var run_icon: String = input._cursor_icon_from_commit_slots(run_slots, unit)
	if run_icon != PlanningIcons.GLYPH_RUN:
		failures.append(
			"PlanningQAGate cursor 1B: run tile must show run glyph, got %s" % run_icon,
		)
	var bash: AbilityData = _knight_ability(SHIELD_BASH_ID)
	if bash == null:
		failures.append("PlanningQAGate cursor 1B: Shield Bash ability missing")
		return
	var paired_slots: Dictionary = {
		"pre": [TimelineAction.make_move(1, BASH_APPROACH)],
		"action": [TimelineAction.make_ability(1, bash, ENEMY_POS, 2)],
		"post": [],
		"invalid": false,
	}
	var paired_icon: String = input._cursor_icon_from_commit_slots(paired_slots, unit)
	var expected_paired: String = PlanningIcons.join_glyphs([
		PlanningIcons.GLYPH_WALK,
		PlanningIcons.GLYPH_ATTACK,
	])
	if paired_icon != expected_paired:
		failures.append(
			"PlanningQAGate cursor 1B: walk+skill must composite %s, got %s"
			% [expected_paired, paired_icon],
		)


static func _test_committed_walk_preview_matches_sim_path(failures: Array[String]) -> void:
	var plain := TerrainData.new()
	plain.blocks_movement = false
	var board := BoardState.new()
	board.grid_size = Vector2i(10, 6)
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	var knight_def: UnitData = DataLibrary.get_unit(&"knight")
	var knight: UnitState = UnitState.create(1, knight_def, GameEnums.Team.PLAYER, Vector2i(0, 2))
	knight.movement.points_left = 3
	knight.movement.max_points = 3
	board.units = [knight]
	GridSystem.set_occupant(board, knight.position, knight.id)
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	director.selected_ability_index = -1
	var input := CombatPlanningInput.new()
	input._director = director
	var dest := Vector2i(2, 2)
	var slots: Dictionary = _commit_slots_at(input, 1, dest)
	if bool(slots.get("invalid", true)):
		failures.append("PlanningQAGate movement exec: basic walk commit slots invalid")
		return
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningQAGate movement exec: basic walk commit failed")
		return
	director.flush_plan_refresh_signals_if_pending()
	var start_board: BoardState = director.base_board.clone()
	start_board.intents = []
	var result: SimResult = Simulator.simulate(start_board, director.get_player_plan())
	var visited: Array[Vector2i] = [Vector2i(0, 2)]
	for event: SimEvent in result.events:
		if event.type != GameEnums.SimEventType.UNIT_MOVED:
			continue
		if int(event.data.get("actor", -1)) != 1:
			continue
		var path_v: Variant = event.data.get("path", [])
		if path_v is Array:
			for step: Variant in path_v:
				if step is Vector2i:
					visited.append(step)
	var pre: TimelineAction = director.plan_pre_move.entries[0]
	if pre.waypoints.size() > 0:
		for wp: Vector2i in pre.waypoints:
			if not visited.has(wp):
				failures.append(
					"PlanningQAGate movement exec: sim path missing committed waypoint %s (visited %s)"
					% [str(wp), str(visited)],
				)
	if visited.back() != dest:
		failures.append(
			"PlanningQAGate movement exec: sim must end at %s, visited %s"
			% [str(dest), str(visited)],
		)


static func _test_shield_bash_enemy_hover_commit_slots(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate Shield Bash 2A: ability missing on knight")
		return
	director.selected_ability_index = bash_idx
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, [], [], Vector2i(-999999, -999999),
	)
	if _is_invalid(slots):
		failures.append("PlanningQAGate Shield Bash 2A: enemy hover slots invalid")
		return
	var pre: Array = slots.get("pre", []) as Array
	var action: Array = slots.get("action", []) as Array
	if pre.is_empty() or action.is_empty():
		failures.append("PlanningQAGate Shield Bash 2A: enemy hover must fill pre + action")
		return
	var move_step: TimelineAction = pre[0] as TimelineAction
	var bash_step: TimelineAction = action[0] as TimelineAction
	if move_step.target_coord != BASH_APPROACH:
		failures.append(
			"PlanningQAGate Shield Bash 2A: pre-move must approach %s, got %s"
			% [str(BASH_APPROACH), str(move_step.target_coord)],
		)
	if bash_step.target_unit_id != 2:
		failures.append("PlanningQAGate Shield Bash 2A: action must target enemy id 2")


static func _test_shield_bash_push_away_from_player(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(BASH_APPROACH, ENEMY_POS)
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate Shield Bash 2A push: ability missing")
		return
	var bash: AbilityData = fix.knight.active_abilities[bash_idx]
	var actions: Array[TimelineAction] = [
		TimelineAction.make_ability(
			1, bash, ENEMY_POS, 2, GameEnums.MoveTiming.PRE_ACTION,
		),
	]
	var preview := _preview_for_actions(director, actions)
	var pushes: Array = preview.preview_pushes.get(2, [])
	var seg: Array = _push_segment(pushes)
	if seg.size() < 2:
		failures.append("PlanningQAGate Shield Bash 2A push: preview_pushes missing segment")
		return
	var from_cell: Vector2i = seg[0] as Vector2i
	var to_cell: Vector2i = seg[1] as Vector2i
	if to_cell.x <= from_cell.x:
		failures.append(
			"PlanningQAGate Shield Bash 2A push: must push east away from player %s -> %s"
			% [str(from_cell), str(to_cell)],
		)


static func _test_shield_bash_enemy_lands_at_push_destination(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(BASH_APPROACH, ENEMY_POS)
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate Shield Bash 2A threat: ability missing")
		return
	var bash: AbilityData = fix.knight.active_abilities[bash_idx]
	var actions: Array[TimelineAction] = [
		TimelineAction.make_ability(
			1, bash, ENEMY_POS, 2, GameEnums.MoveTiming.PRE_ACTION,
		),
	]
	var preview := _preview_for_actions(director, actions)
	var pushes: Array = preview.preview_pushes.get(2, [])
	var seg: Array = _push_segment(pushes)
	if seg.size() < 2:
		failures.append("PlanningQAGate Shield Bash 2A threat: missing push preview")
		return
	var pushed_to: Vector2i = seg[1] as Vector2i
	if preview.preview_board == null:
		failures.append("PlanningQAGate Shield Bash 2A threat: preview board missing")
		return
	var pv_enemy: UnitState = preview.preview_board.get_unit_by_id(2)
	if pv_enemy == null:
		failures.append("PlanningQAGate Shield Bash 2A threat: enemy missing on preview board")
		return
	if pv_enemy.position != pushed_to:
		failures.append(
			"PlanningQAGate Shield Bash 2A threat: enemy must land at push dest %s, at %s"
			% [str(pushed_to), str(pv_enemy.position)],
		)


static func _test_shield_bash_enemy_hover_composite_cursor(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	director.selected_ability_index = bash_idx
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, [], [], Vector2i(-999999, -999999),
	)
	var icon: String = input._cursor_icon_from_commit_slots(slots, fix.knight)
	if icon.find(PlanningIcons.GLYPH_WALK) < 0 or icon.find(PlanningIcons.GLYPH_ATTACK) < 0:
		failures.append(
			"PlanningQAGate Shield Bash 2A cursor: enemy hover must composite walk+attack, got %s"
			% icon,
		)


static func _test_shield_bash_adjacent_painted_approach_hover(failures: Array[String]) -> void:
	var knight_pos := Vector2i(6, 7)
	var enemy_pos := Vector2i(7, 7)
	var north_approach := Vector2i(7, 6)
	var fix: Dictionary = _planning_fixture(knight_pos, enemy_pos)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate bash_adjacent_painted_approach: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	var route: Array[Vector2i] = [knight_pos, Vector2i(6, 6), north_approach]
	TramplingAdvanceE2ETest._paint_drag_route(fix.input, fix.knight, route, north_approach)
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1, enemy_pos, input._route_waypoints(), [], enemy_pos,
	)
	if _slots_invalid(slots):
		failures.append("PlanningQAGate bash_adjacent_painted_approach: enemy hover slots invalid")
		return
	var pre: Array = slots.get("pre", []) as Array
	var action: Array = slots.get("action", []) as Array
	if pre.is_empty() or action.is_empty():
		failures.append(
			"PlanningQAGate bash_adjacent_painted_approach: must pair pre-move + bash when painted stand differs from current tile",
		)
		return
	var move_step: TimelineAction = pre[0] as TimelineAction
	if move_step == null or move_step.target_coord != north_approach:
		failures.append(
			"PlanningQAGate bash_adjacent_painted_approach: pre-move must end at painted stand %s, got %s"
			% [north_approach, move_step.target_coord if move_step != null else null],
		)
	var icon: String = input._cursor_icon_from_commit_slots(slots, fix.knight)
	if icon.find(PlanningIcons.GLYPH_ATTACK) < 0:
		failures.append(
			"PlanningQAGate bash_adjacent_painted_approach: cursor must include attack glyph, got %s" % icon,
		)


static func _test_shield_bash_hover_change_clears_stale_approach(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	director.selected_ability_index = bash_idx
	input._drag_route = [KNIGHT_START, Vector2i(5, 5)]
	input.dragging = true
	input._drag_unit_id = 1
	var stale_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, input._drag_route, [], Vector2i(-999999, -999999),
	)
	input.dragging = false
	input._drag_route.clear()
	var fresh_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, [], [], Vector2i(-999999, -999999),
	)
	var stale_pre: Array = stale_slots.get("pre", []) as Array
	var fresh_pre: Array = fresh_slots.get("pre", []) as Array
	if stale_pre.is_empty() or fresh_pre.is_empty():
		failures.append("PlanningQAGate Shield Bash 2A stale: pre-move missing on hover compare")
		return
	var stale_move: TimelineAction = stale_pre[0] as TimelineAction
	var fresh_move: TimelineAction = fresh_pre[0] as TimelineAction
	if fresh_move.target_coord != BASH_APPROACH:
		failures.append(
			"PlanningQAGate Shield Bash 2A stale: fresh hover must use canonical approach %s"
			% str(BASH_APPROACH),
		)
	if stale_move.target_coord == Vector2i(5, 5):
		failures.append(
			"PlanningQAGate Shield Bash 2A stale: enemy hover must not keep invalid drag waypoint (5,5)",
		)


static func _test_chain_hook_awaiting_targeting_segment(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(Vector2i(1, 3), Vector2i(4, 3))
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate Chain Hook 2B: ability missing")
		return
	director.selected_ability_index = hook_idx
	var hook: AbilityData = fix.knight.active_abilities[hook_idx]
	if AbilitySystem.ability_has_movement_effect(hook):
		failures.append("PlanningQAGate Chain Hook 2B: hook must not be movement-effect skill")
	if not hook.has_targeting(GameEnums.TargetingFlags.ENEMY):
		failures.append("PlanningQAGate Chain Hook 2B: hook must target enemies")
	var enemy_pos: Vector2i = fix.enemy.position
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1, enemy_pos, [] as Array[Vector2i], [] as Array[Vector2i], Vector2i(-999999, -999999),
	)
	if bool(slots.get("invalid", true)):
		failures.append("PlanningQAGate Chain Hook 2B: enemy hover slots invalid")
		return
	var action_steps: Array = slots.get("action", []) as Array
	if action_steps.is_empty():
		failures.append("PlanningQAGate Chain Hook 2B: enemy hover must commit hook action")
		return
	var hook_action: TimelineAction = action_steps[0] as TimelineAction
	if hook_action.target_unit_id != 2:
		failures.append("PlanningQAGate Chain Hook 2B: hook action must target enemy id 2")
	var segment: Array[Vector2i] = [fix.knight.position, enemy_pos]
	if segment[0] == segment[1]:
		failures.append("PlanningQAGate Chain Hook 2B: targeting segment must be player -> enemy")


static func _test_chain_hook_pull_toward_player(failures: Array[String]) -> void:
	var knight_pos := Vector2i(1, 3)
	var enemy_pos := Vector2i(4, 3)
	var fix: Dictionary = _planning_fixture(knight_pos, enemy_pos)
	var director: CombatDirector = fix.director
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate Chain Hook 2B pull: ability missing")
		return
	var hook: AbilityData = fix.knight.active_abilities[hook_idx]
	var actions: Array[TimelineAction] = [
		TimelineAction.make_ability(
			1, hook, enemy_pos, 2, GameEnums.MoveTiming.PRE_ACTION,
		),
	]
	var preview := _preview_for_actions(director, actions)
	var pushes: Array = preview.preview_pushes.get(2, [])
	var seg: Array = _push_segment(pushes)
	if seg.size() < 2:
		failures.append("PlanningQAGate Chain Hook 2B pull: preview displacement missing")
		return
	var from_cell: Vector2i = seg[0] as Vector2i
	var to_cell: Vector2i = seg[1] as Vector2i
	if to_cell.x >= from_cell.x:
		failures.append(
			"PlanningQAGate Chain Hook 2B pull: must pull west toward player %s -> %s"
			% [str(from_cell), str(to_cell)],
		)


static func _test_trampling_premove_then_arm_commit_flow(failures: Array[String]) -> void:
	var start := Vector2i(5, 4)
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(start)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate Trampling 2C: missing Trampling Advance")
		return
	director.selected_ability_index = -1
	var pre_dest := Vector2i(6, 4)
	var trample_end := Vector2i(6, 3)
	var pre_slots: Dictionary = _commit_slots_at(input, 1, pre_dest)
	if bool(pre_slots.get("invalid", true)):
		failures.append("PlanningQAGate Trampling 2C: pre-move slots invalid")
		return
	if not director.commit_from_slots(1, pre_slots):
		failures.append("PlanningQAGate Trampling 2C: pre-move commit failed")
		return
	director.flush_plan_refresh_signals_if_pending()
	if director.plan_pre_move.entries.is_empty():
		failures.append("PlanningQAGate Trampling 2C: pre-move must stay on timeline")
	director.selected_ability_index = fix.trample_idx
	var stand: Vector2i = director.projected_state.get_unit_by_id(1).position
	if not _arm_awaiting_at(input, director, stand):
		failures.append("PlanningQAGate Trampling 2C: arm awaiting failed at %s" % str(stand))
		return
	var route: Array[Vector2i] = [pre_dest, trample_end]
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, route, trample_end)
	var slots: Dictionary = TramplingAdvanceE2ETest._commit_drag_route(
		input, director, trample_end,
	)
	if slots.is_empty():
		failures.append("PlanningQAGate Trampling 2C: trample commit failed after pre-move")
		return
	var trample: TimelineAction = TramplingAdvanceE2ETest._committed_trample_action(director)
	if trample == null:
		failures.append("PlanningQAGate Trampling 2C: missing committed trample action")
		return
	if trample.target_coord != trample_end:
		failures.append(
			"PlanningQAGate Trampling 2C: trample target %s expected %s"
			% [str(trample.target_coord), str(trample_end)],
		)
	var preview: CombatPlanningPreview = TramplingAdvanceE2ETest._rebuild_committed_preview(director)
	var path: Array = preview.preview_paths.get(1, [])
	var expected_path: Array[Vector2i] = [start, pre_dest, trample_end]
	if path != expected_path:
		failures.append(
			"PlanningQAGate Trampling 2C: preview path %s expected %s"
			% [str(path), str(expected_path)],
		)


static func _test_trampling_unarmed_empty_hover_is_premove(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(PlanningChecklistHarness.TRAMPLE_START)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate Trampling unarmed hover: missing Trampling Advance")
		return
	director.auto_run = true
	director.selected_ability_index = fix.trample_idx
	if input.awaiting_targeting_active():
		failures.append(
			"PlanningQAGate Trampling unarmed hover: select must not arm awaiting yet",
		)
		return
	var hover_walk: Vector2i = PlanningChecklistHarness.TRAMPLE_ROUTE[0]
	var in_range_endpoint: Vector2i = Vector2i(4, 4)
	var in_range_slots: Dictionary = PlanningQAGateTest._commit_slots_at(input, 1, in_range_endpoint)
	if bool(in_range_slots.get("invalid", false)):
		failures.append(
			"PlanningQAGate Trampling unarmed hover: in-range endpoint slots invalid %s"
			% str(in_range_slots),
		)
		return
	var in_range_pre: Array = in_range_slots.get("pre", []) as Array
	var in_range_actions: Array = in_range_slots.get("action", []) as Array
	if in_range_pre.is_empty():
		failures.append(
			"PlanningQAGate Trampling unarmed hover: in-range endpoint must populate pre-move",
		)
	for raw_action: Variant in in_range_actions:
		if raw_action is TimelineAction:
			var committed: TimelineAction = raw_action as TimelineAction
			if committed.awaiting_target:
				continue
			if committed.ability != null and committed.ability.id == TRAMPLE_ID:
				failures.append(
					"PlanningQAGate Trampling unarmed hover: in-range tile must not commit trample action",
				)
	var slots: Dictionary = PlanningQAGateTest._commit_slots_at(input, 1, hover_walk)
	if bool(slots.get("invalid", false)):
		failures.append(
			"PlanningQAGate Trampling unarmed hover: slots invalid %s" % str(slots),
		)
		return
	var pre_moves: Array = slots.get("pre", []) as Array
	var actions: Array = slots.get("action", []) as Array
	if pre_moves.is_empty():
		failures.append(
			"PlanningQAGate Trampling unarmed hover: expected pre-move on empty tile",
		)
	if not actions.is_empty():
		failures.append(
			"PlanningQAGate Trampling unarmed hover: action must stay empty before arm",
		)
	var pre: TimelineAction = pre_moves[0] as TimelineAction if not pre_moves.is_empty() else null
	if pre != null and pre.target_coord != hover_walk:
		failures.append(
			"PlanningQAGate Trampling unarmed hover: pre-move dest %s expected %s"
			% [str(pre.target_coord), str(hover_walk)],
		)


static func _test_trampling_unarmed_hover_follows_mouse_waypoints(failures: Array[String]) -> void:
	TramplingAdvanceE2ETest._test_unarmed_hover_follows_mouse_waypoints(failures)


static func _test_hover_slots_are_deterministic(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate integrity: Shield Bash missing for deterministic hover")
		return
	director.selected_ability_index = bash_idx
	var empty_wps: Array[Vector2i] = []
	var empty_legal: Array[Vector2i] = []
	var first: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, empty_wps, empty_legal, Vector2i(-999999, -999999),
	)
	var second: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, empty_wps, empty_legal, Vector2i(-999999, -999999),
	)
	if _slot_signature(first) != _slot_signature(second):
		failures.append(
			"PlanningQAGate integrity: repeat enemy hover must return identical slots %s vs %s"
			% [_slot_signature(first), _slot_signature(second)],
		)


static func _test_commit_plan_matches_hover_slots(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate integrity: Shield Bash missing for commit parity")
		return
	director.selected_ability_index = bash_idx
	var slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	if _is_invalid(slots):
		failures.append("PlanningQAGate integrity: enemy hover must be committable")
		return
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningQAGate integrity: commit_from_slots failed on hover slots")
		return
	director.flush_plan_refresh_signals_if_pending()
	var pre_target: Vector2i = _pre_target(slots)
	if not director.plan_pre_move.entries.is_empty():
		var committed_pre: TimelineAction = director.plan_pre_move.entries[0]
		if committed_pre.target_coord != pre_target:
			failures.append(
				"PlanningQAGate integrity: committed pre-move %s != hover preview %s"
				% [str(committed_pre.target_coord), str(pre_target)],
			)
	if not director.plan_action.entries.is_empty():
		var committed_action: TimelineAction = director.plan_action.entries[0]
		if committed_action.target_unit_id != _action_target_unit(slots):
			failures.append(
				"PlanningQAGate integrity: committed action target %d != hover preview %d"
				% [committed_action.target_unit_id, _action_target_unit(slots)],
			)


static func _test_undo_action_keeps_premove(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(Vector2i(3, 3))
	var director: CombatDirector = fix.director
	var trample_idx: int = _ability_index(fix.knight, TRAMPLE_ID)
	if trample_idx < 0:
		failures.append("PlanningQAGate integrity: Trampling Advance missing for undo test")
		return
	var trample: AbilityData = fix.knight.active_abilities[trample_idx]
	director.plan_pre_move.entries.append(
		TimelineAction.make_move(
			1, Vector2i(4, 2), -1, [], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	director.plan_action.entries.append(
		TimelineAction.make_ability(
			1,
			trample,
			Vector2i(5, 1),
			-1,
			GameEnums.MoveTiming.PRE_ACTION,
			[Vector2i(4, 2), Vector2i(5, 1)],
		),
	)
	director.rpc_remove_last_for_unit(1)
	if not director.plan_action.entries.is_empty():
		failures.append("PlanningQAGate integrity: undo must remove action column entry")
	if director.plan_pre_move.entries.is_empty():
		failures.append("PlanningQAGate integrity: undo must not remove paired pre-move walk")


static func _test_premove_reposition_applies_live_board(failures: Array[String]) -> void:
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var lancer_def: UnitData = DataLibrary.get_unit(&"lancer")
	if lancer_def == null:
		failures.append("PlanningQAGate premove live: lancer definition missing")
		return
	var push: AbilityData = null
	for ability: AbilityData in lancer_def.abilities:
		if ability != null and ability.id == &"lancer_push":
			push = ability
			break
	if push == null:
		failures.append("PlanningQAGate premove live: lancer_push missing")
		return
	var actor := UnitState.create(1, lancer_def, GameEnums.Team.PLAYER, Vector2i(1, 1), {
		"active_abilities": [push],
	})
	var ally_def: UnitData = DataLibrary.get_unit(&"knight")
	var ally := UnitState.create(2, ally_def, GameEnums.Team.PLAYER, Vector2i(2, 1), {
		"active_abilities": [],
	})
	var board := _plain_board(Vector2i(6, 4), [actor, ally])
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	var push_action := TimelineAction.make_ability(actor.id, push, ally.position, ally.id)
	var slots: Dictionary = {
		"pre": [push_action],
		"action": [],
		"post": [],
		"_preview_validated": true,
	}
	if not director.commit_from_slots(actor.id, slots):
		failures.append("PlanningQAGate premove live: lancer push commit rejected")
		return
	var live_ally: UnitState = director.board.get_unit_by_id(ally.id)
	if live_ally == null:
		failures.append("PlanningQAGate premove live: ally missing from live board after push")
		return
	if live_ally.position != Vector2i(3, 1):
		failures.append(
			"PlanningQAGate premove live: ally must move on live board during planning (got %s)"
			% str(live_ally.position),
		)
	if director.plan_pre_move.entries.is_empty():
		failures.append("PlanningQAGate premove live: push must stay in pre-move timeline")
	var live_actor: UnitState = director.board.get_unit_by_id(actor.id)
	if live_actor == null:
		failures.append("PlanningQAGate premove live: actor missing from live board after push")
		return
	_assert_move_preview_origin_contract(
		failures,
		"lancer push live",
		director,
		actor.id,
		live_actor.position,
	)


static func _test_premove_beast_reposition_applies_live_board(failures: Array[String]) -> void:
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var rider_def: UnitData = DataLibrary.get_unit(&"beast_rider")
	if rider_def == null:
		failures.append("PlanningQAGate beast reposition: beast_rider definition missing")
		return
	var reposition: AbilityData = null
	for ability: AbilityData in rider_def.abilities:
		if ability != null and ability.id == &"beast_reposition":
			reposition = ability
			break
	if reposition == null:
		failures.append("PlanningQAGate beast reposition: beast_reposition missing")
		return
	if not reposition.is_pre_move_planner():
		failures.append("PlanningQAGate beast reposition: skill must be Pre-Move")
		return
	var actor := UnitState.create(1, rider_def, GameEnums.Team.PLAYER, Vector2i(2, 3), {
		"active_abilities": [reposition],
	})
	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	var dummy := UnitState.create(2, dummy_def, GameEnums.Team.PLAYER, Vector2i(3, 3), {
		"active_abilities": [],
	})
	var board := _plain_board(Vector2i(8, 6), [actor, dummy])
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	var repos_action := TimelineAction.make_ability(actor.id, reposition, dummy.position, dummy.id)
	var slots: Dictionary = {
		"pre": [repos_action],
		"action": [],
		"post": [],
		"_preview_validated": true,
	}
	if not director.commit_from_slots(actor.id, slots):
		failures.append("PlanningQAGate beast reposition: commit rejected")
		return
	if director.plan_pre_move.entries.is_empty():
		failures.append("PlanningQAGate beast reposition: must land in the Pre-Move column")
	if not director.plan_action.entries.is_empty():
		failures.append("PlanningQAGate beast reposition: must not land in the Action column")
	var live_actor: UnitState = director.board.get_unit_by_id(actor.id)
	var live_dummy: UnitState = director.board.get_unit_by_id(dummy.id)
	if live_actor == null or live_actor.position != Vector2i(2, 3):
		failures.append("PlanningQAGate beast reposition: caster must stay put during planning")
	if live_dummy == null or live_dummy.position != Vector2i(1, 3):
		failures.append(
			"PlanningQAGate beast reposition: dummy must slide opposite during planning (got %s)"
			% str(live_dummy.position if live_dummy != null else Vector2i(-1, -1)),
		)


static func _test_reposition_commit_clears_move_preview(failures: Array[String]) -> void:
	const Checklist := preload("res://tests/harness/planning_checklist_harness.gd")
	var fix: Dictionary = Checklist.wire_swap_board(Checklist.WALK_SWAP_ALLY_CELL)
	var overlay: TacticalPlanningOverlay = fix.get("overlay", null) as TacticalPlanningOverlay
	if overlay == null:
		failures.append("PlanningQAGate reposition_preview_clear: overlay fixture missing")
		return
	var unit_id: int = fix.k1_id as int
	if Checklist.select_ability_for_unit(fix, unit_id, Checklist.KNIGHT_SWAP_ID) < 0:
		failures.append("PlanningQAGate reposition_preview_clear: Swap missing")
		return
	Checklist.hover(fix, Checklist.WALK_SWAP_ALLY_CELL)
	var slots: Dictionary = Checklist.commit_production(fix, Checklist.WALK_SWAP_ALLY_CELL)
	if Checklist._slots_invalid(slots):
		failures.append("PlanningQAGate reposition_preview_clear: commit rejected")
		return
	if fix.director.plan_pre_move.entries.size() < 2:
		failures.append(
			"PlanningQAGate reposition_preview_clear: expected waypointed premove + reposition",
		)
	if overlay._should_draw_player_move_preview():
		failures.append(
			"PlanningQAGate reposition_preview_clear: renderer still exposes committed move route",
		)
	var committed: CombatPlanningPreview = overlay.get_committed_preview()
	if committed.preview_board != null or not committed.preview_paths.is_empty():
		failures.append(
			"PlanningQAGate reposition_preview_clear: route must clear when premove execution starts",
		)
	var stale_result := SimResult.new()
	stale_result.final_state = fix.director.projected_state.clone()
	overlay._on_preview_updated(stale_result)
	if overlay.get_committed_preview().preview_board != null:
		failures.append(
			"PlanningQAGate reposition_preview_clear: deferred refresh restored stale route",
		)


static func _test_push_through_premove_moves_both_units(failures: Array[String]) -> void:
	const BruiserFixture := preload("res://tests/harness/bruiser_planning_checklist_harness.gd")
	const Checklist := preload("res://tests/harness/planning_checklist_harness.gd")
	const MovementTimeline := preload("res://tests/harness/movement_timeline_qa_harness.gd")
	PlanningDragE2EHarness.cleanup_all()
	var fix: Dictionary = BruiserFixture.wire_board(
		Vector2i(4, 5), Vector2i(-1, -1), Vector2i(3, 5), &"bruiser_push_through",
	)
	fix.director.auto_run = true
	var ally_commit: Vector2i = Vector2i(3, 5)
	var idx: int = Checklist.select_ability(fix, &"bruiser_push_through")
	if idx < 0:
		failures.append("PlanningQAGate push_through live: ability not selectable")
		return
	Checklist.hover(fix, ally_commit)
	var hover_slots: Dictionary = Checklist.slots_for_hover(fix, ally_commit)
	if Checklist._slots_invalid(hover_slots):
		failures.append("PlanningQAGate push_through live: invalid hover slots at ally")
		return
	Checklist.assert_slots_match_preview_commit(
		failures, "push_through live/hover_click", fix, ally_commit,
	)
	var slots: Dictionary = Checklist.commit_production(fix, ally_commit)
	if Checklist._slots_invalid(slots):
		failures.append("PlanningQAGate push_through live: production commit rejected")
		return
	var live_actor: UnitState = fix.director.board.get_unit_by_id(fix.bruiser.id)
	var ally: UnitState = fix.get("ally", null) as UnitState
	var live_ally: UnitState = (
		fix.director.board.get_unit_by_id(ally.id) if ally != null else null
	)
	if live_actor == null or live_ally == null:
		failures.append("PlanningQAGate push_through live: missing units on live board")
		return
	if live_actor.position != Vector2i(3, 5):
		failures.append(
			"PlanningQAGate push_through live: bruiser must occupy ally tile (got %s)"
			% str(live_actor.position),
		)
	if live_ally.position != Vector2i(2, 5):
		failures.append(
			"PlanningQAGate push_through live: ally must be pushed west (got %s)"
			% str(live_ally.position),
		)
	var push: AbilityData = fix.bruiser.active_abilities[idx] as AbilityData
	MovementTimeline.assert_move_preview_origin(
		failures, "push_through live", fix, fix.bruiser.id, push,
	)
	var pre_moves: Array = slots.get("pre", [])
	if pre_moves.is_empty():
		failures.append("PlanningQAGate push_through live: premove column empty after commit")
		return
	var push_action: TimelineAction = pre_moves[0] as TimelineAction
	if push_action == null or not CombatPlanningPreview.premove_displacement_realized(
		fix.director, push_action,
	):
		failures.append(
			"PlanningQAGate push_through live: premove displacement must be realized on live board",
		)


static func _test_push_through_hover_uses_shared_refresh_path(failures: Array[String]) -> void:
	const BruiserFixture := preload("res://tests/harness/bruiser_planning_checklist_harness.gd")
	const Checklist := preload("res://tests/harness/planning_checklist_harness.gd")
	PlanningDragE2EHarness.cleanup_all()
	var fix: Dictionary = BruiserFixture.wire_board(
		Vector2i(4, 5), Vector2i(-1, -1), Vector2i(3, 5), &"bruiser_push_through",
	)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	var idx: int = Checklist.select_ability(fix, &"bruiser_push_through")
	if idx < 0:
		failures.append("PlanningQAGate push_through hover_refresh: ability not selectable")
		return
	overlay.qa_static_overlay = false
	if input._should_run_hover_sim_sync(Vector2i(3, 5)):
		failures.append(
			"PlanningQAGate push_through hover_refresh: premove must use shared hover refresh scheduling",
		)
	var slots: Dictionary = Checklist.slots_for_click(fix, Vector2i(3, 5))
	if Checklist._slots_invalid(slots):
		failures.append("PlanningQAGate push_through hover_refresh: commit rejected")
		return
	var empty_path: Array[Vector2i] = []
	var committed: bool = input.call(
		"_commit_at_cell",
		director.selected_unit_id,
		Vector2i(3, 5),
		Vector2.ZERO,
		empty_path,
		empty_path,
		Vector2i(-999999, -999999),
		-1,
		slots,
	)
	if not committed:
		failures.append("PlanningQAGate push_through hover_refresh: production commit failed")
		return
	if director.selected_ability_index >= 0:
		failures.append(
			"PlanningQAGate push_through hover_refresh: committed pre-move skill must be deselected",
		)


static func _test_move_preview_origin_premove_and_postmove(failures: Array[String]) -> void:
	const Trample := preload("res://tests/harness/trampling_advance_e2e_test.gd")
	var raw_fix: Dictionary = Trample._knight_fixture(Trample.START_CELL)
	var fix: Dictionary = PlanningDragE2EHarness.wire_fixture(raw_fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var overlay: TacticalPlanningOverlay = fix.overlay
	var unit: UnitState = fix.unit
	var label := "PlanningQAGate move_preview_origin"
	if fix.trample_idx < 0:
		failures.append("%s: Trampling Advance missing" % label)
		return
	PlanningChecklistHarness.set_unit_pools(fix, unit.id, 1, 8)

	# Stage 1: diagonal premove, start -> east -> north.
	var pre_route: Array[Vector2i] = [
		Trample.START_CELL, Vector2i(6, 4), Vector2i(6, 3),
	]
	PlanningChecklistHarness.enter_basic_movement(fix)
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(
		fix, pre_route, pre_route.back(),
	):
		failures.append("%s: diagonal premove commit failed" % label)
		return
	var committed_pre: TimelineAction = PlanningChecklistHarness.committed_pre_move(director, unit.id)
	if committed_pre == null or committed_pre.waypoints != pre_route.slice(1):
		failures.append(
			"%s: premove waypoints %s expected %s"
			% [label, str(committed_pre.waypoints if committed_pre != null else []), str(pre_route.slice(1))],
		)
		return
	var projected_after_pre: UnitState = director.projected_state.get_unit_by_id(unit.id)
	if projected_after_pre == null or projected_after_pre.position != pre_route.back():
		failures.append(
			"%s: projected premove stand %s expected %s"
			% [label, str(projected_after_pre.position if projected_after_pre != null else null), str(pre_route.back())],
		)
		return

	# Stage 2: arm Trampling Advance and paint a second diagonal/L-shaped route.
	if PlanningChecklistHarness.select_ability(fix, Trample.TRAMPLE_ID) < 0:
		failures.append("%s: Trampling Advance selection failed" % label)
		return
	if not Trample._arm_trample_awaiting(input, director, projected_after_pre):
		failures.append("%s: movement skill arm failed after premove" % label)
		return
	var trample_route: Array[Vector2i] = [
		pre_route.back(), Vector2i(7, 3), Vector2i(7, 2),
	]
	Trample._paint_drag_route(input, projected_after_pre, trample_route, trample_route.back())
	PlanningChecklistHarness.hover(fix, trample_route.back())
	var live_trample: CombatPlanningPreview = overlay.get_live_preview()
	var trample_preview_path: Array = live_trample.preview_paths.get(unit.id, [])
	if trample_preview_path != trample_route:
		failures.append(
			"%s: movement-skill preview path %s expected %s"
			% [label, str(trample_preview_path), str(trample_route)],
		)
		return
	for i: int in range(1, trample_preview_path.size()):
		if GridSystem.manhattan(trample_preview_path[i - 1], trample_preview_path[i]) != 1:
			failures.append("%s: movement-skill preview contains diagonal segment %s" % [label, str(trample_preview_path)])
			return
	if not overlay.targeting_intent_arrow_cells().is_empty():
		failures.append("%s: movement skill drew a duplicate direct target arrow" % label)
		return
	var trample_slots: Dictionary = input._intent_snapshot_slots.duplicate(true)
	var trample_hover_action: TimelineAction = _slot_action_with_ability(
		trample_slots, Trample.TRAMPLE_ID,
	)
	if _slots_invalid(trample_slots) or trample_hover_action == null:
		failures.append("%s: movement-skill hover slots missing" % label)
		return
	if trample_hover_action.waypoints != trample_route.slice(1):
		failures.append(
			"%s: hover movement-skill waypoints %s expected %s"
			% [label, str(trample_hover_action.waypoints), str(trample_route.slice(1))],
		)
		return
	input.set_qa_pointer_grid_cell(trample_route.back())
	input.on_left_press(fix.map_stub.grid_to_local(trample_route.back()))
	PlanningChecklistHarness.flush_planning(fix)
	var committed_trample: TimelineAction = Trample._committed_trample_action(director)
	if committed_trample == null or committed_trample.waypoints != trample_route.slice(1):
		failures.append(
			"%s: committed movement-skill waypoints %s expected %s"
			% [label, str(committed_trample.waypoints if committed_trample != null else []), str(trample_route.slice(1))],
		)
		return
	var projected_after_trample: UnitState = director.projected_state.get_unit_by_id(unit.id)
	if projected_after_trample == null or projected_after_trample.position != trample_route.back():
		failures.append(
			"%s: projected movement-skill stand %s expected %s"
			% [label, str(projected_after_trample.position if projected_after_trample != null else null), str(trample_route.back())],
		)
		return

	# Stage 3: diagonal postmove from the movement skill's actual action end.
	PlanningChecklistHarness.enter_basic_movement(fix)
	var post_route: Array[Vector2i] = [
		trample_route.back(), Vector2i(8, 2), Vector2i(8, 1),
	]
	Trample._paint_drag_route(input, projected_after_trample, post_route, post_route.back())
	PlanningChecklistHarness.hover(fix, post_route.back())
	var live_post: CombatPlanningPreview = overlay.get_live_preview()
	var post_preview_path: Array = live_post.preview_paths.get(unit.id, [])
	if post_preview_path != post_route:
		failures.append(
			"%s: postmove preview path %s expected %s"
			% [label, str(post_preview_path), str(post_route)],
		)
		return
	for i: int in range(1, post_preview_path.size()):
		if GridSystem.manhattan(post_preview_path[i - 1], post_preview_path[i]) != 1:
			failures.append("%s: postmove preview contains diagonal segment %s" % [label, str(post_preview_path)])
			return
	input.set_qa_pointer_grid_cell(post_route.back())
	input.on_left_press(fix.map_stub.grid_to_local(post_route.back()))
	PlanningChecklistHarness.flush_planning(fix)
	var committed_post: TimelineAction = PlanningChecklistHarness.committed_post_move(
		director, unit.id,
	)
	if committed_post == null or committed_post.waypoints != post_route.slice(1):
		failures.append(
			"%s: postmove waypoints %s expected %s"
			% [label, str(committed_post.waypoints if committed_post != null else []), str(post_route.slice(1))],
		)
		return

	var result: SimResult = _simulate_committed_plan(director)
	var expected_full_path: Array[Vector2i] = [
		pre_route[0], pre_route[1], pre_route[2],
		trample_route[1], trample_route[2],
		post_route[1], post_route[2],
	]
	var visited: Array[Vector2i] = [pre_route[0]]
	for event: SimEvent in result.events:
		if event.type != GameEnums.SimEventType.UNIT_MOVED:
			continue
		if int(event.data.get("actor", -1)) != unit.id:
			continue
		for step: Variant in event.data.get("path", []):
			if step is Vector2i:
				visited.append(step as Vector2i)
	if visited != expected_full_path:
		failures.append(
			"%s: Simulator visited %s expected premove -> skill -> postmove %s"
			% [label, str(visited), str(expected_full_path)],
		)
	var final_unit: UnitState = result.final_state.get_unit_by_id(unit.id)
	if final_unit == null or final_unit.position != post_route.back():
		failures.append(
			"%s: final simulated position %s expected %s"
			% [label, str(final_unit.position if final_unit != null else null), str(post_route.back())],
		)
	var committed_preview: CombatPlanningPreview = CombatPlanningPreview.from_sim_result(
		result, director, director.base_board,
	)
	var full_preview_path: Array = committed_preview.preview_paths.get(unit.id, [])
	if full_preview_path != expected_full_path:
		failures.append(
			"%s: committed preview path %s expected %s"
			% [label, str(full_preview_path), str(expected_full_path)],
		)


static func _test_charge_strike_composite_move_preview(failures: Array[String]) -> void:
	const BruiserFixture := preload("res://tests/harness/bruiser_planning_checklist_harness.gd")
	const ChargeStrikeId: StringName = &"bruiser_charge_strike"
	var start := Vector2i(5, 4)
	var enemy_cell := Vector2i(8, 2)
	var pre_route: Array[Vector2i] = [
		start, Vector2i(6, 4), Vector2i(6, 3),
	]
	var charge_route: Array[Vector2i] = [
		pre_route.back(), Vector2i(7, 3), Vector2i(7, 2),
	]
	var post_route: Array[Vector2i] = [
		charge_route.back(), Vector2i(8, 2), Vector2i(8, 1),
	]
	var label := "PlanningQAGate charge_strike_composite"
	var fix: Dictionary = BruiserFixture.wire_board(
		start, enemy_cell, Vector2i(-1, -1), ChargeStrikeId,
	)
	if fix.is_empty():
		failures.append("%s: Bruiser fixture missing" % label)
		return
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var overlay: TacticalPlanningOverlay = fix.overlay
	var actor: UnitState = fix.actor
	PlanningChecklistHarness.set_unit_pools(fix, actor.id, 1, 8)

	# Premove: dense hover orbit before any drag paint (red off, blue + move arrows on).
	PlanningChecklistHarness.enter_basic_movement(fix)
	var premove_sweep: Array[Vector2i] = HoverMatrix.dense_hover_cells(
		fix.board, [start], HoverMatrix.ORBIT_RADIUS, true,
	)
	HoverMatrix.probe_hover_sweep(failures, fix, {
		"label_prefix": label,
		"phase": "premove_hover",
		"hover_cells": premove_sweep,
		"sweep_from": start,
		"actor": actor,
		"ability": null,
		"stand_cell": start,
		"expect_red": false,
		"expect_blue": true,
		"move_preview_kind": "corridor",
		"suppress_target_arrow": true,
		"check_module_stand": false,
		"expect_awaiting_move_route": false,
	})
	PlanningDragE2EHarness.begin_drag_route(fix, pre_route)
	PlanningChecklistHarness.hover(fix, pre_route.back())
	var pre_live: CombatPlanningPreview = overlay.get_live_preview()
	var pre_preview_path: Array = pre_live.preview_paths.get(actor.id, [])
	if pre_preview_path != pre_route:
		failures.append(
			"%s: premove hover path %s expected %s"
			% [label, str(pre_preview_path), str(pre_route)],
		)
	var pre_slots: Dictionary = input._intent_snapshot_slots.duplicate(true)
	var pre_hover: TimelineAction = (pre_slots.get("pre", []) as Array).front() as TimelineAction
	if _slots_invalid(pre_slots) or pre_hover == null:
		failures.append("%s: premove hover slots missing" % label)
	elif pre_hover.waypoints != pre_route.slice(1):
		failures.append(
			"%s: premove hover waypoints %s expected %s"
			% [label, str(pre_hover.waypoints), str(pre_route.slice(1))],
		)
	if _slots_invalid(pre_slots):
		failures.append("%s: premove commit failed" % label)
		return
	# Premove drag orbit while keeping the painted corridor (pointer jitters during paint).
	var premove_drag_sweep: Array[Vector2i] = HoverMatrix.dense_hover_cells(
		fix.board, pre_route, 2, true,
	)
	input._begin_drag(actor, fix.map_stub.grid_to_local(pre_route.back()), true)
	input._drag_route = pre_route.duplicate()
	input._drag_last_free = pre_route.back()
	_probe_charge_strike_hover_orbit(
		failures,
		fix,
		overlay,
		input,
		actor,
		label,
		premove_drag_sweep,
		"premove_drag",
		start,
		charge_route,
		enemy_cell,
		pre_route,
		post_route,
		ChargeStrikeId,
		true,
	)
	PlanningDragE2EHarness.release_at(fix, pre_route.back())
	PlanningChecklistHarness.flush_planning(fix)
	var committed_pre: TimelineAction = PlanningChecklistHarness.committed_pre_move(
		director, actor.id,
	)
	if committed_pre == null or committed_pre.waypoints != pre_route.slice(1):
		failures.append(
			"%s: committed premove waypoints %s expected %s"
			% [label, str(committed_pre.waypoints if committed_pre != null else []), str(pre_route.slice(1))],
		)
	var pre_committed_preview: CombatPlanningPreview = overlay.get_committed_preview()
	if pre_committed_preview.preview_board != null or not pre_committed_preview.preview_paths.is_empty():
		failures.append(
			"%s: premove execution boundary retained committed preview %s"
			% [label, str(pre_committed_preview.preview_paths.get(actor.id, []))],
		)

	# Charge Strike: arm and commit its MOVE module, then observe the NEW_AIM attack.
	if PlanningChecklistHarness.select_ability(fix, ChargeStrikeId) < 0:
		failures.append("%s: Charge Strike selection failed" % label)
		return
	var stand_after_pre: UnitState = director.projected_state.get_unit_by_id(actor.id)
	if stand_after_pre == null or stand_after_pre.position != pre_route.back():
		failures.append(
			"%s: projected premove stand %s expected %s"
			% [label, str(stand_after_pre.position if stand_after_pre != null else null), str(pre_route.back())],
		)
		return
	if not _arm_awaiting_at(input, director, stand_after_pre.position):
		failures.append("%s: Charge Strike MOVE module did not arm" % label)
		return
	var move_orbit_cells: Array[Vector2i] = HoverMatrix.dense_hover_cells(
		fix.board, [stand_after_pre.position, charge_route.back()], HoverMatrix.ORBIT_RADIUS, true,
	)
	_probe_charge_strike_hover_orbit(
		failures,
		fix,
		overlay,
		input,
		actor,
		label,
		move_orbit_cells,
		"move",
		stand_after_pre.position,
		charge_route,
		enemy_cell,
		pre_route,
		post_route,
		ChargeStrikeId,
		false,
	)
	input._begin_drag(
		stand_after_pre,
		fix.map_stub.grid_to_local(charge_route[0]),
		true,
	)
	_probe_charge_strike_hover_orbit(
		failures,
		fix,
		overlay,
		input,
		actor,
		label,
		move_orbit_cells,
		"move_drag",
		stand_after_pre.position,
		charge_route,
		enemy_cell,
		pre_route,
		post_route,
		ChargeStrikeId,
		true,
	)
	for route_cell: Vector2i in charge_route.slice(1):
		input.set_qa_pointer_grid_cell(route_cell)
		input.update_drag(fix.map_stub.grid_to_local(route_cell))
	PlanningChecklistHarness.hover(fix, charge_route.back())
	var charge_move_live: CombatPlanningPreview = overlay.get_live_preview()
	var charge_move_preview_path: Array = charge_move_live.preview_paths.get(actor.id, [])
	if charge_move_preview_path != charge_route:
		failures.append(
			"%s: Charge Strike MOVE hover path %s expected %s"
			% [label, str(charge_move_preview_path), str(charge_route)],
		)
	for i: int in range(1, charge_move_preview_path.size()):
		if GridSystem.manhattan(charge_move_preview_path[i - 1], charge_move_preview_path[i]) != 1:
			failures.append(
				"%s: Charge Strike MOVE hover path contains diagonal step %s"
				% [label, str(charge_move_preview_path)],
			)
			break
	var charge_move_slots: Dictionary = input._intent_snapshot_slots.duplicate(true)
	var charge_move_action: TimelineAction = _slot_action_with_ability(
		charge_move_slots, ChargeStrikeId,
	)
	if _slots_invalid(charge_move_slots) or charge_move_action == null:
		failures.append("%s: Charge Strike MOVE hover slots missing" % label)
	elif AbilitySystem.module_target_coord(charge_move_action, 0) != charge_route.back():
		failures.append("%s: Charge Strike MOVE slot lost landing target" % label)
	if _slots_invalid(charge_move_slots):
		failures.append("%s: Charge Strike MOVE landing commit failed" % label)
		return
	PlanningDragE2EHarness.release_at(fix, charge_route.back())
	PlanningChecklistHarness.flush_planning(fix)
	if not input.awaiting_targeting_active():
		failures.append("%s: Charge Strike attack module did not remain awaiting" % label)
		return

	var damage_orbit_cells: Array[Vector2i] = HoverMatrix.dense_hover_cells(
		fix.board, [charge_route.back(), enemy_cell], HoverMatrix.ORBIT_RADIUS, true,
	)
	_probe_charge_strike_hover_orbit(
		failures,
		fix,
		overlay,
		input,
		actor,
		label,
		damage_orbit_cells,
		"damage",
		charge_route.back(),
		charge_route,
		enemy_cell,
		pre_route,
		post_route,
		ChargeStrikeId,
		false,
	)

	PlanningChecklistHarness.hover(fix, charge_route.back())
	PlanningChecklistHarness.hover(fix, enemy_cell)
	input._flush_hover_heavy_sync()
	PlanningChecklistHarness.flush_planning(fix)
	var charge_live: CombatPlanningPreview = overlay.get_live_preview()
	var charge_preview_path: Array = charge_live.preview_paths.get(actor.id, [])
	if charge_preview_path != [charge_route.back()]:
		failures.append(
			"%s: Charge Strike attack hover path %s expected committed landing %s; live=%s projected=%s timing=%d"
			% [
				label,
				str(charge_preview_path),
				str([charge_route.back()]),
				str(director.live_planning_board().get_unit_by_id(actor.id).position),
				str(director.projected_state.get_unit_by_id(actor.id).position),
				director.get_planning_move_timing(actor.id),
			],
		)
	if not overlay.targeting_intent_arrow_cells().is_empty():
		var arrow: Array[Vector2i] = overlay.targeting_intent_arrow_cells()
		if arrow.size() >= 2:
			var arrow_from: Vector2i = arrow[0] as Vector2i
			var arrow_to: Vector2i = arrow[1] as Vector2i
			if arrow_from != charge_route.back():
				failures.append(
					"%s: strike arrow origin %s expected landing %s"
					% [label, arrow_from, charge_route.back()],
				)
			if arrow_from.x != arrow_to.x and arrow_from.y != arrow_to.y:
				failures.append(
					"%s: strike arrow is diagonal %s -> %s"
					% [label, arrow_from, arrow_to],
				)
		else:
			failures.append("%s: Charge Strike drew unexpected targeting arrow %s" % [label, str(arrow)])
	var charge_hover_slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, enemy_cell)
	var charge_hover_action: TimelineAction = _slot_action_with_ability(
		charge_hover_slots, ChargeStrikeId,
	)
	if _slots_invalid(charge_hover_slots) or charge_hover_action == null:
		failures.append(
			"%s: Charge Strike hover slots missing invalid=%s slots=%s"
			% [label, str(charge_hover_slots.get("invalid", "")), str(charge_hover_slots)],
		)
	else:
		if charge_hover_action.waypoints != charge_route.slice(1):
			failures.append(
				"%s: Charge Strike hover waypoints %s expected %s"
				% [label, str(charge_hover_action.waypoints), str(charge_route.slice(1))],
			)
		var move_target: Vector2i = AbilitySystem.module_target_coord(charge_hover_action, 0)
		var strike_target: Vector2i = AbilitySystem.module_target_coord(charge_hover_action, 1)
		if move_target != charge_route.back() or strike_target != enemy_cell:
			failures.append(
				"%s: Charge Strike module targets move=%s strike=%s expected move=%s strike=%s"
				% [label, move_target, strike_target, charge_route.back(), enemy_cell],
			)
	var charge_click_slots: Dictionary = PlanningChecklistHarness.slots_for_click(fix, enemy_cell)
	if _intent_slot_signature(charge_hover_slots) != _intent_slot_signature(charge_click_slots):
		failures.append("%s: Charge Strike hover slots differ from click slots" % label)
	input.set_qa_pointer_grid_cell(enemy_cell)
	input.on_left_press(fix.map_stub.grid_to_local(enemy_cell))
	if director.find_awaiting_action(actor.id) != null:
		failures.append("%s: Charge Strike click commit failed" % label)
		return
	PlanningChecklistHarness.flush_planning(fix)
	var committed_charge: TimelineAction = PlanningChecklistHarness.committed_action(
		director, actor.id,
	)
	if committed_charge == null:
		failures.append("%s: committed Charge Strike action missing" % label)
		return
	if committed_charge.waypoints != charge_route.slice(1):
		failures.append(
			"%s: committed Charge Strike waypoints %s expected %s"
			% [label, str(committed_charge.waypoints), str(charge_route.slice(1))],
		)
	if AbilitySystem.module_target_coord(committed_charge, 0) != charge_route.back():
		failures.append("%s: committed MOVE target is not Charge Strike landing" % label)
	if AbilitySystem.module_target_coord(committed_charge, 1) != enemy_cell:
		failures.append("%s: committed DAMAGE target is not hovered enemy" % label)
	var projected_after_charge: UnitState = director.projected_state.get_unit_by_id(actor.id)
	if projected_after_charge == null or projected_after_charge.position != charge_route.back():
		failures.append(
			"%s: projected Charge Strike stand %s expected %s"
			% [label, str(projected_after_charge.position if projected_after_charge != null else null), str(charge_route.back())],
		)
	var charge_committed_preview: CombatPlanningPreview = overlay.get_committed_preview()
	var expected_after_charge: Array[Vector2i] = [
		pre_route[0], pre_route[1], pre_route[2], charge_route[1], charge_route[2],
	]
	if charge_committed_preview.preview_paths.get(actor.id, []) != expected_after_charge:
		failures.append(
			"%s: committed Charge Strike preview %s expected %s"
			% [label, str(charge_committed_preview.preview_paths.get(actor.id, [])), str(expected_after_charge)],
		)

	# Postmove: its route must begin at Charge Strike's actual landing, not turn start.
	PlanningChecklistHarness.enter_basic_movement(fix)
	var post_orbit_cells: Array[Vector2i] = HoverMatrix.dense_hover_cells(
		fix.board, [post_route[0], post_route.back()], HoverMatrix.ORBIT_RADIUS, true,
	)
	input._begin_drag(
		projected_after_charge,
		fix.map_stub.grid_to_local(post_route[0]),
		true,
	)
	_probe_charge_strike_hover_orbit(
		failures,
		fix,
		overlay,
		input,
		actor,
		label,
		post_orbit_cells,
		"postmove_drag",
		post_route[0],
		charge_route,
		enemy_cell,
		pre_route,
		post_route,
		ChargeStrikeId,
		true,
	)
	for route_cell: Vector2i in post_route.slice(1):
		input.set_qa_pointer_grid_cell(route_cell)
		input.update_drag(fix.map_stub.grid_to_local(route_cell))
	PlanningChecklistHarness.hover(fix, post_route.back())
	var post_live: CombatPlanningPreview = overlay.get_live_preview()
	var post_preview_path: Array = post_live.preview_paths.get(actor.id, [])
	if post_preview_path != post_route:
		failures.append(
			"%s: postmove hover path %s expected %s"
			% [label, str(post_preview_path), str(post_route)],
		)
	var post_slots: Dictionary = input._intent_snapshot_slots.duplicate(true)
	var post_hover: TimelineAction = (post_slots.get("post", []) as Array).front() as TimelineAction
	if _slots_invalid(post_slots) or post_hover == null:
		failures.append("%s: postmove hover slots missing" % label)
	elif post_hover.waypoints != post_route.slice(1):
		failures.append(
			"%s: postmove hover waypoints %s expected %s"
			% [label, str(post_hover.waypoints), str(post_route.slice(1))],
		)
	if _slots_invalid(post_slots):
		failures.append("%s: postmove click commit failed" % label)
		return
	PlanningDragE2EHarness.release_at(fix, post_route.back())
	PlanningChecklistHarness.flush_planning(fix)
	var committed_post: TimelineAction = PlanningChecklistHarness.committed_post_move(
		director, actor.id,
	)
	if committed_post == null or committed_post.waypoints != post_route.slice(1):
		failures.append(
			"%s: committed postmove waypoints %s expected %s"
			% [label, str(committed_post.waypoints if committed_post != null else []), str(post_route.slice(1))],
		)

	# Final parity: one simulator path and one ordered event stream must contain all three legs.
	var result: SimResult = _simulate_committed_plan(director)
	var expected_full_path: Array[Vector2i] = [
		pre_route[0], pre_route[1], pre_route[2],
		charge_route[1], charge_route[2], post_route[1], post_route[2],
	]
	var visited: Array[Vector2i] = [start]
	var charge_move_index := -1
	var damage_index := -1
	var push_index := -1
	var post_move_index := -1
	for event_index: int in range(result.events.size()):
		var event: SimEvent = result.events[event_index] as SimEvent
		if event == null:
			continue
		if event.type == GameEnums.SimEventType.UNIT_MOVED:
			if int(event.data.get("actor", -1)) != actor.id:
				continue
			for step: Variant in event.data.get("path", []):
				if step is Vector2i:
					visited.append(step as Vector2i)
			if event.data.get("ability_id", &"") == ChargeStrikeId:
				charge_move_index = event_index
			elif int(event.data.get("move_timing", GameEnums.MoveTiming.PRE_ACTION)) == GameEnums.MoveTiming.POST_ACTION:
				post_move_index = event_index
		elif event.type == GameEnums.SimEventType.UNIT_DAMAGED and int(event.data.get("unit", -1)) == 2:
			damage_index = event_index
		elif event.type == GameEnums.SimEventType.UNIT_PUSHED and int(event.data.get("unit", -1)) == 2:
			push_index = event_index
	if visited != expected_full_path:
		failures.append(
			"%s: Simulator path %s expected %s"
			% [label, str(visited), str(expected_full_path)],
		)
	if charge_move_index < 0 or damage_index < 0 or push_index < 0 or post_move_index < 0:
		failures.append(
			"%s: missing ordered Charge Strike events move=%d damage=%d push=%d postmove=%d"
			% [label, charge_move_index, damage_index, push_index, post_move_index],
		)
	elif not (charge_move_index < damage_index and damage_index < push_index and push_index < post_move_index):
		failures.append(
			"%s: event order move=%d damage=%d push=%d postmove=%d"
			% [label, charge_move_index, damage_index, push_index, post_move_index],
		)
	var final_unit: UnitState = result.final_state.get_unit_by_id(actor.id)
	if final_unit == null or final_unit.position != post_route.back():
		failures.append(
			"%s: final simulated position %s expected %s"
			% [label, str(final_unit.position if final_unit != null else null), str(post_route.back())],
		)
	var final_preview: CombatPlanningPreview = CombatPlanningPreview.from_sim_result(
		result, director, director.base_board,
	)
	if final_preview.preview_paths.get(actor.id, []) != expected_full_path:
		failures.append(
			"%s: final preview path %s expected %s"
			% [label, str(final_preview.preview_paths.get(actor.id, [])), str(expected_full_path)],
		)
	if int(final_preview.action_splits.get(actor.id, -1)) != pre_route.size() - 1:
		failures.append(
			"%s: action split %s expected %d"
			% [label, str(final_preview.action_splits.get(actor.id, -1)), pre_route.size() - 1],
		)
	if int(final_preview.preview_post_splits.get(actor.id, -1)) != expected_after_charge.size():
		failures.append(
			"%s: post split %s expected %d"
			% [label, str(final_preview.preview_post_splits.get(actor.id, -1)), expected_after_charge.size()],
		)


static func _assert_move_preview_origin_contract(
	failures: Array[String],
	label: String,
	director: CombatDirector,
	unit_id: int,
	expected_pre_stand: Vector2i,
	expected_post_stand: Vector2i = Vector2i(-999999, -999999),
) -> void:
	var board: BoardState = director.board if director.board != null else director.base_board
	var pre_origin: Vector2i = CombatPlanningPreview.planning_move_origin_cell_for_timing(
		director, board, unit_id, GameEnums.MoveTiming.PRE_ACTION,
	)
	if pre_origin != expected_pre_stand:
		failures.append(
			"PlanningQAGate %s: pre-move origin must be %s (got %s)"
			% [label, expected_pre_stand, pre_origin],
		)
	if expected_post_stand.x <= -900000:
		return
	var post_origin: Vector2i = CombatPlanningPreview.planning_move_origin_cell_for_timing(
		director, board, unit_id, GameEnums.MoveTiming.POST_ACTION,
	)
	if post_origin != expected_post_stand:
		failures.append(
			"PlanningQAGate %s: post-move origin must be %s (got %s)"
			% [label, expected_post_stand, post_origin],
		)


static func _test_push_through_repaths_off_expensive_walk(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var bruiser_def: UnitData = DataLibrary.get_unit(&"bruiser")
	var push: AbilityData = null
	for ability: AbilityData in bruiser_def.abilities:
		if ability != null and ability.id == &"bruiser_push_through":
			push = ability
			break
	if push == null:
		failures.append("PlanningQAGate push_through repath: ability missing")
		return
	var actor := UnitState.create(1, bruiser_def, GameEnums.Team.PLAYER, Vector2i(4, 5), {
		"active_abilities": [push],
	})
	actor.movement.points_left = 2
	var ally := UnitState.create(2, DataLibrary.get_unit(&"knight"), GameEnums.Team.PLAYER, Vector2i(3, 5), {
		"active_abilities": [],
	})
	var board := _plain_board(Vector2i(8, 8), [actor, ally])
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	director.selected_ability_index = 0
	input._director = director
	var expensive_route: Array[Vector2i] = [Vector2i(4, 4), Vector2i(3, 4)]
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1, Vector2i(3, 5), expensive_route,
	)
	if bool(slots.get("invalid", false)):
		failures.append(
			"PlanningQAGate push_through repath: ally hover must repath off expensive walk (invalid=%s)"
			% str(slots.get("invalid", "")),
		)
		return
	var pre_moves: Array = slots.get("pre", [])
	if pre_moves.is_empty():
		failures.append("PlanningQAGate push_through repath: expected premove push through on ally")
		return
	var pre_action: TimelineAction = pre_moves[0] as TimelineAction
	if pre_action == null or pre_action.ability == null or pre_action.ability.id != &"bruiser_push_through":
		failures.append("PlanningQAGate push_through repath: premove must be push through on ally")
		return
	if not pre_action.waypoints.is_empty():
		failures.append("PlanningQAGate push_through repath: repathed premove must drop painted walk")


static func _test_shield_bash_full_approach_push_preview(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate integrity: Shield Bash missing for full approach push")
		return
	director.selected_ability_index = bash_idx
	var slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	var actions: Array[TimelineAction] = _actions_from_slots(slots)
	if actions.size() < 2:
		failures.append("PlanningQAGate integrity: enemy hover must plan walk + bash together")
		return
	var preview := _preview_for_actions(director, actions)
	var pushes: Array = preview.preview_pushes.get(2, [])
	var seg: Array = _push_segment(pushes)
	if seg.size() < 2:
		failures.append("PlanningQAGate integrity: full approach + bash must preview push")
		return
	var from_cell: Vector2i = seg[0] as Vector2i
	var to_cell: Vector2i = seg[1] as Vector2i
	if to_cell.x <= from_cell.x:
		failures.append(
			"PlanningQAGate integrity: full approach bash must push east %s -> %s"
			% [str(from_cell), str(to_cell)],
		)


static func _test_committed_hook_approach_uses_premove(failures: Array[String]) -> void:
	var fix: Dictionary = _hook_committed_approach_fixture()
	if fix.input == null:
		failures.append("PlanningQAGate integrity: Chain Hook missing for committed approach")
		return
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var knight: UnitState = fix.knight
	var enemy: UnitState = fix.enemy
	var enemy_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, enemy.position, [] as Array[Vector2i], [] as Array[Vector2i], Vector2i(-999999, -999999),
	)
	if (enemy_slots.get("pre", []) as Array).is_empty():
		failures.append(
			"PlanningQAGate integrity: committed hook + enemy hover must build pre-move approach",
		)
	if not (enemy_slots.get("post", []) as Array).is_empty():
		failures.append(
			"PlanningQAGate integrity: committed hook approach must not use post-move column",
		)
	var approach_cell: Vector2i = director.preview_approach_tile(
		1, enemy.id, 0, Vector2i(3, 3),
	)
	if approach_cell == knight.position:
		failures.append("PlanningQAGate integrity: hook fixture should need approach tile")
		return
	var stand_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, approach_cell, [] as Array[Vector2i], [] as Array[Vector2i], Vector2i(-999999, -999999),
	)
	if (stand_slots.get("pre", []) as Array).is_empty():
		failures.append(
			"PlanningQAGate integrity: committed hook + approach stand hover must build pre-move",
		)
	if not (stand_slots.get("post", []) as Array).is_empty():
		failures.append(
			"PlanningQAGate integrity: approach stand hover must not use post-move column",
		)


static func _test_out_of_range_hover_is_invalid(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate integrity: Shield Bash missing for range gate")
		return
	director.selected_ability_index = bash_idx
	var oob_slots: Dictionary = _commit_slots_at(input, 1, Vector2i(-1, 0))
	if not _slots_invalid(oob_slots):
		failures.append(
			"PlanningQAGate integrity: out-of-bounds hover must be rejected",
		)


static func _test_trample_paint_preview_matches_route(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate integrity: Trampling missing for paint preview")
		return
	TramplingAdvanceE2ETest._arm_trample_awaiting(input, fix.director, unit)
	var route: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, route, TramplingAdvanceE2ETest.END_CELL)
	input._sync_drag_route_stand()
	var expected: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	var preview_path: Array = input.preview_state.preview_paths.get(1, [])
	if preview_path != expected:
		failures.append(
			"PlanningQAGate integrity: trample live preview path %s expected %s"
			% [str(preview_path), str(expected)],
		)


static func _test_trample_commit_preserves_east_then_north(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate integrity: Trampling missing for commit waypoints")
		return
	TramplingAdvanceE2ETest._arm_trample_awaiting(input, director, unit)
	var route: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, route, TramplingAdvanceE2ETest.END_CELL)
	TramplingAdvanceE2ETest._commit_drag_route(input, director, TramplingAdvanceE2ETest.END_CELL)
	var action: TimelineAction = TramplingAdvanceE2ETest._committed_trample_action(director)
	if action == null:
		failures.append("PlanningQAGate integrity: missing committed trample after paint")
		return
	if action.waypoints != TramplingAdvanceE2ETest.EAST_THEN_NORTH:
		failures.append(
			"PlanningQAGate integrity: trample waypoints %s expected E-then-N %s"
			% [str(action.waypoints), str(TramplingAdvanceE2ETest.EAST_THEN_NORTH)],
		)


static func _test_trample_sim_follows_painted_order(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate integrity: Trampling missing for sim order")
		return
	TramplingAdvanceE2ETest._arm_trample_awaiting(input, director, unit)
	var route: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, route, TramplingAdvanceE2ETest.END_CELL)
	if TramplingAdvanceE2ETest._commit_drag_route(input, director, TramplingAdvanceE2ETest.END_CELL).is_empty():
		failures.append("PlanningQAGate integrity: trample commit failed for sim order")
		return
	var start_board: BoardState = director.base_board.clone()
	start_board.intents = []
	var result: SimResult = Simulator.simulate(start_board, director.get_player_plan())
	var visited: Array[Vector2i] = [TramplingAdvanceE2ETest.START_CELL]
	for event: SimEvent in result.events:
		if event.type != GameEnums.SimEventType.UNIT_MOVED:
			continue
		if int(event.data.get("actor", -1)) != 1:
			continue
		var path_v: Variant = event.data.get("path", [])
		if path_v is Array:
			for step: Variant in path_v:
				if step is Vector2i:
					visited.append(step)
	var expected: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	if visited != expected:
		failures.append(
			"PlanningQAGate integrity: trample sim walk %s expected painted E-then-N %s"
			% [str(visited), str(expected)],
		)


static func _test_trample_repath_does_not_replace_painted_order(
	failures: Array[String],
) -> void:
	TramplingAdvanceE2ETest._test_mouse_jump_drag_exposes_pathfinder_reorder(
		failures,
	)


static func _test_trample_post_move_preview_commit_sim(
	failures: Array[String],
) -> void:
	TramplingAdvanceE2ETest._test_post_move_sim_preview_keeps_trample_paint_order(
		failures,
	)


static func _test_trample_full_preview_truth_click(failures: Array[String]) -> void:
	var raw_fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(
		TramplingAdvanceE2ETest.START_CELL,
	)
	var fix: Dictionary = PlanningDragE2EHarness.wire_fixture(raw_fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var overlay: TacticalPlanningOverlay = fix.overlay
	var unit: UnitState = fix.unit
	var label := "PlanningQAGate trample_full_truth"
	if fix.trample_idx < 0:
		failures.append("%s: Trampling Advance missing" % label)
		return
	if not TramplingAdvanceE2ETest._arm_trample_awaiting(input, director, unit):
		failures.append("%s: awaiting arm failed" % label)
		return
	var route: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	TramplingAdvanceE2ETest._paint_drag_route(
		input,
		unit,
		route,
		TramplingAdvanceE2ETest.END_CELL,
	)
	input.set_qa_pointer_grid_cell(TramplingAdvanceE2ETest.END_CELL)
	input.on_hover_moved(TramplingAdvanceE2ETest.END_CELL)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	var live: CombatPlanningPreview = overlay.get_live_preview()
	if live == null or live.preview_board == null:
		failures.append("%s: valid hover preview board missing" % label)
		return
	var live_unit: UnitState = live.preview_board.get_unit_by_id(unit.id)
	if live_unit == null or live_unit.position != TramplingAdvanceE2ETest.END_CELL:
		failures.append(
			"%s: preview stand %s != %s"
			% [
				str(live_unit.position if live_unit != null else null),
				str(TramplingAdvanceE2ETest.END_CELL),
			],
		)
	var live_path: Array = live.preview_paths.get(unit.id, [])
	if live_path != route:
		failures.append("%s: preview path %s != painted %s" % [
			label, str(live_path), str(route),
		])
	var blue_tiles: Array[Vector2i] = PlanningChecklistHarness.collect_blue_tiles(fix)
	if not blue_tiles.has(route[1]):
		failures.append("%s: blue tiles missing first painted waypoint" % label)
	if not input.action_range_visible_for_hover():
		failures.append("%s: action-range overlay hidden for valid Trample hover" % label)
	else:
		var trample: AbilityData = unit.active_abilities[fix.trample_idx]
		var origin: Vector2i = CombatPlanningPreview.planning_move_origin_cell(
			director,
			fix.board,
			unit.id,
		)
		var expected_red: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
			fix.board,
			unit,
			trample,
			origin,
		)
		var red_matches: bool = false
		for tile: Vector2i in expected_red:
			if overlay.is_hover_action_range_tile(tile):
				red_matches = true
				break
		if not red_matches:
			failures.append("%s: red tiles do not match canonical Trample range" % label)
	var hover_slots: Dictionary = input._intent_snapshot_slots.duplicate(true)
	if not input._intent_snapshot_valid or _slots_invalid(hover_slots):
		failures.append("%s: valid hover snapshot missing or invalid" % label)
		return
	var action: TimelineAction = _slot_action_with_ability(hover_slots, TRAMPLE_ID)
	if action == null or action.target_coord != TramplingAdvanceE2ETest.END_CELL:
		failures.append("%s: hover slots missing exact Trample target" % label)
	elif action.waypoints != TramplingAdvanceE2ETest.EAST_THEN_NORTH:
		failures.append("%s: hover waypoints drifted to %s" % [
			label, str(action.waypoints),
		])
	var slot_icon: String = input._cursor_icon_from_commit_slots(hover_slots, unit)
	if slot_icon.is_empty():
		failures.append("%s: finalized Trample slots produced no cursor icon" % label)
	_assert_pending_hover_ghost(input, director, fix.board, unit.id, label, failures)
	var map_stub: QaPlanningMapStub = fix.map_stub
	input.on_left_press(map_stub.grid_to_local(TramplingAdvanceE2ETest.END_CELL))
	var committed: TimelineAction = TramplingAdvanceE2ETest._committed_trample_action(director)
	if committed == null or committed.waypoints != TramplingAdvanceE2ETest.EAST_THEN_NORTH:
		failures.append("%s: real click did not ratify hover waypoints" % label)
		return
	var result: SimResult = _simulate_committed_plan(director)
	var final_unit: UnitState = result.final_state.get_unit_by_id(unit.id)
	if final_unit == null or final_unit.position != TramplingAdvanceE2ETest.END_CELL:
		failures.append("%s: Simulator landing %s != hover stand %s" % [
			label,
			str(final_unit.position if final_unit != null else null),
			str(TramplingAdvanceE2ETest.END_CELL),
		])


static func _test_teleport_full_preview_truth_click(failures: Array[String]) -> void:
	var start := Vector2i(2, 2)
	var target := Vector2i(4, 3)
	var fix: Dictionary = _mage_teleport_fixture(start, target)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var overlay: TacticalPlanningOverlay = fix.overlay
	var mage: UnitState = fix.mage
	var label := "PlanningQAGate teleport_full_truth"
	if int(fix.teleport_idx) < 0:
		failures.append("%s: Mage Teleport missing" % label)
		return
	if not AbilitySystem.ability_uses_caster_teleport(fix.teleport, mage):
		failures.append("%s: factory Teleport ability is not marked caster-teleport" % label)
		return
	director.set_awaiting_action(mage.id, fix.teleport)
	director.flush_plan_refresh_signals_if_pending()
	if not input.awaiting_targeting_active():
		failures.append("%s: awaiting teleport target was not armed" % label)
		return
	input.on_hover_moved(target)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	var live: CombatPlanningPreview = overlay.get_live_preview()
	if live == null or live.preview_board == null:
		failures.append("%s: valid teleport preview board missing" % label)
		return
	var live_mage: UnitState = live.preview_board.get_unit_by_id(mage.id)
	if live_mage == null or live_mage.position != target:
		failures.append("%s: preview landing %s != %s" % [
			label,
			str(live_mage.position if live_mage != null else null),
			str(target),
		])
	var live_path: Array = live.preview_paths.get(mage.id, [])
	if live_path != [start, target]:
		failures.append("%s: teleport path %s != direct hop %s" % [
			label, str(live_path), str([start, target]),
		])
	var hover_slots: Dictionary = input._intent_snapshot_slots.duplicate(true)
	if not input._intent_snapshot_valid or _slots_invalid(hover_slots):
		failures.append("%s: valid teleport snapshot missing or invalid" % label)
		return
	var teleport: TimelineAction = _slot_action_with_ability(hover_slots, MAGE_TELEPORT_ID)
	if teleport == null or teleport.target_coord != target:
		failures.append("%s: finalized slots lost teleport target" % label)
	var slot_icon: String = input._cursor_icon_from_commit_slots(hover_slots, mage)
	if slot_icon.is_empty():
		failures.append("%s: finalized teleport slots produced no cursor icon" % label)
	_assert_pending_hover_ghost(input, director, fix.board, mage.id, label, failures)
	input.set_qa_pointer_grid_cell(target)
	input.on_left_press(fix.map_stub.grid_to_local(target))
	var committed: TimelineAction = _first_plan_action_for_unit(
		director,
		mage.id,
		MAGE_TELEPORT_ID,
	)
	if committed == null or committed.target_coord != target:
		failures.append("%s: real click did not ratify teleport target" % label)
		return
	var result: SimResult = _simulate_committed_plan(director)
	var final_mage: UnitState = result.final_state.get_unit_by_id(mage.id)
	if final_mage == null or final_mage.position != target:
		failures.append("%s: Simulator landing %s != %s" % [
			label,
			str(final_mage.position if final_mage != null else null),
			str(target),
		])


static func _test_bash_slots_preview_board_parity(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate preview parity: Shield Bash missing")
		return
	var slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	if _slots_invalid(slots):
		failures.append("PlanningQAGate preview parity: bash enemy hover must be valid")
		return
	var preview_dict: Dictionary = _preview_dict_from_cell(input, 1, ENEMY_POS)
	if bool(preview_dict.get("invalid", false)):
		failures.append("PlanningQAGate preview parity: slots preview dict must not be invalid")
		return
	var preview: CombatPlanningPreview = _preview_from_dict(director, preview_dict)
	var pushed_to: Vector2i = _enemy_push_destination(preview, 2)
	if pushed_to.x < -900000:
		failures.append("PlanningQAGate preview parity: slots preview must include push segment")
		return
	if preview.preview_board == null:
		failures.append("PlanningQAGate preview parity: slots preview missing preview_board")
		return
	var pv_enemy: UnitState = preview.preview_board.get_unit_by_id(2)
	if pv_enemy == null:
		failures.append("PlanningQAGate preview parity: enemy missing on slots preview board")
		return
	if pv_enemy.position != pushed_to:
		failures.append(
			"PlanningQAGate preview parity: preview_board enemy %s must match push dest %s"
			% [str(pv_enemy.position), str(pushed_to)],
		)


static func _test_hover_click_drop_slot_parity(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	var input: CombatPlanningInput = fix.input
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate hover/click/drop parity: Shield Bash missing")
		return
	_clear_drag_state(input)
	var hover_slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	var click_slots: Dictionary = _click_slots_at(input, 1, ENEMY_POS)
	var drop_slots: Dictionary = _drop_slots_at(input, 1, ENEMY_POS)
	if _slots_invalid(hover_slots) or _slots_invalid(click_slots) or _slots_invalid(drop_slots):
		failures.append("PlanningQAGate hover/click/drop parity: bash enemy must be valid in all modes")
		return
	var hover_sig: String = _intent_slot_signature(hover_slots)
	var click_sig: String = _intent_slot_signature(click_slots)
	var drop_sig: String = _intent_slot_signature(drop_slots)
	if hover_sig != click_sig:
		failures.append(
			"PlanningQAGate hover/click/drop parity: interaction vs click differ %s vs %s"
			% [hover_sig, click_sig],
		)
	if click_sig != drop_sig:
		failures.append(
			"PlanningQAGate hover/click/drop parity: selection vs drop differ %s vs %s"
			% [click_sig, drop_sig],
		)


static func _test_click_drop_parity_bash_enemy(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate click/drop bash: Shield Bash missing")
		return
	_clear_drag_state(fix.input)
	_assert_click_drop_signature_parity(failures, "bash enemy", fix.input, 1, ENEMY_POS)


static func _test_click_drop_parity_walk_adjacent(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	var director: CombatDirector = fix.director
	director.selected_ability_index = -1
	_clear_drag_state(fix.input)
	_assert_click_drop_signature_parity(failures, "walk adjacent", fix.input, 1, Vector2i(5, 5))


static func _test_click_drop_parity_bash_approach(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate click/drop approach: Shield Bash missing")
		return
	_clear_drag_state(fix.input)
	_assert_click_drop_signature_parity(failures, "bash approach", fix.input, 1, BASH_APPROACH)


static func _test_click_drop_parity_hook_enemy(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(Vector2i(1, 3), Vector2i(4, 3))
	_wire_click_drop_context(fix)
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate click/drop hook: Chain Hook missing")
		return
	fix.director.selected_ability_index = hook_idx
	_clear_drag_state(fix.input)
	_assert_click_drop_signature_parity(
		failures, "hook enemy", fix.input, 1, fix.enemy.position,
	)


static func _test_click_drop_parity_oob_invalid(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	var director: CombatDirector = fix.director
	_clear_drag_state(fix.input)
	var oob := Vector2i(-1, 0)
	var click_slots: Dictionary = _click_slots_at(fix.input, 1, oob)
	var drop_slots: Dictionary = _drop_slots_at(fix.input, 1, oob)
	if not _slots_invalid(click_slots):
		failures.append("PlanningQAGate click/drop oob: selection must reject out-of-bounds")
	if _actions_from_slots(drop_slots).size() > 0:
		failures.append("PlanningQAGate click/drop oob: drop must not offer OOB actions")
	if director.commit_from_slots(1, click_slots):
		failures.append("PlanningQAGate click/drop oob: selection commit must fail")
	if director.commit_from_slots(1, drop_slots):
		failures.append("PlanningQAGate click/drop oob: drop commit must fail")


static func _test_click_drop_cursor_parity_bash(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	var input: CombatPlanningInput = fix.input
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate click/drop cursor bash: Shield Bash missing")
		return
	_clear_drag_state(input)
	var click_slots: Dictionary = _click_slots_at(input, 1, ENEMY_POS)
	var drop_slots: Dictionary = _drop_slots_at(input, 1, ENEMY_POS)
	var click_icon: String = input._cursor_icon_from_commit_slots(click_slots, fix.knight)
	var drop_icon: String = input._cursor_icon_from_commit_slots(drop_slots, fix.knight)
	if click_icon != drop_icon:
		failures.append(
			"PlanningQAGate click/drop cursor bash: selection %s != drop %s"
			% [click_icon, drop_icon],
		)


static func _test_click_drop_cursor_parity_walk(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	director.selected_ability_index = -1
	_clear_drag_state(input)
	var dest := Vector2i(5, 5)
	var click_slots: Dictionary = _click_slots_at(input, 1, dest)
	var drop_slots: Dictionary = _drop_slots_at(input, 1, dest)
	if _slots_invalid(click_slots) or _slots_invalid(drop_slots):
		failures.append("PlanningQAGate click/drop cursor walk: adjacent walk must be valid")
		return
	var click_icon: String = input._cursor_icon_from_commit_slots(click_slots, fix.knight)
	var drop_icon: String = input._cursor_icon_from_commit_slots(drop_slots, fix.knight)
	if click_icon != drop_icon:
		failures.append(
			"PlanningQAGate click/drop cursor walk: selection %s != drop %s"
			% [click_icon, drop_icon],
		)


static func _test_click_drop_commit_sim_bash(failures: Array[String]) -> void:
	var click_fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(click_fix)
	if _bash_img1_ready(click_fix) < 0:
		failures.append("PlanningQAGate click/drop sim bash: Shield Bash missing")
		return
	_clear_drag_state(click_fix.input)
	var click_slots: Dictionary = _click_slots_at(click_fix.input, 1, ENEMY_POS)
	if _slots_invalid(click_slots):
		failures.append("PlanningQAGate click/drop sim bash: selection slots invalid")
		return
	var click_enemy_pos: Vector2i = _sim_enemy_position_after_slots_commit(
		click_fix.director, 1, 2, click_slots,
	)
	if click_enemy_pos.x < -900000:
		failures.append("PlanningQAGate click/drop sim bash: selection commit/sim failed")
		return
	var drop_fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(drop_fix)
	if _bash_img1_ready(drop_fix) < 0:
		failures.append("PlanningQAGate click/drop sim bash: Shield Bash missing on drop fixture")
		return
	_clear_drag_state(drop_fix.input)
	var drop_slots: Dictionary = _drop_slots_at(drop_fix.input, 1, ENEMY_POS)
	if _slots_invalid(drop_slots):
		failures.append("PlanningQAGate click/drop sim bash: drop slots invalid")
		return
	var drop_enemy_pos: Vector2i = _sim_enemy_position_after_slots_commit(
		drop_fix.director, 1, 2, drop_slots,
	)
	if drop_enemy_pos != click_enemy_pos:
		failures.append(
			"PlanningQAGate click/drop sim bash: enemy at %s (selection) vs %s (drop)"
			% [str(click_enemy_pos), str(drop_enemy_pos)],
		)


static func _test_click_drop_commit_sim_walk(failures: Array[String]) -> void:
	var dest := Vector2i(5, 5)
	var click_fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(click_fix)
	click_fix.director.selected_ability_index = -1
	_clear_drag_state(click_fix.input)
	var click_slots: Dictionary = _click_slots_at(click_fix.input, 1, dest)
	if _slots_invalid(click_slots):
		failures.append("PlanningQAGate click/drop sim walk: selection slots invalid")
		return
	var click_knight_pos: Vector2i = _sim_unit_position_after_slots_commit(
		click_fix.director, 1, click_slots,
	)
	if click_knight_pos != dest:
		failures.append(
			"PlanningQAGate click/drop sim walk: selection ended at %s expected %s"
			% [str(click_knight_pos), str(dest)],
		)
		return
	var drop_fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(drop_fix)
	drop_fix.director.selected_ability_index = -1
	_clear_drag_state(drop_fix.input)
	var drop_slots: Dictionary = _drop_slots_at(drop_fix.input, 1, dest)
	if _slots_invalid(drop_slots):
		failures.append("PlanningQAGate click/drop sim walk: drop slots invalid")
		return
	var drop_knight_pos: Vector2i = _sim_unit_position_after_slots_commit(
		drop_fix.director, 1, drop_slots,
	)
	if drop_knight_pos != click_knight_pos:
		failures.append(
			"PlanningQAGate click/drop sim walk: knight at %s (selection) vs %s (drop)"
			% [str(click_knight_pos), str(drop_knight_pos)],
		)


static func _test_click_drop_drag_walk_sim_parity(failures: Array[String]) -> void:
	var dest := Vector2i(5, 5)
	var click_fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(click_fix)
	click_fix.director.selected_ability_index = -1
	_clear_drag_state(click_fix.input)
	var click_slots: Dictionary = _click_slots_at(click_fix.input, 1, dest)
	var click_pos: Vector2i = _sim_unit_position_after_slots_commit(click_fix.director, 1, click_slots)
	if click_pos != dest:
		failures.append(
			"PlanningQAGate click/drop drag walk: selection baseline failed at %s"
			% str(click_pos),
		)
		return
	var drop_fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(drop_fix)
	drop_fix.director.selected_ability_index = -1
	var route: Array[Vector2i] = [KNIGHT_START, dest]
	TramplingAdvanceE2ETest._paint_drag_route(drop_fix.input, drop_fix.knight, route, dest)
	var drop_slots: Dictionary = _drop_slots_at(drop_fix.input, 1, dest)
	if _slots_invalid(drop_slots):
		failures.append("PlanningQAGate click/drop drag walk: painted drop slots invalid")
		return
	var drop_pos: Vector2i = _sim_unit_position_after_slots_commit(drop_fix.director, 1, drop_slots)
	if drop_pos != click_pos:
		failures.append(
			"PlanningQAGate click/drop drag walk: painted drop ended at %s, selection at %s"
			% [str(drop_pos), str(click_pos)],
		)


static func _test_click_drop_drag_bash_enemy_parity(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate click/drop drag bash: Shield Bash missing")
		return
	_clear_drag_state(fix.input)
	var click_slots: Dictionary = _click_slots_at(fix.input, 1, ENEMY_POS)
	if _slots_invalid(click_slots):
		failures.append("PlanningQAGate click/drop drag bash: selection slots invalid")
		return
	var route: Array[Vector2i] = [KNIGHT_START, Vector2i(5, 5), BASH_APPROACH]
	TramplingAdvanceE2ETest._paint_drag_route(fix.input, fix.knight, route, BASH_APPROACH)
	var drop_slots: Dictionary = _drop_slots_at(fix.input, 1, ENEMY_POS)
	if _slots_invalid(drop_slots):
		failures.append("PlanningQAGate click/drop drag bash: painted drop on enemy invalid")
		return
	if _intent_slot_signature(click_slots) != _intent_slot_signature(drop_slots):
		failures.append(
			"PlanningQAGate click/drop drag bash: selection vs painted-drop differ %s vs %s"
			% [_intent_slot_signature(click_slots), _intent_slot_signature(drop_slots)],
		)


static func _test_k1_painted_route_enemy_click_keeps_waypoints(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate k1_painted_click_waypoints: Shield Bash missing")
		return
	var route: Array[Vector2i] = PlanningChecklistHarness.K1_BASH_ROUTE
	_clear_drag_state(fix.input)
	TramplingAdvanceE2ETest._paint_drag_route(fix.input, fix.knight, route, BASH_APPROACH)
	PlanningChecklistHarness.hover(fix, ENEMY_POS)
	var preview_slots: Dictionary = _commit_slots_at(fix.input, 1, ENEMY_POS)
	if _slots_invalid(preview_slots):
		failures.append("PlanningQAGate k1_painted_click_waypoints: painted enemy hover slots invalid")
		return
	var preview_pre: TimelineAction = (preview_slots.get("pre", []) as Array).front() as TimelineAction
	if preview_pre == null or preview_pre.waypoints != PlanningChecklistHarness.K1_BASH_WAYPOINTS:
		failures.append(
			"PlanningQAGate k1_painted_click_waypoints: hover pre waypoints %s expected %s"
			% [str(preview_pre.waypoints if preview_pre != null else null), PlanningChecklistHarness.K1_BASH_WAYPOINTS],
		)
	if not PlanningChecklistHarness.commit_painted_click_on_cell(fix, route, ENEMY_POS):
		failures.append("PlanningQAGate k1_painted_click_waypoints: enemy click commit failed")
		return
	var committed_pre: TimelineAction = PlanningChecklistHarness.committed_pre_move(fix.director, 1)
	if committed_pre == null or committed_pre.waypoints != PlanningChecklistHarness.K1_BASH_WAYPOINTS:
		failures.append(
			"PlanningQAGate k1_painted_click_waypoints: committed pre waypoints %s expected %s"
			% [str(committed_pre.waypoints if committed_pre != null else null), PlanningChecklistHarness.K1_BASH_WAYPOINTS],
		)
	if _intent_slot_signature(preview_slots) != _intent_slot_signature_from_timeline(fix.director, 1):
		failures.append(
			"PlanningQAGate k1_painted_click_waypoints: committed timeline must match hover preview slots",
		)


static func _intent_slot_signature_from_timeline(director: CombatDirector, unit_id: int) -> String:
	var slots: Dictionary = {
		"pre": [],
		"action": [],
		"post": [],
	}
	for col: String in ["pre", "action", "post"]:
		var entries: Array = []
		match col:
			"pre":
				entries = director.plan_pre_move.entries
			"action":
				entries = director.plan_action.entries
			"post":
				entries = director.plan_post_move.entries
		for raw: Variant in entries:
			var action: TimelineAction = raw as TimelineAction
			if action != null and action.actor_id == unit_id:
				slots[col].append(action)
	return _intent_slot_signature(slots)


static func _sim_result_signature(result: SimResult) -> String:
	var unit_parts: PackedStringArray = PackedStringArray()
	if result != null and result.final_state != null:
		var ids: Array[int] = []
		for unit: UnitState in result.final_state.units:
			ids.append(unit.id)
		ids.sort()
		for unit_id: int in ids:
			var unit: UnitState = result.final_state.get_unit_by_id(unit_id)
			if unit == null:
				continue
			var ap_left: int = unit.ability.points_left if unit.ability != null else 0
			var mp_left: int = unit.movement.points_left if unit.movement != null else 0
			unit_parts.append(
				"%s@%d,%d:ap%s:mp%s"
				% [
					str(unit.id),
					unit.position.x,
					unit.position.y,
					str(ap_left),
					str(mp_left),
				]
			)
	var event_parts: PackedStringArray = PackedStringArray()
	if result != null:
		for event: SimEvent in result.events:
			event_parts.append(event.describe())
	return "units=%s||events=%s" % [
		";".join(unit_parts),
		";".join(event_parts),
	]


static func _test_drag_drop_commit_undo_clears_plan(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, Vector2i(-1, -1))
	_wire_click_drop_context(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	director.selected_ability_index = -1
	var dest := Vector2i(5, 5)
	input._begin_drag(fix.knight, Vector2.ZERO, true)
	var route: Array[Vector2i] = [KNIGHT_START, dest]
	input._drag_route = route.duplicate()
	input._drag_last_free = dest
	var params: Dictionary = input._commit_interaction_params(dest, -1)
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1, params.cell, params.waypoints, params.legal_move_tiles, params.preferred,
		int(params.get("face_dir", -1)),
	)
	if _slots_invalid(slots):
		failures.append("PlanningQAGate drag_drop_undo: painted drag commit slots invalid")
		return
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningQAGate drag_drop_undo: commit_from_slots failed")
		return
	input._end_drag_interaction(false, false)
	director.flush_plan_refresh_signals_if_pending()
	if input._drag_saved_preview != null:
		failures.append(
			"PlanningQAGate drag_drop_undo: successful drop must clear _drag_saved_preview",
		)
	if director.plan_pre_move.size() == 0:
		failures.append("PlanningQAGate drag_drop_undo: drag commit must write pre-move")
		return
	var move_action: TimelineAction = director.plan_pre_move.entries[0]
	if move_action.irreversible:
		failures.append("PlanningQAGate drag_drop_undo: basic drag walk must stay undoable")
		return
	if not director.unit_has_undoable_action(1):
		failures.append("PlanningQAGate drag_drop_undo: unit must be undoable after drag commit")
		return
	var before: int = director.plan_pre_move.size()
	director.rpc_remove_last_for_unit(1)
	director.flush_plan_refresh_signals_if_pending()
	if director.plan_pre_move.size() >= before:
		failures.append(
			"PlanningQAGate drag_drop_undo: undo must remove drag-committed pre-move",
		)
	if input._drag_saved_preview != null:
		failures.append(
			"PlanningQAGate drag_drop_undo: undo must not leave stale drag preview stash",
		)


static func _test_cursor_equals_slots_on_hover(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate cursor parity: Shield Bash missing")
		return
	var bash_slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	var bash_icon_slots: String = input._cursor_icon_from_commit_slots(bash_slots, fix.knight)
	var bash_icon_hover: String = input.compute_hover_action_icon(ENEMY_POS)
	if bash_icon_slots != bash_icon_hover:
		failures.append(
			"PlanningQAGate cursor parity: bash enemy hover icon %s != slots icon %s"
			% [bash_icon_hover, bash_icon_slots],
		)
	director.selected_ability_index = -1
	var walk_dest := Vector2i(5, 5)
	var walk_slots: Dictionary = _commit_slots_at(input, 1, walk_dest)
	if _slots_invalid(walk_slots):
		failures.append("PlanningQAGate cursor parity: adjacent walk hover must be valid")
		return
	var walk_icon_slots: String = input._cursor_icon_from_commit_slots(walk_slots, fix.knight)
	var walk_icon_hover: String = input.compute_hover_action_icon(walk_dest)
	if walk_icon_slots != walk_icon_hover:
		failures.append(
			"PlanningQAGate cursor parity: walk hover icon %s != slots icon %s"
			% [walk_icon_hover, walk_icon_slots],
		)


static func _test_bash_commit_sim_push(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate bash sim: Shield Bash missing")
		return
	var slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	if _slots_invalid(slots):
		failures.append("PlanningQAGate bash sim: enemy hover must be committable")
		return
	var preview_dict: Dictionary = _preview_dict_from_cell(input, 1, ENEMY_POS)
	var preview: CombatPlanningPreview = _preview_from_dict(director, preview_dict)
	var expected_push: Vector2i = _enemy_push_destination(preview, 2)
	if expected_push.x < -900000:
		failures.append("PlanningQAGate bash sim: preview must define push destination before commit")
		return
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningQAGate bash sim: commit_from_slots failed on hover slots")
		return
	director.flush_plan_refresh_signals_if_pending()
	var result: SimResult = _simulate_committed_plan(director)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	if enemy == null:
		failures.append("PlanningQAGate bash sim: enemy missing after simulate")
		return
	if enemy.position != expected_push:
		failures.append(
			"PlanningQAGate bash sim: enemy at %s expected push destination %s from preview"
			% [str(enemy.position), str(expected_push)],
		)


static func _test_hook_commit_sim_pull(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(Vector2i(1, 3), Vector2i(4, 3))
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate hook sim: Chain Hook missing")
		return
	director.selected_ability_index = hook_idx
	var start_enemy_x: int = fix.enemy.position.x
	var slots: Dictionary = _commit_slots_at(input, 1, fix.enemy.position)
	if _slots_invalid(slots):
		failures.append("PlanningQAGate hook sim: enemy hover must be committable")
		return
	var preview_dict: Dictionary = _preview_dict_from_cell(input, 1, fix.enemy.position)
	var preview: CombatPlanningPreview = _preview_from_dict(director, preview_dict)
	var expected_pos: Vector2i = fix.enemy.position
	if preview.preview_board != null:
		var pv_enemy: UnitState = preview.preview_board.get_unit_by_id(2)
		if pv_enemy != null:
			expected_pos = pv_enemy.position
	if expected_pos.x >= start_enemy_x:
		failures.append(
			"PlanningQAGate hook sim: preview must place enemy west of %d, got %s"
			% [start_enemy_x, str(expected_pos)],
		)
		return
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningQAGate hook sim: commit_from_slots failed")
		return
	director.flush_plan_refresh_signals_if_pending()
	var result: SimResult = _simulate_committed_plan(director)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	if enemy == null:
		failures.append("PlanningQAGate hook sim: enemy missing after simulate")
		return
	if enemy.position != expected_pos:
		failures.append(
			"PlanningQAGate hook sim: enemy at %s expected preview/sim position %s"
			% [str(enemy.position), str(expected_pos)],
		)


static func _test_invalid_slots_block_commit(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate invalid commit: Shield Bash missing")
		return
	var oob_slots: Dictionary = _commit_slots_at(input, 1, Vector2i(-1, 0))
	if not _slots_invalid(oob_slots):
		failures.append("PlanningQAGate invalid commit: OOB slots must be invalid")
		return
	var actions: Array[TimelineAction] = _actions_from_slots(oob_slots)
	if director.preview_commit_valid(1, actions) == "":
		failures.append("PlanningQAGate invalid commit: preview_commit_valid must reject OOB/empty plan")
	if director.commit_from_slots(1, oob_slots):
		failures.append("PlanningQAGate invalid commit: commit_from_slots must reject invalid OOB slots")


static func _test_full_slot_signature_on_commit(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate full signature: Shield Bash missing")
		return
	var slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	if _slots_invalid(slots):
		failures.append("PlanningQAGate full signature: bash enemy hover must be valid")
		return
	var pre_steps: Array = slots.get("pre", []) as Array
	var action_steps: Array = slots.get("action", []) as Array
	if pre_steps.is_empty() or action_steps.is_empty():
		failures.append("PlanningQAGate full signature: bash enemy hover must fill pre + action")
		return
	var slot_pre: TimelineAction = pre_steps[0] as TimelineAction
	var slot_action: TimelineAction = action_steps[0] as TimelineAction
	if slot_pre.move_timing != GameEnums.MoveTiming.PRE_ACTION:
		failures.append("PlanningQAGate full signature: pre-move must use PRE_ACTION timing")
	if slot_action.ability == null or slot_action.ability.id != SHIELD_BASH_ID:
		failures.append("PlanningQAGate full signature: action must be Shield Bash")
	if not (slots.get("post", []) as Array).is_empty():
		failures.append("PlanningQAGate full signature: bash approach must not use post column")
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningQAGate full signature: commit failed")
		return
	director.flush_plan_refresh_signals_if_pending()
	if director.plan_pre_move.entries.is_empty() or director.plan_action.entries.is_empty():
		failures.append("PlanningQAGate full signature: commit must write pre + action columns")
		return
	var committed_pre: TimelineAction = director.plan_pre_move.entries[0]
	var committed_action: TimelineAction = director.plan_action.entries[0]
	if committed_pre.target_coord != slot_pre.target_coord:
		failures.append("PlanningQAGate full signature: committed pre target mismatch")
	if committed_pre.waypoints != slot_pre.waypoints:
		failures.append(
			"PlanningQAGate full signature: committed pre waypoints %s != slots %s"
			% [str(committed_pre.waypoints), str(slot_pre.waypoints)],
		)
	if committed_action.target_unit_id != slot_action.target_unit_id:
		failures.append("PlanningQAGate full signature: committed action target mismatch")
	if committed_action.ability == null or committed_action.ability.id != SHIELD_BASH_ID:
		failures.append("PlanningQAGate full signature: committed action ability mismatch")


static func _test_ability_switch_clears_preview_cache(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	input._hover_preview_cache_key = "stale|1|ability|0"
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate cache clear: Shield Bash missing")
		return
	input._on_ability_selected(bash_idx)
	if input._hover_preview_cache_key != "":
		failures.append(
			"PlanningQAGate cache clear: ability select must invalidate hover preview cache",
		)


static func _test_ability_select_refreshes_enemy_hover_path(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate ability scroll hover: Shield Bash missing")
		return
	var other_idx: int = -1
	for i: int in range(fix.knight.active_abilities.size()):
		if i == bash_idx:
			continue
		var ability: AbilityData = fix.knight.active_abilities[i] as AbilityData
		if ability != null and not ability.is_universal_run():
			other_idx = i
			break
	if other_idx < 0:
		failures.append("PlanningQAGate ability scroll hover: no alternate ability for scroll test")
		return
	input.on_hover_moved(ENEMY_POS)
	director.selected_ability_index = other_idx
	input._on_ability_selected(other_idx)
	director.selected_ability_index = bash_idx
	input._on_ability_selected(bash_idx)
	if not input.is_live_preview_active():
		failures.append(
			"PlanningQAGate ability scroll hover: Shield Bash on enemy must activate live preview",
		)
		return
	var path: Array = input.preview_state.preview_paths.get(1, [])
	if path.size() < 2:
		failures.append(
			"PlanningQAGate ability scroll hover: expected approach path, got %s" % str(path),
		)


static func _test_trample_paint_commit_sim_chain(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate trample chain: Trampling Advance missing")
		return
	TramplingAdvanceE2ETest._arm_trample_awaiting(input, director, unit)
	var route: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	var expected: Array[Vector2i] = route.duplicate()
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, route, TramplingAdvanceE2ETest.END_CELL)
	input._sync_drag_route_stand()
	var live_path: Array = input.preview_state.preview_paths.get(1, [])
	if live_path != expected:
		failures.append(
			"PlanningQAGate trample chain: live preview %s != painted %s"
			% [str(live_path), str(expected)],
		)
	if TramplingAdvanceE2ETest._commit_drag_route(
		input, director, TramplingAdvanceE2ETest.END_CELL,
	).is_empty():
		failures.append("PlanningQAGate trample chain: commit failed")
		return
	var trample: TimelineAction = TramplingAdvanceE2ETest._committed_trample_action(director)
	if trample == null or trample.waypoints != TramplingAdvanceE2ETest.EAST_THEN_NORTH:
		failures.append("PlanningQAGate trample chain: committed waypoints must match paint")
		return
	var result: SimResult = _simulate_committed_plan(director)
	var visited: Array[Vector2i] = [TramplingAdvanceE2ETest.START_CELL]
	for event: SimEvent in result.events:
		if event.type != GameEnums.SimEventType.UNIT_MOVED:
			continue
		if int(event.data.get("actor", -1)) != 1:
			continue
		var path_v: Variant = event.data.get("path", [])
		if path_v is Array:
			for step: Variant in path_v:
				if step is Vector2i:
					visited.append(step)
	if visited != expected:
		failures.append(
			"PlanningQAGate trample chain: sim path %s != painted %s"
			% [str(visited), str(expected)],
		)


static func _test_bash_sim_determinism(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate sim determinism: Shield Bash missing")
		return
	var slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningQAGate sim determinism: bash commit failed")
		return
	director.flush_plan_refresh_signals_if_pending()
	var plan: Timeline = director.get_player_plan()
	var board_a: BoardState = director.base_board.clone()
	board_a.intents = []
	var board_b: BoardState = director.base_board.clone()
	board_b.intents = []
	var result_a: SimResult = Simulator.simulate(board_a, plan)
	var result_b: SimResult = Simulator.simulate(board_b, plan)
	var enemy_a: UnitState = result_a.final_state.get_unit_by_id(2)
	var enemy_b: UnitState = result_b.final_state.get_unit_by_id(2)
	if enemy_a == null or enemy_b == null:
		failures.append("PlanningQAGate sim determinism: enemy missing after simulate")
		return
	if enemy_a.position != enemy_b.position:
		failures.append(
			"PlanningQAGate sim determinism: repeat sim enemy positions differ %s vs %s"
			% [str(enemy_a.position), str(enemy_b.position)],
		)


static func _test_hover_order_invariant(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate hover order: Shield Bash missing")
		return
	var first_approach: Dictionary = _commit_slots_at(input, 1, BASH_APPROACH)
	var enemy_hover: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	var second_approach: Dictionary = _commit_slots_at(input, 1, BASH_APPROACH)
	if _slots_invalid(first_approach) or _slots_invalid(enemy_hover):
		failures.append("PlanningQAGate hover order: approach and enemy hovers must be valid")
		return
	if _intent_slot_signature(first_approach) != _intent_slot_signature(second_approach):
		failures.append(
			"PlanningQAGate hover order: approach hover unstable %s vs %s"
			% [_intent_slot_signature(first_approach), _intent_slot_signature(second_approach)],
		)
	if _pre_target(enemy_hover) != BASH_APPROACH:
		failures.append(
			"PlanningQAGate hover order: enemy hover pre-move must target canonical approach %s"
			% str(BASH_APPROACH),
		)


static func _test_drag_cleared_restores_canonical_bash_intent(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate drag cleared: Shield Bash missing")
		return
	var baseline: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	input._drag_unit_id = 1
	input._drag_route = [KNIGHT_START, Vector2i(5, 5)]
	input._drag_last_free = Vector2i(5, 5)
	input.dragging = true
	var polluted: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, input._drag_route, [], Vector2i(-999999, -999999),
	)
	input.dragging = false
	input._drag_route.clear()
	input._drag_unit_id = -1
	input._drag_last_free = Vector2i(-999999, -999999)
	var restored: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	if _slots_invalid(baseline) or _slots_invalid(restored):
		failures.append("PlanningQAGate drag cleared: bash enemy hover must stay valid")
		return
	if _intent_slot_signature(restored) != _intent_slot_signature(baseline):
		failures.append(
			"PlanningQAGate drag cleared: after drag cancel enemy intent must restore %s vs %s"
			% [_intent_slot_signature(baseline), _intent_slot_signature(restored)],
		)
	var polluted_pre: Array = polluted.get("pre", []) as Array
	if not polluted_pre.is_empty():
		var polluted_move: TimelineAction = polluted_pre[0] as TimelineAction
		if polluted_move != null and polluted_move.target_coord == Vector2i(5, 5):
			failures.append(
				"PlanningQAGate drag cleared: stale drag waypoint (5,5) must not persist on enemy hover",
			)


static func _test_approach_bash_slots_preview_keeps_push(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate approach bash push: Shield Bash missing")
		return
	var preview_dict: Dictionary = _preview_dict_from_cell(input, 1, ENEMY_POS)
	if bool(preview_dict.get("invalid", false)):
		failures.append("PlanningQAGate approach bash push: slots preview must be valid")
		return
	var preview: CombatPlanningPreview = _preview_from_dict(director, preview_dict)
	if _enemy_push_destination(preview, 2).x < -900000:
		failures.append(
			"PlanningQAGate approach bash push: slots→preview must keep push arrows after approach move",
		)


static func _test_timeline_ghost_clears_when_committed(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, Vector2i(-1, -1))
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	director.selected_ability_index = -1
	var dest := Vector2i(5, 5)
	var move: TimelineAction = TimelineAction.make_move(
		1, dest, -1, [], GameEnums.MoveTiming.PRE_ACTION,
	)
	input.preview_state.preview_board = director.board.clone()
	input._intent_snapshot_valid = true
	input._intent_snapshot_slots = {
		"pre": [move],
		"action": [],
		"post": [],
		"invalid": false,
	}
	var ghost_before: Dictionary = input.timeline_ghost_slots(1)
	if (ghost_before.get("pre", []) as Array).is_empty():
		failures.append("PlanningQAGate ghost: uncommitted hover intent must show ghost pre-move")
		return
	var ghost_move: TimelineAction = (ghost_before.get("pre", []) as Array)[0] as TimelineAction
	if ghost_move == null or ghost_move.target_coord != dest:
		failures.append("PlanningQAGate ghost: ghost pre-move must match hover intent target")
	director.plan_pre_move.entries.append(move)
	input._intent_snapshot_valid = true
	var ghost_after: Dictionary = input.timeline_ghost_slots(1)
	if not (ghost_after.get("pre", []) as Array).is_empty():
		failures.append(
			"PlanningQAGate ghost: ghost must clear when hover intent matches committed pre-move",
		)


static func _test_action_range_centered_on_live_stand(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate action_range_live_stand: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	input.on_hover_moved(ENEMY_POS)
	input._flush_hover_heavy_sync()
	if not input.is_live_preview_active():
		failures.append(
			"PlanningQAGate action_range_live_stand: enemy hover must activate live preview",
		)
		return
	if not input.action_range_visible_for_hover():
		failures.append(
			"PlanningQAGate action_range_live_stand: enemy hover must keep action-range visible at live stand",
		)
		return
	var live_board: BoardState = overlay.get_live_preview().preview_board
	if live_board == null:
		failures.append("PlanningQAGate action_range_live_stand: live preview board missing")
		return
	var live_knight: UnitState = live_board.get_unit_by_id(1)
	if live_knight == null:
		failures.append("PlanningQAGate action_range_live_stand: live knight missing on preview board")
		return
	if live_knight.position != BASH_APPROACH:
		failures.append(
			"PlanningQAGate action_range_live_stand: expected live stand %s got %s"
			% [BASH_APPROACH, live_knight.position],
		)
		return
	var ability: AbilityData = _knight_ability(SHIELD_BASH_ID)
	if ability == null:
		failures.append("PlanningQAGate action_range_live_stand: Shield Bash ability missing")
		return
	var expected: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, fix.knight, ability, live_knight.position,
	)
	for tile: Vector2i in expected:
		if not overlay.is_hover_action_range_tile(tile):
			failures.append(
				"PlanningQAGate action_range_live_stand: red tile %s missing (stand %s)"
				% [tile, live_knight.position],
			)


static func _find_run_hover_tile(board: BoardState, unit: UnitState) -> Vector2i:
	if board == null or unit == null:
		return Vector2i(-999999, -999999)
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			if coord == unit.position:
				continue
			if AbilitySystem.movement_requires_run(board, unit, coord, []):
				return coord
	return Vector2i(-999999, -999999)


static func _test_action_range_hides_when_auto_run_blocks_skill_ap(failures: Array[String]) -> void:
	const COMMITTED_RUN_DEST := Vector2i(3, 6)
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	director.auto_run = true
	fix.knight.ability.points_left = 1
	fix.knight.movement.points_left = 2
	var projected_knight: UnitState = director.projected_state.get_unit_by_id(1) if director.projected_state != null else null
	if projected_knight != null:
		projected_knight.ability.points_left = 1
		projected_knight.movement.points_left = 2
	var bowling_idx: int = _ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("PlanningQAGate action_range_auto_run_ap_gate: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	var run_tile: Vector2i = _find_run_hover_tile(fix.board, fix.knight)
	if run_tile.x <= -900000:
		failures.append("PlanningQAGate action_range_auto_run_ap_gate: no run-requiring hover tile found")
		return
	input.on_hover_moved(run_tile)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	if input.action_range_visible_for_hover():
		failures.append(
			"PlanningQAGate action_range_auto_run_ap_gate: action_range_visible_for_hover must be false after run hover %s"
			% run_tile,
		)
	if overlay.is_hover_action_range_tile(ENEMY_POS):
		failures.append(
			"PlanningQAGate action_range_auto_run_ap_gate: red tiles must hide when auto-run premove consumes skill AP (hover %s)"
			% run_tile,
		)
	var ability: AbilityData = _knight_ability(BOWLING_CHARGE_ID)
	if ability == null:
		failures.append("PlanningQAGate action_range_auto_run_ap_gate: Bowling Charge ability missing")
		return
	var expected: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, fix.knight, ability, fix.knight.position,
	)
	for tile: Vector2i in expected:
		if overlay.is_hover_action_range_tile(tile):
			failures.append(
				"PlanningQAGate action_range_auto_run_ap_gate: red tile %s must be hidden after run hover %s"
				% [tile, run_tile],
			)
			return


static func _test_auto_run_stays_on_when_swap_armed(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_swap_board(PlanningChecklistHarness.SWAP_ALLY_CELL)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	director.auto_run = true
	var k1_id: int = int(fix.k1_id)
	var swap_idx: int = PlanningChecklistHarness.select_ability_for_unit(
		fix, k1_id, PlanningChecklistHarness.KNIGHT_SWAP_ID
	)
	if swap_idx < 0:
		failures.append("PlanningQAGate auto_run_swap: Swap missing")
		return
	var actor: UnitState = director.projected_state.get_unit_by_id(k1_id)
	if actor == null:
		failures.append("PlanningQAGate auto_run_swap: knight missing on projected board")
		return
	if not AbilitySystem.can_afford_run(actor):
		failures.append("PlanningQAGate auto_run_swap: knight cannot afford Run")
		return
	if not input.auto_run_movement_active(actor):
		failures.append(
			"PlanningQAGate auto_run_swap: Auto Run must stay on for walk columns while Swap is armed"
		)


static func _test_action_range_hides_after_commit_run_icon(failures: Array[String]) -> void:
	ActionRangeRegressionTest.assert_hide_red_after_commit_run_icon_shield_bash(failures)


static func _test_action_range_shows_while_awaiting_trample(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate action_range_awaiting_trample: Trampling Advance missing")
		return
	if not TramplingAdvanceE2ETest._arm_trample_awaiting(input, director, unit):
		failures.append("PlanningQAGate action_range_awaiting_trample: arm awaiting failed")
		return
	input.on_hover_moved(TramplingAdvanceE2ETest.END_CELL)
	overlay._recompute_hover_ranges_from_inputs()
	if not input.action_range_visible_for_hover():
		failures.append(
			"PlanningQAGate action_range_awaiting_trample: awaiting trample must keep action-range visible",
		)
		return
	var trample: AbilityData = unit.active_abilities[fix.trample_idx]
	var origin: Vector2i = CombatPlanningPreview.planning_move_origin_cell(director, fix.board, unit.id)
	var expected: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, unit, trample, origin,
	)
	if expected.is_empty():
		failures.append("PlanningQAGate action_range_awaiting_trample: expected trample range tiles")
		return
	var found: bool = false
	for tile: Vector2i in expected:
		if overlay.is_hover_action_range_tile(tile):
			found = true
			break
	if not found:
		failures.append(
			"PlanningQAGate action_range_awaiting_trample: red tiles missing while awaiting (origin %s)"
			% origin,
		)


static func _test_action_range_shows_on_enemy_hover(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate action_range_enemy_hover: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	director.plan_pre_move.entries.append(
		TimelineAction.make_move(
			1, BASH_APPROACH, -1, [], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	input.on_hover_moved(ENEMY_POS)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	if not input.action_range_visible_for_hover():
		failures.append(
			"PlanningQAGate action_range_enemy_hover: enemy hover must keep action-range visible",
		)
		return
	var ability: AbilityData = _knight_ability(SHIELD_BASH_ID)
	if ability == null:
		failures.append("PlanningQAGate action_range_enemy_hover: Shield Bash ability missing")
		return
	var stand: Vector2i = BASH_APPROACH
	var expected: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, fix.knight, ability, stand,
	)
	var found: bool = false
	for tile: Vector2i in expected:
		if overlay.is_hover_action_range_tile(tile):
			found = true
			break
	if not found:
		failures.append(
			"PlanningQAGate action_range_enemy_hover: red tiles must show on enemy hover (stand %s)"
			% stand,
		)


static func _test_action_range_follows_cursor_on_move_hover(failures: Array[String]) -> void:
	const HOVER_DEST := Vector2i(3, 4)
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	director.auto_run = true
	fix.knight.ability.points_left = 1
	var projected_knight: UnitState = (
		director.projected_state.get_unit_by_id(1) if director.projected_state != null else null
	)
	if projected_knight != null:
		projected_knight.ability.points_left = 1
	director.plan_pre_move.entries.append(
		TimelineAction.make_move(
			1, HOVER_DEST, -1, [], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	var bowling_idx: int = _ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("PlanningQAGate action_range_move_hover_follows_cursor: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	input.on_hover_moved(HOVER_DEST)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	if not input.action_range_visible_for_hover():
		failures.append(
			"PlanningQAGate action_range_move_hover_follows_cursor: red tiles must show on move hover when skill stays affordable after premove (hover %s)"
			% HOVER_DEST,
		)
		return
	var stand: Vector2i = input.action_range_intent_stand_cell(1)
	if stand != HOVER_DEST:
		failures.append(
			"PlanningQAGate action_range_move_hover_follows_cursor: expected stand %s got %s"
			% [HOVER_DEST, stand],
		)
		return
	var ability: AbilityData = _knight_ability(BOWLING_CHARGE_ID)
	if ability == null:
		failures.append("PlanningQAGate action_range_move_hover_follows_cursor: Bowling Charge ability missing")
		return
	var expected: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, fix.knight, ability, stand,
	)
	var found: bool = false
	for tile: Vector2i in expected:
		if overlay.is_hover_action_range_tile(tile):
			found = true
			break
	if not found:
		failures.append(
			"PlanningQAGate action_range_move_hover_follows_cursor: red tiles must anchor on cursor stand %s"
			% stand,
		)


static func _test_enemy_skill_hover_not_movement_route(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate enemy_hover_not_move_route: Chain Hook missing")
		return
	director.selected_ability_index = hook_idx
	director.plan_pre_move.entries.append(
		TimelineAction.make_move(
			1, Vector2i(5, 4), -1, [], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	input.on_hover_moved(ENEMY_POS)
	if input.interaction_move_hover_active(1, ENEMY_POS):
		failures.append(
			"PlanningQAGate enemy_hover_not_move_route: enemy skill targeting must not use movement hover route",
		)
	if input.hover_attack_target_id() != fix.enemy.id:
		failures.append(
			"PlanningQAGate enemy_hover_not_move_route: enemy hover must resolve attack target id",
		)


static func _test_self_skill_move_hover_no_attack_target(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, Vector2i(-1, -1))
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var phalanx_idx: int = _ability_index(fix.knight, PHALANX_STANCE_ID)
	if phalanx_idx < 0:
		failures.append("PlanningQAGate self_skill_move_no_target_arrow: Phalanx Stance missing")
		return
	director.selected_ability_index = phalanx_idx
	var dest: Vector2i = Vector2i(5, 5)
	TramplingAdvanceE2ETest._paint_drag_route(fix.input, fix.knight, [KNIGHT_START, dest], dest)
	var intent := CombatIntentState.new()
	intent.bind(director)
	intent.set_hover_coord(dest)
	input._intent_state = intent
	input._update_hover_attack_preview()
	if input.hover_attack_target_id() >= 0:
		failures.append(
			"PlanningQAGate self_skill_move_no_target_arrow: move+self hover must not expose attack target id (got %d)"
			% input.hover_attack_target_id(),
		)


static func _test_enemy_bash_approach_move_leg(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate bash_enemy_approach_leg: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	input.on_hover_moved(ENEMY_POS)
	if not input.is_live_preview_active():
		failures.append(
			"PlanningQAGate bash_enemy_approach_leg: live preview required on enemy hover",
		)
		return
	if input.interaction_move_hover_active(1, ENEMY_POS):
		failures.append(
			"PlanningQAGate bash_enemy_approach_leg: enemy hover must not be move-tile hover",
		)
		return
	var leg: Array = CombatPlanningPreview.pending_move_route_leg(
		1, input.preview_state, director, fix.board,
	)
	if leg.size() < 2:
		failures.append(
			"PlanningQAGate bash_enemy_approach_leg: expected pre-move leg, got %s" % str(leg),
		)


static func _test_bash_targeting_uses_pre_push_enemy_cell(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate bash_target_pre_push_cell: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	input.on_hover_moved(ENEMY_POS)
	if not input.is_live_preview_active():
		failures.append(
			"PlanningQAGate bash_target_pre_push_cell: live preview required on enemy hover",
		)
		return
	var pushes: Array = input.preview_state.preview_pushes.get(fix.enemy.id, [])
	if pushes.is_empty():
		failures.append(
			"PlanningQAGate bash_target_pre_push_cell: Shield Bash must preview push displacement",
		)
		return
	var preview_enemy: UnitState = input.preview_state.preview_board.get_unit_by_id(fix.enemy.id)
	if preview_enemy == null:
		failures.append("PlanningQAGate bash_target_pre_push_cell: preview enemy missing")
		return
	if preview_enemy.position == fix.enemy.position:
		failures.append(
			"PlanningQAGate bash_target_pre_push_cell: preview enemy must move on push preview",
		)


static func _test_hook_pull_preview_keeps_attack_target(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate hook_pull_attack_target: Chain Hook missing")
		return
	director.selected_ability_index = hook_idx
	input.on_hover_moved(ENEMY_POS)
	if input.hover_attack_target_id() != fix.enemy.id:
		failures.append(
			"PlanningQAGate hook_pull_attack_target: enemy hover must resolve attack target",
		)
		return
	var pushes: Array = input.preview_state.preview_pushes.get(fix.enemy.id, [])
	if pushes.is_empty():
		failures.append(
			"PlanningQAGate hook_pull_attack_target: hook hover must preview pull displacement",
		)


static func _test_class_skill_execute_spends_ap(failures: Array[String]) -> void:
	const HOOK_KNIGHT := Vector2i(1, 3)
	const HOOK_ENEMY := Vector2i(4, 3)
	var fix: Dictionary = _planning_fixture(HOOK_KNIGHT, HOOK_ENEMY)
	var ability: AbilityData = _knight_ability(CHAIN_HOOK_ID)
	if ability == null:
		failures.append("PlanningQAGate class_skill_execute_ap: Chain Hook missing")
		return
	var action := TimelineAction.new()
	action.type = GameEnums.ActionType.ABILITY
	action.actor_id = 1
	action.target_unit_id = 2
	action.target_coord = HOOK_ENEMY
	action.ability = ability
	PlanningChecklistHarness.assert_execute_spends_ap(
		failures, "PlanningQAGate class_skill_execute_ap", fix.board, action, 0,
	)


static func _test_class_skill_player_turn_spends_ap(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningDragE2EHarness.wire_fixture(
		PlanningDragE2EHarness._planning_fixture(KNIGHT_START, ENEMY_POS),
	)
	fix.director.auto_run = true
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate class_skill_player_turn_ap: Shield Bash missing")
		return
	fix.director.selected_ability_index = bash_idx
	fix.input.on_hover_moved(ENEMY_POS)
	fix.input._flush_hover_heavy_sync()
	if not PlanningChecklistHarness.commit_paint_promote_only(fix, ENEMY_POS):
		failures.append("PlanningQAGate class_skill_player_turn_ap: bash commit failed")
		return
	PlanningChecklistHarness.assert_player_turn_ap_spent(
		failures, "PlanningQAGate class_skill_player_turn_ap", fix.director, 1, 0,
	)


static func _test_bash_promote_locks_committed_ghost(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningDragE2EHarness.wire_minimal_fixture(KNIGHT_START, ENEMY_POS)
	fix.director.auto_run = true
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate bash_promote_ghost: Shield Bash missing")
		return
	fix.director.selected_ability_index = bash_idx
	fix.input.on_hover_moved(ENEMY_POS)
	fix.input._flush_hover_heavy_sync()
	if not PlanningChecklistHarness.commit_paint_promote_only(fix, ENEMY_POS):
		failures.append("PlanningQAGate bash_promote_ghost: paint/commit failed")
		return
	PlanningChecklistHarness.assert_committed_ghost_pos(
		failures, "PlanningQAGate bash_promote_ghost", fix, 1, BASH_APPROACH,
	)


static func _test_hook_in_range_approach_tile_is_actor_position(failures: Array[String]) -> void:
	const HOOK_KNIGHT := Vector2i(1, 3)
	const HOOK_ENEMY := Vector2i(4, 3)
	var fix: Dictionary = _planning_fixture(HOOK_KNIGHT, HOOK_ENEMY)
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate hook_in_range_approach: Chain Hook missing")
		return
	PlanningChecklistHarness.assert_preview_approach_tile(
		failures, "PlanningQAGate hook_in_range_approach", fix, 2, hook_idx,
		HOOK_ENEMY, HOOK_KNIGHT,
	)


static func _test_hook_in_range_ignores_stale_drag_route(failures: Array[String]) -> void:
	const HOOK_KNIGHT := Vector2i(1, 3)
	const HOOK_ENEMY := Vector2i(4, 3)
	var fix: Dictionary = _planning_fixture(HOOK_KNIGHT, HOOK_ENEMY)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate hook_in_range_no_stale_drag: Chain Hook missing")
		return
	director.selected_ability_index = hook_idx
	TramplingAdvanceE2ETest._paint_drag_route(
		input, fix.knight, [HOOK_KNIGHT, Vector2i(2, 3)], Vector2i(2, 3),
	)
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1, HOOK_ENEMY, input._route_waypoints(), [], HOOK_ENEMY,
	)
	if _slots_invalid(slots):
		failures.append("PlanningQAGate hook_in_range_no_stale_drag: in-range hook hover must stay valid")
		return
	var pre: Array = slots.get("pre", []) as Array
	var action: Array = slots.get("action", []) as Array
	if not pre.is_empty():
		failures.append(
			"PlanningQAGate hook_in_range_no_stale_drag: in-range hook must not add pre-move for stale drag route",
		)
	if action.is_empty():
		failures.append(
			"PlanningQAGate hook_in_range_no_stale_drag: in-range hook must still build action slot",
		)


static func _test_hook_out_of_range_enemy_hover_invalid(failures: Array[String]) -> void:
	const HOOK_KNIGHT := Vector2i(1, 3)
	const HOOK_ENEMY := Vector2i(9, 3)
	var fix: Dictionary = _planning_fixture(HOOK_KNIGHT, HOOK_ENEMY)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate hook_out_of_range_null: Chain Hook missing")
		return
	director.selected_ability_index = hook_idx
	fix.knight.movement.points_left = 3
	var proj: UnitState = director.projected_state.get_unit_by_id(1)
	if proj != null:
		proj.movement.points_left = 3
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1, HOOK_ENEMY, [], [], HOOK_ENEMY,
	)
	if not _slots_invalid(slots):
		failures.append("PlanningQAGate hook_out_of_range_null: unreachable enemy hover must be invalid")
	var icon: String = input._cursor_icon_from_commit_slots(slots, fix.knight)
	if icon != PlanningIcons.GLYPH_NULL:
		failures.append(
			"PlanningQAGate hook_out_of_range_null: unreachable enemy hover must show null icon, got %s"
			% icon,
		)


static func _bind_bar_layer(overlay: TacticalPlanningOverlay, director: CombatDirector, board: BoardState) -> TacticalUnitLayer:
	var layer := TacticalUnitLayer.new()
	layer._director = director
	layer._board = board
	layer._phase = CombatDirector.Phase.PLANNING
	overlay.bind_unit_layer(layer)
	return layer


static func _test_volley_awaiting_hover_damage_and_targeting_arrow(failures: Array[String]) -> void:
	var archer_pos := Vector2i(4, 5)
	var enemy_pos := Vector2i(7, 5)
	var fix: Dictionary = _archer_volley_fixture(archer_pos, enemy_pos)
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	var layer: TacticalUnitLayer = _bind_bar_layer(overlay, fix.director, fix.board)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	director.set_awaiting_action(1, fix.volley)
	if director.has_method("flush_plan_refresh_signals_if_pending"):
		director.flush_plan_refresh_signals_if_pending()
	if not input.awaiting_targeting_active():
		failures.append("PlanningQAGate volley_hover_damage_arrow: Volley must be awaiting input")
		return
	if not input.is_skill_aim_hover_at(enemy_pos):
		failures.append("PlanningQAGate volley_hover_damage_arrow: enemy tile must count as live skill aim")
		return
	if input._should_restore_stand_hover_preview(enemy_pos):
		failures.append(
			"PlanningQAGate volley_hover_damage_arrow: TILE AOE hover must not restore committed preview",
		)
		return
	input.on_hover_moved(enemy_pos)
	var live: CombatPlanningPreview = overlay.get_live_preview()
	if live == null or live.preview_board == null:
		failures.append("PlanningQAGate volley_hover_damage_arrow: live preview board missing on Volley hover")
		return
	if live.forecast == null or live.forecast.damage_hp(fix.enemy.id) <= 0:
		failures.append(
			"PlanningQAGate volley_hover_damage_arrow: hover sim must forecast damage on the aimed enemy",
		)
		return
	var merged: CombatPlanningForecast = CombatPlanningForecast.merge_for_bar_display(
		null, live.forecast, fix.board, director.plan_revision,
	)
	if merged.damage_hp(fix.enemy.id) <= 0:
		failures.append(
			"PlanningQAGate volley_hover_damage_arrow: bar merge must show uncommitted Volley hover damage",
		)
	var bar: CombatPlanningForecast = layer._bar_display_forecast()
	if bar == null or bar.damage_hp(fix.enemy.id) <= 0:
		failures.append(
			"PlanningQAGate volley_hover_damage_arrow: HP bar display forecast must include hover damage",
		)
	if not overlay._should_draw_interaction_overlay():
		failures.append(
			"PlanningQAGate volley_hover_damage_arrow: targeting overlay must draw while aiming Volley",
		)
	var arrow: Array[Vector2i] = overlay.targeting_intent_arrow_cells()
	if arrow.size() < 2:
		failures.append("PlanningQAGate volley_hover_damage_arrow: targeting dash arrow missing on Volley hover")
	elif arrow[0] != archer_pos or arrow[1] != enemy_pos:
		failures.append(
			"PlanningQAGate volley_hover_damage_arrow: targeting arrow must be stand %s -> aim %s, got %s -> %s"
			% [str(archer_pos), str(enemy_pos), str(arrow[0]), str(arrow[1])],
		)


static func _test_volley_hover_damage_survives_board_changed(failures: Array[String]) -> void:
	var fix: Dictionary = _archer_volley_fixture(Vector2i(4, 5), Vector2i(7, 5))
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	var layer: TacticalUnitLayer = _bind_bar_layer(overlay, fix.director, fix.board)
	var input: CombatPlanningInput = fix.input
	fix.director.set_awaiting_action(1, fix.volley)
	if fix.director.has_method("flush_plan_refresh_signals_if_pending"):
		fix.director.flush_plan_refresh_signals_if_pending()
	input.on_hover_moved(Vector2i(7, 5))
	var before: CombatPlanningForecast = layer._bar_display_forecast()
	if before == null or before.damage_hp(fix.enemy.id) <= 0:
		failures.append(
			"PlanningQAGate volley_hover_board_changed: need hover damage before board_changed",
		)
		return
	layer._on_board_changed(fix.board)
	var after: CombatPlanningForecast = layer._bar_display_forecast()
	if after == null or after.damage_hp(fix.enemy.id) <= 0:
		failures.append(
			"PlanningQAGate volley_hover_board_changed: board_changed must not wipe live hover damage",
		)
	if overlay.targeting_intent_arrow_cells().size() < 2:
		failures.append(
			"PlanningQAGate volley_hover_board_changed: targeting arrow must survive board_changed",
		)


static func _test_undo_clears_stale_hover_damage_forecast(failures: Array[String]) -> void:
	var archer_pos := Vector2i(4, 5)
	var enemy_pos := Vector2i(7, 5)
	var fix: Dictionary = _archer_volley_fixture(archer_pos, enemy_pos)
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	var layer: TacticalUnitLayer = _bind_bar_layer(overlay, fix.director, fix.board)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	director.set_awaiting_action(1, fix.volley)
	if director.has_method("flush_plan_refresh_signals_if_pending"):
		director.flush_plan_refresh_signals_if_pending()
	input.on_hover_moved(enemy_pos)
	var before_undo: CombatPlanningForecast = layer._bar_display_forecast()
	if before_undo == null or before_undo.damage_hp(fix.enemy.id) <= 0:
		failures.append(
			"PlanningQAGate undo_clears_stale_damage: Volley hover must forecast damage before commit",
		)
		return
	var click_slots: Dictionary = _click_slots_at(input, 1, enemy_pos)
	if _slots_invalid(click_slots):
		failures.append(
			"PlanningQAGate undo_clears_stale_damage: Volley commit slots invalid at %s"
			% str(enemy_pos),
		)
		return
	if not director.commit_from_slots(1, click_slots):
		failures.append("PlanningQAGate undo_clears_stale_damage: Volley commit rejected")
		return
	input.call("_promote_intent_preview_after_commit")
	PlanningChecklistHarness.flush_planning(fix)
	if not director.unit_has_undoable_action(1):
		failures.append("PlanningQAGate undo_clears_stale_damage: committed Volley must be undoable")
		return
	director.rpc_remove_last_for_unit(1)
	if director.has_method("flush_plan_refresh_signals_if_pending"):
		director.flush_plan_refresh_signals_if_pending()
	var after_undo: CombatPlanningForecast = layer._bar_display_forecast()
	if after_undo != null and after_undo.damage_hp(fix.enemy.id) > 0:
		failures.append(
			"PlanningQAGate undo_clears_stale_damage: HP bar must not show pre-undo hover damage",
		)
	if not overlay._hit_markers.is_empty():
		failures.append(
			"PlanningQAGate undo_clears_stale_damage: damage hit markers must clear on undo refresh",
		)


static func _test_selecting_unit_keeps_movement_points(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bible_board()
	var k1_id: int = fix.k1_id as int
	var k2_id: int = fix.k2_id as int
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.KNIGHT_START)
	PlanningChecklistHarness.select_ability_for_unit(
		fix, k1_id, PlanningChecklistHarness.SHIELD_BASH_ID,
	)
	PlanningChecklistHarness.refresh_attack_hover(fix, PlanningChecklistHarness.E_BASH_CELL)
	var committed: Dictionary = PlanningChecklistHarness.commit_production(
		fix, PlanningChecklistHarness.E_BASH_CELL,
	)
	if PlanningChecklistHarness.slots_invalid(committed):
		failures.append("PlanningQAGate selection_is_mp_read_only: setup attack commit failed")
		return
	var before: UnitState = PlanningChecklistHarness.projected_unit(fix, k2_id)
	if before == null:
		failures.append("PlanningQAGate selection_is_mp_read_only: second Knight missing")
		return
	var expected_mp: int = before.movement.points_left
	PlanningChecklistHarness.select_unit(fix, k2_id, PlanningChecklistHarness.K2_CELL)
	if fix.input.is_live_preview_active():
		failures.append(
			"PlanningQAGate selection_is_mp_read_only: selecting a unit retained stale live preview",
		)
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, k2_id)
	if projected == null or projected.movement.points_left != expected_mp:
		failures.append(
			"PlanningQAGate selection_is_mp_read_only: selecting second Knight changed projected MP "
			+ "%d -> %d" % [expected_mp, projected.movement.points_left if projected != null else -1],
		)
	var displayed_mp: int = fix.input.planning_display_mp_left(k2_id)
	if displayed_mp != expected_mp:
		failures.append(
			"PlanningQAGate selection_is_mp_read_only: displayed MP changed %d -> %d"
			% [expected_mp, displayed_mp],
		)


static func _test_tile_targeting_forbids_premove(failures: Array[String]) -> void:
	## Once TARGET_PICK is armed, TILE aim must not paint, preview, or slot a walk.
	## Knight Bash/Hook/Trample fixtures never arm this phase, so they cannot catch it.
	## Selected-but-unarmed Volley premove is `_test_selected_tile_aoe_allows_premove`.
	var archer_pos := Vector2i(4, 5)
	var empty_step := Vector2i(5, 5)
	var empty_aim := Vector2i(6, 5)
	var enemy_pos := Vector2i(7, 5)
	var fix: Dictionary = _archer_volley_fixture(archer_pos, enemy_pos)
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	input._drag_unit_id = 1
	input._drag_route = [archer_pos, empty_step]
	director.set_awaiting_action(1, fix.volley)
	if director.has_method("flush_plan_refresh_signals_if_pending"):
		director.flush_plan_refresh_signals_if_pending()
	if not input.awaiting_targeting_active():
		failures.append("PlanningQAGate tile_aim_forbids_premove: Volley must be awaiting TARGET_PICK")
		return
	if not input._awaiting_target_pick_blocks_premove():
		failures.append(
			"PlanningQAGate tile_aim_forbids_premove: TARGET_PICK must block basic walk/premove",
		)
		return
	input.on_hover_moved(empty_step)
	input.on_hover_moved(empty_aim)
	if input._drag_route.size() >= 2:
		failures.append(
			"PlanningQAGate tile_aim_forbids_premove: TILE aim hover must not paint a walk corridor (route %s)"
			% str(input._drag_route),
		)
	if input.interaction_move_hover_active(1, empty_aim):
		failures.append(
			"PlanningQAGate tile_aim_forbids_premove: TILE aim hover must not use movement hover route",
		)
	if not overlay.get_hover_move_tiles().is_empty():
		failures.append(
			"PlanningQAGate tile_aim_forbids_premove: blue walk tiles must hide during TILE targeting",
		)
	var live: CombatPlanningPreview = overlay.get_live_preview()
	if live == null or live.preview_board == null:
		failures.append("PlanningQAGate tile_aim_forbids_premove: live TILE aim preview missing")
		return
	var live_archer: UnitState = live.preview_board.get_unit_by_id(1)
	if live_archer == null or live_archer.position != archer_pos:
		failures.append(
			"PlanningQAGate tile_aim_forbids_premove: TILE aim preview must not walk the caster (stand %s, got %s)"
			% [str(archer_pos), str(live_archer.position if live_archer != null else Vector2i(-1, -1))],
		)
	var walk_path: Array = live.preview_paths.get(1, [])
	if walk_path.size() >= 2:
		failures.append(
			"PlanningQAGate tile_aim_forbids_premove: TILE aim must not preview a walk path (got %s)"
			% str(walk_path),
		)
	var hover_slots: Dictionary = _commit_slots_at(input, 1, empty_aim)
	if _slots_have_move(hover_slots):
		failures.append(
			"PlanningQAGate tile_aim_forbids_premove: hover/commit slots must not include MOVE during TILE aim",
		)
	var click_slots: Dictionary = _click_slots_at(input, 1, empty_aim)
	if _slots_have_move(click_slots):
		failures.append(
			"PlanningQAGate tile_aim_forbids_premove: click slots must not include MOVE during TILE aim",
		)
	if director.plan_pre_move.size() > 0:
		failures.append(
			"PlanningQAGate tile_aim_forbids_premove: TILE aim hover must not commit a pre-move",
		)
	input.on_hover_moved(enemy_pos)
	live = overlay.get_live_preview()
	if live == null or live.forecast == null or live.forecast.damage_hp(fix.enemy.id) <= 0:
		failures.append(
			"PlanningQAGate tile_aim_forbids_premove: enemy TILE hover must still forecast skill damage",
		)
	var enemy_slots: Dictionary = _click_slots_at(input, 1, enemy_pos)
	if _slots_have_move(enemy_slots):
		failures.append(
			"PlanningQAGate tile_aim_forbids_premove: enemy TILE click must not slot a walk",
		)


static func _test_selected_tile_aoe_allows_premove(failures: Array[String]) -> void:
	## Regression: Volley selected (not awaiting) must still premove on empty walk tiles.
	## Live Archer QA missed this because it arms on self / walks with skill deselected first.
	## Prior gate `_test_tile_targeting_forbids_premove` only covered the armed TARGET_PICK state.
	var archer_pos := Vector2i(4, 5)
	var empty_step := Vector2i(5, 5)
	var enemy_pos := Vector2i(8, 5)
	var fix: Dictionary = _archer_volley_fixture(archer_pos, enemy_pos)
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var archer: UnitState = fix.archer
	if director.find_awaiting_action(1) != null:
		failures.append("PlanningQAGate selected_tile_aoe_allows_premove: Volley must start unarmed")
		return
	if input._awaiting_target_pick_blocks_premove():
		failures.append(
			"PlanningQAGate selected_tile_aoe_allows_premove: unarmed Volley must not block basic walk",
		)
		return
	input.on_hover_moved(empty_step)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	if overlay.get_hover_move_tiles().is_empty() or not overlay.is_hover_move_tile(empty_step):
		failures.append(
			"PlanningQAGate selected_tile_aoe_allows_premove: blue walk tiles must stay visible with Volley selected (tiles %s)"
			% str(overlay.get_hover_move_tiles()),
		)
	if not input._is_hover_move_cell(archer, empty_step):
		failures.append(
			"PlanningQAGate selected_tile_aoe_allows_premove: empty walk tile must count as a move hover",
		)
	if input._is_armed_tile_skill_aim_cell(archer, empty_step, fix.volley):
		failures.append(
			"PlanningQAGate selected_tile_aoe_allows_premove: unarmed in-range walk tile must not count as TILE aim",
		)
	var live: CombatPlanningPreview = overlay.get_live_preview()
	if live == null or live.preview_board == null:
		failures.append("PlanningQAGate selected_tile_aoe_allows_premove: live premove preview missing")
		return
	var live_archer: UnitState = live.preview_board.get_unit_by_id(1)
	if live_archer == null or live_archer.position != empty_step:
		failures.append(
			"PlanningQAGate selected_tile_aoe_allows_premove: hover preview must walk to %s, got %s"
			% [str(empty_step), str(live_archer.position if live_archer != null else Vector2i(-1, -1))],
		)
	var hover_slots: Dictionary = _commit_slots_at(input, 1, empty_step)
	if _slots_invalid(hover_slots) or not _slots_have_move(hover_slots):
		failures.append(
			"PlanningQAGate selected_tile_aoe_allows_premove: hover/commit slots must include MOVE, got %s"
			% str(hover_slots),
		)
	var click_slots: Dictionary = _click_slots_at(input, 1, empty_step)
	if _slots_invalid(click_slots) or not _slots_have_move(click_slots):
		failures.append(
			"PlanningQAGate selected_tile_aoe_allows_premove: click slots must include MOVE, got %s"
			% str(click_slots),
		)
	if not director.commit_from_slots(1, click_slots):
		failures.append("PlanningQAGate selected_tile_aoe_allows_premove: premove commit rejected")
		return
	if director.plan_pre_move.size() == 0:
		failures.append("PlanningQAGate selected_tile_aoe_allows_premove: click did not write a pre-move")
	var projected: UnitState = director.projected_state.get_unit_by_id(1) if director.projected_state != null else null
	if projected == null or projected.position != empty_step:
		failures.append(
			"PlanningQAGate selected_tile_aoe_allows_premove: projected stand must be %s after premove, got %s"
			% [str(empty_step), str(projected.position if projected != null else Vector2i(-1, -1))],
		)


static func _test_shaped_skill_red_range_yellow_blast(failures: Array[String]) -> void:
	## Red = AbilitySystem range from latest stand. Yellow = blast at aim hover only.
	var archer_pos := Vector2i(4, 5)
	var empty_step := Vector2i(5, 5)
	var enemy_pos := Vector2i(8, 5)
	var walk_fix: Dictionary = _archer_volley_fixture(archer_pos, enemy_pos)
	var walk_overlay: TacticalPlanningOverlay = _wire_overlay(walk_fix)
	var walk_input: CombatPlanningInput = walk_fix.input
	var walk_archer: UnitState = walk_fix.archer
	var walk_volley: AbilityData = walk_fix.volley
	walk_input.on_hover_moved(empty_step)
	walk_input._flush_hover_heavy_sync()
	walk_overlay._recompute_hover_ranges_from_inputs()
	if (
		walk_overlay.is_hover_blast_tile(empty_step)
		or not walk_overlay.get_hover_blast_tiles().is_empty()
	):
		failures.append(
			"PlanningQAGate shaped_red_yellow: unarmed walk hover must not paint yellow blast (got %s)"
			% str(walk_overlay.get_hover_blast_tiles()),
		)
	var walk_range: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		walk_fix.board, walk_archer, walk_volley, empty_step, [],
	)
	for tile: Vector2i in walk_range:
		if not walk_overlay.is_hover_action_range_tile(tile):
			failures.append(
				"PlanningQAGate shaped_red_yellow: red range from intended walk stand missing %s"
				% tile,
			)
			break
	var aim_fix: Dictionary = _archer_volley_fixture(archer_pos, enemy_pos)
	var overlay: TacticalPlanningOverlay = _wire_overlay(aim_fix)
	var input: CombatPlanningInput = aim_fix.input
	var director: CombatDirector = aim_fix.director
	var archer: UnitState = aim_fix.archer
	var volley: AbilityData = aim_fix.volley
	director.set_awaiting_action(1, volley)
	input.set_qa_pointer_grid_cell(enemy_pos)
	input.on_hover_moved(enemy_pos)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	var expected_red: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		aim_fix.board, archer, volley, archer_pos, [],
	)
	var awaiting: TimelineAction = director.find_awaiting_action(1)
	if awaiting != null and awaiting.awaiting_module_index >= 0:
		expected_red = AbilitySystem.planning_module_range_tiles(
			aim_fix.board, awaiting, awaiting.awaiting_module_index, archer_pos,
		)
	var expected_yellow: Array[Vector2i] = AbilitySystem.planning_blast_tiles_at_target(
		aim_fix.board, archer, volley, archer_pos, enemy_pos,
	)
	if expected_yellow.is_empty():
		failures.append("PlanningQAGate shaped_red_yellow: Volley blast at enemy must be non-empty")
		return
	for tile: Vector2i in expected_red:
		if not overlay.is_hover_action_range_tile(tile):
			failures.append(
				"PlanningQAGate shaped_red_yellow: armed aim must keep full red range (missing %s)"
				% tile,
			)
			break
	for tile: Vector2i in expected_yellow:
		if not overlay.is_hover_blast_tile(tile):
			failures.append(
				"PlanningQAGate shaped_red_yellow: yellow blast missing %s (got %s)"
				% [tile, overlay.get_hover_blast_tiles()],
			)
			break
	for tile: Vector2i in overlay.get_hover_blast_tiles():
		if not expected_yellow.has(tile):
			failures.append(
				"PlanningQAGate shaped_red_yellow: yellow extra tile %s outside blast %s"
				% [tile, expected_yellow],
			)
			break
	if overlay.get_hover_action_range_tiles().size() <= overlay.get_hover_blast_tiles().size():
		failures.append(
			"PlanningQAGate shaped_red_yellow: red must remain the range bubble, not collapse to yellow",
		)
	var live_range: int = AbilitySystem.active_range_tiles(archer, volley)
	var authored_range: int = 0
	if not volley.modules.is_empty() and volley.modules[0] is AbilityModule:
		authored_range = (volley.modules[0] as AbilityModule).max_range
	if live_range <= authored_range:
		failures.append(
			"PlanningQAGate shaped_red_yellow: armed Volley fixture must keep Steady Aim extra range (live %d module %d)"
			% [live_range, authored_range],
		)
	else:
		var extra_tile := Vector2i(archer_pos.x, archer_pos.y - live_range)
		if extra_tile.y < 0:
			extra_tile = Vector2i(archer_pos.x + live_range, archer_pos.y)
		if not overlay.is_hover_action_range_tile(extra_tile):
			failures.append(
				"PlanningQAGate shaped_red_yellow: armed Volley red must include Steady Aim tile %s (range %d vs module %d)"
				% [extra_tile, live_range, authored_range],
			)


static func _test_zero_range_self_aoe_red_yellow_contract(failures: Array[String]) -> void:
	## RANGE 0 shaped self-AOE (Crimson Whirlwind): red = no Manhattan bubble; yellow = stand footprint.
	const BruiserFixture := preload("res://tests/harness/bruiser_planning_checklist_harness.gd")
	const Checklist := preload("res://tests/harness/planning_checklist_harness.gd")
	var bruiser_pos := Vector2i(4, 5)
	var enemy_pos := Vector2i(6, 5)
	var fix: Dictionary = BruiserFixture.wire_board(
		bruiser_pos, enemy_pos, Vector2i(-1, -1), &"bruiser_crimson_whirlwind",
	)
	var idx: int = Checklist.select_ability(fix, &"bruiser_crimson_whirlwind")
	if idx < 0:
		failures.append("PlanningQAGate zero_range_self_aoe: Crimson Whirlwind missing on fixture")
		return
	var ability: AbilityData = fix.bruiser.active_abilities[idx]
	if AbilitySystem.active_range_tiles(fix.bruiser, ability) != 0:
		failures.append("PlanningQAGate zero_range_self_aoe: fixture must be authored RANGE 0")
		return
	var red: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, fix.bruiser, ability, bruiser_pos, [],
	)
	if not red.is_empty():
		failures.append(
			"PlanningQAGate zero_range_self_aoe: red must be empty for RANGE 0 AOE (got %s)"
			% str(red),
		)
	var yellow: Array[Vector2i] = AbilitySystem.planning_blast_tiles_at_target(
		fix.board, fix.bruiser, ability, bruiser_pos, bruiser_pos,
	)
	if yellow.is_empty():
		failures.append("PlanningQAGate zero_range_self_aoe: yellow blast at stand must be non-empty")
		return
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	input.on_hover_moved(bruiser_pos)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	if not overlay.get_hover_action_range_tiles().is_empty():
		failures.append(
			"PlanningQAGate zero_range_self_aoe: overlay red must be empty (got %s)"
			% str(overlay.get_hover_action_range_tiles()),
		)
	for tile: Vector2i in yellow:
		if not overlay.is_hover_blast_tile(tile):
			failures.append(
				"PlanningQAGate zero_range_self_aoe: overlay yellow missing %s (got %s)"
				% [tile, overlay.get_hover_blast_tiles()],
			)
			break


static func _test_single_target_yellow_impact_tile(failures: Array[String]) -> void:
	## Yellow is skill impact at aim, including SINGLE (the aimed tile).
	var archer_pos := Vector2i(4, 5)
	var enemy_pos := Vector2i(6, 5)
	var fix: Dictionary = _archer_snap_shot_fixture(archer_pos, enemy_pos)
	var overlay: TacticalPlanningOverlay = fix.overlay
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var archer: UnitState = fix.archer
	var snap: AbilityData = fix.basic
	director.select_unit(1)
	director.select_ability(0)
	input.set_qa_pointer_grid_cell(enemy_pos)
	input.on_hover_moved(enemy_pos)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	var stand: Vector2i = CombatPlanningPreview.planning_latest_stand_cell(
		director, fix.board, 1,
	)
	var expected_yellow: Array[Vector2i] = AbilitySystem.planning_blast_tiles_at_target(
		fix.board, archer, snap, stand, enemy_pos,
	)
	if expected_yellow.size() != 1 or expected_yellow[0] != enemy_pos:
		failures.append(
			"PlanningQAGate single_yellow: SINGLE impact must be the aimed tile %s, got %s"
			% [enemy_pos, expected_yellow],
		)
		return
	if not overlay.is_hover_blast_tile(enemy_pos):
		failures.append(
			"PlanningQAGate single_yellow: yellow must mark the aimed tile (got %s)"
			% str(overlay.get_hover_blast_tiles()),
		)
	if overlay.get_hover_blast_tiles().size() != 1:
		failures.append(
			"PlanningQAGate single_yellow: SINGLE yellow must be exactly one tile, got %s"
			% str(overlay.get_hover_blast_tiles()),
		)
	if not overlay.is_hover_action_range_tile(enemy_pos):
		failures.append("PlanningQAGate single_yellow: red range must still include the aimed tile")
	if overlay.get_hover_action_range_tiles().size() <= 1:
		failures.append(
			"PlanningQAGate single_yellow: red must remain the full range bubble, not collapse to yellow",
		)
	var empty_step := Vector2i(archer_pos.x, archer_pos.y + 1)
	input.set_qa_pointer_grid_cell(empty_step)
	input.on_hover_moved(empty_step)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	if overlay.is_hover_blast_tile(empty_step) or not overlay.get_hover_blast_tiles().is_empty():
		failures.append(
			"PlanningQAGate single_yellow: walk hover must not paint yellow (got %s)"
			% str(overlay.get_hover_blast_tiles()),
		)


static func _test_yellow_clears_after_skill_commit(failures: Array[String]) -> void:
	## Yellow is hover-only — must not persist after skill commit (frozen path may remain).
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate yellow_clears_after_commit: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	input.on_hover_moved(ENEMY_POS)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	if overlay.get_hover_blast_tiles().is_empty():
		failures.append(
			"PlanningQAGate yellow_clears_after_commit: enemy hover must paint yellow before commit",
		)
		return
	if not PlanningChecklistHarness.commit_paint_promote_only(fix, ENEMY_POS):
		failures.append("PlanningQAGate yellow_clears_after_commit: commit failed")
		return
	overlay._recompute_hover_ranges_from_inputs()
	if not overlay.get_hover_blast_tiles().is_empty():
		failures.append(
			"PlanningQAGate yellow_clears_after_commit: yellow must clear after commit (got %s)"
			% str(overlay.get_hover_blast_tiles()),
		)


static func _test_bash_hover_keeps_targeting_arrow(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate bash_hover_targeting_arrow: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	input.on_hover_moved(ENEMY_POS)
	var arrow: Array[Vector2i] = overlay.targeting_intent_arrow_cells()
	if arrow.size() < 2:
		failures.append("PlanningQAGate bash_hover_targeting_arrow: Shield Bash hover must draw targeting arrow")
	elif arrow[1] != ENEMY_POS:
		failures.append(
			"PlanningQAGate bash_hover_targeting_arrow: arrow must aim at enemy cell, got %s"
			% str(arrow[1]),
		)
	var live: CombatPlanningPreview = overlay.get_live_preview()
	if live == null or live.forecast == null or not live.forecast.has_stat_change():
		failures.append(
			"PlanningQAGate bash_hover_targeting_arrow: Shield Bash hover must forecast HP/armor change",
		)


static func _test_waypoint_premove_enemy_hover_full_truth(
	failures: Array[String],
) -> void:
	var cases: Array[Dictionary] = [
		{
			"start": Vector2i(2, 2),
			"route": [
				Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3),
				Vector2i(3, 4), Vector2i(4, 4),
			],
			"enemy": Vector2i(5, 4),
		},
		{
			"start": Vector2i(8, 8),
			"route": [
				Vector2i(8, 8), Vector2i(8, 7), Vector2i(7, 7),
				Vector2i(7, 6), Vector2i(6, 6),
			],
			"enemy": Vector2i(5, 6),
		},
		{
			"start": Vector2i(2, 8),
			"route": [
				Vector2i(2, 8), Vector2i(3, 8), Vector2i(3, 7),
				Vector2i(4, 7), Vector2i(4, 6),
			],
			"enemy": Vector2i(5, 6),
		},
	]
	for case_index: int in range(cases.size()):
		var spec: Dictionary = cases[case_index]
		var start: Vector2i = spec["start"]
		var route: Array[Vector2i] = []
		for raw_cell: Variant in spec["route"] as Array:
			route.append(raw_cell as Vector2i)
		var enemy_cell: Vector2i = spec["enemy"]
		var fix: Dictionary = _knight_shield_bash_fixture(start, enemy_cell)
		var input: CombatPlanningInput = fix.input
		var director: CombatDirector = fix.director
		var overlay: TacticalPlanningOverlay = fix.overlay
		var label: String = "PlanningQAGate waypoint_enemy_hover/%d" % (case_index + 1)
		var power_shot: AbilityData = fix.power_shot
		if power_shot == null:
			failures.append("%s: Power Shot missing" % label)
			continue
		if GridSystem.manhattan(start, enemy_cell) <= power_shot.range_tiles:
			failures.append("%s: enemy must begin out of Power Shot range" % label)
			continue
		if GridSystem.manhattan(route.back(), enemy_cell) > power_shot.range_tiles:
			failures.append("%s: final waypoint must enter Power Shot range" % label)
			continue
		if route.size() - 1 != input._move_budget(fix.archer):
			failures.append(
				"%s: route must exhaust all MP (%d steps, budget %d)"
				% [label, route.size() - 1, input._move_budget(fix.archer)],
			)
			continue

		PlanningChecklistHarness.hover(fix, start)
		var previous: Vector2i = start
		for waypoint: Vector2i in route.slice(1):
			PlanningChecklistHarness.sweep_to_cell(fix, waypoint, previous)
			previous = waypoint
		if input._drag_route != route:
			failures.append(
				"%s: mouse waypoint route %s != expected %s"
				% [label, str(input._drag_route), str(route)],
			)
			continue
		var blue_tiles: Array[Vector2i] = PlanningChecklistHarness.collect_blue_tiles(fix)
		if not blue_tiles.has(route[1]):
			failures.append("%s: blue movement tiles must include first premove waypoint" % label)

		## This is the real hover boundary: leave the final waypoint and move
		## the simulated mouse onto the enemy, where the preview must recompose
		## the exact move-plus-attack intent.
		PlanningChecklistHarness.sweep_to_cell(fix, enemy_cell, previous)
		var live: CombatPlanningPreview = overlay.get_live_preview()
		if live == null or live.preview_board == null:
			failures.append("%s: enemy hover live preview missing" % label)
			continue
		var live_archer: UnitState = live.preview_board.get_unit_by_id(1)
		if live_archer == null or live_archer.position != route.back():
			failures.append(
				"%s: hover preview stand %s != final waypoint %s"
				% [label, str(live_archer.position if live_archer != null else null), str(route.back())],
			)
		var live_path: Array = live.preview_paths.get(1, [])
		if live_path != route:
			failures.append(
				"%s: hover preview path %s != mouse route %s"
				% [label, str(live_path), str(route)],
			)
		if live.forecast == null or live.forecast.damage_hp(2) <= 0:
			failures.append("%s: enemy hover must forecast Power Shot damage" % label)

		var hover_slots: Dictionary = input._intent_snapshot_slots.duplicate(true)
		if not input._intent_snapshot_valid or _slots_invalid(hover_slots):
			failures.append("%s: valid enemy hover must retain finalized preview slots" % label)
			continue
		var hover_pre: Array = hover_slots.get("pre", []) as Array
		var hover_action: Array = hover_slots.get("action", []) as Array
		if hover_pre.is_empty() or hover_action.is_empty():
			failures.append(
				"%s: hover slots must contain both exhaustive pre-move and Power Shot action"
				% label,
			)
			continue
		var hover_move: TimelineAction = hover_pre[0] as TimelineAction
		var hover_skill: TimelineAction = hover_action[0] as TimelineAction
		if hover_move == null or hover_move.target_coord != route.back():
			failures.append("%s: hover pre-move target must be %s" % [label, str(route.back())])
		if hover_move != null and hover_move.waypoints != route.slice(1):
			failures.append(
				"%s: hover pre-move waypoints %s != mouse route %s"
				% [label, str(hover_move.waypoints), str(route.slice(1))],
			)
		if hover_skill == null or hover_skill.ability != power_shot or hover_skill.target_unit_id != 2:
			failures.append("%s: hover action must target enemy with Power Shot" % label)
		if hover_skill != null and live_archer != null:
			var expected_face: int = PhysicsSystem.facing_from_vector(enemy_cell - route.back())
			if live_archer.facing != expected_face:
				failures.append("%s: preview facing %d != target-facing %d" % [
					label, live_archer.facing, expected_face,
				])
			if hover_skill.face_dir != -1 and hover_skill.face_dir != expected_face:
				failures.append("%s: explicit slot facing %d != target-facing %d" % [
					label, hover_skill.face_dir, expected_face,
				])
		var hover_icon: String = input.compute_hover_action_icon(enemy_cell)
		var slot_icon: String = input._cursor_icon_from_commit_slots(hover_slots, fix.archer)
		if hover_icon != slot_icon or hover_icon.is_empty():
			failures.append("%s: hover cursor %s != finalized-slot cursor %s" % [
				label, hover_icon, slot_icon,
			])

		var ghost_slots: Dictionary = input.timeline_ghost_slots(1)
		if (ghost_slots.get("pre", []) as Array).is_empty() or (
			ghost_slots.get("action", []) as Array
		).is_empty():
			failures.append(
				"%s: planning slots must expose faded pending pre-move + action preview" % label,
			)
		var timeline_grid := TacticalTimelineGrid.new()
		timeline_grid.setup(director)
		timeline_grid.bind_planning_input(input)
		timeline_grid.set_board(fix.board)
		timeline_grid.set_display_board(fix.board)
		timeline_grid.set_phase(CombatDirector.Phase.PLANNING)
		timeline_grid.set_selected(1)
		timeline_grid.rebuild(director.get_player_plan(), PackedStringArray())
		if timeline_grid._pending_plan_labels.is_empty():
			failures.append("%s: timeline must render a pending hover preview label" % label)
		else:
			var pending_label: Label = timeline_grid._pending_plan_labels[0]
			var alpha_before: float = pending_label.modulate.a
			timeline_grid._process(0.25)
			var alpha_after: float = pending_label.modulate.a
			if is_equal_approx(alpha_before, alpha_after):
				failures.append("%s: pending timeline preview must pulse/fade" % label)
		timeline_grid.free()

		var click_slots: Dictionary = input._final_commit_slots_for_click_at_cell(
			1, enemy_cell, Vector2.ZERO,
		)
		if _intent_slot_signature(click_slots) != _intent_slot_signature(hover_slots):
			failures.append(
				"%s: click slots %s != hover slots %s"
				% [label, _intent_slot_signature(click_slots), _intent_slot_signature(hover_slots)],
			)
			continue
		input.set_qa_pointer_grid_cell(enemy_cell)
		input.on_left_press(fix.map_stub.grid_to_local(enemy_cell))
		if director.get_player_plan().entries.is_empty():
			failures.append("%s: actual enemy click failed" % label)
			continue
		director.flush_plan_refresh_signals_if_pending()
		var result: SimResult = _simulate_committed_plan(director)
		var final_archer: UnitState = result.final_state.get_unit_by_id(1)
		var final_enemy: UnitState = result.final_state.get_unit_by_id(2)
		if final_archer == null or final_archer.position != route.back():
			failures.append(
				"%s: committed simulator stand %s != hover stand %s"
				% [label, str(final_archer.position if final_archer != null else null), str(route.back())],
			)
		if final_enemy == null or final_enemy.health.current_hp >= fix.enemy.health.current_hp:
			failures.append("%s: committed Power Shot damage missing" % label)


static func _test_sidestep_enemy_click_ratifies_move_preview(
	failures: Array[String],
) -> void:
	var cases: Array[Dictionary] = [
		{
			"start": Vector2i(2, 2),
			"route": [
				Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3),
				Vector2i(3, 4), Vector2i(4, 4),
			],
			"enemy": Vector2i(5, 4),
			"target": Vector2i(4, 3),
		},
		{
			"start": Vector2i(8, 8),
			"route": [
				Vector2i(8, 8), Vector2i(8, 7), Vector2i(7, 7),
				Vector2i(7, 6), Vector2i(6, 6),
			],
			"enemy": Vector2i(5, 6),
			"target": Vector2i(6, 5),
		},
		{
			"start": Vector2i(2, 8),
			"route": [
				Vector2i(2, 8), Vector2i(3, 8), Vector2i(3, 7),
				Vector2i(4, 7), Vector2i(4, 6),
			],
			"enemy": Vector2i(5, 6),
			"target": Vector2i(4, 5),
		},
	]
	for case_index: int in range(cases.size()):
		var spec: Dictionary = cases[case_index]
		var start: Vector2i = spec["start"]
		var route: Array[Vector2i] = _vector2i_array(spec["route"] as Array)
		var enemy_cell: Vector2i = spec["enemy"]
		var destination: Vector2i = spec["target"]
		var label := "PlanningQAGate sidestep_waypoint_hover/%d" % (case_index + 1)
		var fix: Dictionary = _archer_skill_fixture(start, enemy_cell, ARCHER_SIDESTEP_ID)
		var input: CombatPlanningInput = fix.input
		var director: CombatDirector = fix.director
		if not _commit_archer_waypoint_premove(fix, route, label, failures):
			continue
		director.selected_ability_index = 0
		input._on_ability_selected(0)
		input.call("_run_ability_settled_refresh")
		var projected: UnitState = director.projected_state.get_unit_by_id(1)
		if projected == null or projected.movement.points_left <= 0:
			## Exhausted-MP cases must reject enemy hover without inventing an attack.
			input.set_qa_pointer_grid_cell(enemy_cell)
			input.on_hover_moved(enemy_cell)
			if input._intent_snapshot_valid or input.preview_state.preview_board != null:
				failures.append("%s: exhausted Sidestep enemy hover must be invalid" % label)
			input.on_left_press(fix.map_stub.grid_to_local(enemy_cell))
			if _first_plan_action_for_unit(director, 1, ARCHER_SIDESTEP_ID) != null:
				failures.append("%s: invalid enemy hover must not commit Sidestep" % label)
			continue
		PlanningChecklistHarness.sweep_to_cell(fix, destination, route.back())
		var live: CombatPlanningPreview = fix.overlay.get_live_preview()
		if live == null or live.preview_board == null:
			failures.append("%s: Sidestep hover preview board missing" % label)
			continue
		var live_archer: UnitState = live.preview_board.get_unit_by_id(1)
		if live_archer == null or live_archer.position != destination:
			failures.append("%s: preview stand %s != Sidestep target %s" % [
				label, str(live_archer.position if live_archer != null else null), str(destination),
			])
		var path: Array = live.preview_paths.get(1, [])
		if path.is_empty() or path.back() != destination:
			failures.append("%s: preview path must end at %s, got %s" % [
				label, str(destination), str(path),
			])
		var slots: Dictionary = input._intent_snapshot_slots.duplicate(true)
		if not input._intent_snapshot_valid or _slots_invalid(slots):
			failures.append("%s: valid Sidestep hover must retain slots" % label)
			continue
		var action_steps: Array = slots.get("action", []) as Array
		if action_steps.is_empty() or not action_steps[0] is TimelineAction:
			failures.append("%s: Sidestep hover must expose an action slot" % label)
			continue
		var sidestep: TimelineAction = action_steps[0] as TimelineAction
		if (
			sidestep.ability == null
			or sidestep.ability.id != ARCHER_SIDESTEP_ID
			or sidestep.target_coord != destination
		):
			failures.append("%s: finalized Sidestep slot does not match hover" % label)
		_assert_pending_hover_ghost(input, director, fix.board, 1, label, failures)
		input.set_qa_pointer_grid_cell(destination)
		input.on_left_press(fix.map_stub.grid_to_local(destination))
		var committed: TimelineAction = _first_plan_action_for_unit(
			director, 1, ARCHER_SIDESTEP_ID,
		)
		if committed == null or committed.target_coord != destination:
			failures.append("%s: click must commit the exact Sidestep hover" % label)
			continue
		var result: SimResult = _simulate_committed_plan(director)
		var final_archer: UnitState = result.final_state.get_unit_by_id(1)
		if final_archer == null or final_archer.position != destination:
			failures.append("%s: Simulator stand %s != Sidestep target %s" % [
				label, str(final_archer.position if final_archer != null else null), str(destination),
			])
		## Enemy hover after the valid tile intent must not reinterpret it as an attack.
		input.set_qa_pointer_grid_cell(enemy_cell)
		input.on_hover_moved(enemy_cell)
		if input._intent_snapshot_valid:
			failures.append("%s: enemy hover must not retain stale Sidestep tile intent" % label)


static func _test_sidestep_valid_tile_after_waypoint_premove(
	failures: Array[String],
) -> void:
	var cases: Array[Dictionary] = [
		{
			"start": Vector2i(2, 2),
			"route": [Vector2i(2, 2), Vector2i(2, 3)],
			"target": Vector2i(3, 3),
			"enemy": Vector2i(6, 3),
		},
		{
			"start": Vector2i(8, 8),
			"route": [
				Vector2i(8, 8), Vector2i(8, 7), Vector2i(7, 7),
			],
			"target": Vector2i(6, 7),
			"enemy": Vector2i(4, 7),
		},
	]
	for case_index: int in range(cases.size()):
		var spec: Dictionary = cases[case_index]
		var route: Array[Vector2i] = _vector2i_array(spec["route"] as Array)
		var target: Vector2i = spec["target"]
		var enemy_cell: Vector2i = spec["enemy"]
		var label := "PlanningQAGate sidestep_valid_waypoint/%d" % (case_index + 1)
		var fix: Dictionary = _archer_skill_fixture(spec["start"], enemy_cell, ARCHER_SIDESTEP_ID)
		var input: CombatPlanningInput = fix.input
		var director: CombatDirector = fix.director
		if not _commit_archer_waypoint_premove(fix, route, label, failures):
			continue
		director.selected_ability_index = 0
		input._on_ability_selected(0)
		input.call("_run_ability_settled_refresh")
		PlanningChecklistHarness.sweep_to_cell(fix, target, route.back())
		var live: CombatPlanningPreview = fix.overlay.get_live_preview()
		if live == null or live.preview_board == null:
			failures.append("%s: valid Sidestep preview missing" % label)
			continue
		var live_archer: UnitState = live.preview_board.get_unit_by_id(1)
		if live_archer == null or live_archer.position != target:
			failures.append("%s: preview stand must equal Sidestep target %s" % [
				label, str(target),
			])
		var preview_path: Array = live.preview_paths.get(1, [])
		if preview_path.is_empty() or preview_path.back() != target:
			failures.append("%s: preview path must end at Sidestep target" % label)
		var hover_slots: Dictionary = input._intent_snapshot_slots.duplicate(true)
		if not input._intent_snapshot_valid or _slots_invalid(hover_slots):
			failures.append("%s: valid Sidestep preview slots missing" % label)
			continue
		var sidestep: TimelineAction = _slot_action_with_ability(
			hover_slots, ARCHER_SIDESTEP_ID,
		)
		if sidestep == null:
			failures.append("%s: Sidestep action slot missing" % label)
			continue
		if (
			sidestep.ability == null
			or sidestep.ability.id != ARCHER_SIDESTEP_ID
			or sidestep.target_coord != target
		):
			failures.append("%s: Sidestep slot does not match preview target" % label)
		if live_archer != null:
			var expected_face: int = PhysicsSystem.facing_from_vector(
				route.back() - route[route.size() - 2],
			)
			if live_archer.facing != expected_face:
				failures.append("%s: Sidestep preview facing %d != final movement-facing %d (stand %s -> %s)" % [
					label, live_archer.facing, expected_face, str(route.back()), str(target),
				])
			if sidestep.face_dir != -1 and sidestep.face_dir != expected_face:
				failures.append("%s: Sidestep explicit slot facing does not match target" % label)
		var hover_icon: String = input.compute_hover_action_icon(target)
		var slot_icon: String = input._cursor_icon_from_commit_slots(hover_slots, fix.archer)
		if hover_icon != slot_icon or hover_icon.is_empty():
			failures.append("%s: Sidestep hover cursor does not match slots" % label)
		_assert_pending_hover_ghost(input, director, fix.board, 1, label, failures)
		input.set_qa_pointer_grid_cell(target)
		input.on_left_press(fix.map_stub.grid_to_local(target))
		var committed: TimelineAction = _first_plan_action_for_unit(
			director, 1, ARCHER_SIDESTEP_ID,
		)
		if committed == null or committed.target_coord != target:
			failures.append("%s: click must ratify Sidestep target" % label)
			continue
		var result: SimResult = _simulate_committed_plan(director)
		var final_archer: UnitState = result.final_state.get_unit_by_id(1)
		if final_archer == null or final_archer.position != target:
			failures.append("%s: Simulator must end at Sidestep target" % label)


static func _test_waypoint_premove_then_tile_aoe_enemy_hover(
	failures: Array[String],
) -> void:
	var cases: Array[Dictionary] = [
		{
			"start": Vector2i(2, 2),
			"route": [
				Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3),
				Vector2i(3, 4), Vector2i(4, 4),
			],
			"enemy": Vector2i(7, 4),
		},
		{
			"start": Vector2i(8, 8),
			"route": [
				Vector2i(8, 8), Vector2i(8, 7), Vector2i(7, 7),
				Vector2i(7, 6), Vector2i(6, 6),
			],
			"enemy": Vector2i(2, 6),
		},
		{
			"start": Vector2i(2, 8),
			"route": [
				Vector2i(2, 8), Vector2i(3, 8), Vector2i(3, 7),
				Vector2i(4, 7), Vector2i(4, 6),
			],
			"enemy": Vector2i(8, 6),
		},
	]
	for case_index: int in range(cases.size()):
		var spec: Dictionary = cases[case_index]
		var start: Vector2i = spec["start"]
		var route: Array[Vector2i] = _vector2i_array(spec["route"] as Array)
		var enemy_cell: Vector2i = spec["enemy"]
		var label := "PlanningQAGate tile_aoe_waypoint_hover/%d" % (case_index + 1)
		var fix: Dictionary = _archer_volley_fixture(start, enemy_cell)
		var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
		var input: CombatPlanningInput = fix.input
		var director: CombatDirector = fix.director
		var volley: AbilityData = fix.volley
		if not _commit_archer_waypoint_premove(fix, route, label, failures):
			continue
		director.set_awaiting_action(1, volley)
		input.set_qa_pointer_grid_cell(enemy_cell)
		input.on_hover_moved(enemy_cell)
		var live: CombatPlanningPreview = overlay.get_live_preview()
		if live == null or live.preview_board == null or live.forecast == null:
			failures.append("%s: Volley enemy hover preview missing" % label)
			continue
		var live_archer: UnitState = live.preview_board.get_unit_by_id(1)
		if live_archer == null or live_archer.position != route.back():
			failures.append("%s: AOE preview stand must remain latest premove stand" % label)
		if live.forecast.damage_hp(2) <= 0:
			failures.append("%s: Volley enemy hover must forecast damage" % label)
		if not overlay.is_hover_action_range_tile(enemy_cell):
			failures.append("%s: red action-range tiles must include hovered AOE tile" % label)
		if not overlay.is_hover_blast_tile(enemy_cell):
			failures.append("%s: yellow blast tiles must include hovered AOE tile" % label)
		var path: Array = live.preview_paths.get(1, [])
		if path.is_empty() or path.back() != route.back():
			failures.append("%s: AOE preview path must end at latest stand %s, got %s" % [
				label, str(route.back()), str(path),
			])
		var slots: Dictionary = input._intent_snapshot_slots.duplicate(true)
		if not input._intent_snapshot_valid or _slots_invalid(slots):
			failures.append("%s: valid Volley hover must retain slots" % label)
			continue
		var action_steps: Array = slots.get("action", []) as Array
		if action_steps.is_empty() or not action_steps[0] is TimelineAction:
			failures.append("%s: Volley hover must expose an action slot" % label)
			continue
		var volley_action: TimelineAction = action_steps[0] as TimelineAction
		if volley_action.target_coord != enemy_cell or volley_action.target_unit_id >= 0:
			failures.append("%s: tile AOE must preserve tile target semantics" % label)
		if live_archer != null:
			var expected_face: int = PhysicsSystem.facing_from_vector(enemy_cell - route.back())
			if live_archer.facing != expected_face:
				failures.append("%s: Volley preview facing does not face hovered tile" % label)
			if volley_action.face_dir != -1 and volley_action.face_dir != expected_face:
				failures.append("%s: Volley explicit slot facing does not match hovered tile" % label)
		var hover_icon: String = input.compute_hover_action_icon(enemy_cell)
		var slot_icon: String = input._cursor_icon_from_commit_slots(slots, fix.archer)
		if hover_icon != slot_icon or hover_icon.is_empty():
			failures.append("%s: Volley hover cursor does not match slots" % label)
		var volley_module: AbilityModule = volley.modules[0] as AbilityModule
		var affected_tiles: Array[Vector2i] = GridSystem.get_affected_tiles(
			fix.board,
			route.back(),
			enemy_cell,
			volley_module.target_shape,
			volley_module.target_shape_size,
		)
		if not affected_tiles.has(enemy_cell):
			failures.append("%s: canonical AOE footprint must include hovered enemy tile" % label)
		for tile: Vector2i in affected_tiles:
			if not overlay.is_hover_blast_tile(tile):
				failures.append("%s: yellow blast missing footprint tile %s" % [label, tile])
		for tile: Vector2i in overlay.get_hover_blast_tiles():
			if not affected_tiles.has(tile):
				failures.append("%s: yellow blast extra tile %s outside footprint %s" % [
					label, tile, affected_tiles,
				])
		var range_tiles: Array[Vector2i] = overlay.get_hover_action_range_tiles()
		if range_tiles.size() <= overlay.get_hover_blast_tiles().size():
			failures.append(
				"%s: red range must stay the full bubble (got %d), not collapse to yellow blast (%d)"
				% [label, range_tiles.size(), overlay.get_hover_blast_tiles().size()],
			)
		_assert_pending_hover_ghost(input, director, fix.board, 1, label, failures)
		var tile_px := float(TacticalConstants.TILE_PX)
		input.on_left_press(Vector2(enemy_cell) * tile_px + Vector2(tile_px, tile_px) * 0.5)
		var committed: TimelineAction = _first_plan_action_for_unit(
			director, 1, ARCHER_VOLLEY_ID,
		)
		if committed == null or committed.target_coord != enemy_cell or committed.target_unit_id >= 0:
			failures.append("%s: enemy click must commit the exact tile AOE hover" % label)
			continue
		var result: SimResult = _simulate_committed_plan(director)
		var final_archer: UnitState = result.final_state.get_unit_by_id(1)
		var final_enemy: UnitState = result.final_state.get_unit_by_id(2)
		if final_archer == null or final_archer.position != route.back():
			failures.append("%s: Simulator stand must remain latest premove stand" % label)
		if final_enemy == null or final_enemy.health.current_hp >= fix.enemy.health.current_hp:
			failures.append("%s: Simulator must apply tile AOE damage to hovered enemy" % label)


static func _assert_pending_hover_ghost(
	input: CombatPlanningInput,
	director: CombatDirector,
	board: BoardState,
	unit_id: int,
	label: String,
	failures: Array[String],
) -> void:
	var ghost_slots: Dictionary = input.timeline_ghost_slots(unit_id)
	if (ghost_slots.get("pre", []) as Array).is_empty() and (
		ghost_slots.get("action", []) as Array
	).is_empty():
		failures.append("%s: valid hover must expose pending timeline ghost slots" % label)
		return
	var timeline_grid := TacticalTimelineGrid.new()
	timeline_grid.setup(director)
	timeline_grid.bind_planning_input(input)
	timeline_grid.set_board(board)
	timeline_grid.set_display_board(board)
	timeline_grid.set_phase(CombatDirector.Phase.PLANNING)
	timeline_grid.set_selected(unit_id)
	timeline_grid.rebuild(director.get_player_plan(), PackedStringArray())
	if timeline_grid._pending_plan_labels.is_empty():
		failures.append("%s: timeline must render a pending hover preview label" % label)
	else:
		var pending_label: Label = timeline_grid._pending_plan_labels[0]
		var alpha_before: float = pending_label.modulate.a
		timeline_grid._process(0.25)
		if is_equal_approx(alpha_before, pending_label.modulate.a):
			failures.append("%s: pending timeline preview must pulse/fade" % label)
	timeline_grid.free()


static func _vector2i_array(raw_cells: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for raw_cell: Variant in raw_cells:
		cells.append(raw_cell as Vector2i)
	return cells


static func _commit_archer_waypoint_premove(
	fix: Dictionary,
	route: Array[Vector2i],
	label: String,
	failures: Array[String],
) -> bool:
	if route.size() < 2:
		failures.append("%s: premove route must contain a waypoint" % label)
		return false
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var map_stub: QaPlanningMapStub = fix.get("map_stub", null) as QaPlanningMapStub
	if map_stub == null:
		map_stub = QaPlanningMapStub.new()
		fix["map_stub"] = map_stub
		input._map_view = map_stub
	director.selected_ability_index = -1
	input._on_ability_selected(-1)
	PlanningChecklistHarness.hover(fix, route[0])
	var previous: Vector2i = route[0]
	for waypoint: Vector2i in route.slice(1):
		PlanningChecklistHarness.sweep_to_cell(fix, waypoint, previous)
		previous = waypoint
	if input._drag_route != route:
		failures.append("%s: painted premove route %s != %s" % [
			label, str(input._drag_route), str(route),
		])
		return false
	input.set_qa_pointer_grid_cell(route.back())
	input.on_left_press(map_stub.grid_to_local(route.back()))
	director.flush_plan_refresh_signals_if_pending()
	var committed_move: TimelineAction = null
	for action: TimelineAction in director.get_player_plan().entries:
		if (
			action != null
			and action.actor_id == 1
			and action.type == GameEnums.ActionType.MOVE
			and action.target_coord == route.back()
			and action.waypoints == route.slice(1)
		):
			committed_move = action
			break
	if committed_move == null:
		failures.append("%s: actual click did not commit the complete premove route" % label)
		return false
	var projected: UnitState = director.projected_state.get_unit_by_id(1)
	if projected == null or projected.position != route.back():
		failures.append("%s: committed premove stand is not %s" % [label, str(route.back())])
		return false
	return true


static func _slot_action_with_ability(
	slots: Dictionary,
	ability_id: StringName,
) -> TimelineAction:
	for bucket_name: String in ["pre", "action", "post"]:
		for raw_action: Variant in slots.get(bucket_name, []) as Array:
			var action: TimelineAction = raw_action as TimelineAction
			if (
				action != null
				and action.ability != null
				and action.ability.id == ability_id
			):
				return action
	return null


static func _first_plan_action_for_unit(
	director: CombatDirector,
	unit_id: int,
	ability_id: StringName,
) -> TimelineAction:
	if director == null:
		return null
	for action: TimelineAction in director.get_player_plan().entries:
		if (
			action != null
			and action.actor_id == unit_id
			and action.ability != null
			and action.ability.id == ability_id
		):
			return action
	return null


static func _archer_fixture(
	archer_pos: Vector2i,
	enemy_pos: Vector2i,
) -> Dictionary:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var sidestep: AbilityData = ArcherQaHarness.factory_ability(&"archer_sidestep")
	var power_shot: AbilityData = ArcherQaHarness.factory_ability(&"archer_power_shot")
	var volley: AbilityData = ArcherQaHarness.factory_ability(&"archer_volley")
	var archer_def: UnitData = ArcherQaHarness.archer_unit_data()
	var archer: UnitState = UnitState.create(1, archer_def, GameEnums.Team.PLAYER, archer_pos)
	archer.active_abilities = [sidestep, power_shot, volley]
	archer.movement.points_left = archer.movement.max_points
	archer.ability.points_left = maxi(1, archer.ability.max_points)
	archer.ability.max_points = maxi(1, archer.ability.max_points)
	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	var enemy: UnitState = UnitState.create(2, dummy_def, GameEnums.Team.ENEMY, enemy_pos)
	var units: Array[UnitState] = [archer, enemy]
	var board := _plain_board(Vector2i(12, 12), units)
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	director.selected_ability_index = 1
	input._director = director
	input.auto_use_skill_after_move = true
	var fix: Dictionary = {
		"input": input,
		"director": director,
		"board": board,
		"archer": archer,
		"knight": archer,
		"enemy": enemy,
	}
	return PlanningDragE2EHarness.wire_fixture(fix)


static func _test_committed_premove_then_enemy_hover_click_preserves_intent(failures: Array[String]) -> void:
	var fix: Dictionary = _archer_fixture(Vector2i(4, 5), Vector2i(7, 7))
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var overlay: TacticalPlanningOverlay = fix.overlay
	
	# Step 1: Commit curved 4-step walk to (7, 4)
	var route: Array[Vector2i] = [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)]
	var move_action: TimelineAction = director.make_planning_move_action(
		1, Vector2i(7, 4), director.board, fix.archer, route, GameEnums.MoveTiming.PRE_ACTION,
	)
	var commit_ok: bool = director.commit_from_slots(1, {"pre": [move_action], "action": [], "post": []})
	if not commit_ok or director.plan_pre_move.entries.size() != 1:
		failures.append("PlanningQAGate premove_enemy_hover: failed to commit initial pre-move")
		return
	
	# Verify projected stand is (7, 4)
	var proj_archer: UnitState = director.projected_state.get_unit_by_id(1)
	if proj_archer == null or proj_archer.position != Vector2i(7, 4):
		failures.append("PlanningQAGate premove_enemy_hover: projected stand not at (7, 4)")
		return
	
	# Step 2: Hover enemy at (7, 7) with Power Shot selected
	director.select_ability(1)
	input.on_hover_moved(Vector2i(7, 7))
	input._flush_hover_heavy_sync()
	
	# Assert overlay intent stand origin is at (7, 4) NOT (4, 5)
	var stand_origin: Vector2i = overlay._intent_stand_origin(fix.archer)
	if stand_origin != Vector2i(7, 4):
		failures.append("PlanningQAGate premove_enemy_hover: overlay intent stand origin %s expected (7, 4)" % str(stand_origin))
		return
	
	# Assert timeline ghost has action
	var ghost_slots: Dictionary = input.timeline_ghost_slots(1)
	var ghost_actions: Array = ghost_slots.get("action", [])
	if ghost_actions.is_empty():
		failures.append("PlanningQAGate premove_enemy_hover: timeline ghost must display pending action on enemy hover")
		return
	
	# Step 3: Click enemy at (7, 7) to commit
	input.set_qa_pointer_grid_cell(Vector2i(7, 7))
	input.on_left_press(fix.map_stub.grid_to_local(Vector2i(7, 7)))
	
	# Assert pre-move is STILL IN PLAN
	if director.plan_pre_move.entries.size() != 1:
		failures.append("PlanningQAGate premove_enemy_hover: pre-move was wiped out on enemy click! Expected 1, got %d" % director.plan_pre_move.entries.size())
		return
	if director.plan_pre_move.entries[0].target_coord != Vector2i(7, 4):
		failures.append("PlanningQAGate premove_enemy_hover: pre-move destination changed! Expected (7, 4), got %s" % str(director.plan_pre_move.entries[0].target_coord))
		return
	if director.plan_action.entries.size() != 1:
		failures.append("PlanningQAGate premove_enemy_hover: action was not committed! Expected 1, got %d" % director.plan_action.entries.size())
		return
	
	# Step 4: Verify Simulator execution
	var trial: BoardState = director.base_board.clone()
	var evs: Array[SimEvent] = []
	Simulator.simulate_player_turn(trial, director.get_player_plan(), evs)
	var moved: bool = false
	var shot: bool = false
	for e: SimEvent in evs:
		if e.type == GameEnums.SimEventType.UNIT_MOVED and e.data.get("actor", -1) == 1 and e.data.get("to") == Vector2i(7, 4):
			moved = true
		if e.type == GameEnums.SimEventType.ABILITY_USED and e.data.get("actor", -1) == 1:
			shot = true
	if not moved:
		failures.append("PlanningQAGate premove_enemy_hover: simulator did not execute movement to (7, 4)")
		return
	if not shot:
		failures.append("PlanningQAGate premove_enemy_hover: simulator did not execute ability from (7, 4)")
		return


static func _test_painted_route_then_enemy_hover_click_preserves_intent(failures: Array[String]) -> void:
	var fix: Dictionary = _archer_fixture(Vector2i(4, 5), Vector2i(7, 5))
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var overlay: TacticalPlanningOverlay = fix.overlay
	
	# Select Archer and Power Shot (skill index 1, range 3-5 / 1-5)
	director.select_unit(1)
	director.select_ability(1)
	
	# Step 1: Cursor moved/painted corridor toward enemy
	input._drag_unit_id = 1
	input._drag_route = [Vector2i(4, 5), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)]
	input._drag_last_free = Vector2i(7, 4)
	input._sync_drag_route_stand()
	overlay.set_drag_route(input._drag_route)
	
	# Step 2: Hover the enemy at (7, 5)
	input.on_hover_moved(Vector2i(7, 5))
	input._flush_hover_heavy_sync()
	
	# For Range 2+ (Power Shot), direct enemy hover attacks from current stand (4, 5) with 0 movement
	var stand_origin: Vector2i = overlay._intent_stand_origin(fix.archer)
	if stand_origin != Vector2i(4, 5):
		failures.append("PlanningQAGate range2_enemy_hover: overlay intent stand origin %s expected (4, 5)" % str(stand_origin))
		return
	
	# Targeting arrow originates directly from (4, 5) to (7, 5)
	var arrow: Array[Vector2i] = overlay.targeting_intent_arrow_cells()
	if arrow.size() != 2 or arrow[0] != Vector2i(4, 5) or arrow[1] != Vector2i(7, 5):
		failures.append("PlanningQAGate range2_enemy_hover: targeting arrow %s expected [(4, 5), (7, 5)]" % str(arrow))
		return
	
	# Drag route in CombatPlanningInput must be immediately cleared when hovering Range 2+ enemy
	if not input.get_drag_route().is_empty():
		failures.append("PlanningQAGate range2_enemy_hover: input.get_drag_route() %s must be EMPTY on Range 2+ enemy hover" % str(input.get_drag_route()))
		return
	
	# Move preview arrow must NOT be drawn on screen when hovering an enemy in range with Range 2+
	var live: CombatPlanningPreview = overlay.get_live_preview()
	var hover_move_arrow: Array = overlay._interaction_move_route(fix.archer.id, live, live.preview_paths.get(fix.archer.id, []) if live != null else [])
	if not hover_move_arrow.is_empty():
		failures.append("PlanningQAGate range2_enemy_hover: hover move preview arrow %s must NOT be drawn for Range 2+ stationary shot" % str(hover_move_arrow))
		return
	
	# Timeline ghost has action from (4, 5) and NO pre-move
	var ghost_slots: Dictionary = input.timeline_ghost_slots(1)
	var ghost_pre: Array = ghost_slots.get("pre", [])
	var ghost_act: Array = ghost_slots.get("action", [])
	if not ghost_pre.is_empty():
		failures.append("PlanningQAGate range2_enemy_hover: timeline ghost must NOT have pre-move for Range 2+ in-range hover")
		return
	if ghost_act.is_empty():
		failures.append("PlanningQAGate range2_enemy_hover: timeline ghost missing action on enemy")
		return
	
	# Step 3: Click enemy at (7, 5) to commit
	input.set_qa_pointer_grid_cell(Vector2i(7, 5))
	input.on_left_press(fix.map_stub.grid_to_local(Vector2i(7, 5)))
	
	# Assert action committed from (4, 5) and NO pre-move
	if director.plan_pre_move.entries.size() != 0:
		failures.append("PlanningQAGate range2_enemy_hover: pre-move must NOT be committed for Range 2+ in-range hover! Got %d" % director.plan_pre_move.entries.size())
		return
	if director.plan_action.entries.size() != 1:
		failures.append("PlanningQAGate range2_enemy_hover: action was not committed! Expected 1, got %d" % director.plan_action.entries.size())
		return
	
	# Drag route must remain clean after commit
	if not input.get_drag_route().is_empty():
		failures.append("PlanningQAGate range2_enemy_hover: input.get_drag_route() %s must be EMPTY immediately after commit" % str(input.get_drag_route()))
		return
	
	# Assert 100% parity between hover movepreview and committed movepreview
	var committed: CombatPlanningPreview = overlay.get_committed_preview()
	var commit_move_arrow: Array = CombatPlanningPreview.committed_move_route_leg(fix.archer.id, committed, director, director.base_board, GameEnums.MoveTiming.PRE_ACTION)
	if not commit_move_arrow.is_empty():
		failures.append("PlanningQAGate range2_enemy_hover: committed move preview arrow %s must NOT be present for Range 2+ stationary shot" % str(commit_move_arrow))
		return
	if hover_move_arrow != commit_move_arrow:
		failures.append("PlanningQAGate range2_enemy_hover: hover movepreview (%s) != commit movepreview (%s)" % [str(hover_move_arrow), str(commit_move_arrow)])
		return
	
	# Step 4: Moving mouse to another tile after commit must not flicker or spawn movepreview
	input.on_hover_moved(Vector2i(4, 4))
	input._flush_hover_heavy_sync()
	var post_move_mouse_arrow: Array = CombatPlanningPreview.committed_move_route_leg(fix.archer.id, overlay.get_committed_preview(), director, director.base_board, GameEnums.MoveTiming.PRE_ACTION)
	if not post_move_mouse_arrow.is_empty():
		failures.append("PlanningQAGate range2_enemy_hover: moving mouse after commit spawned move preview arrow %s" % str(post_move_mouse_arrow))
		return
	
	# Step 5: Verify Simulator execution parity (direct shot from (4, 5), 0 movement)
	var trial: BoardState = director.base_board.clone()
	var evs: Array[SimEvent] = []
	Simulator.simulate_player_turn(trial, director.get_player_plan(), evs)
	var moved: bool = false
	var shot: bool = false
	for e: SimEvent in evs:
		if e.type == GameEnums.SimEventType.UNIT_MOVED and e.data.get("actor", -1) == 1:
			moved = true
		if e.type == GameEnums.SimEventType.ABILITY_USED and e.data.get("actor", -1) == 1:
			shot = true
	if moved:
		failures.append("PlanningQAGate range2_enemy_hover: simulator must NOT execute movement for Range 2+ in-range attack")
		return
	if not shot:
		failures.append("PlanningQAGate range2_enemy_hover: simulator did not execute ability from (4, 5)")
		return


static func _test_range1_painted_route_enemy_hover_respects_waypoints(failures: Array[String]) -> void:
	var fix: Dictionary = _knight_shield_bash_fixture(Vector2i(4, 5), Vector2i(7, 5))
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var overlay: TacticalPlanningOverlay = fix.overlay
	
	# Knight at (4, 5), Enemy at (7, 5). Shield Bash (Range 1). 4 MP for 4-step corridor.
	director.select_unit(1)
	director.select_ability(0)
	
	# Step 1: Paint corridor to adjacent tile (7, 4)
	input._drag_unit_id = 1
	input._drag_route = [Vector2i(4, 5), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)]
	input._drag_last_free = Vector2i(7, 4)
	input._sync_drag_route_stand()
	overlay.set_drag_route(input._drag_route)
	
	# Step 2: Hover enemy at (7, 5)
	input.on_hover_moved(Vector2i(7, 5))
	input._flush_hover_heavy_sync()
	
	# For Range 1, painted waypoints ARE respected to chosen adjacent stand (7, 4)
	var stand_origin: Vector2i = overlay._intent_stand_origin(fix.knight)
	if stand_origin != Vector2i(7, 4):
		failures.append("PlanningQAGate range1_enemy_hover: overlay intent stand origin %s expected (7, 4)" % str(stand_origin))
		return
	
	# Targeting arrow originates from (7, 4) to (7, 5)
	var arrow: Array[Vector2i] = overlay.targeting_intent_arrow_cells()
	if arrow.size() != 2 or arrow[0] != Vector2i(7, 4) or arrow[1] != Vector2i(7, 5):
		failures.append("PlanningQAGate range1_enemy_hover: targeting arrow %s expected [(7, 4), (7, 5)]" % str(arrow))
		return
	
	# Move preview arrow on hover matches the painted route
	var live: CombatPlanningPreview = overlay.get_live_preview()
	var hover_move_arrow: Array = overlay._interaction_move_route(fix.knight.id, live, live.preview_paths.get(fix.knight.id, []) if live != null else [])
	var expected_route: Array = [Vector2i(4, 5), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)]
	if hover_move_arrow != expected_route:
		failures.append("PlanningQAGate range1_enemy_hover: hover move preview arrow %s expected %s" % [str(hover_move_arrow), str(expected_route)])
		return
	
	# Timeline ghost has BOTH pre-move to (7, 4) and action on enemy
	var ghost_slots: Dictionary = input.timeline_ghost_slots(1)
	var ghost_pre: Array = ghost_slots.get("pre", [])
	var ghost_act: Array = ghost_slots.get("action", [])
	if ghost_pre.is_empty():
		failures.append("PlanningQAGate range1_enemy_hover: timeline ghost missing pre-move to (7, 4)")
		return
	if (ghost_pre[0] as TimelineAction).target_coord != Vector2i(7, 4):
		failures.append("PlanningQAGate range1_enemy_hover: timeline ghost pre-move target %s expected (7, 4)" % str((ghost_pre[0] as TimelineAction).target_coord))
		return
	if ghost_act.is_empty():
		failures.append("PlanningQAGate range1_enemy_hover: timeline ghost missing action on enemy")
		return
	
	# Step 3: Click enemy at (7, 5) to commit
	input.set_qa_pointer_grid_cell(Vector2i(7, 5))
	input.on_left_press(fix.map_stub.grid_to_local(Vector2i(7, 5)))
	
	# Assert BOTH pre-move and action are committed
	if director.plan_pre_move.entries.size() != 1:
		failures.append("PlanningQAGate range1_enemy_hover: pre-move was not committed! Expected 1, got %d" % director.plan_pre_move.entries.size())
		return
	if director.plan_pre_move.entries[0].target_coord != Vector2i(7, 4):
		failures.append("PlanningQAGate range1_enemy_hover: pre-move destination %s expected (7, 4)" % str(director.plan_pre_move.entries[0].target_coord))
		return
	if director.plan_action.entries.size() != 1:
		failures.append("PlanningQAGate range1_enemy_hover: action was not committed! Expected 1, got %d" % director.plan_action.entries.size())
		return
	
	# Assert 100% parity between hover movepreview and committed movepreview
	var committed: CombatPlanningPreview = overlay.get_committed_preview()
	var commit_move_arrow: Array = CombatPlanningPreview.committed_move_route_leg(fix.knight.id, committed, director, director.base_board, GameEnums.MoveTiming.PRE_ACTION)
	if commit_move_arrow != expected_route:
		failures.append("PlanningQAGate range1_enemy_hover: committed move preview arrow %s expected %s" % [str(commit_move_arrow), str(expected_route)])
		return
	if hover_move_arrow != commit_move_arrow:
		failures.append("PlanningQAGate range1_enemy_hover: hover movepreview (%s) != commit movepreview (%s)" % [str(hover_move_arrow), str(commit_move_arrow)])
		return
	
	# Step 4: Simulator execution parity (walks along waypoints to (7, 4), then bashes)
	var trial: BoardState = director.base_board.clone()
	var evs: Array[SimEvent] = []
	Simulator.simulate_player_turn(trial, director.get_player_plan(), evs)
	var moved: bool = false
	var bashed: bool = false
	for e: SimEvent in evs:
		if e.type == GameEnums.SimEventType.UNIT_MOVED and e.data.get("actor", -1) == 1 and e.data.get("to") == Vector2i(7, 4):
			moved = true
		if e.type == GameEnums.SimEventType.ABILITY_USED and e.data.get("actor", -1) == 1:
			bashed = true
	if not moved:
		failures.append("PlanningQAGate range1_enemy_hover: simulator did not execute movement to (7, 4)")
		return
	if not bashed:
		failures.append("PlanningQAGate range1_enemy_hover: simulator did not execute Shield Bash from (7, 4)")
		return


static func _test_movement_module_hover_uses_route_not_target_arrow(
	failures: Array[String],
) -> void:
	const BruiserFixture := preload("res://tests/harness/bruiser_planning_checklist_harness.gd")
	var start := Vector2i(6, 4)
	var target := Vector2i(7, 5)
	var fix: Dictionary = BruiserFixture.wire_board(
		start, Vector2i(-1, -1), Vector2i(-1, -1), &"bruiser_charge_strike",
	)
	if fix.is_empty():
		failures.append("PlanningQAGate movement_module_hover: bruiser fixture missing")
		return
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var overlay: TacticalPlanningOverlay = fix.overlay
	var actor: UnitState = fix.actor
	var ability: AbilityData = actor.active_abilities[0]
	if not AbilitySystem.ability_has_movement_effect(ability, actor):
		failures.append("PlanningQAGate movement_module_hover: fixture ability lacks MOVE module")
		return
	director.select_ability(0)
	var expected: Array[Vector2i] = [start, Vector2i(7, 4), target]
	var live := CombatPlanningPreview.new()
	live.preview_board = fix.board.clone()
	live.preview_paths[actor.id] = expected
	live.preview_splits[actor.id] = expected.size()
	input.preview_state = live
	overlay.apply_preview_state(live, actor.id, -1)
	overlay.set_hover_coord(target)
	var preview_route: Array = overlay.get_live_preview().preview_paths.get(actor.id, [])
	if preview_route != expected:
		failures.append(
			"PlanningQAGate movement_module_hover: preview route %s expected %s"
			% [
				str(preview_route), str(expected),
			],
		)
		return
	for i: int in range(1, preview_route.size()):
		if GridSystem.manhattan(preview_route[i - 1], preview_route[i]) != 1:
			failures.append(
				"PlanningQAGate movement_module_hover: preview route %s contains diagonal step"
				% str(preview_route),
			)
			return
	if not overlay.targeting_intent_arrow_cells().is_empty():
		failures.append(
			"PlanningQAGate movement_module_hover: MOVE module must not draw direct target arrow",
		)
		return
	var action := TimelineAction.make_ability(
		actor.id, ability, target, -1, GameEnums.MoveTiming.PRE_ACTION, expected.slice(1),
	)
	var committed_route: Array = CombatPlanningPreview.committed_action_route_leg(
		actor.id, live, action, start,
	)
	if committed_route != preview_route:
		failures.append(
			"PlanningQAGate movement_module_hover: preview route %s != commit route %s"
			% [str(preview_route), str(committed_route)],
		)
	# Live production path: charge MOVE module hover must not emit diagonal target arrow.
	var live_start := Vector2i(6, 4)
	var live_enemy := Vector2i(8, 6)
	var live_fix: Dictionary = BruiserFixture.wire_board(
		live_start, live_enemy, Vector2i(-1, -1), &"bruiser_charge_strike",
	)
	if live_fix.is_empty():
		failures.append("PlanningQAGate movement_module_hover live: bruiser fixture missing")
		return
	var live_input: CombatPlanningInput = live_fix.input
	var live_director: CombatDirector = live_fix.director
	var live_overlay: TacticalPlanningOverlay = live_fix.overlay
	var live_actor: UnitState = live_fix.actor
	if PlanningChecklistHarness.select_ability(live_fix, &"bruiser_charge_strike") < 0:
		failures.append("PlanningQAGate movement_module_hover live: ability select failed")
		return
	if not _arm_awaiting_at(live_input, live_director, live_start):
		failures.append("PlanningQAGate movement_module_hover live: MOVE module did not arm")
		return
	if not live_input.active_movement_planning_step(live_actor):
		failures.append("PlanningQAGate movement_module_hover live: expected active movement step")
		return
	PlanningChecklistHarness.hover(live_fix, live_enemy)
	PlanningChecklistHarness.flush_planning(live_fix)
	if not live_input.active_movement_planning_step(live_actor):
		failures.append(
			"PlanningQAGate movement_module_hover live: movement step lost after enemy hover",
		)
		return
	_assert_charge_strike_hover_visual_contract(
		failures,
		"PlanningQAGate movement_module_hover live/enemy",
		live_overlay,
		live_input,
		live_actor,
		false,
	)
	var move_dest := Vector2i(7, 5)
	PlanningChecklistHarness.hover(live_fix, move_dest)
	PlanningChecklistHarness.flush_planning(live_fix)
	_assert_charge_strike_hover_visual_contract(
		failures,
		"PlanningQAGate movement_module_hover live/dest",
		live_overlay,
		live_input,
		live_actor,
		false,
		)


static func _test_planning_route_policy_enemy_hover_geometry(failures: Array[String]) -> void:
	const Policy := preload("res://core/systems/planning_route_policy.gd")
	var fix: Dictionary = _archer_power_shot_fixture(Vector2i(4, 5), Vector2i(5, 5))
	var actor: UnitState = fix.archer
	var enemy: UnitState = fix.enemy
	var ability: AbilityData = fix.power_shot
	var move_origin: Vector2i = actor.position
	var detour: Array[Vector2i] = [Vector2i(4, 4)]
	if Policy.enemy_hover_respects_painted_corridor(
		actor,
		enemy,
		ability,
		detour,
		move_origin,
		true,
		false,
		Vector2i(-999999, -999999),
		false,
		true,
	):
		failures.append(
			"PlanningQAGate planning_route_policy: in-range range-2+ must ignore painted corridor",
		)
	var approach: Vector2i = Vector2i(6, 5)
	var approach_route: Array[Vector2i] = [approach]
	if not Policy.enemy_hover_respects_painted_corridor(
		actor,
		enemy,
		ability,
		approach_route,
		move_origin,
		false,
		true,
		approach,
		false,
		true,
	):
		failures.append(
			"PlanningQAGate planning_route_policy: out-of-range approach stand must respect corridor",
		)
	var stationary: Array[Vector2i] = [move_origin]
	if Policy.enemy_hover_respects_painted_corridor(
		actor,
		enemy,
		ability,
		stationary,
		move_origin,
		true,
		true,
		Vector2i(-999999, -999999),
		false,
		true,
	):
		failures.append(
			"PlanningQAGate planning_route_policy: in-range stationary hover must not lock painted corridor",
		)


static func _test_out_of_range_enemy_hover_with_move_exhausted_shows_null_glyph_and_no_ghost(failures: Array[String]) -> void:
	# Archer at (4, 5), Enemy at (8, 5) (distance 4, out of range for Snap Shot which has range 1-2)
	var fix: Dictionary = _archer_power_shot_fixture(Vector2i(4, 5), Vector2i(8, 5))
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var overlay: TacticalPlanningOverlay = fix.overlay
	
	# Step 1: Pre-plan a move for Archer to (4, 4) (move slot now closed)
	director.rpc_plan_move(fix.archer.id, Vector2i(4, 4), -1, [Vector2i(4, 4)])
	if director.plan_pre_move.entries.size() != 1:
		failures.append("PlanningQAGate out_of_range_enemy_hover: failed to plan initial pre-move")
		return
	
	# Select Snap Shot (Ability 1, Range 1-2)
	director.selected_ability_index = 1
	
	# Step 2: Hover over enemy at (8, 5) (distance from (4, 4) is 4 > range 2, and move slot is closed)
	input.on_hover_moved(Vector2i(8, 5))
	input._flush_hover_heavy_sync()
	
	# Assert cursor icon is GLYPH_NULL (🚫)
	var hover_icon: String = input.compute_hover_action_icon(Vector2i(8, 5))
	if hover_icon != PlanningIcons.GLYPH_NULL:
		failures.append("PlanningQAGate out_of_range_enemy_hover: hover cursor icon '%s' expected GLYPH_NULL ('%s')" % [hover_icon, PlanningIcons.GLYPH_NULL])
		return
	
	# Assert live preview has NO targeting arrow and NO attack ghost
	var arrow: Array[Vector2i] = overlay.targeting_intent_arrow_cells()
	if not arrow.is_empty():
		failures.append("PlanningQAGate out_of_range_enemy_hover: targeting arrow %s must NOT be present for unattackable enemy" % str(arrow))
		return
	
	# Step 3: Click enemy at (8, 5)
	input.set_qa_pointer_grid_cell(Vector2i(8, 5))
	input.on_left_press(fix.map_stub.grid_to_local(Vector2i(8, 5)))
	
	# Assert action was NOT committed and pre-move remained intact
	if director.plan_action.entries.size() != 0:
		failures.append("PlanningQAGate out_of_range_enemy_hover: clicking out-of-range unattackable enemy committed action!")
		return
	if director.plan_pre_move.entries.size() != 1:
		failures.append("PlanningQAGate out_of_range_enemy_hover: clicking out-of-range enemy corrupted pre-move!")
		return


static func _test_post_move_after_variety_of_skills_contract(failures: Array[String]) -> void:
	var label := "PlanningQAGate post_move_after_skills"
	# 1. Stationary attack + Post-Move (Move 1 -> Slash -> Move 1)
	var raw_fix: Dictionary = _planning_fixture(Vector2i(2, 2), Vector2i(2, 4))
	var fix: Dictionary = PlanningDragE2EHarness.wire_fixture(raw_fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var knight: UnitState = fix.knight
	knight.movement.points_left = 3
	director.board.get_unit_by_id(1).movement.points_left = 3
	
	# Step 1: Pre-move to (2, 3)
	input.set_qa_pointer_grid_cell(Vector2i(2, 3))
	input.on_left_press(fix.map_stub.grid_to_local(Vector2i(2, 3)))
	if director.plan_pre_move.entries.size() != 1:
		failures.append("%s: stationary pre-move commit failed" % label)
		return
	
	# Step 2: Shield Bash Dummy at (2, 4)
	PlanningChecklistHarness.select_ability(fix, SHIELD_BASH_ID)
	input.set_qa_pointer_grid_cell(Vector2i(2, 4))
	input.on_hover_moved(Vector2i(2, 4))
	input.on_left_press(fix.map_stub.grid_to_local(Vector2i(2, 4)))
	if director.plan_action.entries.size() != 1:
		failures.append("%s: stationary action commit failed" % label)
		return
	
	# Step 3: Post-move to (3, 3) (adjacent to stand at (2, 3))
	input.set_qa_pointer_grid_cell(Vector2i(3, 3))
	input.on_hover_moved(Vector2i(3, 3))
	input.on_left_press(fix.map_stub.grid_to_local(Vector2i(3, 3)))
	if director.plan_post_move.entries.size() != 1:
		failures.append("%s: post-move after stationary attack failed to commit" % label)
		return
	var post_action: TimelineAction = director.plan_post_move.entries[0] as TimelineAction
	if post_action == null or post_action.target_coord != Vector2i(3, 3) or post_action.move_timing != GameEnums.MoveTiming.POST_ACTION:
		failures.append("%s: post-move action entry corrupted" % label)
		return
	
	# Verify projected state reflects [pre -> action -> post]
	var proj_knight: UnitState = director.projected_state.get_unit_by_id(1)
	if proj_knight == null or proj_knight.position != Vector2i(3, 3):
		failures.append("%s: projected position %s != (3, 3)" % [label, str(proj_knight.position if proj_knight != null else null)])
		return
	if proj_knight.movement.points_left != 1:
		failures.append("%s: projected MP %d expected 1" % [label, proj_knight.movement.points_left])
		return
	
	# Verify complete simulation executes [pre -> action -> post] cleanly
	var result: SimResult = _simulate_committed_plan(director)
	if result == null or result.final_state == null:
		failures.append("%s: sim failed for [pre -> action -> post]" % label)
		return
	var final_knight: UnitState = result.final_state.get_unit_by_id(1)
	if final_knight == null or final_knight.position != Vector2i(3, 3):
		failures.append("%s: final simulated position %s != (3, 3)" % [label, str(final_knight.position if final_knight != null else null)])
		return

	# 2. Post-move after Swap: [Swap -> Shield Bash -> Post-Move Walk]
	var swap_fix: Dictionary = PlanningChecklistHarness.wire_swap_board(PlanningChecklistHarness.SWAP_ALLY_CELL)
	var k1_id: int = swap_fix.k1_id
	var swap_director: CombatDirector = swap_fix.director
	# Add dummy at (4, 3) for Shield Bash target after swap
	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	var dummy: UnitState = UnitState.create(4, dummy_def, GameEnums.Team.ENEMY, Vector2i(4, 3))
	swap_director.board.add_unit(dummy)
	GridSystem.set_occupant(swap_director.board, dummy.position, dummy.id)
	swap_director.base_board.add_unit(dummy.clone())
	GridSystem.set_occupant(swap_director.base_board, dummy.position, dummy.id)
	swap_director.projected_state.add_unit(dummy.clone())
	GridSystem.set_occupant(swap_director.projected_state, dummy.position, dummy.id)

	# 2a. Pre-move Swap with Ally at (4, 4)
	var swap_idx: int = PlanningChecklistHarness.select_ability_for_unit(swap_fix, k1_id, PlanningChecklistHarness.KNIGHT_SWAP_ID)
	if swap_idx >= 0:
		PlanningChecklistHarness.select_unit(swap_fix, k1_id, PlanningChecklistHarness.SWAP_ALLY_CELL)
		var swap_slots: Dictionary = PlanningChecklistHarness.commit_production(swap_fix, PlanningChecklistHarness.SWAP_ALLY_CELL)
		if PlanningChecklistHarness.slots_invalid(swap_slots) or swap_director.plan_pre_move.entries.size() != 1:
			failures.append("%s: swap pre-move commit failed (invalid=%s)" % [label, str(swap_slots.get("invalid", ""))])
			return
		
		# 2b. Shield Bash Dummy at (4, 3) from swapped stand (4, 4)
		PlanningChecklistHarness.select_ability_for_unit(swap_fix, k1_id, PlanningChecklistHarness.SHIELD_BASH_ID)
		PlanningChecklistHarness.select_unit(swap_fix, k1_id, Vector2i(4, 3))
		var bash_slots: Dictionary = PlanningChecklistHarness.commit_production(swap_fix, Vector2i(4, 3))
		if PlanningChecklistHarness.slots_invalid(bash_slots) or swap_director.plan_action.entries.size() != 1:
			failures.append("%s: shield bash after swap commit failed (invalid=%s)" % [label, str(bash_slots.get("invalid", ""))])
			return

		# 2c. Post-move to (3, 4) (1 step away from swapped stand at (4, 4))
		PlanningChecklistHarness.select_unit(swap_fix, k1_id, Vector2i(3, 4))
		var post_slots: Dictionary = PlanningChecklistHarness.commit_production(swap_fix, Vector2i(3, 4))
		if PlanningChecklistHarness.slots_invalid(post_slots) or swap_director.plan_post_move.entries.size() != 1:
			failures.append("%s: post-move after Swap failed to commit (invalid=%s)" % [label, str(post_slots.get("invalid", ""))])
			return
		var swap_post: TimelineAction = swap_director.plan_post_move.entries[0] as TimelineAction
		if swap_post == null or swap_post.target_coord != Vector2i(3, 4):
			failures.append("%s: post-move after Swap destination corrupted" % label)
			return

		# 2d. Simulate entire [Swap -> Bash -> Post-Move] timeline
		var swap_result: SimResult = _simulate_committed_plan(swap_director)
		if swap_result == null or swap_result.final_state == null:
			failures.append("%s: swap sim failed" % label)
			return
		var final_swap_knight: UnitState = swap_result.final_state.get_unit_by_id(k1_id)
		if final_swap_knight == null or final_swap_knight.position != Vector2i(3, 4):
			failures.append("%s: final simulated swap knight %s != (3, 4)" % [label, str(final_swap_knight.position if final_swap_knight != null else null)])
			return
		var final_dummy: UnitState = swap_result.final_state.get_unit_by_id(4)
		if final_dummy == null or final_dummy.position != Vector2i(4, 1):
			failures.append("%s: final simulated dummy push %s != (4, 1)" % [label, str(final_dummy.position if final_dummy != null else null)])
			return

	# 3. Archer Power Shot (Stationary without pre-move) -> Post-move walk (2 tiles) & MP display check
	var raw_archer_fix: Dictionary = _planning_fixture(Vector2i(2, 2), Vector2i(2, 5))
	var archer_fix: Dictionary = PlanningDragE2EHarness.wire_fixture(raw_archer_fix)
	var archer_input: CombatPlanningInput = archer_fix.input
	var archer_director: CombatDirector = archer_fix.director
	var archer_unit: UnitState = archer_fix.knight
	var power_shot: AbilityData = ArcherQaHarness.factory_ability(&"archer_power_shot")
	archer_unit.active_abilities = [power_shot]
	archer_director.board.get_unit_by_id(1).active_abilities = [power_shot]
	archer_director.base_board.get_unit_by_id(1).active_abilities = [power_shot]
	archer_director.projected_state.get_unit_by_id(1).active_abilities = [power_shot]
	
	# 3a. Select Power Shot and shoot Dummy at (2, 5) without moving
	archer_director.select_ability(0)
	archer_input.set_qa_pointer_grid_cell(Vector2i(2, 5))
	archer_input.on_hover_moved(Vector2i(2, 5))
	archer_input.on_left_press(archer_fix.map_stub.grid_to_local(Vector2i(2, 5)))
	if archer_director.plan_action.entries.size() != 1:
		failures.append("%s: archer power shot commit failed" % label)
		return
	if archer_director.plan_pre_move.entries.size() != 0:
		failures.append("%s: archer should not have pre-move" % label)
		return
	
	# 3b. Verify post-move hover & display MP before commit (hovering 2 tiles away from (2, 2) to (4, 2))
	archer_input.set_qa_pointer_grid_cell(Vector2i(4, 2))
	archer_input.on_hover_moved(Vector2i(4, 2))
	var archer_mp_display: int = archer_input.planning_display_mp_left(1)
	if archer_mp_display != 1:
		failures.append("%s: archer hovering 2 tiles away displayed MP %d expected 1" % [label, archer_mp_display])
		return
	
	# 3c. Commit post-move walk to (4, 2)
	archer_input.on_left_press(archer_fix.map_stub.grid_to_local(Vector2i(4, 2)))
	if archer_director.plan_post_move.entries.size() != 1:
		failures.append("%s: archer post-move commit failed" % label)
		return
	var archer_post: TimelineAction = archer_director.plan_post_move.entries[0] as TimelineAction
	if archer_post == null or archer_post.target_coord != Vector2i(4, 2):
		failures.append("%s: archer post-move destination corrupted" % label)
		return
	
	# 3d. Simulate Archer [Power Shot -> Post-Move Walk]
	var archer_result: SimResult = _simulate_committed_plan(archer_director)
	if archer_result == null or archer_result.final_state == null:
		failures.append("%s: archer sim failed" % label)
		return
	var final_archer: UnitState = archer_result.final_state.get_unit_by_id(1)
	if final_archer == null or final_archer.position != Vector2i(4, 2):
		failures.append("%s: final simulated archer %s != (4, 2)" % [label, str(final_archer.position if final_archer != null else null)])
		return
	var final_dummy_target: UnitState = archer_result.final_state.get_unit_by_id(2)
	if final_dummy_target == null or final_dummy_target.position != Vector2i(2, 6):
		failures.append("%s: final simulated target dummy push %s != (2, 6)" % [label, str(final_dummy_target.position if final_dummy_target != null else null)])
		return
	var last_attack_effect_index := -1
	var post_move_event_index := -1
	for event_index: int in range(archer_result.events.size()):
		var event: SimEvent = archer_result.events[event_index]
		if event.type in [
			GameEnums.SimEventType.UNIT_DAMAGED,
			GameEnums.SimEventType.UNIT_PUSHED,
			GameEnums.SimEventType.COLLISION,
		]:
			last_attack_effect_index = event_index
		elif (
			event.type == GameEnums.SimEventType.UNIT_MOVED
			and int(event.data.get("move_timing", GameEnums.MoveTiming.PRE_ACTION))
				== GameEnums.MoveTiming.POST_ACTION
		):
			post_move_event_index = event_index
	if (
		last_attack_effect_index < 0
		or post_move_event_index <= last_attack_effect_index
	):
		failures.append(
			"%s: post-move must follow attack damage/push/collision events" % label,
		)

	# 4. Training unlimited-actions: skill commit must still route walk to post-move (not live premove)
	var raw_unlimited: Dictionary = _planning_fixture(Vector2i(2, 2), Vector2i(2, 5))
	var unlimited_fix: Dictionary = PlanningDragE2EHarness.wire_fixture(raw_unlimited)
	var unlimited_input: CombatPlanningInput = unlimited_fix.input
	var unlimited_director: CombatDirector = unlimited_fix.director
	var unlimited_archer: UnitState = unlimited_fix.knight
	var unlimited_power_shot: AbilityData = ArcherQaHarness.factory_ability(&"archer_power_shot")
	unlimited_archer.active_abilities = [unlimited_power_shot]
	for b: BoardState in [
		unlimited_director.board,
		unlimited_director.base_board,
		unlimited_director.projected_state,
	]:
		if b == null:
			continue
		var u: UnitState = b.get_unit_by_id(1)
		if u != null:
			u.active_abilities = [unlimited_power_shot]
			u.passive_flags["training_unlimited_actions"] = true
	unlimited_director.select_ability(0)
	unlimited_input.set_qa_pointer_grid_cell(Vector2i(2, 5))
	unlimited_input.on_hover_moved(Vector2i(2, 5))
	unlimited_input.on_left_press(unlimited_fix.map_stub.grid_to_local(Vector2i(2, 5)))
	if unlimited_director.plan_action.entries.size() != 1:
		failures.append("%s: unlimited training action commit failed" % label)
		return
	var stand_before_post: Vector2i = unlimited_director.board.get_unit_by_id(1).position
	unlimited_input.set_qa_pointer_grid_cell(Vector2i(4, 2))
	unlimited_input.on_hover_moved(Vector2i(4, 2))
	unlimited_input.on_left_press(unlimited_fix.map_stub.grid_to_local(Vector2i(4, 2)))
	if unlimited_director.plan_pre_move.entries.size() != 0:
		failures.append("%s: unlimited training post-move must not land in pre-move column" % label)
		return
	if unlimited_director.plan_post_move.entries.size() != 1:
		failures.append("%s: unlimited training post-move commit failed" % label)
		return
	var live_after: UnitState = unlimited_director.board.get_unit_by_id(1)
	if live_after != null and live_after.position != stand_before_post:
		failures.append(
			"%s: unlimited training post-move must not walk live board (got %s expected %s)"
			% [label, live_after.position, stand_before_post],
		)


static func _archer_snap_shot_fixture(
	archer_pos: Vector2i,
	enemy_pos: Vector2i,
) -> Dictionary:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var basic: AbilityData = DataLibrary._make_class_basic_attack(&"archer")
	var archer_def: UnitData = ArcherQaHarness.archer_unit_data()
	var archer: UnitState = UnitState.create(
		1, archer_def, GameEnums.Team.PLAYER, archer_pos,
		{"active_abilities": [basic]},
	)
	archer.movement.points_left = archer.movement.max_points
	archer.ability.points_left = maxi(1, archer.ability.max_points)
	archer.ability.max_points = maxi(1, archer.ability.max_points)
	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	var enemy: UnitState = UnitState.create(2, dummy_def, GameEnums.Team.ENEMY, enemy_pos)
	var board: BoardState = _plain_board(Vector2i(12, 12), [archer, enemy])
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = archer.id
	director.selected_ability_index = 0
	input._director = director
	input.auto_use_skill_after_move = true
	var fix: Dictionary = {
		"input": input,
		"director": director,
		"board": board,
		"archer": archer,
		"knight": archer,
		"enemy": enemy,
		"basic": basic,
	}
	return PlanningDragE2EHarness.wire_fixture(fix)


static func _test_steady_aim_auto_run_parity(failures: Array[String]) -> void:
	var far: Dictionary = _archer_snap_shot_fixture(Vector2i(4, 5), Vector2i(7, 5))
	var far_input: CombatPlanningInput = far.input
	var far_director: CombatDirector = far.director
	far_director.select_unit(1)
	far_director.select_ability(0)
	far_input.set_qa_pointer_grid_cell(Vector2i(7, 5))
	far_input.on_hover_moved(Vector2i(7, 5))
	far_input._flush_hover_heavy_sync()
	var far_slots: Dictionary = far_input._intent_snapshot_slots.duplicate(true)
	if not far_input._intent_snapshot_valid or _slots_invalid(far_slots):
		failures.append(
			"PlanningQAGate steady_aim_auto_run_parity: extra-range hover slots invalid (%s)"
			% str(far_slots.get("invalid", "")),
		)
		return
	var far_action_steps: Array = far_slots.get("action", []) as Array
	if far_action_steps.is_empty():
		failures.append("PlanningQAGate steady_aim_auto_run_parity: extra-range hover missing action slot")
		return
	var far_action: TimelineAction = far_action_steps[0] as TimelineAction
	if far_action == null or not far_action.uses_steady_aim:
		failures.append("PlanningQAGate steady_aim_auto_run_parity: extra-range hover must stamp uses_steady_aim")
		return
	var far_hover_icon: String = far_input.compute_hover_action_icon(Vector2i(7, 5))
	var far_slot_icon: String = far_input._cursor_icon_from_commit_slots(far_slots, far.archer)
	if far_hover_icon != far_slot_icon or far_hover_icon.is_empty():
		failures.append(
			"PlanningQAGate steady_aim_auto_run_parity: hover icon %s != slot icon %s"
			% [far_hover_icon, far_slot_icon],
		)
		return
	if far_hover_icon.find(PlanningIcons.GLYPH_RANGE) < 0:
		failures.append(
			"PlanningQAGate steady_aim_auto_run_parity: extra-range hover icon %s missing Steady Aim bow"
			% far_hover_icon,
		)
		return
	if far_input.planning_display_mp_left(1) != 0:
		failures.append(
			"PlanningQAGate steady_aim_auto_run_parity: extra-range hover MP %d expected 0"
			% far_input.planning_display_mp_left(1),
		)
		return
	var ghost: Dictionary = far_input.timeline_ghost_slots(1)
	var ghost_actions: Array = ghost.get("action", []) as Array
	if ghost_actions.is_empty() or not (ghost_actions[0] as TimelineAction).uses_steady_aim:
		failures.append("PlanningQAGate steady_aim_auto_run_parity: timeline ghost must show Steady Aim")
		return
	far_input.on_left_press(far.map_stub.grid_to_local(Vector2i(7, 5)))
	if far_director.plan_action.entries.size() != 1:
		failures.append("PlanningQAGate steady_aim_auto_run_parity: extra-range Snap Shot did not commit")
		return
	var committed: TimelineAction = far_director.plan_action.entries[0] as TimelineAction
	if committed == null or not committed.uses_steady_aim:
		failures.append("PlanningQAGate steady_aim_auto_run_parity: committed slot missing uses_steady_aim")
		return
	var proj: UnitState = far_director.projected_state.get_unit_by_id(1)
	if proj == null or proj.movement.points_left != 0:
		failures.append(
			"PlanningQAGate steady_aim_auto_run_parity: committed projected MP %s expected 0"
			% str(proj.movement.points_left if proj != null else null),
		)
		return
	if far_input.planning_display_mp_left(1) != 0:
		failures.append(
			"PlanningQAGate steady_aim_auto_run_parity: committed display MP %d expected 0"
			% far_input.planning_display_mp_left(1),
		)
		return

	var near: Dictionary = _archer_snap_shot_fixture(Vector2i(4, 5), Vector2i(6, 5))
	var near_input: CombatPlanningInput = near.input
	var near_director: CombatDirector = near.director
	near_director.select_unit(1)
	near_director.select_ability(0)
	near_input.set_qa_pointer_grid_cell(Vector2i(6, 5))
	near_input.on_hover_moved(Vector2i(6, 5))
	near_input._flush_hover_heavy_sync()
	var near_slots: Dictionary = near_input._intent_snapshot_slots.duplicate(true)
	if not near_input._intent_snapshot_valid or _slots_invalid(near_slots):
		failures.append(
			"PlanningQAGate steady_aim_auto_run_parity: in-range hover slots invalid (%s)"
			% str(near_slots.get("invalid", "")),
		)
		return
	var near_action_steps: Array = near_slots.get("action", []) as Array
	if near_action_steps.is_empty():
		failures.append("PlanningQAGate steady_aim_auto_run_parity: in-range hover missing action slot")
		return
	var near_action: TimelineAction = near_action_steps[0] as TimelineAction
	if near_action != null and near_action.uses_steady_aim:
		failures.append("PlanningQAGate steady_aim_auto_run_parity: in-range hover must not stamp uses_steady_aim")
		return
	var near_icon: String = near_input.compute_hover_action_icon(Vector2i(6, 5))
	if near_icon.find(PlanningIcons.GLYPH_RANGE) >= 0:
		failures.append(
			"PlanningQAGate steady_aim_auto_run_parity: in-range hover icon %s must not show Steady Aim bow"
			% near_icon,
		)
		return
	var near_max_mp: int = (near.archer as UnitState).movement.max_points
	if near_input.planning_display_mp_left(1) != near_max_mp:
		failures.append(
			"PlanningQAGate steady_aim_auto_run_parity: in-range hover MP %d expected %d"
			% [near_input.planning_display_mp_left(1), near_max_mp],
		)



