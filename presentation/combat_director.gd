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
const RUN_STEP_TIME: float = 0.14    ## seconds per tile when running (faster than walk)
const DASH_STEP_TIME: float = 0.08   ## seconds per tile during dash abilities
const ATTACK_ANIM_TIME: float = 0.35 ## how long attack animations take
const PUSH_ANIM_FALLBACK: float = 1.0 ## Safety timeout if push signal never arrives

var base_board: BoardState
var board: BoardState
var plan_pre_move: Timeline = Timeline.new()
var plan_action: Timeline = Timeline.new()
var plan_post_move: Timeline = Timeline.new()
var phase: Phase = Phase.PLANNING
var selected_unit_id: int = -1
var selected_ability_index: int = 0
## Last chosen ability slot per unit (planning UI memory).
var unit_ability_memory: Dictionary = {}
## Board after ONLY the player's queued actions (no enemy intents). Drives range,
## reachability and target highlights so they follow planned moves, not start tiles.
var projected_state: BoardState
var _run_id: int = 0
## Actor ids whose MOVE was just committed via _try_add_multiple (planning walk anim).
var _commit_animate_actor_ids: Dictionary = {}
var initial_board: BoardState
## Snapshot at the start of the current player turn (planning).
var turn_start_board: BoardState
## Incremented on every successful _refresh_plan — cheap cache-bust for hover previews.
var plan_revision: int = 0
## Units whose plan was removed this refresh — forces visual resync (e.g. undo during walk).
var plan_affected_unit_ids: Array[int] = []
## When true, Run is hidden from the skill list and applied automatically for out-of-range moves.
var auto_run: bool = false
## Drag-drop move commits snap instantly; selection/hover commits walk/run on plan.
var _instant_planning_move_units: Dictionary = {}
## Hidden exhaustion slot (Master Bible § Universal Wait) — not in plan_action.
var _wait_unit_ids: Dictionary = {}
var _plan_refresh_emit_pending: bool = false
var _pending_refresh_board: BoardState
var _pending_refresh_plan: Timeline
var _pending_refresh_statuses: PackedStringArray
var _pending_refresh_preview: SimResult
## Undo/remove: snap sprites immediately; enables sim-only fast path (never skips walk/run on commit).
var plan_refresh_snap_units: bool = false
## Defer heavy overlay preview rebuild one frame (walk commit / undo snap).
var plan_refresh_defer_overlay: bool = false
## Snap undo back to turn-start layout: skip hover/stats churn in overlay apply.
var plan_refresh_light_overlay: bool = false
var _turn_start_intents: Array = []
var _turn_start_enemy_ghost_events: Array[SimEvent] = []
var _pending_planning_commit_events: Array[SimEvent] = []
## Swap premoves: play planning presentation before snapping sprites to swapped board tiles.
var _swap_planning_presentations: Array[TimelineAction] = []
## Execute replay: skip player premove visuals already shown during planning commit.
var _skip_committed_premove_visuals: bool = false
var _execute_premove_skip_actions: Array[TimelineAction] = []
var _refresh_plan_queued: bool = false
var _cached_wait_marker_ghost_events: Array[SimEvent] = []
## Autobattler batches rpc_plan_move commits; one parallel planning walk plays at batch end.
var _autobattler_plan_batch: bool = false
## When this returns true, default victory/defeat checks are skipped (battle continues).
var suppress_end_state: Callable = Callable()


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


## First active_abilities index the unit can commit right now (projected state).
static func first_selectable_ability_index(unit: UnitState, projected_state: BoardState, skip_run: bool = false) -> int:
	if unit == null:
		return -1
	var abilities: Array = unit.active_abilities
	for i: int in range(abilities.size()):
		var ability: AbilityData = abilities[i]
		if skip_run and ability.is_universal_run():
			continue
		if AbilitySystem.ability_planning_selectable(unit, ability, projected_state):
			return i
	return -1


static func _get_all_selectable_abilities(unit: UnitState, projected_state: BoardState, skip_run: bool = false) -> Array[int]:
	if unit == null or not unit.is_alive():
		return []
	var abilities: Array = unit.active_abilities
	var selectable: Array[int] = []
	for i: int in range(abilities.size()):
		var ability: AbilityData = abilities[i]
		if skip_run and ability.is_universal_run():
			continue
		if AbilitySystem.ability_planning_selectable(unit, ability, projected_state):
			selectable.append(i)
	return selectable


## Scroll-wheel helper: step only among abilities that are planning-selectable.
static func next_selectable_ability_index(
	unit: UnitState,
	projected_state: BoardState,
	current: int,
	delta: int,
	skip_run: bool = false,
) -> int:
	if unit == null or unit.active_abilities.is_empty():
		return -1
	var selectable: Array[int] = _get_all_selectable_abilities(unit, projected_state, skip_run)
	if selectable.is_empty():
		return -1
	if selectable.size() == 1:
		return selectable[0]
	var pos: int = selectable.find(current)
	if pos < 0:
		return selectable[0] if delta > 0 else selectable[selectable.size() - 1]
	pos = (pos + delta + selectable.size()) % selectable.size()
	return selectable[pos]


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
	plan_action = Timeline.new()
	plan_post_move = Timeline.new()
	_wait_unit_ids.clear()
	_instant_planning_move_units.clear()
	_pending_planning_commit_events.clear()
	_swap_planning_presentations.clear()
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
	sync_selected_ability_if_invalid()
	_emit_planning_selection()


func remember_unit_ability(unit_id: int, ability_index: int) -> void:
	if unit_id < 0:
		return
	unit_ability_memory[unit_id] = ability_index


func _emit_planning_selection() -> void:
	EventBus.selection_changed.emit(selected_unit_id)
	EventBus.ability_selected.emit(selected_ability_index)

## Choose which of the selected unit's abilities a queued attack will use.
func select_ability(index: int, remember_choice: bool = true) -> void:
	if not is_planning_phase(phase):
		return
	if is_wait_ability_index(index):
		if selected_ability_index == index:
			return
		selected_ability_index = index
		if remember_choice:
			remember_unit_ability(selected_unit_id, selected_ability_index)
		EventBus.ability_selected.emit(selected_ability_index)
		return
	if index < 0:
		if selected_ability_index == -1:
			return
		selected_ability_index = -1
		EventBus.ability_selected.emit(selected_ability_index)
		return
	var unit := board.get_unit_by_id(selected_unit_id)
	if unit == null or index >= unit.active_abilities.size():
		return
	if auto_run:
		var picked: AbilityData = unit.active_abilities[index] as AbilityData
		if picked != null and picked.is_universal_run():
			sync_selected_ability_if_invalid()
			return
	if selected_ability_index == index:
		return
	selected_ability_index = index
	if remember_choice:
		remember_unit_ability(selected_unit_id, selected_ability_index)
	EventBus.ability_selected.emit(selected_ability_index)


func sync_selected_ability_if_invalid() -> void:
	if not is_planning_phase(phase) or selected_unit_id < 0:
		return
	if find_awaiting_action(selected_unit_id) != null:
		return
	if is_wait_ability_index(selected_ability_index):
		return
	var p_unit: UnitState = (
		projected_state.get_unit_by_id(selected_unit_id)
		if projected_state != null
		else board.get_unit_by_id(selected_unit_id)
	)
	if p_unit == null:
		if selected_ability_index != -1:
			select_ability(-1)
		return
	if (
		selected_ability_index >= 0
		and selected_ability_index < p_unit.active_abilities.size()
	):
		var current: AbilityData = p_unit.active_abilities[selected_ability_index] as AbilityData
		if auto_run and current.is_universal_run():
			pass
		else:
			return
	var next: int = first_selectable_ability_index(p_unit, projected_state, auto_run)
	if next != selected_ability_index:
		select_ability(next, false)

@rpc("any_peer", "call_local", "reliable")
func rpc_plan_wait(unit_id: int) -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		var u := base_board.get_unit_by_id(unit_id)
		if u == null or u.controlling_player_id != multiplayer.get_remote_sender_id():
			return
	if (not is_planning_phase(phase)) or unit_id < 0:
		return
	if unit_has_wait_planned(unit_id):
		_clear_unit_wait(unit_id)
		plan_affected_unit_ids = [unit_id]
		_queue_refresh_plan()
		return
	var target_timing: int = _get_move_timing(unit_id)
	if target_timing != GameEnums.MoveTiming.PRE_ACTION:
		EventBus.action_rejected.emit("no_actions_left")
		return
	var p_unit := projected_state.get_unit_by_id(unit_id) if projected_state != null else board.get_unit_by_id(unit_id)
	if p_unit == null or not p_unit.can_use_action_slot():
		EventBus.action_rejected.emit("no_actions_left")
		return
	_clear_unit_class_actions_from_plan(unit_id)
	_clear_unit_post_moves_from_plan(unit_id)
	_set_unit_waiting(unit_id, true)
	selected_ability_index = -1
	EventBus.ability_selected.emit(selected_ability_index)
	plan_affected_unit_ids = [unit_id]
	_queue_refresh_plan()


func unit_has_wait_planned(unit_id: int) -> bool:
	return _wait_unit_ids.has(unit_id)


func unit_has_committed_class_action(unit_id: int) -> bool:
	for action: TimelineAction in plan_action.entries:
		if action.actor_id != unit_id:
			continue
		if action.type != GameEnums.ActionType.ABILITY:
			continue
		if action.ability != null and action.ability.kind == GameEnums.AbilityKind.UNIVERSAL_WAIT:
			continue
		return true
	return false


func _set_unit_waiting(unit_id: int, waiting: bool) -> void:
	if waiting:
		_wait_unit_ids[unit_id] = true
	else:
		_wait_unit_ids.erase(unit_id)


func _clear_unit_wait(unit_id: int) -> void:
	_wait_unit_ids.erase(unit_id)


func _make_wait_action(unit_id: int) -> TimelineAction:
	var p_unit := projected_state.get_unit_by_id(unit_id) if projected_state != null else board.get_unit_by_id(unit_id)
	var pos: Vector2i = p_unit.position if p_unit != null else Vector2i.ZERO
	return TimelineAction.make_ability(
		unit_id,
		DataLibrary.get_universal_wait(),
		pos,
		unit_id,
		GameEnums.MoveTiming.PRE_ACTION,
	)


func _clear_unit_class_actions_from_plan(unit_id: int) -> void:
	var kept: Array[TimelineAction] = []
	for action: TimelineAction in plan_action.entries:
		if action.actor_id == unit_id:
			continue
		kept.append(action)
	plan_action.entries = kept


func find_awaiting_action(unit_id: int) -> TimelineAction:
	if unit_id < 0:
		return null
	for action: TimelineAction in plan_action.entries:
		if action.actor_id != unit_id or not action.awaiting_target:
			continue
		if action.type != GameEnums.ActionType.ABILITY or action.ability == null:
			continue
		return action
	return null


func set_awaiting_action(unit_id: int, ability: AbilityData) -> void:
	if unit_id < 0 or ability == null:
		return
	var actor: UnitState = (
		projected_state.get_unit_by_id(unit_id)
		if projected_state != null
		else board.get_unit_by_id(unit_id)
	)
	if actor == null:
		actor = board.get_unit_by_id(unit_id)
	if actor == null:
		return
	_clear_unit_class_actions_from_plan(unit_id)
	var action: TimelineAction = TimelineAction.make_ability_awaiting(
		unit_id, ability, actor.position,
	)
	plan_action.entries.append(action)
	plan_affected_unit_ids = [unit_id]
	_refresh_plan()


func clear_awaiting_action(unit_id: int) -> void:
	if unit_id < 0:
		return
	var kept: Array[TimelineAction] = []
	var removed: bool = false
	for action: TimelineAction in plan_action.entries:
		if action.actor_id == unit_id and action.awaiting_target:
			removed = true
			continue
		kept.append(action)
	if not removed:
		return
	plan_action.entries = kept
	plan_affected_unit_ids = [unit_id]
	_refresh_plan()


func _try_finalize_awaiting_from_slots(unit_id: int, slots: Dictionary) -> bool:
	var awaiting: TimelineAction = find_awaiting_action(unit_id)
	if awaiting == null:
		return false
	for raw: Variant in slots.get("action", []):
		if not raw is TimelineAction:
			continue
		var action: TimelineAction = raw as TimelineAction
		if action.type != GameEnums.ActionType.ABILITY or action.ability == null:
			continue
		if awaiting.ability != action.ability:
			return false
		awaiting.target_coord = action.target_coord
		awaiting.target_unit_id = action.target_unit_id
		awaiting.waypoints = action.waypoints.duplicate()
		awaiting.face_dir = action.face_dir
		awaiting.awaiting_target = false
		return true
	return false


func _plan_for_ability(ability: AbilityData) -> Timeline:
	if ability != null and ability.is_movement_kind():
		return plan_pre_move
	return plan_action


func _plan_containing_action(action: TimelineAction) -> Timeline:
	if action == null:
		return plan_pre_move
	if action.type == GameEnums.ActionType.ABILITY and action.ability != null:
		return _plan_for_ability(action.ability)
	if action.move_timing == GameEnums.MoveTiming.POST_ACTION:
		return plan_post_move
	return plan_pre_move


func _all_plans() -> Array:
	return [plan_pre_move, plan_action, plan_post_move]


func _cancel_ally_plans_after_movement_step(step: TimelineAction) -> void:
	var allies: Array[int] = PlanDependency.ally_ids_affected_by_action(board, step)
	if allies.is_empty():
		return
	var combined: Timeline = _get_combined_plan()
	if PlanDependency.cancel_ally_plans_after_step(combined, _all_plans(), step, allies):
		EventBus.action_rejected.emit("ally_plan_cancelled")


func _clear_unit_abilities_from_plan(unit_id: int, timing: int) -> void:
	_clear_unit_class_actions_from_plan(unit_id)
	if timing == GameEnums.MoveTiming.PRE_ACTION:
		var kept: Array[TimelineAction] = []
		for action: TimelineAction in plan_pre_move.entries:
			if action.actor_id == unit_id and action.type == GameEnums.ActionType.ABILITY:
				continue
			kept.append(action)
		plan_pre_move.entries = kept


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
	if projected_state != null:
		return projected_state.clone()
	return base_board.clone()


func get_planning_move_timing(unit_id: int) -> int:
	return _get_move_timing(unit_id)


func _get_move_timing(unit_id: int) -> int:
	if unit_has_wait_planned(unit_id):
		return -1
	var p_unit := projected_state.get_unit_by_id(unit_id) if projected_state != null else board.get_unit_by_id(unit_id)
	if p_unit == null:
		return -1
	if p_unit.has_used_turn_action():
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


func unit_has_move_planned_at_timing(unit_id: int, timing: int) -> bool:
	return _unit_has_move_queued_for_timing(unit_id, timing)


func _unit_has_move_queued_for_timing(unit_id: int, timing: int) -> bool:
	if timing == GameEnums.MoveTiming.PRE_ACTION:
		return _unit_has_pre_move_queued(unit_id)
	if timing == GameEnums.MoveTiming.POST_ACTION:
		return _unit_has_post_move_queued(unit_id)
	return false


func _reject_if_move_slot_filled(unit_id: int, timing: int) -> bool:
	if not _unit_has_move_queued_for_timing(unit_id, timing):
		return false
	EventBus.action_rejected.emit("move_already_planned")
	return true


func _unit_can_post_move(unit_id: int, p_unit: UnitState) -> bool:
	if unit_has_wait_planned(unit_id):
		return false
	if _unit_has_post_move_queued(unit_id):
		return false
	if not p_unit.has_used_turn_action():
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
	if _reject_if_move_slot_filled(unit_id, target_timing):
		return

	_clear_unit_from_plans(unit_id, target_timing)
	var plan_board: BoardState = projected_state if projected_state != null else board
	var actor: UnitState = plan_board.get_unit_by_id(unit_id) if plan_board != null else null
	var uses_run: bool = false
	if auto_run and actor != null and AbilitySystem.can_afford_run(actor):
		uses_run = AbilitySystem.movement_requires_run(plan_board, actor, coord, waypoints)
	var action: TimelineAction
	if uses_run:
		action = TimelineAction.make_run_move(unit_id, coord, face_dir, waypoints, target_timing)
	else:
		action = TimelineAction.make_move(unit_id, coord, face_dir, waypoints, target_timing)
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
			
		var max_steps: int = planning_move_budget(actor, proj)
		var waypoints: Array[Vector2i] = []
		move_action = make_planning_move_action(
			unit_id, approach, proj, actor, waypoints, GameEnums.MoveTiming.PRE_ACTION,
		)

	var trial := proj.clone()
	
	if move_action != null:
		if _reject_if_move_slot_filled(unit_id, GameEnums.MoveTiming.PRE_ACTION):
			return
		# Approach move + ability queued together in pre-action bucket
		var after_actor := trial.get_unit_by_id(target_unit_id)
		var attack_action := TimelineAction.make_ability(unit_id, ability,
			after_actor.position if after_actor != null else target.position, target_unit_id, GameEnums.MoveTiming.PRE_ACTION)
		_clear_unit_from_plans(unit_id, GameEnums.MoveTiming.PRE_ACTION)
		_try_add_multiple([move_action, attack_action], [plan_pre_move, plan_action])
		return

	# No approach needed, just attack
	_clear_unit_wait(unit_id)
	_clear_unit_class_actions_from_plan(unit_id)
	_clear_unit_post_moves_from_plan(unit_id)
	var after_actor := trial.get_unit_by_id(target_unit_id)
	var attack_action := TimelineAction.make_ability(unit_id, ability,
		after_actor.position if after_actor != null else target.position, target_unit_id, GameEnums.MoveTiming.PRE_ACTION)
	if ability.is_movement_kind():
		_try_add(attack_action, plan_pre_move)
	else:
		_try_add(attack_action, plan_action)


## Approach tile for attack-with-approach preview (cursor / UI only).
func preview_approach_tile(
	unit_id: int,
	target_unit_id: int,
	ability_index: int,
	preferred_tile: Vector2i,
) -> Vector2i:
	var proj: BoardState = _get_planning_state()
	var actor: UnitState = proj.get_unit_by_id(unit_id)
	var target: UnitState = proj.get_unit_by_id(target_unit_id)
	if actor == null:
		return preferred_tile
	if target == null or actor.active_abilities.is_empty():
		return actor.position
	var index: int = clampi(ability_index, 0, actor.active_abilities.size() - 1)
	var ability: AbilityData = actor.active_abilities[index]
	var rng: int = actor.get_ability_range(ability)
	if GridSystem.manhattan(actor.position, target.position) <= rng:
		return actor.position
	return _find_approach_tile(proj, actor, target.position, rng, preferred_tile)


func planning_move_budget(actor: UnitState, board: BoardState = null) -> int:
	if actor == null:
		return 0
	var plan_board: BoardState = board if board != null else _get_planning_state()
	var plan_actor: UnitState = plan_board.get_unit_by_id(actor.id) if plan_board != null else null
	if plan_actor != null:
		actor = plan_actor
	if auto_run and AbilitySystem.can_afford_run(actor):
		return AbilitySystem.preview_move_budget_with_run(actor)
	return actor.movement.points_left


func make_planning_move_action(
	unit_id: int,
	dest: Vector2i,
	board: BoardState,
	actor: UnitState,
	waypoints: Array[Vector2i],
	timing: int,
) -> TimelineAction:
	if (
		auto_run
		and actor != null
		and AbilitySystem.can_afford_run(actor)
		and AbilitySystem.movement_requires_run(board, actor, dest, waypoints)
	):
		return TimelineAction.make_run_move(unit_id, dest, -1, waypoints, timing)
	return TimelineAction.make_move(unit_id, dest, -1, waypoints, timing)


func preview_commit_valid(unit_id: int, actions: Array[TimelineAction]) -> String:
	if unit_id < 0 or actions.is_empty():
		return "invalid"
	var combined: Timeline = _build_preview_plan(unit_id, actions)
	var trial: BoardState = base_board.clone()
	var ev: Array[SimEvent] = []
	Simulator.simulate_player_turn(trial, combined, ev)
	for e: SimEvent in ev:
		if e.type != GameEnums.SimEventType.ACTION_FAILED:
			continue
		if int(e.data.get("actor", -1)) == unit_id:
			return e.data.get("reason", "cannot_use_ability") as String
	return ""


func commit_from_slots(unit_id: int, slots: Dictionary) -> bool:
	if slots.has("invalid") and (typeof(slots["invalid"]) == TYPE_BOOL and slots["invalid"] or typeof(slots["invalid"]) == TYPE_STRING and slots["invalid"] != ""):
		var reason: String = slots["invalid"] if typeof(slots["invalid"]) == TYPE_STRING else "cannot_use_ability"
		EventBus.action_rejected.emit(reason)
		return false
	var actions: Array[TimelineAction] = []
	var plans: Array[Timeline] = []
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if raw is TimelineAction:
				var action: TimelineAction = raw as TimelineAction
				actions.append(action)
				plans.append(_slot_plan_for_action(action))
	if actions.is_empty():
		return false
	if _actions_are_wait_only(actions):
		rpc_plan_wait(unit_id)
		return true
	if unit_has_wait_planned(unit_id):
		EventBus.action_rejected.emit("no_actions_left")
		return false
	if slots.get("_preview_validated", false) != true:
		var reason := preview_commit_valid(unit_id, actions)
		if reason != "":
			EventBus.action_rejected.emit(reason)
			return false
	var has_pre_move: bool = not (slots.get("pre", []) as Array).is_empty()
	var has_action: bool = not (slots.get("action", []) as Array).is_empty()
	if has_pre_move and _slots_contain_move_for_unit(slots, unit_id, GameEnums.MoveTiming.PRE_ACTION):
		if _reject_if_move_slot_filled(unit_id, GameEnums.MoveTiming.PRE_ACTION):
			return false
		_clear_unit_moves_from_plan_at_timing(unit_id, GameEnums.MoveTiming.PRE_ACTION)
	if has_action:
		if _try_finalize_awaiting_from_slots(unit_id, slots):
			if has_pre_move and _slots_contain_move_for_unit(slots, unit_id, GameEnums.MoveTiming.PRE_ACTION):
				if _reject_if_move_slot_filled(unit_id, GameEnums.MoveTiming.PRE_ACTION):
					return false
				_clear_unit_moves_from_plan_at_timing(unit_id, GameEnums.MoveTiming.PRE_ACTION)
				for raw: Variant in slots.get("pre", []):
					if raw is TimelineAction:
						_try_add(raw as TimelineAction, plan_pre_move)
			plan_affected_unit_ids = [unit_id]
			_refresh_plan()
			return true
		_clear_unit_wait(unit_id)
		_clear_unit_class_actions_from_plan(unit_id)
		_clear_unit_post_moves_from_plan(unit_id)
	_try_add_multiple(actions, plans)
	return true


func _actions_are_wait_only(actions: Array[TimelineAction]) -> bool:
	if actions.size() != 1:
		return false
	var action: TimelineAction = actions[0]
	return (
		action.type == GameEnums.ActionType.ABILITY
		and action.ability != null
		and action.ability.is_universal_wait()
	)


func _slot_plan_for_action(action: TimelineAction) -> Timeline:
	if action.type == GameEnums.ActionType.MOVE:
		if action.move_timing == GameEnums.MoveTiming.POST_ACTION:
			return plan_post_move
		return plan_pre_move
	if action.type == GameEnums.ActionType.ABILITY and action.ability != null:
		if action.ability.is_movement_kind():
			return plan_pre_move
	return plan_action


func _slots_contain_move_for_unit(slots: Dictionary, unit_id: int, timing: int) -> bool:
	var col: String = "post" if timing == GameEnums.MoveTiming.POST_ACTION else "pre"
	for raw: Variant in slots.get(col, []):
		if not raw is TimelineAction:
			continue
		var action: TimelineAction = raw as TimelineAction
		if (
			action.actor_id == unit_id
			and action.type == GameEnums.ActionType.MOVE
			and action.move_timing == timing
		):
			return true
	return false


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
			var dist: int = GridSystem.manhattan(actor.position, coord)
			if dist < best_len:
				best_len = dist
				best = coord
	return best

func _is_attack_tile(state: BoardState, actor: UnitState, coord: Vector2i, target_pos: Vector2i, rng: int) -> bool:
	if coord == actor.position or not GridSystem.is_in_bounds(state, coord):
		return false
	if GridSystem.manhattan(coord, target_pos) > rng or not GridSystem.is_passable(state, coord):
		return false
	var dist: int = GridSystem.manhattan(actor.position, coord)
	return dist <= planning_move_budget(actor, state)

func _clear_unit_from_plans(unit_id: int, from_timing: int) -> void:
	if from_timing <= GameEnums.MoveTiming.PRE_ACTION:
		var kept_1: Array[TimelineAction] = []
		for a in plan_pre_move.entries: if a.actor_id != unit_id: kept_1.append(a)
		plan_pre_move.entries = kept_1
	if from_timing <= GameEnums.MoveTiming.POST_ACTION:
		var kept_2: Array[TimelineAction] = []
		for a in plan_post_move.entries: if a.actor_id != unit_id: kept_2.append(a)
		plan_post_move.entries = kept_2


func _clear_unit_moves_from_plan_at_timing(unit_id: int, timing: int) -> void:
	var plan: Timeline = (
		plan_post_move if timing == GameEnums.MoveTiming.POST_ACTION else plan_pre_move
	)
	var kept: Array[TimelineAction] = []
	for action: TimelineAction in plan.entries:
		if action.actor_id == unit_id and action.type == GameEnums.ActionType.MOVE:
			continue
		kept.append(action)
	plan.entries = kept

func _try_add(action: TimelineAction, target_plan: Timeline) -> void:
	_try_add_multiple([action], [target_plan])

func _try_add_multiple(actions: Array[TimelineAction], target_plans: Array[Timeline]) -> void:
	var temp_p1 := Timeline.new()
	var temp_act := Timeline.new()
	var temp_p2 := Timeline.new()
	for a: TimelineAction in plan_pre_move.entries:
		temp_p1.add(a)
	for a: TimelineAction in plan_action.entries:
		temp_act.add(a)
	for a: TimelineAction in plan_post_move.entries:
		temp_p2.add(a)
	var new_actors: Array[int] = []
	for i: int in range(actions.size()):
		var a: TimelineAction = actions[i]
		new_actors.append(a.actor_id)
		if target_plans[i] == plan_post_move:
			temp_p2.add(a)
		elif target_plans[i] == plan_action:
			temp_act.add(a)
		else:
			temp_p1.add(a)
	var combined := Timeline.new()
	for a: TimelineAction in temp_p1.entries:
		combined.add(a)
	for a: TimelineAction in temp_act.entries:
		combined.add(a)
	for a: TimelineAction in temp_p2.entries:
		combined.add(a)
	var movement_only: bool = _plan_is_movement_only(combined)
	if not movement_only:
		var trial: BoardState = base_board.clone()
		var ev: Array[SimEvent] = []
		Simulator.simulate_player_turn(trial, combined, ev)
		for e: SimEvent in ev:
			if e.type == GameEnums.SimEventType.ACTION_FAILED:
				var failed_actor: int = int(e.data.get("actor", -1))
				if failed_actor in new_actors:
					EventBus.action_rejected.emit(String(e.data.get("reason", "failed")))
					return
	for i: int in range(actions.size()):
		target_plans[i].add(actions[i])
		if actions[i].type == GameEnums.ActionType.MOVE and not _autobattler_plan_batch:
			_commit_animate_actor_ids[actions[i].actor_id] = true
		if actions[i].type == GameEnums.ActionType.ABILITY and actions[i].ability != null:
			if actions[i].ability.is_movement_kind():
				_cancel_ally_plans_after_movement_step(actions[i])
			if AbilitySystem.ability_has_swap_effect(actions[i].ability):
				## Every swap commit animates both units; never pre-mark instant or sprites
				## snap on board_changed and skip the swap presentation tween.
				clear_planning_move_instant(actions[i].actor_id)
				if actions[i].target_unit_id >= 0:
					clear_planning_move_instant(actions[i].target_unit_id)
				_swap_planning_presentations.append(actions[i])
				if actions[i].target_unit_id >= 0 and actions[i].target_unit_id not in plan_affected_unit_ids:
					plan_affected_unit_ids.append(actions[i].target_unit_id)
	for actor_id: int in new_actors:
		if actor_id not in plan_affected_unit_ids:
			plan_affected_unit_ids.append(actor_id)
	_refresh_plan()

func get_player_plan() -> Timeline:
	return _get_combined_plan()


func mark_planning_move_instant(unit_id: int) -> void:
	if unit_id >= 0:
		_instant_planning_move_units[unit_id] = true


func take_planning_move_instant(unit_id: int) -> bool:
	return _instant_planning_move_units.erase(unit_id)


func is_planning_move_instant(unit_id: int) -> bool:
	return _instant_planning_move_units.has(unit_id)


func clear_planning_move_instant(unit_id: int) -> void:
	_instant_planning_move_units.erase(unit_id)


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


## Waypoints for a committed movement-skill leg (trample, dash tile walk, etc.).
func get_planned_skill_walk_waypoints(unit_id: int, to_cell: Vector2i) -> Array[Vector2i]:
	for action: TimelineAction in get_unit_plan_steps(unit_id):
		if action.type != GameEnums.ActionType.ABILITY or action.awaiting_target:
			continue
		if action.ability == null or not AbilitySystem.ability_has_movement_effect(action.ability):
			continue
		if action.target_coord != to_cell:
			continue
		if not action.waypoints.is_empty():
			return action.waypoints.duplicate()
	return []


func get_unit_plan_steps(unit_id: int) -> Array[TimelineAction]:
	return UnitPlanOrder.ordered_steps_for_unit(get_player_plan(), unit_id)


func _get_combined_plan() -> Timeline:
	var combined = Timeline.new()
	for a in plan_pre_move.entries:
		combined.add(a)
	for a in plan_action.entries:
		combined.add(a)
	var wait_ids: Array = _wait_unit_ids.keys()
	wait_ids.sort()
	for uid_var: Variant in wait_ids:
		combined.add(_make_wait_action(int(uid_var)))
	for a in plan_post_move.entries:
		combined.add(a)
	return combined

func _build_preview_plan(unit_id: int, new_actions: Array) -> Timeline:
	var strip_pre: bool = false
	var strip_act: bool = false
	var strip_post: bool = false
	for a: Variant in new_actions:
		if not a is TimelineAction:
			continue
		var action: TimelineAction = a as TimelineAction
		match action.type:
			GameEnums.ActionType.MOVE:
				if action.move_timing == GameEnums.MoveTiming.POST_ACTION:
					strip_post = true
				else:
					strip_pre = true
			_:
				strip_act = true
	var combined := Timeline.new()
	for a: TimelineAction in plan_pre_move.entries:
		if a.actor_id == unit_id and strip_pre and a.type == GameEnums.ActionType.MOVE:
			continue
		combined.add(a)
	for a: TimelineAction in plan_action.entries:
		if a.actor_id == unit_id and strip_act:
			continue
		combined.add(a)
	var wait_ids: Array = _wait_unit_ids.keys()
	wait_ids.sort()
	for uid_var: Variant in wait_ids:
		combined.add(_make_wait_action(int(uid_var)))
	for a: TimelineAction in plan_post_move.entries:
		if a.actor_id == unit_id and strip_post and a.type == GameEnums.ActionType.MOVE:
			continue
		combined.add(a)
	for a: Variant in new_actions:
		if a is TimelineAction:
			combined.add(a)
	## Intent truth: preview must already omit ally plans that commit would cancel.
	_preview_strip_ally_cancels_for_new_actions(combined, new_actions)
	return combined


func _preview_strip_ally_cancels_for_new_actions(combined: Timeline, new_actions: Array) -> void:
	if combined == null or board == null:
		return
	for raw: Variant in new_actions:
		if not raw is TimelineAction:
			continue
		var action: TimelineAction = raw as TimelineAction
		if (
			action.type != GameEnums.ActionType.ABILITY
			or action.ability == null
			or not action.ability.is_movement_kind()
		):
			continue
		var allies: Array[int] = PlanDependency.ally_ids_affected_by_action(board, action)
		PlanDependency.strip_ally_entries_after_step(combined, action, allies)


func _preview_from_plan(combined: Timeline) -> Dictionary:
	var ev: Array[SimEvent] = []
	var temp: BoardState = base_board.clone()
	Simulator.simulate_player_turn(temp, combined, ev)
	## Intent truth: if moves displace targets, strip dependent abilities and re-sim once
	## so ghosts match what commit's displacement cancel would leave.
	if _preview_apply_displacement_strips(combined, base_board, ev):
		ev.clear()
		temp = base_board.clone()
		Simulator.simulate_player_turn(temp, combined, ev)
	var intents: Array = EnemyPlanner.plan(temp)
	for intent: Variant in intents:
		if not intent is Intent:
			continue
		for action: TimelineAction in (intent as Intent).actions:
			ResolutionPipeline.apply_action(temp, action, ev)
	ResolutionPipeline.resolve_pending_pushes(temp, ev)
	return {"intents": intents, "events": ev, "temp_board": temp}


func _preview_apply_displacement_strips(
	combined: Timeline,
	pre_board: BoardState,
	events: Array[SimEvent],
) -> bool:
	if combined == null or pre_board == null:
		return false
	var displaced := _collect_displaced_enemies(pre_board, events)
	if displaced.is_empty():
		return false
	## Skip the displacing unit's own abilities (same as commit cancel).
	var mover_ids: Dictionary = {}
	for e: SimEvent in events:
		if e.type == GameEnums.SimEventType.TRAMPLE_HIT:
			var actor_id: int = int(e.data.get("actor", -1))
			if actor_id >= 0:
				mover_ids[actor_id] = true
		elif e.type == GameEnums.SimEventType.COLLISION:
			var collision_pusher: int = int(e.data.get("pusher_id", -1))
			if collision_pusher >= 0:
				mover_ids[collision_pusher] = true
		elif e.type == GameEnums.SimEventType.UNIT_PUSHED:
			var push_pusher: int = int(e.data.get("pusher", -1))
			if push_pusher >= 0:
				mover_ids[push_pusher] = true
	var mover_id: int = -1
	if not mover_ids.is_empty():
		mover_id = int(mover_ids.keys()[0])
	var old_positions: Array = displaced.values()
	return PlanDependency.strip_actions_targeting_displaced(
		combined, mover_id, displaced, old_positions,
	)


func preview_actions(unit_id: int, actions: Array[TimelineAction]) -> Dictionary:
	var empty: BoardState = base_board.clone() if base_board != null else BoardState.new()
	if unit_id < 0 or actions.is_empty():
		return {"intents": [], "events": [], "temp_board": empty, "actions": []}
	var res: Dictionary = _preview_from_plan(_build_preview_plan(unit_id, actions))
	## Carry commit-slot actions so preview can ratify movement intent geometry.
	res["actions"] = actions
	return res


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
						TimelineAction.make_run_move(unit_id, coord, -1, waypoints, GameEnums.MoveTiming.PRE_ACTION),
					)
				else:
					new_actions.append(
						TimelineAction.make_move(unit_id, coord, -1, waypoints, move_timing),
					)
			elif self_after_move:
				var move_actor: UnitState = plan_actor if plan_actor != null else actor
				new_actions.append(
					make_planning_move_action(
						unit_id, coord, plan_board, move_actor, waypoints, move_timing,
					),
				)
				if (
					not AbilitySystem.movement_requires_run(plan_board, move_actor, coord, waypoints)
					or AbilitySystem.can_afford_run_for_commit(move_actor, ability)
				):
					new_actions.append(
						TimelineAction.make_ability(
							unit_id, ability, coord, attack_target_id, GameEnums.MoveTiming.PRE_ACTION,
						),
					)
			elif GridSystem.manhattan(actor.position, target.position) > rng:
				var approach := _find_approach_tile(start_board, actor, target.position, rng, coord)
				var approach_path: Array[Vector2i] = []
				if approach != actor.position:
					approach_path = []
					new_actions.append(
						make_planning_move_action(
							unit_id, approach, start_board, actor, approach_path, move_timing,
						),
					)
				if (
					approach == actor.position
					or not AbilitySystem.movement_requires_run(start_board, actor, approach, approach_path)
					or AbilitySystem.can_afford_run_for_commit(actor, ability)
				):
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
						TimelineAction.make_run_move(unit_id, coord, -1, waypoints, GameEnums.MoveTiming.PRE_ACTION),
					)
				else:
					new_actions.append(
						TimelineAction.make_move(unit_id, coord, -1, waypoints, move_timing),
					)
			else:
				var move_actor: UnitState = plan_actor if plan_actor != null else actor
				new_actions.append(
					make_planning_move_action(
						unit_id, coord, plan_board, move_actor, waypoints, move_timing,
					),
				)
		else:
			var move_actor: UnitState = plan_actor if plan_actor != null else actor
			new_actions.append(
				make_planning_move_action(
					unit_id, coord, plan_board, move_actor, waypoints, move_timing,
				),
			)
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
		
	var plan_to_use = _plan_containing_action(action)
	
	# Compute local index
	var local_from = -1
	for i in range(plan_to_use.size()):
		if plan_to_use.entries[i] == action:
			local_from = i
			break
			
	var action_at_to = combined.entries[clampi(to_index, 0, combined.size() - 1)]
	if _plan_containing_action(action_at_to) != plan_to_use:
		return # Cannot reorder across timeline buckets
		
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
	var p_unit := projected_state.get_unit_by_id(unit_id) if projected_state != null else attacker
	if p_unit == null:
		p_unit = attacker
	var cast_pos: Vector2i = p_unit.position
	if AbilitySystem.is_run_ability(ability):
		if move_coord == cast_pos:
			return
		var plan_board: BoardState = projected_state if projected_state != null else board
		if AbilitySystem.movement_requires_run(plan_board, p_unit, move_coord, waypoints):
			rpc_plan_run_and_move(unit_id, move_coord, face_dir, waypoints, index)
		else:
			if _reject_if_move_slot_filled(unit_id, target_timing):
				return
			_clear_unit_from_plans(unit_id, target_timing)
			_try_add(
				TimelineAction.make_move(unit_id, move_coord, face_dir, waypoints, target_timing),
				plan_to_use,
			)
		return
	if move_coord == cast_pos:
		_clear_unit_wait(unit_id)
		_clear_unit_class_actions_from_plan(unit_id)
		_clear_unit_post_moves_from_plan(unit_id)
		_try_add(
			TimelineAction.make_ability(
				unit_id, ability, cast_pos, unit_id, GameEnums.MoveTiming.PRE_ACTION,
			),
			plan_action,
		)
		return
	if _reject_if_move_slot_filled(unit_id, target_timing):
		return
	_clear_unit_from_plans(unit_id, target_timing)
	var plan_board: BoardState = projected_state if projected_state != null else board
	var needs_run: bool = (
		auto_run
		and AbilitySystem.can_afford_run(p_unit)
		and AbilitySystem.movement_requires_run(plan_board, p_unit, move_coord, waypoints)
	)
	var move_action := TimelineAction.make_move(unit_id, move_coord, face_dir, waypoints, target_timing)
	if needs_run:
		move_action = TimelineAction.make_run_move(unit_id, move_coord, face_dir, waypoints, target_timing)
	if needs_run and not AbilitySystem.can_afford_run_for_commit(p_unit, ability):
		_clear_unit_wait(unit_id)
		_clear_unit_class_actions_from_plan(unit_id)
		_clear_unit_post_moves_from_plan(unit_id)
		_try_add(move_action, plan_to_use)
		return
	var ability_action := TimelineAction.make_ability(
		unit_id, ability, move_coord, unit_id, GameEnums.MoveTiming.PRE_ACTION,
	)
	_clear_unit_wait(unit_id)
	_clear_unit_class_actions_from_plan(unit_id)
	_clear_unit_post_moves_from_plan(unit_id)
	_try_add_multiple([move_action, ability_action], [plan_to_use, plan_action])


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
	_clear_unit_post_moves_from_plan(unit_id)
	var move_action := TimelineAction.make_run_move(
		unit_id, move_coord, face_dir, waypoints, GameEnums.MoveTiming.PRE_ACTION,
	)
	_try_add(move_action, plan_pre_move)


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
	if ability.is_movement_kind() and target_timing != GameEnums.MoveTiming.PRE_ACTION:
		EventBus.action_rejected.emit("movement_skill_after_action")
		return

	var proj := _get_planning_state(target_timing)
	var projected_actor := proj.get_unit_by_id(unit_id)
	var projected_target := proj.get_unit_by_id(target_unit_id)
	var coord: Vector2i
	if projected_actor != null and target_unit_id == unit_id:
		coord = projected_actor.position
	elif projected_target != null:
		coord = projected_target.position
	else:
		coord = target.position
	var action := TimelineAction.make_ability(unit_id, ability, coord, target_unit_id, GameEnums.MoveTiming.PRE_ACTION)
	if ability.is_movement_kind():
		_try_add(action, plan_pre_move)
	else:
		_clear_unit_wait(unit_id)
		_clear_unit_class_actions_from_plan(unit_id)
		_clear_unit_post_moves_from_plan(unit_id)
		_try_add(action, plan_action)

@rpc("any_peer", "call_local", "reliable")
func rpc_plan_ability_at_coord(unit_id: int, ability_index: int, coord: Vector2i, waypoints: Array[Vector2i] = []) -> void:
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
	if ability.is_movement_kind():
		_try_add(
			TimelineAction.make_ability(unit_id, ability, coord, -1, GameEnums.MoveTiming.PRE_ACTION, waypoints),
			plan_pre_move,
		)
	else:
		_clear_unit_wait(unit_id)
		_clear_unit_class_actions_from_plan(unit_id)
		_clear_unit_post_moves_from_plan(unit_id)
		_try_add(
			TimelineAction.make_ability(unit_id, ability, coord, -1, GameEnums.MoveTiming.PRE_ACTION, waypoints),
			plan_action,
		)

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
					var removed: TimelineAction = plan_post_move.entries[i]
					plan_post_move.remove_at(i)
					_begin_undo_plan_refresh(unit_id)
					_refresh_plan()
					_reselect_ability_from_action(removed)
					return
		if plan_action.size() > 0:
			for i in range(plan_action.size() - 1, -1, -1):
				if plan_action.entries[i].actor_id == unit_id:
					if plan_action.entries[i].irreversible:
						EventBus.action_rejected.emit("cannot_undo_trample")
						return
					var removed: TimelineAction = plan_action.entries[i]
					if (
						removed.type == GameEnums.ActionType.ABILITY
						and removed.ability != null
						and removed.ability.is_movement_kind()
					):
						_cancel_ally_plans_after_movement_step(removed)
					plan_action.remove_at(i)
					_begin_undo_plan_refresh(unit_id)
					_refresh_plan()
					_reselect_ability_from_action(removed)
					return
		if plan_pre_move.size() > 0:
			for i in range(plan_pre_move.size() - 1, -1, -1):
				if plan_pre_move.entries[i].actor_id == unit_id:
					if plan_pre_move.entries[i].irreversible:
						EventBus.action_rejected.emit("cannot_undo_trample")
						return
					var removed: TimelineAction = plan_pre_move.entries[i]
					_cancel_ally_plans_after_movement_step(removed)
					plan_pre_move.remove_at(i)
					_begin_undo_plan_refresh(unit_id)
					_refresh_plan()
					_reselect_ability_from_action(removed)
					return

func _reselect_ability_from_action(action: TimelineAction) -> void:
	if action == null or action.actor_id != selected_unit_id:
		return
	if action.ability == null or action.ability.id.is_empty():
		return
	var u := base_board.get_unit_by_id(selected_unit_id)
	if u == null:
		return
	for i in u.active_abilities.size():
		if u.active_abilities[i].id == action.ability.id:
			select_ability(i)
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
		var removed_pre: TimelineAction = plan_pre_move.entries[index]
		if removed_pre.irreversible:
			EventBus.action_rejected.emit("cannot_undo_trample")
			return
		_cancel_ally_plans_after_movement_step(removed_pre)
		plan_pre_move.remove_at(index)
	elif index < plan_pre_move.size() + plan_action.size():
		var act_idx: int = index - plan_pre_move.size()
		var removed_act: TimelineAction = plan_action.entries[act_idx]
		if removed_act.irreversible:
			EventBus.action_rejected.emit("cannot_undo_trample")
			return
		if (
			removed_act.type == GameEnums.ActionType.ABILITY
			and removed_act.ability != null
			and removed_act.ability.is_movement_kind()
		):
			_cancel_ally_plans_after_movement_step(removed_act)
		plan_action.remove_at(act_idx)
	elif index - plan_pre_move.size() - plan_action.size() < plan_post_move.size():
		var post_idx: int = index - plan_pre_move.size() - plan_action.size()
		if plan_post_move.entries[post_idx].irreversible:
			EventBus.action_rejected.emit("cannot_undo_trample")
			return
		plan_post_move.remove_at(post_idx)
	_begin_undo_plan_refresh(action.actor_id)
	_refresh_plan()
	_reselect_ability_from_action(action)

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

	for plan in [plan_pre_move, plan_action, plan_post_move]:
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
		var kept_act: Array[TimelineAction] = []
		for a in plan_action.entries:
			if a.actor_id != unit_id:
				kept_act.append(a)
		plan_action.entries = kept_act
		var kept_2: Array[TimelineAction] = []
		for a in plan_post_move.entries:
			if a.actor_id != unit_id:
				kept_2.append(a)
		plan_post_move.entries = kept_2
		_clear_unit_wait(unit_id)
		_begin_undo_plan_refresh(unit_id)
		_refresh_plan()

func clear_plan() -> void:
	if is_planning_phase(phase):
		plan_pre_move.clear()
		plan_action.clear()
		plan_post_move.clear()
		_wait_unit_ids.clear()
	_refresh_plan()

func restart_turn() -> void:
	if turn_start_board == null:
		return
	_run_id += 1
	base_board = turn_start_board.clone()
	board = base_board.clone()
	plan_pre_move.clear()
	plan_action.clear()
	plan_post_move.clear()
	_wait_unit_ids.clear()
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
	_skip_committed_premove_visuals = not plan_pre_move.entries.is_empty()
	_execute_premove_skip_actions.clear()
	for action: TimelineAction in plan_pre_move.entries:
		_execute_premove_skip_actions.append(action)
	var result: SimResult = Simulator.simulate(base_board, combined)
	_set_phase(Phase.EXECUTING)
	await _play_events(result.events)
	_skip_committed_premove_visuals = false
	_execute_premove_skip_actions.clear()
	if current_run_id != _run_id:
		return
	base_board = result.final_state
	plan_pre_move.clear()
	plan_action.clear()
	plan_post_move.clear()
	_wait_unit_ids.clear()
	if _check_end_state():
		return
	selected_unit_id = -1
	selected_ability_index = 0
	_emit_planning_selection()
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

## Plays a list of events in ordered phases: pre-moves (simultaneous) → attacks
## (sequential) → post-moves (simultaneous) → forced movement (simultaneous).
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
		if events[i].type == GameEnums.SimEventType.ABILITY_USED and events[i].data.get("presentation_anim", GameEnums.PresentationAnim.WALK) == GameEnums.PresentationAnim.SUPER_RUN:
			i += 1
			while i < events.size():
				var t := events[i].type
				if t == GameEnums.SimEventType.UNIT_MOVED and events[i].data.get("presentation_anim", GameEnums.PresentationAnim.WALK) == GameEnums.PresentationAnim.SUPER_RUN:
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
					GameEnums.SimEventType.TRAMPLE_HIT,
				]:
					i += 1
				else:
					break
			blocks.append({"start": start, "end": i})
			continue
		i += 1
	return blocks


func _is_displacement_playback_event(event: SimEvent) -> bool:
	return event.type in [
		GameEnums.SimEventType.UNIT_PUSHED,
		GameEnums.SimEventType.COLLISION,
	]


func _step_playback_sort_key(event: SimEvent) -> int:
	if _is_displacement_playback_event(event):
		return 3
	match event.type:
		GameEnums.SimEventType.TRAMPLE_HIT:
			return 0
		GameEnums.SimEventType.UNIT_DAMAGED, \
		GameEnums.SimEventType.MATH_TELEMETRY, \
		GameEnums.SimEventType.UNIT_ARMORED, \
		GameEnums.SimEventType.UNIT_HEALED:
			return 1
		GameEnums.SimEventType.STATUS_APPLIED, \
		GameEnums.SimEventType.STATUS_REMOVED, \
		GameEnums.SimEventType.UNIT_DIED, \
		GameEnums.SimEventType.UNIT_EXPLODED:
			return 2
		_:
			return 1


func _playback_step_index(event: SimEvent) -> int:
	if event.data.has("dash_hit_step"):
		return int(event.data.get("dash_hit_step", -1))
	if event.data.has("trample_step"):
		return int(event.data.get("trample_step", -1))
	return -1


func _append_step_playback_event(step_events: Dictionary, event: SimEvent) -> void:
	var step: int = _playback_step_index(event)
	if step < 0:
		return
	if not step_events.has(step):
		step_events[step] = []
	(step_events[step] as Array).append(event)


func _sorted_step_playback_events(step_events: Array) -> Array:
	var ordered: Array = step_events.duplicate()
	ordered.sort_custom(func(a: SimEvent, b: SimEvent) -> bool:
		return _step_playback_sort_key(a) < _step_playback_sort_key(b)
	)
	return ordered


func _emit_step_playback_events(step_events: Array, run_id: int) -> void:
	if step_events.is_empty() or run_id != _run_id:
		return
	var had_displacement := false
	for event: SimEvent in _sorted_step_playback_events(step_events):
		if run_id != _run_id:
			return
		EventBus.sim_event.emit(event)
		if _is_displacement_playback_event(event):
			had_displacement = true
	if had_displacement:
		await _await_push_animations(run_id)


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
		GameEnums.SimEventType.TRAMPLE_HIT,
	]
	
	for event: SimEvent in block:
		match event.type:
			GameEnums.SimEventType.UNIT_FACED:
				pre_ability_events.append(event)
			GameEnums.SimEventType.ABILITY_USED:
				ability_event = event
			GameEnums.SimEventType.UNIT_MOVED:
				if event.data.get("presentation_anim", GameEnums.PresentationAnim.WALK) == GameEnums.PresentationAnim.SUPER_RUN:
					move_event = event
				else:
					pre_ability_events.append(event)
			GameEnums.SimEventType.UNIT_PUSHED:
				var push_step: int = _playback_step_index(event)
				if push_step >= 0:
					_append_step_playback_event(step_events, event)
				else:
					push_events.append(event)
			_:
				if event.type in step_event_types:
					var step: int = _playback_step_index(event)
					if step >= 0:
						_append_step_playback_event(step_events, event)
					else:
						post_dash_events.append(event)
				else:
					pre_ability_events.append(event)
	
	for e in pre_ability_events:
		if run_id != _run_id:
			return
		EventBus.sim_event.emit(e)
	
	if ability_event != null:
		EventBus.sim_event.emit(ability_event)
		var delay: float = _playback_delay_for_event(ability_event)
		await get_tree().create_timer(delay).timeout
		if run_id != _run_id:
			return
	
	if move_event == null:
		var tail_no_move: Array = []
		tail_no_move.append_array(post_dash_events)
		tail_no_move.append_array(push_events)
		await _emit_step_playback_events(tail_no_move, run_id)
		return
	
	var path: Array = move_event.data.get("path", [])
	move_event.data["presentation_anim"] = GameEnums.PresentationAnim.SUPER_RUN
	move_event.data["dash_step_time"] = DASH_STEP_TIME
	EventBus.sim_event.emit(move_event)
	
	for step_i in range(path.size()):
		await get_tree().create_timer(DASH_STEP_TIME).timeout
		if run_id != _run_id:
			return
		if step_events.has(step_i):
			await _emit_step_playback_events(step_events[step_i] as Array, run_id)
	
	await get_tree().create_timer(0.05).timeout
	if run_id != _run_id:
		return
	
	var tail_events: Array = []
	tail_events.append_array(post_dash_events)
	tail_events.append_array(push_events)
	await _emit_step_playback_events(tail_events, run_id)


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
	if _skip_committed_premove_visuals:
		events = _filter_committed_premove_visual_events(events)
		if events.is_empty():
			return
	
	var pre_move_events: Array[SimEvent] = []
	var post_move_events: Array[SimEvent] = []
	var attack_events: Array[SimEvent] = []
	var push_events:   Array[SimEvent] = []
	var post_push_events: Array[SimEvent] = []
	var meta_events:   Array[SimEvent] = []
	
	for event in events:
		# Trample side-effect events (damage, push, collision) tagged with a step index
		# must travel with the UNIT_MOVED so _play_move_batch fires them mid-walk.
		if event.data.has("trample_step"):
			pre_move_events.append(event)
			continue
		match event.type:
			GameEnums.SimEventType.UNIT_MOVED:
				var timing: int = int(
					event.data.get("move_timing", GameEnums.MoveTiming.PRE_ACTION)
				)
				if timing == GameEnums.MoveTiming.POST_ACTION:
					post_move_events.append(event)
				else:
					pre_move_events.append(event)
			GameEnums.SimEventType.ABILITY_USED:
				# A movement-skill ABILITY_USED (WALK/RUN anim) should play before the
				# walk tween, not after it. ATTACK/SUPER_RUN/SPELLCAST go to attack_events.
				var pres_int: int = int(event.data.get("presentation_anim", GameEnums.PresentationAnim.WALK))
				var pres: GameEnums.PresentationAnim = pres_int as GameEnums.PresentationAnim
				if pres in [GameEnums.PresentationAnim.WALK, GameEnums.PresentationAnim.RUN]:
					pre_move_events.append(event)
				else:
					attack_events.append(event)
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
				if event.data.get("is_collision_side_effect", false):
					post_push_events.append(event)
				else:
					attack_events.append(event)
			GameEnums.SimEventType.UNIT_PUSHED, \
			GameEnums.SimEventType.COLLISION:
				push_events.append(event)
			_: # TURN_ENDED, ACTION_FAILED, UNIT_SPAWNED, etc.
				meta_events.append(event)
	
	if not pre_move_events.is_empty():
		await _play_move_batch(pre_move_events, run_id)
		if run_id != _run_id:
			return
	
	# --- Attack batch: sequential, one action at a time ---
	var attack_i: int = 0
	while attack_i < attack_events.size():
		if run_id != _run_id:
			return
		var e: SimEvent = attack_events[attack_i]
		EventBus.sim_event.emit(e)
		if e.type == GameEnums.SimEventType.ABILITY_USED and _event_uses_spellcast_animation(e):
			await get_tree().create_timer(LpcConstants.spellcast_release_delay_sec()).timeout
			if run_id != _run_id:
				return
			attack_i += 1
			while attack_i < attack_events.size() and _is_spellcast_impact_event(attack_events[attack_i]):
				EventBus.sim_event.emit(attack_events[attack_i])
				attack_i += 1
			await get_tree().create_timer(LpcConstants.spellcast_flash_hold_sec()).timeout
			continue
		var delay: float = _playback_delay_for_event(e)
		await get_tree().create_timer(delay).timeout
		attack_i += 1
	if run_id != _run_id: return
	
	if not post_move_events.is_empty():
		await _play_move_batch(post_move_events, run_id)
		if run_id != _run_id:
			return
	
	# --- Forced movement — all pushes/collisions at the same time ---
	if not push_events.is_empty():
		for e in push_events:
			if run_id != _run_id: return
			EventBus.sim_event.emit(e)
		await _await_push_animations(run_id)
	
	# --- Collision side effects (damage, death, statuses) ---
	var post_push_i: int = 0
	while post_push_i < post_push_events.size():
		if run_id != _run_id:
			return
		var e: SimEvent = post_push_events[post_push_i]
		EventBus.sim_event.emit(e)
		var delay: float = _playback_delay_for_event(e)
		await get_tree().create_timer(delay).timeout
		post_push_i += 1
	if run_id != _run_id: return
	
	# --- Meta events (TURN_ENDED, ACTION_FAILED, etc.) ---
	for e in meta_events:
		if run_id != _run_id: return
		EventBus.sim_event.emit(e)


func _playback_delay_for_event(event: SimEvent) -> float:
	if event.type == GameEnums.SimEventType.COUNTER_ATTACK:
		return ATTACK_ANIM_TIME
	if event.type != GameEnums.SimEventType.ABILITY_USED:
		return 0.15
	if _event_uses_spellcast_animation(event):
		return LpcConstants.spellcast_playback_delay_sec()
	var actor_id: int = int(event.data.get("actor", -1))
	var ability_id: StringName = event.data.get("ability", &"")
	if board == null or actor_id < 0 or ability_id == &"":
		return ATTACK_ANIM_TIME
	var actor := board.get_unit_by_id(actor_id)
	if actor == null:
		return ATTACK_ANIM_TIME
	return ATTACK_ANIM_TIME


func _event_uses_spellcast_animation(event: SimEvent) -> bool:
	if event.type != GameEnums.SimEventType.ABILITY_USED:
		return false
	var actor_id: int = int(event.data.get("actor", -1))
	var ability_id: StringName = event.data.get("ability", &"")
	if board == null or actor_id < 0 or ability_id == &"":
		return false
	var actor := board.get_unit_by_id(actor_id)
	if actor == null:
		return false
	for ability: AbilityData in actor.active_abilities:
		if ability.id == ability_id:
			return AbilitySystem.ability_uses_spellcast_animation(ability)
	return false


func _is_spellcast_impact_event(event: SimEvent) -> bool:
	return event.type in [
		GameEnums.SimEventType.MATH_TELEMETRY,
		GameEnums.SimEventType.UNIT_DAMAGED,
		GameEnums.SimEventType.UNIT_ARMORED,
		GameEnums.SimEventType.UNIT_HEALED,
		GameEnums.SimEventType.UNIT_DIED,
		GameEnums.SimEventType.STATUS_APPLIED,
		GameEnums.SimEventType.STATUS_REMOVED,
		GameEnums.SimEventType.UNIT_EXPLODED,
	]


func _play_move_batch(move_events: Array[SimEvent], run_id: int) -> void:
	if move_events.is_empty() or run_id != _run_id:
		return

	# Collect any trample-step-tagged side-effect events that need per-step interleaving.
	# Key = step_index (int), value = Array of SimEvent to fire after that step's timer.
	var trample_step_events: Dictionary = {}
	var clean_move_events: Array[SimEvent] = []
	for e: SimEvent in move_events:
		if e.data.has("trample_step"):
			var step_i: int = int(e.data["trample_step"])
			if not trample_step_events.has(step_i):
				trample_step_events[step_i] = []
			(trample_step_events[step_i] as Array).append(e)
		else:
			clean_move_events.append(e)

	# Fire the UNIT_MOVED (and any other non-trample-tagged) events immediately so
	# the walk tween starts. Then wait per-step, firing trample events at contact time.
	var max_path_len := 0
	for e: SimEvent in clean_move_events:
		if run_id != _run_id:
			return
		EventBus.sim_event.emit(e)
		max_path_len = max(max_path_len, (e.data.get("path", []) as Array).size())

	if trample_step_events.is_empty():
		# No trample hits — just wait for the whole walk to finish.
		await get_tree().create_timer(max(1, max_path_len) * MOVE_STEP_TIME + 0.05).timeout
		return

	# Step through the path, firing trample events when the sprite reaches each tile.
	for step_i in range(max(1, max_path_len)):
		await get_tree().create_timer(MOVE_STEP_TIME).timeout
		if run_id != _run_id:
			return
		if trample_step_events.has(step_i):
			await _emit_step_playback_events(trample_step_events[step_i] as Array, run_id)
	# Small tail buffer so the last hit animation settles before we move on.
	await get_tree().create_timer(0.05).timeout


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
	for plan in [plan_pre_move, plan_action, plan_post_move]:
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
	for i in range(plan_action.size() - 1, -1, -1):
		if plan_action.entries[i].actor_id == unit_id:
			return not plan_action.entries[i].irreversible
	for i in range(plan_pre_move.size() - 1, -1, -1):
		if plan_pre_move.entries[i].actor_id == unit_id:
			return not plan_pre_move.entries[i].irreversible
	return false


func _begin_undo_plan_refresh(unit_id: int) -> void:
	plan_affected_unit_ids = [unit_id]
	plan_refresh_snap_units = true
	# Undo must refresh red action-range tiles immediately — do not defer overlay.
	plan_refresh_defer_overlay = false
	plan_refresh_light_overlay = true
	_pending_planning_commit_events.clear()
	clear_planning_move_instant(unit_id)


func _refresh_plan() -> void:
	_refresh_plan_core()


func _queue_refresh_plan() -> void:
	if _refresh_plan_queued:
		return
	_refresh_plan_queued = true
	call_deferred("_flush_queued_refresh_plan")


func _flush_queued_refresh_plan() -> void:
	_refresh_plan_queued = false
	_refresh_plan_core()


func _refresh_plan_core() -> void:
	var plan_to_run := _get_combined_plan()
	if _plan_is_wait_marker_only(plan_to_run):
		_refresh_plan_wait_marker_only(plan_to_run)
		return
	_cached_wait_marker_ghost_events.clear()
	if plan_refresh_snap_units and _plan_is_movement_only(plan_to_run):
		_refresh_plan_snap_movement_only(plan_to_run)
		return
	var move_only := base_board.clone()
	var full_proj := base_board.clone()
	var statuses := PackedStringArray()
	var anim_events: Array[SimEvent] = []
	var any_cancelled := false
	
	for action in plan_to_run.entries:
		if action.awaiting_target:
			statuses.append("")
			continue
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
			if (
				action.type == GameEnums.ActionType.MOVE
				and _commit_animate_actor_ids.has(action.actor_id)
			):
				for move_event: SimEvent in _extract_commit_anim_events(move_ev):
					move_event.data["planning_commit_move"] = true
					anim_events.append(move_event)
			
		var reason := ""
		for e in events:
			if e.type == GameEnums.SimEventType.ACTION_FAILED:
				reason = String(e.data.get("reason", "failed"))
				break
		statuses.append(reason)

	if any_cancelled:
		_refresh_plan()
		return

	_commit_animate_actor_ids.clear()
		
	var dummy_ev: Array[SimEvent] = []
	ResolutionPipeline.resolve_pending_pushes(full_proj, dummy_ev)

	projected_state = base_board.clone()
	var evs: Array[SimEvent] = []
	Simulator.simulate_player_turn(projected_state, plan_to_run, evs)

	# Premoves (walk + movement skills like Swap) apply immediately on live board.
	# Action-phase displacement (bash push, hook pull, etc.) stays preview-only until execute.
	board = projected_state.clone()
	_sync_live_enemy_positions_to_turn_start(board)
	var new_intents := EnemyPlanner.plan(projected_state)
	base_board.intents = new_intents
	board.intents = new_intents
	projected_state.intents = new_intents

	if not anim_events.is_empty():
		for event: SimEvent in anim_events:
			_pending_planning_commit_events.append(event)
	if not _swap_planning_presentations.is_empty():
		for swap_action: TimelineAction in _swap_planning_presentations:
			_pending_planning_commit_events.append(
				_make_planning_swap_ability_event(swap_action, plan_to_run)
			)
		_swap_planning_presentations.clear()
	if not _pending_planning_commit_events.is_empty():
		plan_refresh_defer_overlay = true
	plan_revision += 1
	sync_selected_ability_if_invalid()

	var preview_board: BoardState = projected_state.clone()
	var ghost_evs: Array[SimEvent] = _build_enemy_ghost_events(preview_board, new_intents)

	var sim_res := SimResult.new(preview_board)
	sim_res.events = _preview_events_for_overlay(evs, ghost_evs)
	_defer_plan_refresh_signals(board, plan_to_run, statuses, sim_res)


func _refresh_plan_snap_movement_only(plan: Timeline) -> void:
	var move_only := base_board.clone()
	var evs: Array[SimEvent] = []
	for action: TimelineAction in plan.entries:
		if action.awaiting_target or action.type != GameEnums.ActionType.MOVE:
			continue
		var move_ev: Array[SimEvent] = []
		ResolutionPipeline.apply_action(move_only, action, move_ev)
		ResolutionPipeline.resolve_pending_pushes(move_only, move_ev)
		evs.append_array(move_ev)
	_commit_animate_actor_ids.clear()
	_pending_planning_commit_events.clear()

	if _player_positions_match_turn_start(move_only):
		_refresh_plan_snap_turn_start(plan, evs)
		return

	projected_state = move_only.clone()
	board = move_only

	var new_intents := EnemyPlanner.plan(projected_state)
	base_board.intents = new_intents
	board.intents = new_intents
	projected_state.intents = new_intents

	plan_revision += 1
	sync_selected_ability_if_invalid()

	var preview_board: BoardState = projected_state.clone()
	var ghost_evs := _build_enemy_ghost_events(preview_board, new_intents)
	var sim_res := SimResult.new(preview_board)
	sim_res.events = _preview_events_for_overlay(evs, ghost_evs)
	var statuses := PackedStringArray()
	statuses.resize(maxi(plan.size(), 1))
	_defer_plan_refresh_signals(board, plan, statuses, sim_res)


func _refresh_plan_snap_turn_start(plan: Timeline, player_events: Array[SimEvent]) -> void:
	projected_state = base_board.clone()
	board = base_board.clone()
	var intents: Array = _clone_intents(_turn_start_intents)
	if intents.is_empty():
		intents = EnemyPlanner.plan(projected_state)
	base_board.intents = intents
	board.intents = intents
	projected_state.intents = intents

	plan_revision += 1
	sync_selected_ability_if_invalid()

	var preview_board: BoardState = projected_state.clone()
	var ghost_evs: Array[SimEvent] = _turn_start_enemy_ghost_events.duplicate()
	if ghost_evs.is_empty():
		ghost_evs = _build_enemy_ghost_events(preview_board, intents)
	var sim_res := SimResult.new(preview_board)
	sim_res.events = _preview_events_for_overlay(player_events, ghost_evs)
	var statuses := PackedStringArray()
	statuses.resize(maxi(plan.size(), 1))
	plan_refresh_light_overlay = true
	_defer_plan_refresh_signals(board, plan, statuses, sim_res)


func _refresh_plan_wait_marker_only(plan: Timeline) -> void:
	_commit_animate_actor_ids.clear()
	projected_state = base_board.clone()
	for action: TimelineAction in plan.entries:
		if action.awaiting_target:
			continue
		if action.type != GameEnums.ActionType.ABILITY:
			continue
		if action.ability == null or not action.ability.is_universal_wait():
			continue
		var unit: UnitState = projected_state.get_unit_by_id(action.actor_id)
		if unit != null:
			unit.turn_action_used = true
	board = projected_state
	var intents: Array = base_board.intents
	if intents.is_empty():
		intents = EnemyPlanner.plan(projected_state)
		base_board.intents = intents
	board.intents = base_board.intents
	projected_state.intents = base_board.intents
	plan_revision += 1
	sync_selected_ability_if_invalid()
	var ghost_evs: Array[SimEvent]
	if not _cached_wait_marker_ghost_events.is_empty():
		ghost_evs = _cached_wait_marker_ghost_events
	else:
		var preview_board: BoardState = projected_state.clone()
		ghost_evs = _build_ghost_events(preview_board, plan, intents)
		_cached_wait_marker_ghost_events = ghost_evs.duplicate()
	var sim_res := SimResult.new(projected_state.clone())
	sim_res.events = _preview_events_for_overlay([], ghost_evs)
	var statuses := PackedStringArray()
	statuses.resize(maxi(plan.size(), 1))
	_defer_plan_refresh_signals(board, plan, statuses, sim_res)


func _plan_is_movement_only(plan: Timeline) -> bool:
	if plan == null:
		return true
	for action: TimelineAction in plan.entries:
		if action.type == GameEnums.ActionType.ABILITY:
			if action.awaiting_target:
				continue
			return false
	return true


func _plan_is_wait_marker_only(plan: Timeline) -> bool:
	if plan == null:
		return true
	for action: TimelineAction in plan.entries:
		if action.awaiting_target:
			continue
		if action.type == GameEnums.ActionType.MOVE:
			return false
		if action.type == GameEnums.ActionType.FACE:
			return false
		if action.type == GameEnums.ActionType.ABILITY:
			if action.ability == null or not action.ability.is_universal_wait():
				return false
			continue
		return false
	return true


func _defer_plan_refresh_signals(
	board_state: BoardState,
	plan: Timeline,
	statuses: PackedStringArray,
	preview: SimResult,
) -> void:
	_pending_refresh_board = board_state
	_pending_refresh_plan = plan
	_pending_refresh_statuses = statuses
	_pending_refresh_preview = preview
	if not plan_refresh_defer_overlay:
		# Undo snap: emit board + preview this frame so red range tiles update immediately.
		_plan_refresh_emit_pending = false
		_flush_plan_refresh_signals()
		return
	if _plan_refresh_emit_pending:
		return
	_plan_refresh_emit_pending = true
	call_deferred("_flush_plan_refresh_signals")


func flush_plan_refresh_signals_if_pending() -> void:
	if _plan_refresh_emit_pending:
		_flush_plan_refresh_signals()


func begin_autobattler_plan_batch() -> void:
	_autobattler_plan_batch = true
	_commit_animate_actor_ids.clear()


func finish_autobattler_plan_batch(unit_layer: TacticalUnitLayer) -> void:
	_autobattler_plan_batch = false
	_commit_animate_actor_ids.clear()
	flush_plan_refresh_signals_if_pending()
	var anim_events: Array[SimEvent] = _collect_all_planning_move_anim_events()
	if not anim_events.is_empty() and unit_layer != null:
		unit_layer.reset_planning_walk_origins_for_moves(anim_events)
		EventBus.planning_commit_events.emit(anim_events)
	if unit_layer != null:
		await unit_layer.await_planning_move_tweens()


func _collect_all_planning_move_anim_events() -> Array[SimEvent]:
	var plan_to_run := _get_combined_plan()
	if plan_to_run.size() == 0 or base_board == null:
		return []
	var move_only := base_board.clone()
	var anim_events: Array[SimEvent] = []
	for action: TimelineAction in plan_to_run.entries:
		if action.awaiting_target or action.type != GameEnums.ActionType.MOVE:
			continue
		var actor := base_board.get_unit_by_id(action.actor_id)
		if actor == null or actor.is_enemy():
			continue
		var move_ev: Array[SimEvent] = []
		ResolutionPipeline.apply_action(move_only, action, move_ev)
		ResolutionPipeline.resolve_pending_pushes(move_only, move_ev)
		for move_event: SimEvent in _extract_commit_anim_events(move_ev):
			move_event.data["planning_commit_move"] = true
			anim_events.append(move_event)
	return anim_events


func _flush_plan_refresh_signals() -> void:
	_plan_refresh_emit_pending = false
	if _pending_refresh_board == null:
		return
	## Animations + walk-origin reset must run before board_changed so sprites are not
	## pulled to post-swap logical cells before the commit presentation queue starts.
	var commit_events: Array[SimEvent] = _pending_planning_commit_events.duplicate()
	_pending_planning_commit_events.clear()
	if not commit_events.is_empty():
		EventBus.planning_commit_events.emit(commit_events)
	EventBus.board_changed.emit(_pending_refresh_board)
	EventBus.timeline_changed.emit(_pending_refresh_plan, _pending_refresh_statuses)
	EventBus.preview_updated.emit(_pending_refresh_preview)
	plan_affected_unit_ids.clear()
	plan_refresh_snap_units = false
	plan_refresh_defer_overlay = false
	_pending_refresh_board = null
	_pending_refresh_plan = null
	_pending_refresh_preview = null

func _build_ghost_events(sim: BoardState, timeline: Timeline, intents: Array[Intent]) -> Array[SimEvent]:
	var evs: Array[SimEvent] = []
	for action in timeline.entries:
		ResolutionPipeline.apply_action(sim, action, evs)
	ResolutionPipeline.resolve_pending_pushes(sim, evs)
	evs.append_array(_build_enemy_ghost_events(sim, intents))
	return evs


## Enemy ghost tail only — player phase already applied on `sim` (e.g. projected_state).
func _build_enemy_ghost_events(sim: BoardState, intents: Array[Intent]) -> Array[SimEvent]:
	var evs: Array[SimEvent] = []
	evs.append(SimEvent.make(GameEnums.SimEventType.ENEMY_PHASE_BEGAN, {}))
	for intent in intents:
		for action in intent.actions:
			ResolutionPipeline.apply_action(sim, action, evs)
		ResolutionPipeline.resolve_pending_pushes(sim, evs)
	return evs


## Player-turn sim events (incl. UNIT_PUSHED) + enemy ghost tail for overlay path building.
func _preview_events_for_overlay(
	player_turn_events: Array[SimEvent],
	ghost_events: Array[SimEvent],
) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event: SimEvent in player_turn_events:
		out.append(event)
	var include_enemy: bool = false
	for event: SimEvent in ghost_events:
		if event.type == GameEnums.SimEventType.ENEMY_PHASE_BEGAN:
			include_enemy = true
		if include_enemy:
			out.append(event)
	return out

func _capture_turn_start() -> void:
	turn_start_board = base_board.clone()
	_cache_turn_start_enemy_preview()


func _cache_turn_start_enemy_preview() -> void:
	_turn_start_intents = _clone_intents(base_board.intents)
	var preview_board: BoardState = base_board.clone()
	var intents: Array = _turn_start_intents
	if intents.is_empty():
		intents = EnemyPlanner.plan(preview_board)
		_turn_start_intents = _clone_intents(intents)
	_turn_start_enemy_ghost_events = _build_enemy_ghost_events(preview_board, intents)


func _clone_intents(source: Array) -> Array:
	var out: Array = []
	for intent: Variant in source:
		if intent is Intent:
			out.append((intent as Intent).clone())
	return out


func _player_positions_match_turn_start(candidate: BoardState) -> bool:
	if turn_start_board == null or candidate == null:
		return false
	for unit: UnitState in turn_start_board.units:
		if not unit.is_alive() or unit.is_enemy():
			continue
		var other: UnitState = candidate.get_unit_by_id(unit.id)
		if other == null or other.position != unit.position:
			return false
	return true


## Planning live board: player premoves snap; enemies stay on turn-start tiles until execute.
func _sync_live_enemy_positions_to_turn_start(live: BoardState) -> void:
	if turn_start_board == null or live == null:
		return
	for start_unit: UnitState in turn_start_board.units:
		if not start_unit.is_alive() or not start_unit.is_enemy():
			continue
		var live_unit: UnitState = live.get_unit_by_id(start_unit.id)
		if live_unit == null or not live_unit.is_alive():
			continue
		var from_pos: Vector2i = live_unit.position
		var to_pos: Vector2i = start_unit.position
		if from_pos == to_pos:
			continue
		GridSystem.set_occupant(live, from_pos, -1)
		live_unit.position = to_pos
		GridSystem.set_occupant(live, to_pos, live_unit.id)


func _make_planning_swap_ability_event(action: TimelineAction, plan: Timeline) -> SimEvent:
	var pres_anim: int = action.ability.presentation_anim
	if pres_anim == GameEnums.PresentationAnim.AUTO:
		pres_anim = GameEnums.PresentationAnim.WALK
	var before: BoardState = _board_before_planning_action(action, plan)
	var after: BoardState = before.clone()
	var swap_events: Array[SimEvent] = []
	ResolutionPipeline.apply_action(after, action, swap_events)
	ResolutionPipeline.resolve_pending_pushes(after, swap_events)
	var actor_before: UnitState = before.get_unit_by_id(action.actor_id)
	var target_before: UnitState = before.get_unit_by_id(action.target_unit_id)
	var actor_after: UnitState = after.get_unit_by_id(action.actor_id)
	var target_after: UnitState = after.get_unit_by_id(action.target_unit_id)
	return SimEvent.make(GameEnums.SimEventType.ABILITY_USED, {
		"actor": action.actor_id,
		"ability": action.ability.id,
		"ability_name": action.ability.display_name,
		"target_coord": action.target_coord,
		"target_unit": action.target_unit_id,
		"presentation_anim": pres_anim,
		"actor_from": actor_before.position if actor_before != null else action.target_coord,
		"actor_to": actor_after.position if actor_after != null else action.target_coord,
		"target_from": target_before.position if target_before != null else action.target_coord,
		"target_to": target_after.position if target_after != null else action.target_coord,
		"planning_swap_presentation": true,
	})


func _board_before_planning_action(action: TimelineAction, plan: Timeline) -> BoardState:
	assert(action != null)
	assert(plan != null)
	assert(base_board != null)
	var before: BoardState = base_board.clone()
	for entry: TimelineAction in plan.entries:
		if entry == action:
			return before
		if entry.awaiting_target:
			continue
		var events: Array[SimEvent] = []
		ResolutionPipeline.apply_action(before, entry, events)
		ResolutionPipeline.resolve_pending_pushes(before, events)
	return before


func _filter_committed_premove_visual_events(events: Array[SimEvent]) -> Array[SimEvent]:
	if _execute_premove_skip_actions.is_empty():
		return events
	var remaining: Array[TimelineAction] = _execute_premove_skip_actions.duplicate()
	var out: Array[SimEvent] = []
	var skip_push_unit_ids: Dictionary = {}
	for event: SimEvent in events:
		if remaining.is_empty():
			if (
				event.type == GameEnums.SimEventType.UNIT_PUSHED
				and skip_push_unit_ids.has(int(event.data.get("unit", -1)))
				and not event.data.has("pusher")
			):
				continue
			out.append(event)
			continue
		if _consume_committed_premove_visual_event(event, remaining, skip_push_unit_ids):
			continue
		out.append(event)
	return out


func _consume_committed_premove_visual_event(
	event: SimEvent,
	remaining: Array[TimelineAction],
	skip_push_unit_ids: Dictionary,
) -> bool:
	if remaining.is_empty():
		return false
	var action: TimelineAction = remaining[0]
	match action.type:
		GameEnums.ActionType.MOVE:
			if event.type != GameEnums.SimEventType.UNIT_MOVED:
				return false
			if int(event.data.get("actor", -1)) != action.actor_id:
				return false
			remaining.pop_front()
			return true
		GameEnums.ActionType.ABILITY:
			if action.ability == null:
				remaining.pop_front()
				return _consume_committed_premove_visual_event(event, remaining, skip_push_unit_ids)
			if event.type == GameEnums.SimEventType.ABILITY_USED:
				if int(event.data.get("actor", -1)) != action.actor_id:
					return false
				if event.data.get("ability", &"") != action.ability.id:
					return false
				remaining.pop_front()
				if action.ability.is_movement_kind() and AbilitySystem.ability_has_swap_effect(action.ability):
					if action.target_unit_id >= 0:
						skip_push_unit_ids[action.target_unit_id] = true
					skip_push_unit_ids[action.actor_id] = true
				return true
			if (
				event.type == GameEnums.SimEventType.UNIT_PUSHED
				and action.ability.is_movement_kind()
				and AbilitySystem.ability_has_swap_effect(action.ability)
			):
				var unit_id: int = int(event.data.get("unit", -1))
				if unit_id == action.actor_id or unit_id == action.target_unit_id:
					remaining.pop_front()
					return true
			return false
		_:
			remaining.pop_front()
			return _consume_committed_premove_visual_event(event, remaining, skip_push_unit_ids)


func _flush_pending_planning_commit_events() -> void:
	if _pending_planning_commit_events.is_empty():
		return
	var events: Array[SimEvent] = _pending_planning_commit_events.duplicate()
	_pending_planning_commit_events.clear()
	EventBus.planning_commit_events.emit(events)


func _lock_enemy_intents() -> void:
	base_board.intents = EnemyPlanner.plan(base_board)

func _check_end_state() -> bool:
	if base_board == null:
		return false
	if suppress_end_state.is_valid() and bool(suppress_end_state.call(base_board)):
		return false
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
