class_name EffectsPanel
extends CanvasLayer

## Left panel â€” toggle living-environment systems on and off.

const PANEL_WIDTH: int = 405

signal toggled
signal biome_changed(variant: int)
signal character_gen_changed

var _panel: PanelContainer
var _checks: Dictionary = {}
var _biome_option: OptionButton
var _shadow_tuning_widgets: Dictionary = {}
var _shadow_tuning_specs: Dictionary = {}
var _shadow_tuning_readout: Label
var _shadow_tuning_reset_btn: Button
var _cloud_tuning_widgets: Dictionary = {}
var _cloud_tuning_specs: Dictionary = {}
var _cloud_tuning_reset_btn: Button
var _shadow_stats_label: Label
var _shadow_stats_reset_btn: Button
var _shadow_stats_accum: float = 0.0
var _settings: EffectsSettings
var _on_changed: Callable
var _char_profile: CharacterGenProfile
var _on_character_reroll: Callable
var _char_parts_label: Label
var _scale_slider: HSlider
var _map_smaller_btn: Button
var _map_larger_btn: Button
var _tile_labels_check: CheckButton
var _boredom_atmo_check: CheckButton
var _boredom_water_check: CheckButton
var _male_check: CheckButton
var _female_check: CheckButton
var _nonhuman_check: CheckButton


func _ready() -> void:
	layer = 20
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)


func setup(settings: EffectsSettings, on_changed: Callable) -> void:
	_settings = settings
	_on_changed = on_changed
	_sync_checks_from_settings()


func setup_character_gen(
	profile: CharacterGenProfile,
	on_reroll: Callable,
) -> void:
	_char_profile = profile
	_on_character_reroll = on_reroll
	_sync_character_sliders()


func panel_width() -> int:
	return PANEL_WIDTH





func _on_viewport_resized() -> void:
	pass


func _build_ui() -> void:
	var screen_root: Control = Control.new()
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_root)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_panel.offset_right = float(PANEL_WIDTH)
	_panel.add_theme_stylebox_override("panel", _panel_style())
	screen_root.add_child(_panel)

	var outer: MarginContainer = MarginContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("margin_left", 10)
	outer.add_theme_constant_override("margin_right", 10)
	outer.add_theme_constant_override("margin_top", 10)
	outer.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(outer)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Sandbox"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var effects_title: Label = Label.new()
	effects_title.text = "Effects"
	effects_title.add_theme_font_size_override("font_size", 20)
	effects_title.add_theme_color_override("font_color", Color(0.88, 0.9, 0.98))
	vbox.add_child(effects_title)

	var hint: Label = Label.new()
	hint.text = "Toggle living systems Â· saved automatically"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.72, 0.74, 0.82))
	vbox.add_child(hint)
	vbox.add_child(HSeparator.new())

	_add_section(vbox, "Wind")
	_add_toggle(vbox, "wind_field", "Wind field (grass / dirt / trees)")

	vbox.add_child(HSeparator.new())
	_add_section(vbox, "Sky & time")
	_add_toggle(vbox, "time_light", "Day / night cycle (CanvasModulate)")
	_add_toggle(vbox, "cloud_shadows", "Cloud shadows")
	_add_cloud_tuning_sliders(vbox)

	vbox.add_child(HSeparator.new())
	_add_section(vbox, "Water")
	_add_toggle(vbox, "water_ripples", "Water ripples")
	_add_toggle(vbox, "shoreline_foam", "Shoreline foam")
	_add_toggle(vbox, "water_sparkles", "Deep water sparkles")
	_add_toggle(vbox, "fish_splash", "Fish splash burst")

	vbox.add_child(HSeparator.new())
	_add_section(vbox, "Ecology")
	_add_toggle(vbox, "ambient_particles", "Ambient particles")
	_add_toggle(vbox, "ecology_actors", "Sparse actors")
	_add_toggle(vbox, "rare_events", "Rare ambient events")

	vbox.add_child(HSeparator.new())
	_add_section(vbox, "Biome")
	_biome_option = OptionButton.new()
	_biome_option.add_theme_font_size_override("font_size", 17)
	for i: int in range(BiomeProfile.variant_count()):
		var variant: int = i + 1
		var profile: BiomeProfile = BiomeProfile.for_variant(variant)
		_biome_option.add_item("%s (v%02d)" % [profile.display_name, variant], variant)
	_biome_option.item_selected.connect(_on_biome_selected)
	vbox.add_child(_biome_option)

	vbox.add_child(HSeparator.new())
	_add_section(vbox, "Shadows")
	_add_toggle(
		vbox,
		"oblique_contact_shadows",
		"Oblique contact shadows (rocks / ruins / tree B / props)",
	)
	_add_toggle(
		vbox,
		"shadow_perf_mode",
		"Shadow perf mode (lower quality, higher FPS)",
	)
	_add_toggle(
		vbox,
		"shadow_hybrid_twilight_lod",
		"Hybrid twilight LOD (perf bake at dusk/dawn, quality by day)",
	)
	_add_toggle(vbox, "shadow_edge_soften", "Shadow edge softening (3Ã—3 blur)")
	_add_toggle(vbox, "tree_variant_b", "Large tree B (procedural shadow)")
	_add_toggle(
		vbox,
		"shadow_disable_caster_punch",
		"Disable caster punch-out (no tree-shaped holes)",
	)
	_add_toggle(vbox, "shadow_disable_tree_nudge", "Disable tree shadow nudge")
	_add_toggle(vbox, "shadow_freeze_time", "Freeze game time")
	_add_shadow_tuning_sliders(vbox)
	_add_shadow_stats_row(vbox)

	vbox.add_child(HSeparator.new())
	_add_section(vbox, "Character (LPC)")
	_add_character_controls(vbox)

	vbox.add_child(HSeparator.new())
	_add_hotkeys_hint(vbox)


func _process(delta: float) -> void:
	if _shadow_stats_label == null:
		return
	_shadow_stats_accum += delta
	if _shadow_stats_accum < 0.25:
		return
	_shadow_stats_accum = 0.0
	if _settings == null or not _settings.oblique_contact_shadows:
		_shadow_stats_label.visible = false
		if _shadow_stats_reset_btn != null:
			_shadow_stats_reset_btn.visible = false
		if _shadow_tuning_readout != null:
			_shadow_tuning_readout.visible = false
		return
	_shadow_stats_label.visible = true
	if _shadow_stats_reset_btn != null:
		_shadow_stats_reset_btn.visible = true
	if _shadow_tuning_readout != null:
		_shadow_tuning_readout.visible = true
		_shadow_tuning_readout.text = ShadowTuning.live_readout(_settings)
	_shadow_stats_label.text = ShadowPlacer.debug_format_line()





func _add_hotkeys_hint(parent: VBoxContainer) -> void:
	var label: Label = Label.new()
	label.text = (
		"Keys: WASD move Â· G regen Â· R seed Â· T center Â· [ ] size Â· P biome Â· E export grid Â· "
		+ "C character Â· L labels Â· K walkability Â· J shadow hit Â· B boredom atmo Â· water test in panel Â· O options"
	)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.58, 0.62, 0.72))
	parent.add_child(label)


func _add_section(parent: VBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.95))
	parent.add_child(label)


func _add_toggle(
	parent: VBoxContainer, key: String, label_text: String, disabled: bool = false,
) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var check: CheckButton = CheckButton.new()
	check.text = label_text
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.add_theme_font_size_override("font_size", 17)
	check.disabled = disabled
	if disabled:
		check.button_pressed = false
		check.modulate = Color(0.62, 0.64, 0.72, 1.0)
	check.toggled.connect(_on_check_toggled.bind(key))
	row.add_child(check)
	_checks[key] = check


func _add_cloud_tuning_sliders(parent: VBoxContainer) -> void:
	_add_section(parent, "Cloud tuning")
	var hint: Label = Label.new()
	hint.text = "Cloud field tuning Â· live while dragging Â· saved on release"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.66, 0.70, 0.80))
	parent.add_child(hint)
	for spec: Dictionary in CloudTuning.panel_slider_specs():
		var key: String = str(spec.get("key", ""))
		if key.is_empty():
			continue
		_cloud_tuning_specs[key] = spec
		var caption: Label = Label.new()
		caption.text = str(spec.get("label", key))
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_size_override("font_size", 14)
		caption.add_theme_color_override("font_color", Color(0.76, 0.80, 0.90))
		parent.add_child(caption)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		parent.add_child(row)
		var slider: HSlider = HSlider.new()
		slider.min_value = float(spec.get("min", 0.0))
		slider.max_value = float(spec.get("max", 1.0))
		slider.step = float(spec.get("step", 0.01))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_cloud_tuning_slider_changed.bind(key))
		slider.drag_ended.connect(_on_cloud_tuning_slider_drag_ended)
		row.add_child(slider)
		var value_label: Label = Label.new()
		value_label.custom_minimum_size = Vector2(88.0, 0.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", 13)
		value_label.add_theme_color_override("font_color", Color(0.84, 0.86, 0.94))
		row.add_child(value_label)
		_cloud_tuning_widgets[key] = {"slider": slider, "value": value_label}
	_cloud_tuning_reset_btn = Button.new()
	_cloud_tuning_reset_btn.text = "Reset cloud tuning to defaults"
	_cloud_tuning_reset_btn.add_theme_font_size_override("font_size", 14)
	_cloud_tuning_reset_btn.pressed.connect(_on_cloud_tuning_reset_pressed)
	parent.add_child(_cloud_tuning_reset_btn)


func _sync_cloud_tuning_sliders() -> void:
	if _settings == null:
		return
	for key: String in _cloud_tuning_widgets:
		var widgets: Dictionary = _cloud_tuning_widgets[key] as Dictionary
		var slider: HSlider = widgets.get("slider") as HSlider
		if slider == null:
			continue
		slider.set_block_signals(true)
		slider.value = float(_settings.get(key))
		slider.set_block_signals(false)
		_update_cloud_tuning_label(key, float(_settings.get(key)))


func _update_cloud_tuning_label(key: String, value: float) -> void:
	var widgets: Dictionary = _cloud_tuning_widgets.get(key, {}) as Dictionary
	var value_label: Label = widgets.get("value") as Label
	var spec: Dictionary = _cloud_tuning_specs.get(key, {}) as Dictionary
	if value_label == null or spec.is_empty():
		return
	value_label.text = CloudTuning.format_slider_value(spec, value)


func _apply_cloud_tuning_live(persist: bool) -> void:
	if _settings == null:
		return
	CloudTuning.clamp_all(_settings)
	CloudTuning.sync_runtime(_settings)
	_sync_cloud_tuning_sliders()
	if persist:
		_settings.save_to_disk()
	toggled.emit()
	if _on_changed.is_valid():
		_on_changed.call()


func _on_cloud_tuning_slider_changed(value: float, key: String) -> void:
	if _settings == null:
		return
	_settings.set(key, value)
	_update_cloud_tuning_label(key, float(value))
	_apply_cloud_tuning_live(false)


func _on_cloud_tuning_slider_drag_ended(_value_changed: bool) -> void:
	if _settings == null:
		return
	_settings.save_to_disk()


func _on_cloud_tuning_reset_pressed() -> void:
	if _settings == null:
		return
	CloudTuning.apply_defaults(_settings)
	_apply_cloud_tuning_live(true)


func _add_shadow_tuning_sliders(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())
	_add_section(parent, "Shadow twilight tuning")
	var hint: Label = Label.new()
	hint.text = "Map + player share these values Â· live while dragging Â· saved on release"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.66, 0.70, 0.80))
	parent.add_child(hint)
	_shadow_tuning_readout = Label.new()
	_shadow_tuning_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shadow_tuning_readout.add_theme_font_size_override("font_size", 12)
	_shadow_tuning_readout.add_theme_color_override("font_color", Color(0.70, 0.78, 0.92))
	parent.add_child(_shadow_tuning_readout)
	for spec: Dictionary in ShadowTuning.panel_slider_specs():
		if str(spec.get("kind", "")) == "section":
			_add_section(parent, str(spec.get("text", "")))
			continue
		var key: String = str(spec.get("key", ""))
		if key.is_empty():
			continue
		_shadow_tuning_specs[key] = spec
		var caption: Label = Label.new()
		caption.text = str(spec.get("label", key))
		caption.add_theme_font_size_override("font_size", 14)
		caption.add_theme_color_override("font_color", Color(0.76, 0.80, 0.90))
		parent.add_child(caption)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		parent.add_child(row)
		var slider: HSlider = HSlider.new()
		slider.min_value = float(spec.get("min", 0.0))
		slider.max_value = float(spec.get("max", 1.0))
		slider.step = float(spec.get("step", 0.01))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_shadow_tuning_slider_changed.bind(key))
		slider.drag_ended.connect(_on_shadow_tuning_slider_drag_ended)
		row.add_child(slider)
		var value_label: Label = Label.new()
		value_label.custom_minimum_size = Vector2(88.0, 0.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", 13)
		value_label.add_theme_color_override("font_color", Color(0.84, 0.86, 0.94))
		row.add_child(value_label)
		_shadow_tuning_widgets[key] = {"slider": slider, "value": value_label}
	_shadow_tuning_reset_btn = Button.new()
	_shadow_tuning_reset_btn.text = "Reset shadow tuning to defaults"
	_shadow_tuning_reset_btn.add_theme_font_size_override("font_size", 14)
	_shadow_tuning_reset_btn.pressed.connect(_on_shadow_tuning_reset_pressed)
	parent.add_child(_shadow_tuning_reset_btn)


func _sync_shadow_tuning_sliders() -> void:
	if _settings == null:
		return
	for key: String in _shadow_tuning_widgets:
		var widgets: Dictionary = _shadow_tuning_widgets[key] as Dictionary
		var slider: HSlider = widgets.get("slider") as HSlider
		if slider == null:
			continue
		slider.set_block_signals(true)
		slider.value = float(_settings.get(key))
		slider.set_block_signals(false)
		_update_shadow_tuning_label(key, float(_settings.get(key)))
	if _shadow_tuning_readout != null:
		_shadow_tuning_readout.text = ShadowTuning.live_readout(_settings)


func _update_shadow_tuning_label(key: String, value: float) -> void:
	var widgets: Dictionary = _shadow_tuning_widgets.get(key, {}) as Dictionary
	var value_label: Label = widgets.get("value") as Label
	var spec: Dictionary = _shadow_tuning_specs.get(key, {}) as Dictionary
	if value_label == null or spec.is_empty():
		return
	value_label.text = ShadowTuning.format_slider_value(spec, value)


func _apply_shadow_tuning_live(persist: bool) -> void:
	if _settings == null:
		return
	ShadowTuning.clamp_all(_settings)
	ShadowTuning.apply_to_weather_bus(_settings)
	_sync_shadow_tuning_sliders()
	if persist:
		_settings.save_to_disk()
	toggled.emit()
	if _on_changed.is_valid():
		_on_changed.call()


func _on_shadow_tuning_slider_changed(value: float, key: String) -> void:
	if _settings == null:
		return
	_settings.set(key, value)
	_update_shadow_tuning_label(key, float(value))
	_apply_shadow_tuning_live(false)


func _on_shadow_tuning_slider_drag_ended(_value_changed: bool) -> void:
	if _settings == null:
		return
	_settings.save_to_disk()


func _on_shadow_tuning_reset_pressed() -> void:
	if _settings == null:
		return
	ShadowTuning.apply_defaults(_settings)
	_sync_checks_from_settings()
	_apply_shadow_tuning_live(true)


func _sync_checks_from_settings() -> void:
	if _settings == null:
		return
	for key: String in _checks:
		var check: CheckButton = _checks[key] as CheckButton
		check.set_block_signals(true)
		check.button_pressed = bool(_settings.get(key))
		check.set_block_signals(false)
	_sync_biome_option()
	_sync_shadow_tuning_sliders()
	_sync_cloud_tuning_sliders()


func _add_shadow_stats_row(parent: VBoxContainer) -> void:
	var caption: Label = Label.new()
	caption.text = "Shadow bake stats"
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_color", Color(0.78, 0.82, 0.92))
	parent.add_child(caption)
	_shadow_stats_label = Label.new()
	_shadow_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shadow_stats_label.add_theme_font_size_override("font_size", 13)
	_shadow_stats_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86))
	parent.add_child(_shadow_stats_label)
	_shadow_stats_reset_btn = Button.new()
	_shadow_stats_reset_btn.text = "Reset shadow bake counters"
	_shadow_stats_reset_btn.add_theme_font_size_override("font_size", 14)
	_shadow_stats_reset_btn.pressed.connect(_on_shadow_stats_reset_pressed)
	parent.add_child(_shadow_stats_reset_btn)


func _on_shadow_stats_reset_pressed() -> void:
	ShadowPlacer.debug_reset_counters()
	if _shadow_stats_label != null:
		_shadow_stats_label.text = ShadowPlacer.debug_format_line()


func _sync_biome_option() -> void:
	if _biome_option == null or _settings == null:
		return
	var variant: int = clampi(_settings.biome_variant, 1, BiomeProfile.variant_count())
	for i: int in range(_biome_option.item_count):
		if _biome_option.get_item_id(i) == variant:
			_biome_option.select(i)
			return


func _on_biome_selected(index: int) -> void:
	if _settings == null or _biome_option == null:
		return
	var variant: int = _biome_option.get_item_id(index)
	if _settings.biome_variant == variant:
		return
	_settings.biome_variant = variant
	_settings.save_to_disk()
	biome_changed.emit(variant)


func _on_check_toggled(pressed: bool, key: String) -> void:
	if _settings == null:
		return
	_settings.set(key, pressed)
	_settings.save_to_disk()
	toggled.emit()
	if _on_changed.is_valid():
		_on_changed.call()


func _panel_style() -> StyleBoxFlat:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.07, 0.11, 0.94)
	bg.border_width_right = 2
	bg.border_color = Color(0.28, 0.32, 0.42)
	return bg


func _add_character_controls(parent: VBoxContainer) -> void:
	_male_check = _add_profile_toggle(parent, "Include Male", _on_male_toggled)
	_female_check = _add_profile_toggle(parent, "Include Female", _on_female_toggled)
	_nonhuman_check = _add_profile_toggle(parent, "Include Non-human parts", _on_nonhuman_toggled)
	parent.add_child(HSeparator.new())

	var reroll: Button = Button.new()
	reroll.text = "Reroll character"
	reroll.add_theme_font_size_override("font_size", 16)
	reroll.pressed.connect(_on_character_reroll_pressed)
	parent.add_child(reroll)

	_char_parts_label = Label.new()
	_char_parts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_char_parts_label.add_theme_font_size_override("font_size", 12)
	_char_parts_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86))
	_char_parts_label.text = "Parts: (reroll to list slot ids)"
	parent.add_child(_char_parts_label)


func set_character_parts_report(text: String) -> void:
	if _char_parts_label != null:
		_char_parts_label.text = text


func _add_profile_slider(
	parent: VBoxContainer,
	label_text: String,
	min_v: float,
	max_v: float,
	step: float,
	on_change: Callable,
) -> HSlider:
	var caption: Label = Label.new()
	caption.text = label_text
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_color", Color(0.78, 0.82, 0.92))
	parent.add_child(caption)

	var slider: HSlider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(on_change)
	parent.add_child(slider)
	return slider


func _sync_character_sliders() -> void:
	if _char_profile == null:
		return
	if _male_check != null:
		_male_check.set_block_signals(true)
		_male_check.button_pressed = _char_profile.body_type_weights.get("male", 1.0) > 0.0
		_male_check.set_block_signals(false)
	if _female_check != null:
		_female_check.set_block_signals(true)
		_female_check.button_pressed = _char_profile.body_type_weights.get("female", 1.0) > 0.0
		_female_check.set_block_signals(false)
	if _nonhuman_check != null:
		_nonhuman_check.set_block_signals(true)
		_nonhuman_check.button_pressed = _char_profile.allow_non_human_parts
		_nonhuman_check.set_block_signals(false)


func get_character_overrides() -> Dictionary:
	return {
		"male": _male_check.button_pressed if _male_check != null else true,
		"female": _female_check.button_pressed if _female_check != null else true,
		"nonhuman": _nonhuman_check.button_pressed if _nonhuman_check != null else false,
	}


func _add_profile_toggle(parent: VBoxContainer, label_text: String, on_change: Callable) -> CheckButton:
	var cb := CheckButton.new()
	cb.text = label_text
	cb.toggled.connect(on_change)
	parent.add_child(cb)
	return cb


func _on_male_toggled(on: bool) -> void:
	if _char_profile == null: return
	_char_profile.body_type_weights["male"] = 1.0 if on else 0.0
	character_gen_changed.emit()


func _on_female_toggled(on: bool) -> void:
	if _char_profile == null: return
	_char_profile.body_type_weights["female"] = 1.0 if on else 0.0
	character_gen_changed.emit()


func _on_nonhuman_toggled(on: bool) -> void:
	if _char_profile == null: return
	_char_profile.allow_non_human_parts = on
	character_gen_changed.emit()


func _on_scale_changed(value: float) -> void:
	if _settings != null:
		_settings.sandbox_character_scale = float(value)
		_settings.save_to_disk()
	if _char_profile == null:
		return
	_char_profile.display_scale = float(value)
	character_gen_changed.emit()


func _on_character_reroll_pressed() -> void:
	if _on_character_reroll.is_valid():
		_on_character_reroll.call()
