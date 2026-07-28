class_name MassSimWorkspace
extends RefCounted

const _C = preload("res://core/batch/mass_sim_constants.gd")

var last_tab: int = 0
var log_path: String = _C.DEFAULT_LOG_PATH
var map_tag_filter: String = ""
var pinned_run_ids: Array[int] = []
var triage_states: Dictionary = {}
var triage_notes: Dictionary = {}

var active_epoch_id: String = ""
var epochs: Array[Dictionary] = []
var skirmish_setup: Dictionary = MassSimSkirmishSetup.defaults().to_dict()


static func load() -> MassSimWorkspace:
	var ws := MassSimWorkspace.new()
	if not FileAccess.file_exists(_C.WORKSPACE_PATH):
		return ws
	var file: FileAccess = FileAccess.open(_C.WORKSPACE_PATH, FileAccess.READ)
	if file == null:
		return ws
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		file.close()
		return ws
	file.close()
	var d: Dictionary = json.data as Dictionary
	ws.last_tab = int(d.get("last_tab", 0))
	ws.log_path = String(d.get("log_path", _C.DEFAULT_LOG_PATH))
	ws.map_tag_filter = String(d.get("map_tag_filter", ""))
	ws.pinned_run_ids.assign(d.get("pinned_run_ids", []))
	ws.triage_states = d.get("triage_states", {})
	ws.triage_notes = d.get("triage_notes", {})
	ws.active_epoch_id = String(d.get("active_epoch_id", ""))
	ws.skirmish_setup = d.get("skirmish_setup", MassSimSkirmishSetup.defaults().to_dict())
	var raw_epochs: Array = d.get("epochs", [])
	ws.epochs.clear()
	for ep: Variant in raw_epochs:
		if ep is Dictionary:
			ws.epochs.append(ep as Dictionary)
	MassSimRulesEpoch.ensure_default_epoch(ws)
	return ws


func save() -> void:
	var file: FileAccess = FileAccess.open(_C.WORKSPACE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"last_tab": last_tab,
		"log_path": log_path,
		"map_tag_filter": map_tag_filter,
		"pinned_run_ids": pinned_run_ids,
		"triage_states": triage_states,
		"triage_notes": triage_notes,
		"active_epoch_id": active_epoch_id,
		"epochs": epochs,
		"skirmish_setup": skirmish_setup,
	}))
	file.close()
