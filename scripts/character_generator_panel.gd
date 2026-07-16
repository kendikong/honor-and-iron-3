class_name CharacterGeneratorPanel
extends CanvasLayer

## Dedicated dockable panel for the Character Generator.
## Hosts per-slot, per-body-type, and per-item-ID weight sliders,
## a Generate button, and an embedded CharacterPreview viewport.

const PANEL_WIDTH: int = 405
const CFG_PATH: String = "user://character_gen.cfg"

# Slot names as displayed in the UI (mirrors web app categories).
const DISPLAY_SLOTS: PackedStringArray = [
	"body", "head", "ears", "ears_inner", "furry_ears", "furry_ears_skin", "nose", 
	"eyes", "eyebrows", "facial_eyes", "facial_left", "facial_left_trim", 
	"facial_mask", "facial_right", "facial_right_trim", 
	"beard", "mustache", "expression", "expression_crying", "wrinkles",
	"hair", "hairextl", "hairextr", "hairtie", "hairtie_rune", "ponytail", "updo", 
	"horns", "wings", "wings_dots", "wings_edge", "tail", "fins", 
	"wound_eye_left", "wound_eye_right", "wound_mouth", "wound_ribs", "wound_arm", "wound_brain",
	"hat", "hat_accessory", "hat_buckle", "hat_overlay", "hat_trim", "headcover", "headcover_rune", "bandana", "bandana_overlay", "visor", 
	"accessory", "earrings", "earring_left", "earring_right", "charm", "necklace", "ring",
	"clothes", "dress", "dress_sleeves", "dress_sleeves_trim", "dress_trim", 
	"jacket", "jacket_collar", "jacket_pockets", "jacket_trim", "overalls", "apron", "sleeves", "vest",
	"armour", "shoulders", "bauldron", "bracers", "gloves", "wrists", 
	"chainmail", "belt", "buckles", "sash", "sash_tie", "cape", "cape_trim", 
	"backpack", "backpack_straps", "cargo", "quiver", 
	"bandages", "neck", "legs", "socks", "shoes", "shoes_toe", 
	"weapon", "weapon_magic_crystal", "shield", "shield_paint", "shield_pattern", "shield_trim",
	"prosthesis_hand", "prosthesis_leg", "arms", "shadow"
]

# ---- state ----
var _profile: CharacterGenProfile
var _catalog: LpcCatalog

# ---- widgets ----
var _panel: PanelContainer
var _slot_sliders: Dictionary = {}      # slot_name -> HSlider
var _body_sliders: Dictionary = {}      # body_type -> HSlider
var _item_sliders: Dictionary = {}      # item_id -> HSlider
var _item_section_vbox: VBoxContainer
var _item_section_toggle: Button
var _item_section_visible: bool = false
var _generate_btn: Button
var _seed_spin: SpinBox
var _report_label: Label
var _parts_section_vbox: VBoxContainer   # current-character part sliders
var _part_saved_weights: Dictionary = {} # item_id -> float before zeroing
var _preview_container: SubViewportContainer
var _preview_viewport: SubViewport
var _preview_node: CharacterPreview

signal generated(report: Dictionary, recipe: CharacterRecipe)
signal part_visibility_changed(item_id: String, visible: bool)


func _ready() -> void:
	layer = 25
	_profile = CharacterGenProfile.new()
	_load_config()
	_catalog = LpcCatalog.load_from_disk()
	_build_ui()
	_preview_node.roll_and_apply.call_deferred(_catalog, _profile)


# ---- public API ----

func set_catalog(catalog: LpcCatalog) -> void:
	_catalog = catalog

func get_profile() -> CharacterGenProfile:
	return _profile

## Hide or show an item's layers on both the preview and (via signal) the in-game actor.
func set_part_visible(item_id: String, visible: bool) -> void:
	if _preview_node != null:
		_preview_node.set_item_visibility(item_id, visible)
	part_visibility_changed.emit(item_id, visible)


# ---- config persistence ----

func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		_profile.load_from_config(cfg)

func _save_config() -> void:
	var cfg := ConfigFile.new()
	_profile.save_to_config(cfg)
	cfg.save(CFG_PATH)


# ---- UI construction ----

func _build_ui() -> void:
	var screen_root := Control.new()
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_root)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -float(PANEL_WIDTH)
	_panel.add_theme_stylebox_override("panel", _panel_style())
	screen_root.add_child(_panel)

	var outer := MarginContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		outer.add_theme_constant_override(m, 8)
	_panel.add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(vbox)
	outer.add_child(scroll)

	# Title
	_add_section_label(vbox, "⚙  Character Generator")

	# Seed
	_add_labeled_spinbox(vbox, "Seed", 0, 99999, _profile.seed,
		func(v: float) -> void:
			_profile.seed = int(v); _save_config()
	)
	var adv_btn := Button.new()
	adv_btn.text = "▶  Advanced Filters"
	adv_btn.flat = true
	adv_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(adv_btn)
	
	var adv_panel := VBoxContainer.new()
	adv_panel.visible = false
	vbox.add_child(adv_panel)
	
	adv_btn.pressed.connect(func():
		adv_panel.visible = not adv_panel.visible
		adv_btn.text = "▼  Advanced Filters" if adv_panel.visible else "▶  Advanced Filters"
	)
	
	_add_section_label(adv_panel, "Require Native Animations")
	var anim_grid := GridContainer.new()
	anim_grid.columns = 3
	adv_panel.add_child(anim_grid)
	
	var filter_actions = [
		"run", "climb", "jump", "sit", "emote", "combat_idle",
		"slash", "thrust", "spellcast", "shoot", "hurt"
	]
	for act in filter_actions:
		var cb := CheckBox.new()
		cb.text = act.capitalize()
		cb.button_pressed = _profile.required_animations.has(act)
		cb.toggled.connect(func(on: bool, a: String = act):
			if on and not _profile.required_animations.has(a):
				_profile.required_animations.append(a)
			elif not on and _profile.required_animations.has(a):
				_profile.required_animations.erase(a)
			_save_config()
		)
		anim_grid.add_child(cb)

	# Action selection
	var action_row := HBoxContainer.new()
	var action_lbl := Label.new()
	action_lbl.text = "Preview Action"
	action_row.add_child(action_lbl)
	var action_btn := OptionButton.new()
	action_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var all_actions = [
		"walk", "run", "slash", "thrust", "spellcast", "shoot", "hurt",
		"climb", "jump", "sit", "emote", "combat_idle", "backslash", "halfslash"
	]
	for act in all_actions:
		action_btn.add_item(act.capitalize())
		action_btn.set_item_metadata(action_btn.item_count - 1, act)
	action_btn.item_selected.connect(func(idx: int) -> void:
		if _preview_node != null:
			_preview_node.set_action(action_btn.get_item_metadata(idx))
	)
	action_row.add_child(action_btn)
	vbox.add_child(action_row)

	# Preview viewport (embedded)
	_add_section_label(vbox, "Preview")
	_preview_container = SubViewportContainer.new()
	_preview_container.custom_minimum_size = Vector2(PANEL_WIDTH - 20, 140)
	_preview_container.stretch = true
	vbox.add_child(_preview_container)

	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(PANEL_WIDTH - 20, 140)
	_preview_viewport.transparent_bg = true
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_container.add_child(_preview_viewport)

	_preview_node = CharacterPreview.new()
	_preview_node.position = Vector2((PANEL_WIDTH - 20) / 2.0, 100.0)
	_preview_node.recipe_applied.connect(_on_recipe_applied)
	_preview_viewport.add_child(_preview_node)

	# Generate button
	_generate_btn = Button.new()
	_generate_btn.text = "🎲  Generate"
	_generate_btn.pressed.connect(_on_generate_pressed)
	vbox.add_child(_generate_btn)

	# Report label
	_report_label = Label.new()
	_report_label.text = "—"
	_report_label.add_theme_font_size_override("font_size", 14)
	_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_report_label)

	# Current Character Parts — rebuilt after each Generate
	var parts_header_row := HBoxContainer.new()
	parts_header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var parts_hdr := Label.new()
	parts_hdr.text = "Current Parts"
	parts_hdr.add_theme_font_size_override("font_size", 16)
	parts_hdr.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	parts_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts_header_row.add_child(parts_hdr)
	vbox.add_child(parts_header_row)

	_parts_section_vbox = VBoxContainer.new()
	_parts_section_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_parts_section_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_parts_section_vbox)

	var parts_placeholder := Label.new()
	parts_placeholder.text = "Press Generate to see parts"
	parts_placeholder.add_theme_font_size_override("font_size", 14)
	parts_placeholder.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
	_parts_section_vbox.add_child(parts_placeholder)

	# Body-type weights
	var body_hdr_row := HBoxContainer.new()
	var body_lbl := Label.new()
	body_lbl.text = "Body Type Weights"
	body_lbl.add_theme_font_size_override("font_size", 16)
	body_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hdr_row.add_child(body_lbl)
	vbox.add_child(body_hdr_row)

	var type_toggles := HBoxContainer.new()
	type_toggles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var human_toggle := CheckButton.new()
	human_toggle.text = "Human"
	human_toggle.button_pressed = _profile.body_type_weights.get("male", 1.0) > 0.0 or _profile.body_type_weights.get("female", 1.0) > 0.0
	type_toggles.add_child(human_toggle)
	
	var non_human_toggle := CheckButton.new()
	non_human_toggle.text = "Non-Human"
	non_human_toggle.button_pressed = _profile.allow_non_human_parts
	type_toggles.add_child(non_human_toggle)
	
	vbox.add_child(type_toggles)
	
	human_toggle.toggled.connect(func(on: bool) -> void:
		for bt in ["male", "female", "teen", "child", "muscular", "pregnant"]:
			var val := 1.0 if on else 0.0
			_profile.body_type_weights[bt] = val
			if _body_sliders.has(bt):
				_body_sliders[bt].set_value_no_signal(val)
				_body_sliders[bt].value_changed.emit(val)
		_save_config()
	)
	
	non_human_toggle.toggled.connect(func(on: bool) -> void:
		_profile.allow_non_human_parts = on
		for bt in ["skeleton", "zombie"]:
			var val := 1.0 if on else 0.0
			_profile.body_type_weights[bt] = val
			if _body_sliders.has(bt):
				_body_sliders[bt].set_value_no_signal(val)
				_body_sliders[bt].value_changed.emit(val)
		_save_config()
	)
	var all_types := ["human", "non-human", "male", "female", "teen", "child", "muscular", "pregnant", "skeleton", "zombie"]
	for bt: String in all_types:
		var bw: float = _profile.body_type_weights.get(bt, 1.0)
		var sl := _add_labeled_slider(vbox, "Weight: " + bt, 0.0, 1.0, bw,
			func(v: float, b_t: String = bt) -> void:
				_profile.body_type_weights[b_t] = v; _save_config()
		)
		_body_sliders[bt] = sl

	# Slot weights
	_add_section_label(vbox, "Slot Weights")
	for slot: String in DISPLAY_SLOTS:
		var w: float = _profile.slot_weights.get(slot, _catalog.default_fill_chance(slot))
		var sl := _add_labeled_slider(vbox, slot, 0.0, 1.0, w,
			func(v: float, s: String = slot) -> void:
				_profile.set_slot_weight(s, v); _save_config()
		)
		_slot_sliders[slot] = sl

	# Item weights — collapsible
	_item_section_toggle = Button.new()
	_item_section_toggle.text = "▶  Item Weights"
	_item_section_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_item_section_toggle.flat = true
	_item_section_toggle.pressed.connect(_toggle_item_section)
	vbox.add_child(_item_section_toggle)

	_item_section_vbox = VBoxContainer.new()
	_item_section_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_section_vbox.add_theme_constant_override("separation", 4)
	_item_section_vbox.visible = false
	vbox.add_child(_item_section_vbox)
	_rebuild_item_sliders()


func _rebuild_item_sliders() -> void:
	for c in _item_section_vbox.get_children():
		c.queue_free()
	_item_sliders.clear()
	if _catalog == null:
		return
	for slot: String in _catalog.slot_names():
		for raw: Variant in _catalog.items_for_slot(slot):
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = raw
			var id: String = str(item.get("id", ""))
			if id.is_empty() or _item_sliders.has(id):
				continue
			var w: float = _profile.item_weights.get(id, 1.0)
			var sl := _add_labeled_slider(_item_section_vbox, id, 0.0, 1.0, w,
				func(v: float, iid: String = id) -> void:
					_profile.set_item_weight(iid, v); _save_config()
			)
			_item_sliders[id] = sl


func _toggle_item_section() -> void:
	_item_section_visible = not _item_section_visible
	_item_section_vbox.visible = _item_section_visible
	_item_section_toggle.text = ("▼  Item Weights" if _item_section_visible else "▶  Item Weights")


# ---- actions ----

func _on_generate_pressed() -> void:
	if _catalog == null or _preview_node == null:
		return
	_profile.seed = randi() % 100000
	_save_config()
	_preview_node.roll_and_apply(_catalog, _profile)


func _on_recipe_applied(report: Dictionary) -> void:
	var drawn: int = int(report.get("drawn", 0))
	var skipped: int = int(report.get("skipped", 0))
	var body: String = str(report.get("body_type", "?"))
	var seed_v: int = int(report.get("seed", -1))
	_report_label.text = "body=%s  seed=%d  drawn=%d  skip=%d" % [body, seed_v, drawn, skipped]
	_rebuild_parts_section(report)
	generated.emit(report, _preview_node.last_recipe)


## Rebuild the "Current Parts" sliders based on the last rolled recipe report.
func _rebuild_parts_section(report: Dictionary) -> void:
	# Synchronous removal: queue_free defers and leaves stale nodes visible this frame.
	for c: Node in _parts_section_vbox.get_children():
		_parts_section_vbox.remove_child(c)
		c.free()

	var body: String = str(report.get("body_type", ""))

	# Body-type row
	if not body.is_empty():
		_add_part_slot_header(_parts_section_vbox, "body_type", body)
		var bw: float = _profile.body_type_weights.get(body, 1.0)
		_add_labeled_slider(_parts_section_vbox, body, 0.0, 1.0, bw,
			func(v: float, bt: String = body) -> void:
				_profile.body_type_weights[bt] = v
				if _body_sliders.has(bt):
					_body_sliders[bt].set_value_no_signal(v)
				_save_config()
		)

	# One row per drawn part (skip duplicated fg/bg planes — use first occurrence per slot)
	var seen_slots: Dictionary = {}
	var parts: Variant = report.get("parts", [])
	if typeof(parts) != TYPE_ARRAY:
		return
	for raw: Variant in parts:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = raw
		var status: String = str(p.get("status", ""))
		if status != "drawn":
			continue
		var slot: String = str(p.get("slot", ""))
		var item_id: String = str(p.get("id", ""))
		if item_id.is_empty() or seen_slots.has(slot):
			continue
		seen_slots[slot] = true

		# Slot header with recolor tag if applicable
		var recolor_kind: String = str(p.get("recolor_kind", "none"))
		var recolor: String = str(p.get("recolor", ""))
		var tag: String = ""
		if recolor_kind != "none" and not recolor.is_empty():
			tag += " [color=#75c9ff][%s:%s][/color]" % [recolor_kind, recolor]
		elif str(p.get("variant", "")) != "":
			tag += " [color=#ffd375][var:%s][/color]" % p.get("variant", "")
			
		var missing_anims: Array = p.get("missing_anims", [])
		if not missing_anims.is_empty():
			var m_strs = PackedStringArray()
			for m in missing_anims: m_strs.append(str(m))
			if m_strs.size() > 3:
				tag += " [color=#ff7575](missing: " + ", ".join(m_strs.slice(0, 3)) + ", ...)[/color]"
			else:
				tag += " [color=#ff7575](missing: " + ", ".join(m_strs) + ")[/color]"
				
		_add_part_slot_header(_parts_section_vbox, slot, item_id + tag)

		# For the 'body' item, there is only one shape. Users toggling it expect to toggle the skin color.
		var weight_key: String = item_id
		if item_id == "body" and recolor_kind == "skin" and not recolor.is_empty():
			weight_key = "skin:" + recolor
			
		var iw: float = _profile.item_weights.get(weight_key, 1.0)
		_add_part_toggle_row(_parts_section_vbox, item_id, weight_key, iw)


## Row with enable/disable CheckButton and a weight slider for one part item.
func _add_part_toggle_row(parent: VBoxContainer, item_id: String, weight_key: String, current_weight: float) -> HSlider:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# CheckButton — ON = included, OFF = weight zeroed
	var toggle := CheckButton.new()
	toggle.button_pressed = current_weight > 0.0
	toggle.text = ""
	toggle.custom_minimum_size = Vector2(38, 0)
	toggle.flat = true
	row.add_child(toggle)

	var label := Label.new()
	label.text = item_id
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = 1.0
	label.clip_text = true
	row.add_child(label)

	# Gender tag dropdown
	var tag_opt := OptionButton.new()
	tag_opt.add_item("Neutral", 0)
	tag_opt.add_item("Male", 1)
	tag_opt.add_item("Female", 2)
	var current_tag: String = str(_profile.item_gender_tags.get(item_id, "neutral"))
	if current_tag == "male":
		tag_opt.selected = 1
	elif current_tag == "female":
		tag_opt.selected = 2
	else:
		tag_opt.selected = 0
	row.add_child(tag_opt)

	# Weight HSlider
	var sl := HSlider.new()
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = current_weight
	row.add_child(sl)

	# Numeric readout
	var readout := Label.new()
	readout.text = "%.2f" % current_weight
	readout.custom_minimum_size.x = 40
	readout.add_theme_font_size_override("font_size", 14)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	parent.add_child(row)

	# ---- wire tag opt ----
	tag_opt.item_selected.connect(func(idx: int, iid: String = item_id) -> void:
		var tag: String = "neutral"
		if idx == 1:
			tag = "male"
		elif idx == 2:
			tag = "female"
		_profile.set_item_gender_tag(iid, tag)
		_save_config()
	)

	# ---- wire slider ----
	sl.value_changed.connect(func(v: float, wk: String = weight_key) -> void:
		readout.text = "%.2f" % v
		_profile.set_item_weight(wk, v)
		toggle.set_pressed_no_signal(v > 0.0)
		if _item_sliders.has(wk):
			_item_sliders[wk].set_value_no_signal(v)
		_save_config()
	)

	# ---- wire toggle ----
	toggle.toggled.connect(func(on: bool, wk: String = weight_key, iid: String = item_id) -> void:
		print("TOGGLED: ", iid, " -> ", on)
		if on:
			# Restore saved weight (or 1.0 default)
			var restore: float = _part_saved_weights.get(wk, 1.0)
			_part_saved_weights.erase(wk)
			sl.set_value_no_signal(restore)
			readout.text = "%.2f" % restore
			_profile.set_item_weight(wk, restore)
			if _item_sliders.has(wk):
				_item_sliders[wk].set_value_no_signal(restore)
			set_part_visible(iid, true)
		else:
			# Save current then zero
			_part_saved_weights[wk] = _profile.item_weights.get(wk, 1.0)
			sl.set_value_no_signal(0.0)
			readout.text = "0.00"
			_profile.set_item_weight(wk, 0.0)
			if _item_sliders.has(wk):
				_item_sliders[wk].set_value_no_signal(0.0)
			set_part_visible(iid, false)
		_save_config()
	)

	return sl

## Adds a compact two-column header: slot name (dim) + item id (bright).
func _add_part_slot_header(parent: VBoxContainer, slot: String, item_label: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slot_lbl := Label.new()
	slot_lbl.text = slot + ":"
	slot_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_lbl.size_flags_stretch_ratio = 0.5
	slot_lbl.add_theme_font_size_override("font_size", 14)
	slot_lbl.add_theme_color_override("font_color", Color(0.55, 0.60, 0.72))
	slot_lbl.clip_text = true
	row.add_child(slot_lbl)
	var id_lbl := RichTextLabel.new()
	id_lbl.text = item_label
	id_lbl.bbcode_enabled = true
	id_lbl.add_theme_font_size_override("normal_font_size", 14)
	id_lbl.add_theme_color_override("default_color", Color(0.9, 0.95, 1.0))
	id_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_lbl.size_flags_stretch_ratio = 1.5
	id_lbl.fit_content = true
	id_lbl.scroll_active = false
	id_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	id_lbl.clip_contents = true
	row.add_child(id_lbl)
	parent.add_child(row)


# ---- widget helpers ----

func _add_section_label(parent: VBoxContainer, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	parent.add_child(lbl)
	return lbl


func _add_labeled_slider(
	parent: VBoxContainer,
	label: String,
	min_v: float,
	max_v: float,
	value: float,
	on_change: Callable,
) -> HSlider:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_stretch_ratio = 1.5
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.clip_text = true
	row.add_child(lbl)
	var sl := HSlider.new()
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_stretch_ratio = 1.0
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = 0.01
	sl.value = value
	sl.value_changed.connect(on_change)
	row.add_child(sl)
	var readout := Label.new()
	readout.text = "%.2f" % value
	readout.custom_minimum_size.x = 60
	readout.add_theme_font_size_override("font_size", 15)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sl.value_changed.connect(func(v: float) -> void: readout.text = "%.2f" % v)
	row.add_child(readout)
	parent.add_child(row)
	return sl


func _add_labeled_spinbox(
	parent: VBoxContainer,
	label: String,
	min_v: float,
	max_v: float,
	value: float,
	on_change: Callable,
) -> SpinBox:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_stretch_ratio = 1.5
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.clip_text = true
	row.add_child(lbl)
	var sp := SpinBox.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.size_flags_stretch_ratio = 1.0
	sp.min_value = min_v
	sp.max_value = max_v
	sp.step = 1
	sp.value = value
	sp.value_changed.connect(on_change)
	row.add_child(sp)
	parent.add_child(row)
	return sp


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.10, 0.92)
	s.border_color = Color(0.3, 0.3, 0.35, 1.0)
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	return s
