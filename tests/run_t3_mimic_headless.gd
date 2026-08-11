extends SceneTree

## Headless CLI runner for fixture parity (NOT Tier 3 LIVE TestBattle).
## Run: godot --headless --path <repo> --script res://tests/run_t3_mimic_headless.gd
## Scene gate: res://tests/T3MimicHeadless.tscn → t3_mimic_headless_host.gd


func _initialize() -> void:
	var failures: Array[String] = []
	var drag: GDScript = load("res://tests/planning_drag_e2e_harness.gd") as GDScript
	if drag == null:
		printerr("[FAIL] planning_drag_e2e_harness load failed")
		quit(1)
		return
	var runner: GDScript = load("res://tests/planning_t3_mimic_runner.gd") as GDScript
	if runner == null:
		printerr("[FAIL] planning_t3_mimic_runner load failed")
		quit(1)
		return
	var host := Node.new()
	host.name = "T3MimicHeadlessHost"
	root.add_child(host)
	drag.set_host(host)
	if not runner.has_method("run_all"):
		printerr("[FAIL] planning_t3_mimic_runner missing run_all")
		quit(1)
		return
	runner.run_all(failures)
	drag.cleanup_all()
	drag.set_host(null)
	host.queue_free()
	if failures.is_empty():
		print("[PASS] Fixture Parity Suite (action_range + intent + journeys + bible)")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
