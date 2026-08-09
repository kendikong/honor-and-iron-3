class_name ShieldBashScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Shield Bash â€” DAMAGE 1 + PUSH 2; [+] STAGGER if push collides with wall/enemy.
## Globals: EffectType.DAMAGE, PUSH; upgraded PUSH_STAGGER_ON_COLLISION via AbilitySystem.
## Tier 1: 7-phase planning harness + sim upgrade collision assert (Knight QA â€” not planning gate).


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_phase1_select(failures)
	_phase2_hover_empty(failures)
	_phase3_pathing(failures)
	_phase4_hover_enemy(failures)
	_phase5_commit(failures)
	_phase6_execute(failures)
	_phase7_premove_then_bash(failures)


static func _sim_contract(failures: Array[String]) -> void:
	var bash: AbilityData = _KnightQaHarness.factory_ability(&"knight_shield_bash")
	_KnightQaHarness.assert_true(
		failures, "bash/contract/damage",
		_KnightQaHarness.ability_has_effect(bash, GameEnums.EffectType.DAMAGE, false),
	)
	_KnightQaHarness.assert_true(
		failures, "bash/contract/push",
		_KnightQaHarness.ability_has_effect(bash, GameEnums.EffectType.PUSH, false),
	)
	_KnightQaHarness.assert_true(
		failures, "bash/contract/upgrade_stagger",
		_KnightQaHarness.ability_has_effect(bash, GameEnums.EffectType.PUSH_STAGGER_ON_COLLISION, true),
	)
	_KnightQaHarness.run_bash_wall_stagger_upgrade(failures)
	_KnightQaHarness.run_bash_base_sim(failures)


static func _bash_ability(fix: Dictionary) -> AbilityData:
	var idx: int = PlanningChecklistHarness.ability_index(
		fix.knight, PlanningChecklistHarness.SHIELD_BASH_ID,
	)
	return fix.knight.active_abilities[idx] if idx >= 0 else null


static func _phase1_select(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	fix.director.auto_run = true
	var idx: int = PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.SHIELD_BASH_ID)
	var ability: AbilityData = _bash_ability(fix)
	if idx < 0 or ability == null:
		PlanningChecklistHarness.assert_fail(failures, "bash/phase1", "Shield Bash missing")
		return
	PlanningChecklistHarness.assert_ability_kind_class(failures, "bash/phase1", ability)
	PlanningChecklistHarness.assert_eq_int(
		failures, "bash/phase1/ap",
		fix.knight.ability.points_left, 1,
	)
	PlanningChecklistHarness.assert_eq_int(
		failures, "bash/phase1/mp",
		fix.knight.movement.points_left, fix.knight.movement.max_points,
	)
	PlanningChecklistHarness.assert_true(
		failures, "bash/phase1/timeline_empty",
		fix.director.plan_pre_move.entries.is_empty()
		and fix.director.plan_action.entries.is_empty(),
		"timeline must be empty on select",
	)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "bash/phase1/stand",
		PlanningChecklistHarness.projected_unit(fix, 1).position,
		PlanningChecklistHarness.KNIGHT_START,
	)
	PlanningChecklistHarness.assert_red_contract(
		failures, "bash/phase1/red_at_stand", fix, ability, true, PlanningChecklistHarness.KNIGHT_START,
	)
	PlanningChecklistHarness.assert_red_excludes_cell(
		failures, "bash/phase1/enemy_oob",
		fix, ability, PlanningChecklistHarness.KNIGHT_START, PlanningChecklistHarness.ENEMY_POS,
	)


static func _phase2_hover_empty(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	fix.director.auto_run = true
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.SHIELD_BASH_ID)
	var ability: AbilityData = _bash_ability(fix)
	var hover_walk: Vector2i = Vector2i(5, 5)
	PlanningChecklistHarness.hover(fix, hover_walk)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "bash/phase2/ghost_walk",
		PlanningChecklistHarness.preview_unit_pos(fix, 1), hover_walk,
	)
	var path: Array[Vector2i] = PlanningChecklistHarness.preview_path(fix, 1)
	PlanningChecklistHarness.assert_true(
		failures, "bash/phase2/path_walk",
		path.size() >= 2 and path[0] == PlanningChecklistHarness.KNIGHT_START and path[-1] == hover_walk,
		"path must be %s -> %s, got %s"
		% [PlanningChecklistHarness.KNIGHT_START, hover_walk, path],
	)
	PlanningChecklistHarness.assert_red_contract(
		failures, "bash/phase2/red_walk", fix, ability, true, hover_walk,
	)
	PlanningChecklistHarness.assert_red_excludes_cell(
		failures, "bash/phase2/enemy_oob_walk",
		fix, ability, hover_walk, PlanningChecklistHarness.ENEMY_POS,
	)
	var walk_slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, hover_walk)
	PlanningChecklistHarness.assert_cursor_contains(
		failures, "bash/phase2/cursor_walk", fix, walk_slots, PlanningIcons.GLYPH_WALK,
	)
	# Run-required hover with 0 MP â€” red off (run eats only AP).
	PlanningChecklistHarness.set_knight_pools(fix, 1, 0)
	var run_tile: Vector2i = PlanningChecklistHarness.find_run_hover_tile(fix.board, fix.knight)
	if run_tile.x <= -900000:
		PlanningChecklistHarness.assert_fail(failures, "bash/phase2", "no run tile in fixture")
		return
	PlanningChecklistHarness.hover(fix, run_tile)
	PlanningChecklistHarness.assert_red_contract(
		failures, "bash/phase2/red_off_run", fix, ability, false,
	)
	var run_slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, run_tile)
	PlanningChecklistHarness.assert_cursor_is(
		failures, "bash/phase2/cursor_run", fix, run_slots, PlanningIcons.GLYPH_RUN,
	)


static func _phase3_pathing(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	fix.director.auto_run = true
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.SHIELD_BASH_ID)
	var ability: AbilityData = _bash_ability(fix)
	var route: Array[Vector2i] = [
		PlanningChecklistHarness.KNIGHT_START,
		Vector2i(5, 5),
		PlanningChecklistHarness.BASH_APPROACH,
	]
	PlanningDragE2EHarness.begin_drag_route(fix, route)
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.BASH_APPROACH)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "bash/phase3/ghost_end",
		PlanningChecklistHarness.preview_unit_pos(fix, 1), PlanningChecklistHarness.BASH_APPROACH,
	)
	var path: Array[Vector2i] = PlanningChecklistHarness.preview_path(fix, 1)
	for i: int in range(route.size()):
		if i >= path.size() or path[i] != route[i]:
			PlanningChecklistHarness.assert_fail(
				failures, "bash/phase3/paint_order",
				"painted route %s must match preview path %s" % [route, path],
			)
			break
	PlanningChecklistHarness.assert_red_contract(
		failures, "bash/phase3/red_at_path_end",
		fix, ability, true, PlanningChecklistHarness.BASH_APPROACH,
	)
	PlanningChecklistHarness.assert_red_includes_cell(
		failures, "bash/phase3/enemy_in_red",
		fix, ability, PlanningChecklistHarness.BASH_APPROACH, PlanningChecklistHarness.ENEMY_POS,
	)
	PlanningChecklistHarness.assert_true(
		failures, "bash/phase3/timeline_empty",
		fix.director.plan_pre_move.entries.is_empty(),
		"no timeline commit during drag preview only",
	)


static func _phase4_hover_enemy(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	fix.director.auto_run = true
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.SHIELD_BASH_ID)
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.ENEMY_POS)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "bash/phase4/ghost_approach",
		PlanningChecklistHarness.preview_unit_pos(fix, 1), PlanningChecklistHarness.BASH_APPROACH,
	)
	var path: Array[Vector2i] = PlanningChecklistHarness.preview_path(fix, 1)
	PlanningChecklistHarness.assert_true(
		failures, "bash/phase4/path_approach",
		path.size() >= 3 and path[-1] == PlanningChecklistHarness.BASH_APPROACH,
		"approach path must end at %s, got %s"
		% [PlanningChecklistHarness.BASH_APPROACH, path],
	)
	var slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, PlanningChecklistHarness.ENEMY_POS)
	PlanningChecklistHarness.assert_cursor_contains(
		failures, "bash/phase4/cursor_walk", fix, slots, PlanningIcons.GLYPH_WALK,
	)
	PlanningChecklistHarness.assert_cursor_contains(
		failures, "bash/phase4/cursor_attack", fix, slots, PlanningIcons.GLYPH_ATTACK,
	)
	var ability: AbilityData = _bash_ability(fix)
	PlanningChecklistHarness.assert_red_contract(
		failures, "bash/phase4/red_at_stand",
		fix, ability, true, PlanningChecklistHarness.BASH_APPROACH,
	)
	var push_from: Vector2i = PlanningChecklistHarness.ENEMY_POS
	var push_to: Vector2i = PlanningChecklistHarness.push_destination(fix, 2)
	PlanningChecklistHarness.assert_true(
		failures, "bash/phase4/push_east",
		push_to.x > push_from.x,
		"push must go east from %s, landing %s" % [push_from, push_to],
	)
	var pv_enemy: UnitState = fix.input.preview_state.preview_board.get_unit_by_id(2)
	PlanningChecklistHarness.assert_true(
		failures, "bash/phase4/preview_enemy_lands",
		pv_enemy != null and pv_enemy.position == push_to,
		"preview enemy must land at push tip %s" % push_to,
	)
	var pre: Array = slots.get("pre", []) as Array
	var action: Array = slots.get("action", []) as Array
	PlanningChecklistHarness.assert_true(
		failures, "bash/phase4/slots_pre_action",
		not pre.is_empty() and not action.is_empty(),
		"must build pre + action on enemy hover",
	)
	if not pre.is_empty() and pre[0] is TimelineAction:
		PlanningChecklistHarness.assert_eq_cell(
			failures, "bash/phase4/pre_dest",
			(pre[0] as TimelineAction).target_coord, PlanningChecklistHarness.BASH_APPROACH,
		)


static func _phase5_commit(failures: Array[String]) -> void:
	var fix_promote: Dictionary = PlanningChecklistHarness.wire_bash_board_minimal()
	fix_promote.director.auto_run = true
	PlanningChecklistHarness.select_ability(fix_promote, PlanningChecklistHarness.SHIELD_BASH_ID)
	PlanningChecklistHarness.hover(fix_promote, PlanningChecklistHarness.ENEMY_POS)
	if not PlanningChecklistHarness.commit_paint_promote_only(
		fix_promote, PlanningChecklistHarness.ENEMY_POS,
	):
		PlanningChecklistHarness.assert_fail(failures, "bash/phase5/promote_push", "commit paint/promote failed")
	else:
		PlanningChecklistHarness.assert_committed_ghost_pos(
			failures, "bash/phase5/promote_ghost", fix_promote, 1,
			PlanningChecklistHarness.BASH_APPROACH,
		)
		PlanningChecklistHarness.assert_committed_preview_push(
			failures, "bash/phase5/promote_push", fix_promote, 2,
		)
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	fix.director.auto_run = true
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.SHIELD_BASH_ID)
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.ENEMY_POS)
	PlanningChecklistHarness.assert_slots_match_preview_commit(
		failures, "bash/phase5/hover_click_parity", fix, PlanningChecklistHarness.ENEMY_POS,
	)
	PlanningChecklistHarness.assert_commit_no_jump(
		failures, "bash/phase5/no_jump", fix, PlanningChecklistHarness.ENEMY_POS,
	)
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, 1)
	PlanningChecklistHarness.assert_eq_int(
		failures, "bash/phase5/ap_after",
		projected.ability.points_left, 0,
	)
	var ability: AbilityData = _bash_ability(fix)
	PlanningChecklistHarness.assert_red_contract(
		failures, "bash/phase5/red_off_0ap", fix, ability, false,
	)
	# Run-only commit regression (F5 paint/promote path).
	var fix_run: Dictionary = PlanningChecklistHarness.wire_bash_board()
	fix_run.director.auto_run = true
	PlanningChecklistHarness.set_knight_pools(fix_run, 1, 0)
	PlanningChecklistHarness.select_ability(fix_run, PlanningChecklistHarness.SHIELD_BASH_ID)
	var run_dest: Vector2i = PlanningChecklistHarness.find_run_hover_tile(fix_run.board, fix_run.knight)
	if run_dest.x <= -900000:
		PlanningChecklistHarness.assert_fail(failures, "bash/phase5/run", "no run tile")
		return
	PlanningChecklistHarness.hover(fix_run, run_dest)
	var run_slots: Dictionary = PlanningChecklistHarness.commit_production(fix_run, run_dest)
	PlanningChecklistHarness.assert_true(
		failures, "bash/phase5/run_commit",
		not PlanningChecklistHarness._slots_invalid(run_slots),
		"run-only commit must succeed",
	)
	var pre: Array = fix_run.director.plan_pre_move.entries
	PlanningChecklistHarness.assert_true(
		failures, "bash/phase5/run_timeline", not pre.is_empty(),
		"run commit must queue pre-move",
	)
	if not pre.is_empty() and pre[0] is TimelineAction:
		var step: TimelineAction = pre[0] as TimelineAction
		PlanningChecklistHarness.assert_true(
			failures, "bash/phase5/run_uses_run", step.uses_run,
			"timeline pre-move must be run",
		)
	PlanningChecklistHarness.assert_red_contract(
		failures, "bash/phase5/run_red_off", fix_run, _bash_ability(fix_run), false, run_dest,
	)


static func _phase6_execute(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	fix.director.auto_run = true
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.SHIELD_BASH_ID)
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.ENEMY_POS)
	var push_to: Vector2i = PlanningChecklistHarness.push_destination(fix, 2)
	PlanningChecklistHarness.commit_production(fix, PlanningChecklistHarness.ENEMY_POS)
	var result: SimResult = PlanningChecklistHarness.simulate_committed(fix.director)
	var knight: UnitState = result.final_state.get_unit_by_id(1)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "bash/phase6/knight",
		knight.position if knight != null else Vector2i(-1, -1),
		PlanningChecklistHarness.BASH_APPROACH,
	)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "bash/phase6/enemy_push",
		enemy.position if enemy != null else Vector2i(-1, -1),
		push_to,
	)
	PlanningChecklistHarness.assert_player_turn_ap_spent(
		failures, "bash/phase6/ap_spent", fix.director, 1, 0,
	)


static func _phase7_premove_then_bash(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	fix.director.auto_run = true
	var walk_only: Vector2i = Vector2i(5, 5)
	fix.director.plan_pre_move.entries.append(
		TimelineAction.make_move(
			1, walk_only, -1, [], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	PlanningChecklistHarness.assert_true(
		failures, "bash/phase7/walk_planned",
		not fix.director.plan_pre_move.entries.is_empty(),
		"premove must be on timeline before bash select",
	)
	var bash_idx: int = PlanningChecklistHarness.ability_index(
		fix.knight, PlanningChecklistHarness.SHIELD_BASH_ID,
	)
	fix.director.selected_ability_index = bash_idx
	PlanningChecklistHarness.refresh_attack_hover(fix, PlanningChecklistHarness.ENEMY_POS)
	var ability: AbilityData = _bash_ability(fix)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "bash/phase7/stand_anchor",
		fix.input.action_range_intent_stand_cell(1),
		walk_only,
	)
	PlanningChecklistHarness.assert_red_contract(
		failures, "bash/phase7/red_at_approach", fix, ability, true,
		walk_only,
	)
