class_name DebugReportRuntime
extends Node

## Global, on-demand bug capture.
##
## Normal play only appends compact records to a bounded event ring. Full board
## serialization, screenshot capture, and disk I/O happen only after the owner
## presses Report Bug while the game is paused.

const REPORT_DIR_USER: String = "user://bug_reports"
const REPORT_DIR_PROJECT: String = "res://reports/bug_reports"
const MAX_RECENT_EVENTS: int = 64
const MAX_REPORT_DESCRIPTION_LENGTH: int = 4000

var _recent_events: Array[Dictionary] = []
var _latest_preview: Dictionary = {}
var _latest_timeline: Dictionary = {}
var _latest_rejection: String = ""
var _preview_update_count: int = 0
var _overlay: CanvasLayer
var _generic_menu: Control
var _report_dialog: Control
var _pause_owned: bool = false
var _was_paused_before_debug_menu: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = CanvasLayer.new()
	_overlay.name = "DebugReportOverlay"
	_overlay.layer = 100
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)
	get_tree().scene_changed.connect(_on_scene_changed)
	if EventBus != null:
		EventBus.sim_event.connect(_on_sim_event)
		EventBus.action_rejected.connect(_on_action_rejected)
		EventBus.selection_changed.connect(_on_selection_changed)
		EventBus.ability_selected.connect(_on_ability_selected)
		EventBus.turn_phase_changed.connect(_on_turn_phase_changed)
		EventBus.timeline_changed.connect(_on_timeline_changed)
		EventBus.preview_updated.connect(_on_preview_updated)


func _on_scene_changed() -> void:
	_recent_events.clear()
	_latest_preview.clear()
	_latest_timeline.clear()
	_latest_rejection = ""
	_preview_update_count = 0
	var scene_path := ""
	if get_tree().current_scene != null:
		scene_path = get_tree().current_scene.scene_file_path
	_append_event({
		"kind": "scene_changed",
		"scene_path": scene_path,
	})


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if _report_dialog != null:
		close_report_dialog()
		get_viewport().set_input_as_handled()
		return
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	# TacticalMapView owns its own pause menu so Escape keeps its established
	# planning/input path. Other scenes receive this lightweight global menu.
	if current_scene.find_child("PauseMenu", true, false) != null:
		return
	if _generic_menu != null:
		_close_generic_menu()
	else:
		_pause_for_debug_capture()
		_open_generic_menu()
	get_viewport().set_input_as_handled()


func open_report_dialog() -> void:
	if _report_dialog != null:
		return
	_pause_for_debug_capture()
	_close_generic_menu(false)
	var dialog_script: Script = load("res://debug/debug_report_dialog.gd")
	_report_dialog = dialog_script.new()
	_report_dialog.name = "DebugReportDialog"
	_report_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.add_child(_report_dialog)
	_report_dialog.setup(self)


func close_report_dialog() -> void:
	if _report_dialog == null:
		return
	_report_dialog.queue_free()
	_report_dialog = null
	_restore_pause_after_debug_capture()


func submit_report(
	category: String,
	severity: String,
	title: String,
	description: String,
	expected: String,
	actual: String,
	include_screenshot: bool,
) -> Dictionary:
	var report_id := _make_report_id()
	var report_dir := _ensure_report_directory(REPORT_DIR_USER)
	var project_dir := _ensure_report_directory(REPORT_DIR_PROJECT)
	var screenshot_path := ""
	if include_screenshot:
		screenshot_path = _capture_screenshot(report_id, report_dir, project_dir)

	var report := {
		"report_id": report_id,
		"status": "open",
		"created_at": Time.get_datetime_string_from_system(true),
		"category": category,
		"severity": severity,
		"title": _limit_text(title.strip_edges(), 180),
		"description": _limit_text(description.strip_edges(), MAX_REPORT_DESCRIPTION_LENGTH),
		"expected": _limit_text(expected.strip_edges(), MAX_REPORT_DESCRIPTION_LENGTH),
		"actual": _limit_text(actual.strip_edges(), MAX_REPORT_DESCRIPTION_LENGTH),
		"runtime": _runtime_metadata(),
		"recent_events": _recent_events.duplicate(true),
		"latest_preview": _latest_preview.duplicate(true),
		"latest_timeline": _latest_timeline.duplicate(true),
		"latest_rejection": _latest_rejection,
		"context": _capture_scene_context(),
		"screenshot": screenshot_path,
	}
	var report_json := JSON.stringify(report, "\t")
	var paths: Array[String] = []
	var user_path := report_dir.path_join("%s.json" % report_id)
	if _write_text(user_path, report_json):
		paths.append(user_path)
	var project_path := project_dir.path_join("%s.json" % report_id)
	if _write_text(project_path, report_json):
		paths.append(project_path)
	_append_index(report)
	var display_paths: Array[String] = []
	for path: String in paths:
		display_paths.append(_display_path(path))
	return {
		"report_id": report_id,
		"paths": paths,
		"display_paths": display_paths,
		"screenshot": screenshot_path,
	}


static func serialize_board(board: BoardState) -> Dictionary:
	if board == null:
		return {}
	var tiles: Array[Dictionary] = []
	for key: Variant in board.tiles.keys():
		var tile := board.tiles[key] as TileState
		if tile == null:
			continue
		tiles.append({
			"coord": _coord(tile.coord),
			"terrain": String(tile.definition.id) if tile.definition != null else "",
			"occupant_id": tile.occupant_id,
		})
	var units: Array[Dictionary] = []
	for unit: UnitState in board.units:
		if unit == null:
			continue
		units.append({
			"id": unit.id,
			"definition": String(unit.definition.id) if unit.definition != null else "",
			"team": unit.team,
			"team_name": _enum_name(GameEnums.Team.keys(), unit.team),
			"position": _coord(unit.position),
			"facing": unit.facing,
			"facing_name": _enum_name(GameEnums.Facing.keys(), unit.facing),
			"alive": unit.is_alive(),
			"hp": unit.health.current_hp,
			"max_hp": unit.health.max_hp,
			"ap": unit.ability.points_left,
			"max_ap": unit.ability.max_points,
			"mp": unit.movement.points_left,
			"max_mp": unit.movement.max_points,
			"armor": unit.armor,
			"level": unit.level,
			"promotion": String(unit.promotion_id),
			"abilities": _ability_ids(unit.active_abilities),
			"passives": _passive_ids(unit.active_passives),
			"upgraded_abilities": _string_names(unit.upgraded_abilities),
			"upgraded_passives": _string_names(unit.upgraded_passives),
			"statuses": _statuses(unit.active_statuses),
		})
	return {
		"grid_size": _coord(board.grid_size),
		"turn_index": board.turn_index,
		"tiles": tiles,
		"units": units,
		"intents": _sanitize(board.intents),
		"pending_pushes": _sanitize(board.pending_pushes),
		"delayed_effects": _sanitize(board.delayed_effects),
	}


static func serialize_timeline(timeline: Timeline) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if timeline == null:
		return result
	for action: TimelineAction in timeline.entries:
		if action == null:
			continue
		result.append({
			"actor_id": action.actor_id,
			"type": action.type,
			"type_name": _enum_name(GameEnums.ActionType.keys(), action.type),
			"move_timing": action.move_timing,
			"move_timing_name": _enum_name(GameEnums.MoveTiming.keys(), action.move_timing),
			"target_coord": _coord(action.target_coord),
			"target_unit_id": action.target_unit_id,
			"ability": String(action.ability.id) if action.ability != null else "",
			"module_target_coords": action.module_target_coords.map(_coord),
			"module_target_unit_ids": action.module_target_unit_ids,
			"face_dir": action.face_dir,
			"waypoints": action.waypoints.map(_coord),
			"irreversible": action.irreversible,
			"uses_run": action.uses_run,
			"awaiting_target": action.awaiting_target,
			"is_free_reaction": action.is_free_reaction,
		})
	return result


func _open_generic_menu() -> void:
	_generic_menu = ColorRect.new()
	_generic_menu.name = "GlobalDebugEscapeMenu"
	_generic_menu.color = MenuTheme.BG_DIM
	_generic_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_generic_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.add_child(_generic_menu)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 220)
	_generic_menu.add_child(panel)
	MenuTheme.apply_panel(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	MenuTheme.style_title(title)
	box.add_child(title)
	var report := Button.new()
	report.text = "Report Bug"
	report.custom_minimum_size.y = 42
	MenuTheme.style_menu_button(report)
	report.pressed.connect(open_report_dialog)
	box.add_child(report)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size.y = 42
	MenuTheme.style_menu_button(close)
	close.pressed.connect(_close_generic_menu)
	box.add_child(close)


func _close_generic_menu(restore_pause: bool = true) -> void:
	if _generic_menu == null:
		return
	_generic_menu.queue_free()
	_generic_menu = null
	if restore_pause:
		_restore_pause_after_debug_capture()


func _pause_for_debug_capture() -> void:
	if _pause_owned:
		return
	_was_paused_before_debug_menu = get_tree().paused
	get_tree().paused = true
	_pause_owned = true


func _restore_pause_after_debug_capture() -> void:
	if not _pause_owned:
		return
	get_tree().paused = _was_paused_before_debug_menu
	_pause_owned = false


func _capture_scene_context() -> Dictionary:
	var scene := get_tree().current_scene
	if scene == null:
		return {}
	var context := {
		"scene_name": scene.name,
		"scene_path": scene.scene_file_path,
		"mode": scene.get_class(),
	}
	if scene.has_method("build_debug_context"):
		var provided: Variant = scene.call("build_debug_context")
		if provided is Dictionary:
			context.merge(provided as Dictionary, true)
	return _sanitize(context)


func _runtime_metadata() -> Dictionary:
	var scene := get_tree().current_scene
	var scene_path := ""
	if scene != null:
		scene_path = scene.scene_file_path
	return {
		"engine": Engine.get_version_info(),
		"project": ProjectSettings.get_setting("application/config/name", ""),
		"project_version": ProjectSettings.get_setting("application/config/version", "dev"),
		"git_commit": _read_git_commit_hash(),
		"scene_path": scene_path,
		"fps_at_capture": Engine.get_frames_per_second(),
		"paused_at_capture": get_tree().paused,
		"window_size": _sanitize(get_viewport().get_visible_rect().size),
		"command_line": OS.get_cmdline_args(),
	}


func _capture_screenshot(report_id: String, user_dir: String, project_dir: String) -> String:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return ""
	var filename := "%s.png" % report_id
	var user_path := user_dir.path_join(filename)
	if image.save_png(user_path) != OK:
		return ""
	var project_path := project_dir.path_join(filename)
	if image.save_png(project_path) == OK:
		return project_path
	return user_path


func _ensure_report_directory(path: String) -> String:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute)
	return absolute


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _append_index(report: Dictionary) -> void:
	var title_text: String = String(report.title)
	if title_text.is_empty():
		title_text = "(untitled)"
	var line := "- `%s` **%s** — %s — %s — %s\n" % [
		report.report_id,
		report.get("status", "open"),
		report.severity,
		report.category,
		title_text,
	]
	var project_index := _ensure_report_directory(REPORT_DIR_PROJECT).path_join("index.md")
	_append_index_line(project_index, line)
	var user_index := _ensure_report_directory(REPORT_DIR_USER).path_join("index.md")
	_append_index_line(user_index, line)


func _append_index_line(index_path: String, line: String) -> void:
	var existing := ""
	if FileAccess.file_exists(index_path):
		existing = FileAccess.get_file_as_string(index_path)
	_write_text(index_path, existing + line)


func _on_sim_event(event: SimEvent) -> void:
	_append_event({
		"kind": "sim_event",
		"type": event.type,
		"type_name": _enum_name(GameEnums.SimEventType.keys(), event.type),
		"data": _sanitize(event.data),
	})


func _on_action_rejected(reason: String) -> void:
	_latest_rejection = reason
	_append_event({"kind": "action_rejected", "reason": reason})


func _on_selection_changed(unit_id: int) -> void:
	_append_event({"kind": "selection_changed", "unit_id": unit_id})


func _on_ability_selected(index: int) -> void:
	_append_event({"kind": "ability_selected", "index": index})


func _on_turn_phase_changed(phase: int) -> void:
	_append_event({
		"kind": "phase_changed",
		"phase": phase,
		"phase_name": _enum_name(CombatDirector.Phase.keys(), phase),
	})


func _on_timeline_changed(timeline: Timeline, statuses: PackedStringArray) -> void:
	_latest_timeline = {
		"action_count": timeline.entries.size() if timeline != null else 0,
		"statuses": Array(statuses),
	}
	_append_event({
		"kind": "timeline_changed",
		"action_count": timeline.entries.size() if timeline != null else 0,
		"statuses": Array(statuses),
	})


func _on_preview_updated(result: SimResult) -> void:
	_preview_update_count += 1
	var event_count := result.events.size() if result != null else 0
	var last_event_type := -1
	if result != null and not result.events.is_empty():
		last_event_type = result.events.back().type
	_latest_preview = {
		"update_count": _preview_update_count,
		"event_count": event_count,
		"last_event_type": last_event_type,
		"last_event_type_name": _enum_name(GameEnums.SimEventType.keys(), last_event_type),
	}


func _append_event(record: Dictionary) -> void:
	_recent_events.append(record)
	if _recent_events.size() > MAX_RECENT_EVENTS:
		_recent_events.pop_front()


static func _ability_ids(abilities: Array[AbilityData]) -> Array[String]:
	var ids: Array[String] = []
	for ability: AbilityData in abilities:
		if ability != null:
			ids.append(String(ability.id))
	return ids


static func _passive_ids(passives: Array[PassiveData]) -> Array[String]:
	var ids: Array[String] = []
	for passive: PassiveData in passives:
		if passive != null:
			ids.append(String(passive.id))
	return ids


static func _string_names(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


static func _statuses(statuses: Array[StatusData]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for status: StatusData in statuses:
		if status == null:
			continue
		result.append({
			"type": status.type,
			"value": status.value,
			"duration": status.duration,
			"ticks_remaining": status.ticks_remaining,
		})
	return result


static func _coord(value: Vector2i) -> Array[int]:
	return [value.x, value.y]


static func _enum_name(names: PackedStringArray, value: int) -> String:
	if value < 0 or value >= names.size():
		return ""
	return names[value]


static func _limit_text(value: String, max_length: int) -> String:
	return value.substr(0, max_length)


static func _make_report_id() -> String:
	var stamp := Time.get_datetime_string_from_system(false).replace("-", "").replace(":", "")
	var suffix: int = Time.get_ticks_msec() % 1000
	return "BUG-%s-%03d" % [stamp, suffix]


func _read_git_commit_hash() -> String:
	var head_path := ProjectSettings.globalize_path("res://.git/HEAD")
	if not FileAccess.file_exists(head_path):
		return ""
	var head := FileAccess.get_file_as_string(head_path).strip_edges()
	if head.is_empty():
		return ""
	if head.begins_with("ref: "):
		var ref_path := head.substr(5).strip_edges()
		var object_path := ProjectSettings.globalize_path("res://.git/%s" % ref_path)
		if FileAccess.file_exists(object_path):
			return FileAccess.get_file_as_string(object_path).strip_edges().substr(0, 40)
		return ""
	return head.substr(0, 40)


func _display_path(absolute_path: String) -> String:
	var project_root := ProjectSettings.globalize_path("res://").replace("\\", "/")
	var normalized := absolute_path.replace("\\", "/")
	if normalized.begins_with(project_root):
		return normalized.substr(project_root.length())
	if normalized.find("bug_reports/") >= 0:
		return normalized.substr(normalized.find("bug_reports/"))
	return normalized.get_file()


static func _sanitize(value: Variant) -> Variant:
	if value is Vector2i:
		return _coord(value as Vector2i)
	if value is Vector2:
		var vector := value as Vector2
		return [vector.x, vector.y]
	if value is StringName:
		return String(value)
	if value is Object:
		if value is SimEvent:
			return {"type": (value as SimEvent).type, "data": _sanitize((value as SimEvent).data)}
		return str(value)
	if value is Dictionary:
		var dict: Dictionary = {}
		for key: Variant in value.keys():
			dict[String(key)] = _sanitize(value[key])
		return dict
	if value is Array:
		var array: Array = []
		for item: Variant in value:
			array.append(_sanitize(item))
		return array
	return value
