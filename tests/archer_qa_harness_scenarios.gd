class_name ArcherQaHarnessScenarios
extends RefCounted

## Per-skill Tier-1 sim depth for Archer (Bible + shared systems).

const H := preload("res://tests/archer_qa_harness.gd")


static func run_sidestep(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"archer_sidestep")
	H.assert_true(failures, "sidestep/premove", ab.is_pre_move_planner())
	H.assert_true(
		failures, "sidestep/ignore_zoc",
		ab.modules[0].legacy_modifiers.get("ignore_zoc", false),
	)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_archer(board, 1, Vector2i(2, 3), H.archer_with_ability(&"archer_sidestep"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_sidestep")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3), -1, GameEnums.MoveTiming.PRE_ACTION))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_eq_cell(
		failures, "sidestep/pos",
		result.final_state.get_unit_by_id(1).position,
		Vector2i(3, 3),
	)


static func run_power_shot(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"archer_power_shot")
	H.assert_eq_int(failures, "power_shot/dmg", ab.effects[0].amount, 3)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_archer(board, 1, Vector2i(2, 3), H.archer_with_ability(&"archer_power_shot"))
	H.place_dummy(board, 2, Vector2i(5, 3))
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_power_shot")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "power_shot/damage",
		H.unit_hp(result.final_state, 2) < hp,
	)
	H.assert_true(
		failures, "power_shot/outside_safe",
		H.unit_hp(result.final_state, 2) == H.unit_hp(board, 2) or H.unit_hp(result.final_state, 2) < hp,
	)


static func run_volley(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"archer_volley")
	H.assert_eq_int(failures, "volley/shape", ab.target_shape, GameEnums.TargetShape.AOE_SQUARE)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_archer(board, 1, Vector2i(2, 3), H.archer_with_ability(&"archer_volley"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	H.place_dummy(board, 3, Vector2i(4, 4))
	H.place_dummy(board, 4, Vector2i(6, 6))
	var hp_in: int = H.unit_hp(board, 2) + H.unit_hp(board, 3)
	var hp_out: int = H.unit_hp(board, 4)
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_volley")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	var dmg_in: int = hp_in - (H.unit_hp(result.final_state, 2) + H.unit_hp(result.final_state, 3))
	H.assert_true(failures, "volley/aoe_hits", dmg_in > 0)
	H.assert_eq_int(
		failures, "volley/outside_excluded",
		H.unit_hp(result.final_state, 4),
		hp_out,
	)


static func run_pinning_arrow(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_archer(board, 1, Vector2i(2, 3), H.archer_with_ability(&"archer_pinning_arrow"))
	H.place_dummy(board, 2, Vector2i(5, 3))
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_pinning_arrow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_true(
		failures, "pinning_arrow/root",
		enemy != null and _has_status(enemy, GameEnums.StatusType.ROOT),
	)


static func run_piercing_shot(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(12, 8))
	H.place_archer(board, 1, Vector2i(2, 3), H.archer_with_ability(&"archer_piercing_shot"))
	H.place_dummy(board, 2, Vector2i(5, 3))
	H.place_dummy(board, 3, Vector2i(6, 3))
	var hp_line: int = H.unit_hp(board, 2) + H.unit_hp(board, 3)
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_piercing_shot")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(6, 3), 3))
	var result: SimResult = H.simulate_plan(board, plan)
	var dmg_line: int = hp_line - (H.unit_hp(result.final_state, 2) + H.unit_hp(result.final_state, 3))
	H.assert_true(failures, "piercing_shot/line_hits", dmg_line > 0)


static func run_toxic_spore_arrow(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_archer(board, 1, Vector2i(2, 3), H.archer_with_ability(&"archer_toxic_spore_arrow"))
	H.place_dummy(board, 2, Vector2i(5, 3))
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_toxic_spore_arrow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "toxic_spore_arrow/used",
		_events_have_ability(result.events, &"archer_toxic_spore_arrow"),
	)


static func run_grapple_arrow(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	board.set_tile_terrain(Vector2i(5, 3), DataLibrary.get_terrain(&"wall"))
	H.place_archer(board, 1, Vector2i(2, 3), H.archer_with_ability(&"archer_grapple_arrow"))
	var start: Vector2i = board.get_unit_by_id(1).position
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_grapple_arrow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	var archer: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "grapple_arrow/pull",
		archer != null and archer.position != start,
	)


static func run_explosive_arrow(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_archer(board, 1, Vector2i(2, 3), H.archer_with_ability(&"archer_explosive_arrow"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	H.place_dummy(board, 3, Vector2i(4, 2))
	H.place_dummy(board, 4, Vector2i(6, 6))
	var hp_cross: int = H.unit_hp(board, 2) + H.unit_hp(board, 3)
	var hp_out: int = H.unit_hp(board, 4)
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_explosive_arrow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	var dmg_cross: int = hp_cross - (H.unit_hp(result.final_state, 2) + H.unit_hp(result.final_state, 3))
	H.assert_true(failures, "explosive_arrow/square_hits", dmg_cross > 0)
	H.assert_eq_int(failures, "explosive_arrow/outside_excluded", H.unit_hp(result.final_state, 4), hp_out)


static func run_hunters_mark(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_archer(board, 1, Vector2i(2, 3), H.archer_with_ability(&"archer_hunters_mark"))
	H.place_dummy(board, 2, Vector2i(5, 3))
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_hunters_mark")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_true(
		failures, "hunters_mark/status",
		enemy != null and enemy.active_statuses.size() > 0,
	)


static func run_repelling_shot(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.archer_with_ability(&"archer_repelling_shot")
	H.place_archer(board, 1, Vector2i(2, 4), cfg)
	H.place_dummy(board, 2, Vector2i(5, 4))
	var start: Vector2i = board.get_unit_by_id(2).position
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_repelling_shot")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 4), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_true(
		failures, "repelling_shot/push",
		enemy != null and enemy.position != start,
	)


static func run_bear_trap(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_archer(board, 1, Vector2i(2, 3), H.archer_with_ability(&"archer_bear_trap"))
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_bear_trap")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "bear_trap/hazard",
		result.final_state.tiles.has(Vector2i(4, 3)),
	)


static func run_suppressing_fire(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"archer_suppressing_fire")
	H.assert_eq_int(failures, "suppressing_fire/shape", ab.target_shape, GameEnums.TargetShape.ARC)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_archer(board, 1, Vector2i(2, 3), H.archer_with_ability(&"archer_suppressing_fire"))
	H.place_dummy(board, 2, Vector2i(5, 3))
	H.place_dummy(board, 3, Vector2i(5, 4))
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_suppressing_fire")
	var target: Vector2i = Vector2i(5, 3)
	var footprint: Array[Vector2i] = GridSystem.get_affected_tiles(
		board, Vector2i(2, 3), target, GameEnums.TargetShape.ARC, skill.target_shape_size,
	)
	H.assert_true(
		failures, "suppressing_fire/footprint_in",
		footprint.has(Vector2i(5, 3)),
		"ARC footprint must include aim tile",
	)
	H.assert_true(
		failures, "suppressing_fire/footprint_excludes_far",
		not footprint.has(Vector2i(8, 3)),
		"ARC footprint must not include tiles beyond authored sweep",
	)
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, target, -1))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "suppressing_fire/used",
		_events_have_ability(result.events, &"archer_suppressing_fire"),
	)


static func run_caltrop_trap(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_archer(board, 1, Vector2i(2, 3), H.archer_with_ability(&"archer_caltrop_trap"))
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_caltrop_trap")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "caltrop_trap/hazard",
		_events_have_ability(result.events, &"archer_caltrop_trap"),
	)


static func run_parting_shot(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_archer(board, 1, Vector2i(2, 3), H.archer_with_ability(&"archer_parting_shot"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_parting_shot")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "parting_shot/damage",
		H.unit_hp(result.final_state, 2) < hp,
	)


static func run_scouts_eye(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_archer(board, 1, Vector2i(2, 3), H.archer_with_ability(&"archer_scouts_eye"))
	H.place_dummy(board, 2, Vector2i(5, 3))
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_scouts_eye")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "scouts_eye/used",
		_events_have_ability(result.events, &"archer_scouts_eye"),
	)


static func _events_have_type(events: Array[SimEvent], event_type: int, unit_id: int) -> bool:
	for event: SimEvent in events:
		if event.type == event_type and int(event.data.get("unit", -1)) == unit_id:
			return true
	return false


static func _events_have_ability(events: Array[SimEvent], ability_id: StringName) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ABILITY_USED and event.data.get("ability") == ability_id:
			return true
	return false


static func _has_status(unit: UnitState, status_type: GameEnums.StatusType) -> bool:
	for status: StatusData in unit.active_statuses:
		if status.type == status_type:
			return true
	return false
