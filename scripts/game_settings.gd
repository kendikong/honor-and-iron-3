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
	"Fullscreen (Borderless Window)",
	"Exclusive Fullscreen",
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
var combat_ui_scale: float = 1.0
var combat_text_scale: float = 1.0
var show_fps_hud: bool = true
var show_time_of_day_hud: bool = true
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var show_damage_numbers: bool = true
var dev_tile_labels: bool = false
var dev_boredom_atmosphere: bool = false
var dev_boredom_water: bool = false
var planning_force_basic: bool = false
var planning_auto_run: bool = false
var planning_danger_area: bool = false
var planning_auto_use_skill_after_move: bool = true
var screen_index: int = 0
var window_position: Vector2i = Vector2i.ZERO
var _has_saved_window_placement: bool = false


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
	combat_ui_scale = float(cfg.get_value("display", "combat_ui_scale", combat_ui_scale))
	combat_text_scale = float(cfg.get_value("display", "combat_text_scale", combat_text_scale))
	show_fps_hud = bool(cfg.get_value("interface", "show_fps_hud", show_fps_hud))
	show_time_of_day_hud = bool(cfg.get_value("interface", "show_time_of_day_hud", show_time_of_day_hud))
	master_volume = float(cfg.get_value("audio", "master_volume", master_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", sfx_volume))
	music_volume = float(cfg.get_value("audio", "music_volume", music_volume))
	show_damage_numbers = bool(cfg.get_value("interface", "show_damage_numbers", show_damage_numbers))
	dev_tile_labels = bool(cfg.get_value("developer", "tile_labels", dev_tile_labels))
	dev_boredom_atmosphere = bool(cfg.get_value("developer", "boredom_atmosphere", dev_boredom_atmosphere))
	dev_boredom_water = bool(cfg.get_value("developer", "boredom_water", dev_boredom_water))
	planning_force_basic = bool(cfg.get_value("planning", "force_basic_movement", planning_force_basic))
	planning_auto_run = bool(cfg.get_value("planning", "auto_run", planning_auto_run))
	planning_danger_area = bool(cfg.get_value("planning", "danger_area", planning_danger_area))
	planning_auto_use_skill_after_move = bool(
		cfg.get_value("planning", "auto_use_skill_after_move", planning_auto_use_skill_after_move),
	)
	if cfg.has_section_key("display", "screen_index"):
		screen_index = int(cfg.get_value("display", "screen_index", screen_index))
		window_position = Vector2i(
			int(cfg.get_value("display", "window_position_x", window_position.x)),
			int(cfg.get_value("display", "window_position_y", window_position.y)),
		)
		_has_saved_window_placement = true


func capture_from_window(window: Window) -> void:
	window_mode = DisplayServer.window_get_mode()
	if window != null:
		screen_index = window.current_screen
	else:
		screen_index = DisplayServer.window_get_current_screen()
	if window_mode == DisplayServer.WINDOW_MODE_WINDOWED and window != null:
		resolution = window.size
		window_position = window.position
		_has_saved_window_placement = true


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
	cfg.set_value("display", "combat_ui_scale", combat_ui_scale)
	cfg.set_value("display", "combat_text_scale", combat_text_scale)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("interface", "show_damage_numbers", show_damage_numbers)
	cfg.set_value("interface", "show_fps_hud", show_fps_hud)
	cfg.set_value("interface", "show_time_of_day_hud", show_time_of_day_hud)
	cfg.set_value("developer", "tile_labels", dev_tile_labels)
	cfg.set_value("developer", "boredom_atmosphere", dev_boredom_atmosphere)
	cfg.set_value("developer", "boredom_water", dev_boredom_water)
	cfg.set_value("planning", "force_basic_movement", planning_force_basic)
	cfg.set_value("planning", "auto_run", planning_auto_run)
	cfg.set_value("planning", "danger_area", planning_danger_area)
	cfg.set_value("planning", "auto_use_skill_after_move", planning_auto_use_skill_after_move)
	cfg.set_value("display", "screen_index", screen_index)
	cfg.set_value("display", "window_position_x", window_position.x)
	cfg.set_value("display", "window_position_y", window_position.y)
	cfg.save(CONFIG_PATH)


func apply_to_window(window: Window, preserve_center_on_resize: bool = false) -> void:
	var screen_id: int = _validated_screen_index(screen_index)

	match window_mode:
		DisplayServer.WINDOW_MODE_WINDOWED:
			if preserve_center_on_resize:
				DisplayWindowHelper.apply_resolution(
					window,
					resolution,
					false,
					screen_id,
					true,
				)
			elif _has_saved_window_placement:
				window.mode = Window.MODE_WINDOWED
				window.current_screen = screen_id
				window.size = resolution
				window.position = DisplayWindowHelper.clamp_to_usable_rect(
					window_position,
					resolution,
					screen_id,
				)
			else:
				DisplayWindowHelper.apply_resolution(
					window,
					resolution,
					false,
					screen_id,
					false,
				)
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			if screen_id >= 0:
				window.current_screen = screen_id
			window.mode = Window.MODE_FULLSCREEN
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			if screen_id >= 0:
				window.current_screen = screen_id
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN


func _validated_screen_index(preferred: int) -> int:
	var count: int = DisplayServer.get_screen_count()
	if preferred >= 0 and preferred < count:
		return preferred
	return DisplayServer.get_primary_screen()


func resolution_index_for(size: Vector2i) -> int:
	for i: int in range(RESOLUTION_PRESETS.size()):
		if RESOLUTION_PRESETS[i] == size:
			return i
	var best_index: int = 0
	var best_dist: int = 0x7FFFFFFF
	for i: int in range(RESOLUTION_PRESETS.size()):
		var preset: Vector2i = RESOLUTION_PRESETS[i]
		var dist: int = absi(preset.x - size.x) + absi(preset.y - size.y)
		if dist < best_dist:
			best_dist = dist
			best_index = i
	return best_index


func resolution_index() -> int:
	return resolution_index_for(resolution)


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


func scaled_body_font() -> int:
	return int(round(float(inspector_body_font()) * combat_text_scale))


func scaled_title_font() -> int:
	return int(round(float(inspector_title_font()) * combat_text_scale))


func scaled_hint_font() -> int:
	return int(round(float(inspector_hint_font()) * combat_text_scale))


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


func apply_and_save(window: Window, preserve_center_on_resize: bool = false) -> void:
	apply_to_window(window, preserve_center_on_resize)
	apply_audio_buses()
	save_to_disk()
	changed.emit()


func apply_audio_buses() -> void:
	_ensure_audio_bus(&"SFX", &"Master")
	_ensure_audio_bus(&"Music", &"Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Master"), _volume_db(master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), _volume_db(sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), _volume_db(music_volume))


static func _ensure_audio_bus(bus_name: StringName, send_to: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send_to)


static func _volume_db(linear: float) -> float:
	var clamped: float = clampf(linear, 0.0, 1.0)
	if clamped <= 0.001:
		return -80.0
	return linear_to_db(clamped)
