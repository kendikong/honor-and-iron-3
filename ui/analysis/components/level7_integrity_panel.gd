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

	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]Sample Size & Distribution[/b]")
	lines.append("â€¢ Battles analyzed: %d / %d confidence gate" % [
		report.total_battles, MassSimConstants.MIN_SAMPLE_FULL_CONFIDENCE,
	])
	lines.append("â€¢ Unique classes observed: %d / %d roster" % [
		report.unique_classes_seen, report.total_player_classes,
	])
	if not report.missing_classes.is_empty():
		lines.append("â€¢ Missing from batch: %s" % ", ".join(report.missing_classes))
	lines.append("â€¢ Meta diversity: %.0f%%" % report.meta_diversity_pct)
	lines.append("â€¢ Integrity score: [b]%.0f / 100[/b]" % report.integrity_score)
	for note: String in report.integrity_notes:
		lines.append("  â€“ %s" % note)
	lines.append("")
	lines.append("[b]Matchup Confidence Intervals (Wilson 95%%)[/b]")
	for row: Dictionary in report.tier_rows.slice(0, 8):
		var appearances: int = int(row.get("appearances", 0))
		var wins: int = int(round(float(row.get("win_rate", 0.0)) / 100.0 * float(appearances)))
		var wilson: float = report.wilson_margin(wins, appearances)
		lines.append(
			"â€¢ %s: %.1f%% Â± %.1f%% (n=%d, tier %s)"
			% [
				report.class_display_name(row["class_id"]),
				float(row["win_rate"]),
				wilson,
				appearances,
				String(row.get("tier", "?")),
			]
		)
	if report.tier_rows.is_empty():
		lines.append(report.sample_gate_label("confidence intervals"))
	_body.text = "\n".join(lines)
