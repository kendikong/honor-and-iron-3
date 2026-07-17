class_name TacticalSidePanels
extends CanvasLayer

## Left/right combat panels — unit info, tile info, skills, intents, battle log.

const COLOR_SELECT: Color = Color(0.98, 0.86, 0.32, 0.95)
const COLOR_SKILL_DISABLED: Color = Color(0.55, 0.55, 0.55, 0.85)
const LOG_FONT_SIZE: int = 10
const PANEL_WIDTH: int = 280

var _director: CombatDirector
var _map_view: TacticalMapView

var _info_label: RichTextLabel
var _tile_info_label: RichTextLabel
var _intent_label: RichTextLabel
var _skill_list: VBoxContainer
var _log_label: RichTextLabel
var _warn_label: RichTextLabel

var _board: BoardState
var _preview_board: BoardState
var _phase: int = CombatDirector.Phase.PLANNING_PHASE_1
var _selected_id: int = -1
var _selected_ability: int = 0
var _hover_coord: Vector2i = Vector2i(-999, -999)
var _intent_units: Dictionary = {}


func setup(director: CombatDirector, map_view: TacticalMapView) -> void:
	_director = director
	_map_view = map_view
	layer = 21
	_build_ui()
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.ability_selected.connect(_on_ability_selected)
	EventBus.turn_phase_changed.connect(_on_phase_changed)
	EventBus.timeline_changed.connect(func(_t: Timeline, statuses: PackedStringArray) -> void:
		_apply_timeline_warnings(statuses),
	)
	EventBus.action_rejected.connect(_on_action_rejected)
	EventBus.sim_event.connect(_on_sim_event)


func set_hover_coord(coord: Vector2i) -> void:
	if coord == _hover_coord:
		return
	_hover_coord = coord
	_recompute_intent_units()
	_refresh_info()
	_refresh_intent_label()


func set_intent_units(units: Dictionary) -> void:
	_intent_units = units
	_refresh_intent_label()


func set_warning(text: String) -> void:
	if _warn_label == null:
		return
	if text.is_empty():
		_warn_label.visible = false
		_warn_label.text = ""
	else:
		_warn_label.visible = true
		_warn_label.text = "[color=#%s]! %s[/color]" % [TacticalCombatInfo.HEX_DEATH, text]


func _build_ui() -> void:
	var left := _make_panel_column(true)
	add_child(left)
	var right := _make_panel_column(false)
	add_child(right)


func _make_panel_column(left_side: bool) -> Control:
	var anchor := Control.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if left_side:
		anchor.offset_right = -maxf(0.0, get_viewport().get_visible_rect().size.x - float(PANEL_WIDTH) - 16.0)
		anchor.add_theme_constant_override("margin_left", 8)
	else:
		anchor.offset_left = maxf(0.0, get_viewport().get_visible_rect().size.x - float(PANEL_WIDTH) - 16.0)
		anchor.add_theme_constant_override("margin_right", 8)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 72
	col.offset_bottom = -260
	col.add_theme_constant_override("separation", 8)
	anchor.add_child(col)
	if left_side:
		_info_label = _add_rich_panel(col, "Unit Info")
		_tile_info_label = _add_rich_panel(col, "Tile", 72)
		_warn_label = RichTextLabel.new()
		_warn_label.bbcode_enabled = true
		_warn_label.fit_content = true
		_warn_label.visible = false
		col.add_child(_warn_label)
	else:
		_intent_label = _add_rich_panel(col, "Enemy Intent", 100)
		var skill_panel := PanelContainer.new()
		skill_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(skill_panel)
		var skill_margin := MarginContainer.new()
		skill_margin.add_theme_constant_override("margin_left", 8)
		skill_margin.add_theme_constant_override("margin_right", 8)
		skill_margin.add_theme_constant_override("margin_top", 8)
		skill_margin.add_theme_constant_override("margin_bottom", 8)
		skill_panel.add_child(skill_margin)
		var skill_vbox := VBoxContainer.new()
		skill_margin.add_child(skill_vbox)
		var skill_title := Label.new()
		skill_title.text = "Skills"
		skill_title.add_theme_font_size_override("font_size", 14)
		skill_vbox.add_child(skill_title)
		var skill_scroll := ScrollContainer.new()
		skill_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		skill_scroll.custom_minimum_size.y = 180
		skill_vbox.add_child(skill_scroll)
		_skill_list = VBoxContainer.new()
		_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_scroll.add_child(_skill_list)
		var log_panel := PanelContainer.new()
		log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(log_panel)
		var log_margin := MarginContainer.new()
		log_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		log_margin.add_theme_constant_override("margin_left", 8)
		log_margin.add_theme_constant_override("margin_right", 8)
		log_margin.add_theme_constant_override("margin_top", 8)
		log_margin.add_theme_constant_override("margin_bottom", 8)
		log_panel.add_child(log_margin)
		var log_vbox := VBoxContainer.new()
		log_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		log_margin.add_child(log_vbox)
		var log_title := Label.new()
		log_title.text = "Battle Log"
		log_title.add_theme_font_size_override("font_size", 14)
		log_vbox.add_child(log_title)
		_log_label = RichTextLabel.new()
		_log_label.bbcode_enabled = true
		_log_label.scroll_following = true
		_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_log_label.add_theme_font_size_override("normal_font_size", LOG_FONT_SIZE)
		log_vbox.add_child(_log_label)
	return anchor


func _add_rich_panel(parent: VBoxContainer, title: String, min_h: int = 120) -> RichTextLabel:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = min_h
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl)
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = true
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(rich)
	return rich


func _on_board_changed(board: BoardState) -> void:
	_board = board
	_recompute_intent_units()
	_refresh_info()
	_refresh_intent_label()
	_rebuild_ability_buttons()


func _on_preview_updated(result: SimResult) -> void:
	_preview_board = result.final_state
	_recompute_intent_units()
	_refresh_info()
	_refresh_intent_label()
	_rebuild_ability_buttons()


func _on_selection_changed(unit_id: int) -> void:
	_selected_id = unit_id
	_recompute_intent_units()
	_refresh_info()
	_refresh_intent_label()
	_rebuild_ability_buttons()


func _on_ability_selected(index: int) -> void:
	_selected_ability = index
	_rebuild_ability_buttons()


func _on_phase_changed(phase: int) -> void:
	_phase = phase
	_recompute_intent_units()
	_refresh_intent_label()


func _on_action_rejected(reason: String) -> void:
	set_warning(TacticalCombatInfo.reason_text(reason))


func _apply_timeline_warnings(statuses: PackedStringArray) -> void:
	if statuses.is_empty():
		return
	for reason: String in statuses:
		if reason != "":
			set_warning(TacticalCombatInfo.reason_text(reason))
			return
	set_warning("")


func _on_sim_event(event: SimEvent) -> void:
	if _log_label == null:
		return
	match event.type:
		GameEnums.SimEventType.UNIT_DAMAGED:
			var unit_id: int = int(event.data.get("unit", -1))
			var amount: int = int(event.data.get("amount", 0))
			var unit := _board.get_unit_by_id(unit_id) if _board != null else null
			var name: String = unit.definition.display_name if unit != null else "Unit %d" % unit_id
			_append_log("%s takes %d damage" % [name, amount])
		GameEnums.SimEventType.UNIT_DIED:
			var dead_id: int = int(event.data.get("unit", -1))
			var dead := _board.get_unit_by_id(dead_id) if _board != null else null
			var dead_name: String = dead.definition.display_name if dead != null else "Unit %d" % dead_id
			_append_log("%s was defeated" % dead_name)
		GameEnums.SimEventType.ABILITY_USED:
			var actor_id: int = int(event.data.get("actor", -1))
			var actor := _board.get_unit_by_id(actor_id) if _board != null else null
			if actor != null:
				_append_log("%s used an ability" % actor.definition.display_name)


func _append_log(text: String) -> void:
	_log_label.append_text("[font_size=%d]%s[/font_size]\n" % [LOG_FONT_SIZE, text])


func _refresh_info() -> void:
	if _board == null or _info_label == null or _tile_info_label == null:
		return
	var hov: Vector2i = _hover_coord
	_tile_info_label.text = TacticalCombatInfo.tile_info(_board, hov)
	if _selected_id >= 0:
		var u := _board.get_unit_by_id(_selected_id)
		if u != null:
			_info_label.text = TacticalCombatInfo.unit_info(_board, u)
			return
	if not _board.is_in_bounds(hov):
		_info_label.text = ""
		return
	var unit := _board.get_unit_at(hov)
	if unit != null:
		_info_label.text = TacticalCombatInfo.unit_info(_board, unit)
	else:
		_info_label.text = "[color=#%s]Hover a unit or tile for details.[/color]" % TacticalCombatInfo.HEX_DIM


func _refresh_intent_label() -> void:
	if _intent_label == null or _board == null:
		return
	var body: String = TacticalCombatInfo.summarize_intents(_board, _phase, _intent_units)
	_intent_label.text = "💀 Enemy intent:\n%s" % body


func _recompute_intent_units() -> void:
	_intent_units.clear()
	if _board == null:
		return
	if _selected_id >= 0:
		for intent in _board.intents:
			for action: TimelineAction in intent.actions:
				if action.target_unit_id == _selected_id:
					_intent_units[intent.enemy_id] = true
	if _board.is_in_bounds(_hover_coord):
		var hovered: UnitState = _board.get_unit_at(_hover_coord)
		if hovered != null and hovered.is_enemy():
			_intent_units[hovered.id] = true
	_refresh_intent_label()


func _rebuild_ability_buttons() -> void:
	if _skill_list == null:
		return
	for c: Node in _skill_list.get_children():
		_skill_list.remove_child(c)
		c.queue_free()
	if _board == null or _selected_id < 0:
		return
	var unit := _proj_unit(_selected_id)
	if unit == null:
		unit = _board.get_unit_by_id(_selected_id)
	if unit == null or unit.is_enemy():
		return
	var abilities: Array = unit.active_abilities
	for i: int in abilities.size():
		var ability: AbilityData = abilities[i]
		var index: int = i
		var row_btn := Button.new()
		var can_afford: bool = unit.ability.points_left >= ability.action_point_cost
		row_btn.disabled = not can_afford
		row_btn.modulate = COLOR_SELECT if index == _selected_ability else (
			Color.WHITE if can_afford else COLOR_SKILL_DISABLED
		)
		row_btn.pressed.connect(func() -> void:
			if _director != null:
				_director.select_ability(index)
		)
		row_btn.tooltip_text = ability.display_name
		row_btn.custom_minimum_size.y = 44
		_skill_list.add_child(row_btn)
		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_btn.add_child(vbox)
		var name_lbl := Label.new()
		name_lbl.text = ability.display_name
		name_lbl.add_theme_font_size_override("font_size", 10)
		vbox.add_child(name_lbl)
		var stats := Label.new()
		stats.text = "🔵%d  🏹%d" % [ability.action_point_cost, ability.range_tiles]
		stats.add_theme_font_size_override("font_size", 9)
		vbox.add_child(stats)


func _proj_unit(unit_id: int) -> UnitState:
	if _director == null or unit_id < 0:
		return null
	var proj: BoardState = _preview_board
	if proj == null and _director.projected_state != null:
		proj = _director.projected_state
	if proj == null:
		return _board.get_unit_by_id(unit_id) if _board != null else null
	return proj.get_unit_by_id(unit_id)
