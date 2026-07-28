class_name SkirmishSetupFields
extends VBoxContainer

const _C = preload("res://core/batch/mass_sim_constants.gd")

var _player_count: SpinBox
var _enemy_count: SpinBox
var _player_level: SpinBox
var _enemy_level: SpinBox
var _player_passives: SpinBox
var _player_skills: SpinBox
var _preview: Label


func _init() -> void:
	add_theme_constant_override("separation", 8)
	_player_count = _add_spin_row("Player count", _C.SKIRMISH_MIN_PLAYER_COUNT, _C.SKIRMISH_MAX_PLAYER_COUNT)
	_enemy_count = _add_spin_row("Enemy count", _C.SKIRMISH_MIN_ENEMY_COUNT, _C.SKIRMISH_MAX_ENEMY_COUNT)
	_player_level = _add_spin_row("Player level", _C.SKIRMISH_MIN_LEVEL, _C.SKIRMISH_MAX_LEVEL)
	_enemy_level = _add_spin_row("Enemy level", _C.SKIRMISH_MIN_LEVEL, _C.SKIRMISH_MAX_LEVEL)
	_player_passives = _add_spin_row("Player passives (random)", 0, _C.SKIRMISH_MAX_PASSIVE_COUNT)
	_player_skills = _add_spin_row("Player class skills", 0, _C.SKIRMISH_ALL_CLASS_SKILLS_UI)
	var skills_hint := Label.new()
	skills_hint.text = "Class skills: 0 = run/move/basic only · 99 = full kit · 1–98 = random pick count"
	skills_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(skills_hint)
	_preview = Label.new()
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_preview)
	for sb: SpinBox in [_player_count, _enemy_count, _player_level, _enemy_level, _player_passives, _player_skills]:
		sb.value_changed.connect(func(_v: float) -> void: _refresh_preview())


func _add_spin_row(label_text: String, min_v: int, max_v: int) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 180
	row.add_child(lbl)
	var sb := SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sb)
	add_child(row)
	return sb


func load_setup(setup: MassSimSkirmishSetup) -> void:
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
	_refresh_preview()


func read_setup() -> MassSimSkirmishSetup:
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
	_preview.text = "Loadout: %s" % read_setup().summary_label()
