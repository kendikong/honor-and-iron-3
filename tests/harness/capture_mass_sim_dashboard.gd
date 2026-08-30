extends SceneTree

## Headless capture: PNG + JSON under tests/captures/ so agents see what the user sees.

const CAPTURE_DIR := "res://tests/captures"
const CAPTURE_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 4


func _initialize() -> void:
	var runner := CaptureRunner.new()
	runner.capture_dir = CAPTURE_DIR
	runner.capture_size = CAPTURE_SIZE
	runner.warmup_frames = WARMUP_FRAMES
	runner.finished.connect(func(code: int) -> void: quit(code))
	root.add_child(runner)


class CaptureRunner extends Node:
	signal finished(exit_code: int)

	var capture_dir: String = "res://tests/captures"
	var capture_size: Vector2i = Vector2i(1280, 720)
	var warmup_frames: int = 4

	var _viewport: SubViewport
	var _dashboard: Control
	var _frames_waited: int = 0

	func _ready() -> void:
		_ensure_capture_dir()
		_viewport = SubViewport.new()
		_viewport.size = capture_size
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_viewport.disable_3d = true
		add_child(_viewport)
		_dashboard = load("res://scenes/MassSimDashboard.tscn").instantiate() as Control
		_viewport.add_child(_dashboard)
		set_process(true)

	func _process(_delta: float) -> void:
		_frames_waited += 1
		if _frames_waited < warmup_frames:
			return
		set_process(false)
		var code: int = _write_outputs()
		finished.emit(code)

	func _ensure_capture_dir() -> void:
		var abs_dir: String = ProjectSettings.globalize_path(capture_dir)
		DirAccess.make_dir_recursive_absolute(abs_dir)

	func _write_outputs() -> int:
		var abs_dir: String = ProjectSettings.globalize_path(capture_dir)
		var json_path: String = abs_dir.path_join("mass_sim_snapshot.json")
		var png_path: String = abs_dir.path_join("mass_sim_dashboard.png")

		var snapshot: Dictionary = {}
		if _dashboard is MassSimDashboard:
			snapshot = (_dashboard as MassSimDashboard).export_visual_snapshot()
		else:
			snapshot = {"error": "MassSimDashboard instance missing", "node_class": _dashboard.get_class()}

		snapshot["capture_size"] = [capture_size.x, capture_size.y]
		snapshot["png_path"] = png_path

		var tex: ViewportTexture = _viewport.get_texture()
		if tex != null:
			var image: Image = tex.get_image()
			if image != null and not image.is_empty():
				var png_err: Error = image.save_png(png_path)
				if png_err != OK:
					snapshot["png_error"] = str(png_err)
					printerr("[CAPTURE_FAIL] png save error %s" % str(png_err))
				else:
					snapshot["png_saved"] = true
			else:
				snapshot["png_error"] = "empty viewport image (try capture without -Headless)"
				printerr("[CAPTURE_WARN] %s" % String(snapshot["png_error"]))
		else:
			snapshot["png_error"] = "no viewport texture"

		var json_file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
		if json_file == null:
			printerr("[CAPTURE_FAIL] cannot write %s" % json_path)
			return 1
		json_file.store_string(JSON.stringify(snapshot, "\t"))
		json_file.close()

		print("[CAPTURE_OK] %s" % json_path)
		print("[CAPTURE_OK] %s" % png_path)
		if snapshot.has("status_text"):
			print("[CAPTURE_STATUS] %s" % String(snapshot["status_text"]))
		return 0
