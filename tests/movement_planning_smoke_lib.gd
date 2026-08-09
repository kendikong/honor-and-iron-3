class_name MovementPlanningSmokeLib
extends RefCounted

## Production planning commit smoke for movement / premove skills (all classes).

const _Fixture := preload("res://tests/class_planning_checklist_harness.gd")
const _Checklist := preload("res://tests/planning_checklist_harness.gd")
const _Drag := preload("res://tests/planning_drag_e2e_harness.gd")
const _MovementTimeline := preload("res://tests/movement_timeline_qa_harness.gd")


static func run_entry(failures: Array[String], entry: Dictionary) -> void:
	var class_id: StringName = entry.get("class_id", &"") as StringName
	var factory_id: StringName = entry.get("factory_id", &"") as StringName
	if class_id == &"" or factory_id == &"":
		return
	var mode: String = String(entry.get("mode", "click"))
	match mode:
		"ally":
			run_ally_smoke(
				failures,
				class_id,
				factory_id,
				String(entry.get("tag", factory_id)),
				entry.get("actor_pos", Vector2i.ZERO),
				entry.get("ally_pos", Vector2i.ZERO),
				entry.get("commit_cell", Vector2i.ZERO),
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
) -> void:
	_Drag.cleanup_all()
	var enemy: Vector2i = enemy_pos if enemy_pos.x > -999000 else Vector2i(-1, -1)
	var fix: Dictionary = _Fixture.wire_board(
		class_id, actor_pos, enemy, ally_pos, ability_id,
	)
	if fix.is_empty():
		_fail(failures, "%s/planning/fixture" % tag, "failed to wire planning board")
		return
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


static func run_ally_smoke(
	failures: Array[String],
	class_id: StringName,
	ability_id: StringName,
	tag: String,
	actor_pos: Vector2i,
	ally_pos: Vector2i,
	commit_cell: Vector2i,
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
	_Checklist.assert_commit_no_jump(
		failures, "%s/planning/no_jump" % tag, fix, commit_cell,
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
) -> void:
	_Drag.cleanup_all()
	var fix: Dictionary = _Fixture.wire_board(
		class_id, actor_pos, enemy_pos, Vector2i(-1, -1), ability_id,
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
	if stand.x > -900000:
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
			"invalid commit slots at %s for awaiting finalize" % commit_cell,
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
