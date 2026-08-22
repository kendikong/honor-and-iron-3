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

const STATUS_ONGOING: String = "ongoing"
const STATUS_DONE: String = "done"
const STATUS_TRASH: String = "trash"

const INDEX_HEADER: String = (
	"# Bug Reports Index\n\n"
	+ "> Owner statuses: **ongoing** (still open), **done** (resolved), **trash** (dismissed).\n"
	+ "> Agents treat **ongoing** as active work; ignore **done** and **trash** unless asked.\n\n"
	+ "> [!IMPORTANT]\n"
	+ "> **MANDATORY FOR ALL AGENTS FIXING BUG REPORTS:**\n"
	+ "> You are strictly forbidden from writing or proposing heuristic fixes. Before attempting any fix, you MUST read `.cursor/rules/global-systems-first.mdc`, `.cursor/rules/no-bandaid-fixes.mdc`, and `.cursor/rules/move-preview-intent-truth.mdc`.\n"
	+ "> All fixes must adhere to the **6 Major Architectural Sources of Truth** (`Simulator`, `CombatDirector.validate_commit_slots`, `CombatPlanningPreview`, action range latest stand, `.tres` data, simulation-derived presentation).\n\n"
)

signal report_dialog_opened
signal report_dialog_closed
signal report_status_changed(report_id: String, status: String)

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
	_rebuild_index()
	_pause_for_debug_capture()
	_close_generic_menu(false)
	var dialog_script: Script = load("res://debug/debug_report_dialog.gd")
	_report_dialog = dialog_script.new()
	_report_dialog.name = "DebugReportDialog"
	_report_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.add_child(_report_dialog)
	_report_dialog.setup(self)
	report_dialog_opened.emit()


func close_report_dialog() -> void:
	if _report_dialog == null:
		return
	_report_dialog.queue_free()
	_report_dialog = null
	_restore_pause_after_debug_capture()
	report_dialog_closed.emit()


func is_report_dialog_open() -> bool:
	return _report_dialog != null


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
		"mandatory_agent_instructions": {
			"directive": "MANDATORY FOR ALL AGENTS: You are strictly forbidden from applying heuristic fixes. All fixes must use shared global systems and the canonical single sources of truth.",
			"required_rules": [
				".cursor/rules/global-systems-first.mdc",
				".cursor/rules/no-bandaid-fixes.mdc",
				".cursor/rules/move-preview-intent-truth.mdc",
				".cursor/rules/action-range-latest-stand.mdc",
				".cursor/rules/qa-after-gameplay-changes.mdc"
			],
			"architectural_sources_of_truth": {
				"1_simulation": "Simulator.simulate_player_turn(state, timeline, events) is the pure RefCounted deterministic resolution for preview and commit.",
				"2_commit_authority": "CombatDirector.validate_commit_slots(unit_id, slots) is the single authority on action legality and commit success.",
				"3_move_preview": "CombatPlanningPreview and TacticalPlanningOverlay — preview is intent truth (what is previewed on hover is what gets committed).",
				"4_action_range": "CombatPlanningPreview.committed_stand_tile(unit_id) — range tiles paint from committed stand on active timeline, never turn-start base_board.",
				"5_abilities": "AbilitySystem and AbilityData Resources — data-driven resources, not hardcoded engine branches.",
				"6_input_buffers": "Input buffers (_drag_route, waypoints) are transient staging and must never directly paint canvas routes without simulation validation."
			}
		},
		"report_id": report_id,
		"status": STATUS_ONGOING,
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
		"diagnosis_hints": {},
		"screenshot": screenshot_path,
	}
	report["diagnosis_hints"] = _build_diagnosis_hints(
		report["context"] as Dictionary,
		_latest_rejection,
	)
	var report_json := JSON.stringify(report, "\t")
	var paths: Array[String] = []
	var user_path := report_dir.path_join("%s.json" % report_id)
	if _write_text(user_path, report_json):
		paths.append(user_path)
	var project_path := project_dir.path_join("%s.json" % report_id)
	if _write_text(project_path, report_json):
		paths.append(project_path)
	_rebuild_index()
	var display_paths: Array[String] = []
	for path: String in paths:
		display_paths.append(_display_path(path))
	return {
		"report_id": report_id,
		"paths": paths,
		"display_paths": display_paths,
		"screenshot": screenshot_path,
	}


static func normalize_status(raw: String) -> String:
	match String(raw).strip_edges().to_lower():
		"open":
			return STATUS_ONGOING
		"fixed":
			return STATUS_DONE
		STATUS_ONGOING, STATUS_DONE, STATUS_TRASH:
			return String(raw).strip_edges().to_lower()
		_:
			return STATUS_ONGOING


static func status_display_name(status: String) -> String:
	match normalize_status(status):
		STATUS_DONE:
			return "Done"
		STATUS_TRASH:
			return "Trash"
		_:
			return "Still ongoing"


func list_reports(include_trash: bool = true) -> Array[Dictionary]:
	var merged: Dictionary = {}
	_collect_reports_from_dir(_ensure_report_directory(REPORT_DIR_PROJECT), merged)
	_collect_reports_from_dir(_ensure_report_directory(REPORT_DIR_USER), merged)
	var summaries: Array[Dictionary] = []
	for report_id: Variant in merged.keys():
		var entry: Dictionary = merged[report_id] as Dictionary
		var status: String = normalize_status(String(entry.get("status", STATUS_ONGOING)))
		if not include_trash and status == STATUS_TRASH:
			continue
		summaries.append({
			"report_id": String(entry.get("report_id", report_id)),
			"status": status,
			"created_at": String(entry.get("created_at", "")),
			"category": String(entry.get("category", "")),
			"severity": String(entry.get("severity", "")),
			"title": String(entry.get("title", "(untitled)")),
			"json_path": String(entry.get("json_path", "")),
		})
	summaries.sort_custom(_sort_report_summaries_newest_first)
	return summaries


func set_report_status(report_id: String, status: String) -> bool:
	var normalized_id := report_id.strip_edges()
	if normalized_id.is_empty():
		return false
	var normalized_status := normalize_status(status)
	var user_path := _ensure_report_directory(REPORT_DIR_USER).path_join("%s.json" % normalized_id)
	var project_path := _ensure_report_directory(REPORT_DIR_PROJECT).path_join("%s.json" % normalized_id)
	var source_path := user_path if FileAccess.file_exists(user_path) else project_path
	if not FileAccess.file_exists(source_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	if not parsed is Dictionary:
		return false
	var report: Dictionary = parsed as Dictionary
	report["status"] = normalized_status
	report["status_updated_at"] = Time.get_datetime_string_from_system(true)
	var report_json := JSON.stringify(report, "\t")
	if not _write_text(user_path, report_json):
		return false
	if FileAccess.file_exists(project_path) or _project_report_dir_writable():
		_write_text(project_path, report_json)
	_rebuild_index()
	report_status_changed.emit(normalized_id, normalized_status)
	return true


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
			"turn_action_used": unit.turn_action_used,
			"action_column_spent": unit.action_column_spent(),
			"has_used_turn_action": unit.has_used_turn_action(),
			"training_unlimited_actions": unit.has_unlimited_training_actions(),
			"can_use_action_slot": unit.can_use_action_slot(),
			"pre_move_used_this_turn": unit.pre_move_used_this_turn,
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


static func _move_timing_name(timing: int) -> String:
	match timing:
		GameEnums.MoveTiming.PRE_ACTION:
			return "PRE_ACTION"
		GameEnums.MoveTiming.POST_ACTION:
			return "POST_ACTION"
		_:
			return ""


static func serialize_timeline_action(action: TimelineAction) -> Dictionary:
	if action == null:
		return {}
	return {
		"actor_id": action.actor_id,
		"type": action.type,
		"type_name": _enum_name(GameEnums.ActionType.keys(), action.type),
		"move_timing": action.move_timing,
		"move_timing_name": _move_timing_name(action.move_timing),
		"target_coord": _coord(action.target_coord),
		"target_unit_id": action.target_unit_id,
		"ability": String(action.ability.id) if action.ability != null else "",
		"module_target_coords": action.module_target_coords.map(_coord),
		"module_target_unit_ids": action.module_target_unit_ids,
		"face_dir": action.face_dir,
		"waypoints": action.waypoints.map(_coord),
		"irreversible": action.irreversible,
		"uses_run": action.uses_run,
		"uses_steady_aim": action.uses_steady_aim,
		"awaiting_target": action.awaiting_target,
		"is_free_reaction": action.is_free_reaction,
	}


static func serialize_commit_slots(slots: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"invalid": slots.get("invalid", false),
		"preview_validated": slots.get("_preview_validated", false),
		"noop": slots.get("_noop", false),
	}
	for col: String in ["pre", "action", "post"]:
		var serialized: Array[Dictionary] = []
		for raw: Variant in slots.get(col, []):
			if raw is TimelineAction:
				serialized.append(serialize_timeline_action(raw as TimelineAction))
		result[col] = serialized
	return result


static func serialize_timeline(timeline: Timeline) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if timeline == null:
		return result
	for action: TimelineAction in timeline.entries:
		if action == null:
			continue
		result.append(serialize_timeline_action(action))
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


func _build_diagnosis_hints(context: Dictionary, latest_rejection: String) -> Dictionary:
	var hints: Dictionary = {}
	var training: Dictionary = context.get("training_session", {}) as Dictionary
	if not training.is_empty():
		hints["infinite_player_ap"] = bool(training.get("infinite_player_ap", false))
		hints["training_player_class"] = String(training.get("player_class_id", ""))
	var director_ctx: Dictionary = context.get("combat_director", {}) as Dictionary
	if not director_ctx.is_empty():
		hints["auto_run"] = bool(director_ctx.get("auto_run", false))
		hints["plan_revision"] = int(director_ctx.get("plan_revision", 0))
	var planning: Dictionary = context.get("planning_input", {}) as Dictionary
	if not planning.is_empty():
		hints["hover_tile"] = planning.get("hover_tile", [])
		hints["planning_move_timing"] = planning.get("planning_move_timing", -1)
		hints["planning_move_timing_name"] = String(planning.get("planning_move_timing_name", ""))
		hints["action_column_spent"] = bool(planning.get("action_column_spent", false))
		hints["awaiting_targeting"] = bool(planning.get("awaiting_targeting", false))
		hints["dragging"] = bool(planning.get("dragging", false))
		var slots: Dictionary = planning.get("hover_commit_slots", {}) as Dictionary
		if not slots.is_empty():
			hints["hover_commit_pre_count"] = (slots.get("pre", []) as Array).size()
			hints["hover_commit_action_count"] = (slots.get("action", []) as Array).size()
			hints["hover_commit_post_count"] = (slots.get("post", []) as Array).size()
			hints["hover_commit_invalid"] = slots.get("invalid", false)
	var timelines: Dictionary = context.get("timelines", {}) as Dictionary
	if not timelines.is_empty():
		hints["timeline_pre_count"] = (timelines.get("pre_move", []) as Array).size()
		hints["timeline_action_count"] = (timelines.get("action", []) as Array).size()
		hints["timeline_post_count"] = (timelines.get("post_move", []) as Array).size()
	if latest_rejection != "":
		hints["latest_rejection"] = latest_rejection
	return hints


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


func _rebuild_index() -> void:
	var summaries := list_reports(true)
	var body := INDEX_HEADER
	for summary: Dictionary in summaries:
		var title_text: String = String(summary.get("title", "(untitled)"))
		if title_text.is_empty():
			title_text = "(untitled)"
		body += "- `%s` **%s** — %s — %s — %s\n" % [
			summary.get("report_id", ""),
			summary.get("status", STATUS_ONGOING),
			summary.get("severity", ""),
			summary.get("category", ""),
			title_text,
		]
	var project_index := _ensure_report_directory(REPORT_DIR_PROJECT).path_join("index.md")
	_write_text(project_index, body)
	var user_index := _ensure_report_directory(REPORT_DIR_USER).path_join("index.md")
	_write_text(user_index, body)


func _collect_reports_from_dir(dir_path: String, merged: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var json_path := dir_path.path_join(file_name)
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
			if parsed is Dictionary:
				var report: Dictionary = parsed as Dictionary
				var report_id := String(report.get("report_id", file_name.get_basename()))
				report["json_path"] = json_path
				report["status"] = normalize_status(String(report.get("status", STATUS_ONGOING)))
				merged[report_id] = report
		file_name = dir.get_next()
	dir.list_dir_end()


static func _sort_report_summaries_newest_first(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("created_at", "")) > String(b.get("created_at", ""))


func _project_report_dir_writable() -> bool:
	var probe := _ensure_report_directory(REPORT_DIR_PROJECT).path_join(".write_probe")
	if _write_text(probe, "ok"):
		DirAccess.remove_absolute(probe)
		return true
	return false


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
