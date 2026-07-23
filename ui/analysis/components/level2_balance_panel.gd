class_name Level2BalancePanel
extends VBoxContainer

func _init() -> void:
	var title = Label.new()
	title.text = "Level 2: Balance & Synergy"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hbox)
	
	# Tier List column
	var tier_list_vbox = VBoxContainer.new()
	tier_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(tier_list_vbox)
	
	var tier_lbl = Label.new()
	tier_lbl.text = "Algorithmic S-F Tier List"
	tier_list_vbox.add_child(tier_lbl)
	
	var tier_tree = Tree.new()
	tier_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tier_list_vbox.add_child(tier_tree)
	
	_populate_mock_tiers(tier_tree)
	
	# Distribution Box Plots
	var boxplot_vbox = VBoxContainer.new()
	boxplot_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(boxplot_vbox)
	
	var box_lbl = Label.new()
	box_lbl.text = "Distribution (Medians & Outliers)"
	boxplot_vbox.add_child(box_lbl)
	
	var box_rt = RichTextLabel.new()
	box_rt.bbcode_enabled = true
	box_rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box_rt.text = "[b]Damage Output (95th Percentile)[/b]\nKnight: 450 (Median: 200)\nMage: 800 (Median: 300)"
	boxplot_vbox.add_child(box_rt)

func _populate_mock_tiers(tree: Tree) -> void:
	var root = tree.create_item()
	var s_tier = tree.create_item(root)
	s_tier.set_text(0, "S-Tier: Knight [Map Dependent]")
	var a_tier = tree.create_item(root)
	a_tier.set_text(0, "A-Tier: Mage")
	var b_tier = tree.create_item(root)
	b_tier.set_text(0, "B-Tier: Cleric [Synergy Reliant]")
