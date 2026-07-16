class_name GameSettings
extends RefCounted

## Persisted display preferences (user://game_settings.cfg).

signal changed

const CONFIG_PATH: String = "user://game_settings.cfg"

enum MapZoomMode {
	FIT_VIEWPORT,
	FIXED_REFERENCE,
}

const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3200, 1800),
	Vector2i(3840, 1800),
	Vector2i(3840, 2160),
]

const WINDOW_MODE_LABELS: PackedStringArray = [
	"Windowed",
	"Fullscreen",
	"Borderless fullscreen",
]

const MAP_ZOOM_LABELS: PackedStringArray = [
	"Fit map to window",
	"Fixed reference (1280×720 base)",
]

const TEXT_SIZE_LABELS: PackedStringArray = ["Small", "Medium", "Large"]

const TEXT_SIZE_BODY: PackedInt32Array = [16, 20, 24]
const TEXT_SIZE_TITLE: PackedInt32Array = [22, 26, 30]
const TEXT_SIZE_HINT: PackedInt32Array = [13, 17, 20]

var resolution: Vector2i = Vector2i(3840, 1800)
var window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
var map_zoom_mode: MapZoomMode = MapZoomMode.FIXED_REFERENCE
var map_zoom_reference: Vector2 = Vector2(1280.0, 720.0)
var map_zoom_multiplier: float = 1.0
var inspector_text_size_index: int = 1
var inspector_panel_width: int = 520


func load_from_disk() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	resolution = Vector2i(
		int(cfg.get_value("display", "resolution_width", resolution.x)),
		int(cfg.get_value("display", "resolution_height", resolution.y)),
	)
	window_mode = int(cfg.get_value("display", "window_mode", window_mode)) as DisplayServer.WindowMode
	map_zoom_mode = int(cfg.get_value("display", "map_zoom_mode", map_zoom_mode)) as MapZoomMode
	map_zoom_reference = Vector2(
		float(cfg.get_value("display", "map_zoom_reference_w", map_zoom_reference.x)),
		float(cfg.get_value("display", "map_zoom_reference_h", map_zoom_reference.y)),
	)
	map_zoom_multiplier = float(cfg.get_value("display", "map_zoom_multiplier", map_zoom_multiplier))
	inspector_text_size_index = int(cfg.get_value("display", "inspector_text_size_index", inspector_text_size_index))
	inspector_panel_width = int(cfg.get_value("display", "inspector_panel_width", inspector_panel_width))


func capture_from_window(window: Window) -> void:
	window_mode = DisplayServer.window_get_mode()
	if window_mode == DisplayServer.WINDOW_MODE_WINDOWED and window != null:
		resolution = window.size


func save_to_disk() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(CONFIG_PATH):
		cfg.load(CONFIG_PATH)
	cfg.set_value("display", "resolution_width", resolution.x)
	cfg.set_value("display", "resolution_height", resolution.y)
	cfg.set_value("display", "window_mode", int(window_mode))
	cfg.set_value("display", "map_zoom_mode", int(map_zoom_mode))
	cfg.set_value("display", "map_zoom_reference_w", map_zoom_reference.x)
	cfg.set_value("display", "map_zoom_reference_h", map_zoom_reference.y)
	cfg.set_value("display", "map_zoom_multiplier", map_zoom_multiplier)
	cfg.set_value("display", "inspector_text_size_index", inspector_text_size_index)
	cfg.set_value("display", "inspector_panel_width", inspector_panel_width)
	cfg.save(CONFIG_PATH)


func apply_to_window(window: Window) -> void:
	DisplayServer.window_set_mode(window_mode)
	if window_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		window.size = resolution
		var screen: Vector2i = DisplayServer.screen_get_size()
		window.position = (screen - resolution) / 2


func resolution_index() -> int:
	for i: int in range(RESOLUTION_PRESETS.size()):
		if RESOLUTION_PRESETS[i] == resolution:
			return i
	return 4


func set_resolution_index(index: int) -> void:
	index = clampi(index, 0, RESOLUTION_PRESETS.size() - 1)
	resolution = RESOLUTION_PRESETS[index]


func window_mode_index() -> int:
	match window_mode:
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			return 1
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return 2
		_:
			return 0


func set_window_mode_index(index: int) -> void:
	match clampi(index, 0, 2):
		1:
			window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		2:
			window_mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		_:
			window_mode = DisplayServer.WINDOW_MODE_WINDOWED


func inspector_body_font() -> int:
	return TEXT_SIZE_BODY[clampi(inspector_text_size_index, 0, TEXT_SIZE_BODY.size() - 1)]


func inspector_title_font() -> int:
	return TEXT_SIZE_TITLE[clampi(inspector_text_size_index, 0, TEXT_SIZE_TITLE.size() - 1)]


func inspector_hint_font() -> int:
	return TEXT_SIZE_HINT[clampi(inspector_text_size_index, 0, TEXT_SIZE_HINT.size() - 1)]


func map_zoom_viewport_size(viewport_size: Vector2, inspector_width: float, effects_width: float = 0.0) -> Vector2:
	var chrome_x: float = inspector_width + effects_width
	match map_zoom_mode:
		MapZoomMode.FIT_VIEWPORT:
			return Vector2(viewport_size.x - chrome_x, viewport_size.y)
		_:
			return Vector2(map_zoom_reference.x - chrome_x, map_zoom_reference.y)


func compute_map_zoom(map_pixels: Vector2, zoom_viewport: Vector2) -> int:
	if map_pixels.x <= 0.0 or map_pixels.y <= 0.0:
		return 1
	var fit: int = mini(
		int(floor(zoom_viewport.x / map_pixels.x)),
		int(floor(zoom_viewport.y / map_pixels.y)),
	)
	var scaled: int = int(floor(float(maxi(1, fit)) * clampf(map_zoom_multiplier, 0.5, 4.0)))
	return maxi(1, scaled)


func apply_and_save(window: Window) -> void:
	apply_to_window(window)
	save_to_disk()
	changed.emit()
