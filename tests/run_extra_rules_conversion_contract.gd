extends SceneTree

## Headless entry point for the fail-loud Extra Rules conversion bar.
## Run: godot --headless --path . -s res://tests/run_extra_rules_conversion_contract.gd


func _initialize() -> void:
	print("EXTRA_RULES_CONTRACT: START")
	DataLibrary.reset_cache()
	var failures: Array[String] = []
	var contract: Script = load("res://tests/extra_rules_conversion_contract.gd") as Script
	contract.call("run_all", failures)
	print("EXTRA_RULES_CONTRACT: checks=%d" % failures.size())
	for failure: String in failures:
		print("[FAIL] %s" % failure)
	if failures.is_empty():
		print("[PASS] Extra Rules conversion contract")
	quit(0 if failures.is_empty() else 1)
