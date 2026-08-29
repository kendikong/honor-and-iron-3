class_name MoveSkillHoverMatrixHarness
extends RefCounted

## Dense multi-hover overlay contract for MOVE-module skills (Trampling Advance, Charge Strike).
## Every probe cell checks red tiles, blue tiles, preview_paths, drawn move route, and arrows.

const ORBIT_RADIUS := 3


static func dense_hover_cells(
	board: BoardState,
	centers: Array[Vector2i],
	radius: int = ORBIT_RADIUS,
	include_centers: bool = true,
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen: Dictionary = {}
	for center: Vector2i in centers:
		for cell: Vector2i in _orbit_cells(board, center, radius, include_centers):
			if seen.has(cell):
				continue
			seen[cell] = true
			out.append(cell)
		for diag: Vector2i in _diagonal_neighbors(board, center):
			if seen.has(diag):
				continue
			seen[diag] = true
			out.append(diag)
	return out


static func probe_hover_sweep(
	failures: Array[String],
	fix: Dictionary,
	config: Dictionary,
) -> void:
	var cells: Array[Vector2i] = config.get("hover_cells", []) as Array[Vector2i]
	if cells.is_empty():
		failures.append("%s: hover sweep has no cells" % config.get("label_prefix", "matrix"))
		return
	var previous: Vector2i = config.get("sweep_from", cells[0]) as Vector2i
	for cell: Vector2i in cells:
		probe_hover_cell(failures, fix, config, cell, previous)
		previous = cell


static func probe_hover_cell(
	failures: Array[String],
	fix: Dictionary,
	config: Dictionary,
	cell: Vector2i,
	previous: Vector2i,
) -> void:
	_apply_hover_input(fix, config, cell, previous)
	var probe_label: String = _probe_label(config, cell)
	assert_hover_layers(failures, fix, probe_label, config, cell)


static func assert_hover_layers(
	failures: Array[String],
	fix: Dictionary,
	probe_label: String,
	config: Dictionary,
	hover_cell: Vector2i,
) -> void:
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	var actor: UnitState = config.get("actor", null) as UnitState
	if actor == null or overlay == null or input == null:
		failures.append("%s: missing actor or overlay" % probe_label)
		return
	if bool(config.get("check_empty_drag_route", false)) and not bool(config.get("update_drag", false)):
		if not input.get_drag_route().is_empty():
			failures.append(
				"%s: selection-hover must not accumulate drag route %s"
				% [probe_label, str(input.get_drag_route())],
			)
	var ability: AbilityData = config.get("ability", null) as AbilityData
	var stand_cell: Vector2i = config.get("stand_cell", actor.position) as Vector2i
	if bool(config.get("expect_red", false)):
		PlanningChecklistHarness.assert_red_contract(
			failures,
			probe_label + "/red",
			fix,
			ability,
			true,
			stand_cell,
			actor.id,
		)
	else:
		PlanningChecklistHarness.assert_red_contract(
			failures,
			probe_label + "/red_off",
			fix,
			ability,
			false,
			Vector2i(-999999, -999999),
			actor.id,
		)
	_assert_blue_contract(
		failures,
		probe_label + "/blue",
		fix,
		bool(config.get("expect_blue", false)),
	)
	_assert_move_preview_layers(
		failures,
		probe_label,
		fix,
		overlay,
		input,
		actor,
		hover_cell,
		stand_cell,
		config,
	)
	_assert_targeting_arrow(
		failures,
		probe_label + "/arrow",
		overlay,
		config,
		hover_cell,
	)


static func _apply_hover_input(
	fix: Dictionary,
	config: Dictionary,
	cell: Vector2i,
	previous: Vector2i,
) -> void:
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	PlanningChecklistHarness.sweep_to_cell(fix, cell, previous)
	if bool(config.get("update_drag", false)):
		input.update_drag(fix.map_stub.grid_to_local(cell))
	input._flush_hover_heavy_sync()
	input.call("_run_ability_settled_refresh")
	PlanningChecklistHarness.flush_planning(fix)
	if overlay != null:
		overlay._flush_hover_recompute()


static func _probe_label(config: Dictionary, cell: Vector2i) -> String:
	var label_prefix: String = config.get("label_prefix", "matrix") as String
	var phase: String = config.get("phase", "unknown") as String
	return "%s/%s/%s" % [label_prefix, phase, cell]


static func probe_hover_cell_legacy(
	failures: Array[String],
	fix: Dictionary,
	config: Dictionary,
	cell: Vector2i,
	previous: Vector2i,
) -> void:
	probe_hover_cell(failures, fix, config, cell, previous)


static func _orbit_cells(
	board: BoardState,
	center: Vector2i,
	radius: int,
	include_center: bool,
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen: Dictionary = {}
	if include_center and board.is_in_bounds(center):
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


static func _diagonal_neighbors(board: BoardState, center: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for off: Vector2i in [
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]:
		var cell: Vector2i = center + off
		if board.is_in_bounds(cell):
			out.append(cell)
	return out


static func _assert_blue_contract(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	expect_show: bool,
) -> void:
	var input: CombatPlanningInput = fix.input
	var overlay_blue: Array[Vector2i] = PlanningChecklistHarness.collect_blue_tiles(fix)
	var legal: Array[Vector2i] = input._snapshot_drag_legal_move_tiles()
	overlay_blue.sort_custom(_sort_cells)
	legal.sort_custom(_sort_cells)
	if expect_show and not legal.is_empty() and overlay_blue != legal:
		failures.append(
			"%s: blue overlay %s must match legal move tiles %s"
			% [label, str(overlay_blue), str(legal)],
		)
	if not expect_show and not overlay_blue.is_empty():
		failures.append(
			"%s: blue tiles must be off, got %s" % [label, str(overlay_blue)],
		)


static func _assert_move_preview_layers(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	overlay: TacticalPlanningOverlay,
	input: CombatPlanningInput,
	actor: UnitState,
	hover_cell: Vector2i,
	stand_cell: Vector2i,
	config: Dictionary,
) -> void:
	var preview_kind: String = config.get("move_preview_kind", "none") as String
	if preview_kind == "none":
		return
	var live: CombatPlanningPreview = overlay.get_live_preview()
	var preview_path: Array = live.preview_paths.get(actor.id, []) if live != null else []
	var expected_path: Array = []
	match preview_kind:
		"corridor":
			if input._can_move_to(actor, hover_cell):
				expected_path = _expected_corridor_path(input, actor, hover_cell, stand_cell)
			else:
				expected_path = [stand_cell]
		"drag_painted":
			var painted: Array = input._drag_route.duplicate()
			if painted.size() >= 2:
				expected_path = painted
			elif input._can_move_to(actor, hover_cell):
				expected_path = _expected_corridor_path(input, actor, hover_cell, stand_cell)
			else:
				expected_path = [stand_cell]
		"fixed_route":
			expected_path = (config.get("fixed_route", []) as Array).duplicate()
		"frozen_landing":
			var landing: Vector2i = config.get("frozen_cell", stand_cell) as Vector2i
			expected_path = [landing]
		"postmove_corridor":
			var post_start: Vector2i = config.get("post_start", stand_cell) as Vector2i
			if input._can_move_to(actor, hover_cell):
				expected_path = _expected_corridor_path(input, actor, hover_cell, post_start)
			else:
				expected_path = [post_start]
		_:
			failures.append("%s: unknown move_preview_kind %s" % [label, preview_kind])
			return
	if preview_path != expected_path:
		if _preview_path_acceptable(preview_path, expected_path, hover_cell, stand_cell, input, actor):
			pass
		else:
			failures.append(
				"%s: preview_paths %s expected %s"
				% [label, str(preview_path), str(expected_path)],
			)
	var draw_route: Array = (
		overlay._interaction_move_route(actor.id, live, preview_path)
		if live != null else []
	)
	if draw_route != expected_path:
		if not _preview_path_acceptable(draw_route, expected_path, hover_cell, stand_cell, input, actor):
			failures.append(
				"%s: drawn move route %s expected %s (arrow=%s)"
				% [
					label,
					str(draw_route),
					str(expected_path),
					str(overlay.targeting_intent_arrow_cells()),
				],
			)
	var movement_route: Array = overlay._movement_hover_route_cells(actor.id)
	if bool(config.get("expect_awaiting_move_route", false)):
		if movement_route != draw_route and not draw_route.is_empty():
			failures.append(
				"%s: movement hover route %s must match draw route %s"
				% [label, str(movement_route), str(draw_route)],
			)
	for step_index: int in range(1, expected_path.size()):
		var a: Vector2i = expected_path[step_index - 1] as Vector2i
		var b: Vector2i = expected_path[step_index] as Vector2i
		if GridSystem.manhattan(a, b) != 1:
			failures.append(
				"%s: move preview contains diagonal %s -> %s in %s"
				% [label, a, b, str(expected_path)],
			)
			break
	var forbidden: Array = config.get("forbidden_path_cells", [])
	for forbidden_cell: Variant in forbidden:
		if expected_path.has(forbidden_cell):
			failures.append(
				"%s: preview path bleeds forbidden cell %s in %s"
				% [label, str(forbidden_cell), str(expected_path)],
			)
	if bool(config.get("suppress_target_arrow", false)):
		if not overlay.targeting_intent_arrow_cells().is_empty():
			failures.append(
				"%s: movement phase must not draw targeting arrow %s"
				% [label, str(overlay.targeting_intent_arrow_cells())],
			)
	if bool(config.get("check_module_stand", false)):
		var intent_stand: Vector2i = overlay._intent_stand_origin(actor)
		if intent_stand != stand_cell:
			failures.append(
				"%s: intent stand %s expected module stand %s"
				% [label, intent_stand, stand_cell],
			)


static func _preview_path_acceptable(
	actual: Array,
	expected: Array,
	hover_cell: Vector2i,
	stand_cell: Vector2i,
	input: CombatPlanningInput,
	actor: UnitState,
) -> bool:
	if actual == expected:
		return true
	if expected == [stand_cell] and actual.is_empty():
		return true
	if not input._can_move_to(actor, hover_cell) and (actual.is_empty() or actual == [stand_cell]):
		return true
	return false


static func _assert_targeting_arrow(
	failures: Array[String],
	label: String,
	overlay: TacticalPlanningOverlay,
	config: Dictionary,
	hover_cell: Vector2i,
) -> void:
	var allow_at: Variant = config.get("allow_target_arrow_at", Vector2i(-999999, -999999))
	var allow: bool = allow_at is Vector2i and (allow_at as Vector2i) == hover_cell
	var arrow_from: Vector2i = config.get("arrow_from", Vector2i(-999999, -999999)) as Vector2i
	var arrow_cells: Array[Vector2i] = overlay.targeting_intent_arrow_cells()
	if not allow:
		if not arrow_cells.is_empty():
			failures.append("%s: must not draw targeting arrow %s" % [label, str(arrow_cells)])
		return
	if arrow_cells.size() < 2:
		failures.append("%s: enemy hover must draw targeting arrow" % label)
		return
	var from_cell: Vector2i = arrow_cells[0] as Vector2i
	var to_cell: Vector2i = arrow_cells[1] as Vector2i
	if arrow_from.x > -900000 and from_cell != arrow_from:
		failures.append(
			"%s: arrow origin %s expected %s (arrow=%s)"
			% [label, from_cell, arrow_from, str(arrow_cells)],
		)
	if from_cell.x != to_cell.x and from_cell.y != to_cell.y:
		failures.append("%s: targeting arrow is diagonal %s -> %s" % [label, from_cell, to_cell])


static func _expected_corridor_path(
	input: CombatPlanningInput,
	actor: UnitState,
	cell: Vector2i,
	stand_cell: Vector2i,
) -> Array[Vector2i]:
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


static func _sort_cells(a: Vector2i, b: Vector2i) -> bool:
	if a.x == b.x:
		return a.y < b.y
	return a.x < b.x


const TrampleE2E := preload("res://tests/trampling_advance_e2e_test.gd")


static func capture_painted_leg_hover_layers(
	fix: Dictionary,
	unit: UnitState,
	hover_cell: Vector2i,
	previous: Vector2i,
) -> Dictionary:
	PlanningChecklistHarness.sweep_to_cell(fix, hover_cell, previous)
	fix.input._flush_hover_heavy_sync()
	fix.input.call("_run_ability_settled_refresh")
	PlanningChecklistHarness.flush_planning(fix)
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	var live: CombatPlanningPreview = overlay.get_live_preview() if overlay != null else null
	var preview_path: Array = live.preview_paths.get(unit.id, []) if live != null else []
	var draw_route: Array = (
		overlay._interaction_move_route(unit.id, live, preview_path)
		if live != null and overlay != null else []
	)
	return {
		"preview_paths": preview_path.duplicate(),
		"draw_route": draw_route.duplicate(),
	}


static func assert_two_leg_painted_route_equivalence(
	failures: Array[String],
	label_prefix: String,
	fix: Dictionary,
	unit: UnitState,
	painted_route: Array[Vector2i],
	orbit_cells: Array[Vector2i],
	baseline_setup: Callable,
	compare_setup: Callable,
) -> void:
	var reference_by_cell: Dictionary = {}
	baseline_setup.call(fix)
	var previous: Vector2i = painted_route[0]
	for cell: Vector2i in orbit_cells:
		reference_by_cell[cell] = capture_painted_leg_hover_layers(fix, unit, cell, previous)
		previous = cell
	compare_setup.call(fix)
	previous = painted_route[0]
	for cell: Vector2i in orbit_cells:
		var snap: Dictionary = capture_painted_leg_hover_layers(fix, unit, cell, previous)
		var baseline: Dictionary = reference_by_cell.get(cell, {}) as Dictionary
		if snap.get("preview_paths", []) != baseline.get("preview_paths", []):
			failures.append(
				"%s: preview_paths %s != baseline %s @%s"
				% [
					label_prefix,
					str(snap.get("preview_paths", [])),
					str(baseline.get("preview_paths", [])),
					cell,
				],
			)
		if snap.get("draw_route", []) != baseline.get("draw_route", []):
			failures.append(
				"%s: draw_route %s != baseline %s @%s"
				% [
					label_prefix,
					str(snap.get("draw_route", [])),
					str(baseline.get("draw_route", [])),
					cell,
				],
			)
		previous = cell
