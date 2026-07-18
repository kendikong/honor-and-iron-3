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
	PLANNING,
	EXECUTING,
	ENEMY_TURN,
	VICTORY,
	DEFEAT,
}

## Unit the cursor starts on; any living player unit can be selected by clicking.
const FIRST_PLAYER_ID: int = 1
## Virtual skill-list index for Wait (not in active_abilities; scroll wheel skips it).
const WAIT_ABILITY_INDEX: int = -2

## How long each kind of event lingers during animated playback, in seconds.
const MOVE_STEP_TIME: float = 0.24   ## seconds per tile of movement
const DASH_STEP_TIME: float = 0.08   ## seconds per tile during dash abilities
const ATTACK_ANIM_TIME: float = 0.35 ## how long attack animations take
const PUSH_ANIM_FALLBACK: float = 1.0 ## Safety timeout if push signal never arrives

var base_board: BoardState
var board: BoardState
var plan_pre_move: Timeline
var plan_post_move: Timeline
var phase: Phase = Phase.PLANNING
var selected_unit_id: int = -1
var selected_ability_index: int = 0
## Last chosen ability slot per unit (planning UI memory).
var unit_ability_memory: Dictionary = {}
## Board after ONLY the player's queued actions (no enemy intents). Drives range,
## reachability and target highlights so they follow planned moves, not start tiles.
var projected_state: BoardState
var _run_id: int = 0
## Moves just added via _try_add_multiple that may need a planning commit animation.
var _commit_animate_actions: Array[TimelineAction] = []
var initial_board: BoardState
## Snapshot at the start of the current player turn (planning).
var turn_start_board: BoardState
## Incremented on every successful _refresh_plan — cheap cache-bust for hover previews.
var plan_revision: int = 0
## Units touched by the latest plan add/remove (lightweight view refresh).
var plan_affected_unit_ids: Array[int] = []
var _queued_preview: SimResult = null
## Populated by _try_add_multiple to skip a second simulate_player_turn in _refresh_plan.
var _pending_refresh_sim: Dictionary = {}


static func is_planning_phase(p: Phase) -> bool:
	return p == Phase.PLANNING


static func is_executing_phase(p: Phase) -> bool:
	return p == Phase.EXECUTING


static func is_wait_ability_index(index: int) -> bool:
	return index == WAIT_ABILITY_INDEX


static func resolve_selected_ability(unit: UnitState, index: int) -> AbilityData:
	if is_wait_ability_index(index):
		return DataLibrary.get_universal_wait()
	if unit == null or index < 0 or index >= unit.active_abilities.size():
		return null
	return unit.active_abilities[index]


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
	plan_pre_move = Timeline.new()
	plan_post_move = Timeline.new()
	_lock_enemy_intents()
	
	# Start with no unit selected
	selected_unit_id = -1
			
	selected_ability_index = 0
	_set_phase(Phase.PLANNING)
	EventBus.board_changed.emit(board)
	EventBus.selection_changed.emit(selected_unit_id)
	EventBus.ability_selected.emit(selected_ability_index)
	_refresh_plan()
	_capture_turn_start()

func select_unit(unit_id: int) -> void:
	if not is_planning_phase(phase):
		return
	if unit_id == -1:
		selected_unit_id = -1
		selected_ability_index = 0
		_emit_planning_selection()
		return
	var unit := board.get_unit_by_id(unit_id)
	if unit == null or not unit.is_alive():
		return
	var switched := unit_id != selected_unit_id
	selected_unit_id = unit_id
	if not switched:
		return
	var restored: int = int(unit_ability_memory.get(unit_id, 0))
	if restored < 0 or restored >= unit.active_abilities.size():
		restored = 0
	selected_ability_index = restored
	_emit_planning_selection()


func remember_unit_ability(unit_id: int, ability_index: int) -> void:
	if unit_id < 0:
		return
	unit_ability_memory[unit_id] = ability_index


func _emit_planning_selection() -> void:
	EventBus.selection_changed.emit(selected_unit_id)
	EventBus.ability_selected.emit(selected_ability_index)

## Choose which of the selected unit's abilities a queued attack will use.
func select_ability(index: int) -> void:
	if not is_planning_phase(phase):
		return
	if is_wait_ability_index(index):
		selected_ability_index = index
		EventBus.ability_selected.emit(selected_ability_index)
		return
	var unit := board.get_unit_by_id(selected_unit_id)
	if unit == null or index < 0 or index >= unit.active_abilities.size():
		return
	selected_ability_index = index
	EventBus.ability_selected.emit(selected_ability_index)

@rpc("any_peer", "call_local", "reliable")
func rpc_plan_wait(unit_id: int) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id():
			return
	if (not is_planning_phase(phase)) or unit_id < 0:
		return
	var target_timing: int = _get_move_timing(unit_id)
	if target_timing != GameEnums.MoveTiming.PRE_ACTION:
		EventBus.action_rejected.emit("no_actions_left")
		return
	var p_unit := projected_state.get_unit_by_id(unit_id) if projected_state != null else board.get_unit_by_id(unit_id)
	if p_unit == null or p_unit.turn_action_used:
		EventBus.action_rejected.emit("no_actions_left")
		return
	_clear_unit_abilities_from_plan(unit_id, GameEnums.MoveTiming.PRE_ACTION)
	_clear_unit_abilities_from_plan(unit_id, GameEnums.MoveTiming.POST_ACTION)
	_clear_unit_post_moves_from_plan(unit_id)
	var wait_ability: AbilityData = DataLibrary.get_universal_wait()
	_try_add(
		TimelineAction.make_ability(unit_id, wait_ability, p_unit.position, unit_id, target_timing),
		plan_pre_move,
	)
	selected_ability_index = -1
	EventBus.ability_selected.emit(selected_ability_index)


func unit_has_wait_planned(unit_id: int) -> bool:
	for plan: Timeline in [plan_pre_move, plan_post_move]:
		for action: TimelineAction in plan.entries:
			if action.actor_id != unit_id or action.type != GameEnums.ActionType.ABILITY:
				continue
			if action.ability != null and DataLibrary.is_universal_wait(action.ability.id):
				return true
	return false


func _clear_unit_abilities_from_plan(unit_id: int, timing: int) -> void:
	var plan: Timeline = plan_pre_move if timing == GameEnums.MoveTiming.PRE_ACTION else plan_post_move
	var kept: Array[TimelineAction] = []
	for action: TimelineAction in plan.entries:
		if action.actor_id == unit_id and action.type == GameEnums.ActionType.ABILITY:
			continue
		kept.append(action)
	plan.entries = kept


func _clear_unit_post_moves_from_plan(unit_id: int) -> void:
	var kept: Array[TimelineAction] = []
	for action: TimelineAction in plan_post_move.entries:
		if (
			action.actor_id == unit_id
			and action.type == GameEnums.ActionType.MOVE
			and action.move_timing == GameEnums.MoveTiming.POST_ACTION
		):
			continue
		kept.append(action)
	plan_post_move.entries = kept


func _get_planning_state(_target_timing: int = 1) -> BoardState:
	return base_board.clone()


func get_planning_move_timing(unit_id: int) -> int:
	return _get_move_timing(unit_id)


func _get_move_timing(unit_id: int) -> int:
	var p_unit := projected_state.get_unit_by_id(unit_id) if projected_state != null else board.get_unit_by_id(unit_id)
	if p_unit == null:
		return -1
	if p_unit.turn_action_used:
		return GameEnums.MoveTiming.POST_ACTION if _unit_can_post_move(unit_id, p_unit) else -1
	return GameEnums.MoveTiming.PRE_ACTION


func _plan_for_timing(timing: int) -> Timeline:
	return plan_post_move if timing == GameEnums.MoveTiming.POST_ACTION else plan_pre_move


func _unit_has_pre_move_queued(unit_id: int) -> bool:
	for a: TimelineAction in plan_pre_move.entries:
		if a.actor_id == unit_id and a.type == GameEnums.ActionType.MOVE and a.move_timing == GameEnums.MoveTiming.PRE_ACTION:
			return true
	return false


func _unit_has_post_move_queued(unit_id: int) -> bool:
	for a: TimelineAction in _get_combined_plan().entries:
		if a.actor_id == unit_id and a.type == GameEnums.ActionType.MOVE and a.move_timing == GameEnums.MoveTiming.POST_ACTION:
			return true
	return false


func _unit_can_post_move(unit_id: int, p_unit: UnitState) -> bool:
	if unit_has_wait_planned(unit_id):
		return false
	if _unit_has_post_move_queued(unit_id):
		return false
	if not p_unit.turn_action_used:
		return false
	if _unit_has_pre_move_queued(unit_id):
		return p_unit.has_passive(&"canto") or p_unit.has_status(GameEnums.StatusType.CANTO)
	return true

@rpc("any_peer", "call_local", "reliable")
func rpc_plan_move(unit_id: int, coord: Vector2i, face_dir: int, waypoints: Array[Vector2i]) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id():
			return
	
	if (not is_planning_phase(phase)) or unit_id < 0:
		return

	var target_timing = _get_move_timing(unit_id)
	if target_timing == -1:
		EventBus.action_rejected.emit("no_actions_left")
		return
		
	_clear_unit_from_plans(unit_id, target_timing)
	var action := TimelineAction.make_move(unit_id, coord, face_dir, waypoints, target_timing)
	var plan_to_use = _plan_for_timing(target_timing)
	_try_add(action, plan_to_use)

@rpc("any_peer", "call_local", "reliable")
func rpc_plan_face(unit_id: int, face_dir: int) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id(): return

	if (not is_planning_phase(phase)) or unit_id < 0 or face_dir < 0:
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

	if (not is_planning_phase(phase)) or unit_id < 0:
		return
	var target_timing = _get_move_timing(unit_id)
	if target_timing == -1:
		return
	var plan_to_use = _plan_for_timing(target_timing)

	var proj := _get_planning_state(target_timing)
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
		
		# If we need an approach, that consumes the target_timing (e.g. phase 1)
		# The attack would then consume target_timing + 1 (e.g. phase 2)
		if target_timing == GameEnums.MoveTiming.POST_ACTION and not _unit_can_post_move(unit_id, proj.get_unit_by_id(unit_id)):
			EventBus.action_rejected.emit("no_actions_left")
			return
			
		var max_steps := actor.movement.max_points if actor.movement != null else 0
		var mov_type := actor.definition.movement_type if actor.definition != null else GameEnums.MovementType.WALK
		var waypoints := MovementSystem.find_path(proj, actor.position, approach, max_steps, mov_type)
		move_action = TimelineAction.make_move(unit_id, approach, -1, waypoints, GameEnums.MoveTiming.PRE_ACTION)

	var trial := proj.clone()
	
	if move_action != null:
		# Approach move + ability queued together in pre-action bucket
		var after_actor := trial.get_unit_by_id(target_unit_id)
		var attack_action := TimelineAction.make_ability(unit_id, ability,
			after_actor.position if after_actor != null else target.position, target_unit_id, GameEnums.MoveTiming.PRE_ACTION)
		_clear_unit_from_plans(unit_id, GameEnums.MoveTiming.PRE_ACTION)
		_try_add_multiple([move_action, attack_action], [plan_pre_move, plan_pre_move])
		return

	# No approach needed, just attack
	_clear_unit_from_plans(unit_id, target_timing)
	var after_actor := trial.get_unit_by_id(target_unit_id)
	var attack_action := TimelineAction.make_ability(unit_id, ability,
		after_actor.position if after_actor != null else target.position, target_unit_id, target_timing)
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

func _clear_unit_from_plans(unit_id: int, from_timing: int) -> void:
	if from_timing <= GameEnums.MoveTiming.PRE_ACTION:
		var kept_1: Array[TimelineAction] = []
		for a in plan_pre_move.entries: if a.actor_id != unit_id: kept_1.append(a)
		plan_pre_move.entries = kept_1
	if from_timing <= GameEnums.MoveTiming.POST_ACTION:
		var kept_2: Array[TimelineAction] = []
		for a in plan_post_move.entries: if a.actor_id != unit_id: kept_2.append(a)
		plan_post_move.entries = kept_2

func _try_add(action: TimelineAction, target_plan: Timeline) -> void:
	_try_add_multiple([action], [target_plan])

func _try_add_multiple(actions: Array[TimelineAction], target_plans: Array[Timeline]) -> void:
	var temp_p1 := Timeline.new()
	var temp_p2 := Timeline.new()
	for a: TimelineAction in plan_pre_move.entries:
		temp_p1.add(a)
	for a: TimelineAction in plan_post_move.entries:
		temp_p2.add(a)
	var new_actors: Array[int] = []
	for i: int in range(actions.size()):
		var a: TimelineAction = actions[i]
		new_actors.append(a.actor_id)
		if target_plans[i] == plan_post_move:
			temp_p2.add(a)
		else:
			temp_p1.add(a)
	var trial: BoardState = base_board.clone()
	var ev: Array[SimEvent] = []
	var combined := Timeline.new()
	for a: TimelineAction in temp_p1.entries:
		combined.add(a)
	for a: TimelineAction in temp_p2.entries:
		combined.add(a)
	Simulator.simulate_player_turn(trial, combined, ev)
	for e: SimEvent in ev:
		if e.type == GameEnums.SimEventType.ACTION_FAILED:
			var failed_actor: int = int(e.data.get("actor", -1))
			if failed_actor in new_actors:
				EventBus.action_rejected.emit(String(e.data.get("reason", "failed")))
				return
	for i: int in range(actions.size()):
		target_plans[i].add(actions[i])
		if actions[i].type == GameEnums.ActionType.MOVE:
			_commit_animate_actions.append(actions[i])
	plan_affected_unit_ids = new_actors.duplicate()
	_pending_refresh_sim = {
		"projected": trial.clone(),
		"player_events": ev.duplicate(),
	}
	_refresh_plan()

func get_player_plan() -> Timeline:
	return _get_combined_plan()


func get_planned_move_waypoints(unit_id: int) -> Array[Vector2i]:
	for i: int in range(plan_post_move.size() - 1, -1, -1):
		var action: TimelineAction = plan_post_move.entries[i]
		if action.actor_id == unit_id and action.type == GameEnums.ActionType.MOVE:
			return action.waypoints.duplicate()
	for i: int in range(plan_pre_move.size() - 1, -1, -1):
		var action: TimelineAction = plan_pre_move.entries[i]
		if action.actor_id == unit_id and action.type == GameEnums.ActionType.MOVE:
			return action.waypoints.duplicate()
	return []


func get_unit_plan_steps(unit_id: int) -> Array[TimelineAction]:
	return UnitPlanOrder.ordered_steps_for_unit(get_player_plan(), unit_id)


func _get_combined_plan() -> Timeline:
	var combined = Timeline.new()
	for a in plan_pre_move.entries: combined.add(a)
	for a in plan_post_move.entries: combined.add(a)
	return combined

func _build_preview_plan(unit_id: int, new_actions: Array) -> Timeline:
	var combined := Timeline.new()
	for a: TimelineAction in plan_pre_move.entries:
		if a.actor_id == unit_id:
			continue
		combined.add(a)
	for a: TimelineAction in plan_post_move.entries:
		if a.actor_id == unit_id:
			continue
		combined.add(a)
	for a: Variant in new_actions:
		if a is TimelineAction:
			combined.add(a)
	return combined


func _preview_from_plan(combined: Timeline) -> Dictionary:
	var ev: Array[SimEvent] = []
	var temp: BoardState = base_board.clone()
	Simulator.simulate_player_turn(temp, combined, ev)
	var intents: Array = EnemyPlanner.plan(temp)
	for intent: Variant in intents:
		if not intent is Intent:
			continue
		for action: TimelineAction in (intent as Intent).actions:
			ResolutionPipeline.apply_action(temp, action, ev)
	ResolutionPipeline.resolve_pending_pushes(temp, ev)
	return {"intents": intents, "events": ev, "temp_board": temp}


func preview_drag(unit_id: int, coord: Vector2i, attack_target_id: int = -1, waypoints: Array[Vector2i] = []) -> Dictionary:
	var move_timing: int = _get_move_timing(unit_id)
	if move_timing < 0:
		return {"intents": [], "events": [], "temp_board": base_board.clone()}
	var start_board: BoardState = base_board.clone()
	var actor := start_board.get_unit_by_id(unit_id)
	var plan_board: BoardState = projected_state if projected_state != null else start_board
	var plan_actor: UnitState = plan_board.get_unit_by_id(unit_id) if plan_board != null else actor
	var new_actions: Array[TimelineAction] = []
	if attack_target_id >= 0:
		var target := start_board.get_unit_by_id(attack_target_id)
		if actor != null and target != null and not actor.active_abilities.is_empty():
			var index := clampi(selected_ability_index, 0, actor.active_abilities.size() - 1)
			var ability: AbilityData = actor.active_abilities[index]
			var rng: int = actor.get_ability_range(ability)
			var self_after_move: bool = (
				attack_target_id == unit_id
				and coord != actor.position
				and AbilitySystem.can_target_self(actor, ability)
			)
			if self_after_move and AbilitySystem.is_run_ability(ability):
				if plan_actor != null and AbilitySystem.movement_requires_run(plan_board, plan_actor, coord, waypoints):
					new_actions.append(
						TimelineAction.make_ability(
							unit_id, ability, actor.position, attack_target_id, GameEnums.MoveTiming.PRE_ACTION,
						),
					)
					new_actions.append(
						TimelineAction.make_move(unit_id, coord, -1, waypoints, GameEnums.MoveTiming.POST_ACTION),
					)
				else:
					new_actions.append(
						TimelineAction.make_move(unit_id, coord, -1, waypoints, move_timing),
					)
			elif self_after_move:
				new_actions.append(
					TimelineAction.make_move(unit_id, coord, -1, waypoints, move_timing),
				)
				new_actions.append(
					TimelineAction.make_ability(
						unit_id, ability, coord, attack_target_id, GameEnums.MoveTiming.PRE_ACTION,
					),
				)
			elif GridSystem.manhattan(actor.position, target.position) > rng:
				var approach := _find_approach_tile(start_board, actor, target.position, rng, coord)
				if approach != actor.position:
					new_actions.append(
						TimelineAction.make_move(unit_id, approach, -1, [], move_timing),
					)
				new_actions.append(
					TimelineAction.make_ability(
						unit_id, ability, target.position, attack_target_id, GameEnums.MoveTiming.PRE_ACTION,
					),
				)
			else:
				new_actions.append(
					TimelineAction.make_ability(
						unit_id, ability, target.position, attack_target_id, GameEnums.MoveTiming.PRE_ACTION,
					),
				)
	else:
		if (
			actor != null
			and not actor.active_abilities.is_empty()
			and selected_ability_index >= 0
			and selected_ability_index < actor.active_abilities.size()
		):
			var ability: AbilityData = actor.active_abilities[selected_ability_index]
			if AbilitySystem.is_run_ability(ability) and coord != actor.position:
				if plan_actor != null and AbilitySystem.movement_requires_run(plan_board, plan_actor, coord, waypoints):
					new_actions.append(
						TimelineAction.make_ability(
							unit_id, ability, actor.position, unit_id, GameEnums.MoveTiming.PRE_ACTION,
						),
					)
					new_actions.append(
						TimelineAction.make_move(unit_id, coord, -1, waypoints, GameEnums.MoveTiming.POST_ACTION),
					)
				else:
					new_actions.append(TimelineAction.make_move(unit_id, coord, -1, waypoints, move_timing))
			else:
				new_actions.append(TimelineAction.make_move(unit_id, coord, -1, waypoints, move_timing))
		else:
			new_actions.append(TimelineAction.make_move(unit_id, coord, -1, waypoints, move_timing))
	return _preview_from_plan(_build_preview_plan(unit_id, new_actions))


func preview_dash(unit_id: int, target_coord: Vector2i, ability_index: int = -1) -> Dictionary:
	var start_board: BoardState = base_board.clone()
	var actor := start_board.get_unit_by_id(unit_id)
	if actor == null or actor.active_abilities.is_empty():
		return {"intents": [], "events": [], "temp_board": start_board}
	var index: int = ability_index if ability_index >= 0 else selected_ability_index
	index = clampi(index, 0, actor.active_abilities.size() - 1)
	var ability: AbilityData = actor.active_abilities[index]
	var dash_action := TimelineAction.make_ability(unit_id, ability, target_coord, -1, GameEnums.MoveTiming.PRE_ACTION)
	return _preview_from_plan(_build_preview_plan(unit_id, [dash_action]))

@rpc("any_peer", "call_local", "reliable")
func rpc_reorder_action(from_index: int, to_index: int) -> void:
	var combined = _get_combined_plan()
	if from_index < 0 or from_index >= combined.size(): return
	var action = combined.entries[from_index]
	
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(action.actor_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id(): return
		
	var plan_to_use = _plan_for_timing(action.move_timing)
	
	# Compute local index
	var local_from = -1
	for i in range(plan_to_use.size()):
		if plan_to_use.entries[i] == action:
			local_from = i
			break
			
	var action_at_to = combined.entries[clampi(to_index, 0, combined.size() - 1)]
	if action_at_to.move_timing != action.move_timing:
		return # Cannot reorder across move-timing buckets
		
	var local_to = -1
	for i in range(plan_to_use.size()):
		if plan_to_use.entries[i] == action_at_to:
			local_to = i
			break
	
	plan_to_use.reorder(local_from, local_to)
	_refresh_plan()

@rpc("any_peer", "call_local", "reliable")
func rpc_plan_move_with_self_ability(
	unit_id: int,
	move_coord: Vector2i,
	face_dir: int,
	waypoints: Array[Vector2i],
	ability_index: int,
) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id():
			return
	if (not is_planning_phase(phase)) or unit_id < 0:
		return
	var target_timing := _get_move_timing(unit_id)
	if target_timing == -1:
		EventBus.action_rejected.emit("no_actions_left")
		return
	var plan_to_use := _plan_for_timing(target_timing)
	var attacker := board.get_unit_by_id(unit_id)
	if attacker == null or attacker.active_abilities.is_empty():
		return
	var index := clampi(ability_index, 0, attacker.active_abilities.size() - 1)
	var ability: AbilityData = attacker.active_abilities[index]
	if not AbilitySystem.can_target_self(attacker, ability):
		EventBus.action_rejected.emit("cannot_use_ability")
		return
	if AbilitySystem.is_run_ability(ability):
		if move_coord == attacker.position:
			return
		var p_unit := projected_state.get_unit_by_id(unit_id) if projected_state != null else attacker
		if p_unit == null:
			p_unit = attacker
		var plan_board: BoardState = projected_state if projected_state != null else board
		if AbilitySystem.movement_requires_run(plan_board, p_unit, move_coord, waypoints):
			rpc_plan_run_and_move(unit_id, move_coord, face_dir, waypoints, index)
		else:
			_clear_unit_from_plans(unit_id, target_timing)
			_try_add(
				TimelineAction.make_move(unit_id, move_coord, face_dir, waypoints, target_timing),
				plan_to_use,
			)
		return
	_clear_unit_from_plans(unit_id, target_timing)
	if move_coord == attacker.position:
		_try_add(
			TimelineAction.make_ability(unit_id, ability, attacker.position, unit_id, target_timing),
			plan_to_use,
		)
		return
	var move_action := TimelineAction.make_move(unit_id, move_coord, face_dir, waypoints, target_timing)
	var ability_action := TimelineAction.make_ability(
		unit_id, ability, attacker.position, unit_id, GameEnums.MoveTiming.PRE_ACTION,
	)
	_try_add_multiple([move_action, ability_action], [plan_to_use, plan_to_use])


@rpc("any_peer", "call_local", "reliable")
func rpc_plan_run_and_move(
	unit_id: int,
	move_coord: Vector2i,
	face_dir: int,
	waypoints: Array[Vector2i],
	ability_index: int,
) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id():
			return
	if (not is_planning_phase(phase)) or unit_id < 0:
		return
	var attacker := board.get_unit_by_id(unit_id)
	if attacker == null or attacker.active_abilities.is_empty():
		return
	var index := clampi(ability_index, 0, attacker.active_abilities.size() - 1)
	var ability: AbilityData = attacker.active_abilities[index]
	if not AbilitySystem.is_run_ability(ability):
		return
	if attacker.ability.points_left < ability.action_point_cost:
		EventBus.action_rejected.emit("cannot_use_ability")
		return
	if move_coord == attacker.position:
		return
	var p_unit := projected_state.get_unit_by_id(unit_id) if projected_state != null else attacker
	if p_unit == null:
		p_unit = attacker
	var plan_board: BoardState = projected_state if projected_state != null else board
	if not AbilitySystem.movement_requires_run(plan_board, p_unit, move_coord, waypoints):
		rpc_plan_move(unit_id, move_coord, face_dir, waypoints)
		return
	_clear_unit_from_plans(unit_id, GameEnums.MoveTiming.PRE_ACTION)
	var ability_action := TimelineAction.make_ability(
		unit_id, ability, attacker.position, unit_id, GameEnums.MoveTiming.PRE_ACTION,
	)
	var move_action := TimelineAction.make_move(
		unit_id, move_coord, face_dir, waypoints, GameEnums.MoveTiming.POST_ACTION,
	)
	_try_add_multiple([ability_action, move_action], [plan_pre_move, plan_post_move])


@rpc("any_peer", "call_local", "reliable")
func rpc_plan_attack(unit_id: int, ability_index: int, target_unit_id: int) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id(): return

	if (not is_planning_phase(phase)) or unit_id < 0:
		return
	if is_wait_ability_index(ability_index):
		rpc_plan_wait(unit_id)
		return
	var target_timing = _get_move_timing(unit_id)
	if target_timing == -1: return
	var plan_to_use = _plan_for_timing(target_timing)
	
	var attacker := board.get_unit_by_id(unit_id)
	if attacker == null or attacker.active_abilities.is_empty(): return
	var target := board.get_unit_by_id(target_unit_id)
	if target == null: return
	var index := clampi(ability_index, 0, attacker.active_abilities.size() - 1)
	var ability: AbilityData = attacker.active_abilities[index]
	
	var proj := _get_planning_state(target_timing)
	var projected_target := proj.get_unit_by_id(target_unit_id)
	var coord: Vector2i = projected_target.position if projected_target != null else target.position
	_try_add(TimelineAction.make_ability(unit_id, ability, coord, target_unit_id, target_timing), plan_to_use)

@rpc("any_peer", "call_local", "reliable")
func rpc_plan_ability_at_coord(unit_id: int, ability_index: int, coord: Vector2i) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id():
			return

	if (not is_planning_phase(phase)) or unit_id < 0:
		return
	var target_timing = _get_move_timing(unit_id)
	if target_timing == -1:
		return
	var plan_to_use = _plan_for_timing(target_timing)

	var attacker := board.get_unit_by_id(unit_id)
	if attacker == null or attacker.active_abilities.is_empty():
		return
	var index := clampi(ability_index, 0, attacker.active_abilities.size() - 1)
	var ability: AbilityData = attacker.active_abilities[index]
	_clear_unit_from_plans(unit_id, target_timing)
	_try_add(TimelineAction.make_ability(unit_id, ability, coord, -1, target_timing), plan_to_use)

@rpc("any_peer", "call_local", "reliable")
func rpc_remove_last_for_unit(unit_id: int) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id(): return

	if is_planning_phase(phase):
		if plan_post_move.size() > 0:
			for i in range(plan_post_move.size() - 1, -1, -1):
				if plan_post_move.entries[i].actor_id == unit_id:
					if plan_post_move.entries[i].irreversible:
						EventBus.action_rejected.emit("cannot_undo_trample")
						return
					plan_post_move.remove_at(i)
					plan_affected_unit_ids = [unit_id]
					_refresh_plan()
					return
		if plan_pre_move.size() > 0:
			for i in range(plan_pre_move.size() - 1, -1, -1):
				if plan_pre_move.entries[i].actor_id == unit_id:
					if plan_pre_move.entries[i].irreversible:
						EventBus.action_rejected.emit("cannot_undo_trample")
						return
					plan_pre_move.remove_at(i)
					plan_affected_unit_ids = [unit_id]
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

	if index < plan_pre_move.size():
		if plan_pre_move.entries[index].irreversible:
			EventBus.action_rejected.emit("cannot_undo_trample")
			return
		plan_pre_move.remove_at(index)
	elif index - plan_pre_move.size() < plan_post_move.size():
		if plan_post_move.entries[index - plan_pre_move.size()].irreversible:
			EventBus.action_rejected.emit("cannot_undo_trample")
			return
		plan_post_move.remove_at(index - plan_pre_move.size())
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
	if base_unit != null and is_planning_phase(phase):
		# Occupancy check: if the unit moved, and its start square is now occupied by ANOTHER unit, reject clear.
		var occ := board.get_unit_at(base_unit.position)
		if occ != null and occ.id != unit_id:
			EventBus.action_rejected.emit("Undo not possible: initial square occupied")
			return

	for plan in [plan_pre_move, plan_post_move]:
		for a in plan.entries:
			if a.actor_id == unit_id and a.irreversible:
				EventBus.action_rejected.emit("cannot_undo_trample")
				return

	if is_planning_phase(phase):
		var kept_1: Array[TimelineAction] = []
		for a in plan_pre_move.entries:
			if a.actor_id != unit_id:
				kept_1.append(a)
		plan_pre_move.entries = kept_1
		var kept_2: Array[TimelineAction] = []
		for a in plan_post_move.entries:
			if a.actor_id != unit_id:
				kept_2.append(a)
		plan_post_move.entries = kept_2
		plan_affected_unit_ids = [unit_id]
	_refresh_plan()

func clear_plan() -> void:
	if is_planning_phase(phase):
		plan_pre_move.clear()
		plan_post_move.clear()
	_refresh_plan()

func restart_turn() -> void:
	if turn_start_board == null:
		return
	_run_id += 1
	base_board = turn_start_board.clone()
	board = base_board.clone()
	plan_pre_move.clear()
	plan_post_move.clear()
	selected_unit_id = -1
	selected_ability_index = 0
	_set_phase(Phase.PLANNING)
	EventBus.board_changed.emit(board)
	EventBus.selection_changed.emit(selected_unit_id)
	EventBus.ability_selected.emit(selected_ability_index)
	_refresh_plan()

func restart() -> void:
	if initial_board != null:
		base_board = initial_board.clone()
	_init_combat()

func execute_turn() -> void:
	if not is_planning_phase(phase):
		return
	var current_run_id: int = _run_id
	var combined := _get_combined_plan()
	var result: SimResult = Simulator.simulate(base_board, combined)
	_set_phase(Phase.EXECUTING)
	await _play_events(result.events)
	if current_run_id != _run_id:
		return
	base_board = result.final_state
	plan_pre_move.clear()
	plan_post_move.clear()
	if _check_end_state():
		return
	_refresh_plan()
	_set_phase(Phase.PLANNING)
	_capture_turn_start()


func _ready() -> void:
	if not GlobalTimeline.player_ready_changed.is_connected(_on_player_ready_changed):
		GlobalTimeline.player_ready_changed.connect(_on_player_ready_changed)

func _on_player_ready_changed(_player_id: int, _is_ready: bool) -> void:
	if NetworkManager == null or not NetworkManager.is_multiplayer or multiplayer.is_server():
		if GlobalTimeline.is_everyone_ready():
			if is_planning_phase(phase):
				if multiplayer.has_multiplayer_peer():
					rpc_commit_phase.rpc()
				else:
					rpc_commit_phase()

@rpc("authority", "call_local", "reliable")
func rpc_commit_phase() -> void:
	GlobalTimeline.rpc_reset_ready_states()
	if is_planning_phase(phase):
		execute_turn()

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
	
	# --- Movement batch: all units move at the same time ---
	if not move_events.is_empty():
		var max_path_len := 0
		for e in move_events:
			if run_id != _run_id: return
			EventBus.sim_event.emit(e)
			max_path_len = max(max_path_len, (e.data.get("path", []) as Array).size())
		await get_tree().create_timer(max(1, max_path_len) * MOVE_STEP_TIME + 0.05).timeout
		if run_id != _run_id: return
	
	# --- Attack batch: sequential, one action at a time ---
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
	for plan in [plan_pre_move, plan_post_move]:
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
	if not is_planning_phase(phase):
		return false
	for i in range(plan_post_move.size() - 1, -1, -1):
		if plan_post_move.entries[i].actor_id == unit_id:
			return not plan_post_move.entries[i].irreversible
	for i in range(plan_pre_move.size() - 1, -1, -1):
		if plan_pre_move.entries[i].actor_id == unit_id:
			return not plan_pre_move.entries[i].irreversible
	return false


func _refresh_plan() -> void:
	var move_only := base_board.clone()
	var full_proj := base_board.clone()
	var statuses := PackedStringArray()
	var anim_events: Array[SimEvent] = []
	var any_cancelled := false
	
	var plan_to_run := _get_combined_plan()
	
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
		_pending_refresh_sim.clear()
		_refresh_plan()
		return

	_commit_animate_actions.clear()
		
	var dummy_ev: Array[SimEvent] = []
	ResolutionPipeline.resolve_pending_pushes(full_proj, dummy_ev)

	var player_events: Array[SimEvent] = []
	if not _pending_refresh_sim.is_empty():
		projected_state = (_pending_refresh_sim["projected"] as BoardState).clone()
		for e: SimEvent in _pending_refresh_sim["player_events"]:
			player_events.append(e)
		_pending_refresh_sim.clear()
	else:
		projected_state = base_board.clone()
		Simulator.simulate_player_turn(projected_state, plan_to_run, player_events)
		
	board = move_only
	var new_intents := EnemyPlanner.plan(projected_state)
	base_board.intents = new_intents
	board.intents = new_intents
	projected_state.intents = new_intents

	if not anim_events.is_empty():
		EventBus.planning_commit_events.emit(anim_events)
	plan_revision += 1
	EventBus.board_changed.emit(board)
	EventBus.timeline_changed.emit(plan_to_run, statuses)
	
	var preview_board: BoardState = projected_state.clone()
	var evs: Array[SimEvent] = []
	for e: SimEvent in player_events:
		evs.append(e)
	evs.append(SimEvent.make(GameEnums.SimEventType.ENEMY_PHASE_BEGAN, {}))
	for intent: Intent in new_intents:
		for action: TimelineAction in intent.actions:
			ResolutionPipeline.apply_action(preview_board, action, evs)
	ResolutionPipeline.resolve_pending_pushes(preview_board, evs)
	
	var sim_res := SimResult.new(preview_board)
	sim_res.events = evs
	_queue_preview_updated(sim_res)

func _queue_preview_updated(result: SimResult) -> void:
	_queued_preview = result
	call_deferred("_emit_queued_preview")


func _emit_queued_preview() -> void:
	if _queued_preview == null:
		return
	var res: SimResult = _queued_preview
	_queued_preview = null
	EventBus.preview_updated.emit(res)

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
	# (Assuming view might break if we send new phase without updating view layer. Let's send 0 for PLANNING and PLANNING if view expects it... actually EventBus can just emit it, and if UI expects PLANNING=0, we'll see.)
	EventBus.turn_phase_changed.emit(phase)

func _build_demo_encounter() -> BoardState:
	var map = DataLibrary.get_all_maps()[0]
	return BoardFactory.build_from_encounter(map.encounter)

