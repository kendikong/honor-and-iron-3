extends SceneTree

func _initialize() -> void:
	var script: GDScript = load("res://presentation/combat_planning_input.gd") as GDScript
	if script == null:
		push_error("[FAIL] Could not load combat_planning_input.gd")
		quit(1)
		return
	var inst: Variant = script.new()
	if inst == null:
		push_error("[FAIL] Could not instantiate CombatPlanningInput")
		quit(1)
		return
	print("[PASS] combat_planning_input.gd parses and instantiates")
	quit(0)
