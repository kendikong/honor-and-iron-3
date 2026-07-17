extends Node

## Boot-time settings loader — delegates to GameSettings (single source of truth).


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var settings := GameSettings.new()
	settings.load_from_disk()
	settings.apply_to_window(get_window(), true)
	settings.apply_audio_buses()


func save_settings(_w: int, _h: int, _fs: bool) -> void:
	# Legacy API — display prefs live in GameSettings only.
	var settings := GameSettings.new()
	settings.load_from_disk()
	settings.capture_from_window(get_window())
	settings.save_to_disk()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var settings := GameSettings.new()
		settings.load_from_disk()
		settings.capture_from_window(get_window())
		settings.save_to_disk()
