class_name AutobattlerHookRegistry
extends RefCounted

## Purpose: Hooks the Autobattler into the game loop (CombatDirector).
## Responsibilities: Registers signal callbacks when the combat director starts the planning phase, overriding human input when active.

var _ai_instance: AutobattlerAI
var _active: bool = false
var _auto_commit: bool = true  ## True = Full Autobattle. False = Phase Autobattle (user presses Execute).
var _combat_director = null

func _init(director) -> void:
	_combat_director = director
	_ai_instance = AutobattlerAI.new()

func set_active(active: bool, auto_commit: bool = true) -> void:
	_active = active
	_auto_commit = auto_commit
	
	if _active:
		if not EventBus.turn_phase_changed.is_connected(Callable(self, "_on_turn_phase_changed")):
			EventBus.turn_phase_changed.connect(Callable(self, "_on_turn_phase_changed"))
		var current_phase = _combat_director.phase
		if current_phase == CombatDirector.Phase.PLANNING_PHASE_1 or current_phase == CombatDirector.Phase.PLANNING_PHASE_2:
			print("[Autobattler] Activated mid-phase, acting immediately.")
			_on_turn_phase_changed(current_phase)
	else:
		if EventBus.turn_phase_changed.is_connected(Callable(self, "_on_turn_phase_changed")):
			EventBus.turn_phase_changed.disconnect(Callable(self, "_on_turn_phase_changed"))

func _on_turn_phase_changed(phase: int) -> void:
	if not _active:
		return
	
	if phase == CombatDirector.Phase.EXECUTING_PHASE_1 or phase == CombatDirector.Phase.EXECUTING_PHASE_2:
		return
	elif phase != CombatDirector.Phase.PLANNING_PHASE_1 and phase != CombatDirector.Phase.PLANNING_PHASE_2:
		return
		
	if phase == CombatDirector.Phase.PLANNING_PHASE_1:
		print("start planning phase 1")
	elif phase == CombatDirector.Phase.PLANNING_PHASE_2:
		print("start planning phase 2")
	
	var board = _combat_director.base_board
	if board == null:
		return

	# When planning phase starts, Autobattler controls player units.
	# Clear all existing plans (using clear_plan to bypass occupancy guards).
	_combat_director.clear_plan()

	print("[Autobattler] === START COMMANDER PIPELINE ===")
	# Yield once before heavy math to ensure frame renders
	await Engine.get_main_loop().process_frame
	
	var vector = _ai_instance.decide_team_vector(board)
	
	if vector != null:
		print("[Autobattler] Found Team Vector (Utility: %.2f)" % vector.utility_score)
		
		var actions_by_unit = {}
		for act in vector.actions:
			if not actions_by_unit.has(act.actor_id):
				actions_by_unit[act.actor_id] = []
			actions_by_unit[act.actor_id].append(act)
			
		for u_id in actions_by_unit:
			var unit = board.get_unit_by_id(u_id)
			if unit != null:
				_commit_unit_actions(board, actions_by_unit[u_id], unit, phase, vector.telemetry)
		
		if EventBus.has_user_signal("ai_telemetry_generated") or true:
			EventBus.ai_telemetry_generated.emit(vector.telemetry)
	else:
		print("[Autobattler] No valid vectors found or no units alive.")

	# All units planned — signal ready to trigger execution if in Full Autobattle mode
	if _auto_commit:
		if NetworkManager != null and NetworkManager.is_multiplayer and NetworkManager.multiplayer.has_multiplayer_peer():
			GlobalTimeline.rpc_set_ready.rpc(true)
		else:
			GlobalTimeline.rpc_set_ready(true)

func _commit_unit_actions(board: BoardState, actions: Array, unit: UnitState, phase: int, telemetry: Dictionary) -> void:
	var phase_num = 1 if phase == CombatDirector.Phase.PLANNING_PHASE_1 else 2
	var score_breakdown = "[Team Util: %.1f]" % telemetry.get("total", 0.0)
	var u_class := unit.definition.display_name if (unit.definition != null and unit.definition.display_name != "") else "Unit"
	
	var dest = unit.position
	var ability = null
	var target_id = -1
	var waypoints = []
	
	for act in actions:
		if act.type == GameEnums.ActionType.MOVE:
			dest = act.target_coord
			waypoints = act.waypoints.duplicate()
		elif act.type == GameEnums.ActionType.ABILITY:
			ability = act.ability
			target_id = act.target_unit_id
			
	if ability != null:
		var ab_idx = -1
		for i in range(unit.active_abilities.size()):
			if unit.active_abilities[i] == ability:
				ab_idx = i
				break
		print("phase (%d) - %s (%d) - skill (%d) target (%d) - score = %s" % [phase_num, u_class, unit.id, ab_idx, target_id, score_breakdown])
		_combat_director.rpc_plan_attack_with_approach(unit.id, ab_idx, target_id, dest)
	elif dest != unit.position:
		print("phase (%d) - %s (%d) - move from (%d,%d) to (%d,%d) - score = %s" % [phase_num, u_class, unit.id, unit.position.x, unit.position.y, dest.x, dest.y, score_breakdown])
		if waypoints.is_empty():
			var max_steps := unit.movement.max_points if unit.movement != null else 0
			var mov_type := unit.definition.movement_type if unit.definition != null else GameEnums.MovementType.WALK
			waypoints = MovementSystem.find_path(board, unit.position, dest, max_steps, mov_type)
		_combat_director.rpc_plan_move(unit.id, dest, unit.facing, waypoints)

