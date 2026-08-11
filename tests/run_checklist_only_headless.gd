extends SceneTree

const _Checklist := preload("res://tests/planning_t3_live_headless_checklist_test.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var drag: GDScript = load("res://tests/planning_drag_e2e_harness.gd") as GDScript
	var host := Node.new()
	host.name = "ChecklistOnlyHost"
	root.add_child(host)
	drag.set_host(host)
	_Checklist.run_all(failures)
	drag.cleanup_all()
	drag.set_host(null)
	host.queue_free()
	if failures.is_empty():
		print("[PASS] t3_live_headless_checklist only")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
