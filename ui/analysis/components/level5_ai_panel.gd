class_name Level5AIPanel
extends VBoxContainer

func _init() -> void:
	var title = Label.new()
	title.text = "Level 5: AI Diagnostics & JSON Utility"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	
	var r = RichTextLabel.new()
	r.bbcode_enabled = true
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var text = "[b]Match Victory Delta[/b]\n"
	text += "- Winner generated [color=green]+312%[/color] more Collision Damage\n"
	text += "- Winner generated [color=green]+40%[/color] AP\n\n"
	text += "[b]Live Utility Inspector Snapshot[/b]\n"
	text += "Final_Utility: 45.2 = [b]Threat_Multiplier (35.0)[/b] + Base_Dmg (10.2)\n\n"
	text += "[b]Counterfactual Analysis[/b]\n"
	text += "Rejected Vector #2: Bowling Charge (Reason: Target displaced prior to execution)"
	r.text = text
	add_child(r)
