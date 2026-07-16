class_name MapCameraController
extends RefCounted

## Session camera for tactical and sandbox maps.
## - Hold middle mouse: pan when map exceeds viewport
## - Ctrl + scroll wheel: dynamic zoom multiplier (session-only until saved)

signal changed

var pan_offset: Vector2 = Vector2.ZERO
var dynamic_zoom_multiplier: float = 1.0

const ZOOM_STEP: float = 0.125
const DYNAMIC_ZOOM_MIN: float = 0.25
const DYNAMIC_ZOOM_MAX: float = 4.0


func reset_session() -> void:
	pan_offset = Vector2.ZERO
	dynamic_zoom_multiplier = 1.0
	changed.emit()


func handle_input(event: InputEvent, input_blocked: bool = false) -> bool:
	if input_blocked:
		return false
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			pan_offset += event.relative
			changed.emit()
			return true
	if event is InputEventMouseButton and event.pressed and event.ctrl_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_dynamic_zoom(ZOOM_STEP)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_dynamic_zoom(-ZOOM_STEP)
			return true
	return false


func _adjust_dynamic_zoom(delta: float) -> void:
	dynamic_zoom_multiplier = clampf(
		dynamic_zoom_multiplier + delta,
		DYNAMIC_ZOOM_MIN,
		DYNAMIC_ZOOM_MAX,
	)
	changed.emit()


## Returns layout dict: zoom, map_root_scale, scene_position, scaled_size, origin.
func compute_layout(
	settings: GameSettings,
	map_pixels: Vector2,
	viewport_size: Vector2,
	left_inset: float,
	right_inset: float,
	map_used_origin: Vector2i = Vector2i.ZERO,
) -> Dictionary:
	var zoom_viewport: Vector2 = settings.map_zoom_viewport_size(
		viewport_size, right_inset, left_inset,
	)
	var base_zoom: int = settings.compute_map_zoom(map_pixels, zoom_viewport)
	var zoom: int = maxi(1, int(floor(float(base_zoom) * dynamic_zoom_multiplier)))
	var scaled_size: Vector2 = map_pixels * float(zoom)
	var map_viewport: Vector2 = Vector2(
		viewport_size.x - left_inset - right_inset,
		viewport_size.y,
	)
	var origin: Vector2 = Vector2(left_inset, 0.0) + (map_viewport - scaled_size) * 0.5 + pan_offset
	var scene_position: Vector2 = origin - Vector2(map_used_origin) * float(TacticalConstants.TILE_PX * zoom)
	return {
		"zoom": zoom,
		"map_root_scale": Vector2(zoom, zoom),
		"scene_position": scene_position,
		"scaled_size": scaled_size,
		"origin": origin,
	}
