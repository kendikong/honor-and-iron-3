class_name BruiserQaHarness
extends RefCounted

## Bruiser class QA harness — separate from planning QA (`run_planning_qa_gate.ps1`).
## Builds headless boards, runs Simulator, asserts Bible outcomes via global systems.

const BRUISER_DEF_ID: StringName = &"bruiser"


static func assert_fail(failures: Array[String], tag: String, message: String) -> void:
	failures.append("%s: %s" % [tag, message])


static func assert_true(failures: Array[String], tag: String, condition: bool, message: String = "") -> void:
	if not condition:
		assert_fail(failures, tag, message if not message.is_empty() else "assertion failed")


static func assert_eq_int(failures: Array[String], tag: String, got: int, expected: int) -> void:
	if got != expected:
		assert_fail(failures, tag, "expected %d got %d" % [expected, got])


static func assert_eq_cell(failures: Array[String], tag: String, got: Vector2i, expected: Vector2i) -> void:
	if got != expected:
		assert_fail(failures, tag, "expected %s got %s" % [expected, got])


static func bruiser_unit_data() -> UnitData:
	return DataLibrary.get_unit(BRUISER_DEF_ID)


static func factory_ability(ability_id: StringName) -> AbilityData:
	var def: UnitData = bruiser_unit_data()
	if def == null:
		return null
	for ab: AbilityData in def.abilities:
		if ab != null and ab.id == ability_id:
			return ab
	return null


static func factory_passive(passive_id: StringName) -> PassiveData:
	var def: UnitData = bruiser_unit_data()
	if def == null:
		return null
	for p: PassiveData in def.passives:
		if p != null and p.id == passive_id:
			return p
	return null


static func ability_index(unit: UnitState, ability_id: StringName) -> int:
	for i: int in range(unit.active_abilities.size()):
		var ab: AbilityData = unit.active_abilities[i]
		if ab != null and ab.id == ability_id:
			return i
	return -1


static func ability_on_unit(unit: UnitState, ability_id: StringName) -> AbilityData:
	var idx: int = ability_index(unit, ability_id)
	return unit.active_abilities[idx] if idx >= 0 else null


static func build_training_kit(def: UnitData) -> Array[AbilityData]:
	return DataLibrary.build_training_abilities(def)


static func make_plain_board(size: Vector2i, wall_cells: Array[Vector2i] = []) -> BoardState:
	var walk_terrain := TerrainData.new()
	walk_terrain.id = &"plain"
	walk_terrain.blocks_movement = false
	walk_terrain.stops_displacement = false
	var wall_terrain := TerrainData.new()
	wall_terrain.id = &"wall"
	wall_terrain.blocks_movement = true
	wall_terrain.stops_displacement = true
	var wall_set: Dictionary = {}
	for c: Vector2i in wall_cells:
		wall_set[c] = true
	var board := BoardState.new()
	board.grid_size = size
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			var terrain: TerrainData = wall_terrain if wall_set.has(coord) else walk_terrain
			board.tiles[coord] = TileState.create(coord, terrain)
	return board


static func place_unit(
	board: BoardState,
	unit_id: int,
	def: UnitData,
	team: GameEnums.Team,
	pos: Vector2i,
	config: Dictionary = {},
) -> UnitState:
	var unit: UnitState = UnitState.create(unit_id, def, team, pos, config)
	board.units.append(unit)
	GridSystem.set_occupant(board, pos, unit_id)
	unit.movement.points_left = unit.movement.max_points
	unit.ability.points_left = unit.ability.max_points
	return unit


static func place_bruiser(
	board: BoardState,
	unit_id: int,
	pos: Vector2i,
	config: Dictionary = {},
) -> UnitState:
	var cfg: Dictionary = config.duplicate(true)
	if not cfg.has("active_abilities"):
		cfg["active_abilities"] = build_training_kit(bruiser_unit_data())
	return place_unit(board, unit_id, bruiser_unit_data(), GameEnums.Team.PLAYER, pos, cfg)


static func place_dummy(board: BoardState, unit_id: int, pos: Vector2i, config: Dictionary = {}) -> UnitState:
	var def: UnitData = DataLibrary.get_training_dummy()
	if def == null:
		def = bruiser_unit_data()
	return place_unit(board, unit_id, def, GameEnums.Team.ENEMY, pos, config)


static func with_upgraded_ability(config: Dictionary, ability_id: StringName) -> Dictionary:
	var cfg: Dictionary = config.duplicate(true)
	var ups: Array = cfg.get("upgraded_abilities", []) as Array
	if not ups.has(ability_id):
		ups.append(ability_id)
	cfg["upgraded_abilities"] = ups
	return cfg


static func with_upgraded_passive(config: Dictionary, passive_id: StringName) -> Dictionary:
	var cfg: Dictionary = config.duplicate(true)
	var ups: Array = cfg.get("upgraded_passives", []) as Array
	if not ups.has(passive_id):
		ups.append(passive_id)
	cfg["upgraded_passives"] = ups
	return cfg


static func with_single_passive(passive_id: StringName, upgraded: bool = false) -> Dictionary:
	var passive: PassiveData = factory_passive(passive_id)
	var cfg: Dictionary = {"active_passives": [passive] if passive != null else []}
	if upgraded:
		cfg = with_upgraded_passive(cfg, passive_id)
	return cfg


static func simulate_player_turn(board: BoardState, plan: Timeline) -> SimResult:
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	var out := SimResult.new()
	out.final_state = board
	out.events = events
	return out


static func simulate_plan(board: BoardState, plan: Timeline) -> SimResult:
	return simulate_player_turn(board, plan)


static func unit_on_board(board: BoardState, unit_id: int) -> UnitState:
	return board.get_unit_by_id(unit_id)


static func unit_hp(state: BoardState, unit_id: int) -> int:
	var unit: UnitState = state.get_unit_by_id(unit_id)
	if unit == null or unit.health == null:
		return -1
	return unit.health.current_hp


static func has_status(unit: UnitState, status_type: GameEnums.StatusType) -> bool:
	return unit != null and unit.has_status(status_type)


static func ability_has_effect(ability: AbilityData, effect_type: GameEnums.EffectType, upgraded: bool = false) -> bool:
	if ability == null:
		return false
	var effects: Array[EffectData] = ability.upgraded_effects if upgraded else ability.effects
	for eff: EffectData in effects:
		if eff != null and eff.type == effect_type:
			return true
	return false


static func assert_passive_registered(failures: Array[String], passive_id: StringName) -> PassiveData:
	var passive: PassiveData = factory_passive(passive_id)
	assert_true(
		failures, "%s/factory" % passive_id,
		passive != null,
		"passive must exist on bruiser_factory",
	)
	return passive


static func plan_ability(
	actor_id: int,
	ability: AbilityData,
	target: Vector2i,
	target_unit_id: int = -1,
	timing: GameEnums.MoveTiming = GameEnums.MoveTiming.PRE_ACTION,
) -> TimelineAction:
	return TimelineAction.make_ability(actor_id, ability, target, target_unit_id, timing)


static func events_have_unit_pushed(events: Array, unit_id: int) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.UNIT_PUSHED:
			if int(e.data.get("unit", -1)) == unit_id:
				return true
	return false


static func run_push_through_base(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = {
		"active_abilities": [
			DataLibrary.get_universal_run(),
			factory_ability(&"bruiser_push_through"),
		],
	}
	place_bruiser(board, 1, Vector2i(3, 3), cfg)
	place_dummy(board, 2, Vector2i(3, 4))
	var bruiser: UnitState = unit_on_board(board, 1)
	var push: AbilityData = ability_on_unit(bruiser, &"bruiser_push_through")
	assert_true(
		failures, "push_through/effect",
		ability_has_effect(push, GameEnums.EffectType.MOVE_INTO_AND_PUSH, false),
	)
	assert_eq_int(failures, "push_through/base_mp_cost", push.movement_point_cost, 2)
	var mp_before: int = bruiser.movement.points_left
	var plan := Timeline.new()
	plan.add(plan_ability(1, push, Vector2i(3, 4), 2, GameEnums.MoveTiming.PRE_ACTION))
	var result: SimResult = simulate_plan(board, plan)
	var b_after: UnitState = result.final_state.get_unit_by_id(1)
	var e_after: UnitState = result.final_state.get_unit_by_id(2)
	assert_eq_cell(failures, "push_through/bruiser_pos", b_after.position, Vector2i(3, 4))
	assert_eq_cell(failures, "push_through/enemy_pos", e_after.position, Vector2i(3, 5))
	assert_true(
		failures, "push_through/pushed_event",
		events_have_unit_pushed(result.events, 2),
	)
	assert_eq_int(
		failures, "push_through/mp_spent",
		mp_before - b_after.movement.points_left,
		2,
	)


static func run_push_through_upgrade(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = with_upgraded_ability({
		"active_abilities": [
			DataLibrary.get_universal_run(),
			factory_ability(&"bruiser_push_through"),
		],
	}, &"bruiser_push_through")
	place_bruiser(board, 1, Vector2i(3, 3), cfg)
	place_dummy(board, 2, Vector2i(3, 4))
	var bruiser: UnitState = unit_on_board(board, 1)
	var push: AbilityData = ability_on_unit(bruiser, &"bruiser_push_through")
	assert_true(
		failures, "push_through/upgrade_modifier",
		push.upgraded_effects[0].modifiers.has("buff_on_push"),
	)
	assert_eq_int(
		failures, "push_through/upgrade_mp_cost",
		AbilitySystem.movement_point_cost(bruiser, push),
		1,
	)
	var mp_before: int = bruiser.movement.points_left
	var plan := Timeline.new()
	plan.add(plan_ability(1, push, Vector2i(3, 4), 2, GameEnums.MoveTiming.PRE_ACTION))
	var result: SimResult = simulate_plan(board, plan)
	var b_after: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "push_through/upgrade_str_buff",
		has_status(b_after, GameEnums.StatusType.STAT_BUFF_STR),
		"[+] must grant +1 STR after push via buff_on_push",
	)
	assert_eq_int(
		failures, "push_through/upgrade_mp_spent",
		mp_before - b_after.movement.points_left,
		1,
	)
