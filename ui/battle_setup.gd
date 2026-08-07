extends Control

var _map_card_center: CenterContainer


func _ready() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	MenuNavigation.register(self, _on_back_pressed)
	
	if has_node("VBoxContainer/LaunchDemoButton"):
		$VBoxContainer/LaunchDemoButton.queue_free()
		
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	
	var center := CenterContainer.new()
	center.name = "MapCardCenter"
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_top = 100
	center.add_child(grid)
	add_child(center)
	_map_card_center = center
	
	for i in range(DataLibrary.get_all_maps().size()):
		var map = DataLibrary.get_all_maps()[i]
		var card := _build_map_card(map, i)
		grid.add_child(card)

	grid.add_child(_build_skirmish_card())
	
	if NetworkManager != null and NetworkManager.is_multiplayer and not multiplayer.is_server():
		# Clients don't choose the map. Hide grid, show waiting label.
		grid.visible = false
		var lbl := Label.new()
		lbl.text = "Waiting for host to select map and assign units..."
		lbl.add_theme_font_size_override("font_size", 32)
		center.add_child(lbl)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _build_map_card(map: MapData, index: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 200)
	btn.pressed.connect(func(): _launch_map(map, index))
	
	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)
	
	var color := ColorRect.new()
	color.custom_minimum_size = Vector2(0, 100)
	color.color = map.card_color
	color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(color)
	
	var title := Label.new()
	title.text = map.display_name
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var desc := Label.new()
	desc.text = map.map_description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 16)
	vbox.add_child(desc)
	
	return btn

func _build_skirmish_card() -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 200)
	btn.pressed.connect(_show_skirmish_picker)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var color := ColorRect.new()
	color.custom_minimum_size = Vector2(0, 100)
	color.color = Color(0.15, 0.35, 0.22)
	color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(color)

	var title := Label.new()
	title.text = "Random Skirmish"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Procedural map â€” configure roster, levels, passives, and skills."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 16)
	vbox.add_child(desc)

	return btn


func _show_skirmish_picker() -> void:
	if _map_card_center != null:
		_map_card_center.visible = false

	var overlay := ColorRect.new()
	overlay.name = "SkirmishPicker"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.03, 0.06, 0.92)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24.0
	panel.offset_top = 24.0
	panel.offset_right = -24.0
	panel.offset_bottom = -24.0
	_apply_skirmish_panel_style(panel)
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var shell := VBoxContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 20)
	margin.add_child(shell)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	shell.add_child(header)

	var title := Label.new()
	title.text = "Random Skirmish Setup"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 34)
	header.add_child(title)

	var cancel_top := Button.new()
	cancel_top.text = "Cancel"
	cancel_top.custom_minimum_size = Vector2(120.0, 48.0)
	cancel_top.pressed.connect(func() -> void: _close_skirmish_picker(overlay))
	header.add_child(cancel_top)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	shell.add_child(body)

	var left_section := _make_skirmish_section("Roster & loadout")
	left_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_section.size_flags_stretch_ratio = 1.0
	body.add_child(left_section)

	var left_body: VBoxContainer = left_section.get_node("SectionMargin/SectionBody") as VBoxContainer
	var setup_fields := SkirmishSetupFields.new()
	setup_fields.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setup_fields.apply_roomy_layout()
	setup_fields.load_setup(MassSimSkirmishSetup.load_last_saved())
	left_body.add_child(setup_fields)

	var right_section := _make_skirmish_section("Map size")
	right_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_section.size_flags_stretch_ratio = 1.0
	body.add_child(right_section)

	var right_body: VBoxContainer = right_section.get_node("SectionMargin/SectionBody") as VBoxContainer
	var size_hint := Label.new()
	size_hint.text = "Pick a battlefield preset. Wider maps show more tiles on the tactical view."
	size_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	size_hint.add_theme_font_size_override("font_size", 16)
	size_hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
	right_body.add_child(size_hint)

	var selected_size: Array[Vector2i] = [Vector2i.ZERO]
	var preset_area := VBoxContainer.new()
	preset_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preset_area.add_theme_constant_override("separation", 12)
	right_body.add_child(preset_area)
	_populate_skirmish_preset_rows(preset_area, selected_size)

	var footer := PanelContainer.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_skirmish_footer_style(footer)
	shell.add_child(footer)

	var footer_margin := MarginContainer.new()
	footer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	footer_margin.add_theme_constant_override("margin_left", 16)
	footer_margin.add_theme_constant_override("margin_right", 16)
	footer_margin.add_theme_constant_override("margin_top", 12)
	footer_margin.add_theme_constant_override("margin_bottom", 12)
	footer.add_child(footer_margin)

	var footer_row := HBoxContainer.new()
	footer_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	footer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_margin.add_child(footer_row)

	var launch := Button.new()
	launch.text = "Launch Skirmish"
	launch.custom_minimum_size = Vector2(320.0, 56.0)
	launch.add_theme_font_size_override("font_size", 20)
	launch.pressed.connect(func() -> void:
		if selected_size[0] == Vector2i.ZERO:
			return
		var setup: MassSimSkirmishSetup = setup_fields.read_setup()
		MassSimSkirmishSetup.save_last(setup)
		_launch_skirmish(selected_size[0], setup)
	)
	footer_row.add_child(launch)


func _close_skirmish_picker(overlay: ColorRect) -> void:
	if _map_card_center != null:
		_map_card_center.visible = true
	overlay.queue_free()


func _make_skirmish_section(heading: String) -> PanelContainer:
	var section := PanelContainer.new()
	_apply_skirmish_section_style(section)
	var margin := MarginContainer.new()
	margin.name = "SectionMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	section.add_child(margin)
	var body := VBoxContainer.new()
	body.name = "SectionBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	margin.add_child(body)
	var title := Label.new()
	title.text = heading
	title.add_theme_font_size_override("font_size", 24)
	body.add_child(title)
	return section


func _populate_skirmish_preset_rows(
	parent: VBoxContainer,
	selected_size: Array[Vector2i],
) -> void:
	var presets: Array[Vector2i] = TacticalConstants.SKIRMISH_PRESETS
	const COLS: int = 2
	var row: HBoxContainer = null
	for i: int in range(presets.size()):
		if i % COLS == 0:
			row = HBoxContainer.new()
			row.size_flags_vertical = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 12)
			parent.add_child(row)
		var preset: Vector2i = presets[i]
		var pick := Button.new()
		pick.text = "%d Ã— %d" % [preset.x, preset.y]
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pick.custom_minimum_size = Vector2(0.0, 72.0)
		pick.add_theme_font_size_override("font_size", 20)
		pick.pressed.connect(func() -> void:
			selected_size[0] = preset
			for child: Node in parent.get_children():
				if child is HBoxContainer:
					for btn: Node in (child as HBoxContainer).get_children():
						if btn is Button:
							(btn as Button).modulate = Color(0.62, 0.62, 0.62)
			pick.modulate = Color.WHITE
		)
		row.add_child(pick)
	if row != null and row.get_child_count() == 1:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)


func _apply_skirmish_section_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	style.border_color = Color(0.34, 0.42, 0.54, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)


func _apply_skirmish_footer_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.92)
	style.border_color = Color(0.34, 0.42, 0.54, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)


func _apply_skirmish_panel_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.17, 0.88)
	style.border_color = Color(0.42, 0.50, 0.62, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)


func _launch_skirmish(size_preset: Vector2i, setup: MassSimSkirmishSetup) -> void:
	var picker: Node = get_node_or_null("SkirmishPicker")
	if picker != null:
		_close_skirmish_picker(picker as ColorRect)
	var config := SkirmishGenerator.SkirmishConfig.new()
	config.size_preset = size_preset
	config.map_seed = randi()
	config.skirmish_setup = setup.to_dict()
	SkirmishLaunch.set_pending(config)
	SettingsManager.persist_window_placement()
	get_tree().change_scene_to_file("res://scenes/TacticalCombat.tscn")


func _launch_map(map: MapData, index: int) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		if multiplayer.is_server():
			_show_assignment_overlay(map, index)
	else:
		_do_launch(map, {})

func _show_assignment_overlay(map: MapData, index: int) -> void:
	var overlay = ColorRect.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0, 0, 0, 0.9)
	add_child(overlay)
	
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -300
	vbox.offset_top = -250
	vbox.offset_right = 300
	vbox.offset_bottom = 250
	overlay.add_child(vbox)
	
	var title = Label.new()
	title.text = "Assign Units to Players"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	
	var players = NetworkManager.player_usernames.keys()
	var dropdowns = []
	
	var id_counter = 1
	for p in map.encounter.player_spawns:
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = p.unit.display_name + " (Unit " + str(id_counter) + ")"
		lbl.custom_minimum_size = Vector2(200, 0)
		hbox.add_child(lbl)
		
		var opt = OptionButton.new()
		for i in range(players.size()):
			var pid = players[i]
			opt.add_item(NetworkManager.player_usernames[pid], pid)
		
		# Auto-distribute evenly
		var default_idx = (id_counter - 1) % players.size()
		opt.select(default_idx)
		
		hbox.add_child(opt)
		vbox.add_child(hbox)
		
		dropdowns.append({"unit_id": id_counter, "opt": opt})
		id_counter += 1
		
	var start_btn = Button.new()
	start_btn.text = "Start Battle"
	start_btn.add_theme_font_size_override("font_size", 32)
	start_btn.pressed.connect(func():
		var assignments = {}
		for d in dropdowns:
			var pid = d["opt"].get_item_id(d["opt"].selected)
			assignments[str(d["unit_id"])] = pid
		rpc_start_battle.rpc(index, JSON.stringify(assignments))
	)
	vbox.add_child(start_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.add_theme_font_size_override("font_size", 24)
	cancel_btn.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(cancel_btn)

@rpc("authority", "call_local", "reliable")
func rpc_start_battle(map_index: int, assignments_json: String) -> void:
	var maps = DataLibrary.get_all_maps()
	if map_index >= 0 and map_index < maps.size():
		var dict: Dictionary = JSON.parse_string(assignments_json)
		var parsed = {}
		for k in dict.keys():
			parsed[int(k)] = int(dict[k])
		_do_launch(maps[map_index], parsed)

func _do_launch(map: MapData, assignments: Dictionary) -> void:
	SkirmishLaunch.set_pending_encounter(map.encounter, assignments)
	get_tree().change_scene_to_file("res://scenes/TacticalCombat.tscn")
