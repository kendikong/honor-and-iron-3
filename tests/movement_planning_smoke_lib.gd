class_name MovementPlanningSmokeLib
extends RefCounted

## Production planning commit smoke for movement / premove skills (all classes).

const _Fixture := preload("res://tests/class_planning_checklist_harness.gd")
const _Checklist := preload("res://tests/planning_checklist_harness.gd")
const _Drag := preload("res://tests/planning_drag_e2e_harness.gd")
const _MovementTimeline := preload("res://tests/movement_timeline_qa_harness.gd")
const _BruiserHarness := preload("res://tests/bruiser_qa_harness.gd")


static func run_entry(failures: Array[String], entry: Dictionary) -> void:
	var class_id: StringName = entry.get("class_id", &"") as StringName
	var factory_id: StringName = entry.get("factory_id", &"") as StringName
	if class_id == &"" or factory_id == &"":
		return
	var mode: String = String(entry.get("mode", "click"))
	match mode:
		"premove":
			run_premove_planner_smoke(
				failures,
				class_id,
				factory_id,
				String(entry.get("tag", factory_id)),
				entry.get("actor_pos", Vector2i.ZERO),
				entry.get("commit_cell", Vector2i.ZERO),
				entry.get("enemy_pos", Vector2i(-999999, -999999)),
				String(entry.get("module_assert", "")),
			)
		"ally":
			run_ally_smoke(
				failures,
				class_id,
				factory_id,
				String(entry.get("tag", factory_id)),
				entry.get("actor_pos", Vector2i.ZERO),
				entry.get("ally_pos", Vector2i.ZERO),
				entry.get("commit_cell", Vector2i.ZERO),
				bool(entry.get("verify_no_jump", true)),
			)
		"awaiting":
			run_awaiting_smoke(
				failures,
				class_id,
				factory_id,
				String(entry.get("tag", factory_id)),
				entry.get("actor_pos", Vector2i.ZERO),
				entry.get("arm_cell", entry.get("actor_pos", Vector2i.ZERO)),
				entry.get("commit_cell", Vector2i.ZERO),
				entry.get("enemy_pos", Vector2i(-1, -1)),
				bool(entry.get("verify_no_jump", true)),
				entry.get("premove_cell", Vector2i(-999999, -999999)),
				entry.get("wall_cells", []),
				entry.get("drag_route", []),
				String(entry.get("module_assert", "")),
				entry.get("ally_pos", Vector2i(-1, -1)),
				bool(entry.get("arm_on_ally", false)),
				entry.get("postmove_cell", Vector2i(-999999, -999999)),
				bool(entry.get("arm_on_stand", true)),
			)
		_:
			run_commit_smoke(
				failures,
				class_id,
				factory_id,
				String(entry.get("tag", factory_id)),
				entry.get("commit_cell", Vector2i.ZERO),
				entry.get("actor_pos", Vector2i.ZERO),
				entry.get("enemy_pos", Vector2i(-999999, -999999)),
				bool(entry.get("verify_no_jump", true)),
				entry.get("premove_cell", Vector2i(-999999, -999999)),
				entry.get("ally_pos", Vector2i(-1, -1)),
				entry.get("postmove_cell", Vector2i(-999999, -999999)),
				String(entry.get("module_assert", "")),
				bool(entry.get("assert_skill_modules", false)),
			)


static func run_premove_planner_smoke(
	failures: Array[String],
	class_id: StringName,
	ability_id: StringName,
	tag: String,
	actor_pos: Vector2i,
	commit_cell: Vector2i,
	enemy_pos: Vector2i = Vector2i(-999999, -999999),
	module_assert: String = "",
) -> void:
	_Drag.cleanup_all()
	var enemy: Vector2i = enemy_pos if enemy_pos.x > -999000 else Vector2i(-1, -1)
	var fix: Dictionary = _Fixture.wire_board(
		class_id, actor_pos, enemy, Vector2i(-1, -1), ability_id,
	)
	if fix.is_empty():
		_fail(failures, "%s/planning/fixture" % tag, "failed to wire PRE_MOVE planning board")
		return
	fix.director.auto_run = true
	var idx: int = _Checklist.select_ability(fix, ability_id)
	_assert_true(
		failures, "%s/planning/select" % tag,
		idx >= 0,
		"%s must be selectable" % ability_id,
	)
	if idx < 0:
		return
	var ability: AbilityData = _ability_on_actor(fix, ability_id)
	_assert_true(
		failures, "%s/planning/premove_kind" % tag,
		ability != null and ability.is_pre_move_planner(),
		"%s must be a PRE_MOVE planner skill" % ability_id,
	)
	_Checklist.hover(fix, commit_cell)
	var hover_slots: Dictionary = _Checklist.slots_for_hover(fix, commit_cell)
	if _Checklist._slots_invalid(hover_slots):
		_fail(
			failures, "%s/planning/valid_slots" % tag,
			"invalid commit slots at %s for %s" % [commit_cell, ability_id],
		)
		return
	_Checklist.assert_slots_match_preview_commit(
		failures, "%s/planning/hover_click_parity" % tag, fix, commit_cell,
	)
	var unit_id: int = fix.director.selected_unit_id
	var commit_slots: Dictionary = _Checklist.commit_production(fix, commit_cell)
	_assert_true(
		failures, "%s/planning/commit" % tag,
		not _Checklist._slots_invalid(commit_slots),
		"PRE_MOVE commit must succeed at %s" % commit_cell,
	)
	_assert_true(
		failures, "%s/planning/pre_slot_built" % tag,
		not (commit_slots.get("pre", []) as Array).is_empty(),
		"PRE_MOVE commit slots must include a pre-move column entry",
	)
	if ability != null:
		_Checklist.assert_skill_timeline_columns(
			failures, "%s/planning/timeline" % tag,
			fix.director, unit_id, ability, {},
		)
	_dispatch_module_assert(
		failures, fix, tag, module_assert, commit_cell,
		Vector2i(-999999, -999999), Vector2i(-999999, -999999),
	)


static func run_commit_smoke(
	failures: Array[String],
	class_id: StringName,
	ability_id: StringName,
	tag: String,
	commit_cell: Vector2i,
	actor_pos: Vector2i,
	enemy_pos: Vector2i = Vector2i(-999999, -999999),
	verify_no_jump: bool = true,
	premove_cell: Vector2i = Vector2i(-999999, -999999),
	ally_pos: Vector2i = Vector2i(-1, -1),
	postmove_cell: Vector2i = Vector2i(-999999, -999999),
	module_assert: String = "",
	assert_skill_modules: bool = false,
) -> void:
	_Drag.cleanup_all()
	var enemy: Vector2i = enemy_pos if enemy_pos.x > -999000 else Vector2i(-1, -1)
	var fix: Dictionary = _Fixture.wire_board(
		class_id, actor_pos, enemy, ally_pos, ability_id,
	)
	if fix.is_empty():
		_fail(failures, "%s/planning/fixture" % tag, "failed to wire planning board")
		return
	_apply_engineer_movement_setup(fix, ability_id)
	fix.director.auto_run = true
	var ability: AbilityData = _ability_on_actor(fix, ability_id)
	var resolved_premove: Vector2i = _MovementTimeline.resolve_premove_run_cell(
		ability, actor_pos, commit_cell, premove_cell,
	)
	_MovementTimeline.commit_run_premove_headless(
		failures, fix, ability, resolved_premove, tag,
	)
	var idx: int = _Checklist.select_ability(fix, ability_id)
	_assert_true(
		failures, "%s/planning/select" % tag,
		idx >= 0,
		"%s must be selectable" % ability_id,
	)
	if idx < 0:
		return
	_assert_true(
		failures, "%s/planning/overlay" % tag,
		fix.get("overlay") != null,
		"planning overlay must wire after ability select",
	)
	_Checklist.hover(fix, commit_cell)
	var hover_slots: Dictionary = _Checklist.slots_for_hover(fix, commit_cell)
	if _Checklist._slots_invalid(hover_slots):
		_fail(
			failures, "%s/planning/valid_slots" % tag,
			"invalid commit slots at %s for %s" % [commit_cell, ability_id],
		)
		return
	_Checklist.assert_slots_match_preview_commit(
		failures, "%s/planning/hover_click_parity" % tag, fix, commit_cell,
	)
	if verify_no_jump:
		_Checklist.assert_commit_no_jump(
			failures, "%s/planning/no_jump" % tag, fix, commit_cell,
		)
	else:
		_Checklist.assert_planning_timeline_after_commit(
			failures, "%s/planning/timeline_columns" % tag, fix, commit_cell,
		)
	if postmove_cell.x > -999000:
		_restore_movement_mp(fix, 2)
		_MovementTimeline.commit_run_postmove_headless(
			failures, fix, ability, postmove_cell, tag,
		)
	if assert_skill_modules and module_assert.is_empty():
		module_assert = "charge_strike"
	_dispatch_module_assert(
		failures, fix, tag, module_assert, commit_cell, postmove_cell, resolved_premove,
	)


static func run_ally_smoke(
	failures: Array[String],
	class_id: StringName,
	ability_id: StringName,
	tag: String,
	actor_pos: Vector2i,
	ally_pos: Vector2i,
	commit_cell: Vector2i,
	verify_no_jump: bool = true,
) -> void:
	_Drag.cleanup_all()
	var fix: Dictionary = _Fixture.wire_board(
		class_id, actor_pos, Vector2i(-1, -1), ally_pos, ability_id,
	)
	if fix.is_empty():
		_fail(failures, "%s/planning/fixture" % tag, "failed to wire ally planning board")
		return
	fix.director.auto_run = true
	var idx: int = _Checklist.select_ability(fix, ability_id)
	_assert_true(failures, "%s/planning/select" % tag, idx >= 0)
	if idx < 0:
		return
	_Checklist.hover(fix, commit_cell)
	var hover_slots: Dictionary = _Checklist.slots_for_hover(fix, commit_cell)
	if _Checklist._slots_invalid(hover_slots):
		_fail(failures, "%s/planning/valid_slots" % tag, "invalid ally commit slots at %s" % commit_cell)
		return
	_Checklist.assert_slots_match_preview_commit(
		failures, "%s/planning/hover_click_parity" % tag, fix, commit_cell,
	)
	if verify_no_jump:
		_Checklist.assert_commit_no_jump(
			failures, "%s/planning/no_jump" % tag, fix, commit_cell,
		)
	else:
		_Checklist.assert_planning_timeline_after_commit(
			failures, "%s/planning/timeline_columns" % tag, fix, commit_cell,
		)


static func run_awaiting_smoke(
	failures: Array[String],
	class_id: StringName,
	ability_id: StringName,
	tag: String,
	actor_pos: Vector2i,
	arm_cell: Vector2i,
	commit_cell: Vector2i,
	enemy_pos: Vector2i = Vector2i(-1, -1),
	verify_no_jump: bool = true,
	premove_cell: Vector2i = Vector2i(-999999, -999999),
	wall_cells: Array = [],
	drag_route: Array = [],
	module_assert: String = "",
	ally_pos: Vector2i = Vector2i(-1, -1),
	arm_on_ally: bool = false,
	postmove_cell: Vector2i = Vector2i(-999999, -999999),
	arm_on_stand: bool = true,
) -> void:
	_Drag.cleanup_all()
	var fix: Dictionary = _Fixture.wire_board(
		class_id, actor_pos, enemy_pos, ally_pos, ability_id,
	)
	if fix.is_empty():
		_fail(failures, "%s/planning/fixture" % tag, "failed to wire awaiting planning board")
		return
	_apply_wall_cells(fix, wall_cells)
	fix.director.auto_run = true
	var ability: AbilityData = _ability_on_actor(fix, ability_id)
	var resolved_premove: Vector2i = _MovementTimeline.resolve_premove_run_cell(
		ability, actor_pos, commit_cell, premove_cell,
	)
	if arm_on_ally or not drag_route.is_empty():
		resolved_premove = Vector2i(-999999, -999999)
	_MovementTimeline.commit_run_premove_headless(
		failures, fix, ability, resolved_premove, tag,
	)
	var idx: int = _Checklist.select_ability(fix, ability_id)
	_assert_true(failures, "%s/planning/select" % tag, idx >= 0)
	if idx < 0:
		return
	var director: CombatDirector = fix.director as CombatDirector
	var unit_id: int = director.selected_unit_id if director != null else -1
	var stand: Vector2i = _MovementTimeline.latest_stand_cell(director, unit_id)
	if arm_on_ally and ally_pos.x >= 0:
		arm_cell = ally_pos
	elif arm_on_stand and stand.x > -900000:
		arm_cell = stand
	_Checklist.hover(fix, arm_cell)
	_Checklist.flush_planning(fix)
	var input: CombatPlanningInput = fix.input as CombatPlanningInput
	if input != null and not input.awaiting_targeting_active():
		var arm_slots: Dictionary = _Checklist.slots_for_hover(fix, arm_cell)
		if _Checklist._slots_invalid(arm_slots):
			_fail(
				failures, "%s/planning/arm" % tag,
				"first click must arm awaiting flow at %s" % arm_cell,
			)
			return
		if not _Checklist.commit_slots_production(fix, arm_slots):
			_fail(
				failures, "%s/planning/arm" % tag,
				"awaiting arm commit failed at %s" % arm_cell,
			)
			return
		_Checklist.flush_planning(fix)
	_assert_true(
		failures, "%s/planning/arm" % tag,
		input != null and input.awaiting_targeting_active(),
		"awaiting flow must be active after arm at %s" % arm_cell,
	)
	if input == null or not input.awaiting_targeting_active():
		return
	if not drag_route.is_empty():
		_paint_drag_route(fix, drag_route, commit_cell)
	else:
		_Checklist.flush_planning(fix)
		_Checklist.hover(fix, commit_cell)
	var hover_slots: Dictionary = (
		_Checklist.slots_for_painted_hover(fix, commit_cell)
		if not drag_route.is_empty()
		else _Checklist.slots_for_hover(fix, commit_cell)
	)
	if _Checklist._slots_invalid(hover_slots):
		_fail(
			failures, "%s/planning/valid_slots" % tag,
			"invalid commit slots at %s for awaiting finalize (%s)"
			% [commit_cell, str(hover_slots.get("invalid", "unknown"))],
		)
		return
	_Checklist.assert_slots_match_preview_commit(
		failures, "%s/planning/hover_click_parity" % tag, fix, commit_cell,
	)
	if verify_no_jump:
		_Checklist.assert_commit_no_jump(
			failures, "%s/planning/no_jump" % tag, fix, commit_cell,
		)
	else:
		if not drag_route.is_empty():
			var finalize_slots: Dictionary = _Checklist.slots_for_painted_hover(
				fix, commit_cell,
			)
			_assert_true(
				failures,
				"%s/planning/timeline_columns" % tag,
				not _Checklist._slots_invalid(finalize_slots),
				"commit must succeed",
			)
			if _Checklist._slots_invalid(finalize_slots):
				return
			_assert_true(
				failures,
				"%s/planning/timeline_columns" % tag,
				_Checklist.commit_slots_production(fix, finalize_slots),
				"commit production failed (%s)" % str(finalize_slots.get("invalid", "")),
			)
			_Checklist.flush_planning(fix)
			_Checklist.assert_skill_timeline_columns(
				failures,
				"%s/planning/timeline_columns" % tag,
				fix.director,
				unit_id,
				ability,
				{},
			)
		else:
			_Checklist.assert_planning_timeline_after_commit(
				failures, "%s/planning/timeline_columns" % tag, fix, commit_cell,
			)
	if postmove_cell.x > -999000:
		_MovementTimeline.commit_run_postmove_headless(
			failures, fix, ability, postmove_cell, tag,
		)
	if not verify_no_jump:
		_MovementTimeline.assert_pre_or_post_leg_if_needed(
			failures, "%s/planning/timeline_columns" % tag, fix.director, unit_id, ability,
		)
	_dispatch_module_assert(
		failures, fix, tag, module_assert, commit_cell,
		Vector2i(-999999, -999999), resolved_premove,
	)


static func _dispatch_module_assert(
	failures: Array[String],
	fix: Dictionary,
	tag: String,
	module_assert: String,
	commit_cell: Vector2i,
	postmove_cell: Vector2i,
	premove_cell: Vector2i,
) -> void:
	if module_assert.is_empty():
		return
	match module_assert:
		"charge_strike":
			_assert_charge_strike_modules(
				failures, fix, tag, commit_cell, postmove_cell, premove_cell,
			)
		"violent_collision":
			_assert_violent_collision_modules(failures, fix, tag, commit_cell)
		"belly_flop":
			_assert_belly_flop_modules(failures, fix, tag, commit_cell)
		"breaching_dash":
			_assert_breaching_dash_modules(failures, fix, tag, commit_cell)
		"archer_sidestep":
			_assert_archer_sidestep_modules(failures, fix, tag, commit_cell)
		_:
			_fail(failures, "%s/modules/unknown" % tag, "unknown module_assert %s" % module_assert)


static func _paint_drag_route(fix: Dictionary, route: Array, dest: Vector2i) -> void:
	var input: CombatPlanningInput = fix.input as CombatPlanningInput
	var director: CombatDirector = fix.director as CombatDirector
	if input == null or director == null:
		return
	var unit_id: int = director.selected_unit_id
	input._drag_unit_id = unit_id
	input._drag_unit_was_selected = true
	var wps: Array[Vector2i] = []
	for raw: Variant in route:
		wps.append(raw as Vector2i)
	input._drag_route = wps
	input._drag_last_free = dest
	input.dragging = true
	_Checklist.hover(fix, dest)
	_Checklist.flush_planning(fix)


static func _ability_on_actor(fix: Dictionary, ability_id: StringName) -> AbilityData:
	var actor: UnitState = fix.get("actor", null) as UnitState
	if actor == null:
		return null
	for ab: AbilityData in actor.active_abilities:
		if ab != null and ab.id == ability_id:
			return ab
	return null


static func _apply_wall_cells(fix: Dictionary, wall_cells: Array) -> void:
	if wall_cells.is_empty():
		return
	for raw: Variant in wall_cells:
		var coord: Vector2i = raw as Vector2i
		var board: BoardState = fix.board as BoardState
		if board == null:
			continue
		board.tiles[coord] = TileState.create(coord, DataLibrary.get_terrain(&"wall"))
		var director: CombatDirector = fix.director as CombatDirector
		if director != null and director.base_board != null:
			director.base_board.tiles[coord] = TileState.create(coord, DataLibrary.get_terrain(&"wall"))
		if director != null and director.projected_state != null:
			director.projected_state.tiles[coord] = TileState.create(
				coord, DataLibrary.get_terrain(&"wall"),
			)


static func _assert_true(
	failures: Array[String], tag: String, condition: bool, message: String = "",
) -> void:
	if not condition:
		_fail(failures, tag, message if message != "" else "assertion failed")


static func _fail(failures: Array[String], tag: String, message: String) -> void:
	failures.append("%s: %s" % [tag, message])


static func _restore_movement_mp(fix: Dictionary, mp_left: int) -> void:
	var director: CombatDirector = fix.director as CombatDirector
	if director == null:
		return
	var unit_id: int = director.selected_unit_id
	for board: BoardState in [director.base_board, director.board, director.projected_state]:
		if board == null:
			continue
		var unit: UnitState = board.get_unit_by_id(unit_id)
		if unit == null:
			continue
		unit.movement.points_left = mp_left
		unit.movement.max_points = maxi(mp_left, unit.movement.max_points)


static func _assert_charge_strike_modules(
	failures: Array[String],
	fix: Dictionary,
	tag: String,
	skill_target: Vector2i,
	postmove_cell: Vector2i,
	premove_cell: Vector2i = Vector2i(-999999, -999999),
) -> void:
	const ENEMY_ID := 2
	var director: CombatDirector = fix.director as CombatDirector
	var unit_id: int = director.selected_unit_id
	var action_entries: Array = director.plan_action.entries
	_assert_true(
		failures,
		"%s/modules/action_committed" % tag,
		not action_entries.is_empty(),
		"Charge Strike must commit an ACTION timeline entry",
	)
	if not action_entries.is_empty():
		var action: TimelineAction = action_entries[0] as TimelineAction
		var move_dest: Vector2i = AbilitySystem.module_target_coord(action, 0)
		var strike_dest: Vector2i = AbilitySystem.module_target_coord(action, 1)
		var expected_land: Vector2i = Vector2i(2, 3)
		if skill_target == Vector2i(4, 3):
			expected_land = Vector2i(3, 3)
		elif skill_target == Vector2i(3, 3):
			expected_land = Vector2i(2, 3)
		_assert_true(
			failures,
			"%s/modules/target" % tag,
			action != null and move_dest == expected_land and strike_dest == skill_target,
			"Charge Strike MOVE dest must be %s and DAMAGE dest must be %s (move=%s strike=%s)"
			% [expected_land, skill_target, move_dest, strike_dest],
		)
	var start_board: BoardState = director.turn_start_board
	if start_board == null:
		start_board = fix.board as BoardState
	var enemy_hp_before: int = _BruiserHarness.unit_hp(start_board, ENEMY_ID)
	var result: SimResult = _Checklist.simulate_committed(director)
	var bruiser: UnitState = result.final_state.get_unit_by_id(unit_id)
	var enemy_unit: UnitState = result.final_state.get_unit_by_id(ENEMY_ID)
	_assert_true(
		failures,
		"%s/modules/moved" % tag,
		_BruiserHarness.events_actor_moved(result.events, unit_id),
		"Charge Strike MOVE module must relocate the bruiser",
	)
	_assert_true(
		failures,
		"%s/modules/pushed" % tag,
		_BruiserHarness.event_push_distance(result.events, ENEMY_ID) >= 1,
		"Charge Strike PUSH module must displace the enemy",
	)
	var dmg: int = enemy_hp_before - _BruiserHarness.unit_hp(result.final_state, ENEMY_ID)
	_assert_true(
		failures,
		"%s/modules/damage" % tag,
		dmg > 0,
		"Charge Strike DAMAGE module must reduce enemy HP (dealt %d)" % dmg,
	)
	var expected_after_skill: Vector2i = Vector2i(2, 3)
	var expected_enemy: Vector2i = Vector2i(4, 3)
	if skill_target == Vector2i(4, 3):
		expected_after_skill = Vector2i(3, 3)
		expected_enemy = Vector2i(5, 3)
	elif skill_target == Vector2i(3, 3):
		expected_after_skill = Vector2i(2, 3)
		expected_enemy = Vector2i(4, 3)
	var expected_bruiser_pos: Vector2i = (
		postmove_cell if postmove_cell.x > -999000 else expected_after_skill
	)
	_Checklist.assert_eq_cell(
		failures,
		"%s/modules/final_pos" % tag,
		bruiser.position if bruiser != null else Vector2i(-999999, -999999),
		expected_bruiser_pos,
	)
	_Checklist.assert_eq_cell(
		failures,
		"%s/modules/enemy_pos" % tag,
		enemy_unit.position if enemy_unit != null else Vector2i(-999999, -999999),
		expected_enemy,
	)


static func _assert_violent_collision_modules(
	failures: Array[String],
	fix: Dictionary,
	tag: String,
	commit_cell: Vector2i,
) -> void:
	const ENEMY_ID := 2
	var director: CombatDirector = fix.director as CombatDirector
	var unit_id: int = director.selected_unit_id
	var result: SimResult = _Checklist.simulate_committed(director)
	var bruiser: UnitState = result.final_state.get_unit_by_id(unit_id)
	_assert_true(
		failures, "%s/modules/dash" % tag,
		bruiser != null and bruiser.position == commit_cell,
		"Violent Collision DASH must end at committed tile %s" % commit_cell,
	)
	_assert_true(
		failures, "%s/modules/moved" % tag,
		_BruiserHarness.events_actor_moved(result.events, unit_id),
		"Violent Collision must emit actor movement events",
	)
	var enemy: UnitState = result.final_state.get_unit_by_id(ENEMY_ID)
	_assert_true(
		failures, "%s/modules/bulldoze" % tag,
		enemy != null and _BruiserHarness.event_push_distance(result.events, ENEMY_ID) >= 1,
		"Violent Collision bulldoze must PUSH the enemy along the dash line",
	)


static func _assert_belly_flop_modules(
	failures: Array[String],
	fix: Dictionary,
	tag: String,
	commit_cell: Vector2i,
) -> void:
	const ENEMY_ID := 2
	var director: CombatDirector = fix.director as CombatDirector
	var unit_id: int = director.selected_unit_id
	var ability_action: TimelineAction = null
	for entry: Variant in director.get_player_plan().entries:
		if entry is TimelineAction and (entry as TimelineAction).type == GameEnums.ActionType.ABILITY:
			ability_action = entry as TimelineAction
			break
	_assert_true(
		failures, "%s/modules/action_committed" % tag,
		ability_action != null,
		"Belly Flop must commit an ACTION timeline entry",
	)
	if ability_action == null:
		return
	var start_board: BoardState = director.turn_start_board
	if start_board == null:
		start_board = director.base_board
	if start_board == null:
		start_board = fix.board as BoardState
	var enemy_hp_before: int = _BruiserHarness.unit_hp(start_board, ENEMY_ID)
	var result: SimResult = _Checklist.simulate_committed(director)
	var bruiser: UnitState = result.final_state.get_unit_by_id(unit_id)
	_assert_true(
		failures, "%s/modules/teleport" % tag,
		bruiser != null and bruiser.position == commit_cell,
		"Belly Flop JUMP must land on committed tile %s" % commit_cell,
	)
	# Damage modules require a real teleport hop; oracle from turn-start (Bible layout).
	var oracle_board: BoardState = start_board.clone()
	oracle_board.intents = []
	var oracle_action: TimelineAction = ability_action.clone()
	oracle_action.awaiting_target = false
	oracle_action.awaiting_module_index = -1
	var oracle_plan := Timeline.new()
	oracle_plan.add(oracle_action)
	var oracle_events: Array[SimEvent] = []
	Simulator.simulate_player_turn(oracle_board, oracle_plan, oracle_events)
	var oracle_dmg: int = maxi(
		enemy_hp_before - _BruiserHarness.unit_hp(oracle_board, ENEMY_ID),
		_BruiserHarness.sum_unit_hp_damage_events(oracle_events, ENEMY_ID),
	)
	var damaged_adjacent: bool = oracle_dmg > 0
	if not damaged_adjacent:
		for e: Variant in oracle_events:
			if e is SimEvent and e.type == GameEnums.SimEventType.UNIT_DAMAGED:
				if int(e.data.get("unit", -1)) == ENEMY_ID:
					damaged_adjacent = true
					break
	_assert_true(
		failures, "%s/modules/damage" % tag,
		damaged_adjacent,
		"Belly Flop DAMAGE module must reduce enemy HP (dealt %d)" % oracle_dmg,
	)


static func _assert_breaching_dash_modules(
	failures: Array[String],
	fix: Dictionary,
	tag: String,
	commit_cell: Vector2i,
) -> void:
	var director: CombatDirector = fix.director as CombatDirector
	var unit_id: int = director.selected_unit_id
	var result: SimResult = _Checklist.simulate_committed(director)
	var bruiser: UnitState = result.final_state.get_unit_by_id(unit_id)
	_assert_true(
		failures, "%s/modules/dash" % tag,
		bruiser != null and bruiser.position == commit_cell,
		"Breaching Dash must end at committed tile %s" % commit_cell,
	)
	_assert_true(
		failures, "%s/modules/moved" % tag,
		_BruiserHarness.events_actor_moved(result.events, unit_id),
		"Breaching Dash must emit actor movement events",
	)


static func _assert_archer_sidestep_modules(
	failures: Array[String],
	fix: Dictionary,
	tag: String,
	commit_cell: Vector2i,
) -> void:
	var director: CombatDirector = fix.director as CombatDirector
	var unit_id: int = director.selected_unit_id
	var result: SimResult = _Checklist.simulate_committed(director)
	var archer: UnitState = result.final_state.get_unit_by_id(unit_id)
	_Checklist.assert_eq_cell(
		failures, "%s/modules/final_pos" % tag,
		archer.position if archer != null else Vector2i(-999999, -999999),
		commit_cell,
	)
	_assert_true(
		failures, "%s/modules/moved" % tag,
		_BruiserHarness.events_actor_moved(result.events, unit_id),
		"Sidestep MOVE module must relocate the archer",
	)


static func _apply_engineer_movement_setup(fix: Dictionary, ability_id: StringName) -> void:
	if ability_id != &"engineer_recall":
		return
	var actor: UnitState = fix.get("actor")
	var board: BoardState = fix.get("board")
	if actor == null or board == null:
		return
	var construct := UnitState.create(
		90, DataLibrary.get_unit(&"construct_turret"), GameEnums.Team.PLAYER, Vector2i(4, 3),
	)
	construct.passive_flags["engineer_owner_id"] = actor.id
	construct.passive_flags["engineer_construct_kind"] = &"construct_turret"
	board.add_unit(construct)
	GridSystem.set_occupant(board, construct.position, construct.id)
	fix.director.base_board = board.clone()
	fix.director.projected_state = board.clone()
