extends CharacterGeneratorPanel

const CATALOG_PATH: String = "res://resources/character/lpc_catalog.json"
const _CLASS_LOADOUTS = preload("res://scripts/lpc/lpc_class_loadout_defaults.gd")

var _class_loadout_class_opt: OptionButton
var _preview_class_opt: OptionButton
var _class_loadout_vbox: VBoxContainer
var _class_loadout_rows: Dictionary = {}
var _selected_loadout_class: String = "knight"

func _ready() -> void:
	super._ready()
	# Optional: visually distinguish the editor
	if _panel != null:
		var sb := _panel.get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb.bg_color = Color(0.12, 0.1, 0.15, 0.95) # Slight purple tint to denote DEV editor
			
	# Add a global save button at the top
	var save_btn := Button.new()
	save_btn.text = "💾 Save Master Catalog"
	save_btn.add_theme_font_size_override("font_size", 16)
	save_btn.custom_minimum_size.y = 40
	save_btn.pressed.connect(_save_catalog)
	
	var outer = _panel.get_child(0)
	var split = outer.get_child(0)
	var left_scroll = split.get_child(0)
	var left_vbox = left_scroll.get_child(0)
	left_vbox.add_child(save_btn)
	left_vbox.move_child(save_btn, 1)
	
	# Scale all text by 2x
	_double_font_sizes(self)
	generated.connect(func(_report, _recipe): _double_font_sizes(_parts_section_vbox))

func _double_font_sizes(node: Node) -> void:
	if node is Control:
		if node.has_theme_font_size_override("font_size"):
			var fs = node.get_theme_font_size("font_size")
			node.add_theme_font_size_override("font_size", fs * 2)
		else:
			node.add_theme_font_size_override("font_size", 28)
	for c in node.get_children():
		_double_font_sizes(c)

func _build_ui() -> void:
	super._build_ui()
	
	# Make it full screen
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 0
	
	# Restructure the UI to be a split screen
	var outer: MarginContainer = _panel.get_child(0)
	var main_scroll: ScrollContainer = outer.get_child(0)
	var main_vbox: VBoxContainer = main_scroll.get_child(0)
	
	# Remove the scroll from outer so we can split
	outer.remove_child(main_scroll)
	
	var split := HBoxContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 24)
	outer.add_child(split)
	
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 1.0
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(left_scroll)
	
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left_vbox)
	
	var vsep := VSeparator.new()
	split.add_child(vsep)
	
	var mid_scroll := ScrollContainer.new()
	mid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_scroll.size_flags_stretch_ratio = 1.0
	mid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(mid_scroll)
	
	var mid_vbox := VBoxContainer.new()
	mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_scroll.add_child(mid_vbox)
	
	var vsep2 := VSeparator.new()
	split.add_child(vsep2)
	
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_stretch_ratio = 1.5
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(right_scroll)
	
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_vbox)
	
	# Move children from the original main_vbox to left/mid/right columns
	var children := main_vbox.get_children()
	for i in range(children.size()):
		var c = children[i]
		main_vbox.remove_child(c)
		
		var is_current_parts_hdr = false
		if c is HBoxContainer and c.get_child_count() > 0 and c.get_child(0) is Label and c.get_child(0).text == "Current Parts":
			is_current_parts_hdr = true
			
		if is_current_parts_hdr or c == _parts_section_vbox or (c is Label and c.text == "Press Generate to see parts"):
			mid_vbox.add_child(c)
		elif c == _item_section_toggle:
			c.queue_free()
		elif c == _item_section_vbox:
			var right_header = Label.new()
			right_header.text = "Master Catalog"
			right_header.add_theme_font_size_override("font_size", 16)
			right_header.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
			right_vbox.add_child(right_header)
			
			var search = LineEdit.new()
			search.placeholder_text = "Search by item name or tag..."
			search.text_changed.connect(_on_search_changed)
			right_vbox.add_child(search)
			
			c.visible = true
			right_vbox.add_child(c)
		else:
			left_vbox.add_child(c)

	_build_class_loadout_section(left_vbox)
			
	# Enlarge the preview viewport significantly now that we have space
	_preview_container.custom_minimum_size = Vector2(500, 400)
	_preview_viewport.size = Vector2i(500, 400)
	if _preview_node:
		_preview_node.position = Vector2(250, 320)
		_preview_node.scale = Vector2(4.0, 4.0)

func _save_catalog() -> void:
	var out := {
		"version": 2,
		"body_types": _catalog.body_types,
		"skin_recolors": _catalog.skin_recolors,
		"hair_recolors": _catalog.hair_recolors,
		"cloth_recolors": _catalog.cloth_recolors,
		"slots": _catalog.slots
	}
	var file := FileAccess.open(CATALOG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(out, "\t"))
		file.close()
	print("Catalog saved to disk!")

func _save_config() -> void:
	super._save_config()
	if _catalog != null:
		_save_catalog()

func _add_part_toggle_row(parent: VBoxContainer, item_id: String, weight_key: String, current_weight: float) -> HSlider:
	# Find the item dict
	var slot: String = ""
	var item_dict: Dictionary = {}
	if _catalog != null:
		for s in _catalog.slots.keys():
			var items: Array = _catalog.slots[s].get("items", [])
			for i in range(items.size()):
				var item: Dictionary = items[i]
				if str(item.get("id", "")) == item_id:
					slot = str(s)
					item_dict = item
					break
			if not slot.is_empty(): break

	if item_dict.is_empty():
		return super._add_part_toggle_row(parent, item_id, weight_key, current_weight)

	# Create wrapper
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0,0,0, 0.2)
	sb.set_corner_radius_all(4)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.add_child(wrapper)
	parent.add_child(panel)

	# Call super to build top row
	var sl := super._add_part_toggle_row(wrapper, item_id, weight_key, current_weight)
	var top_row = wrapper.get_child(0)

	_inject_advanced_panel(wrapper, top_row, item_dict)
	return sl

func _inject_advanced_panel(wrapper: Container, top_row: Container, item_dict: Dictionary) -> void:
	var adv_panel := PanelContainer.new()
	adv_panel.visible = false
	var adv_bg := StyleBoxFlat.new()
	adv_bg.bg_color = Color(0.1, 0.12, 0.16)
	adv_bg.content_margin_left = 8
	adv_bg.content_margin_right = 8
	adv_bg.content_margin_top = 8
	adv_bg.content_margin_bottom = 8
	adv_bg.set_corner_radius_all(4)
	adv_panel.add_theme_stylebox_override("panel", adv_bg)
	wrapper.add_child(adv_panel)

	var edit_btn := Button.new()
	edit_btn.text = "⚙"
	edit_btn.flat = true
	edit_btn.pressed.connect(func():
		adv_panel.visible = not adv_panel.visible
		edit_btn.add_theme_color_override("font_color", Color.YELLOW if adv_panel.visible else Color.WHITE)
	)
	top_row.add_child(edit_btn)
	# Insert it right after the main toggle or label. If there's 4 children (CheckButton, OptionButton, Slider, Label) vs 3 (Label, Slider, Label), we just put it near the front.
	if top_row.get_child_count() >= 4:
		top_row.move_child(edit_btn, 2)
	else:
		top_row.move_child(edit_btn, 1)

	# --- Advanced Panel Contents ---
	var adv_vbox := VBoxContainer.new()
	adv_panel.add_child(adv_vbox)

	var z_hbox := HBoxContainer.new()
	adv_vbox.add_child(z_hbox)
	var z_lbl := Label.new()
	z_lbl.text = "Z-Pos:"
	z_hbox.add_child(z_lbl)
	var z_spin := SpinBox.new()
	z_spin.min_value = -1000
	z_spin.max_value = 1000
	z_spin.value = float(item_dict.get("z_pos", 0))
	z_spin.value_changed.connect(func(v: float, ref: Dictionary = item_dict): ref["z_pos"] = int(v))
	z_hbox.add_child(z_spin)

	var t_hbox := HBoxContainer.new()
	adv_vbox.add_child(t_hbox)
	var t_lbl := Label.new()
	t_lbl.text = "Tags:"
	t_lbl.custom_minimum_size.x = 60
	t_hbox.add_child(t_lbl)
	var t_edit := LineEdit.new()
	t_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t_arr: Variant = item_dict.get("tags", [])
	if typeof(t_arr) == TYPE_ARRAY:
		t_edit.text = ", ".join(t_arr)
	t_edit.text_changed.connect(func(v: String, ref: Dictionary = item_dict): ref["tags"] = _parse_csv(v))
	t_hbox.add_child(t_edit)

	var r_hbox := HBoxContainer.new()
	adv_vbox.add_child(r_hbox)
	var r_lbl := Label.new()
	r_lbl.text = "Requires:"
	r_lbl.custom_minimum_size.x = 60
	r_hbox.add_child(r_lbl)
	var r_edit := LineEdit.new()
	r_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r_arr: Variant = item_dict.get("requires_tags", [])
	if typeof(r_arr) == TYPE_ARRAY:
		r_edit.text = ", ".join(r_arr)
	r_edit.text_changed.connect(func(v: String, ref: Dictionary = item_dict): ref["requires_tags"] = _parse_csv(v))
	r_hbox.add_child(r_edit)

	var ex_hbox := HBoxContainer.new()
	adv_vbox.add_child(ex_hbox)
	var ex_lbl := Label.new()
	ex_lbl.text = "Excludes:"
	ex_lbl.custom_minimum_size.x = 60
	ex_hbox.add_child(ex_lbl)
	var ex_edit := LineEdit.new()
	ex_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ex_arr: Variant = item_dict.get("excludes_tags", [])
	if typeof(ex_arr) == TYPE_ARRAY:
		ex_edit.text = ", ".join(ex_arr)
	ex_edit.text_changed.connect(func(v: String, ref: Dictionary = item_dict): ref["excludes_tags"] = _parse_csv(v))
	ex_hbox.add_child(ex_edit)

	var bt_grid := GridContainer.new()
	bt_grid.columns = 3
	adv_vbox.add_child(bt_grid)
	
	var req_bt: Variant = item_dict.get("required_body_types", [])
	var req_arr: Array = []
	if typeof(req_bt) == TYPE_ARRAY:
		req_arr = req_bt
		
	var all_types := ["human", "non-human", "male", "female", "teen", "child", "muscular", "pregnant", "skeleton", "zombie"]
	for bt in all_types:
		var cb := CheckButton.new()
		cb.text = bt
		cb.button_pressed = req_arr.has(bt)
		cb.toggled.connect(func(on: bool, b: String = bt, ref: Dictionary = item_dict): _toggle_body_type(on, b, ref))
		bt_grid.add_child(cb)

func _rebuild_item_sliders() -> void:
	for c in _item_section_vbox.get_children():
		c.queue_free()
	_item_sliders.clear()
	if _catalog == null:
		return
	var categories := {}
	
	for slot: String in _catalog.slot_names():
		for raw: Variant in _catalog.items_for_slot(slot):
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = raw
			var id: String = str(item.get("id", ""))
			if id.is_empty() or _item_sliders.has(id):
				continue
				
			var id_parts := id.split("_")
			var cat_name := id_parts[0] if id_parts.size() > 0 else "misc"
			
			if not categories.has(cat_name):
				var btn := Button.new()
				btn.text = "▼  " + cat_name.capitalize()
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				btn.flat = true
				_item_section_vbox.add_child(btn)
				
				var cvbox := VBoxContainer.new()
				cvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cvbox.add_theme_constant_override("separation", 4)
				_item_section_vbox.add_child(cvbox)
				
				categories[cat_name] = cvbox
				btn.pressed.connect(func(v=cvbox, b=btn, n=cat_name):
					v.visible = not v.visible
					b.text = ("▼  " if v.visible else "▶  ") + n.capitalize()
				)
				
			var category_vbox: VBoxContainer = categories[cat_name]
			var w: float = _profile.item_weights.get(id, 1.0)
			
			var tags = item.get("tags", [])
			var tag_str = ""
			if typeof(tags) == TYPE_ARRAY:
				tag_str = " ".join(tags)
			var auto_tags = id.replace("_", " ")
			
			var row_container = VBoxContainer.new()
			row_container.set_meta("search_str", (id + " " + tag_str + " " + auto_tags).to_lower())
			category_vbox.add_child(row_container)
			
			var sl := _add_part_toggle_row(row_container, id, id, w)
			_item_sliders[id] = sl


func _parse_csv(text: String) -> Array:
	var clean := text.replace(",", " ")
	var arr := clean.split(" ", false)
	var out := []
	for s in arr:
		var st := s.strip_edges()
		if not st.is_empty() and not out.has(st):
			out.append(st)
	return out

func _toggle_body_type(on: bool, bt: String, item: Dictionary) -> void:
	var req_bt: Variant = item.get("required_body_types")
	if typeof(req_bt) != TYPE_ARRAY:
		req_bt = []
		item["required_body_types"] = req_bt
	
	if on and not req_bt.has(bt):
		req_bt.append(bt)
	elif not on and req_bt.has(bt):
		req_bt.erase(bt)

func _on_search_changed(query: String) -> void:
	var q = query.to_lower().strip_edges()
	for child in _item_section_vbox.get_children():
		if child is VBoxContainer:
			var category_vbox = child
			var any_visible = false
			for c in category_vbox.get_children():
				if c is VBoxContainer:
					if q.is_empty():
						c.visible = true
						any_visible = true
					else:
						var s: String = c.get_meta("search_str", "")
						c.visible = s.contains(q)
						if c.visible:
							any_visible = true
							
			var btn = _item_section_vbox.get_child(child.get_index() - 1)
			if btn is Button:
				btn.visible = any_visible
				if not q.is_empty() and any_visible:
					category_vbox.visible = true
					var n = btn.text.replace("▶  ", "").replace("▼  ", "")
					btn.text = "▼  " + n


func _on_generate_pressed() -> void:
	if _catalog == null or _preview_node == null:
		return
	_profile.seed = randi() % 100000
	_save_config()
	var preview_class: String = _preview_class_id()
	_preview_node.roll_and_apply(_catalog, _profile, preview_class)


func _preview_class_id() -> String:
	if _preview_class_opt == null or _preview_class_opt.selected <= 0:
		return ""
	return str(_preview_class_opt.get_item_metadata(_preview_class_opt.selected))


func _build_class_loadout_section(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())
	var hdr := Label.new()
	hdr.text = "Class Loadouts"
	hdr.add_theme_font_size_override("font_size", 16)
	hdr.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	parent.add_child(hdr)

	var hint := Label.new()
	hint.text = "Force slot items per player class. Combat units use their class id automatically."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	parent.add_child(hint)

	var class_row := HBoxContainer.new()
	var class_lbl := Label.new()
	class_lbl.text = "Edit class"
	class_lbl.custom_minimum_size.x = 90
	class_row.add_child(class_lbl)
	_class_loadout_class_opt = OptionButton.new()
	_class_loadout_class_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for class_id: String in _CLASS_LOADOUTS.PLAYER_CLASS_IDS:
		_class_loadout_class_opt.add_item(class_id.capitalize())
		_class_loadout_class_opt.set_item_metadata(_class_loadout_class_opt.item_count - 1, class_id)
	class_row.add_child(_class_loadout_class_opt)
	parent.add_child(class_row)

	var preview_row := HBoxContainer.new()
	var preview_lbl := Label.new()
	preview_lbl.text = "Preview as"
	preview_lbl.custom_minimum_size.x = 90
	preview_row.add_child(preview_lbl)
	_preview_class_opt = OptionButton.new()
	_preview_class_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_class_opt.add_item("(Random — no class)")
	_preview_class_opt.set_item_metadata(0, "")
	for class_id: String in _CLASS_LOADOUTS.PLAYER_CLASS_IDS:
		_preview_class_opt.add_item(class_id.capitalize())
		_preview_class_opt.set_item_metadata(_preview_class_opt.item_count - 1, class_id)
	preview_row.add_child(_preview_class_opt)
	parent.add_child(preview_row)

	var reset_btn := Button.new()
	reset_btn.text = "Reset class loadouts to defaults"
	reset_btn.pressed.connect(_on_reset_class_loadouts_pressed)
	parent.add_child(reset_btn)

	_class_loadout_vbox = VBoxContainer.new()
	_class_loadout_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_loadout_vbox.add_theme_constant_override("separation", 4)
	parent.add_child(_class_loadout_vbox)

	_class_loadout_class_opt.item_selected.connect(func(_idx: int) -> void:
		_selected_loadout_class = str(
			_class_loadout_class_opt.get_item_metadata(_class_loadout_class_opt.selected)
		)
		_refresh_class_loadout_rows()
	)
	_selected_loadout_class = str(
		_class_loadout_class_opt.get_item_metadata(_class_loadout_class_opt.selected)
	)
	_rebuild_class_loadout_rows()


func _on_reset_class_loadouts_pressed() -> void:
	_profile.class_loadouts = _CLASS_LOADOUTS.build().duplicate(true)
	_save_config()
	_refresh_class_loadout_rows()


func _rebuild_class_loadout_rows() -> void:
	for c: Node in _class_loadout_vbox.get_children():
		c.queue_free()
	_class_loadout_rows.clear()
	if _catalog == null:
		return
	for slot_name: String in _CLASS_LOADOUTS.OVERRIDE_SLOTS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot_lbl := Label.new()
		slot_lbl.text = slot_name
		slot_lbl.custom_minimum_size.x = 88
		slot_lbl.clip_text = true
		row.add_child(slot_lbl)
		var force := CheckButton.new()
		force.text = "Force"
		force.custom_minimum_size.x = 72
		row.add_child(force)
		var item_opt := OptionButton.new()
		item_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_opt.add_item("(none)")
		item_opt.set_item_metadata(0, "")
		for raw: Variant in _catalog.items_for_slot(slot_name):
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = raw
			var item_id: String = str(item.get("id", ""))
			if item_id.is_empty():
				continue
			var label: String = str(item.get("name", item_id))
			item_opt.add_item("%s (%s)" % [label, item_id])
			item_opt.set_item_metadata(item_opt.item_count - 1, item_id)
		row.add_child(item_opt)
		_class_loadout_vbox.add_child(row)
		_class_loadout_rows[slot_name] = {"force": force, "items": item_opt}
		force.toggled.connect(func(on: bool, slot: String = slot_name) -> void:
			_on_class_loadout_force_toggled(slot, on)
		)
		item_opt.item_selected.connect(func(_idx: int, slot: String = slot_name) -> void:
			_on_class_loadout_item_selected(slot)
		)
	_refresh_class_loadout_rows()


func _refresh_class_loadout_rows() -> void:
	if _profile == null:
		return
	for slot_name: String in _class_loadout_rows.keys():
		var row_data: Dictionary = _class_loadout_rows[slot_name]
		var force: CheckButton = row_data["force"]
		var item_opt: OptionButton = row_data["items"]
		var forced_id: String = _profile.class_forced_item(_selected_loadout_class, slot_name)
		force.set_block_signals(true)
		force.button_pressed = not forced_id.is_empty()
		force.set_block_signals(false)
		item_opt.set_block_signals(true)
		var pick_idx: int = 0
		for i in range(item_opt.item_count):
			if str(item_opt.get_item_metadata(i)) == forced_id:
				pick_idx = i
				break
		item_opt.selected = pick_idx
		item_opt.set_block_signals(false)


func _on_class_loadout_force_toggled(slot_name: String, on: bool) -> void:
	if _profile == null:
		return
	if not on:
		_profile.set_class_forced_item(_selected_loadout_class, slot_name, "")
		_save_config()
		_refresh_class_loadout_rows()
		return
	_on_class_loadout_item_selected(slot_name)


func _on_class_loadout_item_selected(slot_name: String) -> void:
	if _profile == null or not _class_loadout_rows.has(slot_name):
		return
	var row_data: Dictionary = _class_loadout_rows[slot_name]
	var item_opt: OptionButton = row_data["items"]
	var force: CheckButton = row_data["force"]
	var item_id: String = str(item_opt.get_item_metadata(item_opt.selected))
	if item_id.is_empty():
		force.set_block_signals(true)
		force.button_pressed = false
		force.set_block_signals(false)
		_profile.set_class_forced_item(_selected_loadout_class, slot_name, "")
	else:
		force.set_block_signals(true)
		force.button_pressed = true
		force.set_block_signals(false)
		_profile.set_class_forced_item(_selected_loadout_class, slot_name, item_id)
		var fill_chance: float = _profile.class_slot_fill_chance(
			_selected_loadout_class,
			slot_name,
			1.0,
		)
		if fill_chance < 1.0:
			_profile.set_class_slot_fill(_selected_loadout_class, slot_name, 1.0)
	_save_config()
