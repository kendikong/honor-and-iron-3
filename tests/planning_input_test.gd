class_name PlanningInputTest
extends RefCounted

## Headless planning-input smoke tests (Phase 11).

static func run_all(failures: Array[String]) -> void:
	_test_force_basic_flag(failures)
	_test_undoable_action_director(failures)


static func _test_force_basic_flag(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	input.force_basic_movement = true
	if not input.force_basic_movement:
		failures.append("PlanningInputTest: force_basic_movement should persist when set")


static func _test_undoable_action_director(failures: Array[String]) -> void:
	var director := CombatDirector.new()
	var board := BoardState.new()
	board.grid_size = Vector2i(8, 6)
	var unit := UnitState.new()
	unit.id = 1
	unit.team = GameEnums.Team.PLAYER
	unit.position = Vector2i(2, 2)
	board.units = [unit]
	director.board = board
	director.phase = CombatDirector.Phase.PLANNING
	if director.unit_has_undoable_action(1):
		failures.append("PlanningInputTest: empty plan should not be undoable")
	var move := TimelineAction.new()
	move.type = GameEnums.ActionType.MOVE
	move.actor_id = 1
	move.target_coord = Vector2i(3, 2)
	director.plan_pre_move.entries.append(move)
	if not director.unit_has_undoable_action(1):
		failures.append("PlanningInputTest: queued move should be undoable")
	director.plan_pre_move.entries.clear()
	var wait_action := TimelineAction.make_ability(
		1,
		DataLibrary.get_universal_wait(),
		Vector2i(2, 2),
		1,
		GameEnums.MoveTiming.PRE_ACTION,
	)
	director.plan_action.entries.append(wait_action)
	if not director.unit_has_undoable_action(1):
		failures.append("PlanningInputTest: queued wait should be undoable")
