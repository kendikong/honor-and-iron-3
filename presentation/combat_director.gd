class_name CombatDirector
extends Node

## Purpose: The bridge between the pure simulation and the visuals, and the turn
## state machine (constitution: "Combat should always exist in one state").
## Responsibilities: Own the live BoardState + the player's Timelines; expose a
##   planning API the view calls; run the SINGLE Simulator for previews (discard)
##   and execution (adopt); broadcast everything through EventBus. It delegates ALL
##   gameplay to Simulator and never computes outcomes itself.
## Dependencies: Simulator, BoardState, Timeline, TimelineAction, EnemyPlanner,
##   EventBus. Builds demo content from data definitions for bootstrap.
## Lifecycle: lives in Combat.tscn; start() is called once by the view after it has
##   subscribed to EventBus, so no initial signal is missed.

enum Phase {
	PLANNING_PHASE_1,
	PLANNING_PHASE_2,
	EXECUTING_PHASE_1,
	EXECUTING_PHASE_2,
	ENEMY_TURN,
	VICTORY,
	DEFEAT,
}

## Unit the cursor starts on; any living player unit can be selected by clicking.
const FIRST_PLAYER_ID: int = 1

## How long each kind of event lingers during animated playback, in seconds.
const MOVE_STEP_TIME: float = 0.24   ## seconds per tile of movement
const DASH_STEP_TIME: float = 0.08   ## seconds per tile during dash abilities
const ATTACK_ANIM_TIME: float = 0.35 ## how long attack animations take
const PUSH_ANIM_FALLBACK: float = 1.0 ## Safety timeout if push signal never arrives

var base_board: BoardState
var board: BoardState
var plan_phase_1: Timeline
var plan_phase_2: Timeline
var phase: Phase = Phase.PLANNING_PHASE_1
var selected_unit_id: int = -1
var selected_ability_index: int = 0
## Board after ONLY the player's queued actions (no enemy intents). Drives range,
## reachability and target highlights so they follow planned moves, not start tiles.
var projected_state: BoardState
var _run_id: int = 0
## Moves just added via _try_add_multiple that may need a planning commit animation.
var _commit_animate_actions: Array[TimelineAction] = []
## True after Phase 1 is executed for the current turn. Phase 1 plan entries are kept
## for UI display but must not be re-applied on top of base_board during Phase 2 planning.
var phase_1_executed: bool = false

var initial_board: BoardState
## Snapshot at the start of the current player turn (planning phase 1).
var turn_start_board: BoardState

func start() -> void:
	# Fallback to demo if nothing was passed
	base_board = _build_demo_encounter()
	initial_board = base_board.clone()
	_init_combat()

func start_from_encounter(encounter: EncounterData, player_assignments: Dictionary = {}) -> void:
	base_board = BoardFactory.build_from_encounter(encounter, player_assignments)
	initial_board = base_board.clone()
	_init_combat()

func start_from_custom(new_board: BoardState) -> void:
	base_board = new_board
	initial_board = base_board.clone()
	_init_combat()

func _init_combat() -> void:
	_run_id += 1
	board = base_board.clone()
	plan_phase_1 = Timeline.new()
	plan_phase_2 = Timeline.new()
	phase_1_executed = false
	_lock_enemy_intents()
	
	# Start with no unit selected
	selected_unit_id = -1
			
	selected_ability_index = 0
	_set_phase(Phase.PLANNING_PHASE_1)
	EventBus.board_changed.emit(board)
	EventBus.selection_changed.emit(selected_unit_id)
	EventBus.ability_selected.emit(selected_ability_index)
	_refresh_plan()
	_capture_turn_start()

func select_unit(unit_id: int) -> void:
	if phase != Phase.PLANNING_PHASE_1 and phase != Phase.PLANNING_PHASE_2:
		return
	if unit_id == -1:
		selected_unit_id = -1
		selected_ability_index = 0
		EventBus.selection_changed.emit(selected_unit_id)
		EventBus.ability_selected.emit(selected_ability_index)
		_refresh_plan()
		return
		
	var unit := board.get_unit_by_id(unit_id)
	if unit == null or not unit.is_alive():
		return
	var switched := unit_id != selected_unit_id
	selected_unit_id = unit_id
	if not switched:
		return  # Re-grabbing the same unit must not reset the chosen ability.
	selected_ability_index = 0
	EventBus.selection_changed.emit(selected_unit_id)
	EventBus.ability_selected.emit(selected_ability_index)
	_refresh_plan()

## Choose which of the selected unit's abilities a queued attack will use.
func select_ability(index: int) -> void:
	if phase != Phase.PLANNING_PHASE_1 and phase != Phase.PLANNING_PHASE_2:
		return
	var unit := board.get_unit_by_id(selected_unit_id)
	if unit == null or index < 0 or index >= unit.active_abilities.size():
		return
	selected_ability_index = index
	EventBus.ability_selected.emit(selected_ability_index)

func _get_planning_state(target_phase: int) -> BoardState:
	var state := base_board.clone()
	var ev: Array[SimEvent] = []
	if target_phase > 1:
		_apply_phase_1_plan_to_state(state, ev)
	return state

## Apply queued Phase 1 plan to a cloned board. Skipped once Phase 1 has been executed
## because base_board already reflects those committed actions.
func _apply_phase_1_plan_to_state(state: BoardState, events: Array[SimEvent]) -> void:
	if phase_1_executed:
		return
	for a in plan_phase_1.entries:
		ResolutionPipeline.apply_action(state, a, events)
	ResolutionPipeline.resolve_pending_pushes(state, events)
	_apply_phase_1_to_2_transition(state)

func _get_target_phase(unit_id: int) -> int:
	var p_unit := projected_state.get_unit_by_id(unit_id) if projected_state else board.get_unit_by_id(unit_id)
	if p_unit == null: return -1
	if phase == Phase.PLANNING_PHASE_1:
		if p_unit.phase_1_action_used:
			return -1 if p_unit.phase_2_action_used else 2
		return 1
	elif phase == Phase.PLANNING_PHASE_2:
		return -1 if p_unit.phase_2_action_used else 2
	return -1

@rpc("any_peer", "call_local", "reliable")
func rpc_plan_move(unit_id: int, coord: Vector2i, face_dir: int, waypoints: Array[Vector2i]) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id():
			return
	
	if (phase != Phase.PLANNING_PHASE_1 and phase != Phase.PLANNING_PHASE_2) or unit_id < 0:
		return

	var target_phase = _get_target_phase(unit_id)
	if target_phase == -1:
		EventBus.action_rejected.emit("no_actions_left")
		return
		
	_clear_unit_from_plans(unit_id, target_phase)
	var action := TimelineAction.make_move(unit_id, coord, face_dir, waypoints, target_phase)
	var plan_to_use = plan_phase_1 if target_phase == 1 else plan_phase_2
	_try_add(action, plan_to_use)

@rpc("any_peer", "call_local", "reliable")
func rpc_plan_face(unit_id: int, face_dir: int) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id(): return

	if (phase != Phase.PLANNING_PHASE_1 and phase != Phase.PLANNING_PHASE_2) or unit_id < 0 or face_dir < 0:
		return
	var unit := base_board.get_unit_by_id(unit_id)
	if unit != null:
		unit.facing = face_dir as GameEnums.Facing
		var p_unit := projected_state.get_unit_by_id(unit_id)
		if p_unit != null: p_unit.facing = face_dir as GameEnums.Facing
		var m_unit := board.get_unit_by_id(unit_id)
		if m_unit != null: m_unit.facing = face_dir as GameEnums.Facing
	_refresh_plan()

@rpc("any_peer", "call_local", "reliable")
func rpc_plan_attack_with_approach(unit_id: int, ability_index: int, target_unit_id: int, preferred_tile: Vector2i) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id():
			return

	if (phase != Phase.PLANNING_PHASE_1 and phase != Phase.PLANNING_PHASE_2) or unit_id < 0:
		return
	var target_phase = _get_target_phase(unit_id)
	if target_phase == -1:
		return
	var plan_to_use = plan_phase_1 if target_phase == 1 else plan_phase_2

	var proj := _get_planning_state(target_phase)
	var actor := proj.get_unit_by_id(unit_id)
	var target := proj.get_unit_by_id(target_unit_id)
	if actor == null or target == null or actor.active_abilities.is_empty():
		return
	var index := clampi(ability_index, 0, actor.active_abilities.size() - 1)
	var ability: AbilityData = actor.active_abilities[index]
	var rng: int = ability.range_tiles

	var move_action: TimelineAction = null
	if GridSystem.manhattan(actor.position, target.position) > rng:
		var approach := _find_approach_tile(proj, actor, target.position, rng, preferred_tile)
		if approach == actor.position:
			EventBus.action_rejected.emit("cannot_use_ability")
			return
		
		# If we need an approach, that consumes the target_phase (e.g. phase 1)
		# The attack would then consume target_phase + 1 (e.g. phase 2)
		if target_phase == 2:
			# Cannot do both move + attack if only phase 2 action is left
			EventBus.action_rejected.emit("no_actions_left")
			return
			
		var max_steps := actor.movement.max_points if actor.movement != null else 0
		var mov_type := actor.definition.movement_type if actor.definition != null else GameEnums.MovementType.WALK
		var waypoints := MovementSystem.find_path(proj, actor.position, approach, max_steps, mov_type)
		move_action = TimelineAction.make_move(unit_id, approach, -1, waypoints, 1)

	var trial := proj.clone()
	
	if move_action != null:
		# Approach is Phase 1/Phase 2 (queued)
		var after_actor := trial.get_unit_by_id(target_unit_id)
		var attack_action := TimelineAction.make_ability(unit_id, ability,
			after_actor.position if after_actor != null else target.position, target_unit_id, 2)
		_clear_unit_from_plans(unit_id, target_phase)
		_try_add_multiple([move_action, attack_action], [plan_phase_1, plan_phase_2])
		return

	# No approach needed, just attack
	_clear_unit_from_plans(unit_id, target_phase)
	var after_actor := trial.get_unit_by_id(target_unit_id)
	var attack_action := TimelineAction.make_ability(unit_id, ability,
		after_actor.position if after_actor != null else target.position, target_unit_id, target_phase)
	_try_add(attack_action, plan_to_use)


func _find_approach_tile(state: BoardState, actor: UnitState, target_pos: Vector2i, rng: int, preferred_tile: Vector2i) -> Vector2i:
	if _is_attack_tile(state, actor, preferred_tile, target_pos, rng):
		return preferred_tile
	var best := actor.position
	var best_len := 1 << 30
	for y in range(state.grid_size.y):
		for x in range(state.grid_size.x):
			var coord := Vector2i(x, y)
			if not _is_attack_tile(state, actor, coord, target_pos, rng):
				continue
			var path := MovementSystem.find_path(state, actor.position, coord, actor.movement.points_left)
			if path.size() < best_len:
				best_len = path.size()
				best = coord
	return best

func _is_attack_tile(state: BoardState, actor: UnitState, coord: Vector2i, target_pos: Vector2i, rng: int) -> bool:
	if coord == actor.position or not GridSystem.is_in_bounds(state, coord):
		return false
	if GridSystem.manhattan(coord, target_pos) > rng or not GridSystem.is_passable(state, coord):
		return false
	var path := MovementSystem.find_path(state, actor.position, coord, actor.movement.points_left)
	return not path.is_empty() and path[path.size() - 1] == coord

func _apply_phase_1_to_2_transition(board: BoardState) -> void:
	for unit in board.units:
		if unit.is_alive() and not unit.is_enemy():
			var rec = floori(unit.definition.move_points / 2.0)
			unit.movement.points_left = mini(unit.definition.move_points, unit.movement.points_left + rec)

func _clear_unit_from_plans(unit_id: int, from_phase: int) -> void:
	if from_phase <= 1:
		var kept_1: Array[TimelineAction] = []
		for a in plan_phase_1.entries: if a.actor_id != unit_id: kept_1.append(a)
		plan_phase_1.entries = kept_1
	if from_phase <= 2:
		var kept_2: Array[TimelineAction] = []
		for a in plan_phase_2.entries: if a.actor_id != unit_id: kept_2.append(a)
		plan_phase_2.entries = kept_2

func _try_add(action: TimelineAction, target_plan: Timeline) -> void:
	_try_add_multiple([action], [target_plan])

func _try_add_multiple(actions: Array[TimelineAction], target_plans: Array[Timeline]) -> void:
	var temp_p1 := Timeline.new()
	var temp_p2 := Timeline.new()
	for a in plan_phase_1.entries: temp_p1.add(a)
	for a in plan_phase_2.entries: temp_p2.add(a)
	
	var new_actors := []
	for i in range(actions.size()):
		var a = actions[i]
		new_actors.append(a.actor_id)
		if target_plans[i] == plan_phase_1: temp_p1.add(a)
		else: temp_p2.add(a)
		
	var trial := base_board.clone()
	var ev: Array[SimEvent] = []

	if not phase_1_executed:
		for a in temp_p1.entries:
			ResolutionPipeline.apply_action(trial, a, ev)
		ResolutionPipeline.resolve_pending_pushes(trial, ev)
		_apply_phase_1_to_2_transition(trial)

	for a in temp_p2.entries:
		ResolutionPipeline.apply_action(trial, a, ev)
	ResolutionPipeline.resolve_pending_pushes(trial, ev)
	
	for e in ev:
		if e.type == GameEnums.SimEventType.ACTION_FAILED:
			var failed_actor = e.data.get("actor", -1)
			if failed_actor in new_actors:
				EventBus.action_rejected.emit(String(e.data.get("reason", "failed")))
				return
				
	for i in range(actions.size()):
		target_plans[i].add(actions[i])
		if actions[i].type == GameEnums.ActionType.MOVE:
			_commit_animate_actions.append(actions[i])
	_refresh_plan()

func _get_combined_plan() -> Timeline:
	var combined = Timeline.new()
	for a in plan_phase_1.entries: combined.add(a)
	for a in plan_phase_2.entries: combined.add(a)
	return combined

func preview_drag(unit_id: int, coord: Vector2i, attack_target_id: int = -1, waypoints: Array[Vector2i] = []) -> Dictionary:
	var phase_val := 1 if phase == Phase.PLANNING_PHASE_1 else 2
	var ev: Array[SimEvent] = []
	
	# Determine the actor's start state for the active phase to calculate approach tile correctly
	var start_board := base_board.clone()
	if phase == Phase.PLANNING_PHASE_2 and not phase_1_executed:
		var discard_ev: Array[SimEvent] = []
		_apply_phase_1_plan_to_state(start_board, discard_ev)
		
	var actor := start_board.get_unit_by_id(unit_id)
	var move_action: TimelineAction = null
	var attack_action: TimelineAction = null
	
	if attack_target_id >= 0:
		var target := start_board.get_unit_by_id(attack_target_id)
		if actor != null and target != null and not actor.active_abilities.is_empty():
			var index := clampi(selected_ability_index, 0, actor.active_abilities.size() - 1)
			var ability: AbilityData = actor.active_abilities[index]
			var rng: int = ability.range_tiles
			
			if GridSystem.manhattan(actor.position, target.position) > rng:
				if phase == Phase.PLANNING_PHASE_1:
					var approach := _find_approach_tile(start_board, actor, target.position, rng, coord)
					if approach != actor.position:
						move_action = TimelineAction.make_move(unit_id, approach, -1, [], 1)
						attack_action = TimelineAction.make_ability(unit_id, ability, target.position, attack_target_id, 2)
				else:
					attack_action = TimelineAction.make_ability(unit_id, ability, target.position, attack_target_id, phase_val)
			else:
				attack_action = TimelineAction.make_ability(unit_id, ability, target.position, attack_target_id, phase_val)
	else:
		move_action = TimelineAction.make_move(unit_id, coord, -1, waypoints, phase_val)

	# Now build the full timeline exactly like _update_preview, replacing unit_id's action
	var temp := base_board.clone()
	
	var p1 := Timeline.new()
	for a in plan_phase_1.entries:
		if phase_val == 1 and a.actor_id == unit_id: continue
		p1.add(a)
	if phase_val == 1:
		if move_action != null: p1.add(move_action)
		if attack_action != null and attack_action.phase == 1: p1.add(attack_action)

	if not phase_1_executed:
		for a in p1.entries:
			ResolutionPipeline.apply_action(temp, a, ev)
		ResolutionPipeline.resolve_pending_pushes(temp, ev)
		_apply_phase_1_to_2_transition(temp)

	var p2 := Timeline.new()
	for a in plan_phase_2.entries:
		if a.actor_id == unit_id: continue
		p2.add(a)
	if phase_val == 2:
		if move_action != null: p2.add(move_action)
		if attack_action != null and attack_action.phase == 2: p2.add(attack_action)
	elif phase_val == 1 and attack_action != null and attack_action.phase == 2:
		p2.add(attack_action)
		
	# Fix targets for attacks right before p2 executes
	if phase_val == 1 and attack_action != null and attack_action.phase == 2:
		var tgt := temp.get_unit_by_id(attack_target_id)
		if tgt != null:
			attack_action.target_coord = tgt.position
			
	for a in p2.entries:
		ResolutionPipeline.apply_action(temp, a, ev)
	ResolutionPipeline.resolve_pending_pushes(temp, ev)
		
	var intents := EnemyPlanner.plan(temp)
	for intent in intents:
		for action in intent.actions:
			ResolutionPipeline.apply_action(temp, action, ev)
	ResolutionPipeline.resolve_pending_pushes(temp, ev)
			
	return {
		"intents": intents,
		"events": ev,
		"temp_board": temp
	}

func preview_dash(unit_id: int, target_coord: Vector2i, ability_index: int = -1) -> Dictionary:
	var phase_val := 1 if phase == Phase.PLANNING_PHASE_1 else 2
	var ev: Array[SimEvent] = []
	var start_board := base_board.clone()
	if phase == Phase.PLANNING_PHASE_2 and not phase_1_executed:
		var discard_ev: Array[SimEvent] = []
		_apply_phase_1_plan_to_state(start_board, discard_ev)
	var actor := start_board.get_unit_by_id(unit_id)
	if actor == null or actor.active_abilities.is_empty():
		return {"intents": [], "events": ev, "temp_board": start_board}
	var index := ability_index if ability_index >= 0 else selected_ability_index
	index = clampi(index, 0, actor.active_abilities.size() - 1)
	var ability: AbilityData = actor.active_abilities[index]
	var dash_action := TimelineAction.make_ability(unit_id, ability, target_coord, -1, phase_val)
	var temp := base_board.clone()
	var p1 := Timeline.new()
	for a in plan_phase_1.entries:
		if phase_val == 1 and a.actor_id == unit_id:
			continue
		p1.add(a)
	if phase_val == 1:
		p1.add(dash_action)
	if not phase_1_executed:
		for a in p1.entries:
			ResolutionPipeline.apply_action(temp, a, ev)
		ResolutionPipeline.resolve_pending_pushes(temp, ev)
		_apply_phase_1_to_2_transition(temp)
	var p2 := Timeline.new()
	for a in plan_phase_2.entries:
		if a.actor_id == unit_id:
			continue
		p2.add(a)
	if phase_val == 2:
		p2.add(dash_action)
	for a in p2.entries:
		ResolutionPipeline.apply_action(temp, a, ev)
	ResolutionPipeline.resolve_pending_pushes(temp, ev)
	var intents := EnemyPlanner.plan(temp)
	for intent in intents:
		for action in intent.actions:
			ResolutionPipeline.apply_action(temp, action, ev)
	ResolutionPipeline.resolve_pending_pushes(temp, ev)
	return {
		"intents": intents,
		"events": ev,
		"temp_board": temp
	}

@rpc("any_peer", "call_local", "reliable")
func rpc_reorder_action(from_index: int, to_index: int) -> void:
	var combined = _get_combined_plan()
	if from_index < 0 or from_index >= combined.size(): return
	var action = combined.entries[from_index]
	
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(action.actor_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id(): return
		
	var plan_to_use = plan_phase_1 if action.phase == 1 else plan_phase_2
	
	# Compute local index
	var local_from = -1
	for i in range(plan_to_use.size()):
		if plan_to_use.entries[i] == action:
			local_from = i
			break
			
	var action_at_to = combined.entries[clampi(to_index, 0, combined.size() - 1)]
	if action_at_to.phase != action.phase:
		return # Cannot reorder across phases
		
	var local_to = -1
	for i in range(plan_to_use.size()):
		if plan_to_use.entries[i] == action_at_to:
			local_to = i
			break
	
	plan_to_use.reorder(local_from, local_to)
	_refresh_plan()

@rpc("any_peer", "call_local", "reliable")
func rpc_plan_attack(unit_id: int, ability_index: int, target_unit_id: int) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id(): return

	if (phase != Phase.PLANNING_PHASE_1 and phase != Phase.PLANNING_PHASE_2) or unit_id < 0:
		return
	var target_phase = _get_target_phase(unit_id)
	if target_phase == -1: return
	var plan_to_use = plan_phase_1 if target_phase == 1 else plan_phase_2
	
	var attacker := board.get_unit_by_id(unit_id)
	if attacker == null or attacker.active_abilities.is_empty(): return
	var target := board.get_unit_by_id(target_unit_id)
	if target == null: return
	var index := clampi(ability_index, 0, attacker.active_abilities.size() - 1)
	var ability: AbilityData = attacker.active_abilities[index]
	
	var proj := _get_planning_state(target_phase)
	var projected_target := proj.get_unit_by_id(target_unit_id)
	var coord: Vector2i = projected_target.position if projected_target != null else target.position
	_try_add(TimelineAction.make_ability(unit_id, ability, coord, target_unit_id, target_phase), plan_to_use)

@rpc("any_peer", "call_local", "reliable")
func rpc_plan_ability_at_coord(unit_id: int, ability_index: int, coord: Vector2i) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id():
			return

	if (phase != Phase.PLANNING_PHASE_1 and phase != Phase.PLANNING_PHASE_2) or unit_id < 0:
		return
	var target_phase = _get_target_phase(unit_id)
	if target_phase == -1:
		return
	var plan_to_use = plan_phase_1 if target_phase == 1 else plan_phase_2

	var attacker := board.get_unit_by_id(unit_id)
	if attacker == null or attacker.active_abilities.is_empty():
		return
	var index := clampi(ability_index, 0, attacker.active_abilities.size() - 1)
	var ability: AbilityData = attacker.active_abilities[index]
	_clear_unit_from_plans(unit_id, target_phase)
	_try_add(TimelineAction.make_ability(unit_id, ability, coord, -1, target_phase), plan_to_use)

@rpc("any_peer", "call_local", "reliable")
func rpc_remove_last_for_unit(unit_id: int) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id(): return

	if phase == Phase.PLANNING_PHASE_1:
		if plan_phase_2.size() > 0:
			for i in range(plan_phase_2.size() - 1, -1, -1):
				if plan_phase_2.entries[i].actor_id == unit_id:
					if plan_phase_2.entries[i].irreversible:
						EventBus.action_rejected.emit("cannot_undo_trample")
						return
					plan_phase_2.remove_at(i)
					_refresh_plan()
					return
		if plan_phase_1.size() > 0:
			for i in range(plan_phase_1.size() - 1, -1, -1):
				if plan_phase_1.entries[i].actor_id == unit_id:
					if plan_phase_1.entries[i].irreversible:
						EventBus.action_rejected.emit("cannot_undo_trample")
						return
					plan_phase_1.remove_at(i)
					_refresh_plan()
					return
	elif phase == Phase.PLANNING_PHASE_2:
		if plan_phase_2.size() > 0:
			for i in range(plan_phase_2.size() - 1, -1, -1):
				if plan_phase_2.entries[i].actor_id == unit_id:
					if plan_phase_2.entries[i].irreversible:
						EventBus.action_rejected.emit("cannot_undo_trample")
						return
					plan_phase_2.remove_at(i)
					_refresh_plan()
					return

@rpc("any_peer", "call_local", "reliable")
func rpc_remove_action(index: int) -> void:
	var combined = _get_combined_plan()
	if index < 0 or index >= combined.size(): return
	var action = combined.entries[index]
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(action.actor_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id(): return

	if index < plan_phase_1.size():
		if plan_phase_1.entries[index].irreversible:
			EventBus.action_rejected.emit("cannot_undo_trample")
			return
		plan_phase_1.remove_at(index)
	elif index - plan_phase_1.size() < plan_phase_2.size():
		if plan_phase_2.entries[index - plan_phase_1.size()].irreversible:
			EventBus.action_rejected.emit("cannot_undo_trample")
			return
		plan_phase_2.remove_at(index - plan_phase_1.size())
	_refresh_plan()

func move_action(index: int, delta: int) -> void:
	if multiplayer.has_multiplayer_peer():
		rpc_reorder_action.rpc(index, index + delta)
	else:
		rpc_reorder_action(index, index + delta)

@rpc("any_peer", "call_local", "reliable")
func rpc_clear_unit_actions(unit_id: int) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id(): return

	var base_unit := base_board.get_unit_by_id(unit_id)
	if base_unit != null and phase == Phase.PLANNING_PHASE_1:
		# Occupancy check: if the unit moved, and its start square is now occupied by ANOTHER unit, reject clear.
		var occ := board.get_unit_at(base_unit.position)
		if occ != null and occ.id != unit_id:
			EventBus.action_rejected.emit("Undo not possible: initial square occupied")
			return

	for plan in [plan_phase_1, plan_phase_2]:
		for a in plan.entries:
			if a.actor_id == unit_id and a.irreversible:
				EventBus.action_rejected.emit("cannot_undo_trample")
				return

	if phase == Phase.PLANNING_PHASE_1:
		var kept_1: Array[TimelineAction] = []
		for a in plan_phase_1.entries:
			if a.actor_id != unit_id:
				kept_1.append(a)
		plan_phase_1.entries = kept_1
		var kept_2: Array[TimelineAction] = []
		for a in plan_phase_2.entries:
			if a.actor_id != unit_id:
				kept_2.append(a)
		plan_phase_2.entries = kept_2
	elif phase == Phase.PLANNING_PHASE_2:
		var kept_p2: Array[TimelineAction] = []
		for a in plan_phase_2.entries:
			if a.actor_id != unit_id:
				kept_p2.append(a)
		plan_phase_2.entries = kept_p2
	_refresh_plan()

func clear_plan() -> void:
	if phase == Phase.PLANNING_PHASE_1:
		plan_phase_1.clear()
		plan_phase_2.clear()
	elif phase == Phase.PLANNING_PHASE_2:
		plan_phase_2.clear()
	_refresh_plan()

func restart_turn() -> void:
	if turn_start_board == null:
		return
	_run_id += 1
	base_board = turn_start_board.clone()
	board = base_board.clone()
	plan_phase_1.clear()
	plan_phase_2.clear()
	phase_1_executed = false
	selected_unit_id = -1
	selected_ability_index = 0
	_set_phase(Phase.PLANNING_PHASE_1)
	EventBus.board_changed.emit(board)
	EventBus.selection_changed.emit(selected_unit_id)
	EventBus.ability_selected.emit(selected_ability_index)
	_refresh_plan()

func restart() -> void:
	if initial_board != null:
		base_board = initial_board.clone()
	_init_combat()

func execute_phase_1() -> void:
	if phase != Phase.PLANNING_PHASE_1: return
	
	var current_run_id = _run_id
	var events: Array[SimEvent] = []
	var sim_board := base_board.clone()
	
	Simulator._tick_start_of_turn(sim_board, events, GameEnums.Team.PLAYER)
	
	for action in plan_phase_1.entries:
		ResolutionPipeline.apply_action(sim_board, action, events)
	ResolutionPipeline.resolve_pending_pushes(sim_board, events)
		
	_set_phase(Phase.EXECUTING_PHASE_1)
	await _play_events(events)
	if current_run_id != _run_id: return
	
	_apply_phase_1_to_2_transition(sim_board)
	
	base_board = sim_board
	phase_1_executed = true

	if _check_end_state(): return
	
	_refresh_plan()
	_set_phase(Phase.PLANNING_PHASE_2)

func execute_phase_2() -> void:
	if phase != Phase.PLANNING_PHASE_2: return
	
	var current_run_id = _run_id
	var events: Array[SimEvent] = []
	var sim_board := base_board.clone()
	for action in plan_phase_2.entries:
		ResolutionPipeline.apply_action(sim_board, action, events)
	ResolutionPipeline.resolve_pending_pushes(sim_board, events)
	
	Simulator._refund_movement(sim_board)
	Simulator._tick_statuses(sim_board, events)
	
	events.append(SimEvent.make(GameEnums.SimEventType.ENEMY_PHASE_BEGAN, {}))
	
	Simulator._tick_start_of_turn(sim_board, events, GameEnums.Team.ENEMY)
	
	for intent in base_board.intents:
		for action in intent.actions:
			ResolutionPipeline.apply_action(sim_board, action, events)
	ResolutionPipeline.resolve_pending_pushes(sim_board, events)
			
	Simulator._tick_end_of_turn(sim_board, events)
			
	sim_board.turn_index += 1
	for unit in sim_board.units:
		if unit.is_alive():
			unit.reset_for_turn()
			
	Simulator._tick_statuses(sim_board, events)
	events.append(SimEvent.make(GameEnums.SimEventType.TURN_ENDED, {
		"turn": sim_board.turn_index,
	}))
	_set_phase(Phase.EXECUTING_PHASE_2)
	await _play_events(events)
	if current_run_id != _run_id: return
	
	base_board = sim_board
	plan_phase_1.clear()
	plan_phase_2.clear()
	phase_1_executed = false
	
	if _check_end_state(): return
	
	_refresh_plan()
	_set_phase(Phase.PLANNING_PHASE_1)
	_capture_turn_start()

func _ready() -> void:
	if not GlobalTimeline.player_ready_changed.is_connected(_on_player_ready_changed):
		GlobalTimeline.player_ready_changed.connect(_on_player_ready_changed)

func _on_player_ready_changed(_player_id: int, _is_ready: bool) -> void:
	if NetworkManager == null or not NetworkManager.is_multiplayer or multiplayer.is_server():
		if GlobalTimeline.is_everyone_ready():
			if phase == Phase.PLANNING_PHASE_1 or phase == Phase.PLANNING_PHASE_2:
				if multiplayer.has_multiplayer_peer():
					rpc_commit_phase.rpc()
				else:
					rpc_commit_phase()

@rpc("authority", "call_local", "reliable")
func rpc_commit_phase() -> void:
	GlobalTimeline.rpc_reset_ready_states()
	if phase == Phase.PLANNING_PHASE_1:
		execute_phase_1()
	elif phase == Phase.PLANNING_PHASE_2:
		execute_phase_2()

# --- Internal -----------------------------------------------------------------

func _play_events(events: Array[SimEvent]) -> void:
	## Split at ENEMY_PHASE_BEGAN so player and enemy phases each get their own
	## simultaneous batch run; the marker itself is emitted between the two runs.
	var player_events: Array[SimEvent] = []
	var enemy_events: Array[SimEvent] = []
	var hit_enemy_phase := false
	for event in events:
		if event.type == GameEnums.SimEventType.ENEMY_PHASE_BEGAN:
			hit_enemy_phase = true
			continue
		if hit_enemy_phase:
			enemy_events.append(event)
		else:
			player_events.append(event)
	
	var run_id := _run_id
	await _play_batched_segment(player_events, run_id)
	if run_id != _run_id: return
	
	if hit_enemy_phase:
		await get_tree().create_timer(1.0).timeout  # breathing room before enemy phase
		if run_id != _run_id: return
		EventBus.sim_event.emit(SimEvent.make(GameEnums.SimEventType.ENEMY_PHASE_BEGAN, {}))
		await _play_batched_segment(enemy_events, run_id)

## Plays a list of events in 3 ordered phases: moves (simultaneous) → attacks
## (sequential, one-by-one) → forced movement (simultaneous at the end).
## Dash ability blocks are peeled out and played with move → pass-through hits → pushes.
func _play_batched_segment(events: Array[SimEvent], run_id: int) -> void:
	if events.is_empty() or run_id != _run_id:
		return
	
	var dash_blocks := _find_dash_blocks(events)
	if dash_blocks.is_empty():
		await _play_batched_segment_legacy(events, run_id)
		return
	
	var cursor := 0
	for block in dash_blocks:
		var start: int = block["start"]
		var end: int = block["end"]
		if cursor < start:
			await _play_batched_segment_legacy(events.slice(cursor, start), run_id)
			if run_id != _run_id:
				return
		await _play_dash_sequence(events.slice(start, end), run_id)
		if run_id != _run_id:
			return
		cursor = end
	if cursor < events.size():
		await _play_batched_segment_legacy(events.slice(cursor, events.size()), run_id)


func _find_dash_blocks(events: Array[SimEvent]) -> Array:
	var blocks: Array = []
	var i := 0
	while i < events.size():
		var start := i
		if events[i].type == GameEnums.SimEventType.UNIT_FACED:
			i += 1
			if i >= events.size():
				break
		if events[i].type == GameEnums.SimEventType.ABILITY_USED and events[i].data.get("is_dash", false):
			i += 1
			while i < events.size():
				var t := events[i].type
				if t == GameEnums.SimEventType.UNIT_MOVED and events[i].data.get("is_dash", false):
					i += 1
					break
				if t in [
					GameEnums.SimEventType.UNIT_DAMAGED,
					GameEnums.SimEventType.UNIT_PUSHED,
					GameEnums.SimEventType.COLLISION,
					GameEnums.SimEventType.MATH_TELEMETRY,
					GameEnums.SimEventType.UNIT_DIED,
					GameEnums.SimEventType.UNIT_ARMORED,
					GameEnums.SimEventType.STATUS_APPLIED,
					GameEnums.SimEventType.STATUS_REMOVED,
				]:
					i += 1
				else:
					break
			blocks.append({"start": start, "end": i})
			continue
		i += 1
	return blocks


func _play_dash_sequence(block: Array, run_id: int) -> void:
	if block.is_empty() or run_id != _run_id:
		return
	
	var pre_ability_events: Array[SimEvent] = []
	var ability_event: SimEvent = null
	var move_event: SimEvent = null
	var push_events: Array[SimEvent] = []
	var step_events: Dictionary = {}
	var post_dash_events: Array[SimEvent] = []
	var step_event_types: Array = [
		GameEnums.SimEventType.COLLISION,
		GameEnums.SimEventType.MATH_TELEMETRY,
		GameEnums.SimEventType.UNIT_DAMAGED,
		GameEnums.SimEventType.UNIT_ARMORED,
		GameEnums.SimEventType.UNIT_DIED,
		GameEnums.SimEventType.STATUS_APPLIED,
		GameEnums.SimEventType.STATUS_REMOVED,
	]
	
	for event: SimEvent in block:
		match event.type:
			GameEnums.SimEventType.UNIT_FACED:
				pre_ability_events.append(event)
			GameEnums.SimEventType.ABILITY_USED:
				ability_event = event
			GameEnums.SimEventType.UNIT_MOVED:
				if event.data.get("is_dash", false):
					move_event = event
				else:
					pre_ability_events.append(event)
			GameEnums.SimEventType.UNIT_PUSHED:
				push_events.append(event)
			_:
				if event.type in step_event_types and event.data.has("dash_hit_step"):
					var step := int(event.data.get("dash_hit_step", -1))
					if step >= 0:
						if not step_events.has(step):
							step_events[step] = []
						(step_events[step] as Array).append(event)
					else:
						post_dash_events.append(event)
				elif event.type in step_event_types:
					post_dash_events.append(event)
				else:
					pre_ability_events.append(event)
	
	for e in pre_ability_events:
		if run_id != _run_id:
			return
		EventBus.sim_event.emit(e)
	
	if ability_event != null:
		EventBus.sim_event.emit(ability_event)
	
	if move_event == null:
		for e in post_dash_events:
			if run_id != _run_id:
				return
			EventBus.sim_event.emit(e)
		for e in push_events:
			if run_id != _run_id:
				return
			EventBus.sim_event.emit(e)
		if not push_events.is_empty():
			await _await_push_animations(run_id)
		return
	
	var path: Array = move_event.data.get("path", [])
	move_event.data["is_dash"] = true
	move_event.data["dash_step_time"] = DASH_STEP_TIME
	EventBus.sim_event.emit(move_event)
	
	for step_i in range(path.size()):
		await get_tree().create_timer(DASH_STEP_TIME).timeout
		if run_id != _run_id:
			return
		if step_events.has(step_i):
			for e in step_events[step_i]:
				EventBus.sim_event.emit(e)
	
	await get_tree().create_timer(0.05).timeout
	if run_id != _run_id:
		return
	
	for e in post_dash_events:
		EventBus.sim_event.emit(e)
	
	for e in push_events:
		EventBus.sim_event.emit(e)
	if not push_events.is_empty():
		await _await_push_animations(run_id)


func _await_push_animations(run_id: int) -> void:
	var _done := false
	var _on_push_done := func() -> void:
		_done = true
	var _on_timeout := func() -> void:
		if not _done:
			EventBus.push_animations_complete.emit()
	EventBus.push_animations_complete.connect(_on_push_done, CONNECT_ONE_SHOT)
	get_tree().create_timer(PUSH_ANIM_FALLBACK).timeout.connect(_on_timeout, CONNECT_ONE_SHOT)
	await EventBus.push_animations_complete
	if run_id != _run_id:
		return


func _play_batched_segment_legacy(events: Array[SimEvent], run_id: int) -> void:
	if events.is_empty() or run_id != _run_id:
		return
	
	var move_events:   Array[SimEvent] = []
	var attack_events: Array[SimEvent] = []
	var push_events:   Array[SimEvent] = []
	var meta_events:   Array[SimEvent] = []
	
	for event in events:
		match event.type:
			GameEnums.SimEventType.UNIT_MOVED:
				move_events.append(event)
			GameEnums.SimEventType.ABILITY_USED, \
			GameEnums.SimEventType.COUNTER_ATTACK, \
			GameEnums.SimEventType.MATH_TELEMETRY, \
			GameEnums.SimEventType.UNIT_DAMAGED, \
			GameEnums.SimEventType.UNIT_ARMORED, \
			GameEnums.SimEventType.UNIT_HEALED, \
			GameEnums.SimEventType.UNIT_DIED, \
			GameEnums.SimEventType.UNIT_FACED, \
			GameEnums.SimEventType.STATUS_APPLIED, \
			GameEnums.SimEventType.STATUS_REMOVED, \
			GameEnums.SimEventType.UNIT_EXPLODED:
				attack_events.append(event)
			GameEnums.SimEventType.UNIT_PUSHED, \
			GameEnums.SimEventType.COLLISION:
				push_events.append(event)
			_: # TURN_ENDED, ACTION_FAILED, UNIT_SPAWNED, etc.
				meta_events.append(event)
	
	# --- Phase 1: Movements — all units move at the same time ---
	if not move_events.is_empty():
		var max_path_len := 0
		for e in move_events:
			if run_id != _run_id: return
			EventBus.sim_event.emit(e)
			max_path_len = max(max_path_len, (e.data.get("path", []) as Array).size())
		await get_tree().create_timer(max(1, max_path_len) * MOVE_STEP_TIME + 0.05).timeout
		if run_id != _run_id: return
	
	# --- Phase 2: Attacks — sequential, one action at a time ---
	for e in attack_events:
		if run_id != _run_id: return
		EventBus.sim_event.emit(e)
		# ABILITY_USED drives the visible attack animation; give it a full beat.
		# Other events (UNIT_DAMAGED, status, etc.) get a shorter pause.
		var delay := ATTACK_ANIM_TIME if e.type in [GameEnums.SimEventType.ABILITY_USED, GameEnums.SimEventType.COUNTER_ATTACK] else 0.15
		await get_tree().create_timer(delay).timeout
	if run_id != _run_id: return
	
	# --- Phase 3: Forced movement — all pushes/collisions at the same time ---
	if not push_events.is_empty():
		for e in push_events:
			if run_id != _run_id: return
			EventBus.sim_event.emit(e)
		await _await_push_animations(run_id)
	
	# --- Meta events (TURN_ENDED, ACTION_FAILED, etc.) ---
	for e in meta_events:
		if run_id != _run_id: return
		EventBus.sim_event.emit(e)


func _move_has_commit_side_effects(events: Array[SimEvent]) -> bool:
	for e in events:
		if e.type in [
			GameEnums.SimEventType.TRAMPLE_HIT,
			GameEnums.SimEventType.COLLISION,
			GameEnums.SimEventType.UNIT_DAMAGED,
			GameEnums.SimEventType.UNIT_PUSHED,
		]:
			return true
	return false


func _collect_displaced_enemies(pre_board: BoardState, events: Array[SimEvent]) -> Dictionary:
	var displaced: Dictionary = {}
	for e in events:
		var enemy_id := -1
		match e.type:
			GameEnums.SimEventType.TRAMPLE_HIT:
				enemy_id = e.data.get("target", -1)
			GameEnums.SimEventType.UNIT_PUSHED, GameEnums.SimEventType.COLLISION:
				enemy_id = e.data.get("unit", -1)
		if enemy_id < 0:
			continue
		var u := pre_board.get_unit_by_id(enemy_id)
		if u != null and u.is_enemy() and not displaced.has(enemy_id):
			displaced[enemy_id] = u.position
	return displaced


func _cancel_plans_for_displacement(mover_id: int, pre_board: BoardState, events: Array[SimEvent]) -> bool:
	var displaced := _collect_displaced_enemies(pre_board, events)
	if displaced.is_empty():
		return false
	var cancelled := false
	for plan in [plan_phase_1, plan_phase_2]:
		var kept: Array[TimelineAction] = []
		for a in plan.entries:
			if a.type != GameEnums.ActionType.ABILITY or a.actor_id == mover_id:
				kept.append(a)
				continue
			var remove := false
			if a.target_unit_id >= 0 and displaced.has(a.target_unit_id):
				remove = true
			else:
				for old_pos: Vector2i in displaced.values():
					if a.target_coord == old_pos:
						remove = true
						break
			if remove:
				cancelled = true
			else:
				kept.append(a)
		plan.entries = kept
	if cancelled:
		EventBus.action_rejected.emit("target_displaced")
	return cancelled


func _extract_commit_anim_events(events: Array[SimEvent]) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in events:
		if e.type in [
			GameEnums.SimEventType.UNIT_MOVED,
			GameEnums.SimEventType.UNIT_PUSHED,
			GameEnums.SimEventType.COLLISION,
			GameEnums.SimEventType.UNIT_DAMAGED,
			GameEnums.SimEventType.TRAMPLE_HIT,
		]:
			out.append(e)
	return out


func unit_has_undoable_action(unit_id: int) -> bool:
	if unit_id < 0:
		return false
	if phase == Phase.PLANNING_PHASE_1:
		for i in range(plan_phase_2.size() - 1, -1, -1):
			if plan_phase_2.entries[i].actor_id == unit_id:
				return not plan_phase_2.entries[i].irreversible
		for i in range(plan_phase_1.size() - 1, -1, -1):
			if plan_phase_1.entries[i].actor_id == unit_id:
				return not plan_phase_1.entries[i].irreversible
	elif phase == Phase.PLANNING_PHASE_2:
		for i in range(plan_phase_2.size() - 1, -1, -1):
			if plan_phase_2.entries[i].actor_id == unit_id:
				return not plan_phase_2.entries[i].irreversible
	return false


func _refresh_plan() -> void:
	var move_only := base_board.clone()
	var full_proj := base_board.clone()
	var statuses := PackedStringArray()
	var anim_events: Array[SimEvent] = []
	var any_cancelled := false
	
	var plan_to_run = plan_phase_1 if phase == Phase.PLANNING_PHASE_1 else plan_phase_2
	
	for action in plan_to_run.entries:
		var events: Array[SimEvent] = []
		ResolutionPipeline.apply_action(full_proj, action, events)
		
		if action.type == GameEnums.ActionType.MOVE:
			var pre_board := move_only.clone()
			var move_ev: Array[SimEvent] = []
			ResolutionPipeline.apply_action(move_only, action, move_ev)
			ResolutionPipeline.resolve_pending_pushes(move_only, move_ev)
			if _move_has_commit_side_effects(move_ev):
				action.irreversible = true
				if _cancel_plans_for_displacement(action.actor_id, pre_board, move_ev):
					any_cancelled = true
				if action in _commit_animate_actions:
					anim_events.append_array(_extract_commit_anim_events(move_ev))
			
		var reason := ""
		for e in events:
			if e.type == GameEnums.SimEventType.ACTION_FAILED:
				reason = String(e.data.get("reason", "failed"))
				break
		statuses.append(reason)

	if any_cancelled:
		_refresh_plan()
		return

	_commit_animate_actions.clear()
		
	var dummy_ev: Array[SimEvent] = []
	ResolutionPipeline.resolve_pending_pushes(full_proj, dummy_ev)
		
	board = move_only
	projected_state = full_proj
	var new_intents := EnemyPlanner.plan(projected_state)
	base_board.intents = new_intents
	board.intents = new_intents
	projected_state.intents = new_intents

	if not anim_events.is_empty():
		EventBus.planning_commit_events.emit(anim_events)
	EventBus.board_changed.emit(board)
	EventBus.timeline_changed.emit(plan_to_run, statuses)
	
	# Compute ghost events and final state by diffing base_board and projected_state
	# The view layer uses preview_updated for ghosts and expected HP.
	var preview_board := base_board.clone()
	var evs := _build_ghost_events(preview_board, plan_to_run, base_board.intents)
	
	var sim_res := SimResult.new(preview_board)
	sim_res.events = evs
	EventBus.preview_updated.emit(sim_res)

func _build_ghost_events(sim: BoardState, timeline: Timeline, intents: Array[Intent]) -> Array[SimEvent]:
	var evs: Array[SimEvent] = []
	for action in timeline.entries:
		ResolutionPipeline.apply_action(sim, action, evs)
	ResolutionPipeline.resolve_pending_pushes(sim, evs)
	
	# Add Enemy intents for preview
	evs.append(SimEvent.make(GameEnums.SimEventType.ENEMY_PHASE_BEGAN, {}))
	for intent in intents:
		for action in intent.actions:
			ResolutionPipeline.apply_action(sim, action, evs)
	ResolutionPipeline.resolve_pending_pushes(sim, evs)
	
	return evs

func _capture_turn_start() -> void:
	turn_start_board = base_board.clone()

func _lock_enemy_intents() -> void:
	base_board.intents = EnemyPlanner.plan(base_board)

func _check_end_state() -> bool:
	if not base_board.has_living_team(GameEnums.Team.ENEMY):
		_set_phase(Phase.VICTORY)
		return true
	if not base_board.has_living_team(GameEnums.Team.PLAYER):
		_set_phase(Phase.DEFEAT)
		return true
	return false

func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	# UI uses simple Phase.PLANNING check sometimes. 
	# (Assuming view might break if we send new phase without updating view layer. Let's send 0 for PLANNING_PHASE_1 and PLANNING_PHASE_2 if view expects it... actually EventBus can just emit it, and if UI expects PLANNING=0, we'll see.)
	EventBus.turn_phase_changed.emit(phase)

func _build_demo_encounter() -> BoardState:
	var map = DataLibrary.get_all_maps()[0]
	return BoardFactory.build_from_encounter(map.encounter)

