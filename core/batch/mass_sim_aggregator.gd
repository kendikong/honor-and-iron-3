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
		else:
			# Caller may track via build_report parse_errors if needed
			pass
	file.close()
	return rows


static func filter_rows(rows: Array, map_tag_filter: String) -> Array:
	if map_tag_filter.is_empty():
		return rows
	var out: Array = []
	for row: Variant in rows:
		if not row is Dictionary:
			continue
		var tags: Array = (row as Dictionary).get("map_tags", [])
		if tags.has(map_tag_filter):
			out.append(row)
	return out


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
	var skill_store: Dictionary = {}
	var class_store: Dictionary = {}
	var passive_store: Dictionary = {}
	var ai_store: Dictionary = {
		"utility_sum": 0.0,
		"sample_turns": 0,
		"total_holds": 0,
		"total_skill_commits": 0,
		"pruned_turns": 0,
		"battles_with_meta": 0,
	}

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
			var tag_rec: Dictionary = _bucket_record(report.map_tag_records, tag)
			tag_rec["battles"] = int(tag_rec["battles"]) + 1
			if player_won:
				tag_rec["player_wins"] = int(tag_rec["player_wins"]) + 1

		for sample: Variant in row.get("ai_telemetry", []):
			if sample is Dictionary:
				var copy: Dictionary = (sample as Dictionary).duplicate(true)
				copy["run_id"] = row.get("run_id", -1)
				report.ai_samples.append(copy)

		for cell_key: Variant in row.get("collision_cells", []):
			var ck: String = str(cell_key)
			report.collision_heatmap[ck] = int(report.collision_heatmap.get(ck, 0)) + 1
		for cell_key: Variant in row.get("death_cells", []):
			var dk: String = str(cell_key)
			report.collision_heatmap[dk] = int(report.collision_heatmap.get(dk, 0)) + 1

		var pq: String = String(row.get("player_spawn_quadrant", ""))
		if not pq.is_empty():
			var sq: Dictionary = _bucket_record(report.spawn_quadrant_records, pq)
			sq["battles"] = int(sq["battles"]) + 1
			if player_won:
				sq["player_wins"] = int(sq["player_wins"]) + 1

		var t_bucket: String = str(turns)
		report.turn_histogram[t_bucket] = int(report.turn_histogram.get(t_bucket, 0)) + 1

		_merge_combat_meta(skill_store, class_store, ai_store, report, row.get("combat_meta", {}) as Dictionary)
		_merge_passive_meta(passive_store, row, player_won)

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
	var library_count: int = 0
	if ClassDB.class_exists("DataLibrary"):
		library_count = DataLibrary.get_all_player_units().size()
		report.meta_diversity_pct = float(class_ids_seen.size()) / float(maxi(library_count, 1)) * 100.0
		for def: UnitData in DataLibrary.get_all_player_units():
			if not class_ids_seen.has(str(def.id)):
				report.missing_classes.append(str(def.id))

	for q_id: Variant in report.spawn_quadrant_records.keys():
		var q_rec: Dictionary = report.spawn_quadrant_records[q_id] as Dictionary
		var qb: int = int(q_rec.get("battles", 0))
		q_rec["player_win_pct"] = float(q_rec.get("player_wins", 0)) / float(maxi(qb, 1)) * 100.0

	_finalize_class_rates(report)
	report.tier_rows = _build_tier_rows(report)
	report.matchup_snippets = _build_matchup_snippets(report)
	report.skill_meta_rows = _finalize_skill_meta(skill_store, class_store)
	report.class_combat_rows = _finalize_class_combat(class_store)
	report.passive_meta_rows = _finalize_passive_meta(passive_store)
	report.economy_per_turn = _finalize_economy_per_turn(report)
	report.ai_commander_meta = _finalize_ai_commander(ai_store, report.total_sim_turns)
	report.integrity_score = _compute_integrity(report, class_ids_seen, chaos_scores)
	_load_previous_snapshot(report)
	report.timeline_entries = load_timeline()
	return report


static func _bucket_record(store: Dictionary, key: String) -> Dictionary:
	if not store.has(key):
		store[key] = {
			"battles": 0,
			"player_wins": 0,
			"player_win_pct": 0.0,
		}
	return store[key] as Dictionary


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
		elif float(rec["win_rate"]) >= 58.0:
			tags.append("High Performer")
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
	append_timeline(report)


static func append_timeline(report: RefCounted) -> void:
	var file: FileAccess = FileAccess.open(_C.TIMELINE_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_C.TIMELINE_PATH, FileAccess.WRITE)
	else:
		file.seek_end()
	if file == null:
		return
	file.store_line(JSON.stringify({
		"timestamp": Time.get_unix_time_from_system(),
		"player_win_pct": report.player_win_pct,
		"avg_turns": report.avg_turns,
		"integrity_score": report.integrity_score,
		"total_battles": report.total_battles,
	}))
	file.close()


static func load_timeline() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(_C.TIMELINE_PATH):
		return out
	var file: FileAccess = FileAccess.open(_C.TIMELINE_PATH, FileAccess.READ)
	if file == null:
		return out
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var json := JSON.new()
		if json.parse(line) == OK and json.data is Dictionary:
			out.append(json.data as Dictionary)
	file.close()
	return out


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


static func _merge_combat_meta(
	skill_store: Dictionary,
	class_store: Dictionary,
	ai_store: Dictionary,
	report: RefCounted,
	combat_meta: Dictionary,
) -> void:
	if combat_meta.is_empty():
		return
	ai_store["battles_with_meta"] = int(ai_store.get("battles_with_meta", 0)) + 1
	report.total_sim_turns += int(combat_meta.get("total_turns", 0))
	for sk: Variant in combat_meta.get("skill_rows", []):
		if not sk is Dictionary:
			continue
		var sd: Dictionary = sk as Dictionary
		var key: String = "%s/%s" % [str(sd.get("class_id", "")), str(sd.get("ability_id", ""))]
		var team: int = int(sd.get("team", GameEnums.Team.PLAYER))
		var store_key: String = "%d:%s" % [team, key]
		if not skill_store.has(store_key):
			skill_store[store_key] = {
				"class_id": sd.get("class_id", ""),
				"ability_id": sd.get("ability_id", ""),
				"display_name": sd.get("display_name", key),
				"team": team,
				"uses": 0,
				"turns_legal": 0,
				"damage_dealt": 0,
				"healing_done": 0,
				"armor_given": 0,
				"kills": 0,
				"action_failed": 0,
				"class_unit_turns": 0,
			}
		var rec: Dictionary = skill_store[store_key] as Dictionary
		for field: String in ["uses", "turns_legal", "damage_dealt", "healing_done", "armor_given", "kills", "action_failed", "class_unit_turns"]:
			rec[field] = int(rec.get(field, 0)) + int(sd.get(field, 0))
	for cr: Variant in combat_meta.get("class_combat_rows", []):
		if not cr is Dictionary:
			continue
		var cd: Dictionary = cr as Dictionary
		var class_id: String = str(cd.get("class_id", ""))
		var team: int = int(cd.get("team", GameEnums.Team.PLAYER))
		if class_id.is_empty():
			continue
		var class_key: String = "%d:%s" % [team, class_id]
		if not class_store.has(class_key):
			class_store[class_key] = {
				"class_id": class_id,
				"team": team,
				"unit_turns": 0,
				"damage_dealt": 0,
				"damage_taken": 0,
				"healing_done": 0,
				"kills": 0,
				"deaths": 0,
				"ai_holds": 0,
				"ai_skill_opportunity_turns": 0,
				"movement_only_turns": 0,
				"floated_ap_turns": 0,
			}
		var crec: Dictionary = class_store[class_key] as Dictionary
		for field: String in ["unit_turns", "damage_dealt", "damage_taken", "healing_done", "kills", "deaths", "ai_holds", "ai_skill_opportunity_turns", "movement_only_turns", "floated_ap_turns"]:
			crec[field] = int(crec.get(field, 0)) + int(cd.get(field, 0))
	var ai: Dictionary = combat_meta.get("ai_commander", {}) as Dictionary
	if not ai.is_empty():
		ai_store["utility_sum"] = float(ai_store.get("utility_sum", 0.0)) + float(ai.get("avg_utility_per_turn", 0.0)) * float(ai.get("sample_turns", 0))
		ai_store["sample_turns"] = int(ai_store.get("sample_turns", 0)) + int(ai.get("sample_turns", 0))
		ai_store["total_holds"] = int(ai_store.get("total_holds", 0)) + int(ai.get("total_holds", 0))
		ai_store["total_skill_commits"] = int(ai_store.get("total_skill_commits", 0)) + int(ai.get("total_skill_commits", 0))
		ai_store["pruned_turns"] = int(ai_store.get("pruned_turns", 0)) + int(ai.get("pruned_turns", 0))


static func _finalize_skill_meta(skill_store: Dictionary, class_store: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for key: Variant in skill_store.keys():
		var rec: Dictionary = (skill_store[key] as Dictionary).duplicate(true)
		var class_id: String = String(rec.get("class_id", ""))
		var team: int = int(rec.get("team", GameEnums.Team.PLAYER))
		var class_key: String = "%d:%s" % [team, class_id]
		var unit_turns: int = int(rec.get("class_unit_turns", 0))
		if unit_turns <= 0 and class_store.has(class_key):
			unit_turns = int((class_store[class_key] as Dictionary).get("unit_turns", 0))
		unit_turns = maxi(unit_turns, 1)
		rec["uses_per_turn"] = float(rec.get("uses", 0)) / float(unit_turns)
		rec["damage_per_turn"] = float(rec.get("damage_dealt", 0)) / float(unit_turns)
		rec["heal_per_turn"] = float(rec.get("healing_done", 0)) / float(unit_turns)
		rec["kills_per_turn"] = float(rec.get("kills", 0)) / float(unit_turns)
		var legal: int = int(rec.get("turns_legal", 0))
		if team == GameEnums.Team.PLAYER and legal > 0:
			rec["pick_rate_when_legal_pct"] = minf(
				float(rec.get("uses", 0)) / float(legal) * 100.0,
				100.0,
			)
		else:
			rec["pick_rate_when_legal_pct"] = -1.0
		rows.append(rec)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("uses_per_turn", 0)) > float(b.get("uses_per_turn", 0))
	)
	return rows


static func _finalize_class_combat(class_store: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for class_key: Variant in class_store.keys():
		var rec: Dictionary = (class_store[class_key] as Dictionary).duplicate(true)
		var ut: int = int(rec.get("unit_turns", 1))
		rec["damage_dealt_per_turn"] = float(rec.get("damage_dealt", 0)) / float(maxi(ut, 1))
		rec["damage_taken_per_turn"] = float(rec.get("damage_taken", 0)) / float(maxi(ut, 1))
		rec["healing_per_turn"] = float(rec.get("healing_done", 0)) / float(maxi(ut, 1))
		rec["kills_per_turn"] = float(rec.get("kills", 0)) / float(maxi(ut, 1))
		rec["deaths_per_turn"] = float(rec.get("deaths", 0)) / float(maxi(ut, 1))
		var opp: int = int(rec.get("ai_skill_opportunity_turns", 0))
		rec["ai_hold_rate_pct"] = float(rec.get("ai_holds", 0)) / float(maxi(opp, 1)) * 100.0
		rows.append(rec)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("damage_dealt_per_turn", 0)) > float(b.get("damage_dealt_per_turn", 0))
	)
	return rows


static func _merge_passive_meta(passive_store: Dictionary, row: Dictionary, player_won: bool) -> void:
	for entry: Variant in row.get("roster_meta", []):
		if not entry is Dictionary:
			continue
		var ed: Dictionary = entry as Dictionary
		if int(ed.get("team", -1)) != GameEnums.Team.PLAYER:
			continue
		var class_id: String = String(ed.get("class_id", ""))
		for pid: Variant in ed.get("passive_ids", []):
			var passive_id: String = str(pid)
			if passive_id.is_empty():
				continue
			if not passive_store.has(passive_id):
				passive_store[passive_id] = {
					"passive_id": passive_id,
					"unit_appearances": 0,
					"player_wins": 0,
					"classes": {},
				}
			var pr: Dictionary = passive_store[passive_id] as Dictionary
			pr["unit_appearances"] = int(pr.get("unit_appearances", 0)) + 1
			if player_won:
				pr["player_wins"] = int(pr.get("player_wins", 0)) + 1
			var classes: Dictionary = pr.get("classes", {}) as Dictionary
			classes[class_id] = int(classes.get(class_id, 0)) + 1
			pr["classes"] = classes


static func _finalize_passive_meta(passive_store: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for pid: Variant in passive_store.keys():
		var rec: Dictionary = (passive_store[pid] as Dictionary).duplicate(true)
		var apps: int = int(rec.get("unit_appearances", 0))
		rec["player_win_pct"] = float(rec.get("player_wins", 0)) / float(maxi(apps, 1)) * 100.0
		rows.append(rec)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("unit_appearances", 0)) > int(b.get("unit_appearances", 0))
	)
	return rows


static func _finalize_economy_per_turn(report: RefCounted) -> Dictionary:
	var turns: int = maxi(int(report.total_sim_turns), 1)
	var battles: int = maxi(int(report.total_battles), 1)
	return {
		"assisted_damage_per_turn": float(report.total_assisted_damage) / float(turns),
		"assisted_shields_per_turn": float(report.total_assisted_shields) / float(turns),
		"overkill_per_turn": float(report.total_overkill) / float(turns),
		"floated_ap_per_turn": float(report.total_floated_ap) / float(turns),
		"whiff_battle_pct": float(report.battles_with_whiffs) / float(battles) * 100.0,
		"total_sim_turns": turns,
	}


static func _finalize_ai_commander(ai_store: Dictionary, total_sim_turns: int) -> Dictionary:
	var sample_turns: int = int(ai_store.get("sample_turns", 0))
	if sample_turns <= 0:
		return {}
	return {
		"avg_utility_per_turn": float(ai_store.get("utility_sum", 0.0)) / float(sample_turns),
		"holds_per_turn": float(ai_store.get("total_holds", 0)) / float(maxi(total_sim_turns, 1)),
		"skill_commits_per_turn": float(ai_store.get("total_skill_commits", 0)) / float(maxi(total_sim_turns, 1)),
		"total_holds": int(ai_store.get("total_holds", 0)),
		"total_skill_commits": int(ai_store.get("total_skill_commits", 0)),
		"pruned_turns": int(ai_store.get("pruned_turns", 0)),
		"battles_with_meta": int(ai_store.get("battles_with_meta", 0)),
		"sample_turns": sample_turns,
	}
