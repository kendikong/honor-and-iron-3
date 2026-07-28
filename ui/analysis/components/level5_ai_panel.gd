class_name Level5AIPanel
extends VBoxContainer

signal inspect_requested(title: String, body: String, meta: Dictionary)
signal replay_requested(run_id: int)

var _body: RichTextLabel
var _replay_row: HBoxContainer


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
	_replay_row = HBoxContainer.new()
	_replay_row.add_theme_constant_override("separation", 8)
	add_child(_replay_row)


func bind_report(report: MassSimBatchReport) -> void:
	for child: Node in _replay_row.get_children():
		child.queue_free()
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
		+ "[b]Live Utility Inspector Snapshot[/b]\n%s"
	) % [
		delta_pct,
		sample_text,
	]
	_add_replay_btn("Best", int(report.curator.get("best_performance_id", -1)))
	_add_replay_btn("Worst", int(report.curator.get("worst_performance_id", -1)))
	_add_replay_btn("Median", int(report.curator.get("median_match_id", -1)))
	_add_replay_btn("Upset", int(report.curator.get("biggest_upset_id", -1)))
	_add_replay_btn("Chaotic", int(report.curator.get("most_chaotic_id", -1)))


func _add_replay_btn(label: String, run_id: int) -> void:
	if run_id < 0:
		return
	var btn := Button.new()
	btn.text = "%s #%d" % [label, run_id]
	MassSimTheme.style_button(btn)
	btn.pressed.connect(func() -> void:
		replay_requested.emit(run_id)
		inspect_requested.emit(
			"Curated Replay: %s" % label,
			"Run #%d selected from batch curator." % run_id,
			{"run_id": run_id},
		)
	)
	_replay_row.add_child(btn)
