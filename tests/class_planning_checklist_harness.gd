class_name ClassPlanningChecklistHarness
extends RefCounted

## Generic planning fixture for movement/preview-origin smoke (all classes).

const _Drag := preload("res://tests/planning_drag_e2e_harness.gd")


static func wire_board(
	class_id: StringName,
	actor_pos: Vector2i,
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
	var def: UnitData = FactoryTestHelpers.build_unit(class_id)
	if def == null:
		push_error("ClassPlanningChecklistHarness: missing unit data for %s" % class_id)
		return {}
	var actor: UnitState = _actor_with_ability(def, actor_pos, ability_id)
	var units: Array[UnitState] = [actor]
	var enemy: UnitState = null
	if enemy_pos.x >= 0:
		enemy = UnitState.create(
			2, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, enemy_pos,
		)
		units.append(enemy)
	var ally: UnitState = null
	if ally_pos.x >= 0:
		ally = UnitState.create(3, def, GameEnums.Team.PLAYER, ally_pos, {
			"active_abilities": [DataLibrary.get_universal_run()],
		})
		units.append(ally)
	var board: BoardState = _Drag._plain_board(Vector2i(12, 12), units)
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = actor.id
	input._director = director
	input.auto_use_skill_after_move = true
	var fix: Dictionary = {
		"input": input,
		"director": director,
		"board": board,
		"actor": actor,
		"bruiser": actor,
		"knight": actor,
		"enemy": enemy,
		"ally": ally,
		"class_id": class_id,
	}
	return _Drag.wire_fixture(fix)


static func _actor_with_ability(
	def: UnitData,
	actor_pos: Vector2i,
	ability_id: StringName,
) -> UnitState:
	var abilities: Array[AbilityData] = []
	if ability_id != &"":
		for ab: AbilityData in def.abilities:
			if ab != null and ab.id == ability_id:
				abilities.append(ab)
				break
	else:
		for ab: AbilityData in def.abilities:
			if ab != null:
				abilities.append(ab)
	var run: AbilityData = DataLibrary.get_universal_run()
	if run != null:
		var has_run: bool = false
		for ab: AbilityData in abilities:
			if ab != null and ab.is_universal_run():
				has_run = true
				break
		if not has_run:
			abilities.append(run)
	var actor: UnitState = UnitState.create(
		1, def, GameEnums.Team.PLAYER, actor_pos, {"active_abilities": abilities},
	)
	actor.movement.points_left = maxi(actor.movement.max_points, 8)
	actor.movement.max_points = maxi(actor.movement.max_points, 8)
	actor.ability.points_left = maxi(actor.ability.max_points, 1)
	actor.ability.max_points = maxi(actor.ability.max_points, 1)
	return actor
