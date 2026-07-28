extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var agg = load("res://core/batch/mass_sim_aggregator.gd")
	var triage = load("res://core/batch/triage_engine.gd")
	_test_empty(agg, failures)
	_test_sample(agg, failures)
	_test_triage(triage, agg, failures)
	if failures.is_empty():
		print("[PASS] Mass sim analytics stack")
		quit(0)
	for f: String in failures:
		printerr("[FAIL] %s" % f)
	quit(1)


func _test_empty(agg, failures: Array[String]) -> void:
	var report = agg.build_report([])
	if report.total_battles != 0:
		failures.append("empty batch should have 0 battles")


func _test_sample(agg, failures: Array[String]) -> void:
	var rows: Array[Dictionary] = []
	for i: int in range(20):
		rows.append({
			"run_id": i,
			"winner": GameEnums.Team.PLAYER if i % 2 == 0 else GameEnums.Team.ENEMY,
			"turns_taken": 8 + (i % 5),
			"completion_reason": "victory",
			"player_classes": ["knight", "mage"],
			"enemy_classes": ["hatchling"],
			"map_tags": ["grass", "open"],
			"wall_collisions": i % 3,
			"execution_whiffs": 1 if i % 4 == 0 else 0,
			"assisted_damage": 10,
		})
	var report = agg.build_report(rows, "test://x.jsonl", {})
	if report.total_battles != 20:
		failures.append("expected 20 battles")
	if absf(report.player_win_pct - 50.0) > 0.1:
		failures.append("expected 50%% player WR")


func _test_triage(triage, agg, failures: Array[String]) -> void:
	var report = load("res://core/batch/mass_sim_batch_report.gd").new()
	var warnings: Array = triage.evaluate_report(report)
	if warnings.is_empty():
		failures.append("triage should warn on empty report")
	_test_filter_and_heatmap(agg, failures)
	_test_wilson(load("res://core/batch/mass_sim_batch_report.gd"), failures)


func _test_filter_and_heatmap(agg, failures: Array[String]) -> void:
	var rows: Array[Dictionary] = [
		{"run_id": 0, "winner": GameEnums.Team.PLAYER, "turns_taken": 10, "map_tags": ["open"], "player_spawn_quadrant": "northwest", "collision_cells": ["5,5"]},
		{"run_id": 1, "winner": GameEnums.Team.ENEMY, "turns_taken": 12, "map_tags": ["narrow"], "player_spawn_quadrant": "southeast", "collision_cells": ["5,5", "6,6"]},
	]
	var filtered: Array = agg.filter_rows(rows, "open")
	if filtered.size() != 1:
		failures.append("map tag filter should keep one row")
	var report = agg.build_report(rows)
	if int(report.collision_heatmap.get("5,5", 0)) != 2:
		failures.append("heatmap should aggregate collision cells")
	if int(report.spawn_quadrant_records.get("northwest", {}).get("battles", 0)) != 1:
		failures.append("spawn quadrant aggregation failed")


func _test_wilson(report_script, failures: Array[String]) -> void:
	var report = report_script.new()
	var margin: float = report.wilson_margin(5, 10)
	if margin <= 0.0 or margin > 50.0:
		failures.append("wilson margin out of expected range")
