extends SceneTree

## Layer-shape conversion gate (ER-2 anti-cheat).
## Default: LAYER_MANDATE — fails when CONVERTED_SKILL_IDS skills still use layer-mandate typed extras.
##
## Run:
##   godot --headless --path . --script res://tests/run_layer_shape_conversion_gate.gd
## Audit only (print report, never fail):
##   godot --headless --path . --script res://tests/run_layer_shape_conversion_gate.gd -- --audit

const _GateScript: Script = preload("res://tests/layer_shape_conversion_gate_test.gd")


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	var audit_only: bool = "--audit" in args
	var class_prefix: String = ""
	var class_idx: int = args.find("--class")
	if class_idx >= 0 and class_idx + 1 < args.size():
		class_prefix = String(args[class_idx + 1]).to_lower()
	print("LAYER_SHAPE_GATE: START mode=%s class=%s" % [
		"audit" if audit_only else "layer_mandate",
		class_prefix if not class_prefix.is_empty() else "all",
	])
	var failures: Array[String] = []
	if audit_only:
		_GateScript.call("run_audit_only", failures)
		print("[PASS] layer shape audit report")
		quit(0)
		return
	else:
		_GateScript.call("run_all", failures, -1, class_prefix)
	print("LAYER_SHAPE_GATE: checks=%d" % failures.size())
	for failure: String in failures:
		print("[FAIL] %s" % failure)
	if failures.is_empty():
		print("[PASS] layer shape conversion gate")
	quit(0 if failures.is_empty() else 1)
