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
	var l1 = Level1SummaryPanel.new()
	l1.name = "L1: Executive Summary"
	tab_container.add_child(l1)
	
	var l2 = Level2BalancePanel.new()
	l2.name = "L2: Balance & Synergy"
	tab_container.add_child(l2)
	
	var l3 = Level3EconomyPanel.new()
	l3.name = "L3: Economy & Math"
	tab_container.add_child(l3)
	
	var l4 = Level4PhysicsPanel.new()
	l4.name = "L4: Physics Heatmaps"
	tab_container.add_child(l4)
	
	var l5 = Level5AIPanel.new()
	l5.name = "L5: AI Diagnostics"
	tab_container.add_child(l5)
	
	var l6 = Level6MapPanel.new()
	l6.name = "L6: Map Bias"
	tab_container.add_child(l6)
	
	var l7 = Level7IntegrityPanel.new()
	l7.name = "L7: Integrity"
	tab_container.add_child(l7)

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
	
	var engine = TriageEngine.new()
	var warnings = engine.evaluate_batch(stats, stats.get("total_battles", 100))
	
	var l1 = tab_container.get_node("L1: Executive Summary") as Level1SummaryPanel
	if l1 != null:
		# Use dummy win rates for now, normally computed from full telemetry
		var p_wins = 55
		var e_wins = 45
		l1.update_summary(engine, warnings, {"player_win_rate": p_wins, "enemy_win_rate": e_wins})
