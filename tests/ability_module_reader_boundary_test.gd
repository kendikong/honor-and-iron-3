class_name AbilityModuleReaderBoundaryTest
extends RefCounted

## Machine-checked boundary: production runtime has no flat-effect compatibility reader.

const SCRIPT_ROOTS: Array[String] = [
	"res://core",
	"res://data",
	"res://presentation",
	"res://ui",
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
	for forbidden: String in [
		"compatibility_effects_for(",
		"legacy_effects_for(",
		"infer_modules_from_effects(",
		"compile_modules_for_runtime(",
		"migrate_editor_save_to_modules(",
	]:
		if source.find(forbidden) >= 0:
			failures.append("removed flat-effect bridge API remains in %s: %s" % [path, forbidden])


static func _collect_scripts(root: String, output: Array[String]) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		if file_name.ends_with(".gd"):
			output.append(root.path_join(file_name))
	for directory_name: String in directory.get_directories():
		_collect_scripts(root.path_join(directory_name), output)
