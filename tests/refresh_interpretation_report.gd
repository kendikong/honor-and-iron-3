extends SceneTree

func _initialize() -> void:
	var log_path: String = MassSimConstants.DEFAULT_LOG_PATH
	var rows: Array[Dictionary] = MassSimAggregator.load_jsonl(log_path)
	var report: MassSimBatchReport = MassSimAggregator.build_report(rows, log_path, {})
	var warnings: Array = TriageEngine.evaluate_report(report)
	MassSimInterpretationExport.write_bundle(report, warnings, {
		"trigger": "refresh_interpretation_script",
		"rows_in_file": rows.size(),
	})
	quit(0)
