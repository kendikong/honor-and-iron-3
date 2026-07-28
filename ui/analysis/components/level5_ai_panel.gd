class_name Level5AIPanel
extends VBoxContainer

signal inspect_requested(title: String, body: String, meta: Dictionary)

var _body: RichTextLabel


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "Level 5: AI Diagnostics"
	MassSimTheme.style_section(title)
	add_child(title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_body)


func bind_report(report: MassSimBatchReport) -> void:
	if report == null or report.is_empty():
		_body.text = "[i]Run a batch to capture Commander AI telemetry.[/i]"
		return

	var win_collision: int = 0
	var loss_collision: int = 0
	for row: Dictionary in report.raw_rows:
		var chaos: int = int(row.get("wall_collisions", 0)) + int(row.get("chain_collisions", 0))
		if int(row.get("winner", -1)) == GameEnums.Team.PLAYER:
			win_collision += chaos
		elif int(row.get("winner", -1)) == GameEnums.Team.ENEMY:
			loss_collision += chaos
	var delta_pct: float = 0.0
	if loss_collision > 0:
		delta_pct = (float(win_collision) / float(loss_collision) - 1.0) * 100.0

	var sample_text: String = "No AI JSON samples in this batch."
	if not report.ai_samples.is_empty():
		var sample: Dictionary = report.ai_samples[0]
		var tel: Dictionary = sample.get("telemetry", sample)
		var total_util: float = float(tel.get("total", tel.get("final_utility", 0.0)))
		sample_text = (
			"Latest sample (run %s, turn %s):\n"
			+ "Final_Utility: [b]%.1f[/b] — keys: %s"
		) % [str(sample.get("run_id", "?")), str(sample.get("turn", "?")), total_util, str(tel.keys())]

	_body.text = (
		"[b]Match Victory Delta[/b]\n"
		+ "• Winners generated [color=#7dcea0]%+.0f%%[/color] more collision pressure (heuristic)\n\n"
		+ "[b]Live Utility Inspector Snapshot[/b]\n%s\n\n"
		+ "[b]Curated Replays[/b]\n"
		+ "Best #%s · Worst #%s · Median #%s · Upset #%s · Chaotic #%s"
	) % [
		delta_pct,
		sample_text,
		str(report.curator.get("best_performance_id", "—")),
		str(report.curator.get("worst_performance_id", "—")),
		str(report.curator.get("median_match_id", "—")),
		str(report.curator.get("biggest_upset_id", "—")),
		str(report.curator.get("most_chaotic_id", "—")),
	]
