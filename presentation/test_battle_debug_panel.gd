class_name TestBattleDebugPanel
extends CanvasLayer

## Training-mode debug controls — class swap, passives, dummy management.

const PANEL_WIDTH: int = 340

var _map_view: TestBattleMapView
var _session: TestBattleSession
var _director: CombatDirector

var _root: PanelContainer
var _body_scroll: ScrollContainer
var _collapse_btn: Button
var _collapsed: bool = false
var _class_option: OptionButton
var _passive_box: VBoxContainer
var _passive_checks: Dictionary = {}
var _unkillable_check: CheckBox
var _infinite_ap_check: CheckBox
var _status_label: Label
var _populating_class_options: bool = false


func setup(
	map_view: TestBattleMapView,
	session: TestBattleSession,
	director: CombatDirector,
) -> void:
	_map_view = map_view
	_session = session
	_director = director
	layer = 25
	_build_ui()
	_refresh_class_options()
	_rebuild_passive_list()


func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.name = "Panel"
	_root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_root.offset_top = 8.0
	_root.offset_right = -8.0
	_root.offset_left = -float(PANEL_WIDTH + 8)
	_root.custom_minimum_size = Vector2(PANEL_WIDTH, 640.0)
	add_child(_root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_root.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	margin.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	outer.add_child(header)

	var title := Label.new()
	title.text = "Skill Test Arena"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)

	_collapse_btn = Button.new()
	_collapse_btn.text = "▼"
	_collapse_btn.tooltip_text = "Collapse debug panel"
	_collapse_btn.custom_minimum_size = Vector2(28.0, 24.0)
	_collapse_btn.pressed.connect(_toggle_collapsed)
	header.add_child(_collapse_btn)

	_body_scroll = ScrollContainer.new()
	_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_scroll.custom_minimum_size = Vector2(PANEL_WIDTH - 20, 600.0)
	outer.add_child(_body_scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	_body_scroll.add_child(body)

	_add_label(body, "10×10 grass — real combat pipeline")

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	body.add_child(_status_label)

	_add_heading(body, "Player Class")
	_class_option = OptionButton.new()
	_class_option.item_selected.connect(_on_class_selected)
	body.add_child(_class_option)

	_add_heading(body, "Passives")
	_passive_box = VBoxContainer.new()
	_passive_box.add_theme_constant_override("separation", 4)
	body.add_child(_passive_box)

	_unkillable_check = CheckBox.new()
	_unkillable_check.text = "Training dummies unkillable (auto-respawn)"
	_unkillable_check.button_pressed = _session.unkillable_dummies
	_unkillable_check.toggled.connect(func(on: bool) -> void:
		_session.unkillable_dummies = on
	)
	body.add_child(_unkillable_check)

	_infinite_ap_check = CheckBox.new()
	_infinite_ap_check.text = "Unlimited actions per turn (+ high AP)"
	_infinite_ap_check.button_pressed = _session.infinite_player_ap
	_infinite_ap_check.toggled.connect(func(on: bool) -> void:
		_session.infinite_player_ap = on
		_map_view.apply_training_board()
	)
	body.add_child(_infinite_ap_check)

	_add_button(body, "Respawn Training Dummies", _on_respawn_dummies_pressed)
	_add_button(body, "Add Dummy (east of player)", _on_add_dummy_pressed)
	_add_button(body, "Add Ally (west slot)", _on_add_player_pressed)
	_add_button(body, "Reset Turn Plan", _on_reset_turn_pressed)
	_add_button(body, "Full Arena Reset", _on_full_reset_pressed)


func _refresh_class_options() -> void:
	_populating_class_options = true
	_class_option.clear()
	var ids: Array[StringName] = DataLibrary.get_player_class_ids()
	for i: int in range(ids.size()):
		var class_id: StringName = ids[i]
		var def: UnitData = DataLibrary.get_unit(class_id)
		var label: String = def.display_name if def != null else String(class_id)
		_class_option.add_item(label, i)
		_class_option.set_item_metadata(i, class_id)
		if class_id == _session.player_class_id:
			_class_option.select(i)
	_populating_class_options = false


func _rebuild_passive_list() -> void:
	for child: Node in _passive_box.get_children():
		child.queue_free()
	_passive_checks.clear()
	var def: UnitData = DataLibrary.get_unit(_session.player_class_id)
	if def == null:
		return
	for passive: PassiveData in def.passives:
		var check := CheckBox.new()
		check.text = passive.display_name
		check.button_pressed = bool(_session.passive_enabled.get(passive.id, true))
		check.toggled.connect(_on_passive_toggled.bind(passive.id))
		_passive_box.add_child(check)
		_passive_checks[passive.id] = check


func _on_class_selected(index: int) -> void:
	if _populating_class_options:
		return
	var class_id: Variant = _class_option.get_item_metadata(index)
	if class_id is StringName:
		_session.player_class_id = class_id
		_session.set_all_passives_enabled(_session.player_class_id, true)
		_rebuild_passive_list()
		_apply_class_and_passives()


func _on_passive_toggled(on: bool, passive_id: StringName) -> void:
	_session.passive_enabled[passive_id] = on
	_apply_class_and_passives()


func _apply_class_and_passives() -> void:
	_map_view.apply_training_board()
	_set_status("Applied %s loadout." % String(_session.player_class_id))


func _on_respawn_dummies_pressed() -> void:
	_map_view.apply_training_board()
	_set_status("Training dummies respawned.")


func _on_add_dummy_pressed() -> void:
	var preferred: Vector2i = (
		TestBattleSession.DEFAULT_DUMMY_CELL
		+ Vector2i(_session.dummy_coords.size(), 0)
	)
	var result: Dictionary = _session.try_add_dummy_at(_map_view.get_live_board(), preferred)
	if not bool(result.get("ok", false)):
		_set_status(String(result.get("reason", "Could not add dummy")))
		return
	_map_view.apply_training_board()
	_set_status("Added dummy at %s." % result["coord"])


func _on_add_player_pressed() -> void:
	var preferred: Vector2i = (
		TestBattleSession.DEFAULT_PLAYER_CELL
		+ Vector2i(-_session.extra_player_coords.size() - 1, 0)
	)
	var result: Dictionary = _session.try_add_player_at(_map_view.get_live_board(), preferred)
	if not bool(result.get("ok", false)):
		_set_status(String(result.get("reason", "Could not add ally")))
		return
	_map_view.apply_training_board()
	_set_status("Added ally at %s." % result["coord"])


func _on_reset_turn_pressed() -> void:
	if _director != null:
		_director.restart_turn()
	_set_status("Turn plan cleared.")


func _on_full_reset_pressed() -> void:
	_session.reset_defaults()
	_refresh_class_options()
	_rebuild_passive_list()
	_unkillable_check.button_pressed = _session.unkillable_dummies
	_infinite_ap_check.button_pressed = _session.infinite_player_ap
	_map_view.apply_training_board()
	_set_status("Arena reset to defaults.")


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _toggle_collapsed() -> void:
	_collapsed = not _collapsed
	_body_scroll.visible = not _collapsed
	_collapse_btn.text = "▶" if _collapsed else "▼"
	_collapse_btn.tooltip_text = "Expand debug panel" if _collapsed else "Collapse debug panel"
	if _collapsed:
		_root.custom_minimum_size = Vector2(PANEL_WIDTH, 48.0)
	else:
		_root.custom_minimum_size = Vector2(PANEL_WIDTH, 640.0)


static func _add_heading(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)


static func _add_label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


static func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	parent.add_child(btn)
