class_name DisplayWindowHelper
extends RefCounted

## Applies window size / fullscreen consistently (main menu + in-game options).
## Multi-monitor: set current_screen before size, then position relative to that screen.


static func apply_resolution(
	window: Window,
	resolution: Vector2i,
	fullscreen: bool,
	lock_screen: int = -1,
	preserve_center_on_screen: bool = false,
) -> void:
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return

	var screen_id: int = lock_screen
	if screen_id < 0:
		screen_id = window.current_screen
	if screen_id < 0:
		screen_id = DisplayServer.window_get_current_screen()

	var screen_origin: Vector2i = DisplayServer.screen_get_position(screen_id)
	var center_on_screen: Vector2i = window.position + window.size / 2 - screen_origin

	window.mode = Window.MODE_WINDOWED
	window.current_screen = screen_id
	window.size = resolution

	var new_pos: Vector2i
	if preserve_center_on_screen:
		new_pos = screen_origin + center_on_screen - resolution / 2
	else:
		var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
		new_pos = screen_origin + (screen_size - resolution) / 2

	window.position = clamp_to_usable_rect(new_pos, resolution, screen_id)


static func clamp_to_usable_rect(pos: Vector2i, size: Vector2i, screen_id: int) -> Vector2i:
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen_id)
	var max_x: int = usable.position.x + maxi(0, usable.size.x - size.x)
	var max_y: int = usable.position.y + maxi(0, usable.size.y - size.y)
	return Vector2i(
		clampi(pos.x, usable.position.x, max_x),
		clampi(pos.y, usable.position.y, max_y),
	)
