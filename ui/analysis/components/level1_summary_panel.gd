class_name Level1SummaryPanel
extends VBoxContainer

signal inspect_requested(title: String, body: String, meta: Dictionary)

var health_summary: RichTextLabel
var kpi_cards: HBoxContainer
var version_row: RichTextLabel
var _triage: TriageInboxPanel
var _empty_banner: RichTextLabel


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_empty_banner = RichTextLabel.new()
	_empty_banner.bbcode_enabled = true
	_empty_banner.fit_content = true
	_empty_banner.text = (
		"[center][color=#8fa3b8]No batch loaded.[/color]\n"
		+ "Queue a job or click [b]Reload Results[/b] to analyze saved JSONL.\n"
		+ "Full confidence requires %d matches.[/center]"
		% MassSimConstants.MIN_SAMPLE_FULL_CONFIDENCE
	)
	add_child(_empty_banner)

	health_summary = RichTextLabel.new()
	health_summary.bbcode_enabled = true
	health_summary.custom_minimum_size = Vector2(0, 72)
	health_summary.visible = false
	add_child(health_summary)

	version_row = RichTextLabel.new()
	version_row.bbcode_enabled = true
	version_row.custom_minimum_size = Vector2(0, 40)
	version_row.visible = false
	add_child(version_row)

	kpi_cards = HBoxContainer.new()
	kpi_cards.add_theme_constant_override("separation", 12)
	kpi_cards.visible = false
	add_child(kpi_cards)

	add_child(HSeparator.new())

	_triage = TriageInboxPanel.new()
	_triage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_triage.inspect_requested.connect(func(t: String, b: String, m: Dictionary) -> void:
		inspect_requested.emit(t, b, m)
	)
	add_child(_triage)


func bind_report(report: MassSimBatchReport, warnings: Array, workspace: MassSimWorkspace = null) -> void:
	var has_data: bool = report != null and not report.is_empty()
	_empty_banner.visible = not has_data
	health_summary.visible = has_data
	version_row.visible = has_data
	kpi_cards.visible = has_data
	if not has_data:
		_triage.populate([])
		return

	health_summary.text = "[b]Algorithmic Health Summary[/b]\n" + TriageEngine.generate_health_summary(report, warnings)
	version_row.text = (
		"[b]Version Comparison[/b]  |  Player WR: %s  |  Avg Turns: %s  |  Integrity: %s\n%s"
		% [
			report.format_pct_delta(report.player_win_pct, report.previous_player_win_pct),
			report.format_pct_delta(report.avg_turns, report.previous_avg_turns, ""),
			report.format_pct_delta(report.integrity_score, report.previous_integrity, " pts"),
			_format_timeline_sparkline(report),
		]
	)

	for child: Node in kpi_cards.get_children():
		child.queue_free()

	var wr_dev: Color = MassSimTheme.dev_color(
		report.player_win_pct, MassSimConstants.TARGET_PLAYER_WIN_PCT, 4.0,
	)
	kpi_cards.add_child(_make_clickable_kpi(
		"Win Rates",
		"Player: %.1f%%\nEnemy: %.1f%%" % [report.player_win_pct, report.enemy_win_pct],
		wr_dev,
		"Win Rate Breakdown",
		"Player %d / Enemy %d / Draw %d / Timeout %d"
		% [report.player_wins, report.enemy_wins, report.draws, report.timeouts],
	))
	kpi_cards.add_child(_make_clickable_kpi(
		"Match Length",
		"Avg: %.1f\nMedian: %d" % [report.avg_turns, report.median_turns],
		MassSimTheme.dev_color(report.avg_turns, MassSimConstants.TARGET_AVG_TURNS, 3.0),
		"Turn Distribution",
		"Target avg ~%.0f turns. Shortest %d, longest %d."
		% [
			MassSimConstants.TARGET_AVG_TURNS,
			report.turn_values.front() if not report.turn_values.is_empty() else 0,
			report.turn_values.back() if not report.turn_values.is_empty() else 0,
		],
	))

	var mvp_name: String = "—"
	var mvp_wr: float = 0.0
	if not report.tier_rows.is_empty():
		mvp_name = report.class_display_name(report.tier_rows[0]["class_id"])
		mvp_wr = float(report.tier_rows[0]["win_rate"])
	kpi_cards.add_child(_make_clickable_kpi(
		"Combat MVP",
		"%s\n%.1f%% WR" % [mvp_name, mvp_wr],
		MenuTheme.ACCENT,
		"Top Performer",
		"%s leads the batch with %.1f%% win rate when fielded." % [mvp_name, mvp_wr],
	))

	kpi_cards.add_child(_make_clickable_kpi(
		"Meta Diversity",
		"%.0f%%\n%d classes" % [report.meta_diversity_pct, report.unique_classes_seen],
		MassSimTheme.dev_color(report.meta_diversity_pct, 70.0, 15.0),
		"Roster Diversity",
		"Coverage of player class library. Missing: %s"
		% (", ".join(report.missing_classes) if not report.missing_classes.is_empty() else "none"),
	))

	var hist: String = _turn_histogram_ascii(report)
	kpi_cards.add_child(_make_clickable_kpi(
		"Turn Histogram",
		"See sparkline",
		MenuTheme.TEXT_MUTED,
		"Turn Length Distribution",
		hist,
	))

	var whiff_pct: float = float(report.battles_with_whiffs) / float(maxi(report.total_battles, 1)) * 100.0
	kpi_cards.add_child(_make_clickable_kpi(
		"Integrity",
		"%.0f / 100" % report.integrity_score,
		MassSimTheme.dev_color(report.integrity_score, 80.0, 15.0),
		"Simulation Integrity",
		"\n".join(report.integrity_notes),
	))

	_triage.populate(warnings, workspace)


func _format_timeline_sparkline(report: MassSimBatchReport) -> String:
	if report.timeline_entries.is_empty():
		return "[i]Timeline: run another batch to build trend history.[/i]"
	var parts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in report.timeline_entries.slice(-6):
		parts.append("%.0f%%" % float(entry.get("player_win_pct", 0)))
	return "[b]WR trend:[/b] " + " → ".join(parts)


func _turn_histogram_ascii(report: MassSimBatchReport) -> String:
	if report.turn_histogram.is_empty():
		return report.sample_gate_label("turn histogram")
	var max_count: int = 1
	for k: Variant in report.turn_histogram.keys():
		max_count = maxi(max_count, int(report.turn_histogram[k]))
	var lines: PackedStringArray = PackedStringArray()
	for turns: int in range(4, 21):
		var key: String = str(turns)
		var count: int = int(report.turn_histogram.get(key, 0))
		if count <= 0:
			continue
		var bars: int = clampi(int(float(count) / float(max_count) * 12.0), 1, 12)
		lines.append("%2d | %s (%d)" % [turns, "█".repeat(bars), count])
	return "\n".join(lines) if not lines.is_empty() else "No turn data"


func _make_clickable_kpi(
	title: String,
	body: String,
	accent: Color,
	inspect_title: String,
	inspect_body: String,
) -> PanelContainer:
	var card: PanelContainer = MassSimTheme.make_kpi_card(title, body, accent)
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func() -> void:
		inspect_requested.emit(inspect_title, inspect_body, {})
	)
	card.add_child(btn)
	return card
