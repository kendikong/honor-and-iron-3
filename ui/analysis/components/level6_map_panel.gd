class_name Level6MapPanel
extends VBoxContainer

signal inspect_requested(title: String, body: String, meta: Dictionary)

var _body: RichTextLabel


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "Level 6: Environment & Map Bias"
	MassSimTheme.style_section(title)
	add_child(title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_body)


func bind_report(report: MassSimBatchReport) -> void:
	if report == null or report.is_empty():
		_body.text = "[i]Run a batch to evaluate map-tag bias.[/i]"
		return
	if report.map_tag_records.is_empty():
		_body.text = "[i]No map tags recorded in telemetry. Runner tags open grass boards as [open].[/i]"
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]Map Tag Filtering[/b]")
	for tag_id: Variant in report.map_tag_records.keys():
		var rec: Dictionary = report.map_tag_records[tag_id] as Dictionary
		var wr: float = float(rec.get("player_win_pct", 0.0))
		var dev: float = absf(wr - MassSimConstants.TARGET_PLAYER_WIN_PCT)
		var color: String = "#7dcea0" if dev < 6.0 else ("#ffb347" if dev < 12.0 else "#ff6b6b")
		lines.append(
			"â€¢ [%s] Win Rate: [color=%s]%.1f%%[/color] (%d matches)"
			% [str(tag_id), color, wr, int(rec.get("battles", 0))]
		)
	lines.append("")
	lines.append("[b]Spawn Bias Validator[/b]")
	if report.spawn_quadrant_records.is_empty():
		lines.append("[i]No spawn quadrant telemetry in this batch.[/i]")
	else:
		for quad_id: Variant in report.spawn_quadrant_records.keys():
			var rec: Dictionary = report.spawn_quadrant_records[quad_id] as Dictionary
			var wr: float = float(rec.get("player_win_pct", 0.0))
			var dev: float = absf(wr - MassSimConstants.TARGET_PLAYER_WIN_PCT)
			var color: String = "#7dcea0" if dev < 6.0 else ("#ffb347" if dev < 12.0 else "#ff6b6b")
			lines.append(
				"â€¢ Spawn %s: [color=%s]%.1f%%[/color] WR (%d matches)"
				% [str(quad_id), color, wr, int(rec.get("battles", 0))]
			)
	_body.text = "\n".join(lines)
