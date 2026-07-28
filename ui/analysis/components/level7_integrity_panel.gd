class_name Level7IntegrityPanel
extends VBoxContainer

signal inspect_requested(title: String, body: String, meta: Dictionary)

var _body: RichTextLabel


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "Level 7: Simulation Integrity"
	MassSimTheme.style_section(title)
	add_child(title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_body)


func bind_report(report: MassSimBatchReport) -> void:
	if report == null or report.is_empty():
		_body.text = "[i]%s[/i]" % (
			"Not enough data. Requires %d matches. (Current: 0)"
			% MassSimConstants.MIN_SAMPLE_FULL_CONFIDENCE
		)
		return

	var margin: float = 100.0 / sqrt(float(maxi(report.total_battles, 1)))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]Sample Size & Distribution[/b]")
	lines.append("• Battles analyzed: %d / %d confidence gate" % [
		report.total_battles, MassSimConstants.MIN_SAMPLE_FULL_CONFIDENCE,
	])
	lines.append("• Unique classes observed: %d" % report.unique_classes_seen)
	lines.append("• Integrity score: [b]%.0f / 100[/b]" % report.integrity_score)
	for note: String in report.integrity_notes:
		lines.append("  – %s" % note)
	lines.append("")
	lines.append("[b]Matchup Confidence Intervals (approx.)[/b]")
	for row: Dictionary in report.tier_rows.slice(0, 5):
		lines.append(
			"• %s: %.1f%% ± %.1f%% (n=%d)"
			% [
				report.class_display_name(row["class_id"]),
				float(row["win_rate"]),
				margin,
				int(row["appearances"]),
			]
		)
	if report.tier_rows.is_empty():
		lines.append(report.sample_gate_label("confidence intervals"))
	_body.text = "\n".join(lines)
