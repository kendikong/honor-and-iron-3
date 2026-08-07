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
		+ "â€¢ Wall Collisions: %d\n"
		+ "â€¢ Chain Collisions: %d\n"
		+ "â€¢ Hazard Landings: %d\n"
		+ "â€¢ Friendly Fire Incidents: %d\n"
		+ "â€¢ Avg Chaos Score / match: %.1f\n\n"
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
	if report.collision_heatmap.is_empty():
		return "[i]%s[/i]" % report.sample_gate_label("spatial heatmap")
	var max_hits: int = 1
	for key: Variant in report.collision_heatmap.keys():
		max_hits = maxi(max_hits, int(report.collision_heatmap[key]))
	var lines: PackedStringArray = PackedStringArray()
	var keys: Array = report.collision_heatmap.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(report.collision_heatmap[a]) > int(report.collision_heatmap[b])
	)
	for key: Variant in keys.slice(0, 12):
		var hits: int = int(report.collision_heatmap[key])
		var bars: int = clampi(int(float(hits) / float(max_hits) * 14.0), 1, 14)
		lines.append("%s | %s (%d)" % [str(key), "â–ˆ".repeat(bars), hits])
	return "\n".join(lines)
