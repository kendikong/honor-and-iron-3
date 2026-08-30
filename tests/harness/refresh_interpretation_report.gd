extends SceneTree

const _Export = preload("res://core/batch/mass_sim_interpretation_export.gd")
const _Agg = preload("res://core/batch/mass_sim_aggregator.gd")
const _Triage = preload("res://core/batch/triage_engine.gd")
const _C = preload("res://core/batch/mass_sim_constants.gd")


func _initialize() -> void:
	var log_path: String = _C.DEFAULT_LOG_PATH
	var rows: Array[Dictionary] = _Agg.load_jsonl(log_path)
	var report = _Agg.build_report(rows, log_path, {})
	var warnings: Array = _Triage.evaluate_report(report)
	_Export.write_bundle(report, warnings, {
		"trigger": "refresh_interpretation_script",
		"rows_in_file": rows.size(),
	})
	quit(0)
