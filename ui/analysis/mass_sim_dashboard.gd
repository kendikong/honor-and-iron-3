class_name MassSimDashboard
extends Control

# Global singleton-like reference for the UI context
static var instance: MassSimDashboard

var main_split: HSplitContainer
var tab_container: TabContainer

var inspector: UniversalInspectorPanel
var command_palette: CommandPaletteModal
var batch_runner: MassBattleRunner

var progress_bar: ProgressBar

func _ready() -> void:
	instance = self
	
	# Base styling
	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Layout
	main_split = HSplitContainer.new()
	main_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(main_split)
	
	var left_side = VBoxContainer.new()
	left_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.add_child(left_side)
	
	# Header controls
	var header = HBoxContainer.new()
	left_side.add_child(header)
	
	var title = Label.new()
	title.text = "Mass Simulation Analytics"
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)
	
	var run_btn = Button.new()
	run_btn.text = "Run Batch (100)"
	run_btn.pressed.connect(_on_run_pressed)
	header.add_child(run_btn)
	
	progress_bar = ProgressBar.new()
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.visible = false
	header.add_child(progress_bar)
	
	# Tab Container for Levels
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_side.add_child(tab_container)
	
	# Build Tabs
	_build_tabs()
	
	# Right-side Inspector
	inspector = UniversalInspectorPanel.new()
	main_split.add_child(inspector)
	
	# Command Palette
	command_palette = CommandPaletteModal.new()
	add_child(command_palette)
	
	batch_runner = MassBattleRunner.new()
	add_child(batch_runner)
	batch_runner.batch_progress.connect(_on_batch_progress)
	batch_runner.batch_completed.connect(_on_batch_completed)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_K and event.is_command_or_control_pressed():
			command_palette.popup_palette()
			get_viewport().set_input_as_handled()

func _build_tabs() -> void:
	# Stubs for the 7 levels. To be expanded in later phases.
	var levels = [
		"L1: Executive Summary",
		"L2: Balance & Synergy",
		"L3: Economy & Math",
		"L4: Physics Heatmaps",
		"L5: AI Diagnostics",
		"L6: Map Bias",
		"L7: Integrity"
	]
	
	for lvl_name in levels:
		var panel = Panel.new()
		panel.name = lvl_name
		var lbl = Label.new()
		lbl.text = "Content for %s" % lvl_name
		lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		panel.add_child(lbl)
		tab_container.add_child(panel)

func _on_run_pressed() -> void:
	progress_bar.visible = true
	progress_bar.value = 0
	progress_bar.max_value = 100
	
	inspector.update_context("Running Batch...", "Simulating 100 battles on background threads.\nPlease wait...")
	batch_runner.start_batch(100)

func _on_batch_progress(completed: int, total: int) -> void:
	progress_bar.value = completed
	progress_bar.max_value = total
	inspector.update_context("Batch Progress", "Completed: %d / %d" % [completed, total])

func _on_batch_completed(path: String, stats: Dictionary) -> void:
	progress_bar.visible = false
	var msg = "Batch completed successfully!\n\n"
	msg += "[b]File:[/b] %s\n" % path
	msg += "[b]Best Replay ID:[/b] %d\n" % stats.get("best_performance_id", -1)
	msg += "[b]Worst Replay ID:[/b] %d\n" % stats.get("worst_performance_id", -1)
	msg += "[b]Median Match ID:[/b] %d\n" % stats.get("median_match_id", -1)
	msg += "[b]Biggest Upset ID:[/b] %d\n" % stats.get("biggest_upset_id", -1)
	msg += "[b]Most Chaotic ID:[/b] %d\n" % stats.get("most_chaotic_id", -1)
	
	inspector.update_context("Batch Complete", msg)
