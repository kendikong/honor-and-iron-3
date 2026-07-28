extends Control

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
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_top = 100
	center.add_child(grid)
	add_child(center)
	
	for i in range(DataLibrary.get_all_maps().size()):
		var map = DataLibrary.get_all_maps()[i]
		var card := _build_map_card(map, i)
		grid.add_child(card)

	grid.add_child(_build_skirmish_card())
	
	var custom_card := _build_custom_card()
	grid.add_child(custom_card)
	
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
	desc.text = "Procedural map — configure roster, levels, passives, and skills."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 16)
	vbox.add_child(desc)

	return btn


func _show_skirmish_picker() -> void:
	var overlay := ColorRect.new()
	overlay.name = "SkirmishPicker"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0, 0, 0, 0.88)
	add_child(overlay)

	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.5
	scroll.anchor_top = 0.5
	scroll.anchor_right = 0.5
	scroll.anchor_bottom = 0.5
	scroll.offset_left = -280
	scroll.offset_top = -300
	scroll.offset_right = 280
	scroll.offset_bottom = 300
	overlay.add_child(scroll)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 12)
	scroll.add_child(panel)

	var title := Label.new()
	title.text = "Random Skirmish Setup"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)

	var setup_fields := SkirmishSetupFields.new()
	setup_fields.load_setup(MassSimSkirmishSetup.load_last_saved())
	panel.add_child(setup_fields)

	var size_lbl := Label.new()
	size_lbl.text = "Map size (select one)"
	size_lbl.add_theme_font_size_override("font_size", 20)
	panel.add_child(size_lbl)

	var preset_grid := GridContainer.new()
	preset_grid.columns = 2
	preset_grid.add_theme_constant_override("h_separation", 12)
	preset_grid.add_theme_constant_override("v_separation", 10)
	panel.add_child(preset_grid)

	var selected_size: Array[Vector2i] = [Vector2i.ZERO]

	for preset: Vector2i in TacticalConstants.SKIRMISH_PRESETS:
		var pick := Button.new()
		pick.text = "%d × %d" % [preset.x, preset.y]
		pick.custom_minimum_size = Vector2(180, 44)
		pick.pressed.connect(func() -> void:
			selected_size[0] = preset
			for child: Node in preset_grid.get_children():
				if child is Button:
					(child as Button).modulate = Color(0.65, 0.65, 0.65)
			pick.modulate = Color.WHITE
		)
		preset_grid.add_child(pick)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	panel.add_child(btn_row)

	var launch := Button.new()
	launch.text = "Launch Skirmish"
	launch.custom_minimum_size = Vector2(180, 48)
	launch.pressed.connect(func() -> void:
		if selected_size[0] == Vector2i.ZERO:
			return
		var setup: MassSimSkirmishSetup = setup_fields.read_setup()
		MassSimSkirmishSetup.save_last(setup)
		_launch_skirmish(selected_size[0], setup)
	)
	btn_row.add_child(launch)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(120, 48)
	cancel.pressed.connect(func() -> void: overlay.queue_free())
	btn_row.add_child(cancel)


func _launch_skirmish(size_preset: Vector2i, setup: MassSimSkirmishSetup) -> void:
	var picker: Node = get_node_or_null("SkirmishPicker")
	if picker != null:
		picker.queue_free()
	var config := SkirmishGenerator.SkirmishConfig.new()
	config.size_preset = size_preset
	config.map_seed = randi()
	config.skirmish_setup = setup.to_dict()
	SkirmishLaunch.set_pending(config)
	get_tree().change_scene_to_file("res://scenes/TacticalCombat.tscn")


func _build_custom_card() -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 200)
	btn.pressed.connect(_launch_custom)
	
	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)
	
	var color := ColorRect.new()
	color.custom_minimum_size = Vector2(0, 100)
	color.color = Color(0.2, 0.2, 0.2)
	color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(color)
	
	var title := Label.new()
	title.text = "Custom Sandbox"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var desc := Label.new()
	desc.text = "A randomized sandbox map. (A full visual map editor will be added in the future!)"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 16)
	vbox.add_child(desc)
	
	return btn

func _launch_custom() -> void:
	get_tree().change_scene_to_file("res://scenes/SandboxEditor.tscn")

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
	var scene = load("res://scenes/Combat.tscn").instantiate()
	scene.name = "Combat"
	get_tree().root.add_child(scene)
	scene.get_node("CombatDirector").start_from_encounter(map.encounter, assignments)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = scene
