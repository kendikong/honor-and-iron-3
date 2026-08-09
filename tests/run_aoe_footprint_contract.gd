extends SceneTree

## AOE footprint contract — headless CLI entry.
## Run: godot --headless --path <repo> --script res://tests/run_aoe_footprint_contract.gd
## Scene gate (F5): res://tests/AoeFootprintQaGate.tscn → aoe_footprint_qa_gate_host.gd

const _SUITE := preload("res://tests/aoe_footprint_contract_suite.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	_SUITE.run(failures)
	if failures.is_empty():
		print("[PASS] AOE footprint contract")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
