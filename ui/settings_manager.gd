extends Node

## Boot-time settings loader — delegates to GameSettings (single source of truth).


func _ready() -> void:
	load_settings()
	var tree := get_tree()
	if not tree.scene_changed.is_connected(_on_scene_changed):
		tree.scene_changed.connect(_on_scene_changed)


func _on_scene_changed() -> void:
	_persist_window_placement()


func load_settings() -> void:
	var settings := GameSettings.new()
	settings.load_from_disk()
	settings.apply_to_window(get_window())
	settings.apply_audio_buses()


func save_settings(_w: int, _h: int, _fs: bool) -> void:
	# Legacy API — display prefs live in GameSettings only.
	_persist_window_placement()


func _persist_window_placement() -> void:
	var window: Window = get_window()
	if window == null:
		return
	var settings := GameSettings.new()
	settings.load_from_disk()
	settings.capture_placement_from_window(window)
	settings.save_to_disk()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_persist_window_placement()
