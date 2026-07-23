class_name Level3EconomyPanel
extends VBoxContainer

func _init() -> void:
	var title = Label.new()
	title.text = "Level 3: Economy & Combat Math"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	
	var r = RichTextLabel.new()
	r.bbcode_enabled = true
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var text = "[b]Assisted Value (Support Tracker)[/b]\n"
	text += "- Damage Enabled: 1500\n"
	text += "- Shield Prevented: 300\n"
	text += "- Movement Enabled: 40 tiles\n\n"
	text += "[b]Waste Analytics[/b]\n"
	text += "- Execution Phase Whiffs: 12\n"
	text += "- Overkill Damage: 450\n"
	text += "- Floated AP (Unused): 35 turns\n"
	r.text = text
	add_child(r)
