class_name DisplayWindowHelper
extends RefCounted

## Applies window size / fullscreen consistently (main menu + in-game options).


static func apply_resolution(
	window: Window,
	resolution: Vector2i,
	fullscreen: bool,
	center: bool = true,
) -> void:
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return
	window.mode = Window.MODE_WINDOWED
	window.size = resolution
	if not center:
		return
	var screen_id: int = window.current_screen
	if screen_id < 0:
		return
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	window.position = (screen_size - resolution) / 2
