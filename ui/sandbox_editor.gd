extends Control

const GRID_WIDTH = 17
const GRID_HEIGHT = 11

var grid_cells: Array[Button] = []
var board_data: Dictionary = {} # Maps Vector2i -> config dict
var board_tiles: Dictionary = {} # Maps Vector2i -> StringName

@onready var class_dropdown := $HBoxContainer/LeftSidebar/ClassDropdown
@onready var brush_dropdown := $HBoxContainer/LeftSidebar/BrushTypeDropdown
@onready var team_dropdown := $HBoxContainer/LeftSidebar/TeamDropdown

@onready var level_spinbox := $HBoxContainer/RightSidebar/LevelSpinbox
@onready var weapon_dropdown := $HBoxContainer/RightSidebar/WeaponDropdown
@onready var abilities_container := $HBoxContainer/RightSidebar/ScrollContainer/VBoxContainer/AbilitiesList
@onready var passives_container := $HBoxContainer/RightSidebar/ScrollContainer/VBoxContainer/PassivesList

var available_units: Array[UnitData] = []
var available_terrains: Array[TerrainData] = []
var selected_unit_data: UnitData = null
var selected_terrain_data: TerrainData = null

enum BrushMode { UNITS, TILES }
var current_brush_mode = BrushMode.UNITS

var selected_coord := Vector2i(-1, -1)
var _dragged_coord := Vector2i(-1, -1)
var remove_btn: Button

var preset_dropdown: OptionButton
var preset_input: LineEdit
var saved_presets: Dictionary = {}
var _delete_preset_dialog: ConfirmationDialog
var _preset_pending_delete: String = ""
const PRESETS_FILE = "user://sandbox_presets.json"

func _style_btn(btn: Button, bg_color: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = bg_color.lightened(0.2)
	var sb_pressed = sb.duplicate()
	sb_pressed.bg_color = bg_color.darkened(0.2)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_color_override("font_color", Color.WHITE)

func _ready() -> void:
	$HBoxContainer/LeftSidebar/BackButton.pressed.connect(_on_back_pressed)
	$HBoxContainer/RightSidebar/LaunchButton.pressed.connect(_on_launch_pressed)
	
	_style_btn($HBoxContainer/LeftSidebar/BackButton, Color(0.3, 0.3, 0.35))
	_style_btn($HBoxContainer/RightSidebar/LaunchButton, Color(0.2, 0.6, 0.3))
	
	var accent_color = Color(0.4, 0.8, 1.0)
	$HBoxContainer/LeftSidebar/Label2.add_theme_color_override("font_color", accent_color)
	$HBoxContainer/LeftSidebar/Label3.add_theme_color_override("font_color", accent_color)
	$HBoxContainer/LeftSidebar/Label4.add_theme_color_override("font_color", accent_color)
	$HBoxContainer/RightSidebar/Label.add_theme_color_override("font_color", accent_color)
	$HBoxContainer/RightSidebar/Label2.add_theme_color_override("font_color", accent_color)
	$HBoxContainer/RightSidebar/Label3.add_theme_color_override("font_color", accent_color)
	$HBoxContainer/RightSidebar/ScrollContainer/VBoxContainer/Label4.add_theme_color_override("font_color", accent_color)
	
	# Add a background behind the sidebars
	var left_bg = ColorRect.new()
	left_bg.color = Color(0.12, 0.12, 0.13)
	left_bg.show_behind_parent = true
	left_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	$HBoxContainer/LeftSidebar.add_child(left_bg)
	
	var right_bg = ColorRect.new()
	right_bg.color = Color(0.12, 0.12, 0.13)
	right_bg.show_behind_parent = true
	right_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	$HBoxContainer/RightSidebar.add_child(right_bg)
	
	team_dropdown.item_selected.connect(func(idx): _on_config_changed())
	level_spinbox.value_changed.connect(func(val): _on_config_changed())
	class_dropdown.item_selected.connect(_on_class_selected)
	brush_dropdown.item_selected.connect(_on_brush_type_selected)
	
	remove_btn = Button.new()
	remove_btn.text = "Remove Unit"
	_style_btn(remove_btn, Color(0.7, 0.2, 0.2))
	remove_btn.custom_minimum_size = Vector2(200, 40)
	remove_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	remove_btn.disabled = true
	remove_btn.pressed.connect(func():
		var coord = selected_coord
		_deselect_unit()
		board_data.erase(coord)
		_refresh_btn_visuals(coord, _get_btn(coord))
	)
	var main_area = $HBoxContainer/MainEditorArea
	main_area.add_child(remove_btn)
	
	# Preset UI
	var preset_vbox = VBoxContainer.new()
	preset_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var sep = HSeparator.new()
	sep.custom_minimum_size.y = 20
	preset_vbox.add_child(sep)
	
	var row1 = HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	var lbl = Label.new()
	lbl.text = "Map Presets:"
	lbl.add_theme_color_override("font_color", accent_color)
	preset_dropdown = OptionButton.new()
	preset_dropdown.custom_minimum_size.x = 200
	var btn_load = Button.new()
	btn_load.text = "Load"
	_style_btn(btn_load, Color(0.2, 0.6, 0.6))
	var btn_del = Button.new()
	btn_del.text = "Delete"
	_style_btn(btn_del, Color(0.7, 0.2, 0.2))
	row1.add_child(lbl)
	row1.add_child(preset_dropdown)
	row1.add_child(btn_load)
	row1.add_child(btn_del)
	
	var row2 = HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	preset_input = LineEdit.new()
	preset_input.placeholder_text = "Preset Name..."
	preset_input.custom_minimum_size.x = 200
	var btn_save = Button.new()
	btn_save.text = "Save Current Board"
	_style_btn(btn_save, Color(0.2, 0.4, 0.7))
	row2.add_child(preset_input)
	row2.add_child(btn_save)
	
	preset_vbox.add_child(row1)
	preset_vbox.add_child(row2)
	main_area.add_child(preset_vbox)
	
	_populate_dropdowns()
	_create_grid()
	
	_load_presets_from_disk()
	_refresh_preset_dropdown()
	
	_delete_preset_dialog = ConfirmationDialog.new()
	_delete_preset_dialog.title = "Delete Preset"
	_delete_preset_dialog.ok_button_text = "Delete"
	_delete_preset_dialog.cancel_button_text = "Cancel"
	_delete_preset_dialog.confirmed.connect(_on_delete_preset_confirmed)
	add_child(_delete_preset_dialog)
	
	btn_save.pressed.connect(func():
		var p_name = preset_input.text.strip_edges()
		if p_name.is_empty(): return
		saved_presets[p_name] = _serialize_board()
		_save_presets_to_disk()
		_refresh_preset_dropdown()
		
		var keys = saved_presets.keys()
		preset_dropdown.select(keys.find(p_name))
	)
	
	btn_load.pressed.connect(func():
		if preset_dropdown.item_count == 0: return
		var p_name = preset_dropdown.get_item_text(preset_dropdown.selected)
		if saved_presets.has(p_name):
			_deserialize_board(saved_presets[p_name])
	)
	
	btn_del.pressed.connect(func():
		if preset_dropdown.item_count == 0: return
		var p_name = preset_dropdown.get_item_text(preset_dropdown.selected)
		if not saved_presets.has(p_name): return
		_preset_pending_delete = p_name
		_delete_preset_dialog.dialog_text = 'Delete preset "%s"? This cannot be undone.' % p_name
		_delete_preset_dialog.popup_centered()
	)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_deselect_unit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if not get_viewport().gui_is_drag_successful():
			if _dragged_coord != Vector2i(-1, -1):
				if current_brush_mode == BrushMode.UNITS:
					board_data.erase(_dragged_coord)
					if selected_coord == _dragged_coord:
						_deselect_unit()
				elif current_brush_mode == BrushMode.TILES:
					board_tiles.erase(_dragged_coord)
					
				_refresh_btn_visuals(_dragged_coord, _get_btn(_dragged_coord))
			_dragged_coord = Vector2i(-1, -1)

func _populate_dropdowns() -> void:
	available_units = DataLibrary.get_all_player_units()
	available_units.append_array(DataLibrary.get_all_enemy_units())
	available_terrains = DataLibrary.get_all_terrains()
	
	brush_dropdown.add_item("Units", BrushMode.UNITS)
	brush_dropdown.add_item("Tiles", BrushMode.TILES)
	
	team_dropdown.add_item("Player", GameEnums.Team.PLAYER)
	team_dropdown.add_item("Enemy", GameEnums.Team.ENEMY)
	team_dropdown.add_item("Neutral", GameEnums.Team.NEUTRAL)
	
	weapon_dropdown.add_item("Basic Weapon", 0)
	
	_on_brush_type_selected(BrushMode.UNITS)

func _on_brush_type_selected(index: int) -> void:
	current_brush_mode = index as BrushMode
	class_dropdown.clear()
	
	if current_brush_mode == BrushMode.UNITS:
		for i in range(available_units.size()):
			class_dropdown.add_item(available_units[i].display_name)
	elif current_brush_mode == BrushMode.TILES:
		for i in range(available_terrains.size()):
			class_dropdown.add_item(available_terrains[i].display_name)
			
	class_dropdown.select(0)
	_on_class_selected(0)

func _create_grid() -> void:
	var container = $HBoxContainer/MainEditorArea/CenterContainer/GridContainer
	container.columns = GRID_WIDTH
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(40, 40)
			var coord := Vector2i(x, y)
			btn.set_meta("coord", coord)
			btn.gui_input.connect(func(event): _on_grid_gui_input(event, coord, btn))
			btn.set_drag_forwarding(
				func(pos): return _get_drag_data_for_btn(coord, btn, pos),
				func(pos, data): return _can_drop_data_for_btn(coord, btn, pos, data),
				func(pos, data): _drop_data_for_btn(coord, btn, pos, data)
			)
			container.add_child(btn)
			grid_cells.append(btn)
			_refresh_btn_visuals(coord, btn)

func _get_btn(coord: Vector2i) -> Button:
	var index = coord.y * GRID_WIDTH + coord.x
	if index >= 0 and index < grid_cells.size(): return grid_cells[index]
	return null

func _get_drag_data_for_btn(coord: Vector2i, btn: Button, pos: Vector2) -> Variant:
	if current_brush_mode == BrushMode.UNITS:
		if not board_data.has(coord): return null
	elif current_brush_mode == BrushMode.TILES:
		if not board_tiles.has(coord): return null
		
	_dragged_coord = coord
	var preview = Button.new()
	preview.text = btn.text
	preview.custom_minimum_size = Vector2(40, 40)
	
	var sb = StyleBoxFlat.new()
	var terrain_id = board_tiles.get(coord, &"plain")
	sb.bg_color = _get_tile_color(terrain_id)
	preview.add_theme_stylebox_override("normal", sb)
	
	if current_brush_mode == BrushMode.UNITS:
		preview.modulate = btn.get_theme_color("font_color")
	else:
		preview.text = ""
		
	preview.modulate.a = 0.5
	set_drag_preview(preview)
	return {"source_coord": coord, "mode": current_brush_mode}

func _can_drop_data_for_btn(coord: Vector2i, btn: Button, pos: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("source_coord"): return false
	if data.get("mode") != current_brush_mode: return false
	return true

func _drop_data_for_btn(coord: Vector2i, btn: Button, pos: Vector2, data: Variant) -> void:
	var src: Vector2i = data["source_coord"]
	if src == coord:
		_dragged_coord = Vector2i(-1, -1)
		return
		
	if current_brush_mode == BrushMode.UNITS:
		var temp = board_data.get(coord)
		board_data[coord] = board_data[src]
		if temp != null:
			board_data[src] = temp
		else:
			board_data.erase(src)
			
		if selected_coord == src:
			selected_coord = coord
		elif selected_coord == coord:
			selected_coord = src
			
	elif current_brush_mode == BrushMode.TILES:
		var temp = board_tiles.get(coord)
		if board_tiles.has(src):
			board_tiles[coord] = board_tiles[src]
		else:
			board_tiles.erase(coord)
			
		if temp != null:
			board_tiles[src] = temp
		else:
			board_tiles.erase(src)
			
	_dragged_coord = Vector2i(-1, -1)
	_refresh_btn_visuals(src, _get_btn(src))
	_refresh_btn_visuals(coord, btn)

func _on_grid_gui_input(event: InputEvent, coord: Vector2i, btn: Button) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if current_brush_mode == BrushMode.UNITS:
					if board_data.has(coord): _select_unit(coord)
					else: _place_brush_unit(coord, btn)
			else:
				# Mouse released
				if current_brush_mode == BrushMode.TILES:
					# Only paint if we didn't just finish a drag
					if _dragged_coord == Vector2i(-1, -1):
						_place_brush_tile(coord, btn)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_on_right_click(coord, btn)

func _on_left_click(coord: Vector2i, btn: Button) -> void:
	if board_data.has(coord):
		_select_unit(coord)
	else:
		if selected_coord != Vector2i(-1, -1):
			_deselect_unit()
		else:
			_place_brush_unit(coord, btn)

func _on_right_click(coord: Vector2i, btn: Button) -> void:
	if selected_coord != Vector2i(-1, -1):
		_deselect_unit()

func _select_unit(coord: Vector2i) -> void:
	var old_coord = selected_coord
	selected_coord = coord
	
	if old_coord != Vector2i(-1, -1):
		_refresh_btn_visuals(old_coord, _get_btn(old_coord))
		
	_refresh_btn_visuals(coord, _get_btn(coord))
	remove_btn.disabled = false
	
	var config = board_data[coord]
	for i in range(available_units.size()):
		if available_units[i].id == config.id:
			class_dropdown.select(i)
			selected_unit_data = available_units[i]
			break
			
	for i in range(team_dropdown.item_count):
		if team_dropdown.get_item_id(i) == config.team:
			team_dropdown.select(i)
			break
			
	level_spinbox.value = config.level
	
	_rebuild_right_panel()
	
	for opt in abilities_container.get_children():
		opt.select(0)
		for a in config.active_abilities:
			if a.id == opt.get_meta("data").id:
				if config.upgraded_abilities.has(a.id): opt.select(2)
				else: opt.select(1)
			
	for opt in passives_container.get_children():
		opt.select(0)
		for p in config.active_passives:
			if p.id == opt.get_meta("data").id:
				if config.upgraded_passives.has(p.id): opt.select(2)
				else: opt.select(1)

func _deselect_unit() -> void:
	if selected_coord != Vector2i(-1, -1):
		var old_coord = selected_coord
		selected_coord = Vector2i(-1, -1)
		_refresh_btn_visuals(old_coord, _get_btn(old_coord))
	remove_btn.disabled = true
	
	var sel = class_dropdown.get_selected_items()
	if sel.size() > 0:
		_on_class_selected(sel[0])

func _on_class_selected(index: int) -> void:
	if current_brush_mode == BrushMode.UNITS:
		selected_unit_data = available_units[index]
	elif current_brush_mode == BrushMode.TILES:
		selected_terrain_data = available_terrains[index]
	_rebuild_right_panel()
	
	if selected_coord != Vector2i(-1, -1):
		var config = board_data[selected_coord]
		config.id = selected_unit_data.id
		config.active_abilities.clear()
		config.active_passives.clear()
		_refresh_btn_visuals(selected_coord, _get_btn(selected_coord))

func _rebuild_right_panel() -> void:
	for child in abilities_container.get_children():
		child.queue_free()
	for child in passives_container.get_children():
		child.queue_free()
		
	var is_unit_selected = (selected_unit_data != null and current_brush_mode == BrushMode.UNITS)
	$HBoxContainer/RightSidebar/Label.visible = is_unit_selected
	level_spinbox.visible = is_unit_selected
	$HBoxContainer/RightSidebar/HSeparator.visible = is_unit_selected
	$HBoxContainer/RightSidebar/Label2.visible = is_unit_selected
	weapon_dropdown.visible = is_unit_selected
	$HBoxContainer/RightSidebar/HSeparator2.visible = is_unit_selected
	$HBoxContainer/RightSidebar/Label3.visible = is_unit_selected
	$HBoxContainer/RightSidebar/ScrollContainer/VBoxContainer/Label4.visible = is_unit_selected
	$HBoxContainer/RightSidebar/ScrollContainer/VBoxContainer/HSeparator3.visible = is_unit_selected
	abilities_container.visible = is_unit_selected
	passives_container.visible = is_unit_selected
		
	if not is_unit_selected:
		return
		
	for ability in selected_unit_data.abilities:
		var opt := OptionButton.new()
		opt.add_item(ability.display_name + " (Disabled)", 0)
		opt.add_item(ability.display_name, 1)
		opt.add_item(ability.display_name + " [+]", 2)
		opt.set_meta("data", ability)
		opt.item_selected.connect(func(v): _on_config_changed())
		abilities_container.add_child(opt)
		
	for passive in selected_unit_data.passives:
		var opt := OptionButton.new()
		opt.add_item(passive.display_name + " (Disabled)", 0)
		opt.add_item(passive.display_name, 1)
		opt.add_item(passive.display_name + " [+]", 2)
		opt.set_meta("data", passive)
		opt.item_selected.connect(func(v): _on_config_changed())
		passives_container.add_child(opt)

func _on_config_changed() -> void:
	if selected_coord != Vector2i(-1, -1):
		var config = board_data[selected_coord]
		config.team = team_dropdown.get_item_id(team_dropdown.selected)
		config.level = int(level_spinbox.value)
		
		config.active_abilities.clear()
		config.upgraded_abilities.clear()
		for opt in abilities_container.get_children():
			if opt.selected > 0:
				var data = opt.get_meta("data")
				config.active_abilities.append(data)
				if opt.selected == 2: config.upgraded_abilities.append(data.id)
			
		config.active_passives.clear()
		config.upgraded_passives.clear()
		for opt in passives_container.get_children():
			if opt.selected > 0:
				var data = opt.get_meta("data")
				config.active_passives.append(data)
				if opt.selected == 2: config.upgraded_passives.append(data.id)
			
		_refresh_btn_visuals(selected_coord, _get_btn(selected_coord))

func _place_brush_unit(coord: Vector2i, btn: Button) -> void:
	if selected_unit_data == null: return
	
	var config = {
		"id": selected_unit_data.id,
		"team": team_dropdown.get_item_id(team_dropdown.selected),
		"level": int(level_spinbox.value),
		"active_abilities": [],
		"active_passives": [],
		"upgraded_abilities": [],
		"upgraded_passives": []
	}
	
	for opt in abilities_container.get_children():
		if opt.selected > 0:
			var data = opt.get_meta("data")
			config.active_abilities.append(data)
			if opt.selected == 2: config.upgraded_abilities.append(data.id)
	
	for opt in passives_container.get_children():
		if opt.selected > 0:
			var data = opt.get_meta("data")
			config.active_passives.append(data)
			if opt.selected == 2: config.upgraded_passives.append(data.id)
			
	board_data[coord] = config
	_refresh_btn_visuals(coord, btn)

func _place_brush_tile(coord: Vector2i, btn: Button) -> void:
	if selected_terrain_data == null: return
	board_tiles[coord] = selected_terrain_data.id
	_refresh_btn_visuals(coord, btn)

func _get_tile_color(terrain_id: StringName) -> Color:
	var tile_color = Color(0.12, 0.12, 0.13)
	if terrain_id == &"wall": tile_color = Color(0.3, 0.3, 0.35)
	elif terrain_id == &"water": tile_color = Color(0.15, 0.25, 0.45)
	elif terrain_id == &"tall_grass": tile_color = Color(0.15, 0.35, 0.2)
	elif terrain_id == &"spikes": tile_color = Color(0.3, 0.1, 0.1)
	elif terrain_id == &"pit": tile_color = Color(0.05, 0.05, 0.05)
	elif terrain_id == &"castle": tile_color = Color(0.4, 0.3, 0.1)
	elif terrain_id == &"fire": tile_color = Color(0.6, 0.2, 0.0)
	elif terrain_id == &"oil": tile_color = Color(0.1, 0.1, 0.1)
	elif terrain_id == &"steam": tile_color = Color(0.4, 0.4, 0.5)
	elif terrain_id == &"frozen": tile_color = Color(0.3, 0.6, 0.8)
	elif terrain_id == &"cracked": tile_color = Color(0.2, 0.15, 0.1)
	elif terrain_id == &"smoke": tile_color = Color(0.25, 0.25, 0.25)
	return tile_color

func _refresh_btn_visuals(coord: Vector2i, btn: Button) -> void:
	if btn == null: return
	var has_unit = board_data.has(coord)
	var terrain_id = board_tiles.get(coord, &"plain")
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = _get_tile_color(terrain_id)
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	
	if coord == selected_coord:
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_color = Color.YELLOW
	
	btn.add_theme_stylebox_override("normal", sb)
	btn.modulate = Color.WHITE
	
	if not has_unit:
		btn.text = ""
		return
		
	var config = board_data[coord]
	var u_data = DataLibrary.get_unit(config.id)
	var initial = u_data.display_name.substr(0, 1) if u_data else "?"
	btn.text = initial
	
	var text_col = Color.WHITE
	if config.team == GameEnums.Team.PLAYER: text_col = Color(0.3, 0.7, 1.0)
	elif config.team == GameEnums.Team.ENEMY: text_col = Color(1.0, 0.3, 0.3)
	else: text_col = Color(0.8, 0.8, 0.8)
	btn.add_theme_color_override("font_color", text_col)

func _serialize_board() -> Dictionary:
	var j = {}
	var tiles_dict = {}
	for c in board_tiles:
		tiles_dict[str(c.x) + "," + str(c.y)] = board_tiles[c]
		
	var units_dict = {}
	for coord in board_data:
		var config = board_data[coord]
		var a_ids = []
		for a in config.active_abilities: a_ids.append(a.id)
		var p_ids = []
		for p in config.active_passives: p_ids.append(p.id)
		var ua_ids = config.get("upgraded_abilities", [])
		var up_ids = config.get("upgraded_passives", [])
		units_dict[str(coord.x) + "," + str(coord.y)] = {
			"id": config.id,
			"team": config.team,
			"level": config.level,
			"active_abilities": a_ids,
			"active_passives": p_ids,
			"upgraded_abilities": ua_ids,
			"upgraded_passives": up_ids
		}
		
	j["tiles"] = tiles_dict
	j["units"] = units_dict
	return j
	
func _deserialize_board(j: Dictionary) -> void:
	_deselect_unit()
	board_data.clear()
	board_tiles.clear()
	
	# Compatibility check for older saves that were just the units dict
	var tiles_j = {}
	var units_j = {}
	if j.has("tiles") and j.has("units"):
		tiles_j = j["tiles"]
		units_j = j["units"]
	else:
		units_j = j
		
	for key in tiles_j:
		var parts = key.split(",")
		var coord = Vector2i(int(parts[0]), int(parts[1]))
		board_tiles[coord] = tiles_j[key]
		
	for key in units_j:
		var parts = key.split(",")
		var coord = Vector2i(int(parts[0]), int(parts[1]))
		var c = units_j[key]
		var u_data = DataLibrary.get_unit(c.id)
		if not u_data: continue
		
		var a_arr: Array[AbilityData] = []
		for aid in c.active_abilities:
			for a in u_data.abilities:
				if a.id == aid: a_arr.append(a)
				
		var p_arr: Array[PassiveData] = []
		for pid in c.active_passives:
			for p in u_data.passives:
				if p.id == pid: p_arr.append(p)
				
		var ua_arr = []
		if c.has("upgraded_abilities"):
			for a in c.upgraded_abilities: ua_arr.append(a)
			
		var up_arr = []
		if c.has("upgraded_passives"):
			for p in c.upgraded_passives: up_arr.append(p)
			
		board_data[coord] = {
			"id": u_data.id,
			"team": c.team,
			"level": int(c.level),
			"active_abilities": a_arr,
			"active_passives": p_arr,
			"upgraded_abilities": ua_arr,
			"upgraded_passives": up_arr
		}
		
	for cell in grid_cells:
		_refresh_btn_visuals(cell.get_meta("coord"), cell)

func _load_presets_from_disk() -> void:
	if not FileAccess.file_exists(PRESETS_FILE): return
	var file = FileAccess.open(PRESETS_FILE, FileAccess.READ)
	if file:
		var txt = file.get_as_text()
		var json = JSON.parse_string(txt)
		if typeof(json) == TYPE_DICTIONARY:
			saved_presets = json
			
func _save_presets_to_disk() -> void:
	var file = FileAccess.open(PRESETS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(saved_presets, "\t"))

func _refresh_preset_dropdown() -> void:
	preset_dropdown.clear()
	for k in saved_presets.keys():
		preset_dropdown.add_item(k)

func _on_delete_preset_confirmed() -> void:
	if _preset_pending_delete.is_empty(): return
	if saved_presets.has(_preset_pending_delete):
		saved_presets.erase(_preset_pending_delete)
		_save_presets_to_disk()
		_refresh_preset_dropdown()
	_preset_pending_delete = ""

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/BattleSetup.tscn")

func _on_launch_pressed() -> void:
	var default_terrain = TerrainData.new()
	default_terrain.id = &"open"
	default_terrain.display_name = "Open"
	var board := BoardFactory.build_empty(Vector2i(GRID_WIDTH, GRID_HEIGHT), default_terrain)
	
	for coord in board_tiles.keys():
		var t_data = DataLibrary.get_terrain(board_tiles[coord])
		if t_data != null:
			board.tiles[coord] = TileState.create(coord, t_data)
	
	var next_id = 1
	for coord in board_data.keys():
		var config = board_data[coord]
		var u_data = DataLibrary.get_unit(config.id)
		if u_data != null:
			BoardFactory.place_configured_unit(board, next_id, u_data, config.team, coord, config)
			next_id += 1
			
	SkirmishLaunch.set_pending_board(board)
	get_tree().change_scene_to_file("res://scenes/TacticalCombat.tscn")
