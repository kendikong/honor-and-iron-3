class_name TriageEngine
extends RefCounted

const _C = preload("res://core/batch/mass_sim_constants.gd")

## Algorithmic root-cause ranking from MassSimBatchReport telemetry.

enum Severity {
	INFO,
	MODERATE,
	MAJOR,
	CRITICAL,
}


static func evaluate_report(report: RefCounted) -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	if report == null or report.is_empty():
		warnings.append(_warning(
			"No Batch Loaded",
			Severity.INFO,
			100,
			"Run a simulation batch or load JSONL results to begin triage.",
		))
		return warnings

	if not report.has_full_confidence():
		warnings.append(_warning(
			"Sample Size Below Confidence Gate",
			Severity.MODERATE,
			95,
			report.sample_gate_label("full statistical confidence"),
		))

	var player_dev: float = absf(report.player_win_pct - _C.TARGET_PLAYER_WIN_PCT)
	if player_dev >= _C.WIN_RATE_CRITICAL_DEV_PCT:
		warnings.append(_warning(
			"Critical Win-Rate Skew",
			Severity.CRITICAL,
			98,
			"Player win rate %.1f%% deviates %.1f%% from 50%% target â€” likely systemic imbalance."
			% [report.player_win_pct, player_dev],
		))
	elif player_dev >= _C.WIN_RATE_MAJOR_DEV_PCT:
		warnings.append(_warning(
			"Win-Rate Drift",
			Severity.MAJOR,
			90,
			"Player win rate %.1f%% (target 50%%). Review class passives and AI aggression."
			% report.player_win_pct,
		))

	if report.timeout_pct > _C.TARGET_TIMEOUT_PCT * 3.0:
		warnings.append(_warning(
			"Stalled Matches",
			Severity.MAJOR,
			88,
			"%.1f%% of battles timed out â€” AI may be stalling or damage floor is too low."
			% report.timeout_pct,
		))

	var whiff_pct: float = float(report.battles_with_whiffs) / float(maxi(report.total_battles, 1)) * 100.0
	if whiff_pct > _C.TARGET_WHIFF_BATTLES_PCT:
		warnings.append(_warning(
			"Execution Whiff Spike",
			Severity.MAJOR,
			86,
			"%.1f%% of matches had execution-phase whiffs (target < %.0f%%)."
			% [whiff_pct, _C.TARGET_WHIFF_BATTLES_PCT],
		))

	for tag_id: Variant in report.map_tag_records.keys():
		var tag_rec: Dictionary = report.map_tag_records[tag_id] as Dictionary
		var battles: int = int(tag_rec.get("battles", 0))
		if battles < _C.MIN_CLASS_APPEARANCES:
			continue
		var tag_wr: float = float(tag_rec.get("player_win_pct", 50.0))
		if absf(tag_wr - _C.TARGET_PLAYER_WIN_PCT) >= _C.MAP_BIAS_MAJOR_DEV_PCT:
			warnings.append(_warning(
				"Map Bias: %s" % str(tag_id),
				Severity.MAJOR,
				97,
				"[%s] player win rate %.1f%% across %d matches."
				% [str(tag_id), tag_wr, battles],
			))

	for row: Dictionary in report.tier_rows:
		if String(row.get("tier", "")) == "F" and int(row.get("appearances", 0)) >= _C.MIN_CLASS_APPEARANCES:
			warnings.append(_warning(
				"Underperformer: %s" % report.class_display_name(row.get("class_id", "")),
				Severity.MODERATE,
				84,
				"%s sits in F-tier at %.1f%% WR â€” check synergies and AI trap vectors."
				% [report.class_display_name(row.get("class_id", "")), float(row.get("win_rate", 0.0))],
			))

	if report.integrity_score < 60.0:
		warnings.append(_warning(
			"Low Simulation Integrity",
			Severity.MODERATE,
			80,
			"Integrity score %.0f / 100. %s"
			% [report.integrity_score, " Â· ".join(report.integrity_notes)],
		))

	var chaos_values: Array[float] = []
	for row: Dictionary in report.raw_rows:
		var chaos: float = float(
			int(row.get("wall_collisions", 0))
			+ int(row.get("chain_collisions", 0))
			+ int(row.get("hazard_landings", 0))
		)
		chaos_values.append(chaos)
	if chaos_values.size() >= _C.MIN_CLASS_APPEARANCES:
		var mean: float = 0.0
		for v: float in chaos_values:
			mean += v
		mean /= float(chaos_values.size())
		var variance: float = 0.0
		for v: float in chaos_values:
			variance += (v - mean) * (v - mean)
		variance /= float(chaos_values.size())
		var std: float = sqrt(variance)
		if std > 0.01:
			var outliers: int = 0
			for v: float in chaos_values:
				if absf(v - mean) / std > 2.5:
					outliers += 1
			if outliers > 0:
				var pct: float = float(outliers) / float(chaos_values.size()) * 100.0
				warnings.append(_warning(
					"Chaos Z-Score Outliers",
					Severity.MODERATE,
					82,
					"%d matches (%.1f%%) exceed 2.5Ïƒ collision chaos â€” review push chains or map hazards."
					% [outliers, pct],
				))

	if warnings.is_empty() or not _has_major_or_critical(warnings):
		warnings.insert(0, _warning(
			"Health Check Passed",
			Severity.INFO,
			92,
			"No major statistical anomalies detected in this batch.",
		))

	warnings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: int = int(a["severity"])
		var sb: int = int(b["severity"])
		if sa != sb:
			return sa > sb
		return int(a.get("confidence", 0)) > int(b.get("confidence", 0))
	)
	return warnings


static func _has_major_or_critical(warnings: Array) -> bool:
	for w: Variant in warnings:
		if w is Dictionary and int((w as Dictionary).get("severity", 0)) >= Severity.MAJOR:
			return true
	return false


static func generate_health_summary(report: RefCounted, warnings: Array) -> String:
	if report == null or report.is_empty():
		return "No batch loaded. Queue a simulation job to generate telemetry."

	var critical_count: int = 0
	var major_count: int = 0
	for w: Variant in warnings:
		if not w is Dictionary:
			continue
		var wd: Dictionary = w as Dictionary
		match int(wd.get("severity", Severity.INFO)):
			Severity.CRITICAL:
				critical_count += 1
			Severity.MAJOR:
				major_count += 1

	var mvp: String = "â€”"
	if not report.tier_rows.is_empty():
		var top: Dictionary = report.tier_rows[0]
		mvp = "%s (%.1f%% WR)" % [
			report.class_display_name(top.get("class_id", "")),
			float(top.get("win_rate", 0.0)),
		]

	if critical_count > 0:
		return (
			"Overall Health: [color=#ff6b6b]Critical[/color]. %d game-breaking signals. "
			+ "Combat MVP: %s. Integrity %.0f/100."
		) % [critical_count, mvp, report.integrity_score]
	if major_count > 0:
		return (
			"Overall Health: [color=#ffb347]Needs Tuning[/color]. %d major anomalies. "
			+ "Player WR %.1f%% (target 50%%). MVP: %s."
		) % [major_count, report.player_win_pct, mvp]
	return (
		"Overall Health: [color=#7dcea0]Good[/color]. Metrics within target margins. "
		+ "Player WR %.1f%%, avg %.1f turns, integrity %.0f/100."
	) % [report.player_win_pct, report.avg_turns, report.integrity_score]


static func _warning(title: String, severity: int, confidence: int, description: String) -> Dictionary:
	return {
		"title": title,
		"severity": severity,
		"confidence": confidence,
		"description": description,
		"state": "investigating",
	}
