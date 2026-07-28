class_name MassSimReplayFormat
extends RefCounted


static func format_run(report: MassSimBatchReport, run_id: int) -> String:
	var row: Dictionary = report.row_for_run_id(run_id)
	if row.is_empty():
		return "[color=#ff6b6b]Run #%d not found in loaded batch.[/color]" % run_id
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]Replay Run #%d[/b]" % run_id)
	lines.append("Winner: %s · Turns: %d · Reason: %s" % [
		_team_name(int(row.get("winner", -1))),
		int(row.get("turns_taken", 0)),
		String(row.get("completion_reason", "?")),
	])
	lines.append("Map: %s · Tags: %s" % [
		String(row.get("map_layout_id", "?")),
		str(row.get("map_tags", [])),
	])
	lines.append("Spawn: %s vs %s" % [
		String(row.get("player_spawn_quadrant", "?")),
		String(row.get("enemy_spawn_quadrant", "?")),
	])
	lines.append("Classes P: %s" % str(row.get("player_classes", [])))
	lines.append("Classes E: %s" % str(row.get("enemy_classes", [])))
	lines.append("")
	lines.append("[b]Combat Telemetry[/b]")
	lines.append("Collisions: %d · Chains: %d · Hazards: %d · Whiffs: %d" % [
		int(row.get("wall_collisions", 0)),
		int(row.get("chain_collisions", 0)),
		int(row.get("hazard_landings", 0)),
		int(row.get("execution_whiffs", 0)),
	])
	lines.append("Assisted Dmg: %d · Shields: %d · Overkill: %d" % [
		int(row.get("assisted_damage", 0)),
		int(row.get("assisted_shields", 0)),
		int(row.get("overkill_damage", 0)),
	])
	var ai_rows: Array = row.get("ai_telemetry", [])
	if ai_rows.is_empty():
		lines.append("")
		lines.append("[i]No AI telemetry captured for this run.[/i]")
	else:
		lines.append("")
		lines.append("[b]AI Utility (last turn)[/b]")
		var last: Dictionary = ai_rows[ai_rows.size() - 1] as Dictionary
		var tel: Dictionary = last.get("telemetry", last) as Dictionary
		lines.append("Turn %s · Utility keys: %s" % [str(last.get("turn", "?")), str(tel.keys())])
		if tel.has("total"):
			lines.append("Final_Utility: [b]%.2f[/b]" % float(tel["total"]))
		for key: Variant in tel.keys():
			if str(key) == "total":
				continue
			lines.append("  • %s: %s" % [str(key), str(tel[key])])
	return "\n".join(lines)


static func _team_name(team: int) -> String:
	match team:
		GameEnums.Team.PLAYER:
			return "Player"
		GameEnums.Team.ENEMY:
			return "Enemy"
		_:
			return "Neutral"
