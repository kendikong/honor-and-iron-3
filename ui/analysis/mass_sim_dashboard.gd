class_name MassSimDashboard
extends Control

## Mass Simulation Analytics — triage environment per dashboard bible.

static var instance: MassSimDashboard

var main_split: HSplitContainer
var tab_container: TabContainer
var inspector: UniversalInspectorPanel
var command_palette: CommandPaletteModal
var batch_runner: MassBattleRunner
var progress_bar: ProgressBar
var status_label: Label
var queue_list: ItemList

var _report: MassSimBatchReport
var _log_path: String = MassSimConstants.DEFAULT_LOG_PATH
var _job_queue: Array[Dictionary] = []
var _running_job: bool = false
var _panels: Dictionary = {}


func _ready() -> void:
	instance = self
	_report = MassSimBatchReport.new()
	_build_chrome()
	_build_tabs()
	_bind_runner()
	_load_saved_results()
	_refresh_command_palette()


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

	var back_btn := Button.new()
	back_btn.text = "← Main Menu"
	MassSimTheme.style_button(back_btn)
	back_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	header.add_child(back_btn)

	var title := Label.new()
	title.text = "Mass Simulation Analytics"
	MassSimTheme.style_title(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var reload_btn := Button.new()
	reload_btn.text = "Reload Results"
	MassSimTheme.style_button(reload_btn)
	reload_btn.pressed.connect(_load_saved_results)
	header.add_child(reload_btn)

	var run_btn := Button.new()
	run_btn.text = "Run Queue"
	MassSimTheme.style_button(run_btn)
	run_btn.pressed.connect(_start_queue)
	header.add_child(run_btn)

	var add_job_btn := Button.new()
	add_job_btn.text = "+ Job (100)"
	MassSimTheme.style_button(add_job_btn)
	add_job_btn.pressed.connect(func() -> void: _enqueue_job("Baseline", 100))
	header.add_child(add_job_btn)

	progress_bar = ProgressBar.new()
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size.x = 120
	progress_bar.visible = false
	header.add_child(progress_bar)

	status_label = Label.new()
	MassSimTheme.style_muted(status_label)
	status_label.text = "Ready"
	left.add_child(status_label)

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
	queue_list.custom_minimum_size = Vector2(0, 72)
	queue_vbox.add_child(queue_list)

	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(tab_container)

	inspector = UniversalInspectorPanel.new()
	main_split.add_child(inspector)

	command_palette = CommandPaletteModal.new()
	add_child(command_palette)
	command_palette.item_selected.connect(_on_palette_item)

	if _job_queue.is_empty():
		_enqueue_job("Baseline Batch", 100)


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
	status_label.text = "Running: %s" % label
	progress_bar.visible = true
	progress_bar.value = 0
	progress_bar.max_value = count
	inspector.update_context(
		"Running Batch",
		"[b]%s[/b]\nSimulating %d battles on background threads…" % [label, count],
	)
	batch_runner.start_batch(count, _log_path)


func _on_batch_progress(completed: int, total: int) -> void:
	progress_bar.value = completed
	progress_bar.max_value = total
	inspector.update_context("Batch Progress", "Completed: %d / %d" % [completed, total])


func _on_batch_completed(path: String, stats: Dictionary) -> void:
	_load_saved_results()
	var msg := "[b]Batch saved[/b]\n%s\n\n" % path
	for key: String in ["best_performance_id", "worst_performance_id", "median_match_id", "biggest_upset_id", "most_chaotic_id"]:
		msg += "%s: [b]%s[/b]\n" % [key, str(stats.get(key, "—"))]
	inspector.update_context("Batch Complete", msg)
	MassSimAggregator.save_snapshot(_report)
	_run_next_job()


func _load_saved_results() -> void:
	var rows: Array[Dictionary] = MassSimAggregator.load_jsonl(_log_path)
	var curator: Dictionary = {}
	if not rows.is_empty():
		var curator_obj := SmartReplayCurator.new()
		curator_obj.curate(rows)
		curator = curator_obj.to_dict()
	_report = MassSimAggregator.build_report(rows, _log_path, curator)
	_apply_report()
	status_label.text = (
		"%d battles loaded from %s" % [_report.total_battles, _log_path]
		if not _report.is_empty()
		else "No results file — queue a batch to begin"
	)


func _apply_report() -> void:
	var warnings: Array = TriageEngine.evaluate_report(_report)
	var l1: Level1SummaryPanel = _panels.get("L1: Executive Summary") as Level1SummaryPanel
	if l1 != null:
		l1.bind_report(_report, warnings)
	var l2: Level2BalancePanel = _panels.get("L2: Balance & Synergy") as Level2BalancePanel
	if l2 != null:
		l2.bind_report(_report)
	for tab_name: String in [
		"L3: Economy & Math", "L4: Physics Heatmaps", "L5: AI Diagnostics",
		"L6: Map Bias", "L7: Integrity",
	]:
		var panel: Node = _panels.get(tab_name)
		if panel != null and panel.has_method("bind_report"):
			panel.call("bind_report", _report)
	_refresh_command_palette()


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
			"body": "Switch to analytics tab %d." % (i + 1),
			"meta": {"tab_index": i},
		})
	for key: String in ["best_performance_id", "worst_performance_id", "median_match_id", "biggest_upset_id", "most_chaotic_id"]:
		entries.append({
			"label": "Replay %s: %s" % [key, str(_report.curator.get(key, "—"))],
			"title": "Curated Replay",
			"body": "Open match run_id %s in future replay viewer." % str(_report.curator.get(key, "—")),
			"meta": {"replay_key": key, "run_id": _report.curator.get(key, -1)},
		})
	for row: Dictionary in _report.tier_rows:
		entries.append({
			"label": "Class: %s" % _report.class_display_name(row.get("class_id", "")),
			"title": "Class Tier",
			"body": "Tier %s · %.1f%% WR" % [row.get("tier", "?"), float(row.get("win_rate", 0.0))],
			"meta": row,
		})
	command_palette.set_entries(entries)


func _on_palette_item(title: String, body: String, meta: Dictionary) -> void:
	if meta.has("tab_index"):
		tab_container.current_tab = int(meta["tab_index"])
	_on_inspect(title, body, meta)


func _on_inspect(title: String, body: String, meta: Dictionary = {}) -> void:
	inspector.update_context(title, body, meta)


func _flat_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style
