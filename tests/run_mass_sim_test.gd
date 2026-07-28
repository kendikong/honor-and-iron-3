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
	_test_interpretation_export(agg, triage, failures)
	_test_epoch_filter(failures)
	_test_skirmish_setup(failures)


func _test_skirmish_setup(failures: Array[String]) -> void:
	var setup_script = load("res://core/batch/mass_sim_skirmish_setup.gd")
	var epoch_script = load("res://core/batch/mass_sim_rules_epoch.gd")
	var s = setup_script.defaults()
	s.player_count = 99
	s.clamp()
	if s.player_count > 8:
		failures.append("skirmish setup should clamp player count")
	s.player_class_skill_count = -1
	var fp: String = epoch_script.fingerprint(s)
	if not fp.contains("p8"):
		failures.append("fingerprint should encode player count")


func _test_epoch_filter(failures: Array[String]) -> void:
	var epoch_script = load("res://core/batch/mass_sim_rules_epoch.gd")
	var rows: Array = [
		{"run_id": 0, "rules_epoch_id": "epoch_a"},
		{"run_id": 1},
		{"run_id": 2, "rules_epoch_id": "epoch_b"},
	]
	var only_a: Array = epoch_script.filter_epoch_rows(rows, "epoch_a")
	if only_a.size() != 1:
		failures.append("epoch filter should keep one tagged row")
	var legacy: Array = epoch_script.filter_epoch_rows(rows, epoch_script.LEGACY_EPOCH_ID)
	if legacy.size() != 1:
		failures.append("legacy epoch filter should keep untagged row")
	var mix: Dictionary = epoch_script.analyze_mix(rows)
	if not bool(mix.get("is_mixed", false)):
		failures.append("analyze_mix should detect mixed epochs")
	var dated: Dictionary = {
		"id": "knight_buff_2026-07-27_123456",
		"label": "Knight buff",
		"created_at": 0,
	}
	if not epoch_script.display_label(dated, false).begins_with("Jul 27, 2026"):
		failures.append("epoch display_label should include parsed date")
	var setup_script = load("res://core/batch/mass_sim_skirmish_setup.gd")
	var unit_cfg = load("res://core/batch/mass_sim_unit_config.gd")
	var seed_script = load("res://core/batch/mass_sim_seed.gd")
	var knight = DataLibrary.get_unit(&"knight")
	var s = setup_script.defaults()
	s.player_class_skill_count = 3
	var a = unit_cfg.build(knight, GameEnums.Team.PLAYER, seed_script.battle_seed(1, 10), 0, s, 10)
	var b = unit_cfg.build(knight, GameEnums.Team.PLAYER, seed_script.battle_seed(1, 11), 0, s, 11)
	var ids_a: Array = (a.get("active_abilities", []) as Array).map(func(ab: AbilityData) -> String: return str(ab.id))
	var ids_b: Array = (b.get("active_abilities", []) as Array).map(func(ab: AbilityData) -> String: return str(ab.id))
	if ids_a == ids_b:
		failures.append("unit skill rolls should vary per battle run_id")


func _test_interpretation_export(agg, triage, failures: Array[String]) -> void:
	var rows: Array[Dictionary] = [{
		"run_id": 0,
		"winner": GameEnums.Team.PLAYER,
		"turns_taken": 10,
		"map_tags": ["open"],
		"player_classes": ["knight"],
		"wall_collisions": 2,
		"collision_cells": ["1,1"],
		"player_spawn_quadrant": "northwest",
	}]
	var report = agg.build_report(rows)
	var warnings: Array = triage.evaluate_report(report)
	var export_script = load("res://core/batch/mass_sim_interpretation_export.gd")
	var bundle: Dictionary = export_script.build(report, warnings, {"test": true})
	if not bundle.has("l1_executive"):
		failures.append("interpretation bundle missing l1_executive")
	if not bundle.has("l7_integrity"):
		failures.append("interpretation bundle missing l7_integrity")


func _test_filter_and_heatmap(agg, failures: Array[String]) -> void:
	var rows: Array[Dictionary] = [
		{
			"run_id": 0, "winner": GameEnums.Team.PLAYER, "turns_taken": 10,
			"map_tags": ["open"], "player_spawn_quadrant": "northwest", "collision_cells": ["5,5"],
			"combat_meta": {
				"total_turns": 10,
				"skill_rows": [{"class_id": "knight", "ability_id": "knight_shield_bash", "display_name": "Shield Bash", "team": GameEnums.Team.PLAYER, "uses": 2, "turns_legal": 4, "class_unit_turns": 10, "damage_dealt": 5, "kills": 1}],
				"class_combat_rows": [{
					"class_id": "knight", "team": GameEnums.Team.PLAYER, "unit_turns": 10,
					"damage_dealt": 5, "hp_damage_taken": 12, "damage_mitigated": 3,
					"lifespan_turns_sum": 40, "lifespan_samples": 4, "end_hp_pct_sum": 220.0,
					"end_hp_pct_samples": 4, "ai_holds": 1, "ai_skill_opportunity_turns": 3,
				}],
				"ai_commander": {"avg_utility_per_turn": 3.0, "sample_turns": 10, "total_holds": 1, "total_skill_commits": 2},
			},
		},
		{"run_id": 1, "winner": GameEnums.Team.ENEMY, "turns_taken": 12, "map_tags": ["narrow"], "player_spawn_quadrant": "southeast", "collision_cells": ["5,5", "6,6"]},
	]
	var filtered: Array = agg.filter_rows(rows, "open")
	if filtered.size() != 1:
		failures.append("map tag filter should keep one row")
	var report = agg.build_report(rows)
	if int(report.collision_heatmap.get("5,5", 0)) != 2:
		failures.append("heatmap should aggregate collision cells")
	if report.skill_meta_rows.is_empty():
		failures.append("skill meta should aggregate from combat_meta")
	if report.class_combat_rows.is_empty():
		failures.append("class combat should aggregate from combat_meta")
	var knight_row: Dictionary = report.class_combat_rows[0]
	if float(knight_row.get("avg_survival_turns", 0.0)) < 9.9:
		failures.append("class combat should finalize avg survival turns")
	if int(report.spawn_quadrant_records.get("northwest", {}).get("battles", 0)) != 1:
		failures.append("spawn quadrant aggregation failed")


func _test_wilson(report_script, failures: Array[String]) -> void:
	var report = report_script.new()
	var margin: float = report.wilson_margin(5, 10)
	if margin <= 0.0 or margin > 50.0:
		failures.append("wilson margin out of expected range")
