extends SceneTree

## Headless entry for typed module/layer editor schema round-trip coverage.


func _initialize() -> void:
	print("SCHEMA_TYPED_FIELDS: START")
	var failures: Array[String] = []
	var test_script: Script = load("res://tests/class_library_schema_typed_fields_test.gd") as Script
	test_script.call("run_all", failures)
	print("SCHEMA_TYPED_FIELDS: checks=%d" % failures.size())
	for failure: String in failures:
		print("[FAIL] %s" % failure)
	if failures.is_empty():
		print("[PASS] typed class-library schema roundtrip")
	quit(0 if failures.is_empty() else 1)
