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

	var avg_class_wr: float = _average_class_win_rate(report)
	var wr_target: float = MassSimConstants.TARGET_PLAYER_WIN_PCT
	kpi_cards.add_child(_make_clickable_kpi_rich(
		"Win Rates",
		"%s\n%s" % [
			_tone_line("Player", "%.1f%%" % report.player_win_pct, report.player_win_pct, wr_target, 8.0),
			_tone_line("Enemy", "%.1f%%" % report.enemy_win_pct, report.enemy_win_pct, wr_target, 8.0, true),
		],
		"Win Rate Breakdown",
		"Player %d / Enemy %d / Draw %d / Timeout %d"
		% [report.player_wins, report.enemy_wins, report.draws, report.timeouts],
	))
	kpi_cards.add_child(_make_clickable_kpi_rich(
		"Match Length",
		"%s\n%s" % [
			_tone_line("Avg", "%.1f" % report.avg_turns, report.avg_turns, MassSimConstants.TARGET_AVG_TURNS, 3.0),
			_tone_line("Median", str(report.median_turns), float(report.median_turns), report.avg_turns, 2.0),
		],
		"Turn Distribution",
		"Target avg ~%.0f turns. Shortest %d, longest %d."
		% [
			MassSimConstants.TARGET_AVG_TURNS,
			report.turn_values.front() if not report.turn_values.is_empty() else 0,
			report.turn_values.back() if not report.turn_values.is_empty() else 0,
		],
	))

	var mvp_name: String = "â€”"
	var mvp_wr: float = 0.0
	if not report.tier_rows.is_empty():
		mvp_name = report.class_display_name(report.tier_rows[0]["class_id"])
		mvp_wr = float(report.tier_rows[0]["win_rate"])
	kpi_cards.add_child(_make_clickable_kpi_rich(
		"Combat MVP",
		"%s\n%s" % [
			mvp_name,
			_tone_line("WR", "%.1f%%" % mvp_wr, mvp_wr, avg_class_wr, 10.0),
		],
		"Top Performer",
		"%s leads the batch with %.1f%% win rate when fielded (class avg %.1f%%)."
		% [mvp_name, mvp_wr, avg_class_wr],
	))

	var class_count_avg: float = float(report.total_player_classes) * 0.5
	kpi_cards.add_child(_make_clickable_kpi_rich(
		"Meta Diversity",
		"%s\n%s" % [
			_tone_line("Coverage", "%.0f%%" % report.meta_diversity_pct, report.meta_diversity_pct, 70.0, 15.0),
			_tone_line("Classes", str(report.unique_classes_seen), float(report.unique_classes_seen), class_count_avg, 4.0),
		],
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

	var integrity_avg: float = 80.0
	if report.previous_integrity >= 0.0:
		integrity_avg = report.previous_integrity
	var whiff_pct: float = float(report.battles_with_whiffs) / float(maxi(report.total_battles, 1)) * 100.0
	kpi_cards.add_child(_make_clickable_kpi_rich(
		"Integrity",
		"%s\n%s" % [
			_tone_line("Score", "%.0f / 100" % report.integrity_score, report.integrity_score, integrity_avg, 15.0),
			_tone_line("Whiff battles", "%.1f%%" % whiff_pct, whiff_pct, MassSimConstants.TARGET_WHIFF_BATTLES_PCT, 5.0, true),
		],
		"Simulation Integrity",
		"\n".join(report.integrity_notes),
	))

	_triage.populate(warnings, workspace)


static func _average_class_win_rate(report: MassSimBatchReport) -> float:
	if report.tier_rows.is_empty():
		return MassSimConstants.TARGET_PLAYER_WIN_PCT
	var total: float = 0.0
	for row: Dictionary in report.tier_rows:
		total += float(row.get("win_rate", 0.0))
	return total / float(report.tier_rows.size())


static func _tone_line(
	label: String,
	value_text: String,
	value: float,
	average: float,
	tolerance: float,
	invert: bool = false,
) -> String:
	var color: Color = (
		MassSimTheme.directional_color_inverted(value, average, tolerance)
		if invert
		else MassSimTheme.directional_color(value, average, tolerance)
	)
	return "%s: [color=#%s]%s[/color]" % [label, MassSimTheme.color_hex(color), value_text]


func _format_timeline_sparkline(report: MassSimBatchReport) -> String:
	if report.timeline_entries.is_empty():
		return "[i]Timeline: run another batch to build trend history.[/i]"
	var parts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in report.timeline_entries.slice(-6):
		parts.append("%.0f%%" % float(entry.get("player_win_pct", 0)))
	return "[b]WR trend:[/b] " + " â†’ ".join(parts)


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
		lines.append("%2d | %s (%d)" % [turns, "â–ˆ".repeat(bars), count])
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


func _make_clickable_kpi_rich(
	title: String,
	body_bbcode: String,
	inspect_title: String,
	inspect_body: String,
) -> PanelContainer:
	var card: PanelContainer = MassSimTheme.make_kpi_card_rich(title, body_bbcode)
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func() -> void:
		inspect_requested.emit(inspect_title, inspect_body, {})
	)
	card.add_child(btn)
	return card
