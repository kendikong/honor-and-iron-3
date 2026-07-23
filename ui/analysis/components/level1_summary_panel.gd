class_name Level1SummaryPanel
extends VBoxContainer

var health_summary: RichTextLabel
var kpi_cards: HBoxContainer
var _triage: TriageInboxPanel

func _init() -> void:
	health_summary = RichTextLabel.new()
	health_summary.bbcode_enabled = true
	health_summary.custom_minimum_size = Vector2(0, 80)
	add_child(health_summary)
	
	kpi_cards = HBoxContainer.new()
	kpi_cards.add_theme_constant_override("separation", 20)
	add_child(kpi_cards)
	
	var sep = HSeparator.new()
	add_child(sep)
	
	_triage = TriageInboxPanel.new()
	_triage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_triage)

func update_summary(engine: TriageEngine, warnings: Array, stats: Dictionary) -> void:
	var msg = engine.generate_health_summary(warnings)
	health_summary.text = "[b]Algorithmic Health Summary:[/b]\n" + msg
	
	for child in kpi_cards.get_children():
		child.queue_free()
		
	# Win Rates Card
	var p_win = stats.get("player_win_rate", 0)
	var e_win = stats.get("enemy_win_rate", 0)
	var wcard = _create_kpi_card("Win Rates", "Player: %d%%\nEnemy: %d%%" % [p_win, e_win])
	kpi_cards.add_child(wcard)
	
	# Match Length Card
	var lcard = _create_kpi_card("Match Length", "Avg Turns: 12\nMedian: 10")
	kpi_cards.add_child(lcard)
	
	# MVP Card
	var mvp = _create_kpi_card("Combat MVP", "Knight (WR: 54%)")
	kpi_cards.add_child(mvp)
	
	_triage.populate(warnings)

func _create_kpi_card(title: String, body: String) -> PanelContainer:
	var p = PanelContainer.new()
	var v = VBoxContainer.new()
	p.add_child(v)
	
	var lbl1 = Label.new()
	lbl1.text = title
	lbl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl1.add_theme_font_size_override("font_size", 16)
	v.add_child(lbl1)
	
	var lbl2 = Label.new()
	lbl2.text = body
	v.add_child(lbl2)
	return p
