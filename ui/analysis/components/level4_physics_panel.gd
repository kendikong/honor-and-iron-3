class_name Level4PhysicsPanel
extends VBoxContainer

signal inspect_requested(title: String, body: String, meta: Dictionary)

var _body: RichTextLabel


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "Level 4: Physics & Spatial Control"
	MassSimTheme.style_section(title)
	add_child(title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_body)


func bind_report(report: MassSimBatchReport) -> void:
	if report == null or report.is_empty():
		_body.text = "[i]Run a batch to populate collision telemetry.[/i]"
		return
	var chaos_avg: float = float(
		report.total_wall_collisions + report.total_chain_collisions + report.total_hazard_landings
	) / float(maxi(report.total_battles, 1))
	_body.text = (
		"[b]Collision Analytics[/b]\n"
		+ "• Wall Collisions: %d\n"
		+ "• Chain Collisions: %d\n"
		+ "• Hazard Landings: %d\n"
		+ "• Friendly Fire Incidents: %d\n"
		+ "• Avg Chaos Score / match: %.1f\n\n"
		+ "[b]Collision Heatmap (aggregate)[/b]\n"
		+ "%s"
	) % [
		report.total_wall_collisions,
		report.total_chain_collisions,
		report.total_hazard_landings,
		report.total_friendly_fire,
		chaos_avg,
		_build_heatmap_ascii(report),
	]


func _build_heatmap_ascii(report: MassSimBatchReport) -> String:
	var intensity: int = clampi(int(report.total_wall_collisions / maxi(report.total_battles, 1)), 0, 8)
	var bar: String = ""
	for i: int in range(16):
		bar += "█" if i < intensity * 2 else "░"
	return "[font=monospace]%s[/font]  (wall collision density)" % bar
