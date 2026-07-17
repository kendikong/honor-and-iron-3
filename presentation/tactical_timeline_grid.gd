class_name TacticalTimelineGrid
extends GridContainer

## Turn-order grid — Name / Class / Stats / Pre-Move / Action.

const COLOR_FAIL: Color = Color(1.0, 0.35, 0.35)
const BG_ACTIVE: Color = Color(1.0, 1.0, 0.0, 0.25)
const COLOR_DIM_HEADER: Color = Color(0.6, 0.6, 0.6)

var _director: CombatDirector
var _board: BoardState
var _phase: int = CombatDirector.Phase.PLANNING
var _selected_id: int = -1
var _timeline_hover_id: int = -1
var _header_font_px: int = 13
var _cell_font_px: int = 11

signal row_hovered(unit_id: int)
signal row_unhovered(unit_id: int)
signal warning_changed(text: String)


func setup(director: CombatDirector) -> void:
	_director = director
	columns = 5
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 2)


func set_board(board: BoardState) -> void:
	_board = board


func set_phase(phase: int) -> void:
	_phase = phase


func set_selected(unit_id: int) -> void:
	_selected_id = unit_id


func apply_font_sizes(header_px: int, cell_px: int) -> void:
	_header_font_px = maxi(8, header_px)
	_cell_font_px = maxi(8, cell_px)


func rebuild(timeline: Timeline, statuses: PackedStringArray) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if _board == null or _director == null:
		return
	var headers: PackedStringArray = ["Name", "Class", "Stats", "Pre-Move", "Action"]
	var plan_active: bool = CombatDirector.is_planning_phase(_phase) or CombatDirector.is_executing_phase(_phase)
	var p1_active: bool = plan_active
	var p2_active: bool = plan_active
	for i: int in headers.size():
		var hcol: Color = Color.WHITE
		var hbg: Color = Color.TRANSPARENT
		if i == 3:
			hcol = Color.WHITE if p1_active else COLOR_DIM_HEADER
			hbg = BG_ACTIVE if p1_active else Color.TRANSPARENT
		elif i == 4:
			hcol = Color.WHITE if p2_active else COLOR_DIM_HEADER
			hbg = BG_ACTIVE if p2_active else Color.TRANSPARENT
		_make_cell(headers[i], "", hcol, true, hbg)
	var first_warning: String = ""
	for unit in _board.units:
		if unit.is_enemy():
			continue
		var row_color: Color = Color.WHITE
		var dim_color: Color = Color(0.7, 0.7, 0.7)
		var bg_color: Color = Color.TRANSPARENT
		if unit.id == _selected_id:
			row_color = Color(1.0, 1.0, 0.3)
			dim_color = Color(0.9, 0.9, 0.2)
			bg_color = Color(0.2, 0.3, 0.5, 0.5)
		var name_lbl := _make_cell(unit.definition.display_name, unit.definition.display_name, row_color, false, bg_color)
		var class_lbl := _make_cell(
			CombatUiFormatters.class_symbol(unit),
			unit.definition.display_name,
			row_color,
			false,
			bg_color,
		)
		var stats_text: String = (
			"🌟%d ❤️%d/%d 🛡️%d 💪%d 🔮%d 🏰%d 👟%d"
			% [
				unit.level, unit.health.current_hp, unit.health.max_hp, unit.armor,
				unit.current_strength, unit.current_magic, unit.current_defense,
				unit.movement.max_points,
			]
		)
		var stats_lbl := _make_cell(stats_text, stats_text, dim_color, false, bg_color)
		var p1_action: TimelineAction = _find_pre_action(timeline, unit.id)
		var p1_text: String = CombatUiFormatters.action_symbol_text(_board, p1_action, unit)
		var p1_tooltip: String = (
			CombatUiFormatters.describe_action(_board, p1_action)
			if p1_action != null else "No action queued"
		)
		var p1_col: Color = row_color if p1_active else Color(row_color.r * 0.45, row_color.g * 0.45, row_color.b * 0.45)
		var p1_bg: Color = bg_color.blend(BG_ACTIVE) if p1_active else bg_color
		var p1_lbl := _make_cell(p1_text, p1_tooltip, p1_col, false, p1_bg)
		if p1_action == null:
			p1_lbl.modulate = Color(1, 1, 1, 0.25 if not p1_active else 0.4)
		elif timeline != null:
			var combined_idx: int = timeline.entries.find(p1_action)
			if combined_idx >= 0 and combined_idx < statuses.size() and statuses[combined_idx] != "":
				p1_lbl.add_theme_color_override("font_color", COLOR_FAIL)
				if first_warning.is_empty():
					first_warning = "Action %d (%s): %s" % [
						combined_idx + 1,
						unit.definition.display_name,
						CombatUiFormatters.reason_text(statuses[combined_idx]),
					]
		var p2_action: TimelineAction = _find_post_action(timeline, unit.id)
		var p2_text: String = CombatUiFormatters.action_symbol_text(_board, p2_action, unit)
		var p2_tooltip: String = (
			CombatUiFormatters.describe_action(_board, p2_action)
			if p2_action != null else "No action queued"
		)
		var p2_col: Color = row_color if p2_active else Color(row_color.r * 0.45, row_color.g * 0.45, row_color.b * 0.45)
		var p2_bg: Color = bg_color.blend(BG_ACTIVE) if p2_active else bg_color
		var p2_lbl := _make_cell(p2_text, p2_tooltip, p2_col, false, p2_bg)
		if p2_action == null:
			p2_lbl.modulate = Color(1, 1, 1, 0.25 if not p2_active else 0.4)
		elif timeline != null:
			var combined_idx: int = timeline.entries.find(p2_action)
			if combined_idx >= 0 and combined_idx < statuses.size() and statuses[combined_idx] != "":
				p2_lbl.add_theme_color_override("font_color", COLOR_FAIL)
				if first_warning.is_empty():
					first_warning = "Action %d (%s): %s" % [
						combined_idx + 1,
						unit.definition.display_name,
						CombatUiFormatters.reason_text(statuses[combined_idx]),
					]
		var row_labels: Array[Label] = [name_lbl, class_lbl, stats_lbl, p1_lbl, p2_lbl]
		var base_colors: Array[Color] = [bg_color, bg_color, bg_color, p1_bg, p2_bg]
		var hover_colors: Array[Color] = []
		for c: Color in base_colors:
			hover_colors.append(c.lightened(0.2) if c != Color.TRANSPARENT else Color(1, 1, 1, 0.1))
		var unit_id: int = unit.id
		for lbl: Label in row_labels:
			lbl.mouse_entered.connect(func() -> void:
				_timeline_hover_id = unit_id
				row_hovered.emit(unit_id)
				for i: int in row_labels.size():
					var sb: StyleBoxFlat = row_labels[i].get_theme_stylebox("normal") as StyleBoxFlat
					if sb != null:
						sb.bg_color = hover_colors[i]
			)
			lbl.mouse_exited.connect(func() -> void:
				if _timeline_hover_id == unit_id:
					_timeline_hover_id = -1
					row_unhovered.emit(unit_id)
				for i: int in row_labels.size():
					var sb: StyleBoxFlat = row_labels[i].get_theme_stylebox("normal") as StyleBoxFlat
					if sb != null:
						sb.bg_color = base_colors[i]
			)
			lbl.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					if _director != null:
						_director.select_unit(unit_id)
			)
	warning_changed.emit(first_warning)


func get_hover_unit_id() -> int:
	return _timeline_hover_id


func _find_pre_action(plan: Timeline, unit_id: int) -> TimelineAction:
	if plan == null:
		return null
	for action: TimelineAction in plan.entries:
		if action.actor_id != unit_id:
			continue
		if action.type == GameEnums.ActionType.MOVE and action.move_timing == GameEnums.MoveTiming.PRE_ACTION:
			return action
	return null


func _find_post_action(plan: Timeline, unit_id: int) -> TimelineAction:
	if plan == null:
		return null
	var ability_action: TimelineAction = null
	for action: TimelineAction in plan.entries:
		if action.actor_id != unit_id:
			continue
		if action.type == GameEnums.ActionType.ABILITY:
			ability_action = action
		elif action.type == GameEnums.ActionType.MOVE and action.move_timing == GameEnums.MoveTiming.POST_ACTION:
			return action
	return ability_action


func _find_action(plan: Timeline, unit_id: int) -> TimelineAction:
	if plan == null:
		return null
	for action: TimelineAction in plan.entries:
		if action.actor_id == unit_id:
			return action
	return null


func _make_cell(
	text: String,
	tooltip: String,
	col: Color,
	is_header: bool,
	bg_color: Color,
) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _header_font_px if is_header else _cell_font_px)
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	if tooltip != "":
		lbl.tooltip_text = tooltip
	if col != Color.WHITE:
		lbl.add_theme_color_override("font_color", col)
	if is_header:
		lbl.add_theme_color_override("font_color", Color(0.67, 0.67, 0.67))
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	lbl.add_theme_stylebox_override("normal", sb)
	add_child(lbl)
	return lbl
