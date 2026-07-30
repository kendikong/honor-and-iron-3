class_name TacticalTimelineGrid
extends VBoxContainer

## Party planning table — up to 4 co-op player slots, pre / action / post columns.

const MAX_PARTY_SLOTS: int = 4
const W_PLAYER: int = 32
const W_NAME: int = 76
const W_CLASS: int = 32
const W_STATS_MIN: int = 228
const ROW_HEIGHT: int = 40
const ROW_INSET: int = 8
const COL_SEPARATION: int = 14
const STAT_CHIP_SEPARATION: int = 12
const STAT_FILL_RATIO: float = 0.75
const INFO_COL_GAP: int = 6
const PLAN_COL_SEPARATION: int = 12
const STRETCH_INFO: float = 4.0
const STRETCH_PLAN_TOTAL: float = 6.0
const STRETCH_PRE: float = 1.0
const STRETCH_ACTION: float = 2.0
const STRETCH_POST: float = 1.0
const COLOR_FAIL: Color = Color(1.0, 0.38, 0.38)
const COLOR_HEADER: Color = Color(0.58, 0.62, 0.70)
const COLOR_MUTED: Color = Color(0.58, 0.62, 0.70)
const COLOR_EMPTY: Color = Color(0.35, 0.38, 0.44)
const COLOR_ROW: Color = Color(0.13, 0.15, 0.19, 0.88)
const COLOR_ROW_SEL: Color = Color(0.18, 0.30, 0.46, 0.95)
const COLOR_ROW_HOVER: Color = Color(0.16, 0.20, 0.28, 0.92)
const COLOR_ROW_EXHAUSTED: Color = Color(0.09, 0.10, 0.12, 0.82)
const COLOR_PLAN_EXHAUSTED: Color = Color(0.48, 0.50, 0.54, 1.0)
const COLOR_SLOT_EMPTY: Color = Color(0.10, 0.11, 0.14, 0.55)
const COLOR_PENDING_PLAN: Color = Color(0.92, 0.94, 0.98)
const PENDING_PLAN_PULSE_LOW: float = 0.42
const PENDING_PLAN_PULSE_HIGH: float = 0.90
const COLOR_ACCENT_PRE: Color = Color(0.35, 0.55, 0.85, 0.18)
const COLOR_ACCENT_ACT: Color = Color(0.85, 0.55, 0.25, 0.18)
const COLOR_ACCENT_POST: Color = Color(0.45, 0.75, 0.45, 0.18)

var _director: CombatDirector
var _board: BoardState
var _display_board: BoardState
var _planning_input: CombatPlanningInput
var _phase: int = CombatDirector.Phase.PLANNING
var _selected_id: int = -1
var _timeline_hover_id: int = -1
var _header_font_px: int = 12
var _cell_font_px: int = 12
var _rows_root: VBoxContainer
var _row_panels: Dictionary = {}
var _last_row_click_unit: int = -1
var _last_row_click_ms: int = 0
var _pending_plan_labels: Array[Label] = []
var _ghost_pulse_phase: float = 0.0

signal row_hovered(unit_id: int)
signal row_unhovered(unit_id: int)
signal warning_changed(text: String)


func setup(director: CombatDirector) -> void:
	_director = director
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 2)
	set_process(true)


func _process(delta: float) -> void:
	if _pending_plan_labels.is_empty():
		return
	_ghost_pulse_phase += delta * 2.4
	var half_span: float = (PENDING_PLAN_PULSE_HIGH - PENDING_PLAN_PULSE_LOW) * 0.5
	var pulse: float = PENDING_PLAN_PULSE_LOW + half_span + half_span * sin(_ghost_pulse_phase)
	for lbl: Label in _pending_plan_labels:
		if lbl != null and is_instance_valid(lbl):
			lbl.modulate = Color(1.0, 1.0, 1.0, pulse)


func bind_planning_input(input: CombatPlanningInput) -> void:
	_planning_input = input


func set_board(board: BoardState) -> void:
	_board = board


func set_display_board(board: BoardState) -> void:
	_display_board = board


func set_phase(phase: int) -> void:
	_phase = phase


func set_selected(unit_id: int) -> void:
	_selected_id = unit_id


func apply_font_sizes(header_px: int, cell_px: int) -> void:
	_header_font_px = maxi(9, header_px - 2)
	_cell_font_px = maxi(9, cell_px)


func rebuild(timeline: Timeline, statuses: PackedStringArray) -> void:
	_pending_plan_labels.clear()
	_row_panels.clear()
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


func apply_unit_wait_marker(unit_id: int, waiting: bool) -> void:
	var row_panel: PanelContainer = _row_panels.get(unit_id) as PanelContainer
	if row_panel == null:
		return
	var is_selected: bool = unit_id == _selected_id
	var row_bg: Color = COLOR_ROW_EXHAUSTED if waiting else (
		COLOR_ROW_SEL if is_selected else COLOR_ROW
	)
	row_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(row_bg, is_selected and not waiting),
	)
	var plan: Control = row_panel.get_meta(&"plan_section") as Control
	if plan != null:
		plan.modulate = COLOR_PLAN_EXHAUSTED if waiting else Color.WHITE


func get_hover_unit_id() -> int:
	return _timeline_hover_id


func _units_by_player_id() -> Dictionary:
	var out: Dictionary = {}
	var source: BoardState = _display_board if _display_board != null else _board
	if source == null:
		return out
	for unit: UnitState in source.units:
		if unit.is_enemy() or not unit.is_alive():
			continue
		var pid: int = maxi(1, unit.controlling_player_id)
		if not out.has(pid):
			out[pid] = unit
	return out


func _add_header_row(plan_active: bool) -> void:
	var row := _make_row_container(22)
	var info := _make_info_section()
	row.add_child(info)
	_add_header_cell(info, "P", W_PLAYER)
	_add_info_gap(info)
	_add_header_cell(info, "Unit", W_NAME)
	_add_header_cell(info, "", W_CLASS)
	_add_info_gap(info)
	var stats_shell: Dictionary = _make_stats_column_shell()
	info.add_child(stats_shell["root"])
	var stats_hdr := Label.new()
	stats_hdr.text = "Stats"
	stats_hdr.add_theme_font_size_override("font_size", _header_font_px)
	stats_hdr.add_theme_color_override("font_color", COLOR_HEADER)
	stats_hdr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_shell["chips"].add_child(stats_hdr)
	var plan := _make_plan_section()
	row.add_child(plan)
	_add_plan_header_cell(plan, "Pre-Move", STRETCH_PRE, COLOR_ACCENT_PRE if plan_active else Color.TRANSPARENT)
	_add_plan_header_cell(plan, "Action", STRETCH_ACTION, COLOR_ACCENT_ACT if plan_active else Color.TRANSPARENT)
	_add_plan_header_cell(plan, "Post-Move", STRETCH_POST, COLOR_ACCENT_POST if plan_active else Color.TRANSPARENT)
	add_child(_wrap_row_inset(row))


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
	var is_exhausted: bool = (
		unit != null and _director != null and _director.unit_has_wait_planned(unit.id)
	)
	var row_bg: Color = COLOR_SLOT_EMPTY if is_empty else COLOR_ROW
	if is_exhausted:
		row_bg = COLOR_ROW_EXHAUSTED
	elif is_selected:
		row_bg = COLOR_ROW_SEL
	row_panel.add_theme_stylebox_override("panel", _panel_style(row_bg, is_selected))
	var row := _make_row_container(0)
	var info := _make_info_section()
	row.add_child(info)
	var plan := _make_plan_section()
	row.add_child(plan)
	if is_exhausted:
		plan.modulate = COLOR_PLAN_EXHAUSTED
	row_panel.add_child(_wrap_row_inset(row))
	if unit != null:
		_row_panels[unit.id] = row_panel
		row_panel.set_meta(&"plan_section", plan)
	var player_col: Color = CombatUiFormatters.player_color(slot) if not is_empty else COLOR_EMPTY
	_add_body_cell(info, "P%d" % slot, "", player_col, W_PLAYER, false)
	_add_info_gap(info)
	var name_text: String = "— open —" if is_empty else unit.definition.display_name
	var name_col: Color = COLOR_EMPTY if is_empty else Color.WHITE
	if is_selected and not is_empty:
		name_col = Color(1.0, 0.95, 0.55)
	_add_body_cell(info, name_text, name_text, name_col, W_NAME, false)
	var class_text: String = "" if is_empty else CombatUiFormatters.class_symbol(unit)
	_add_body_cell(info, class_text, unit.definition.display_name if unit != null else "", name_col, W_CLASS, false)
	_add_info_gap(info)
	if is_empty:
		var stats_shell: Dictionary = _make_stats_column_shell()
		info.add_child(stats_shell["root"])
		var empty_lbl := Label.new()
		empty_lbl.text = "—"
		empty_lbl.add_theme_font_size_override("font_size", _cell_font_px)
		empty_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_shell["chips"].add_child(empty_lbl)
		_add_plan_cell(plan, "—", "", false, COLOR_ACCENT_PRE, plan_active, STRETCH_PRE)
		_add_plan_cell(plan, "—", "", false, COLOR_ACCENT_ACT, plan_active, STRETCH_ACTION)
		_add_plan_cell(plan, "—", "", false, COLOR_ACCENT_POST, plan_active, STRETCH_POST)
		row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return ""
	var stats_col: Color = Color(0.72, 0.76, 0.82) if is_selected else COLOR_MUTED
	_add_stats_cells(info, unit, stats_col)
	var slots: Dictionary = _plan_slots_for_unit(timeline, unit.id)
	var ghost_slots: Dictionary = {}
	if _planning_input != null:
		ghost_slots = _planning_input.timeline_ghost_slots(unit.id)
	var warn: String = ""
	var exhausted_tooltip: String = "Waiting — no further actions this phase" if is_exhausted else ""
	var plan_board: BoardState = _board
	if _director != null and _director.base_board != null:
		plan_board = _director.base_board
	var cell_warn: String = _append_plan_cell(
		plan, slots.get("pre", []), unit, timeline, statuses, plan_active, COLOR_ACCENT_PRE, STRETCH_PRE,
		is_exhausted, exhausted_tooltip, ghost_slots.get("pre", []) as Array, plan_board,
	)
	if not cell_warn.is_empty():
		warn = cell_warn
	cell_warn = _append_plan_cell(
		plan, slots.get("action", []), unit, timeline, statuses, plan_active, COLOR_ACCENT_ACT, STRETCH_ACTION,
		is_exhausted, exhausted_tooltip, ghost_slots.get("action", []) as Array, plan_board,
	)
	if not cell_warn.is_empty() and warn.is_empty():
		warn = cell_warn
	cell_warn = _append_plan_cell(
		plan, slots.get("post", []), unit, timeline, statuses, plan_active, COLOR_ACCENT_POST, STRETCH_POST,
		is_exhausted, exhausted_tooltip, ghost_slots.get("post", []) as Array, plan_board,
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
			var now_ms: int = Time.get_ticks_msec()
			if unit_id == _last_row_click_unit and (now_ms - _last_row_click_ms) < 450:
				if _director != null:
					_director.rpc_plan_wait(unit_id)
				_last_row_click_unit = -1
				_last_row_click_ms = 0
				return
			_last_row_click_unit = unit_id
			_last_row_click_ms = now_ms
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
				if action.ability != null and action.ability.is_movement_kind():
					pre_moves.append(action)
				elif action.ability == null or action.ability.kind != GameEnums.AbilityKind.UNIVERSAL_WAIT:
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
	stretch: float,
	exhausted: bool = false,
	exhausted_tooltip: String = "",
	ghost_steps: Array = [],
	plan_board: BoardState = null,
) -> String:
	var board: BoardState = plan_board if plan_board != null else _board
	var text: String = "—"
	var tooltip: String = exhausted_tooltip if exhausted else "No action queued"
	var failed: bool = false
	var first_warn: String = ""
	if not steps.is_empty():
		var parts: PackedStringArray = []
		var tips: PackedStringArray = []
		for step: TimelineAction in steps:
			var symbol: String = CombatUiFormatters.action_symbol_text(board, step, unit, timeline)
			if symbol == "":
				continue
			parts.append(symbol)
			tips.append(CombatUiFormatters.describe_action(board, step, timeline))
			var reason: String = UnitPlanOrder.status_for_action(timeline, statuses, step)
			if reason != "":
				failed = true
				if first_warn.is_empty():
					first_warn = "%s: %s" % [
						unit.definition.display_name,
						CombatUiFormatters.reason_text(reason),
					]
		if not parts.is_empty():
			text = " → ".join(parts)
			tooltip = "\n".join(tips)
		elif exhausted:
			tooltip = exhausted_tooltip
	var ghost_text: String = ""
	var ghost_tooltip: String = ""
	if not ghost_steps.is_empty():
		var ghost_parts: PackedStringArray = []
		var ghost_tips: PackedStringArray = []
		for step: Variant in ghost_steps:
			if not step is TimelineAction:
				continue
			var ghost_action: TimelineAction = step as TimelineAction
			var symbol: String = CombatUiFormatters.action_symbol_text(board, ghost_action, unit, timeline)
			if symbol == "":
				continue
			ghost_parts.append(symbol)
			ghost_tips.append(CombatUiFormatters.describe_action(board, ghost_action, timeline))
		if not ghost_parts.is_empty():
			ghost_text = " → ".join(ghost_parts)
			ghost_tooltip = "Pending — click to commit\n" + "\n".join(ghost_tips)
	if ghost_text != "" and text == "—":
		_add_pending_plan_cell(
			row, ghost_text, ghost_tooltip, accent, plan_active, stretch,
		)
		return first_warn
	if ghost_text == "":
		var lbl := _add_plan_cell(row, text, tooltip, failed, accent, plan_active, stretch)
		if text == "—":
			var empty_alpha: float = 0.35 if plan_active else 0.22
			if exhausted:
				empty_alpha = 0.28
			lbl.modulate = Color(1, 1, 1, empty_alpha)
		return first_warn
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	var bg: Color = accent if plan_active else Color(0.12, 0.13, 0.17, 0.4)
	panel.add_theme_stylebox_override("panel", _cell_style(bg))
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)
	row.add_child(panel)
	var committed_lbl := _make_plan_text_label(text, tooltip, failed, plan_active)
	inner.add_child(committed_lbl)
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", _cell_font_px)
	arrow.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72, 0.55))
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(arrow)
	var ghost_lbl := _make_plan_text_label(ghost_text, ghost_tooltip, false, plan_active, true)
	inner.add_child(ghost_lbl)
	_pending_plan_labels.append(ghost_lbl)
	return first_warn


func _add_pending_plan_cell(
	row: HBoxContainer,
	text: String,
	tooltip: String,
	accent: Color,
	plan_active: bool,
	stretch: float,
) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	var glow_bg: Color = accent
	if plan_active:
		glow_bg = Color(accent.r, accent.g, accent.b, minf(accent.a + 0.06, 0.28))
	else:
		glow_bg = Color(0.12, 0.13, 0.17, 0.4)
	panel.add_theme_stylebox_override("panel", _cell_style(glow_bg))
	var lbl := _make_plan_text_label(text, tooltip, false, plan_active, true)
	panel.add_child(lbl)
	row.add_child(panel)
	_pending_plan_labels.append(lbl)
	return lbl


func _make_plan_text_label(
	text: String,
	tooltip: String,
	failed: bool,
	plan_active: bool,
	pending: bool = false,
) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _cell_font_px)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.clip_text = true
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tooltip != "":
		lbl.tooltip_text = tooltip
	if pending:
		lbl.add_theme_color_override("font_color", COLOR_PENDING_PLAN)
	elif failed:
		lbl.add_theme_color_override("font_color", COLOR_FAIL)
	elif plan_active:
		lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	else:
		lbl.add_theme_color_override("font_color", COLOR_MUTED)
	return lbl


func _make_row_container(min_height: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if min_height > 0:
		row.custom_minimum_size.y = float(min_height)
	return row


func _wrap_row_inset(row: HBoxContainer) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", ROW_INSET)
	margin.add_theme_constant_override("margin_right", ROW_INSET)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(row)
	return margin


func _make_info_section() -> HBoxContainer:
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", COL_SEPARATION)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_stretch_ratio = STRETCH_INFO
	return info


func _make_plan_section() -> HBoxContainer:
	var plan := HBoxContainer.new()
	plan.add_theme_constant_override("separation", PLAN_COL_SEPARATION)
	plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan.size_flags_stretch_ratio = STRETCH_PLAN_TOTAL
	return plan


func _add_info_gap(row: HBoxContainer) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.x = float(INFO_COL_GAP)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)


func _make_stats_column_shell() -> Dictionary:
	var root := HBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size.x = float(W_STATS_MIN)
	var pad_ratio: float = (1.0 - STAT_FILL_RATIO) * 0.5
	var left_pad := Control.new()
	left_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_pad.size_flags_stretch_ratio = pad_ratio
	left_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left_pad)
	var chips := HBoxContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.size_flags_stretch_ratio = STAT_FILL_RATIO
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", STAT_CHIP_SEPARATION)
	chips.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(chips)
	var right_pad := Control.new()
	right_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_pad.size_flags_stretch_ratio = pad_ratio
	right_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right_pad)
	return {"root": root, "chips": chips}


func _add_stats_cells(row: HBoxContainer, unit: UnitState, col: Color) -> void:
	var stats_shell: Dictionary = _make_stats_column_shell()
	row.add_child(stats_shell["root"])
	var chips: HBoxContainer = stats_shell["chips"] as HBoxContainer
	var board: BoardState = _display_board if _display_board != null else _board
	_add_stat_chip(
		chips,
		"%s%d" % [PlanningIcons.STAT_LEVEL, unit.level],
		"Level — unit experience tier",
		col,
	)
	_add_stat_chip(
		chips,
		"%s%d/%d" % [PlanningIcons.STAT_HP, unit.health.current_hp, unit.health.max_hp],
		"Health — current / maximum hit points",
		col,
	)
	for stat_type: GameEnums.StatType in [
		GameEnums.StatType.PHYSICAL,
		GameEnums.StatType.MAGICAL,
		GameEnums.StatType.DEFENSE,
	]:
		var chip: Dictionary = CombatUiFormatters.timeline_stat_chip(unit, stat_type, board)
		var chip_col: Color = chip.get("color", col) as Color
		if chip_col == Color.WHITE:
			chip_col = col
		_add_stat_chip(chips, str(chip.get("text", "")), str(chip.get("tooltip", "")), chip_col)
	_add_stat_chip(
		chips,
		"%s%d" % [PlanningIcons.STAT_ARMOR, unit.armor],
		"Armor — absorbs damage before HP",
		col,
	)
	var uses_run: bool = (
		_planning_input != null and _planning_input.unit_move_requires_run(unit.id)
	)
	var mp_left: int = unit.movement.points_left
	if _planning_input != null:
		var display_mp: int = _planning_input.planning_display_mp_left(unit.id)
		if display_mp >= 0:
			mp_left = display_mp
	_add_stat_chip(
		chips,
		"%s%d/%d" % [
			PlanningIcons.move_glyph(uses_run),
			mp_left,
			unit.movement.max_points,
		],
		(
			"Run — remaining / maximum tiles this turn"
			if uses_run
			else "Movement — remaining / maximum tiles this turn"
		),
		col,
	)
	var ap_left: int = unit.ability.points_left
	if _planning_input != null:
		var display_ap: int = _planning_input.planning_display_ap_left(unit.id)
		if display_ap >= 0:
			ap_left = display_ap
	_add_stat_chip(
		chips,
		"%s%d/%d" % [PlanningIcons.STAT_AP, ap_left, unit.ability.max_points],
		"Action Points — remaining / maximum per turn",
		col,
	)


func _add_stat_chip(row: HBoxContainer, text: String, tooltip: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.tooltip_text = tooltip
	lbl.add_theme_font_size_override("font_size", _cell_font_px)
	lbl.add_theme_color_override("font_color", col)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_stretch_ratio = 1.0
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(lbl)


func _add_header_cell(
	row: HBoxContainer,
	text: String,
	width: int,
	expand: bool = false,
) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _header_font_px)
	lbl.add_theme_color_override("font_color", COLOR_HEADER)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if width > 0:
			lbl.custom_minimum_size.x = float(width)
	elif width > 0:
		lbl.custom_minimum_size.x = float(width)
	row.add_child(lbl)


func _add_plan_header_cell(row: HBoxContainer, text: String, stretch: float, bg: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _header_font_px)
	lbl.add_theme_color_override("font_color", COLOR_HEADER)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_stretch_ratio = stretch
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
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.clip_text = false
	if tooltip != "":
		lbl.tooltip_text = tooltip
	if expand:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if width > 0:
			lbl.custom_minimum_size.x = float(width)
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
	stretch: float,
) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _cell_font_px)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	lbl.size_flags_stretch_ratio = stretch
	var bg: Color = accent if plan_active else Color(0.12, 0.13, 0.17, 0.4)
	lbl.add_theme_stylebox_override("normal", _cell_style(bg))
	row.add_child(lbl)
	return lbl


func _panel_style(bg: Color, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
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
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb
