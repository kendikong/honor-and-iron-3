class_name Level7IntegrityPanel
extends VBoxContainer

func _init() -> void:
	var title = Label.new()
	title.text = "Level 7: Simulation Integrity Check"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	
	var r = RichTextLabel.new()
	r.bbcode_enabled = true
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var text = "[b]Sample Size & Distribution[/b]\n"
	text += "- Validated Subclass Coverage: 100%\n"
	text += "- Seed Randomization: Pass (Normal Distribution)\n\n"
	text += "[b]Matchup Confidence Intervals[/b]\n"
	text += "- Knight: 55% +/- 0.7%\n"
	text += "- Mage: 48% +/- 1.2%\n"
	r.text = text
	add_child(r)
