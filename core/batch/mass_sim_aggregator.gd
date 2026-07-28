class_name MassSimAggregator
extends RefCounted

const _C = preload("res://core/batch/mass_sim_constants.gd")
const _ReportT = preload("res://core/batch/mass_sim_batch_report.gd")

## Loads JSONL telemetry and builds a MassSimBatchReport for the dashboard.


static func load_jsonl(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return rows
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var json := JSON.new()
		if json.parse(line) == OK and json.data is Dictionary:
			rows.append(json.data as Dictionary)
	file.close()
	return rows


static func build_report(
	rows: Array,
	source_path: String = "",
	curator: Dictionary = {},
) -> RefCounted:
	var report: RefCounted = _ReportT.new()
	report.source_path = source_path
	report.curator = curator.duplicate(true)
	report.raw_rows.assign(rows)
	report.total_battles = rows.size()
	if report.total_battles == 0:
		return report

	var turn_buf: Array[int] = []
	var chaos_scores: Array[float] = []
	var class_ids_seen: Dictionary = {}

	for row: Dictionary in rows:
		var winner: int = int(row.get("winner", GameEnums.Team.NEUTRAL))
		match winner:
			GameEnums.Team.PLAYER:
				report.player_wins += 1
			GameEnums.Team.ENEMY:
				report.enemy_wins += 1
			_:
				report.draws += 1

		if String(row.get("completion_reason", "")) == "timeout":
			report.timeouts += 1

		var turns: int = int(row.get("turns_taken", 0))
		turn_buf.append(turns)

		report.total_wall_collisions += int(row.get("wall_collisions", 0))
		report.total_chain_collisions += int(row.get("chain_collisions", 0))
		report.total_hazard_landings += int(row.get("hazard_landings", 0))
		report.total_friendly_fire += int(row.get("friendly_fire_incidents", 0))
		report.total_assisted_damage += int(row.get("assisted_damage", 0))
		report.total_assisted_shields += int(row.get("assisted_shields", 0))
		report.total_execution_whiffs += int(row.get("execution_whiffs", 0))
		report.total_overkill += int(row.get("overkill_damage", 0))
		report.total_floated_ap += int(row.get("floated_ap_turns", 0))
		if int(row.get("execution_whiffs", 0)) > 0:
			report.battles_with_whiffs += 1

		var chaos: float = float(
			int(row.get("wall_collisions", 0))
			+ int(row.get("chain_collisions", 0))
			+ int(row.get("hazard_landings", 0))
		)
		chaos_scores.append(chaos)

		var player_won: bool = winner == GameEnums.Team.PLAYER
		for raw_class: Variant in row.get("player_classes", []):
			var class_id: String = str(raw_class)
			if class_id.is_empty():
				continue
			class_ids_seen[class_id] = true
			report.total_player_classes += 1
			var rec: Dictionary = _class_record(report.class_records, class_id)
			rec["appearances"] = int(rec["appearances"]) + 1
			if player_won:
				rec["wins"] = int(rec["wins"]) + 1
			rec["damage_enabled"] = int(rec["damage_enabled"]) + int(row.get("assisted_damage", 0))
			rec["turns_sum"] = int(rec["turns_sum"]) + turns

		for raw_enemy: Variant in row.get("enemy_classes", []):
			class_ids_seen[str(raw_enemy)] = true

		for raw_tag: Variant in row.get("map_tags", []):
			var tag: String = str(raw_tag)
			if tag.is_empty():
				continue
			var tag_rec: Dictionary = _class_record(report.map_tag_records, tag)
			tag_rec["battles"] = int(tag_rec["battles"]) + 1
			if player_won:
				tag_rec["player_wins"] = int(tag_rec["player_wins"]) + 1

		for sample: Variant in row.get("ai_telemetry", []):
			if sample is Dictionary:
				var copy: Dictionary = (sample as Dictionary).duplicate(true)
				copy["run_id"] = row.get("run_id", -1)
				report.ai_samples.append(copy)

	turn_buf.sort()
	report.turn_values = turn_buf
	report.avg_turns = _average_int(turn_buf)
	report.median_turns = turn_buf[turn_buf.size() / 2] if not turn_buf.is_empty() else 0

	var n: float = float(report.total_battles)
	report.player_win_pct = float(report.player_wins) / n * 100.0
	report.enemy_win_pct = float(report.enemy_wins) / n * 100.0
	report.draw_pct = float(report.draws) / n * 100.0
	report.timeout_pct = float(report.timeouts) / n * 100.0
	report.unique_classes_seen = class_ids_seen.size()

	_finalize_class_rates(report)
	report.tier_rows = _build_tier_rows(report)
	report.matchup_snippets = _build_matchup_snippets(report)
	report.integrity_score = _compute_integrity(report, class_ids_seen, chaos_scores)
	_load_previous_snapshot(report)
	return report


static func _class_record(store: Dictionary, key: String) -> Dictionary:
	if not store.has(key):
		store[key] = {
			"wins": 0,
			"appearances": 0,
			"win_rate": 0.0,
			"damage_enabled": 0,
			"turns_sum": 0,
			"tags": [],
		}
	return store[key] as Dictionary


static func _finalize_class_rates(report: RefCounted) -> void:
	for class_id: Variant in report.class_records.keys():
		var rec: Dictionary = report.class_records[class_id] as Dictionary
		var apps: int = int(rec["appearances"])
		rec["win_rate"] = float(rec["wins"]) / float(maxi(apps, 1)) * 100.0
		rec["avg_turns"] = float(rec["turns_sum"]) / float(maxi(apps, 1))
		var tags: Array[String] = []
		if apps < _C.MIN_CLASS_APPEARANCES:
			tags.append("Low Sample")
		if float(rec["win_rate"]) >= 58.0:
			tags.append("Map Dependent")
		if float(rec["win_rate"]) <= 42.0 and apps >= _C.MIN_CLASS_APPEARANCES:
			tags.append("Synergy Reliant")
		rec["tags"] = tags

	for tag_id: Variant in report.map_tag_records.keys():
		var tag_rec: Dictionary = report.map_tag_records[tag_id] as Dictionary
		var battles: int = int(tag_rec["battles"])
		tag_rec["player_win_pct"] = float(tag_rec["player_wins"]) / float(maxi(battles, 1)) * 100.0


static func _build_tier_rows(report: RefCounted) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for class_id: Variant in report.class_records.keys():
		var rec: Dictionary = report.class_records[class_id] as Dictionary
		var apps: int = int(rec["appearances"])
		if apps < 3:
			continue
		var wr: float = float(rec["win_rate"])
		var tier: String = "C"
		if wr >= 58.0:
			tier = "S"
		elif wr >= 52.0:
			tier = "A"
		elif wr >= 48.0:
			tier = "B"
		elif wr >= 42.0:
			tier = "C"
		else:
			tier = "F"
		rows.append({
			"class_id": str(class_id),
			"tier": tier,
			"win_rate": wr,
			"appearances": apps,
			"tags": rec.get("tags", []),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["win_rate"]) > float(b["win_rate"])
	)
	return rows


static func _build_matchup_snippets(report: RefCounted) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if report.tier_rows.is_empty():
		return out
	var best: Dictionary = report.tier_rows[0]
	var worst: Dictionary = report.tier_rows[report.tier_rows.size() - 1]
	out.append({
		"label": "%s vs field" % report.class_display_name(best["class_id"]),
		"detail": "WR %.1f%% across %d appearances" % [float(best["win_rate"]), int(best["appearances"])],
	})
	out.append({
		"label": "%s struggles" % report.class_display_name(worst["class_id"]),
		"detail": "WR %.1f%% — review counters" % float(worst["win_rate"]),
	})
	return out


static func _compute_integrity(
	report: RefCounted,
	class_ids_seen: Dictionary,
	chaos_scores: Array[float],
) -> float:
	var score: float = 0.0
	var notes: PackedStringArray = PackedStringArray()

	var sample_frac: float = clampf(
		float(report.total_battles) / float(_C.MIN_SAMPLE_FULL_CONFIDENCE),
		0.0,
		1.0,
	)
	score += sample_frac * 40.0
	if sample_frac < 1.0:
		notes.append(
			"Sample size %d / %d for full confidence"
			% [report.total_battles, _C.MIN_SAMPLE_FULL_CONFIDENCE],
		)
	else:
		notes.append("Sample size meets 500-match confidence gate")

	var library_count: int = 0
	if ClassDB.class_exists("DataLibrary"):
		library_count = DataLibrary.get_all_player_units().size()
	if library_count > 0:
		var coverage: float = float(class_ids_seen.size()) / float(library_count)
		score += clampf(coverage, 0.0, 1.0) * 30.0
		notes.append(
			"Subclass coverage %.0f%% (%d / %d)"
			% [coverage * 100.0, class_ids_seen.size(), library_count],
		)

	var timeout_penalty: float = clampf(report.timeout_pct / 25.0, 0.0, 1.0)
	score += (1.0 - timeout_penalty) * 20.0
	if report.timeout_pct > _C.TARGET_TIMEOUT_PCT:
		notes.append("Timeout rate elevated: %.1f%%" % report.timeout_pct)

	if not chaos_scores.is_empty():
		var mean_chaos: float = _average_float(chaos_scores)
		var diverse: float = 0.0
		for c: float in chaos_scores:
			if absf(c - mean_chaos) > 0.5:
				diverse += 1.0
		score += clampf(diverse / float(chaos_scores.size()) * 2.0, 0.0, 1.0) * 10.0
		notes.append("Chaos distribution spread OK")

	report.integrity_notes = notes
	return clampf(score, 0.0, 100.0)


static func _load_previous_snapshot(report: RefCounted) -> void:
	if not FileAccess.file_exists(_C.SNAPSHOT_PATH):
		return
	var file: FileAccess = FileAccess.open(_C.SNAPSHOT_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		file.close()
		return
	file.close()
	var snap: Dictionary = json.data as Dictionary
	report.previous_player_win_pct = float(snap.get("player_win_pct", -1.0))
	report.previous_avg_turns = float(snap.get("avg_turns", -1.0))
	report.previous_integrity = float(snap.get("integrity_score", -1.0))


static func save_snapshot(report: RefCounted) -> void:
	var file: FileAccess = FileAccess.open(_C.SNAPSHOT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"player_win_pct": report.player_win_pct,
		"enemy_win_pct": report.enemy_win_pct,
		"avg_turns": report.avg_turns,
		"integrity_score": report.integrity_score,
		"total_battles": report.total_battles,
		"timestamp": Time.get_unix_time_from_system(),
	}))
	file.close()


static func _average_int(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var sum: int = 0
	for v: int in values:
		sum += v
	return float(sum) / float(values.size())


static func _average_float(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sum: float = 0.0
	for v: float in values:
		sum += v
	return sum / float(values.size())
