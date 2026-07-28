class_name MassSimSkirmishSetupDialog
extends Window

signal setup_applied(setup: MassSimSkirmishSetup)

const _C = preload("res://core/batch/mass_sim_constants.gd")

var _player_count: SpinBox
var _enemy_count: SpinBox
var _player_level: SpinBox
var _enemy_level: SpinBox
var _player_passives: SpinBox
var _player_skills: SpinBox
var _preview: Label
var _epoch_note: Label


func _init() -> void:
	title = "Skirmish Setup"
	unresizable = true
	transient = true
	exclusive = true
	min_size = Vector2i(520, 440)
	close_requested.connect(func() -> void: hide())
	var panel := PanelContainer.new()
	MassSimTheme.apply_panel(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var intro := Label.new()
	intro.text = "Configure roster size, levels, and player loadout. Saved to workspace; New Epoch locks these rules."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(intro)
	_epoch_note = Label.new()
	_epoch_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MassSimTheme.style_muted(_epoch_note)
	root.add_child(_epoch_note)
	_player_count = _add_spin_row(root, "Player count", _C.SKIRMISH_MIN_PLAYER_COUNT, _C.SKIRMISH_MAX_PLAYER_COUNT)
	_enemy_count = _add_spin_row(root, "Enemy count", _C.SKIRMISH_MIN_ENEMY_COUNT, _C.SKIRMISH_MAX_ENEMY_COUNT)
	_player_level = _add_spin_row(root, "Player level", _C.SKIRMISH_MIN_LEVEL, _C.SKIRMISH_MAX_LEVEL)
	_enemy_level = _add_spin_row(root, "Enemy level", _C.SKIRMISH_MIN_LEVEL, _C.SKIRMISH_MAX_LEVEL)
	_player_passives = _add_spin_row(root, "Player passives (random)", 0, _C.SKIRMISH_MAX_PASSIVE_COUNT)
	_player_skills = _add_spin_row(root, "Player class skills", 0, _C.SKIRMISH_ALL_CLASS_SKILLS_UI)
	var skills_hint := Label.new()
	skills_hint.text = "Class skills: 0 = run/move/basic only · 99 = full kit · 1–98 = random pick count"
	MassSimTheme.style_muted(skills_hint)
	skills_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(skills_hint)
	_preview = Label.new()
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_preview)
	for sb: SpinBox in [_player_count, _enemy_count, _player_level, _enemy_level, _player_passives, _player_skills]:
		sb.value_changed.connect(func(_v: float) -> void: _refresh_preview())
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	root.add_child(btn_row)
	var cancel := Button.new()
	cancel.text = "Cancel"
	MassSimTheme.style_button(cancel)
	cancel.pressed.connect(func() -> void: hide())
	btn_row.add_child(cancel)
	var apply := Button.new()
	apply.text = "Save Setup"
	MassSimTheme.style_button(apply)
	apply.custom_minimum_size = Vector2(120, 36)
	apply.pressed.connect(_on_apply)
	btn_row.add_child(apply)


func _add_spin_row(parent: VBoxContainer, label_text: String, min_v: int, max_v: int) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 180
	MassSimTheme.style_muted(lbl)
	row.add_child(lbl)
	var sb := SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sb)
	parent.add_child(row)
	return sb


func open_with(setup: MassSimSkirmishSetup, epoch_locked: MassSimSkirmishSetup = null) -> void:
	_player_count.value = setup.player_count
	_enemy_count.value = setup.enemy_count
	_player_level.value = setup.player_level
	_enemy_level.value = setup.enemy_level
	_player_passives.value = setup.player_passive_count
	_player_skills.value = (
		_C.SKIRMISH_ALL_CLASS_SKILLS_UI
		if setup.player_class_skill_count < 0
		else setup.player_class_skill_count
	)
	if epoch_locked != null:
		_epoch_note.text = "Active epoch locked: %s — change setup then click New Epoch." % epoch_locked.summary_label()
	else:
		_epoch_note.text = "Edits apply to the next batch. Click New Epoch to start a comparable log."
	_refresh_preview()
	popup_centered(Vector2i(520, 440))


func _read_setup() -> MassSimSkirmishSetup:
	var s := MassSimSkirmishSetup.new()
	s.player_count = int(_player_count.value)
	s.enemy_count = int(_enemy_count.value)
	s.player_level = int(_player_level.value)
	s.enemy_level = int(_enemy_level.value)
	s.player_passive_count = int(_player_passives.value)
	var skill_ui: int = int(_player_skills.value)
	s.player_class_skill_count = -1 if skill_ui >= _C.SKIRMISH_ALL_CLASS_SKILLS_UI else skill_ui
	s.clamp()
	return s


func _refresh_preview() -> void:
	_preview.text = "Preview: %s" % _read_setup().summary_label()


func _on_apply() -> void:
	setup_applied.emit(_read_setup())
	hide()
