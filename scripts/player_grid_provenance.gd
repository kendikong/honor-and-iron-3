class_name PlayerGridProvenance
extends RefCounted

## Per-cell history of why each PlayerGrid logical type exists (generator + repair).

var _steps: Dictionary = {}


func clear() -> void:
	_steps.clear()


func add_step(pos: Vector2i, step: String, tile_type: int, detail: String) -> void:
	var key: String = _key(pos)
	if not _steps.has(key):
		_steps[key] = [] as Array[Dictionary]
	(_steps[key] as Array).append({
		"step": step,
		"type": tile_type,
		"detail": detail,
	})


func get_steps(pos: Vector2i) -> Array:
	return _steps.get(_key(pos), [] as Array)


func has_steps(pos: Vector2i) -> bool:
	return _steps.has(_key(pos))


static func _key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]
