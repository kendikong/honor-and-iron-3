class_name CommandPaletteModal
extends PopupPanel

var search_input: LineEdit
var results_list: ItemList

func _init() -> void:
	size = Vector2(600, 400)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	
	search_input = LineEdit.new()
	search_input.placeholder_text = "Search Classes, Metrics, Replays (Ctrl+K)..."
	vbox.add_child(search_input)
	
	results_list = ItemList.new()
	results_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(results_list)

func popup_palette() -> void:
	popup_centered()
	search_input.grab_focus()
