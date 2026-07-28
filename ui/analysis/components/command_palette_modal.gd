class_name CommandPaletteModal
extends PopupPanel

signal item_selected(title: String, body: String, meta: Dictionary)

var search_input: LineEdit
var results_list: ItemList
var _entries: Array[Dictionary] = []


func _init() -> void:
	size = Vector2(640, 420)
	MassSimTheme.apply_panel(self)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8
	add_child(vbox)
	search_input = LineEdit.new()
	search_input.placeholder_text = "Search classes, replay IDs, tabs, metrics (Ctrl+K)..."
	search_input.text_changed.connect(_on_search_changed)
	vbox.add_child(search_input)
	results_list = ItemList.new()
	results_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_list.item_activated.connect(_on_item_activated)
	vbox.add_child(results_list)


func set_entries(entries: Array) -> void:
	_entries.clear()
	for e: Variant in entries:
		if e is Dictionary:
			_entries.append(e as Dictionary)
	_filter("")


func popup_palette() -> void:
	popup_centered()
	search_input.text = ""
	_filter("")
	search_input.grab_focus()


func _on_search_changed(text: String) -> void:
	_filter(text)


func _filter(query: String) -> void:
	results_list.clear()
	var q: String = query.strip_edges().to_lower()
	var idx: int = 0
	for entry: Dictionary in _entries:
		var label: String = String(entry.get("label", ""))
		if q.is_empty() or label.to_lower().find(q) >= 0:
			results_list.add_item(label)
			results_list.set_item_metadata(idx, entry)
			idx += 1


func _on_item_activated(index: int) -> void:
	var entry: Variant = results_list.get_item_metadata(index)
	if entry is Dictionary:
		var d: Dictionary = entry as Dictionary
		item_selected.emit(
			String(d.get("title", d.get("label", ""))),
			String(d.get("body", "")),
			d.get("meta", {}) as Dictionary,
		)
		hide()
