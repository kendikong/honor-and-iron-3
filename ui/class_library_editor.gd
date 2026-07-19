class_name ClassLibraryEditorScreen
extends Control

const SAVE_PATH: String = "user://class_library_editor_overrides.json"

static var _restore_unit_id: StringName = &""

var _selected_unit: UnitData
var _detail_vbox: VBoxContainer
var _detail_scroll: ScrollContainer
var _save_status: Label
var _ability_ui: Dictionary = {} ## AbilityData -> Dictionary of preview refs
var _glossary_overrides: Dictionary = {} ## keyword -> {tooltip, system}
var _class_buttons: Dictionary = {}
var _nav_buttons: Array[Button] = []


func _ready() -> void:
	if has_node("PlaceholderLabel"):
		$PlaceholderLabel.queue_free()
	$BackButton.pressed.connect(_on_back_pressed)
	if MenuNavigation:
		MenuNavigation.register(self, _on_back_pressed)
	_build_layout()
	_load_overrides()
	var units: Array[UnitData] = DataLibrary.get_all_player_units()
	var pick: UnitData = null
	if _restore_unit_id != &"":
		pick = DataLibrary.get_unit(_restore_unit_id)
		_restore_unit_id = &""
	if pick == null and not units.is_empty():
		pick = units[0]
	if pick != null:
		_select_unit(pick)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _build_layout() -> void:
	var top_bar := HBoxContainer.new()
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 280.0
	top_bar.offset_top = 40.0
	top_bar.offset_right = -40.0
	top_bar.offset_bottom = 100.0
	add_child(top_bar)
	var save_btn := Button.new()
	save_btn.text = "Save Overrides"
	save_btn.pressed.connect(_save_overrides)
	top_bar.add_child(save_btn)
	var reload_btn := Button.new()
	reload_btn.text = "Reset to Factories"
	reload_btn.pressed.connect(_reload_factories)
	top_bar.add_child(reload_btn)
	_save_status = Label.new()
	_save_status.modulate = Color(0.5, 0.9, 0.55)
	top_bar.add_child(_save_status)
	var hint := Label.new()
	hint.text = "Edits apply live to DataLibrary. Save stores glossary overrides. Reset re-loads factory data."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.modulate = Color(0.7, 0.75, 0.8)
	top_bar.add_child(hint)

	var split := HSplitContainer.new()
	split.anchor_right = 1.0
	split.anchor_bottom = 1.0
	split.offset_top = 110.0
	split.offset_bottom = -20.0
	split.offset_left = 40.0
	split.offset_right = -40.0
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(280, 0)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(sidebar)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_add_header(list, "Reference")
	_add_nav_button(list, "Glossary", _select_glossary)
	_add_nav_button(list, "Definitions", _select_definitions)
	_add_header(list, "Player Classes")
	for unit: UnitData in DataLibrary.get_all_player_units():
		_add_unit_button(list, unit)

	var detail_panel := PanelContainer.new()
	detail_panel.name = "DetailPanel"
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(detail_panel)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(_detail_scroll)
	_detail_scroll.resized.connect(_sync_detail_width)
	_detail_vbox = VBoxContainer.new()
	_detail_vbox.name = "DetailVBox"
	_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_theme_constant_override("separation", 16)
	_detail_scroll.add_child(_detail_vbox)
	_sync_detail_width()


func _sync_detail_width() -> void:
	if _detail_scroll != null and _detail_vbox != null:
		_detail_vbox.custom_minimum_size.x = maxf(640.0, _detail_scroll.size.x - 16.0)


func _add_header(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)


func _add_nav_button(parent: Control, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(func() -> void:
		_highlight_nav(btn)
		callback.call()
	)
	parent.add_child(btn)
	_nav_buttons.append(btn)


func _add_unit_button(parent: Control, unit: UnitData) -> void:
	var btn := Button.new()
	btn.text = unit.display_name
	btn.pressed.connect(func() -> void:
		_highlight_class(unit.id)
		_select_unit(unit)
	)
	parent.add_child(btn)
	_class_buttons[unit.id] = btn


func _highlight_class(unit_id: StringName) -> void:
	for id: StringName in _class_buttons:
		var btn: Button = _class_buttons[id]
		btn.modulate = Color(1.0, 1.0, 0.85) if id == unit_id else Color(0.72, 0.72, 0.72)
	for btn: Button in _nav_buttons:
		btn.modulate = Color.WHITE


func _highlight_nav(active: Button) -> void:
	for btn: Button in _nav_buttons:
		btn.modulate = Color(1.0, 1.0, 0.85) if btn == active else Color.WHITE
	for id: StringName in _class_buttons:
		_class_buttons[id].modulate = Color.WHITE


func _clear_detail() -> void:
	_ability_ui.clear()
	if _detail_vbox == null:
		return
	for c: Node in _detail_vbox.get_children():
		c.queue_free()


func _select_unit(unit: UnitData) -> void:
	_selected_unit = unit
	_highlight_class(unit.id)
	_clear_detail()
	_add_title(unit.display_name)
	_add_subtitle("Unit ID: %s" % String(unit.id))
	_build_stats_section(unit)
	_build_weapon_section(unit)
	_build_passives_section(unit)
	_build_abilities_section(unit)


func _add_title(text: String) -> void:
	var title := Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", 40)
	_detail_vbox.add_child(title)


func _add_subtitle(text: String) -> void:
	var sub := Label.new()
	sub.text = text
	sub.add_theme_font_size_override("font_size", 20)
	sub.modulate = Color(0.75, 0.8, 0.9)
	_detail_vbox.add_child(sub)


func _section_header(text: String) -> void:
	var h := Label.new()
	h.text = text
	h.add_theme_font_size_override("font_size", 28)
	_detail_vbox.add_child(h)


func _build_stats_section(unit: UnitData) -> void:
	_section_header("Stats")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	_detail_vbox.add_child(grid)
	_bind_int(grid, "Level", unit.level, func(v: int) -> void: unit.level = v)
	var hp_lbl := Label.new()
	hp_lbl.text = "Derived Max HP: %d" % (unit.base_constitution * 5)
	hp_lbl.modulate = Color(0.65, 0.7, 0.75)
	_bind_int(grid, "CON (×5 = Max HP)", unit.base_constitution, func(v: int) -> void:
		unit.base_constitution = v
		hp_lbl.text = "Derived Max HP: %d" % (v * 5)
	)
	_bind_int(grid, "Move Points", unit.move_points, func(v: int) -> void: unit.move_points = v)
	_bind_int(grid, "Action Points", unit.action_points, func(v: int) -> void: unit.action_points = v)
	_bind_int(grid, "STR", unit.base_strength, func(v: int) -> void: unit.base_strength = v)
	_bind_int(grid, "MAG", unit.base_magic, func(v: int) -> void: unit.base_magic = v)
	_bind_int(grid, "DEF", unit.base_defense, func(v: int) -> void: unit.base_defense = v)
	_bind_enum(grid, "Preferred Stat", GameEnums.StatType, unit.preferred_stat, func(v: int) -> void: unit.preferred_stat = v)
	_bind_enum(grid, "Movement Type", GameEnums.MovementType, unit.movement_type, func(v: int) -> void: unit.movement_type = v)
	grid.add_child(_label(""))
	grid.add_child(hp_lbl)


func _build_weapon_section(unit: UnitData) -> void:
	_section_header("Equipment")
	if unit.equipped_weapon == null:
		var none := Label.new()
		none.text = "No weapon equipped."
		_detail_vbox.add_child(none)
		return
	var wpn := unit.equipped_weapon
	var grid := GridContainer.new()
	grid.columns = 2
	_detail_vbox.add_child(grid)
	_bind_string(grid, "Weapon Name", wpn.display_name, func(v: String) -> void: wpn.display_name = v)
	_bind_int(grid, "STR Bonus", wpn.bonus_strength, func(v: int) -> void: wpn.bonus_strength = v)
	_bind_int(grid, "MAG Bonus", wpn.bonus_magic, func(v: int) -> void: wpn.bonus_magic = v)
	_bind_int(grid, "DEF Bonus", wpn.bonus_defense, func(v: int) -> void: wpn.bonus_defense = v)
	_bind_int(grid, "HP Bonus", wpn.bonus_max_hp, func(v: int) -> void: wpn.bonus_max_hp = v)
	_bind_int(grid, "MOV Bonus", wpn.bonus_move, func(v: int) -> void: wpn.bonus_move = v)


func _build_passives_section(unit: UnitData) -> void:
	_section_header("Passives")
	if unit.passives.is_empty():
		var none := Label.new()
		none.text = "None"
		_detail_vbox.add_child(none)
		return
	for passive: PassiveData in unit.passives:
		var panel := PanelContainer.new()
		_detail_vbox.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		var grid := GridContainer.new()
		grid.columns = 2
		box.add_child(grid)
		grid.add_child(_label("ID"))
		var id_lbl := Label.new()
		id_lbl.text = String(passive.id)
		grid.add_child(id_lbl)
		_bind_string(grid, "Name", passive.display_name, func(v: String) -> void: passive.display_name = v)
		_add_subsection(box, "In-Game Preview")
		var preview := RichTextLabel.new()
		preview.bbcode_enabled = true
		preview.fit_content = true
		preview.custom_minimum_size = Vector2(0, 60)
		preview.scroll_active = true
		box.add_child(preview)
		var desc_edit := _bind_multiline(box, "Description (raw)", passive.description, func(v: String) -> void:
			passive.description = v
			_refresh_passive_preview(passive, preview)
		)
		_bind_multiline(box, "Upgraded Description", passive.upgraded_description, func(v: String) -> void:
			passive.upgraded_description = v
			_refresh_passive_preview(passive, preview)
		)
		desc_edit.text_changed.connect(func(_t: String) -> void: _refresh_passive_preview(passive, preview))
		_refresh_passive_preview(passive, preview)


func _refresh_passive_preview(passive: PassiveData, preview: RichTextLabel) -> void:
	preview.text = ClassLibrarySchema.passive_preview_bbcode(passive)


func _build_abilities_section(unit: UnitData) -> void:
	_section_header("Skills & Abilities")
	for ability: AbilityData in unit.abilities:
		_build_ability_row(ability)


func _build_ability_row(ability: AbilityData) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 8)
	_detail_vbox.add_child(margin)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	var name_row := HBoxContainer.new()
	outer.add_child(name_row)
	var name_edit := LineEdit.new()
	name_edit.text = ability.display_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(t: String) -> void:
		ability.display_name = t
		_refresh_ability_ui(ability)
	)
	name_row.add_child(name_edit)
	var id_lbl := Label.new()
	id_lbl.text = String(ability.id)
	id_lbl.modulate = Color(0.6, 0.65, 0.7)
	name_row.add_child(id_lbl)

	var cols := HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 8)
	outer.add_child(cols)

	# Column 1 — In-game
	var col_game := _column("In-Game View", 0.32)
	cols.add_child(col_game)
	var preview := RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.fit_content = true
	preview.scroll_active = false
	preview.custom_minimum_size = Vector2(200, 120)
	col_game.add_child(preview)

	# Column 2 — Data editor
	var col_data := _column("Ability Data", 0.38)
	cols.add_child(col_data)
	var data_scroll := ScrollContainer.new()
	data_scroll.custom_minimum_size = Vector2(280, 320)
	data_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_data.add_child(data_scroll)
	var data_vbox := VBoxContainer.new()
	data_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	data_scroll.add_child(data_vbox)
	_populate_ability_data_editor(data_vbox, ability)

	# Column 3 — Implementation
	var col_impl := _column("How It Works", 0.30)
	cols.add_child(col_impl)
	var impl_scroll := ScrollContainer.new()
	impl_scroll.custom_minimum_size = Vector2(200, 280)
	impl_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_impl.add_child(impl_scroll)
	var impl_vbox := VBoxContainer.new()
	impl_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impl_scroll.add_child(impl_vbox)
	var impl_lbl := Label.new()
	impl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	impl_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impl_vbox.add_child(impl_lbl)
	var dump_hdr := Label.new()
	dump_hdr.text = "Data dump"
	dump_hdr.modulate = Color(0.7, 0.75, 0.8)
	impl_vbox.add_child(dump_hdr)
	var dump_lbl := Label.new()
	dump_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dump_lbl.add_theme_font_size_override("font_size", 12)
	dump_lbl.modulate = Color(0.55, 0.6, 0.65)
	dump_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impl_vbox.add_child(dump_lbl)

	_ability_ui[ability] = {
		"preview": preview,
		"impl": impl_lbl,
		"dump": dump_lbl,
		"data_vbox": data_vbox,
	}
	_refresh_ability_ui(ability)


func _column(title: String, stretch: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = stretch
	var hdr := Label.new()
	hdr.text = title
	hdr.add_theme_font_size_override("font_size", 16)
	hdr.modulate = Color(0.85, 0.9, 1.0)
	col.add_child(hdr)
	return col


func _populate_ability_data_editor(parent: VBoxContainer, ability: AbilityData) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	parent.add_child(grid)
	_bind_enum(grid, "kind", GameEnums.AbilityKind, ability.kind, func(v: int) -> void:
		ability.kind = v
		ability.is_movement_skill = v == GameEnums.AbilityKind.MOVEMENT_SKILL
		_refresh_ability_ui(ability)
	)
	_bind_bool(grid, "is_movement_skill", ability.is_movement_skill, func(v: bool) -> void:
		ability.is_movement_skill = v
		if v:
			ability.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
		_refresh_ability_ui(ability)
	)
	_bind_int(grid, "AP cost", ability.action_point_cost, func(v: int) -> void:
		ability.action_point_cost = v
		_refresh_ability_ui(ability)
	)
	_bind_int(grid, "MP cost", ability.movement_point_cost, func(v: int) -> void:
		ability.movement_point_cost = v
		_refresh_ability_ui(ability)
	)
	_bind_int(grid, "range_tiles", ability.range_tiles, func(v: int) -> void:
		ability.range_tiles = v
		_refresh_ability_ui(ability)
	)
	_bind_enum(grid, "targeting_mode", GameEnums.TargetingMode, ability.targeting_mode, func(v: int) -> void:
		ability.targeting_mode = v
		_refresh_ability_ui(ability)
	)
	_bind_bool(grid, "can_target_self", ability.can_target_self, func(v: bool) -> void:
		ability.can_target_self = v
		_refresh_ability_ui(ability)
	)
	_bind_enum(grid, "target_shape", GameEnums.TargetShape, ability.target_shape, func(v: int) -> void:
		ability.target_shape = v
		_refresh_ability_ui(ability)
	)
	_bind_int(grid, "target_shape_size", ability.target_shape_size, func(v: int) -> void:
		ability.target_shape_size = v
		_refresh_ability_ui(ability)
	)
	_bind_enum(grid, "scaling_stat", GameEnums.StatType, ability.scaling_stat, func(v: int) -> void:
		ability.scaling_stat = v
		_refresh_ability_ui(ability)
	)
	_bind_int(grid, "uses_per_combat", ability.uses_per_combat, func(v: int) -> void: ability.uses_per_combat = v)
	_bind_string(grid, "presentation_key", String(ability.presentation_key), func(v: String) -> void:
		ability.presentation_key = StringName(v)
	)
	_bind_enum(grid, "presentation_anim", GameEnums.PresentationAnim, ability.presentation_anim, func(v: int) -> void:
		ability.presentation_anim = v
	)
	_bind_int(grid, "upgraded_range", ability.upgraded_range_tiles, func(v: int) -> void:
		ability.upgraded_range_tiles = v
		_refresh_ability_ui(ability)
	)
	_bind_enum(grid, "upgraded_target_shape", GameEnums.TargetShape, ability.upgraded_target_shape, func(v: int) -> void:
		ability.upgraded_target_shape = v
		_refresh_ability_ui(ability)
	)
	_bind_int(grid, "upgraded_shape_size", ability.upgraded_target_shape_size, func(v: int) -> void:
		ability.upgraded_target_shape_size = v
		_refresh_ability_ui(ability)
	)
	_bind_multiline(parent, "upgrade_description", ability.upgrade_description, func(v: String) -> void:
		ability.upgrade_description = v
	)

	var eff_hdr := Label.new()
	eff_hdr.text = "Effects"
	eff_hdr.add_theme_font_size_override("font_size", 18)
	parent.add_child(eff_hdr)
	var eff_box := VBoxContainer.new()
	eff_box.name = "EffectsBox"
	parent.add_child(eff_box)
	_rebuild_effects_editor(eff_box, ability, ability.effects, false)
	var add_eff := Button.new()
	add_eff.text = "+ Add Effect"
	add_eff.pressed.connect(func() -> void:
		var e := EffectData.new()
		e.type = GameEnums.EffectType.DAMAGE
		e.amount = 1
		ability.effects.append(e)
		_rebuild_effects_editor(eff_box, ability, ability.effects, false)
		_refresh_ability_ui(ability)
	)
	parent.add_child(add_eff)

	var up_hdr := Label.new()
	up_hdr.text = "Upgraded Effects"
	up_hdr.add_theme_font_size_override("font_size", 18)
	parent.add_child(up_hdr)
	var up_box := VBoxContainer.new()
	up_box.name = "UpgradedEffectsBox"
	parent.add_child(up_box)
	_rebuild_effects_editor(up_box, ability, ability.upgraded_effects, true)
	var add_up := Button.new()
	add_up.text = "+ Add Upgraded Effect"
	add_up.pressed.connect(func() -> void:
		var e := EffectData.new()
		e.type = GameEnums.EffectType.DAMAGE
		ability.upgraded_effects.append(e)
		_rebuild_effects_editor(up_box, ability, ability.upgraded_effects, true)
		_refresh_ability_ui(ability)
	)
	parent.add_child(add_up)


func _rebuild_effects_editor(parent: VBoxContainer, ability: AbilityData, effects: Array[EffectData], upgraded: bool) -> void:
	for c: Node in parent.get_children():
		c.queue_free()
	for i: int in effects.size():
		var eff: EffectData = effects[i]
		var eff_panel := PanelContainer.new()
		parent.add_child(eff_panel)
		var ev := VBoxContainer.new()
		eff_panel.add_child(ev)
		var row := HBoxContainer.new()
		ev.add_child(row)
		var idx_lbl := Label.new()
		idx_lbl.text = "Effect %d%s" % [i, " (upgrade)" if upgraded else ""]
		row.add_child(idx_lbl)
		var rm := Button.new()
		rm.text = "Remove"
		rm.pressed.connect(func() -> void:
			var pos: int = effects.find(eff)
			if pos >= 0:
				effects.remove_at(pos)
			_rebuild_effects_editor(parent, ability, effects, upgraded)
			_refresh_ability_ui(ability)
		)
		row.add_child(rm)
		var g := GridContainer.new()
		g.columns = 2
		ev.add_child(g)
		_bind_enum(g, "type", GameEnums.EffectType, eff.type, func(v: int) -> void:
			eff.type = v
			_refresh_ability_ui(ability)
		)
		_bind_int(g, "amount", eff.amount, func(v: int) -> void:
			eff.amount = v
			_refresh_ability_ui(ability)
		)
		_bind_enum(g, "scaling_stat", GameEnums.StatType, eff.scaling_stat, func(v: int) -> void:
			eff.scaling_stat = v
			_refresh_ability_ui(ability)
		)
		_bind_enum(g, "status_type", GameEnums.StatusType, eff.status_type, func(v: int) -> void:
			eff.status_type = v
			_refresh_ability_ui(ability)
		)
		_bind_int(g, "status_duration", eff.status_duration, func(v: int) -> void:
			eff.status_duration = v
			_refresh_ability_ui(ability)
		)
		_bind_int(g, "bonus_if_adjacent", eff.bonus_if_adjacent_at_cast, func(v: int) -> void:
			eff.bonus_if_adjacent_at_cast = v
			_refresh_ability_ui(ability)
		)
		_bind_int(g, "def_debuff_before", eff.def_debuff_before_damage, func(v: int) -> void:
			eff.def_debuff_before_damage = v
			_refresh_ability_ui(ability)
		)
		_bind_string(g, "spawn_unit_id", String(eff.spawn_unit_id), func(v: String) -> void:
			eff.spawn_unit_id = StringName(v)
		)


func _refresh_ability_ui(ability: AbilityData) -> void:
	if not _ability_ui.has(ability):
		return
	var refs: Dictionary = _ability_ui[ability]
	var preview: RichTextLabel = refs["preview"]
	var impl: Label = refs["impl"]
	var dump: Label = refs["dump"]
	preview.text = ClassLibrarySchema.in_game_ability_bbcode(ability)
	impl.text = ClassLibrarySchema.ability_implementation_notes(ability)
	dump.text = ClassLibrarySchema.ability_data_dump(ability)


func _select_glossary() -> void:
	_selected_unit = null
	_clear_detail()
	_add_title("Glossary")
	_add_subtitle("Game tooltip (left) vs system definition (right). Edits are session-only unless saved.")
	var manual: Dictionary = ClassLibrarySchema.manual_keywords()
	var keys: Array = manual.keys()
	keys.sort()
	for kw: String in keys:
		_add_glossary_row(kw, _glossary_tooltip(kw, manual[kw]), _glossary_system(kw, manual[kw]))
	_add_subtitle("Status Effects")
	var status_defs: Dictionary = {}
	for def_entry: Dictionary in ClassLibrarySchema.enum_definitions():
		if def_entry.get("category") == "StatusType":
			status_defs[def_entry.get("name")] = def_entry
	for k: String in GameEnums.StatusType.keys():
		var st: GameEnums.StatusType = GameEnums.StatusType[k]
		var display_name: String = CombatUiFormatters._status_name(st)
		var tooltip: String = CombatUiFormatters._status_desc(st)
		var sys_text: String = ""
		if status_defs.has(k):
			sys_text = String(status_defs[k].get("system", ""))
		_add_glossary_row(display_name, tooltip, sys_text)


func _glossary_tooltip(kw: String, default_val: String) -> String:
	if _glossary_overrides.has(kw) and _glossary_overrides[kw].has("tooltip"):
		return _glossary_overrides[kw]["tooltip"]
	return default_val


func _glossary_system(kw: String, default_val: String) -> String:
	if _glossary_overrides.has(kw) and _glossary_overrides[kw].has("system"):
		return _glossary_overrides[kw]["system"]
	return default_val


func _add_glossary_row(keyword: String, tooltip_default: String, system_default: String) -> void:
	var panel := PanelContainer.new()
	_detail_vbox.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var kw_lbl := Label.new()
	kw_lbl.text = keyword
	kw_lbl.custom_minimum_size = Vector2(140, 0)
	kw_lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(kw_lbl)
	var tip_edit := TextEdit.new()
	tip_edit.text = tooltip_default
	tip_edit.custom_minimum_size = Vector2(280, 64)
	tip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_edit.text_changed.connect(func() -> void:
		if not _glossary_overrides.has(keyword):
			_glossary_overrides[keyword] = {}
		_glossary_overrides[keyword]["tooltip"] = tip_edit.text
	)
	row.add_child(tip_edit)
	var sys_edit := TextEdit.new()
	sys_edit.text = system_default
	sys_edit.custom_minimum_size = Vector2(280, 64)
	sys_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sys_edit.text_changed.connect(func() -> void:
		if not _glossary_overrides.has(keyword):
			_glossary_overrides[keyword] = {}
		_glossary_overrides[keyword]["system"] = sys_edit.text
	)
	row.add_child(sys_edit)


func _select_definitions() -> void:
	_selected_unit = null
	_clear_detail()
	_add_title("Definitions")
	_add_subtitle("Enum values used by AbilityData / EffectData / targeting.")
	var header_row := HBoxContainer.new()
	_detail_vbox.add_child(header_row)
	for col_title: String in ["Category", "Name", "Game Tooltip", "System Definition"]:
		var h := Label.new()
		h.text = col_title
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_theme_font_size_override("font_size", 14)
		header_row.add_child(h)
	for entry: Dictionary in ClassLibrarySchema.enum_definitions():
		var row := HBoxContainer.new()
		_detail_vbox.add_child(row)
		for key: String in ["category", "name", "tooltip", "system"]:
			var l := Label.new()
			l.text = String(entry.get(key, ""))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.add_theme_font_size_override("font_size", 13)
			row.add_child(l)


# --- Widget bindings ---

func _bind_int(parent: GridContainer, label: String, value: int, setter: Callable) -> void:
	parent.add_child(_label(label))
	var spin := SpinBox.new()
	spin.min_value = -999
	spin.max_value = 9999
	spin.value = value
	spin.value_changed.connect(func(v: float) -> void: setter.call(int(v)))
	parent.add_child(spin)


func _bind_bool(parent: GridContainer, label: String, value: bool, setter: Callable) -> void:
	parent.add_child(_label(label))
	var chk := CheckBox.new()
	chk.button_pressed = value
	chk.toggled.connect(func(v: bool) -> void: setter.call(v))
	parent.add_child(chk)


func _bind_string(parent: GridContainer, label: String, value: String, setter: Callable) -> void:
	parent.add_child(_label(label))
	var edit := LineEdit.new()
	edit.text = value
	edit.text_changed.connect(func(t: String) -> void: setter.call(t))
	parent.add_child(edit)


func _bind_enum(parent: GridContainer, label: String, enum_obj: Variant, current: int, setter: Callable) -> void:
	parent.add_child(_label(label))
	var opt := OptionButton.new()
	var keys: PackedStringArray = enum_obj.keys()
	for i: int in keys.size():
		opt.add_item(keys[i], i)
	opt.selected = current
	opt.item_selected.connect(func(idx: int) -> void: setter.call(idx))
	parent.add_child(opt)


func _bind_multiline(parent: Control, label: String, value: String, setter: Callable) -> TextEdit:
	var lbl := _label(label)
	if parent is GridContainer:
		parent.add_child(lbl)
	else:
		parent.add_child(lbl)
	var edit := TextEdit.new()
	edit.text = value
	edit.custom_minimum_size = Vector2(0, 72)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func() -> void: setter.call(edit.text))
	parent.add_child(edit)
	return edit


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _add_subsection(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.modulate = Color(0.8, 0.85, 0.9)
	parent.add_child(l)


func _save_overrides() -> void:
	var data: Dictionary = {
		"glossary": _glossary_overrides,
		"units": {},
	}
	if _selected_unit != null:
		data["last_unit"] = String(_selected_unit.id)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
		if _save_status != null:
			_save_status.text = "Saved."
	else:
		if _save_status != null:
			_save_status.text = "Save failed."
			_save_status.modulate = Color(0.95, 0.45, 0.45)


func _load_overrides() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_glossary_overrides = parsed.get("glossary", {})


func _reload_factories() -> void:
	if _selected_unit != null:
		_restore_unit_id = _selected_unit.id
	DataLibrary.reset_cache()
	get_tree().reload_current_scene()
