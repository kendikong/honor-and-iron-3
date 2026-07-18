class_name TacticalTimelineGrid
extends VBoxContainer

## Party planning table — up to 4 co-op player slots, pre / action / post columns.

const MAX_PARTY_SLOTS: int = 4
const ROW_HEIGHT: int = 46
const COLOR_FAIL: Color = Color(1.0, 0.38, 0.38)
const COLOR_HEADER: Color = Color(0.58, 0.62, 0.70)
const COLOR_MUTED: Color = Color(0.42, 0.45, 0.52)
const COLOR_EMPTY: Color = Color(0.35, 0.38, 0.44)
const COLOR_ROW: Color = Color(0.13, 0.15, 0.19, 0.88)
const COLOR_ROW_SEL: Color = Color(0.18, 0.30, 0.46, 0.95)
const COLOR_ROW_HOVER: Color = Color(0.16, 0.20, 0.28, 0.92)
const COLOR_SLOT_EMPTY: Color = Color(0.10, 0.11, 0.14, 0.55)
const COLOR_ACCENT_PRE: Color = Color(0.35, 0.55, 0.85, 0.18)
const COLOR_ACCENT_ACT: Color = Color(0.85, 0.55, 0.25, 0.18)
const COLOR_ACCENT_POST: Color = Color(0.45, 0.75, 0.45, 0.18)

const W_PLAYER: int = 34
const W_NAME: int = 82
const W_CLASS: int = 34
const W_STATS: int = 188

var _director: CombatDirector
var _board: BoardState
var _phase: int = CombatDirector.Phase.PLANNING
var _selected_id: int = -1
var _timeline_hover_id: int = -1
var _header_font_px: int = 12
var _cell_font_px: int = 12
var _rows_root: VBoxContainer

signal row_hovered(unit_id: int)
signal row_unhovered(unit_id: int)
signal warning_changed(text: String)


func setup(director: CombatDirector) -> void:
	_director = director
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)


func set_board(board: BoardState) -> void:
	_board = board


func set_phase(phase: int) -> void:
	_phase = phase


func set_selected(unit_id: int) -> void:
	_selected_id = unit_id


func apply_font_sizes(header_px: int, cell_px: int) -> void:
	_header_font_px = maxi(9, header_px - 2)
	_cell_font_px = maxi(9, cell_px)


func rebuild(timeline: Timeline, statuses: PackedStringArray) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if _board == null or _director == null:
		return
	var plan_active: bool = CombatDirector.is_planning_phase(_phase) or CombatDirector.is_executing_phase(_phase)
	_add_header_row(plan_active)
	_rows_root = VBoxContainer.new()
	_rows_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_root.add_theme_constant_override("separation", 3)
	add_child(_rows_root)
	var first_warning: String = ""
	var units_by_player: Dictionary = _units_by_player_id()
	for slot: int in range(1, MAX_PARTY_SLOTS + 1):
		var unit: UnitState = units_by_player.get(slot) as UnitState
		var warn: String = _add_party_row(slot, unit, timeline, statuses, plan_active)
		if first_warning.is_empty() and not warn.is_empty():
			first_warning = warn
	warning_changed.emit(first_warning)


func get_hover_unit_id() -> int:
	return _timeline_hover_id


func _units_by_player_id() -> Dictionary:
	var out: Dictionary = {}
	if _board == null:
		return out
	for unit: UnitState in _board.units:
		if unit.is_enemy() or not unit.is_alive():
			continue
		var pid: int = maxi(1, unit.controlling_player_id)
		if not out.has(pid):
			out[pid] = unit
	return out


func _add_header_row(plan_active: bool) -> void:
	var row := _make_row_container(28)
	_add_header_cell(row, "P", W_PLAYER)
	_add_header_cell(row, "Unit", W_NAME)
	_add_header_cell(row, "", W_CLASS)
	_add_header_cell(row, "Stats", W_STATS)
	_add_header_cell(row, "Pre-Move", 0, true, COLOR_ACCENT_PRE if plan_active else Color.TRANSPARENT)
	_add_header_cell(row, "Action", 0, true, COLOR_ACCENT_ACT if plan_active else Color.TRANSPARENT)
	_add_header_cell(row, "Post-Move", 0, true, COLOR_ACCENT_POST if plan_active else Color.TRANSPARENT)
	add_child(row)


func _add_party_row(
	slot: int,
	unit: UnitState,
	timeline: Timeline,
	statuses: PackedStringArray,
	plan_active: bool,
) -> String:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size.y = float(ROW_HEIGHT)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_rows_root.add_child(row_panel)
	var is_empty: bool = unit == null
	var is_selected: bool = unit != null and unit.id == _selected_id
	var row_bg: Color = COLOR_SLOT_EMPTY if is_empty else COLOR_ROW
	if is_selected:
		row_bg = COLOR_ROW_SEL
	row_panel.add_theme_stylebox_override("panel", _panel_style(row_bg, is_selected))
	var row := _make_row_container(0)
	row_panel.add_child(row)
	var player_col: Color = CombatUiFormatters.player_color(slot)
	_add_body_cell(row, "P%d" % slot, "", player_col if not is_empty else COLOR_EMPTY, W_PLAYER, false)
	var name_text: String = "— open —" if is_empty else unit.definition.display_name
	var name_col: Color = COLOR_EMPTY if is_empty else Color.WHITE
	if is_selected and not is_empty:
		name_col = Color(1.0, 0.95, 0.55)
	_add_body_cell(row, name_text, name_text, name_col, W_NAME, false)
	var class_text: String = "" if is_empty else CombatUiFormatters.class_symbol(unit)
	_add_body_cell(row, class_text, unit.definition.display_name if unit != null else "", name_col, W_CLASS, false)
	if is_empty:
		_add_body_cell(row, "—", "", COLOR_MUTED, W_STATS, false)
		_add_plan_cell(row, "—", "", false, COLOR_ACCENT_PRE, plan_active)
		_add_plan_cell(row, "—", "", false, COLOR_ACCENT_ACT, plan_active)
		_add_plan_cell(row, "—", "", false, COLOR_ACCENT_POST, plan_active)
		row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return ""
	var stats_text: String = "Lv%d  HP %d/%d  MOV %d  STR %d" % [
		unit.level,
		unit.health.current_hp,
		unit.health.max_hp,
		unit.movement.max_points,
		unit.current_strength,
	]
	var stats_tip: String = (
		"Level %d · HP %d/%d · MOV %d · STR %d · DEF %d · MAG %d · Armor %d"
		% [
			unit.level, unit.health.current_hp, unit.health.max_hp,
			unit.movement.max_points, unit.current_strength, unit.current_defense,
			unit.current_magic, unit.armor,
		]
	)
	_add_body_cell(row, stats_text, stats_tip, COLOR_MUTED if not is_selected else Color(0.78, 0.82, 0.88), W_STATS, false)
	var slots: Dictionary = _plan_slots_for_unit(timeline, unit.id)
	var warn: String = ""
	var cell_warn: String = _append_plan_cell(
		row, slots.get("pre", []), unit, timeline, statuses, plan_active, COLOR_ACCENT_PRE,
	)
	if not cell_warn.is_empty():
		warn = cell_warn
	cell_warn = _append_plan_cell(
		row, slots.get("action", []), unit, timeline, statuses, plan_active, COLOR_ACCENT_ACT,
	)
	if not cell_warn.is_empty() and warn.is_empty():
		warn = cell_warn
	cell_warn = _append_plan_cell(
		row, slots.get("post", []), unit, timeline, statuses, plan_active, COLOR_ACCENT_POST,
	)
	if not cell_warn.is_empty() and warn.is_empty():
		warn = cell_warn
	var unit_id: int = unit.id
	row_panel.mouse_entered.connect(func() -> void:
		if is_empty:
			return
		_timeline_hover_id = unit_id
		row_hovered.emit(unit_id)
		if unit_id != _selected_id:
			row_panel.add_theme_stylebox_override("panel", _panel_style(COLOR_ROW_HOVER, false))
	)
	row_panel.mouse_exited.connect(func() -> void:
		if is_empty:
			return
		if _timeline_hover_id == unit_id:
			_timeline_hover_id = -1
			row_unhovered.emit(unit_id)
		row_panel.add_theme_stylebox_override("panel", _panel_style(row_bg, is_selected))
	)
	row_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if is_empty:
			return
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if _director != null:
				_director.select_unit(unit_id)
	)
	return warn


func _plan_slots_for_unit(plan: Timeline, unit_id: int) -> Dictionary:
	var pre_moves: Array[TimelineAction] = []
	var abilities: Array[TimelineAction] = []
	var post_moves: Array[TimelineAction] = []
	if plan == null or unit_id < 0:
		return {"pre": pre_moves, "action": abilities, "post": post_moves}
	for action: TimelineAction in plan.entries:
		if action.actor_id != unit_id:
			continue
		match action.type:
			GameEnums.ActionType.ABILITY:
				abilities.append(action)
			GameEnums.ActionType.MOVE, GameEnums.ActionType.FACE:
				if action.move_timing == GameEnums.MoveTiming.POST_ACTION:
					post_moves.append(action)
				else:
					pre_moves.append(action)
	return {"pre": pre_moves, "action": abilities, "post": post_moves}


func _append_plan_cell(
	row: HBoxContainer,
	steps: Array,
	unit: UnitState,
	timeline: Timeline,
	statuses: PackedStringArray,
	plan_active: bool,
	accent: Color,
) -> String:
	var text: String = "—"
	var tooltip: String = "No action queued"
	var failed: bool = false
	var first_warn: String = ""
	if not steps.is_empty():
		var parts: PackedStringArray = []
		var tips: PackedStringArray = []
		for step: TimelineAction in steps:
			parts.append(CombatUiFormatters.action_symbol_text(_board, step, unit))
			tips.append(CombatUiFormatters.describe_action(_board, step))
			var reason: String = UnitPlanOrder.status_for_action(timeline, statuses, step)
			if reason != "":
				failed = true
				if first_warn.is_empty():
					first_warn = "%s: %s" % [
						unit.definition.display_name,
						CombatUiFormatters.reason_text(reason),
					]
		text = " → ".join(parts)
		tooltip = "\n".join(tips)
	var lbl := _add_plan_cell(row, text, tooltip, failed, accent, plan_active)
	if text == "—":
		lbl.modulate = Color(1, 1, 1, 0.35 if plan_active else 0.22)
	return first_warn


func _make_row_container(min_height: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if min_height > 0:
		row.custom_minimum_size.y = float(min_height)
	return row


func _add_header_cell(
	row: HBoxContainer,
	text: String,
	width: int,
	expand: bool = false,
	bg: Color = Color.TRANSPARENT,
) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _header_font_px)
	lbl.add_theme_color_override("font_color", COLOR_HEADER)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_stretch_ratio = 1.0
	elif width > 0:
		lbl.custom_minimum_size.x = float(width)
	if bg.a > 0.01:
		lbl.add_theme_stylebox_override("normal", _cell_style(bg))
	row.add_child(lbl)


func _add_body_cell(
	row: HBoxContainer,
	text: String,
	tooltip: String,
	col: Color,
	width: int,
	expand: bool,
) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _cell_font_px)
	lbl.add_theme_color_override("font_color", col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_text = true
	if tooltip != "":
		lbl.tooltip_text = tooltip
	if expand:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif width > 0:
		lbl.custom_minimum_size.x = float(width)
	row.add_child(lbl)
	return lbl


func _add_plan_cell(
	row: HBoxContainer,
	text: String,
	tooltip: String,
	failed: bool,
	accent: Color,
	plan_active: bool,
) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _cell_font_px)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.clip_text = true
	if tooltip != "":
		lbl.tooltip_text = tooltip
	if failed:
		lbl.add_theme_color_override("font_color", COLOR_FAIL)
	elif plan_active:
		lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	else:
		lbl.add_theme_color_override("font_color", COLOR_MUTED)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_stretch_ratio = 1.0
	var bg: Color = accent if plan_active else Color(0.12, 0.13, 0.17, 0.4)
	lbl.add_theme_stylebox_override("normal", _cell_style(bg))
	row.add_child(lbl)
	return lbl


func _panel_style(bg: Color, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if selected:
		sb.border_color = Color(0.45, 0.72, 1.0, 0.85)
		sb.set_border_width_all(1)
	else:
		sb.border_color = Color(0.22, 0.25, 0.32, 0.9)
		sb.set_border_width_all(1)
	return sb


func _cell_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb
