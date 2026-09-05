class_name PlanningBowlingAdvanceMimicTest
extends RefCounted

## Headless mimic of Bowling Charge advance: L-shape walk/arm, hover every red
## dash tile plus off-red, then commit DASH 3 past an enemy. Dash is a movement
## module (straight-line tile path), not a teleport hop.


static func run_all(failures: Array[String]) -> void:
	print("[SUITE] bowling_advance_mimic")
	run_bowling_advance_session(failures)


static func run_bowling_advance_session(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bowling_advance_board()
	var knight_id: int = fix.k1_id as int
	var enemy_id: int = fix.e_bowl_id as int
	fix.director.auto_run = false
	fix.input.auto_use_skill_after_move = false
	var bowling: AbilityData = _select_bowling(fix, failures, knight_id, "BA-01")
	if bowling == null:
		return
	_probe_unarmed_stand(fix, failures, knight_id, bowling)
	_probe_unarmed_l_walk(fix, failures, knight_id, bowling)
	if not _commit_l_walk_and_arm(fix, failures, knight_id, bowling, "BA-04"):
		return
	_probe_all_red_dash_tiles(fix, failures, knight_id, bowling, enemy_id, "BA-06")
	_probe_off_red_tiles(fix, failures, knight_id, bowling, "BA-07")
	if not _commit_dash_past_enemy(fix, failures, knight_id, bowling, enemy_id, "BA-08"):
		return
	_assert_bowling_dash_committed(fix, failures, knight_id, enemy_id, "BA-09")
	var selection_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, knight_id)
	PlanningLiveParityHarness.undo_until_unit_clear(
		fix, failures, knight_id, PlanningChecklistHarness.BOWLING_ADVANCE_START, "BA-10",
	)
	if not _commit_l_walk_and_arm(fix, failures, knight_id, bowling, "BA-11"):
		return
	if not _commit_dash_past_enemy(fix, failures, knight_id, bowling, enemy_id, "BA-12"):
		return
	_assert_bowling_dash_committed(fix, failures, knight_id, enemy_id, "BA-12")
	var drag_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, knight_id)
	PlanningChecklistHarness.assert_mode_commit_parity(
		failures, "ba/first", selection_surface, "ba/second", drag_surface,
	)
	_probe_postmove_from_landing(fix, failures, knight_id, bowling)
	_assert_execute_matches_projected(fix, failures, knight_id, enemy_id)


static func expected_dash_preview_path(stand: Vector2i, dest: Vector2i) -> Array[Vector2i]:
	var line: Array[Vector2i] = PhysicsSystem.cardinal_straight_line_path(stand, dest)
	var out: Array[Vector2i] = [stand]
	out.append_array(line)
	return out


static func _select_bowling(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	label: String,
) -> AbilityData:
	var idx: int = PlanningChecklistHarness.select_ability_for_unit(
		fix, knight_id, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	if idx < 0:
		PlanningChecklistHarness.assert_fail(failures, label, "Bowling Charge missing")
		return null
	var unit: UnitState = fix.board.get_unit_by_id(knight_id)
	if unit == null:
		PlanningChecklistHarness.assert_fail(failures, label, "knight missing")
		return null
	return unit.active_abilities[idx]


static func _probe_unarmed_stand(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
) -> void:
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, knight_id, PlanningChecklistHarness.BOWLING_ADVANCE_START, {
			"blue_any": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.BOWLING_ADVANCE_START,
			"ability": bowling,
			"manhattan": true,
		}, "BA-01/stand",
	)


static func _probe_unarmed_l_walk(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
) -> void:
	var mid: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_L_MID
	var stand: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_STAND
	var start: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_START
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, knight_id, mid, {
			"path": [start, mid],
			"ghost_pos": mid,
			"manhattan": true,
			"preview_nonempty": true,
			"icon_has": [PlanningIcons.GLYPH_WALK],
			"icon_not": [PlanningIcons.GLYPH_NULL],
			"red_on": true,
			"red_stand": mid,
			"ability": bowling,
		}, "BA-02/l_mid",
	)
	_assert_cursor_matches_slots(fix, failures, knight_id, mid, "BA-02/l_mid/cursor")
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, knight_id, stand, {
			"path_start": start,
			"path_end": stand,
			"path_min_size": 3,
			"ghost_pos": stand,
			"manhattan": true,
			"preview_nonempty": true,
			"icon_has": [PlanningIcons.GLYPH_WALK],
			"icon_not": [PlanningIcons.GLYPH_NULL],
			"red_on": true,
			"red_stand": stand,
			"ability": bowling,
		}, "BA-03/l_dest",
	)
	_assert_cursor_matches_slots(fix, failures, knight_id, stand, "BA-03/l_dest/cursor")


static func _commit_l_walk_and_arm(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
	label: String,
) -> bool:
	var route: Array[Vector2i] = PlanningChecklistHarness.BOWLING_ADVANCE_L_ROUTE
	var dest: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_STAND
	PlanningChecklistHarness.select_unit(fix, knight_id, route[0])
	PlanningChecklistHarness.wait_ability_settle_sync(fix)
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(fix, route, dest):
		PlanningChecklistHarness.assert_fail(failures, "%s/l_walk" % label, "L-walk premove commit failed")
		return false
	_assert_premove_executed_and_preview_cleared(fix, failures, knight_id, dest, "%s/premove_clear" % label)
	var pre: TimelineAction = PlanningChecklistHarness.committed_pre_move(fix.director, knight_id)
	if pre == null:
		PlanningChecklistHarness.assert_fail(failures, "%s/premove" % label, "L-walk must write a pre-move")
		return false
	if pre.target_coord != dest:
		PlanningChecklistHarness.assert_fail(
			failures, "%s/premove" % label, "L-walk dest %s got %s" % [dest, pre.target_coord],
		)
		return false
	if pre.waypoints != PlanningChecklistHarness.BOWLING_ADVANCE_L_WAYPOINTS:
		PlanningChecklistHarness.assert_fail(
			failures,
			"%s/premove" % label,
			"L-walk waypoints %s expected %s" % [pre.waypoints, PlanningChecklistHarness.BOWLING_ADVANCE_L_WAYPOINTS],
		)
	PlanningChecklistHarness.select_ability_for_unit(
		fix, knight_id, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	PlanningChecklistHarness.select_unit(fix, knight_id, dest)
	if not fix.input.awaiting_targeting_active():
		var arm_slots: Dictionary = PlanningChecklistHarness.commit_production(fix, dest)
		if PlanningChecklistHarness.slots_invalid(arm_slots):
			PlanningChecklistHarness.assert_fail(failures, "%s/arm" % label, "walk/arm self-tap failed")
			return false
	if not fix.input.awaiting_targeting_active():
		PlanningChecklistHarness.assert_fail(failures, "%s/arm" % label, "bowling must arm awaiting dash after L-walk")
		return false
	if fix.director.find_awaiting_action(knight_id) == null:
		PlanningChecklistHarness.assert_fail(failures, "%s/arm" % label, "awaiting bowling action missing")
		return false
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, knight_id, dest, {
			"red_on": true,
			"red_stand": dest,
			"ability": bowling,
			"manhattan": true,
		}, "%s/armed_stand" % label,
	)
	return true


static func _assert_premove_executed_and_preview_cleared(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	dest: Vector2i,
	label: String,
) -> void:
	var live: UnitState = fix.director.board.get_unit_by_id(knight_id)
	if live == null or live.position != dest:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"premove executes immediately; live stand expected %s got %s"
			% [dest, live.position if live != null else Vector2i(-1, -1)],
		)
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, knight_id)
	if projected == null or projected.position != dest:
		PlanningChecklistHarness.assert_fail(
			failures, label, "projected stand after premove expected %s" % dest,
		)
	var pre_leg: Array = fix.input.display_committed_move_route_leg(
		knight_id, GameEnums.MoveTiming.PRE_ACTION, dest,
	)
	if not pre_leg.is_empty():
		PlanningChecklistHarness.assert_fail(
			failures, label, "executed L-walk committed leg must clear, got %s" % str(pre_leg),
		)
	var display_route: Array[Vector2i] = fix.input.display_move_route_cells(knight_id)
	if display_route.size() >= 2:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"executed L-walk must not keep a live move preview, got %s" % str(display_route),
		)
	var live_path: Array[Vector2i] = PlanningChecklistHarness.preview_path(fix, knight_id)
	if live_path.size() >= 2 and live_path[0] == PlanningChecklistHarness.BOWLING_ADVANCE_START:
		PlanningChecklistHarness.assert_fail(
			failures, label, "live preview path must not keep the executed L-walk, got %s" % str(live_path),
		)


static func _probe_all_red_dash_tiles(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
	enemy_id: int,
	label: String,
) -> void:
	var stand: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_STAND
	PlanningChecklistHarness.select_unit(fix, knight_id, stand)
	PlanningChecklistHarness.flush_planning(fix)
	var overlay_red: Array[Vector2i] = PlanningChecklistHarness.collect_red_tiles(fix)
	var unit: UnitState = PlanningChecklistHarness.projected_unit(fix, knight_id)
	var expected_red: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.director.projected_state if fix.director.projected_state != null else fix.board,
		unit,
		bowling,
		stand,
	)
	if overlay_red.is_empty():
		PlanningChecklistHarness.assert_fail(failures, label, "armed bowling must paint red dash tiles")
		return
	for tile: Vector2i in expected_red:
		if not overlay_red.has(tile):
			PlanningChecklistHarness.assert_fail(
				failures, label, "missing red dash tile %s from stand %s" % [tile, stand],
			)
	for tile: Vector2i in overlay_red:
		_assert_red_dash_hover(
			fix, failures, knight_id, bowling, enemy_id, stand, tile, "%s/%s" % [label, tile],
		)
	PlanningChecklistHarness.assert_eq_int(
		failures, "%s/count" % label, overlay_red.size(), expected_red.size(),
	)


static func _assert_red_dash_hover(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
	enemy_id: int,
	stand: Vector2i,
	tile: Vector2i,
	label: String,
) -> void:
	PlanningChecklistHarness.refresh_attack_hover(fix, tile)
	var path: Array[Vector2i] = fix.input.display_move_route_cells(knight_id)
	if path.size() < 2:
		path = PlanningChecklistHarness.preview_path(fix, knight_id)
	_assert_dash_path_is_straight_walk(failures, stand, tile, path, label)
	var ghost: Vector2i = PlanningChecklistHarness.preview_unit_pos(fix, knight_id)
	PlanningChecklistHarness.assert_eq_cell(failures, "%s/ghost" % label, ghost, tile)
	var slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, tile)
	if PlanningChecklistHarness.slots_invalid(slots):
		PlanningChecklistHarness.assert_fail(
			failures, label, "red dash tile %s must be selectable (got invalid slots)" % tile,
		)
		return
	var actions: Array = slots.get("action", []) as Array
	if actions.is_empty():
		PlanningChecklistHarness.assert_fail(failures, label, "red dash tile %s must build an action, not ∅" % tile)
		return
	if actions[0] is TimelineAction:
		var dash: TimelineAction = actions[0] as TimelineAction
		if dash.target_coord != tile:
			PlanningChecklistHarness.assert_fail(
				failures, label, "dash target_coord %s expected %s" % [dash.target_coord, tile],
			)
		if dash.target_unit_id != -1:
			PlanningChecklistHarness.assert_fail(
				failures, label, "bowling dash is TILE targeting, got unit %d" % dash.target_unit_id,
			)
	_assert_cursor_matches_slots(fix, failures, knight_id, tile, "%s/cursor" % label)
	var icon: String = fix.input.compute_hover_action_icon(tile)
	if icon == PlanningIcons.GLYPH_NULL or icon == "":
		PlanningChecklistHarness.assert_fail(failures, label, "red dash hover must not show ∅ at %s" % tile)
	PlanningChecklistHarness.assert_red_contract(
		failures, "%s/red" % label, fix, bowling, true, stand, knight_id,
	)
	PlanningChecklistHarness.assert_enemy_live_unchanged(
		failures, "%s/live_enemy" % label, fix, enemy_id, PlanningChecklistHarness.BOWLING_ADVANCE_ENEMY,
	)
	if tile == PlanningChecklistHarness.BOWLING_ADVANCE_DEST:
		var projected_enemy: UnitState = PlanningChecklistHarness.projected_unit(fix, enemy_id)
		if projected_enemy != null and projected_enemy.position == PlanningChecklistHarness.BOWLING_ADVANCE_ENEMY:
			var hover_enemy: UnitState = null
			if fix.input.preview_state != null and fix.input.preview_state.preview_board != null:
				hover_enemy = fix.input.preview_state.preview_board.get_unit_by_id(enemy_id)
			if hover_enemy == null or hover_enemy.position == PlanningChecklistHarness.BOWLING_ADVANCE_ENEMY:
				PlanningChecklistHarness.assert_fail(
					failures, label, "dash past enemy must predict bulldoze displacement",
				)


static func _assert_dash_path_is_straight_walk(
	failures: Array[String],
	stand: Vector2i,
	dest: Vector2i,
	path: Array[Vector2i],
	label: String,
) -> void:
	if path.is_empty():
		PlanningChecklistHarness.assert_fail(
			failures, label, "dash movement module must show a move preview to %s" % dest,
		)
		return
	var line: Array[Vector2i] = PhysicsSystem.cardinal_straight_line_path(stand, dest)
	if line.is_empty():
		PlanningChecklistHarness.assert_fail(
			failures, label, "dash dest %s is not on a cardinal line from %s" % [dest, stand],
		)
		return
	if path[path.size() - 1] != dest:
		PlanningChecklistHarness.assert_fail(
			failures, label, "dash path must end at hover %s got %s" % [dest, path[path.size() - 1]],
		)
	if path[0] != stand and path[0] != line[0]:
		PlanningChecklistHarness.assert_fail(
			failures, label, "dash path must start at stand %s or first step %s, got %s" % [stand, line[0], path[0]],
		)
	for i: int in range(1, path.size()):
		if GridSystem.manhattan(path[i - 1], path[i]) != 1:
			PlanningChecklistHarness.assert_fail(
				failures,
				label,
				"dash path skipped a tile at step %d (%s -> %s); dash is not teleport"
				% [i, path[i - 1], path[i]],
			)
			return
	for cell: Vector2i in line:
		if not path.has(cell):
			PlanningChecklistHarness.assert_fail(
				failures,
				label,
				"dash path %s skipped straight-line cell %s (not a teleport hop)" % [str(path), cell],
			)
			return
	if GridSystem.manhattan(stand, dest) > 1 and path.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures, label, "dash past one tile must visit every cell, got hop %s" % str(path),
		)


static func _probe_off_red_tiles(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
	label: String,
) -> void:
	var stand: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_STAND
	var off_cells: Array[Vector2i] = [
		PlanningChecklistHarness.BOWLING_ADVANCE_OFF_RED_A,
		PlanningChecklistHarness.BOWLING_ADVANCE_OFF_RED_B,
	]
	for cell: Vector2i in off_cells:
		PlanningChecklistHarness.refresh_attack_hover(fix, cell)
		var red: Array[Vector2i] = PlanningChecklistHarness.collect_red_tiles(fix)
		if red.has(cell):
			PlanningChecklistHarness.assert_fail(
				failures, "%s/%s" % [label, cell], "off-red cell %s must not be painted red" % cell,
			)
		var slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, cell)
		var icon: String = fix.input.compute_hover_action_icon(cell)
		var path: Array[Vector2i] = PlanningChecklistHarness.preview_path(fix, knight_id)
		if not PlanningChecklistHarness.slots_invalid(slots) and not (slots.get("action", []) as Array).is_empty():
			PlanningChecklistHarness.assert_fail(
				failures, "%s/%s" % [label, cell], "off-red hover must not build a dash action",
			)
		if icon != PlanningIcons.GLYPH_NULL and icon != "":
			if icon.contains(PlanningIcons.GLYPH_DASH):
				PlanningChecklistHarness.assert_fail(
					failures, "%s/%s" % [label, cell], "off-red must not show dash cursor, got %s" % icon,
				)
		if not path.is_empty() and path[path.size() - 1] == cell:
			PlanningChecklistHarness.assert_fail(
				failures, "%s/%s" % [label, cell], "off-red must not paint a dash path to an illegal tile",
			)
		PlanningChecklistHarness.assert_red_contract(
			failures, "%s/%s/red_from_stand" % [label, cell], fix, bowling, true, stand, knight_id,
		)
	PlanningLiveParityHarness.assert_off_blue_click_must_not_commit(
		fix, failures, knight_id, PlanningChecklistHarness.BOWLING_ADVANCE_OFF_RED_A, "%s/click_a" % label,
	)
	PlanningLiveParityHarness.assert_off_blue_click_must_not_commit(
		fix, failures, knight_id, PlanningChecklistHarness.BOWLING_ADVANCE_OFF_RED_B, "%s/click_b" % label,
	)


static func _commit_dash_past_enemy(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
	enemy_id: int,
	label: String,
) -> bool:
	var dest: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_DEST
	PlanningChecklistHarness.refresh_attack_hover(fix, dest)
	_assert_red_dash_hover(
		fix, failures, knight_id, bowling, enemy_id,
		PlanningChecklistHarness.BOWLING_ADVANCE_STAND, dest, "%s/pre_commit" % label,
	)
	var pre_intent: Dictionary = PlanningLiveParityHarness.capture_preview_intent(
		fix, knight_id, dest, false,
	)
	if not PlanningLiveParityHarness.commit_from_preview_intent(
		fix, knight_id, pre_intent, "%s/release" % label, failures,
	):
		return false
	return true


static func _assert_bowling_dash_committed(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	enemy_id: int,
	label: String,
) -> void:
	var dest: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_DEST
	var action: TimelineAction = PlanningChecklistHarness.committed_action(fix.director, knight_id)
	if action == null:
		PlanningChecklistHarness.assert_fail(failures, label, "bowling dash action missing")
		return
	if action.target_coord != dest:
		PlanningChecklistHarness.assert_fail(
			failures, label, "bowling dest %s got %s" % [dest, action.target_coord],
		)
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, knight_id)
	if projected == null or projected.position != dest:
		PlanningChecklistHarness.assert_fail(failures, label, "projected knight must land at %s" % dest)
	if projected != null and projected.ability.points_left != 0:
		PlanningChecklistHarness.assert_fail(failures, label, "bowling must spend AP")
	PlanningChecklistHarness.assert_enemy_live_unchanged(
		failures, "%s/live_enemy" % label, fix, enemy_id, PlanningChecklistHarness.BOWLING_ADVANCE_ENEMY,
	)
	var live_knight: UnitState = fix.director.board.get_unit_by_id(knight_id)
	if live_knight == null or live_knight.position != PlanningChecklistHarness.BOWLING_ADVANCE_STAND:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"dash has not executed yet; live knight must remain at armed stand %s"
			% PlanningChecklistHarness.BOWLING_ADVANCE_STAND,
		)
	var persist_path: Array[Vector2i] = _committed_dash_persist_path(fix, knight_id, action, dest)
	if persist_path.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures, label, "committed dash move preview must persist until execution",
		)
	else:
		_assert_dash_path_is_straight_walk(
			failures,
			PlanningChecklistHarness.BOWLING_ADVANCE_STAND,
			dest,
			persist_path,
			"%s/committed_path" % label,
		)
	var bowling: AbilityData = action.ability
	PlanningChecklistHarness.assert_red_contract(
		failures, "%s/post_commit_red" % label, fix, bowling, false, dest, knight_id,
	)


static func _probe_postmove_from_landing(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
) -> void:
	var land: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_DEST
	var post: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_POST_DEST
	PlanningChecklistHarness.select_unit(fix, knight_id, land)
	PlanningChecklistHarness.enter_basic_movement(fix)
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, knight_id, land, {
			"blue_any": true,
			"manhattan": true,
		}, "BA-13/post_stand",
	)
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, knight_id, post, {
			"path": [land, post],
			"ghost_pos": post,
			"manhattan": true,
			"preview_nonempty": true,
			"icon_has": [PlanningIcons.GLYPH_WALK],
			"icon_not": [PlanningIcons.GLYPH_NULL],
			"blue_has": [post],
		}, "BA-14/post_hover",
	)
	_assert_cursor_matches_slots(fix, failures, knight_id, post, "BA-14/post_cursor")
	var post_route: Array[Vector2i] = [land, post]
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(fix, post_route, post):
		PlanningChecklistHarness.assert_fail(failures, "BA-15/post_commit", "postmove after bowling failed")
		return
	var post_action: TimelineAction = PlanningChecklistHarness.committed_post_move(fix.director, knight_id)
	if post_action == null:
		PlanningChecklistHarness.assert_fail(failures, "BA-15/post_commit", "post-move missing")
		return
	if post_action.target_coord != post:
		PlanningChecklistHarness.assert_fail(failures, "BA-15/post_commit", "post-move dest")
	PlanningChecklistHarness.assert_red_contract(
		failures, "BA-16/post_after_commit", fix, bowling, false, post, knight_id,
	)


static func _assert_execute_matches_projected(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	enemy_id: int,
) -> void:
	var result: SimResult = PlanningChecklistHarness.simulate_committed(fix.director)
	var sim_board: BoardState = result.final_state
	var proj_k: UnitState = PlanningChecklistHarness.projected_unit(fix, knight_id)
	var proj_e: UnitState = PlanningChecklistHarness.projected_unit(fix, enemy_id)
	var sim_k: UnitState = sim_board.get_unit_by_id(knight_id)
	var sim_e: UnitState = sim_board.get_unit_by_id(enemy_id)
	if sim_k == null or proj_k == null:
		PlanningChecklistHarness.assert_fail(failures, "BA-17/exec", "knight missing at execute")
		return
	PlanningChecklistHarness.assert_eq_cell(failures, "BA-17/k", sim_k.position, proj_k.position)
	if sim_e == null or proj_e == null:
		PlanningChecklistHarness.assert_fail(failures, "BA-17/exec", "enemy missing at execute")
		return
	PlanningChecklistHarness.assert_eq_cell(failures, "BA-17/e", sim_e.position, proj_e.position)
	if sim_e.position == PlanningChecklistHarness.BOWLING_ADVANCE_ENEMY:
		PlanningChecklistHarness.assert_fail(
			failures, "BA-17/exec", "execute must displace the enemy bowling charged through",
		)


static func _assert_cursor_matches_slots(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	cell: Vector2i,
	label: String,
) -> void:
	var unit: UnitState = fix.board.get_unit_by_id(knight_id)
	var slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, cell)
	var hover_icon: String = fix.input.compute_hover_action_icon(cell)
	var expected_icon: String = fix.input._cursor_icon_from_commit_slots(slots, unit)
	if hover_icon != expected_icon:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"cursor %s must match slots cursor %s at %s" % [hover_icon, expected_icon, cell],
		)


static func _committed_dash_persist_path(
	fix: Dictionary,
	knight_id: int,
	action: TimelineAction,
	dest: Vector2i,
) -> Array[Vector2i]:
	var stand: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_STAND
	var candidates: Array = [
		fix.input.display_move_route_cells(knight_id),
		_typed_cells(fix.input.display_frozen_route_cells(knight_id)),
		_typed_cells(fix.input.display_committed_action_route_cells(knight_id, action, stand)),
	]
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	if overlay != null:
		candidates.append(_typed_cells(overlay.get_committed_preview().preview_paths.get(knight_id, [])))
	if fix.input.preview_state != null:
		candidates.append(_typed_cells(fix.input.preview_state.preview_paths.get(knight_id, [])))
	if action != null and not action.waypoints.is_empty():
		var from_wp: Array[Vector2i] = [stand]
		from_wp.append_array(action.waypoints)
		candidates.append(from_wp)
		candidates.append(action.waypoints.duplicate())
	for path: Array in candidates:
		var typed: Array[Vector2i] = _typed_cells(path)
		if typed.size() >= 2 and typed[typed.size() - 1] == dest:
			return typed
	return []


static func _typed_cells(raw: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v: Variant in raw:
		out.append(v as Vector2i)
	return out
