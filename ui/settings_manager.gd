extends Node

const SETTINGS_FILE = "user://settings.cfg"

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	var w: int = 3840
	var h: int = 1800
	var fs: bool = false
	var px: int = -1
	var py: int = -1
	if config.load(SETTINGS_FILE) == OK:
		w = int(config.get_value("video", "width", w))
		h = int(config.get_value("video", "height", h))
		fs = bool(config.get_value("video", "fullscreen", fs))
		px = int(config.get_value("video", "pos_x", -1))
		py = int(config.get_value("video", "pos_y", -1))
	DisplayWindowHelper.apply_resolution(get_window(), Vector2i(w, h), fs, px < 0 or py < 0)
	if not fs and px >= 0 and py >= 0:
		get_window().position = Vector2i(px, py)

func save_settings(w: int, h: int, fs: bool) -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_FILE)
	config.set_value("video", "width", w)
	config.set_value("video", "height", h)
	config.set_value("video", "fullscreen", fs)
	var win = get_window()
	if win.mode != Window.MODE_FULLSCREEN:
		config.set_value("video", "pos_x", win.position.x)
		config.set_value("video", "pos_y", win.position.y)
	config.save(SETTINGS_FILE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var win = get_window()
		save_settings(win.size.x, win.size.y, win.mode == Window.MODE_FULLSCREEN)
