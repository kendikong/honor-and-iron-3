class_name TestBattleDebugPanel
extends CanvasLayer

## Training-mode debug controls — class swap, level, passives, skills, dummy management.

const PANEL_WIDTH: int = 340
const PANEL_HEIGHT_EXPANDED: float = 640.0
const PANEL_HEIGHT_COLLAPSED: float = 48.0

var _map_view: TestBattleMapView
var _session: TestBattleSession
var _director: CombatDirector

var _root: PanelContainer
var _body_scroll: ScrollContainer
var _collapse_btn: Button
var _collapsed: bool = false
var _class_option: OptionButton
var _level_spin: SpinBox
var _passive_box: VBoxContainer
var _passive_checks: Dictionary = {}
var _skill_box: VBoxContainer
var _skill_checks: Dictionary = {}
var _unkillable_check: CheckBox
var _infinite_ap_check: CheckBox
var _status_label: Label
var _populating_class_options: bool = false
var _updating_hover_sliders: bool = false
var _hover_throttle_slider: HSlider
var _hover_sim_slider: HSlider
var _overlay_fps_slider: HSlider
var _hover_throttle_value: Label
var _hover_sim_value: Label
var _overlay_fps_value: Label


func setup(
	map_view: TestBattleMapView,
	session: TestBattleSession,
	director: CombatDirector,
) -> void:
	_map_view = map_view
	_session = session
	_director = director
	layer = 25
	_load_settings()
	_build_ui()
	_set_collapsed(_collapsed)
	_refresh_class_options()
	_rebuild_passive_list()
	_rebuild_skill_list()
	
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(TestBattleSession.PREFS_PATH) == OK:
		_collapsed = cfg.get_value("debug", "collapsed", false)
	_session.load_prefs()


func _save_settings() -> void:
	_session.save_prefs(_collapsed)

func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.name = "Panel"
	# Anchor to bottom-left so the panel sits above the bottom left corner.
	_root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_root.offset_bottom = -8.0
	_root.offset_left = 8.0
	_root.offset_right = float(PANEL_WIDTH + 8)
	_root.offset_top = -PANEL_HEIGHT_EXPANDED
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

	# --- Header ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	outer.add_child(header)

	var title := Label.new()
	title.text = "Skill Test Arena"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)

	_collapse_btn = Button.new()
	_collapse_btn.text = "▲"
	_collapse_btn.tooltip_text = "Collapse debug panel"
	_collapse_btn.custom_minimum_size = Vector2(28.0, 24.0)
	_collapse_btn.pressed.connect(_on_collapse_pressed)
	header.add_child(_collapse_btn)

	# --- Scrollable body ---
	_body_scroll = ScrollContainer.new()
	_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_scroll.custom_minimum_size = Vector2(PANEL_WIDTH - 20, PANEL_HEIGHT_EXPANDED - 60.0)
	outer.add_child(_body_scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	_body_scroll.add_child(body)

	_add_label(body, "10×10 grass — real combat pipeline")

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	body.add_child(_status_label)

	_add_heading(body, "FPS / Hover throttle")
	_add_label(body, "Drag right if circling drops frames. 0 = full quality. 100 = max FPS. Click still commits for real.")
	_hover_throttle_slider = _add_debug_slider(
		body,
		"Throttle",
		0.0,
		100.0,
		1.0,
		_game_settings_or_default().hover_throttle_pct,
		"%",
		func(v: float) -> void:
			if _updating_hover_sliders:
				return
			var settings := _game_settings()
			if settings == null:
				return
			settings.apply_hover_throttle_preset(v)
			_sync_hover_slider_displays()
			_persist_hover_settings(),
	)
	_hover_throttle_value = _hover_throttle_slider.get_meta("value_label") as Label
	_hover_sim_slider = _add_debug_slider(
		body,
		"Hover sim delay",
		0.0,
		400.0,
		5.0,
		_game_settings_or_default().hover_sim_interval_ms,
		"ms",
		func(v: float) -> void:
			if _updating_hover_sliders:
				return
			var settings := _game_settings()
			if settings == null:
				return
			settings.hover_sim_interval_ms = v
			_persist_hover_settings(),
	)
	_hover_sim_value = _hover_sim_slider.get_meta("value_label") as Label
	_overlay_fps_slider = _add_debug_slider(
		body,
		"Overlay anim FPS",
		0.0,
		30.0,
		1.0,
		_game_settings_or_default().planning_overlay_fps,
		"fps",
		func(v: float) -> void:
			if _updating_hover_sliders:
				return
			var settings := _game_settings()
			if settings == null:
				return
			settings.planning_overlay_fps = v
			_persist_hover_settings(),
	)
	_overlay_fps_value = _overlay_fps_slider.get_meta("value_label") as Label
	_sync_hover_slider_displays()

	# --- Player Class ---
	_add_heading(body, "Player Class")
	_class_option = OptionButton.new()
	_class_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_option.item_selected.connect(_on_class_selected)
	body.add_child(_class_option)

	# --- Player Level ---
	_add_heading(body, "Player Level")
	_level_spin = SpinBox.new()
	_level_spin.min_value = 1
	_level_spin.max_value = 99
	_level_spin.step = 1
	_level_spin.value = _session.player_level
	_level_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_spin.value_changed.connect(func(v: float) -> void:
		_session.player_level = int(v)
		_save_settings()
		_apply_class_and_passives()
	)
	body.add_child(_level_spin)

	# --- Passives ---
	_add_heading(body, "Passives")
	_passive_box = VBoxContainer.new()
	_passive_box.add_theme_constant_override("separation", 4)
	body.add_child(_passive_box)

	# --- Skills (active abilities) ---
	_add_heading(body, "Skills")
	_skill_box = VBoxContainer.new()
	_skill_box.add_theme_constant_override("separation", 4)
	body.add_child(_skill_box)

	# --- Flags ---
	_unkillable_check = CheckBox.new()
	_unkillable_check.text = "Training dummies unkillable (auto-respawn)"
	_unkillable_check.button_pressed = _session.unkillable_dummies
	_unkillable_check.toggled.connect(func(on: bool) -> void:
		_session.unkillable_dummies = on
		_save_settings()
	)
	body.add_child(_unkillable_check)

	_infinite_ap_check = CheckBox.new()
	_infinite_ap_check.text = "Unlimited actions per turn (+ high AP)"
	_infinite_ap_check.button_pressed = _session.infinite_player_ap
	_infinite_ap_check.toggled.connect(func(on: bool) -> void:
		_session.infinite_player_ap = on
		_save_settings()
		_map_view.apply_training_board()
	)
	body.add_child(_infinite_ap_check)

	# --- Actions ---
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
		check.button_pressed = bool(_session.passive_enabled.get(passive.id, false))
		check.toggled.connect(_on_passive_toggled.bind(passive.id))
		_passive_box.add_child(check)
		_passive_checks[passive.id] = check


func _rebuild_skill_list() -> void:
	for child: Node in _skill_box.get_children():
		child.queue_free()
	_skill_checks.clear()
	var def: UnitData = DataLibrary.get_unit(_session.player_class_id)
	if def == null:
		return
	for ability: AbilityData in def.abilities:
		var check := CheckBox.new()
		check.text = ability.display_name
		# Skills default to enabled so you can immediately test all of them.
		check.button_pressed = bool(_session.skill_enabled.get(ability.id, true))
		check.toggled.connect(_on_skill_toggled.bind(ability.id))
		_skill_box.add_child(check)
		_skill_checks[ability.id] = check


func _on_class_selected(index: int) -> void:
	if _populating_class_options:
		return
	var class_id: Variant = _class_option.get_item_metadata(index)
	if class_id is StringName:
		_session.player_class_id = class_id
		_session.set_all_passives_enabled(_session.player_class_id, false)
		_session.set_all_skills_enabled(_session.player_class_id, true)
		_save_settings()
		_rebuild_passive_list()
		_rebuild_skill_list()
		_apply_class_and_passives()


func _on_passive_toggled(on: bool, passive_id: StringName) -> void:
	_session.passive_enabled[passive_id] = on
	_save_settings()
	_apply_class_and_passives()


func _on_skill_toggled(on: bool, skill_id: StringName) -> void:
	_session.skill_enabled[skill_id] = on
	_save_settings()
	_apply_class_and_passives()


func _apply_class_and_passives() -> void:
	_map_view.apply_training_board()
	_set_status("Applied %s (Lv %d) loadout." % [String(_session.player_class_id), _session.player_level])


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
	_save_settings()
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
	_save_settings()
	_set_status("Added ally at %s." % result["coord"])


func _on_reset_turn_pressed() -> void:
	if _director != null:
		_director.restart_turn()
	_set_status("Turn plan cleared.")


func _on_full_reset_pressed() -> void:
	_session.reset_defaults()
	_refresh_class_options()
	_rebuild_passive_list()
	_rebuild_skill_list()
	_level_spin.value = _session.player_level
	_unkillable_check.button_pressed = _session.unkillable_dummies
	_infinite_ap_check.button_pressed = _session.infinite_player_ap
	_map_view.apply_training_board()
	_save_settings()
	_set_status("Arena reset to defaults.")


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _on_collapse_pressed() -> void:
	_set_collapsed(not _collapsed)
	_save_settings()
	
func _set_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	if _body_scroll != null:
		_body_scroll.visible = not _collapsed
	if _collapse_btn != null:
		_collapse_btn.text = "▼" if _collapsed else "▲"
		_collapse_btn.tooltip_text = "Expand debug panel" if _collapsed else "Collapse debug panel"
	if _root != null:
		_root.offset_top = -PANEL_HEIGHT_COLLAPSED if _collapsed else -PANEL_HEIGHT_EXPANDED


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


func _game_settings() -> GameSettings:
	if _map_view != null:
		return _map_view.get_game_settings()
	return null


func _game_settings_or_default() -> GameSettings:
	var settings := _game_settings()
	if settings != null:
		return settings
	return GameSettings.new()


func _persist_hover_settings() -> void:
	var settings := _game_settings()
	if settings == null:
		return
	settings.save_to_disk()
	settings.changed.emit()
	EventBus.interface_settings_changed.emit()


func _sync_hover_slider_displays() -> void:
	var settings := _game_settings_or_default()
	_updating_hover_sliders = true
	if _hover_throttle_slider != null:
		_hover_throttle_slider.value = settings.hover_throttle_pct
	if _hover_sim_slider != null:
		_hover_sim_slider.value = settings.hover_sim_interval_ms
	if _overlay_fps_slider != null:
		_overlay_fps_slider.value = settings.planning_overlay_fps
	_updating_hover_sliders = false
	if _hover_throttle_value != null:
		_hover_throttle_value.text = "%d%%" % int(settings.hover_throttle_pct)
	if _hover_sim_value != null:
		_hover_sim_value.text = "%dms" % int(settings.hover_sim_interval_ms)
	if _overlay_fps_value != null:
		_overlay_fps_value.text = "%dfps" % int(settings.planning_overlay_fps)


func _add_debug_slider(
	parent: Control,
	title: String,
	min_value: float,
	max_value: float,
	step: float,
	initial: float,
	suffix: String,
	on_changed: Callable,
) -> HSlider:
	var caption := Label.new()
	caption.text = title
	parent.add_child(caption)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 160.0
	slider.value = initial
	var value_lbl := Label.new()
	value_lbl.custom_minimum_size.x = 56.0
	value_lbl.text = "%d%s" % [int(initial), suffix]
	slider.set_meta("value_label", value_lbl)
	slider.value_changed.connect(func(v: float) -> void:
		value_lbl.text = "%d%s" % [int(v), suffix]
		on_changed.call(v)
	)
	row.add_child(slider)
	row.add_child(value_lbl)
	return slider
