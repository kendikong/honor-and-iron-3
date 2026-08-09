class_name ClassLibraryEditorModuleBoundaryTest
extends RefCounted

const EDITOR_PATH: String = "res://ui/class_library_editor.gd"


static func run_all(failures: Array[String]) -> void:
	var source: String = FileAccess.get_file_as_string(EDITOR_PATH)
	if source.is_empty():
		failures.append("class library editor source could not be read")
		return
	for forbidden: String in [
		"ability.kind =",
		"ability.is_movement_skill =",
		"ability.effects.clear()",
		"ability.upgraded_effects.clear()",
	]:
		if source.contains(forbidden):
			failures.append("class library editor still writes legacy field: %s" % forbidden)
