class_name AnalysisDashboard
extends Control

## Purpose: UI dashboard to view mass simulation results.
## Responsibilities: Parses JSONL output from MassBattleRunner, calculates winrates and aggregate statistics, and provides a CSV export.

var _file_path: String = "user://batch_results.jsonl"
var _results: Array = []

var _summary_label: RichTextLabel
var _load_btn: Button
var _export_btn: Button

func _ready() -> void:
	custom_minimum_size = Vector2(800, 600)
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var header = Label.new()
	header.text = "Autobattler Mass Simulation Analytics"
	header.add_theme_font_size_override("font_size", 24)
	vbox.add_child(header)
	
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	_load_btn = Button.new()
	_load_btn.text = "Load JSONL Results"
	_load_btn.pressed.connect(Callable(self, "_on_load_pressed"))
	hbox.add_child(_load_btn)
	
	_export_btn = Button.new()
	_export_btn.text = "Export to CSV"
	_export_btn.disabled = true
	_export_btn.pressed.connect(Callable(self, "_on_export_pressed"))
	hbox.add_child(_export_btn)
	
	_summary_label = RichTextLabel.new()
	_summary_label.bbcode_enabled = true
	_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_summary_label)

func _on_load_pressed() -> void:
	_results.clear()
	if not FileAccess.file_exists(_file_path):
		_summary_label.text = "[color=red]File not found:[/color] " + _file_path
		return
		
	var file = FileAccess.open(_file_path, FileAccess.READ)
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var json = JSON.new()
		if json.parse(line) == OK:
			_results.append(json.data)
			
	file.close()
	_update_summary()

func _update_summary() -> void:
	if _results.is_empty():
		_summary_label.text = "No results loaded."
		_export_btn.disabled = true
		return
		
	_export_btn.disabled = false
	
	var total_battles = _results.size()
	var p1_wins = 0
	var p2_wins = 0
	var draws = 0
	var total_turns = 0
	
	for res in _results:
		if res.has("winner"):
			var w = res["winner"] as int
			if w == GameEnums.Team.PLAYER:
				p1_wins += 1
			elif w == GameEnums.Team.ENEMY:
				p2_wins += 1
			else:
				draws += 1
		if res.has("turns_taken"):
			total_turns += res["turns_taken"]
			
	var avg_turns = float(total_turns) / float(total_battles)
	
	var text = "[b]Total Battles:[/b] %d\n" % total_battles
	text += "[color=blue]Team 1 (Player) Wins:[/color] %d (%.1f%%)\n" % [p1_wins, (float(p1_wins) / total_battles) * 100.0]
	text += "[color=red]Team 2 (Enemy) Wins:[/color] %d (%.1f%%)\n" % [p2_wins, (float(p2_wins) / total_battles) * 100.0]
	text += "Draws: %d\n" % draws
	text += "Average Turns: %.1f\n" % avg_turns
	
	_summary_label.text = text

func _on_export_pressed() -> void:
	var export_path = "user://batch_results_export.csv"
	var file = FileAccess.open(export_path, FileAccess.WRITE)
	if file == null:
		print("Failed to open export file.")
		return
		
	file.store_line("run_id,winner,turns_taken,surviving_units")
	for res in _results:
		var run_id = res.get("run_id", -1)
		var winner = res.get("winner", GameEnums.Team.NEUTRAL)
		var turns = res.get("turns_taken", 0)
		var surv = ""
		if res.has("units_surviving"):
			surv = str(res["units_surviving"]).replace(",", ";") # Replace commas to avoid CSV break
		
		file.store_line("%d,%d,%d,%s" % [run_id, winner, turns, surv])
		
	file.close()
	print("Exported CSV to: ", export_path)
