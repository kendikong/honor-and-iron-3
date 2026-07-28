class_name MassSimInterpretationExport
extends RefCounted

const _C = preload("res://core/batch/mass_sim_constants.gd")

## Full post-batch export for agent interpretation — every dashboard statistic, one file.


static func write_bundle(
	report: MassSimBatchReport,
	warnings: Array,
	context: Dictionary = {},
) -> Dictionary:
	var bundle: Dictionary = build(report, warnings, context)
	var paths: Dictionary = {}

	var capture_dir: String = ProjectSettings.globalize_path(_C.CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(capture_dir)

	var json_capture: String = capture_dir.path_join("mass_sim_interpretation.json")
	var md_capture: String = capture_dir.path_join("mass_sim_interpretation.md")
	_write_text(json_capture, JSON.stringify(bundle, "\t"))
	_write_text(md_capture, to_markdown(bundle))
	paths["json_capture"] = json_capture
	paths["markdown_capture"] = md_capture

	var user_json: String = _C.INTERPRETATION_USER_PATH
	_write_text(user_json, JSON.stringify(bundle, "\t"))
	paths["json_user"] = user_json

	print("[INTERPRETATION] %s" % json_capture)
	print("[INTERPRETATION] %s" % md_capture)
	return paths


static func build(
	report: MassSimBatchReport,
	warnings: Array,
	context: Dictionary = {},
) -> Dictionary:
	var bundle: Dictionary = {
		"purpose": "Full mass simulation statistics for agent interpretation after a batch run.",
		"generated_at_unix": Time.get_unix_time_from_system(),
		"context": context.duplicate(true),
		"confidence_gate": {
			"required_battles": _C.MIN_SAMPLE_FULL_CONFIDENCE,
			"current_battles": report.total_battles if report != null else 0,
			"has_full_confidence": report.has_full_confidence() if report != null else false,
		},
	}
	if report == null or report.is_empty():
		bundle["empty"] = true
		bundle["triage"] = warnings
		return bundle

	bundle["empty"] = false
	bundle["source_log"] = report.source_path
	bundle["targets"] = {
		"player_win_pct": _C.TARGET_PLAYER_WIN_PCT,
		"avg_turns": _C.TARGET_AVG_TURNS,
		"whiff_battles_pct": _C.TARGET_WHIFF_BATTLES_PCT,
		"timeout_pct": _C.TARGET_TIMEOUT_PCT,
	}
	bundle["l1_executive"] = _l1_executive(report)
	bundle["l2_balance"] = _l2_balance(report)
	bundle["l3_economy"] = _l3_economy(report)
	bundle["skill_meta"] = {
		"ai_commander": report.ai_commander_meta,
		"class_combat_rows": report.class_combat_rows,
		"skill_rows": report.skill_meta_rows,
		"total_sim_turns": report.total_sim_turns,
	}
	bundle["l4_physics"] = _l4_physics(report)
	bundle["l5_ai"] = _l5_ai(report)
	bundle["l6_environment"] = _l6_environment(report)
	bundle["l7_integrity"] = _l7_integrity(report)
	bundle["triage"] = _triage_full(warnings)
	bundle["curated_replays"] = _curated_replays(report)
	bundle["timeline"] = report.timeline_entries
	bundle["version_deltas"] = {
		"player_win_pct": report.format_pct_delta(report.player_win_pct, report.previous_player_win_pct),
		"avg_turns": report.format_pct_delta(report.avg_turns, report.previous_avg_turns, ""),
		"integrity": report.format_pct_delta(report.integrity_score, report.previous_integrity, " pts"),
	}
	return bundle


static func to_markdown(bundle: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# Mass Simulation Interpretation Report")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_unix_time(
		int(bundle.get("generated_at_unix", 0)), true,
	))
	if bool(bundle.get("empty", true)):
		lines.append("")
		lines.append("_No batch data loaded._")
		return "\n".join(lines)

	var l1: Dictionary = bundle.get("l1_executive", {}) as Dictionary
	lines.append("")
	lines.append("## Executive (L1)")
	lines.append("- Battles: %d (confidence gate: %s)" % [
		int(l1.get("total_battles", 0)),
		"PASS" if bool((bundle.get("confidence_gate", {}) as Dictionary).get("has_full_confidence", false)) else "BELOW 500",
	])
	lines.append("- Player WR: %.1f%% | Enemy WR: %.1f%% | Draw: %.1f%% | Timeout: %.1f%%" % [
		float(l1.get("player_win_pct", 0)),
		float(l1.get("enemy_win_pct", 0)),
		float(l1.get("draw_pct", 0)),
		float(l1.get("timeout_pct", 0)),
	])
	lines.append("- Avg turns: %.1f | Median: %d | Integrity: %.0f/100" % [
		float(l1.get("avg_turns", 0)),
		int(l1.get("median_turns", 0)),
		float(l1.get("integrity_score", 0)),
	])
	lines.append("- Meta diversity: %.0f%% (%d classes seen)" % [
		float(l1.get("meta_diversity_pct", 0)),
		int(l1.get("unique_classes_seen", 0)),
	])

	lines.append("")
	lines.append("## Triage (ranked)")
	for w: Variant in bundle.get("triage", []):
		if not w is Dictionary:
			continue
		var wd: Dictionary = w as Dictionary
		lines.append("- **[%s] %s** (conf %d%%): %s" % [
			_severity_name(int(wd.get("severity", 0))),
			String(wd.get("title", "")),
			int(wd.get("confidence", 0)),
			String(wd.get("description", "")),
		])

	lines.append("")
	lines.append("## Balance tiers (L2)")
	for row: Variant in (bundle.get("l2_balance", {}) as Dictionary).get("tier_rows", []):
		if row is Dictionary:
			var r: Dictionary = row as Dictionary
			lines.append("- %s [%s]: %.1f%% WR (n=%d) ±%.1f%% Wilson" % [
				String(r.get("display_name", r.get("class_id", "?"))),
				String(r.get("tier", "?")),
				float(r.get("win_rate", 0)),
				int(r.get("appearances", 0)),
				float(r.get("wilson_margin_pct", 0)),
			])

	var econ: Dictionary = bundle.get("l3_economy", {}) as Dictionary
	lines.append("")
	lines.append("## Economy (L3)")
	lines.append("- Assisted damage: %d | Shields: %d | Overkill: %d | Floated AP turns: %d" % [
		int(econ.get("assisted_damage", 0)),
		int(econ.get("assisted_shields", 0)),
		int(econ.get("overkill", 0)),
		int(econ.get("floated_ap", 0)),
	])
	lines.append("- Battles with whiffs: %.1f%%" % float(econ.get("whiff_battles_pct", 0)))

	var skill: Dictionary = bundle.get("skill_meta", {}) as Dictionary
	lines.append("")
	lines.append("## Commander AI & Skill Meta (L3)")
	var ai: Dictionary = skill.get("ai_commander", {}) as Dictionary
	if ai.is_empty():
		lines.append("_Run a new batch to populate Commander AI skill meta._")
	else:
		lines.append("- Avg utility/turn: %.2f · Holds/turn: %.2f · Skill commits/turn: %.2f" % [
			float(ai.get("avg_utility_per_turn", 0)),
			float(ai.get("holds_per_turn", 0)),
			float(ai.get("skill_commits_per_turn", 0)),
		])
	for row: Variant in (skill.get("class_combat_rows", []) as Array).slice(0, 10):
		if row is Dictionary:
			var r: Dictionary = row as Dictionary
			lines.append("- Class %s: dmg/turn %.2f · taken/turn %.2f · AI hold %.0f%%" % [
				String(r.get("class_id", "?")),
				float(r.get("damage_dealt_per_turn", 0)),
				float(r.get("damage_taken_per_turn", 0)),
				float(r.get("ai_hold_rate_pct", 0)),
			])
	for row: Variant in (skill.get("skill_rows", []) as Array).slice(0, 15):
		if row is Dictionary:
			var s: Dictionary = row as Dictionary
			lines.append("- %s/%s: uses/turn %.3f · pick %.0f%% · dmg/turn %.2f" % [
				String(s.get("class_id", "")),
				String(s.get("display_name", s.get("ability_id", ""))),
				float(s.get("uses_per_turn", 0)),
				float(s.get("pick_rate_when_legal_pct", 0)),
				float(s.get("damage_per_turn", 0)),
			])

	var phys: Dictionary = bundle.get("l4_physics", {}) as Dictionary
	lines.append("")
	lines.append("## Physics (L4)")
	lines.append("- Wall: %d | Chain: %d | Hazards: %d | Friendly fire: %d | Avg chaos/match: %.1f" % [
		int(phys.get("wall_collisions", 0)),
		int(phys.get("chain_collisions", 0)),
		int(phys.get("hazard_landings", 0)),
		int(phys.get("friendly_fire", 0)),
		float(phys.get("avg_chaos_per_match", 0)),
	])
	lines.append("- Top heatmap cells: %s" % str(phys.get("top_heatmap_cells", [])))

	var env: Dictionary = bundle.get("l6_environment", {}) as Dictionary
	lines.append("")
	lines.append("## Environment (L6)")
	for tag: Variant in (env.get("map_tags", {}) as Dictionary).keys():
		var rec: Dictionary = (env.get("map_tags", {}) as Dictionary)[tag] as Dictionary
		lines.append("- Map [%s]: %.1f%% WR (%d matches)" % [
			str(tag), float(rec.get("player_win_pct", 0)), int(rec.get("battles", 0)),
		])
	for quad: Variant in (env.get("spawn_quadrants", {}) as Dictionary).keys():
		var qrec: Dictionary = (env.get("spawn_quadrants", {}) as Dictionary)[quad] as Dictionary
		lines.append("- Spawn %s: %.1f%% WR (%d matches)" % [
			str(quad), float(qrec.get("player_win_pct", 0)), int(qrec.get("battles", 0)),
		])

	var integ: Dictionary = bundle.get("l7_integrity", {}) as Dictionary
	lines.append("")
	lines.append("## Integrity (L7)")
	for note: Variant in integ.get("notes", []):
		lines.append("- %s" % str(note))
	if not (integ.get("missing_classes", []) as Array).is_empty():
		lines.append("- Missing classes: %s" % str(integ.get("missing_classes", [])))

	lines.append("")
	lines.append("## Curated replays (L5)")
	for entry: Variant in bundle.get("curated_replays", []):
		if entry is Dictionary:
			var e: Dictionary = entry as Dictionary
			lines.append("- %s: run #%s" % [String(e.get("label", "")), str(e.get("run_id", "?"))])

	return "\n".join(lines)


static func _l1_executive(report: MassSimBatchReport) -> Dictionary:
	return {
		"total_battles": report.total_battles,
		"player_wins": report.player_wins,
		"enemy_wins": report.enemy_wins,
		"draws": report.draws,
		"timeouts": report.timeouts,
		"player_win_pct": report.player_win_pct,
		"enemy_win_pct": report.enemy_win_pct,
		"draw_pct": report.draw_pct,
		"timeout_pct": report.timeout_pct,
		"avg_turns": report.avg_turns,
		"median_turns": report.median_turns,
		"turn_histogram": report.turn_histogram.duplicate(true),
		"integrity_score": report.integrity_score,
		"meta_diversity_pct": report.meta_diversity_pct,
		"unique_classes_seen": report.unique_classes_seen,
		"total_player_class_slots": report.total_player_classes,
	}


static func _l2_balance(report: MassSimBatchReport) -> Dictionary:
	var rows: Array[Dictionary] = []
	for row: Dictionary in report.tier_rows:
		var copy: Dictionary = row.duplicate(true)
		var apps: int = int(copy.get("appearances", 0))
		var wins: int = int(round(float(copy.get("win_rate", 0.0)) / 100.0 * float(apps)))
		copy["display_name"] = report.class_display_name(copy.get("class_id", ""))
		copy["wilson_margin_pct"] = report.wilson_margin(wins, apps)
		rows.append(copy)
	return {
		"tier_rows": rows,
		"matchup_snippets": report.matchup_snippets,
		"class_records": _enrich_class_records(report),
	}


static func _enrich_class_records(report: MassSimBatchReport) -> Dictionary:
	var out: Dictionary = {}
	for class_id: Variant in report.class_records.keys():
		var rec: Dictionary = (report.class_records[class_id] as Dictionary).duplicate(true)
		rec["display_name"] = report.class_display_name(class_id)
		out[str(class_id)] = rec
	return out


static func _l3_economy(report: MassSimBatchReport) -> Dictionary:
	var n: int = maxi(report.total_battles, 1)
	return {
		"assisted_damage": report.total_assisted_damage,
		"assisted_shields": report.total_assisted_shields,
		"overkill": report.total_overkill,
		"floated_ap": report.total_floated_ap,
		"execution_whiffs": report.total_execution_whiffs,
		"battles_with_whiffs": report.battles_with_whiffs,
		"whiff_battles_pct": float(report.battles_with_whiffs) / float(n) * 100.0,
		"avg_assisted_damage_per_match": float(report.total_assisted_damage) / float(n),
	}


static func _l4_physics(report: MassSimBatchReport) -> Dictionary:
	var n: int = maxi(report.total_battles, 1)
	var chaos_total: int = (
		report.total_wall_collisions + report.total_chain_collisions + report.total_hazard_landings
	)
	return {
		"wall_collisions": report.total_wall_collisions,
		"chain_collisions": report.total_chain_collisions,
		"hazard_landings": report.total_hazard_landings,
		"friendly_fire": report.total_friendly_fire,
		"avg_chaos_per_match": float(chaos_total) / float(n),
		"top_heatmap_cells": _top_heatmap(report.collision_heatmap, 24),
		"heatmap_cell_count": report.collision_heatmap.size(),
	}


static func _top_heatmap(heatmap: Dictionary, limit: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for key: Variant in heatmap.keys():
		rows.append({"cell": str(key), "hits": int(heatmap[key])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["hits"]) > int(b["hits"])
	)
	return rows.slice(0, limit)


static func _l5_ai(report: MassSimBatchReport) -> Dictionary:
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
	return {
		"ai_sample_count": report.ai_samples.size(),
		"collision_pressure_delta_pct": delta_pct,
		"curator_ids": report.curator.duplicate(true),
		"latest_ai_sample": report.ai_samples[report.ai_samples.size() - 1] if not report.ai_samples.is_empty() else {},
	}


static func _l6_environment(report: MassSimBatchReport) -> Dictionary:
	return {
		"map_tags": report.map_tag_records.duplicate(true),
		"spawn_quadrants": report.spawn_quadrant_records.duplicate(true),
	}


static func _l7_integrity(report: MassSimBatchReport) -> Dictionary:
	var ci_rows: Array[Dictionary] = []
	for row: Dictionary in report.tier_rows:
		var apps: int = int(row.get("appearances", 0))
		var wins: int = int(round(float(row.get("win_rate", 0.0)) / 100.0 * float(apps)))
		ci_rows.append({
			"class_id": row.get("class_id", ""),
			"display_name": report.class_display_name(row.get("class_id", "")),
			"win_rate": float(row.get("win_rate", 0.0)),
			"wilson_margin_pct": report.wilson_margin(wins, apps),
			"appearances": apps,
			"tier": row.get("tier", "?"),
		})
	return {
		"integrity_score": report.integrity_score,
		"notes": Array(report.integrity_notes),
		"missing_classes": Array(report.missing_classes),
		"confidence_intervals": ci_rows,
		"parse_errors": report.parse_errors,
	}


static func _triage_full(warnings: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Variant in warnings:
		if w is Dictionary:
			var copy: Dictionary = (w as Dictionary).duplicate(true)
			copy["severity_name"] = _severity_name(int(copy.get("severity", 0)))
			out.append(copy)
	return out


static func _curated_replays(report: MassSimBatchReport) -> Array[Dictionary]:
	var keys: PackedStringArray = PackedStringArray([
		"best_performance_id", "worst_performance_id", "median_match_id",
		"biggest_upset_id", "most_chaotic_id",
	])
	var labels: Dictionary = {
		"best_performance_id": "Best performance",
		"worst_performance_id": "Worst performance",
		"median_match_id": "Median match",
		"biggest_upset_id": "Biggest upset",
		"most_chaotic_id": "Most chaotic",
	}
	var out: Array[Dictionary] = []
	for key: String in keys:
		var run_id: int = int(report.curator.get(key, -1))
		var entry: Dictionary = {
			"label": labels.get(key, key),
			"curator_key": key,
			"run_id": run_id,
		}
		if run_id >= 0:
			var row: Dictionary = report.row_for_run_id(run_id)
			entry["summary"] = {
				"winner": row.get("winner", -1),
				"turns": row.get("turns_taken", 0),
				"layout": row.get("map_layout_id", ""),
				"player_classes": row.get("player_classes", []),
				"wall_collisions": row.get("wall_collisions", 0),
				"execution_whiffs": row.get("execution_whiffs", 0),
			}
		out.append(entry)
	return out


static func _severity_name(severity: int) -> String:
	match severity:
		0:
			return "INFO"
		1:
			return "MODERATE"
		2:
			return "MAJOR"
		3:
			return "CRITICAL"
		_:
			return "UNKNOWN"


static func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("[INTERPRETATION_FAIL] cannot write %s" % path)
		return
	file.store_string(text)
	file.close()
