class_name TacticalTimelineGrid
extends VBoxContainer

## Per-unit planning timeline — ordered action steps in simulation order.

const COLOR_FAIL: Color = Color(1.0, 0.35, 0.35)
const BG_ACTIVE: Color = Color(1.0, 1.0, 0.0, 0.25)
const COLOR_DIM_HEADER: Color = Color(0.6, 0.6, 0.6)
const COL_NAME_W: int = 72
const COL_CLASS_W: int = 40
const COL_STATS_MIN_W: int = 148

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
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 2)


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
	var plan_active: bool = CombatDirector.is_planning_phase(_phase) or CombatDirector.is_executing_phase(_phase)
	var header_row := _make_row()
	_add_row_cell(header_row, "Name", "", Color.WHITE, true, Color.TRANSPARENT, COL_NAME_W, false)
	_add_row_cell(header_row, "Class", "", Color.WHITE, true, Color.TRANSPARENT, COL_CLASS_W, false)
	_add_row_cell(header_row, "Stats", "", Color.WHITE, true, Color.TRANSPARENT, COL_STATS_MIN_W, false)
	var timeline_header_bg: Color = BG_ACTIVE if plan_active else Color.TRANSPARENT
	var timeline_header_col: Color = Color.WHITE if plan_active else COLOR_DIM_HEADER
	_add_row_cell(header_row, "Timeline", "", timeline_header_col, true, timeline_header_bg, 0, true)
	var first_warning: String = ""
	for unit: UnitState in _board.units:
		if unit.is_enemy():
			continue
		var row_color: Color = Color.WHITE
		var dim_color: Color = Color(0.7, 0.7, 0.7)
		var bg_color: Color = Color.TRANSPARENT
		if unit.id == _selected_id:
			row_color = Color(1.0, 1.0, 0.3)
			dim_color = Color(0.9, 0.9, 0.2)
			bg_color = Color(0.2, 0.3, 0.5, 0.5)
		var row := _make_row()
		var name_lbl := _add_row_cell(
			row, unit.definition.display_name, unit.definition.display_name,
			row_color, false, bg_color, COL_NAME_W, false,
		)
		var class_lbl := _add_row_cell(
			row, CombatUiFormatters.class_symbol(unit), unit.definition.display_name,
			row_color, false, bg_color, COL_CLASS_W, false,
		)
		var stats_text: String = (
			"⭐%d  ♥%d/%d\n💪%d 🛡️%d 🔮%d 👟%d"
			% [
				unit.level, unit.health.current_hp, unit.health.max_hp,
				unit.current_strength, unit.armor, unit.current_magic,
				unit.movement.max_points,
			]
		)
		var stats_lbl := _add_row_cell(row, stats_text, stats_text, dim_color, false, bg_color, COL_STATS_MIN_W, false)
		stats_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		var timeline_info: Dictionary = CombatUiFormatters.format_unit_plan_timeline(
			_board, timeline, unit, statuses,
		)
		var timeline_text: String = String(timeline_info.get("text", "—"))
		var timeline_tooltip: String = String(timeline_info.get("tooltip", ""))
		var timeline_failed: bool = bool(timeline_info.get("failed", false))
		var timeline_col: Color = row_color if plan_active else Color(
			row_color.r * 0.45, row_color.g * 0.45, row_color.b * 0.45,
		)
		var timeline_bg: Color = bg_color.blend(BG_ACTIVE) if plan_active else bg_color
		var timeline_lbl := _add_row_cell(
			row, timeline_text, timeline_tooltip, timeline_col, false, timeline_bg, 0, true,
		)
		timeline_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if timeline_text == "—":
			timeline_lbl.modulate = Color(1, 1, 1, 0.25 if not plan_active else 0.4)
		elif timeline_failed:
			timeline_lbl.add_theme_color_override("font_color", COLOR_FAIL)
			if first_warning.is_empty():
				var steps: Array[TimelineAction] = UnitPlanOrder.ordered_steps_for_unit(timeline, unit.id)
				for step: TimelineAction in steps:
					var reason: String = UnitPlanOrder.status_for_action(timeline, statuses, step)
					if reason != "":
						first_warning = "%s: %s" % [
							unit.definition.display_name,
							CombatUiFormatters.reason_text(reason),
						]
						break
		var row_labels: Array[Label] = [name_lbl, class_lbl, stats_lbl, timeline_lbl]
		var base_colors: Array[Color] = [bg_color, bg_color, bg_color, timeline_bg]
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


func _make_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(row)
	return row


func _add_row_cell(
	row: HBoxContainer,
	text: String,
	tooltip: String,
	col: Color,
	is_header: bool,
	bg_color: Color,
	min_width: int,
	expand: bool,
) -> Label:
	var lbl := _make_cell(text, tooltip, col, is_header, bg_color)
	if expand:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_stretch_ratio = 5.0
	elif min_width > 0:
		lbl.custom_minimum_size.x = float(min_width)
	row.add_child(lbl)
	return lbl


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
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	lbl.add_theme_stylebox_override("normal", sb)
	return lbl
