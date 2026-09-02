extends Node

const OUT := "user://debug_sidestep_premove_drag.txt"
const QaGate := preload("res://tests/harness/planning_qa_gate_test.gd")
const ARCHER_SIDESTEP_ID: StringName = &"archer_sidestep"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var lines: PackedStringArray = PackedStringArray()
	var host := Node.new()
	add_child(host)
	PlanningDragE2EHarness.set_host(host)
	var start := Vector2i(2, 2)
	var route: Array[Vector2i] = [
		Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3),
		Vector2i(3, 4), Vector2i(4, 4),
	]
	var fix: Dictionary = QaGate._archer_skill_fixture(start, Vector2i(5, 4), ARCHER_SIDESTEP_ID)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var map_stub: QaPlanningMapStub = QaPlanningMapStub.new()
	fix["map_stub"] = map_stub
	input._map_view = map_stub
	director.selected_ability_index = -1
	input._on_ability_selected(-1)
	lines.append("after deselect drag=%s orbit=%s" % [
		str(input._drag_route),
		str(input._voluntary_walk_orbit_phase_open(fix.archer)),
	])
	PlanningChecklistHarness.hover(fix, route[0])
	lines.append("after hover0 drag=%s" % str(input._drag_route))
	var previous: Vector2i = route[0]
	for i: int in range(1, route.size()):
		var waypoint: Vector2i = route[i]
		PlanningChecklistHarness.sweep_to_cell(fix, waypoint, previous)
		lines.append("after sweep %s drag=%s commits=%s" % [
			str(waypoint),
			str(input._drag_route),
			str(input._drag_route_commits_active()),
		])
		previous = waypoint
	lines.append("FINAL drag=%s expected=%s match=%s" % [
		str(input._drag_route), str(route), str(input._drag_route == route),
	])
	PlanningDragE2EHarness.cleanup_all()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	for line: String in lines:
		if f != null:
			f.store_line(line)
		print(line)
	get_tree().quit()
