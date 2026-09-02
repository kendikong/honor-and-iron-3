class_name MovePreviewMouseFollowHarness
extends RefCounted

## Live F5 regression: hover cell changes must redraw the main overlay (move-preview
## ghost circles in _draw_move_ghosts) without requiring _flush_hover_heavy_sync.
## Existing mouse-waypoint tests only checked _drag_route / commit slots.


static func assert_live_hover_redraws_main_overlay(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	overlay: TacticalPlanningOverlay,
	cells: Array[Vector2i],
) -> void:
	if cells.size() < 2:
		failures.append("%s: need at least two hover cells" % label)
		return
	var input: CombatPlanningInput = fix.input as CombatPlanningInput
	if input == null or overlay == null:
		failures.append("%s: missing input or overlay" % label)
		return
	if overlay.qa_static_overlay:
		failures.append("%s: must use live overlay (qa_static_overlay=false)" % label)
		return
	var nonce_start: int = overlay.overlay_redraw_nonce()
	var previous: Vector2i = cells[0]
	_hover_live_throttle_only(input, overlay, previous)
	var nonce_after_first: int = overlay.overlay_redraw_nonce()
	if nonce_after_first <= nonce_start:
		failures.append(
			"%s: first hover %s must queue main overlay redraw (nonce %d -> %d)"
			% [label, previous, nonce_start, nonce_after_first],
		)
	if _overlay_hover_coord(overlay) != previous:
		failures.append(
			"%s: overlay hover must track pointer at %s, got %s"
			% [label, previous, _overlay_hover_coord(overlay)],
		)
	for i: int in range(1, cells.size()):
		var cell: Vector2i = cells[i] as Vector2i
		var nonce_before: int = overlay.overlay_redraw_nonce()
		_hover_live_throttle_only(input, overlay, cell)
		var nonce_after: int = overlay.overlay_redraw_nonce()
		if nonce_after <= nonce_before:
			failures.append(
				"%s: hover %s must queue main overlay redraw without flush (nonce %d -> %d)"
				% [label, cell, nonce_before, nonce_after],
			)
		if _overlay_hover_coord(overlay) != cell:
			failures.append(
				"%s: overlay hover must follow mouse to %s, got %s"
				% [label, cell, _overlay_hover_coord(overlay)],
			)


static func assert_movement_ghost_circle_at_hover(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	overlay: TacticalPlanningOverlay,
	hover_cell: Vector2i,
	unit: UnitState,
) -> void:
	var input: CombatPlanningInput = fix.input as CombatPlanningInput
	if input == null or overlay == null or unit == null:
		failures.append("%s: missing input, overlay, or unit" % label)
		return
	hover_live_throttle_only(input, overlay, hover_cell)
	if not overlay.movement_ghost_paint_applies(unit):
		failures.append(
			"%s: move-preview ghost circle must paint at hover %s"
			% [label, hover_cell],
		)
		return
	if _overlay_hover_coord(overlay) != hover_cell:
		failures.append(
			"%s: ghost circle anchor must follow hover %s, got %s"
			% [label, hover_cell, _overlay_hover_coord(overlay)],
		)


static func assert_drag_corridor_follows_hover_without_flush(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	overlay: TacticalPlanningOverlay,
	cells: Array[Vector2i],
) -> void:
	var input: CombatPlanningInput = fix.input as CombatPlanningInput
	if input == null or overlay == null:
		failures.append("%s: missing input or overlay" % label)
		return
	var route: Array[Vector2i] = []
	for cell: Vector2i in cells:
		hover_live_throttle_only(input, overlay, cell)
		route = input.get_drag_route()
		if route.is_empty():
			failures.append(
				"%s: staged corridor must be non-empty at hover %s"
				% [label, cell],
			)
			return
		if (route[route.size() - 1] as Vector2i) != cell:
			failures.append(
				"%s: mouse corridor route must end at hover %s, got %s"
				% [label, cell, str(route)],
			)


static func assert_movement_ghost_paint_and_route_at_hover(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	overlay: TacticalPlanningOverlay,
	hover_cell: Vector2i,
	unit: UnitState,
) -> void:
	assert_movement_ghost_circle_at_hover(failures, label, fix, overlay, hover_cell, unit)


static func assert_movement_ghost_route_ends_at_hover(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	overlay: TacticalPlanningOverlay,
	hover_cell: Vector2i,
	unit: UnitState,
) -> void:
	assert_movement_ghost_paint_and_route_at_hover(failures, label, fix, overlay, hover_cell, unit)


static func hover_live_throttle_only(
	input: CombatPlanningInput,
	overlay: TacticalPlanningOverlay,
	cell: Vector2i,
) -> void:
	input.set_qa_pointer_grid_cell(cell)
	input.on_hover_moved(cell)
	# Deliberately no _flush_hover_heavy_sync — live F5 throttle path only.


static func _hover_live_throttle_only(
	input: CombatPlanningInput,
	overlay: TacticalPlanningOverlay,
	cell: Vector2i,
) -> void:
	hover_live_throttle_only(input, overlay, cell)


static func _overlay_hover_coord(overlay: TacticalPlanningOverlay) -> Vector2i:
	var ctx: Dictionary = overlay.build_debug_context()
	var raw: Variant = ctx.get("hover_coord", [-999, -999])
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return Vector2i(-999999, -999999)
