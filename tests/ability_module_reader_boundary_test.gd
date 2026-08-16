class_name AbilityModuleReaderBoundaryTest
extends RefCounted

## Machine-checked AD-2 boundary for the transitional flat-effect reader.
## Compatibility readers are explicitly enumerated; modular runtime code is not
## allowed to add a new call site without updating this contract.

const ALLOWED_COMPATIBILITY_READERS: Dictionary = {
	"res://core/systems/ability_system.gd": {
		"legacy_effects_for": 1,
	},
	"res://presentation/combat_ui_formatters.gd": {
		"_ability_keyword_tooltip_lines": 1,
		"ability_effect_string": 1,
		"ability_effect_bbcode": 1,
	},
	"res://tests/ability_module_runtime_test.gd": {
		"_test_module_only_execution": 2,
		"_test_base_multi_module_compatibility_order": 1,
		"_test_upgraded_module_profile": 1,
		"_test_if_collided_follow_up": 1,
	},
}

const SCRIPT_ROOTS: Array[String] = [
	"res://core",
	"res://data",
	"res://presentation",
	"res://ui",
	"res://tests",
]


static func run_all(failures: Array[String]) -> void:
	var scripts: Array[String] = []
	for root: String in SCRIPT_ROOTS:
		_collect_scripts(root, scripts)
	scripts.sort()
	for path: String in scripts:
		_check_script(path, failures)


static func _check_script(path: String, failures: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		failures.append("compatibility reader boundary could not read %s" % path)
		return
	var source: String = file.get_as_text()
	var forbidden_alias: String = "AbilitySystem.active_" + "effects_for("
	if source.find(forbidden_alias) >= 0:
		failures.append("unguarded active effects alias remains in %s" % path)
	var observed: Dictionary = _reader_counts(source)
	if observed.is_empty():
		return
	if not ALLOWED_COMPATIBILITY_READERS.has(path):
		failures.append("unlisted compatibility reader in %s: %s" % [path, observed])
		return
	var expected: Dictionary = ALLOWED_COMPATIBILITY_READERS[path]
	if observed != expected:
		failures.append(
			"compatibility reader allowlist drift in %s (expected %s, found %s)"
			% [path, expected, observed]
		)


static func _reader_counts(source: String) -> Dictionary:
	var token: String = "compatibility_" + "effects_for("
	var counts: Dictionary = {}
	var current_function: String = "<top-level>"
	for line: String in source.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("#"):
			continue
		if trimmed.begins_with("func ") or trimmed.begins_with("static func "):
			var declaration: String = trimmed.trim_prefix("static ").trim_prefix("func ")
			current_function = declaration.get_slice("(", 0)
			if current_function == "compatibility_effects_for":
				continue
		var call_count: int = line.count(token)
		if call_count > 0:
			counts[current_function] = int(counts.get(current_function, 0)) + call_count
	return counts


static func _collect_scripts(root: String, output: Array[String]) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		if file_name.ends_with(".gd"):
			output.append(root.path_join(file_name))
	for directory_name: String in directory.get_directories():
		_collect_scripts(root.path_join(directory_name), output)
