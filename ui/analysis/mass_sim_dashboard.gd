class_name MassSimDashboard
extends Control

static var instance: MassSimDashboard

var main_split: HSplitContainer
var tab_container: TabContainer
var inspector: UniversalInspectorPanel
var command_palette: CommandPaletteModal
var batch_runner: MassBattleRunner
var progress_bar: ProgressBar
var status_label: Label
var queue_list: ItemList
var _file_dialog: FileDialog
var _tag_filter: OptionButton
var _epoch_filter: OptionButton
var _epoch_banner: Label
var _new_epoch_dialog: Window
var _epoch_label_edit: LineEdit

var _report: MassSimBatchReport
var _workspace: MassSimWorkspace
var _log_path: String = MassSimConstants.DEFAULT_LOG_PATH
var _job_queue: Array[Dictionary] = []
var _running_job: bool = false
var _panels: Dictionary = {}
var _all_rows: Array[Dictionary] = []


func _ready() -> void:
	instance = self
	_workspace = MassSimWorkspace.load()
	MassSimRulesEpoch.ensure_default_epoch(_workspace)
	_sync_log_path_from_epoch()
	_report = MassSimBatchReport.new()
	_build_chrome()
	_build_tabs()
	_bind_runner()
	_load_saved_results()
	tab_container.current_tab = _workspace.last_tab
	_refresh_command_palette()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_save_workspace()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_K and event.is_command_or_control_pressed():
		command_palette.popup_palette()
		get_viewport().set_input_as_handled()


func _build_chrome() -> void:
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", _flat_style(MenuTheme.BG))
	add_child(bg)
	main_split = HSplitContainer.new()
	main_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_split.offset_left = 12
	main_split.offset_top = 12
	main_split.offset_right = -12
	main_split.offset_bottom = -12
	main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg.add_child(main_split)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.add_child(left)
	var header := HBoxContainer.new()
	left.add_child(header)
	_add_header_btn(header, "← Menu", func() -> void:
		_save_workspace()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	var title := Label.new()
	title.text = "Mass Simulation Analytics"
	MassSimTheme.style_title(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_add_header_btn(header, "Open JSONL", _open_file_dialog)
	_add_header_btn(header, "Reload", _load_saved_results)
	_add_header_btn(header, "New Epoch", _open_new_epoch_dialog)
	_add_header_btn(header, "Export CSV", _export_csv)
	_add_header_btn(header, "AI Report", _open_interpretation_folder)
	_add_header_btn(header, "Run Queue", _start_queue)
	_add_header_btn(header, "+100", func() -> void: _enqueue_job("Baseline", 100))
	_add_header_btn(header, "+500", func() -> void: _enqueue_job("Full Confidence", 500))
	progress_bar = ProgressBar.new()
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size.x = 100
	progress_bar.visible = false
	header.add_child(progress_bar)
	status_label = Label.new()
	MassSimTheme.style_muted(status_label)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	left.add_child(status_label)
	var filter_row := HBoxContainer.new()
	left.add_child(filter_row)
	var filter_lbl := Label.new()
	filter_lbl.text = "Map tag filter:"
	MassSimTheme.style_muted(filter_lbl)
	filter_row.add_child(filter_lbl)
	_tag_filter = OptionButton.new()
	_tag_filter.add_item("All tags", 0)
	_tag_filter.item_selected.connect(_on_tag_filter_changed)
	filter_row.add_child(_tag_filter)
	var epoch_lbl := Label.new()
	epoch_lbl.text = "Balance epoch:"
	MassSimTheme.style_muted(epoch_lbl)
	filter_row.add_child(epoch_lbl)
	_epoch_filter = OptionButton.new()
	_epoch_filter.item_selected.connect(_on_epoch_filter_changed)
	filter_row.add_child(_epoch_filter)
	_epoch_banner = Label.new()
	_epoch_banner.autowrap_mode = TextServer.AUTOWRAP_WORD
	MassSimTheme.style_muted(_epoch_banner)
	left.add_child(_epoch_banner)
	var queue_panel := PanelContainer.new()
	MassSimTheme.apply_panel(queue_panel)
	left.add_child(queue_panel)
	var queue_vbox := VBoxContainer.new()
	queue_panel.add_child(queue_vbox)
	var queue_title := Label.new()
	queue_title.text = "Experiment Queue"
	MassSimTheme.style_muted(queue_title)
	queue_vbox.add_child(queue_title)
	queue_list = ItemList.new()
	queue_list.custom_minimum_size = Vector2(0, 64)
	queue_vbox.add_child(queue_list)
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.tab_changed.connect(func(tab: int) -> void:
		_workspace.last_tab = tab
		_save_workspace()
	)
	left.add_child(tab_container)
	inspector = UniversalInspectorPanel.new()
	main_split.add_child(inspector)
	inspector.replay_requested.connect(_open_replay)
	inspector.pin_requested.connect(_pin_replay)
	command_palette = CommandPaletteModal.new()
	add_child(command_palette)
	command_palette.item_selected.connect(_on_palette_item)
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_USERDATA
	_file_dialog.filters = PackedStringArray(["*.jsonl ; JSONL logs"])
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)
	_build_new_epoch_dialog()
	if _job_queue.is_empty():
		_enqueue_job("Baseline Batch", 100)


func _add_header_btn(parent: HBoxContainer, text: String, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	MassSimTheme.style_button(btn)
	btn.pressed.connect(cb)
	parent.add_child(btn)


func _build_tabs() -> void:
	_add_panel("L1: Executive Summary", Level1SummaryPanel.new())
	_add_panel("L2: Balance & Synergy", Level2BalancePanel.new())
	_add_panel("L3: Economy & Math", Level3EconomyPanel.new())
	_add_panel("L4: Physics Heatmaps", Level4PhysicsPanel.new())
	_add_panel("L5: AI Diagnostics", Level5AIPanel.new())
	_add_panel("L6: Map Bias", Level6MapPanel.new())
	_add_panel("L7: Integrity", Level7IntegrityPanel.new())


func _add_panel(tab_name: String, panel: Control) -> void:
	panel.name = tab_name
	tab_container.add_child(panel)
	_panels[tab_name] = panel
	if panel.has_signal("inspect_requested"):
		panel.inspect_requested.connect(_on_inspect)
	if panel.has_signal("replay_requested"):
		panel.replay_requested.connect(_open_replay)


func _bind_runner() -> void:
	batch_runner = MassBattleRunner.new()
	add_child(batch_runner)
	batch_runner.batch_progress.connect(_on_batch_progress)
	batch_runner.batch_completed.connect(_on_batch_completed)


func _enqueue_job(label: String, count: int) -> void:
	_job_queue.append({"label": label, "count": count})
	queue_list.add_item("%s — %d battles" % [label, count])
	status_label.text = "%d job(s) queued" % _job_queue.size()


func _start_queue() -> void:
	if _running_job:
		return
	if _job_queue.is_empty():
		status_label.text = "Queue empty — add a job first."
		return
	_run_next_job()


func _run_next_job() -> void:
	if _job_queue.is_empty():
		_running_job = false
		progress_bar.visible = false
		status_label.text = "Queue complete."
		return
	_running_job = true
	var job: Dictionary = _job_queue.pop_front()
	queue_list.remove_item(0)
	var count: int = int(job.get("count", 100))
	var label: String = String(job.get("label", "Job"))
	status_label.text = "Running: %s (%d battles)" % [label, count]
	progress_bar.visible = true
	progress_bar.value = 0
	progress_bar.max_value = count
	batch_runner.start_batch(count, _log_path, label, true, _batch_epoch_id(), _batch_epoch_fingerprint())


func _batch_epoch_id() -> String:
	if _workspace.active_epoch_id.is_empty() or _workspace.active_epoch_id == MassSimRulesEpoch.LEGACY_EPOCH_ID:
		return ""
	return _workspace.active_epoch_id


func _batch_epoch_fingerprint() -> String:
	if _batch_epoch_id().is_empty():
		return ""
	var ep: Dictionary = MassSimRulesEpoch.active_epoch(_workspace)
	return String(ep.get("fingerprint", MassSimRulesEpoch.fingerprint()))


func _on_batch_progress(completed: int, total: int) -> void:
	progress_bar.value = completed
	progress_bar.max_value = total


func _on_batch_completed(path: String, stats: Dictionary) -> void:
	_load_saved_results()
	inspector.show_replay(_report, int(stats.get("best_performance_id", -1)))
	MassSimAggregator.save_snapshot(_report)
	status_label.text = (
		"Batch done — %d battles · interpretation saved to tests/captures/"
		% _report.total_battles
	)
	_run_next_job()


func _load_saved_results() -> void:
	_sync_log_path_from_epoch()
	_all_rows = MassSimAggregator.load_jsonl(_log_path)
	_rebuild_epoch_filter()
	_rebuild_tag_filter()
	var epoch_rows: Array = MassSimRulesEpoch.filter_epoch_rows(_all_rows, _workspace.active_epoch_id)
	var mix: Dictionary = MassSimRulesEpoch.analyze_mix(_all_rows)
	_update_epoch_banner(mix, epoch_rows.size())
	var filtered: Array = MassSimAggregator.filter_rows(epoch_rows, _workspace.map_tag_filter)
	var curator: Dictionary = {}
	if not filtered.is_empty():
		var curator_obj := SmartReplayCurator.new()
		curator_obj.curate(filtered)
		curator = curator_obj.to_dict()
	_report = MassSimAggregator.build_report(filtered, _log_path, curator)
	_apply_report()
	status_label.text = (
		"%d battles in epoch (%d in file) · %s"
		% [_report.total_battles, _all_rows.size(), _log_path]
		if not _report.is_empty()
		else "No results — queue a batch or Open JSONL"
	)


func _sync_log_path_from_epoch() -> void:
	MassSimRulesEpoch.ensure_default_epoch(_workspace)
	var ep: Dictionary = MassSimRulesEpoch.active_epoch(_workspace)
	if ep.is_empty():
		_log_path = _workspace.log_path
		return
	var lp: String = String(ep.get("log_path", ""))
	if not lp.is_empty():
		_log_path = lp
		_workspace.log_path = lp


func _rebuild_epoch_filter() -> void:
	_epoch_filter.clear()
	var select: int = 0
	for i: int in range(_workspace.epochs.size()):
		var ep: Dictionary = _workspace.epochs[i] as Dictionary
		var eid: String = String(ep.get("id", ""))
		var label: String = String(ep.get("label", eid))
		var battles_hint: String = ""
		if eid == _workspace.active_epoch_id:
			battles_hint = " (active)"
		_epoch_filter.add_item("%s%s" % [label, battles_hint])
		if eid == _workspace.active_epoch_id:
			select = i
	_epoch_filter.select(select)


func _update_epoch_banner(mix: Dictionary, epoch_battle_count: int) -> void:
	var ep: Dictionary = MassSimRulesEpoch.active_epoch(_workspace)
	var fp: String = String(ep.get("fingerprint", ""))
	if fp.is_empty() and _workspace.active_epoch_id != MassSimRulesEpoch.LEGACY_EPOCH_ID:
		fp = MassSimRulesEpoch.fingerprint()
	var lines: PackedStringArray = PackedStringArray()
	if _workspace.active_epoch_id == MassSimRulesEpoch.LEGACY_EPOCH_ID:
		lines.append("Legacy epoch — old battles have no rules tag. Click New Epoch before your next balance change.")
	elif not fp.is_empty():
		lines.append("Active rules: %s" % MassSimRulesEpoch.fingerprint_label())
	if bool(mix.get("is_mixed", false)):
		lines.append("Warning: this log mixes multiple rule sets — stats are not apples-to-apples.")
	if bool(mix.get("fingerprint_mismatch", false)):
		lines.append("Warning: multiple rule fingerprints in file — start a New Epoch after each change.")
	if epoch_battle_count < MassSimConstants.MIN_SAMPLE_BASIC:
		lines.append("Need %d+ battles in this epoch for basic stats (500 for full confidence)." % MassSimConstants.MIN_SAMPLE_BASIC)
	_epoch_banner.text = "\n".join(lines)


func _on_epoch_filter_changed(index: int) -> void:
	if index < 0 or index >= _workspace.epochs.size():
		return
	var ep: Dictionary = _workspace.epochs[index] as Dictionary
	_workspace.active_epoch_id = String(ep.get("id", ""))
	_sync_log_path_from_epoch()
	_save_workspace()
	_load_saved_results()


func _build_new_epoch_dialog() -> void:
	_new_epoch_dialog = Window.new()
	_new_epoch_dialog.title = "New Balance Epoch"
	_new_epoch_dialog.unresizable = true
	_new_epoch_dialog.transient = true
	_new_epoch_dialog.exclusive = true
	_new_epoch_dialog.min_size = Vector2i(440, 248)
	_new_epoch_dialog.size = Vector2i(440, 248)
	_new_epoch_dialog.close_requested.connect(func() -> void: _new_epoch_dialog.hide())
	var panel := PanelContainer.new()
	MassSimTheme.apply_panel(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_new_epoch_dialog.add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var intro := Label.new()
	intro.text = (
		"Use this when you change balance, AI, or skirmish size.\n"
		+ "Your current log is archived; new battles start in a clean file."
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(intro)
	var hint := Label.new()
	hint.text = "What changed?"
	MassSimTheme.style_muted(hint)
	root.add_child(hint)
	_epoch_label_edit = LineEdit.new()
	_epoch_label_edit.placeholder_text = "e.g. Knight damage +2"
	_epoch_label_edit.custom_minimum_size.y = 32
	root.add_child(_epoch_label_edit)
	var rules := Label.new()
	rules.text = "Current rules: %s" % MassSimRulesEpoch.fingerprint_label()
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MassSimTheme.style_muted(rules)
	root.add_child(rules)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(btn_row)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	MassSimTheme.style_button(cancel_btn)
	cancel_btn.pressed.connect(func() -> void: _new_epoch_dialog.hide())
	btn_row.add_child(cancel_btn)
	var ok_btn := Button.new()
	ok_btn.text = "Start Fresh Epoch"
	MassSimTheme.style_button(ok_btn)
	ok_btn.pressed.connect(_on_new_epoch_confirmed)
	btn_row.add_child(ok_btn)
	add_child(_new_epoch_dialog)


func _open_new_epoch_dialog() -> void:
	if _epoch_label_edit != null:
		_epoch_label_edit.text = ""
	_new_epoch_dialog.popup_centered(Vector2i(440, 248))


func _on_new_epoch_confirmed() -> void:
	var label: String = _epoch_label_edit.text.strip_edges() if _epoch_label_edit != null else ""
	_new_epoch_dialog.hide()
	var entry: Dictionary = MassSimRulesEpoch.start_new_epoch(_workspace, label)
	_sync_log_path_from_epoch()
	_save_workspace()
	_load_saved_results()
	status_label.text = "New epoch: %s → %s" % [String(entry.get("label", "")), _log_path]


func _rebuild_tag_filter() -> void:
	var tags: Dictionary = {}
	for row: Dictionary in _all_rows:
		for t: Variant in row.get("map_tags", []):
			tags[str(t)] = true
	_tag_filter.clear()
	_tag_filter.add_item("All tags")
	var idx: int = 0
	var select: int = 0
	for tag: Variant in tags.keys():
		idx += 1
		_tag_filter.add_item(str(tag))
		if str(tag) == _workspace.map_tag_filter:
			select = idx
	_tag_filter.select(select)


func _on_tag_filter_changed(index: int) -> void:
	_workspace.map_tag_filter = "" if index <= 0 else _tag_filter.get_item_text(index)
	_save_workspace()
	_load_saved_results()


func _apply_report() -> void:
	var warnings: Array = TriageEngine.evaluate_report(_report)
	var l1: Level1SummaryPanel = _panels.get("L1: Executive Summary") as Level1SummaryPanel
	if l1 != null:
		l1.bind_report(_report, warnings, _workspace)
	for tab_name: String in _panels.keys():
		if tab_name == "L1: Executive Summary":
			continue
		var panel: Node = _panels[tab_name]
		if panel != null and panel.has_method("bind_report"):
			panel.call("bind_report", _report)
	_refresh_command_palette()
	_write_interpretation_bundle(warnings)


func _write_interpretation_bundle(warnings: Array) -> void:
	MassSimInterpretationExport.write_bundle(_report, warnings, {
		"log_path": _log_path,
		"rows_in_file": _all_rows.size(),
		"map_tag_filter": _workspace.map_tag_filter,
		"active_epoch_id": _workspace.active_epoch_id,
		"active_epoch_label": String(MassSimRulesEpoch.active_epoch(_workspace).get("label", "")),
		"rules_fingerprint": _batch_epoch_fingerprint(),
		"queue_size": _job_queue.size(),
		"running_job": _running_job,
	})


func _refresh_command_palette() -> void:
	var entries: Array[Dictionary] = []
	var tabs: PackedStringArray = PackedStringArray([
		"L1: Executive Summary", "L2: Balance & Synergy", "L3: Economy & Math",
		"L4: Physics Heatmaps", "L5: AI Diagnostics", "L6: Map Bias", "L7: Integrity",
	])
	for i: int in range(tabs.size()):
		entries.append({
			"label": "Tab: %s" % tabs[i],
			"title": tabs[i],
			"body": "Switch to tab %d." % (i + 1),
			"meta": {"tab_index": i},
		})
	for key: String in ["best_performance_id", "worst_performance_id", "median_match_id", "biggest_upset_id", "most_chaotic_id"]:
		var rid: int = int(_report.curator.get(key, -1))
		entries.append({
			"label": "Replay %s #%d" % [key, rid],
			"title": "Curated Replay",
			"body": MassSimReplayFormat.format_run(_report, rid) if rid >= 0 else "N/A",
			"meta": {"run_id": rid, "replay_key": key},
		})
	for row: Dictionary in _report.tier_rows:
		entries.append({
			"label": "Class: %s" % _report.class_display_name(row.get("class_id", "")),
			"title": "Class Tier",
			"body": "Tier %s · %.1f%% WR" % [row.get("tier", "?"), float(row.get("win_rate", 0.0))],
			"meta": row,
		})
	for tag: Variant in _report.map_tag_records.keys():
		var rec: Dictionary = _report.map_tag_records[tag] as Dictionary
		entries.append({
			"label": "Map tag: %s" % str(tag),
			"title": "Map Bias",
			"body": "Player WR %.1f%% (%d matches)" % [float(rec.get("player_win_pct", 0)), int(rec.get("battles", 0))],
			"meta": {"map_tag": str(tag)},
		})
	command_palette.set_entries(entries)


func _on_palette_item(title: String, body: String, meta: Dictionary) -> void:
	if meta.has("tab_index"):
		tab_container.current_tab = int(meta["tab_index"])
	if meta.has("run_id"):
		_open_replay(int(meta["run_id"]))
	else:
		_on_inspect(title, body, meta)


func _on_inspect(title: String, body: String, meta: Dictionary = {}) -> void:
	inspector.update_context(title, body, meta)
	if meta.has("run_id"):
		inspector.show_replay(_report, int(meta["run_id"]))


func _open_replay(run_id: int) -> void:
	inspector.show_replay(_report, run_id)


func _pin_replay(run_id: int) -> void:
	if run_id < 0:
		return
	if not _workspace.pinned_run_ids.has(run_id):
		_workspace.pinned_run_ids.append(run_id)
	_save_workspace()
	status_label.text = "Pinned replay #%d" % run_id


func _open_file_dialog() -> void:
	_file_dialog.popup_centered(Vector2i(700, 420))


func _on_file_selected(path: String) -> void:
	_log_path = path
	_workspace.log_path = path
	_save_workspace()
	_load_saved_results()


func _open_interpretation_folder() -> void:
	var dir: String = ProjectSettings.globalize_path(MassSimConstants.CAPTURE_DIR)
	DisplayServer.clipboard_set(dir)
	status_label.text = "Report folder: %s (path copied)" % dir


func _export_csv() -> void:
	var export_path := "user://batch_results_export.csv"
	var file: FileAccess = FileAccess.open(export_path, FileAccess.WRITE)
	if file == null:
		status_label.text = "CSV export failed."
		return
	file.store_line("run_id,winner,turns,layout,player_quadrant,wall_collisions,execution_whiffs")
	for row: Dictionary in _all_rows:
		file.store_line(
			"%d,%d,%d,%s,%s,%d,%d"
			% [
				int(row.get("run_id", -1)),
				int(row.get("winner", -1)),
				int(row.get("turns_taken", 0)),
				String(row.get("map_layout_id", "")),
				String(row.get("player_spawn_quadrant", "")),
				int(row.get("wall_collisions", 0)),
				int(row.get("execution_whiffs", 0)),
			]
		)
	file.close()
	status_label.text = "Exported CSV → %s" % export_path


func _save_workspace() -> void:
	_workspace.last_tab = tab_container.current_tab
	_workspace.log_path = _log_path
	_workspace.save()


func _flat_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style


## Agent/capture harness: same facts a human sees on open (status, tabs, report, triage).
func export_visual_snapshot() -> Dictionary:
	var warnings: Array = TriageEngine.evaluate_report(_report)
	var queue_items: PackedStringArray = PackedStringArray()
	for i: int in range(queue_list.item_count):
		queue_items.append(queue_list.get_item_text(i))
	var snap: Dictionary = {
		"scene": "MassSimDashboard",
		"captured_at_unix": Time.get_unix_time_from_system(),
		"viewport_size": [size.x, size.y],
		"status_text": status_label.text if status_label != null else "",
		"current_tab_index": tab_container.current_tab if tab_container != null else 0,
		"current_tab_title": tab_container.get_tab_title(tab_container.current_tab) if tab_container != null else "",
		"tag_filter": _tag_filter.get_item_text(_tag_filter.selected) if _tag_filter != null else "",
		"log_path": _log_path,
		"rows_in_file": _all_rows.size(),
		"queue_items": queue_items,
		"jobs_running": _running_job,
		"progress": {
			"visible": progress_bar.visible if progress_bar != null else false,
			"value": progress_bar.value if progress_bar != null else 0.0,
			"max": progress_bar.max_value if progress_bar != null else 0.0,
		},
		"inspector_title": inspector.title_label.text if inspector != null else "",
		"inspector_preview": _truncate(inspector.details_rich_text.text if inspector != null else "", 1200),
		"triage_warning_titles": _warning_titles(warnings),
		"report_empty": _report == null or _report.is_empty(),
	}
	if _report != null and not _report.is_empty():
		snap["report"] = {
			"total_battles": _report.total_battles,
			"player_win_pct": _report.player_win_pct,
			"enemy_win_pct": _report.enemy_win_pct,
			"avg_turns": _report.avg_turns,
			"integrity_score": _report.integrity_score,
			"meta_diversity_pct": _report.meta_diversity_pct,
			"unique_classes": _report.unique_classes_seen,
			"tier_top": _report.tier_rows[0] if not _report.tier_rows.is_empty() else {},
		}
	snap["tab_labels"] = _tab_labels()
	snap["visible_ui_text"] = _collect_visible_ui_text(self, 6000)
	return snap


func _warning_titles(warnings: Array) -> PackedStringArray:
	var titles: PackedStringArray = PackedStringArray()
	for w: Variant in warnings:
		if w is Dictionary:
			titles.append(String((w as Dictionary).get("title", "")))
	return titles


func _tab_labels() -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	if tab_container == null:
		return labels
	for i: int in range(tab_container.get_tab_count()):
		labels.append(tab_container.get_tab_title(i))
	return labels


func _truncate(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len) + "…"


func _collect_visible_ui_text(node: Node, budget: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	_collect_visible_ui_text_recursive(node, lines, {"remaining": budget})
	return lines


func _collect_visible_ui_text_recursive(node: Node, lines: PackedStringArray, state: Dictionary) -> void:
	if int(state["remaining"]) <= 0:
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	var line: String = ""
	if node is Label:
		line = (node as Label).text.strip_edges()
	elif node is RichTextLabel:
		line = (node as RichTextLabel).text.strip_edges()
	elif node is Button:
		line = (node as Button).text.strip_edges()
	if not line.is_empty():
		var entry: String = "%s: %s" % [str(node.get_path()).replace(str(get_path()), "."), line]
		lines.append(entry)
		state["remaining"] = int(state["remaining"]) - entry.length()
	for child: Node in node.get_children():
		_collect_visible_ui_text_recursive(child, lines, state)
