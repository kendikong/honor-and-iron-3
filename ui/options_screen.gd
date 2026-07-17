extends Control

signal close_requested

func _ready() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	MenuNavigation.register(self, _on_back_pressed)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var tab_container := TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(tab_container)
	
	_build_display_tab(tab_container)
	_build_graphics_tab(tab_container)
	_build_sound_tab(tab_container)
	_build_gameplay_tab(tab_container)
	_build_controls_tab(tab_container)
	_build_interface_tab(tab_container)
	_build_developer_tab(tab_container)
	
func _build_display_tab(parent: TabContainer) -> void:
	var margin = MarginContainer.new()
	margin.name = "Display"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	parent.add_child(margin)
	
	var fs_check = CheckBox.new()
	fs_check.text = "Fullscreen"
	fs_check.button_pressed = get_window().mode == Window.MODE_FULLSCREEN
	vbox.add_child(fs_check)
	
	fs_check.toggled.connect(func(t: bool):
		if t:
			get_window().mode = Window.MODE_FULLSCREEN
		else:
			get_window().mode = Window.MODE_WINDOWED
	)
	
	var res_hbox = HBoxContainer.new()
	var res_lbl = Label.new()
	res_lbl.text = "Resolution: "
	res_hbox.add_child(res_lbl)
	
	var res_dd = OptionButton.new()
	var res_list: Array[Vector2i] = GameSettings.RESOLUTION_PRESETS
	for i: int in range(res_list.size()):
		res_dd.add_item("%d × %d" % [res_list[i].x, res_list[i].y], i)
		
	var current_sz = get_window().size
	for i in range(res_list.size()):
		if current_sz == res_list[i]:
			res_dd.select(i)
			break
	res_hbox.add_child(res_dd)
	vbox.add_child(res_hbox)
	
	vbox.add_child(Control.new()) # Spacer
	
	var apply_btn = Button.new()
	apply_btn.text = "Apply Settings"
	apply_btn.pressed.connect(func():
		var target_res: Vector2i = res_list[res_dd.get_selected_id()]
		var is_fs: bool = fs_check.button_pressed
		DisplayWindowHelper.apply_resolution(get_window(), target_res, is_fs)
		SettingsManager.save_settings(target_res.x, target_res.y, is_fs)
	)
	vbox.add_child(apply_btn)

func _build_graphics_tab(parent: TabContainer) -> void:
	var margin = MarginContainer.new()
	margin.name = "Graphics"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	var lbl = Label.new()
	lbl.text = "Graphics options placeholder..."
	margin.add_child(lbl)
	parent.add_child(margin)

func _build_sound_tab(parent: TabContainer) -> void:
	var margin = MarginContainer.new()
	margin.name = "Sound"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	parent.add_child(margin)
	
	var m_lbl = Label.new(); m_lbl.text = "Master Volume"
	var m_slider = HSlider.new(); m_slider.value = 100; m_slider.custom_minimum_size.x = 200
	vbox.add_child(m_lbl); vbox.add_child(m_slider)
	
	var s_lbl = Label.new(); s_lbl.text = "Sound Effects"
	var s_slider = HSlider.new(); s_slider.value = 100; s_slider.custom_minimum_size.x = 200
	vbox.add_child(s_lbl); vbox.add_child(s_slider)
	
	var mu_lbl = Label.new(); mu_lbl.text = "Music"
	var mu_slider = HSlider.new(); mu_slider.value = 100; mu_slider.custom_minimum_size.x = 200
	vbox.add_child(mu_lbl); vbox.add_child(mu_slider)

func _build_gameplay_tab(parent: TabContainer) -> void:
	var margin = MarginContainer.new()
	margin.name = "Gameplay"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	var lbl = Label.new()
	lbl.text = "Gameplay options placeholder..."
	margin.add_child(lbl)
	parent.add_child(margin)

func _build_controls_tab(parent: TabContainer) -> void:
	var margin = MarginContainer.new()
	margin.name = "Controls"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	parent.add_child(margin)
	
	var kb_lbl = Label.new(); kb_lbl.text = "Keyboard (Placeholder)"
	var ct_lbl = Label.new(); ct_lbl.text = "Controller (Placeholder)"
	vbox.add_child(kb_lbl); vbox.add_child(ct_lbl)

func _build_interface_tab(parent: TabContainer) -> void:
	var margin = MarginContainer.new()
	margin.name = "Interface"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	parent.add_child(margin)
	
	var c1 = CheckBox.new(); c1.text = "Show Damage Numbers"; c1.button_pressed = true; vbox.add_child(c1)
	var c2 = CheckBox.new(); c2.text = "Show Tile Display"; c2.button_pressed = true; vbox.add_child(c2)
	
	var s_lbl = Label.new(); s_lbl.text = "UI Scale"
	var s_slider = HSlider.new(); s_slider.value = 100; s_slider.custom_minimum_size.x = 200
	vbox.add_child(s_lbl); vbox.add_child(s_slider)
	
	var c3 = CheckBox.new(); c3.text = "Large Font"; vbox.add_child(c3)
	var c4 = CheckBox.new(); c4.text = "Show Tooltips"; c4.button_pressed = true; vbox.add_child(c4)
	var c5 = CheckBox.new(); c5.text = "Show Action Planning Window"; c5.button_pressed = true; vbox.add_child(c5)
	var c6 = CheckBox.new(); c6.text = "Show Prediction"; c6.button_pressed = true; vbox.add_child(c6)
	
	var indent = MarginContainer.new()
	indent.add_theme_constant_override("margin_left", 20)
	var sub_vbox = VBoxContainer.new()
	indent.add_child(sub_vbox)
	vbox.add_child(indent)
	
	var c7 = CheckBox.new(); c7.text = "Movement Prediction"; c7.button_pressed = true; sub_vbox.add_child(c7)
	var c8 = CheckBox.new(); c8.text = "Attack Prediction"; c8.button_pressed = true; sub_vbox.add_child(c8)
	
	var c9 = CheckBox.new(); c9.text = "Show Autobattler HUD"; c9.button_pressed = true; vbox.add_child(c9)

func _build_developer_tab(parent: TabContainer) -> void:
	var margin = MarginContainer.new()
	margin.name = "Developer"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	var lbl = Label.new()
	lbl.text = "Developer options placeholder..."
	margin.add_child(lbl)
	parent.add_child(margin)

func _on_back_pressed() -> void:
	if close_requested.get_connections().size() > 0:
		close_requested.emit()
	else:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
