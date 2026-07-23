class_name Level4PhysicsPanel
extends VBoxContainer

func _init() -> void:
	var title = Label.new()
	title.text = "Level 4: Physics & Spatial Control"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	
	var r = RichTextLabel.new()
	r.bbcode_enabled = true
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var text = "[b]Hazard Lifecycle Tracker[/b]\n"
	text += "- Created -> Triggered: Avg 2.1 turns\n"
	text += "- Created -> Expired: 15%\n\n"
	text += "[b]Collision Analytics[/b]\n"
	text += "- Chain Collisions: 34\n"
	text += "- Friendly Fire: 5\n"
	r.text = text
	add_child(r)
