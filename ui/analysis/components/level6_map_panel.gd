class_name Level6MapPanel
extends VBoxContainer

func _init() -> void:
	var title = Label.new()
	title.text = "Level 6: Environment & Map Bias"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	
	var r = RichTextLabel.new()
	r.bbcode_enabled = true
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var text = "[b]Map Tag Filtering[/b]\n"
	text += "- [Open] Win Rate: 48%\n"
	text += "- [Narrow] Win Rate: 65%\n"
	text += "- [Hazard] Win Rate: 30%\n\n"
	text += "[b]Spawn Bias Validator[/b]\n"
	text += "- North Spawn: 52%\n"
	text += "- South Spawn: 48%\n"
	r.text = text
	add_child(r)
