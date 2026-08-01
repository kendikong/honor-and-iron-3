class_name AutobattlerHookRegistry
extends RefCounted

## Purpose: Hooks the Autobattler into the game loop (CombatDirector).
## Responsibilities: Registers signal callbacks when the combat director starts the planning phase, overriding human input when active.

var _ai_instance: AutobattlerAI
var _active: bool = false
var _auto_commit: bool = true  ## True = Full Autobattle. False = planning assist (user presses Execute).
var _combat_director = null
var _unit_layer: TacticalUnitLayer = null
var _planning_run_id: int = 0

func _init(director) -> void:
	_combat_director = director
	_ai_instance = AutobattlerAI.new()


func set_unit_layer(layer: TacticalUnitLayer) -> void:
	_unit_layer = layer

func set_active(active: bool, auto_commit: bool = true) -> void:
	_active = active
	_auto_commit = auto_commit
	_planning_run_id += 1
	
	if _active:
		if not EventBus.turn_phase_changed.is_connected(Callable(self, "_on_turn_phase_changed")):
			EventBus.turn_phase_changed.connect(Callable(self, "_on_turn_phase_changed"))
		var current_phase = _combat_director.phase
		if CombatDirector.is_planning_phase(current_phase):
			print("[Autobattler] Activated mid-planning, acting immediately.")
			_on_turn_phase_changed(current_phase)
	else:
		if EventBus.turn_phase_changed.is_connected(Callable(self, "_on_turn_phase_changed")):
			EventBus.turn_phase_changed.disconnect(Callable(self, "_on_turn_phase_changed"))

func _on_turn_phase_changed(phase: int) -> void:
	if not _active:
		return
	
	if CombatDirector.is_executing_phase(phase):
		return
	elif not CombatDirector.is_planning_phase(phase):
		return

	var run_id: int = _planning_run_id
		
	print("[Autobattler] start planning")
	
	var board: BoardState = _combat_director.base_board
	if board == null:
		return

	_combat_director.clear_plan()

	print("[Autobattler] === START COMMANDER PIPELINE ===")
	await Engine.get_main_loop().process_frame
	if run_id != _planning_run_id or not _active:
		return
	
	var vector = _ai_instance.decide_team_vector(board)
	
	_combat_director.begin_autobattler_plan_batch()
	if vector != null:
		print("[Autobattler] Found Team Vector (Utility: %.2f)" % vector.utility_score)
		
		var actions_by_unit = {}
		for act in vector.actions:
			if not actions_by_unit.has(act.actor_id):
				actions_by_unit[act.actor_id] = []
			actions_by_unit[act.actor_id].append(act)
			
		for u_id in actions_by_unit:
			var unit: UnitState = board.get_unit_by_id(u_id)
			if unit != null and unit.is_alive() and not unit.is_enemy():
				_commit_unit_actions(board, actions_by_unit[u_id], unit, vector.telemetry)
		
		if EventBus.has_user_signal("ai_telemetry_generated") or true:
			EventBus.ai_telemetry_generated.emit(vector.telemetry)
	else:
		print("[Autobattler] No valid vectors found or no units alive.")

	_ensure_alive_units_planned()
	await _combat_director.finish_autobattler_plan_batch(_unit_layer)
	if run_id != _planning_run_id or not _active:
		return

	if _auto_commit:
		if board != null and not board.has_living_team(GameEnums.Team.PLAYER):
			return
		if _combat_director.get_player_plan().size() == 0:
			print("[Autobattler] No committable plan — skipping auto-ready")
			return
		if NetworkManager != null and NetworkManager.is_multiplayer and NetworkManager.multiplayer.has_multiplayer_peer():
			GlobalTimeline.rpc_set_ready.rpc(true)
		else:
			GlobalTimeline.rpc_set_ready(true)


func _ensure_alive_units_planned() -> void:
	var board: BoardState = _combat_director.base_board
	if board == null:
		return
	for unit: UnitState in board.units:
		if not unit.is_alive() or unit.is_enemy():
			continue
		if _unit_already_planned(unit.id):
			continue
		_combat_director.rpc_plan_wait(unit.id)


func _unit_already_planned(unit_id: int) -> bool:
	if _combat_director.unit_has_wait_planned(unit_id):
		return true
	for action: TimelineAction in _combat_director.plan_pre_move.entries:
		if action.actor_id == unit_id:
			return true
	for action: TimelineAction in _combat_director.plan_action.entries:
		if action.actor_id == unit_id:
			return true
	for action: TimelineAction in _combat_director.plan_post_move.entries:
		if action.actor_id == unit_id:
			return true
	return false

func _commit_unit_actions(board: BoardState, actions: Array, unit: UnitState, telemetry: Dictionary) -> void:
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
		print("planning - %s (%d) - skill (%d) target (%d) - score = %s" % [u_class, unit.id, ab_idx, target_id, score_breakdown])
		_combat_director.rpc_plan_attack_with_approach(unit.id, ab_idx, target_id, dest)
	elif dest != unit.position:
		print("planning - %s (%d) - move from (%d,%d) to (%d,%d) - score = %s" % [u_class, unit.id, unit.position.x, unit.position.y, dest.x, dest.y, score_breakdown])
		if waypoints.is_empty():
			var max_steps := unit.movement.max_points if unit.movement != null else 0
			var mov_type := unit.definition.movement_type if unit.definition != null else GameEnums.MovementType.WALK
			waypoints = MovementSystem.find_path(board, unit.position, dest, max_steps, mov_type)
		_combat_director.rpc_plan_move(unit.id, dest, unit.facing, waypoints)
