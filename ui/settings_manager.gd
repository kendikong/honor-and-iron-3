extends Node

const SETTINGS_FILE = "user://settings.cfg"

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		var w = config.get_value("video", "width", 1600)
		var h = config.get_value("video", "height", 900)
		var fs = config.get_value("video", "fullscreen", false)
		
		var px = config.get_value("video", "pos_x", -1)
		var py = config.get_value("video", "pos_y", -1)
		
		if fs:
			get_window().mode = Window.MODE_FULLSCREEN
		else:
			get_window().mode = Window.MODE_WINDOWED
			
		get_window().size = Vector2i(w, h)
		
		if px != -1 and py != -1:
			get_window().position = Vector2i(px, py)
		else:
			var screen_id = get_window().current_screen
			if screen_id >= 0:
				var screen_size = DisplayServer.screen_get_size(screen_id)
				get_window().position = (screen_size - get_window().size) / 2

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
