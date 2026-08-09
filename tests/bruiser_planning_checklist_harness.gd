class_name BruiserPlanningChecklistHarness
extends RefCounted

## Bruiser planning fixtures for Knight-bar commit smoke (click path only — no drag/undo).

const _Harness := preload("res://tests/bruiser_qa_harness.gd")
const _Drag := preload("res://tests/planning_drag_e2e_harness.gd")


static func wire_board(
	bruiser_pos: Vector2i,
	enemy_pos: Vector2i = Vector2i(-1, -1),
	ally_pos: Vector2i = Vector2i(-1, -1),
	ability_id: StringName = &"",
) -> Dictionary:
	_Drag.cleanup_all()
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var def: UnitData = _Harness.bruiser_unit_data()
	var cfg: Dictionary = (
		_Harness.bruiser_with_ability(ability_id)
		if ability_id != &""
		else {}
	)
	var bruiser: UnitState = UnitState.create(1, def, GameEnums.Team.PLAYER, bruiser_pos, cfg)
	if cfg.is_empty():
		bruiser.active_abilities = _Harness.build_training_kit(def)
	bruiser.movement.points_left = bruiser.movement.max_points
	bruiser.ability.points_left = 1
	bruiser.ability.max_points = 1
	var units: Array[UnitState] = [bruiser]
	var enemy: UnitState = null
	if enemy_pos.x >= 0:
		var dummy_def: UnitData = DataLibrary.get_training_dummy()
		enemy = UnitState.create(2, dummy_def, GameEnums.Team.ENEMY, enemy_pos)
		units.append(enemy)
	var ally: UnitState = null
	if ally_pos.x >= 0:
		ally = UnitState.create(3, def, GameEnums.Team.PLAYER, ally_pos)
		units.append(ally)
	var board: BoardState = _Drag._plain_board(Vector2i(12, 12), units)
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	input._director = director
	input.auto_use_skill_after_move = true
	var fix: Dictionary = {
		"input": input,
		"director": director,
		"board": board,
		"bruiser": bruiser,
		"knight": bruiser,
		"enemy": enemy,
		"ally": ally,
	}
	return _Drag.wire_fixture(fix)
