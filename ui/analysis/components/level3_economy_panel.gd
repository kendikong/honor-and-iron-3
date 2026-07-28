class_name Level3EconomyPanel
extends VBoxContainer

signal inspect_requested(title: String, body: String, meta: Dictionary)

var _body: RichTextLabel


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "Level 3: Economy & Combat Math"
	MassSimTheme.style_section(title)
	add_child(title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_body)


func bind_report(report: MassSimBatchReport) -> void:
	if report == null or report.is_empty():
		_body.text = "[i]Run a batch to populate economy telemetry.[/i]"
		return
	var whiff_pct: float = float(report.battles_with_whiffs) / float(maxi(report.total_battles, 1)) * 100.0
	_body.text = (
		"[b]Assisted Value (Support Tracker)[/b]\n"
		+ "• Damage Enabled: [color=#7dcea0]%d[/color]\n"
		+ "• Shield Prevented: %d\n"
		+ "• Movement/AP Float tracked: %d floated turns\n\n"
		+ "[b]Waste Analytics[/b]\n"
		+ "• Execution Whiffs (battles): %.1f%% (%d total events)\n"
		+ "• Overkill Damage: %d\n"
		+ "• Target whiff rate: < %.0f%%"
	) % [
		report.total_assisted_damage,
		report.total_assisted_shields,
		report.total_floated_ap,
		whiff_pct,
		report.total_execution_whiffs,
		report.total_overkill,
		MassSimConstants.TARGET_WHIFF_BATTLES_PCT,
	]
