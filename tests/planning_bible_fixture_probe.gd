extends RefCounted

## Headless probe parity for Tier 3 LIVE `_probe_cell` / `_audit_surface` contracts.


static func probe_cell(
	failures: Array[String],
	fix: Dictionary,
	unit_id: int,
	hover_cell: Vector2i,
	contract: Dictionary,
	label: String,
) -> void:
	if hover_cell == PlanningChecklistHarness.OFF_MAP_HOVER:
		PlanningChecklistHarness.select_unit(fix, unit_id)
		PlanningChecklistHarness.hover_off_map(fix)
	else:
		PlanningChecklistHarness.select_unit(fix, unit_id, hover_cell)
	PlanningChecklistHarness.flush_planning(fix)
	_audit_surface(failures, fix, unit_id, hover_cell, contract, label)


static func _audit_surface(
	failures: Array[String],
	fix: Dictionary,
	unit_id: int,
	hover_cell: Vector2i,
	contract: Dictionary,
	label: String,
) -> void:
	var input: CombatPlanningInput = fix.input
	var path: Array[Vector2i] = PlanningChecklistHarness.preview_path(fix, unit_id)
	var icon: String = input.compute_hover_action_icon(hover_cell)
	var overlay_blue: bool = _overlay_has_blue(fix)
	var overlay_red: bool = not PlanningChecklistHarness.collect_red_tiles(fix).is_empty()

	if contract.has("preview_nonempty"):
		PlanningChecklistHarness.assert_true(
			failures,
			label,
			path.size() > 0,
			"preview path empty at %s" % hover_cell,
		)
	if contract.has("path"):
		_assert_path_equals(failures, path, contract["path"] as Array, label)
	elif contract.has("path_end"):
		var min_sz: int = int(contract.get("path_min_size", 2))
		var start: Vector2i = contract.get("path_start", hover_cell) as Vector2i
		_assert_path_ends(failures, path, contract["path_end"] as Vector2i, min_sz, start, label)
	if contract.get("manhattan", false) and not path.is_empty():
		_assert_manhattan(path, failures, label)
	if contract.has("ghost_pos"):
		var ghost_pos: Vector2i = PlanningChecklistHarness.preview_unit_pos(fix, unit_id)
		PlanningChecklistHarness.assert_eq_cell(
			failures, "%s/ghost" % label, ghost_pos, contract["ghost_pos"] as Vector2i,
		)
	for glyph: Variant in contract.get("icon_has", []):
		PlanningChecklistHarness.assert_true(
			failures,
			label,
			icon.contains(glyph as String),
			"icon must contain %s, got %s" % [glyph, icon],
		)
	for glyph_n: Variant in contract.get("icon_not", []):
		PlanningChecklistHarness.assert_true(
			failures,
			label,
			not icon.contains(glyph_n as String),
			"icon must not contain %s, got %s" % [glyph_n, icon],
		)
	if contract.has("red_on"):
		var ability: AbilityData = contract.get("ability", null) as AbilityData
		var stand: Vector2i = contract.get("red_stand", hover_cell) as Vector2i
		var expect_on: bool = contract["red_on"] as bool
		PlanningChecklistHarness.assert_red_contract(
			failures,
			"%s/red" % label,
			fix,
			ability,
			expect_on,
			stand,
			unit_id,
		)
	if contract.has("red_cell"):
		var rc: Dictionary = contract["red_cell"] as Dictionary
		var ability_rc: AbilityData = contract.get("ability", null) as AbilityData
		var stand_rc: Vector2i = rc.get("stand", hover_cell) as Vector2i
		var cell_rc: Vector2i = rc["cell"] as Vector2i
		var in_range: bool = rc.get("in_range", true) as bool
		var unit: UnitState = fix.board.get_unit_by_id(unit_id)
		if ability_rc != null and unit != null:
			if in_range:
				PlanningChecklistHarness.assert_red_includes_cell(
					failures, "%s/red_cell" % label, fix, ability_rc, stand_rc, cell_rc,
				)
			else:
				PlanningChecklistHarness.assert_red_excludes_cell(
					failures, "%s/red_cell" % label, fix, ability_rc, stand_rc, cell_rc,
				)
	if contract.has("blue_any"):
		PlanningChecklistHarness.assert_true(
			failures,
			label,
			overlay_blue == contract["blue_any"],
			"overlay blue expected %s at %s" % [contract["blue_any"], hover_cell],
		)
	for blue_cell: Variant in contract.get("blue_has", []):
		_assert_move_tile_at(fix, blue_cell as Vector2i, true, "%s/blue_has_%s" % [label, blue_cell], failures)
	for blue_off: Variant in contract.get("blue_not", []):
		_assert_move_tile_at(fix, blue_off as Vector2i, false, "%s/blue_not_%s" % [label, blue_off], failures)
	if contract.has("push_dest"):
		var push_id: int = int(contract.get("push_enemy_id", 2))
		var push_dest: Vector2i = contract["push_dest"] as Vector2i
		PlanningChecklistHarness.assert_eq_cell(
			failures,
			"%s/push" % label,
			PlanningChecklistHarness.push_destination(fix, push_id),
			push_dest,
		)
	if contract.has("pull_dest"):
		var pull_id: int = int(contract.get("pull_enemy_id", 2))
		var pull_dest: Vector2i = contract["pull_dest"] as Vector2i
		PlanningChecklistHarness.assert_eq_cell(
			failures,
			"%s/pull" % label,
			PlanningChecklistHarness.push_destination(fix, pull_id),
			pull_dest,
		)
	if contract.get("tiles_only_in_bounds", false):
		_assert_overlay_tiles_in_bounds(fix, failures, label)
	if contract.get("attack_target_clear", false):
		PlanningChecklistHarness.assert_eq_int(
			failures,
			"%s/attack_target" % label,
			fix.input.hover_attack_target_id(),
			-1,
		)
	if contract.get("hover_oob", false):
		var hover_ui: Vector2i = fix.input.get_hover_tile_for_ui()
		PlanningChecklistHarness.assert_true(
			failures,
			label,
			not fix.board.is_in_bounds(hover_ui),
			"hover must be out of bounds, got %s" % hover_ui,
		)
	if contract.has("icon_is"):
		var want_icon: String = contract["icon_is"] as String
		PlanningChecklistHarness.assert_true(
			failures,
			label,
			icon == want_icon,
			"icon expected %s got %s" % [want_icon, icon],
		)
	if contract.get("slots_invalid", false):
		var hover_slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, hover_cell)
		PlanningChecklistHarness.assert_true(
			failures,
			label,
			PlanningChecklistHarness.slots_invalid(hover_slots),
			"hover slots must be invalid at %s" % hover_cell,
		)


static func assert_k4_walk_loop(
	failures: Array[String],
	fix: Dictionary,
	unit_id: int,
	bowling: AbilityData,
	stand: Vector2i,
	label: String,
) -> void:
	var input: CombatPlanningInput = fix.input
	PlanningChecklistHarness.assert_true(
		failures,
		label,
		not input.unit_move_requires_run(unit_id),
		"walk detour must not require Run at %s" % stand,
	)
	PlanningChecklistHarness.assert_eq_int(
		failures, label, input.planning_display_ap_left(unit_id), 1,
	)
	PlanningChecklistHarness.assert_true(
		failures,
		label,
		input.action_range_visible_for_hover(),
		"action-range gate must stay on at walk detour",
	)
	PlanningChecklistHarness.assert_red_contract(
		failures, "%s/red" % label, fix, bowling, true, stand, unit_id,
	)


static func assert_k4_run_trigger(
	failures: Array[String],
	fix: Dictionary,
	unit_id: int,
	label: String,
) -> void:
	var input: CombatPlanningInput = fix.input
	PlanningChecklistHarness.assert_true(
		failures,
		label,
		input.unit_move_requires_run(unit_id),
		"run trigger must require Run",
	)
	PlanningChecklistHarness.assert_eq_int(
		failures, label, input.planning_display_ap_left(unit_id), 0,
	)
	PlanningChecklistHarness.assert_true(
		failures,
		label,
		not input.action_range_visible_for_hover(),
		"action-range gate must be off at run trigger",
	)
	PlanningChecklistHarness.assert_true(
		failures,
		label,
		PlanningChecklistHarness.collect_red_tiles(fix).is_empty(),
		"overlay red must be empty at run trigger",
	)


static func _overlay_has_blue(fix: Dictionary) -> bool:
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	var board: BoardState = fix.board
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			if overlay.is_hover_move_tile(Vector2i(x, y)):
				return true
	return false


static func _assert_move_tile_at(
	fix: Dictionary,
	cell: Vector2i,
	expect_on: bool,
	label: String,
	failures: Array[String],
) -> void:
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	var on: bool = overlay.is_hover_move_tile(cell)
	PlanningChecklistHarness.assert_true(
		failures,
		label,
		on == expect_on,
		"move tile %s expected %s got %s" % [cell, expect_on, on],
	)


static func _assert_path_equals(
	failures: Array[String],
	path: Array[Vector2i],
	expected: Array,
	label: String,
) -> void:
	if path.size() != expected.size():
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"path len expected %d got %d (%s vs %s)" % [expected.size(), path.size(), expected, path],
		)
		return
	for i: int in range(expected.size()):
		var want: Vector2i = expected[i] as Vector2i
		if path[i] != want:
			PlanningChecklistHarness.assert_fail(
				failures,
				label,
				"path[%d] expected %s got %s (full %s)" % [i, want, path[i], path],
			)


static func _assert_path_ends(
	failures: Array[String],
	path: Array[Vector2i],
	end: Vector2i,
	min_size: int,
	start: Vector2i,
	label: String,
) -> void:
	if path.size() < min_size:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"path min size %d got %d (%s)" % [min_size, path.size(), path],
		)
	if path.is_empty():
		return
	if path[0] != start:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"path start expected %s got %s" % [start, path[0]],
		)
	if path[path.size() - 1] != end:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"path end expected %s got %s" % [end, path[path.size() - 1]],
		)


static func _assert_manhattan(path: Array[Vector2i], failures: Array[String], label: String) -> void:
	for i: int in range(1, path.size()):
		var dist: int = GridSystem.manhattan(path[i - 1], path[i])
		if dist != 1:
			PlanningChecklistHarness.assert_fail(
				failures,
				label,
				"path step %d not manhattan (dist %d)" % [i, dist],
			)


static func _assert_overlay_tiles_in_bounds(
	fix: Dictionary,
	failures: Array[String],
	label: String,
) -> void:
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	var board: BoardState = fix.board
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			if not board.is_in_bounds(coord):
				continue
			if overlay.is_hover_move_tile(coord) or overlay.is_hover_action_range_tile(coord):
				continue
	for y: int in range(-2, board.grid_size.y + 2):
		for x: int in range(-2, board.grid_size.x + 2):
			var coord := Vector2i(x, y)
			if board.is_in_bounds(coord):
				continue
			if overlay.is_hover_move_tile(coord) or overlay.is_hover_action_range_tile(coord):
				PlanningChecklistHarness.assert_fail(
					failures,
					label,
					"overlay tile painted out of bounds at %s" % coord,
				)
