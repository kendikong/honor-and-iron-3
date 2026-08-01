class_name KnightQaHarness
extends RefCounted

## Knight class QA harness — separate from planning QA (`run_planning_qa_gate.ps1`).
## Builds headless boards, runs Simulator, asserts Bible outcomes via global systems.

const KNIGHT_DEF_ID: StringName = &"knight"
const DUMMY_DEF_ID: StringName = &"training_dummy"


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


static func knight_unit_data() -> UnitData:
	return DataLibrary.get_unit(KNIGHT_DEF_ID)


static func factory_ability(ability_id: StringName) -> AbilityData:
	var def: UnitData = knight_unit_data()
	if def == null:
		return null
	for ab: AbilityData in def.abilities:
		if ab != null and ab.id == ability_id:
			return ab
	return null


static func factory_passive(passive_id: StringName) -> PassiveData:
	var def: UnitData = knight_unit_data()
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


static func place_knight(
	board: BoardState,
	unit_id: int,
	pos: Vector2i,
	config: Dictionary = {},
) -> UnitState:
	var cfg: Dictionary = config.duplicate(true)
	if not cfg.has("active_abilities"):
		cfg["active_abilities"] = build_training_kit(knight_unit_data())
	return place_unit(board, unit_id, knight_unit_data(), GameEnums.Team.PLAYER, pos, cfg)


static func place_dummy(board: BoardState, unit_id: int, pos: Vector2i) -> UnitState:
	var def: UnitData = DataLibrary.get_training_dummy()
	if def == null:
		def = knight_unit_data()
	return place_unit(board, unit_id, def, GameEnums.Team.ENEMY, pos)


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


static func simulate_plan(board: BoardState, plan: Timeline) -> SimResult:
	board.intents = []
	return Simulator.simulate(board, plan)


static func simulate_player_turn(board: BoardState, plan: Timeline) -> SimResult:
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	var out := SimResult.new()
	out.final_state = board
	out.events = events
	return out


static func unit_on_board(board: BoardState, unit_id: int) -> UnitState:
	return board.get_unit_by_id(unit_id)


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


static func ability_has_status_effect(
	ability: AbilityData,
	status_type: GameEnums.StatusType,
	upgraded: bool = false,
) -> bool:
	if ability == null:
		return false
	var effects: Array[EffectData] = ability.upgraded_effects if upgraded else ability.effects
	for eff: EffectData in effects:
		if eff == null:
			continue
		if eff.type in [GameEnums.EffectType.ADD_STATUS, GameEnums.EffectType.ADD_STATUS_SELF]:
			if eff.status_type == status_type:
				return true
	return false


static func assert_passive_registered(failures: Array[String], passive_id: StringName) -> PassiveData:
	var passive: PassiveData = factory_passive(passive_id)
	assert_true(
		failures, "%s/factory" % passive_id,
		passive != null,
		"passive must exist on knight_factory",
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


static func run_bash_wall_stagger_upgrade(failures: Array[String]) -> void:
	## Shield Bash [+]: PUSH_STAGGER_ON_COLLISION applies STAGGER when push hits wall/enemy.
	var walls: Array[Vector2i] = [Vector2i(7, 2)]
	var board: BoardState = make_plain_board(Vector2i(10, 5), walls)
	var cfg: Dictionary = with_upgraded_ability({}, &"knight_shield_bash")
	place_knight(board, 1, Vector2i(4, 2), cfg)
	place_dummy(board, 2, Vector2i(6, 2))
	var knight: UnitState = unit_on_board(board, 1)
	var bash: AbilityData = ability_on_unit(knight, &"knight_shield_bash")
	assert_true(failures, "bash/upgrade/effect", ability_has_effect(bash, GameEnums.EffectType.PUSH_STAGGER_ON_COLLISION, true))
	var plan := Timeline.new()
	plan.add(TimelineAction.make_move(1, Vector2i(5, 2)))
	plan.add(plan_ability(1, bash, Vector2i(6, 2), 2))
	var result: SimResult = simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "bash/upgrade/stagger",
		enemy != null and has_status(enemy, GameEnums.StatusType.STAGGER),
		"upgraded bash must apply STAGGER on wall collision",
	)


# --- Sim scenario patterns (Knight QA Tier 1) --------------------------------


static func run_active_smoke(
	failures: Array[String],
	ability_id: StringName,
	bible_line: String,
	effect_types: Array = [],
	status_types: Array = [],
) -> void:
	var board: BoardState = make_plain_board(Vector2i(12, 8))
	place_knight(board, 1, Vector2i(3, 3))
	place_dummy(board, 2, Vector2i(6, 3))
	var ability: AbilityData = factory_ability(ability_id)
	assert_true(
		failures, "%s/data" % ability_id,
		ability != null,
		"missing factory ability (%s)" % bible_line,
	)
	if ability == null:
		return
	for eff_type: Variant in effect_types:
		var et: GameEnums.EffectType = eff_type as GameEnums.EffectType
		assert_true(
			failures, "%s/effect/%s" % [ability_id, et],
			ability_has_effect(ability, et, false),
			"base effects must include %s" % et,
		)
	for st: Variant in status_types:
		var status_type: GameEnums.StatusType = st as GameEnums.StatusType
		assert_true(
			failures, "%s/status/%s" % [ability_id, status_type],
			ability_has_status_effect(ability, status_type, false),
			"base effects must include status %s" % status_type,
		)
	if ability.upgraded_effects.size() > 0:
		assert_true(
			failures, "%s/upgrade_data" % ability_id,
			ability.upgrade_description.length() > 0,
			"upgraded_effects require upgrade_description",
		)


static func run_self_buff(
	failures: Array[String],
	ability_id: StringName,
	status_type: GameEnums.StatusType,
) -> void:
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board, 1, Vector2i(3, 3))
	var knight: UnitState = unit_on_board(board, 1)
	var ability: AbilityData = ability_on_unit(knight, ability_id)
	var plan := Timeline.new()
	plan.add(plan_ability(1, ability, knight.position, knight.id))
	var result: SimResult = simulate_plan(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "%s/self_status" % ability_id,
		has_status(after, status_type),
		"self cast must apply %s" % status_type,
	)


static func run_swap_base(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = {
		"active_abilities": [
			DataLibrary.get_universal_run(),
			factory_ability(&"knight_swap"),
			factory_ability(&"knight_shield_bash"),
		],
	}
	place_knight(board, 1, Vector2i(2, 3), cfg)
	var ally_def: UnitData = knight_unit_data()
	place_unit(board, 3, ally_def, GameEnums.Team.PLAYER, Vector2i(2, 4), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var knight: UnitState = unit_on_board(board, 1)
	var swap: AbilityData = ability_on_unit(knight, &"knight_swap")
	assert_true(
		failures, "knight_swap/effect",
		ability_has_effect(swap, GameEnums.EffectType.SWAP, false),
	)
	var mp_before: int = knight.movement.points_left
	var plan := Timeline.new()
	plan.add(plan_ability(1, swap, Vector2i(2, 4), 3, GameEnums.MoveTiming.PRE_ACTION))
	var result: SimResult = simulate_player_turn(board, plan)
	var k_after: UnitState = result.final_state.get_unit_by_id(1)
	var a_after: UnitState = result.final_state.get_unit_by_id(3)
	assert_eq_cell(failures, "knight_swap/knight_pos", k_after.position, Vector2i(2, 4))
	assert_eq_cell(failures, "knight_swap/ally_pos", a_after.position, Vector2i(2, 3))
	assert_true(
		failures, "knight_swap/mp_spent",
		k_after.movement.points_left < mp_before,
		"swap must spend MP",
	)


static func run_swap_upgrade(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = with_upgraded_ability({
		"active_abilities": [
			DataLibrary.get_universal_run(),
			factory_ability(&"knight_swap"),
		],
	}, &"knight_swap")
	place_knight(board, 1, Vector2i(2, 3), cfg)
	var ally_def: UnitData = knight_unit_data()
	place_unit(board, 3, ally_def, GameEnums.Team.PLAYER, Vector2i(2, 4), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var knight: UnitState = unit_on_board(board, 1)
	var swap: AbilityData = ability_on_unit(knight, &"knight_swap")
	assert_true(
		failures, "knight_swap/upgrade/def",
		ability_has_effect(swap, GameEnums.EffectType.ARMOR_UP, true),
	)
	var plan := Timeline.new()
	plan.add(plan_ability(1, swap, Vector2i(2, 4), 3, GameEnums.MoveTiming.PRE_ACTION))
	var result: SimResult = simulate_player_turn(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "knight_swap/upgrade/shield",
		after.armor > 0 or has_status(after, GameEnums.StatusType.STAT_BUFF_DEF),
		"upgraded swap grants DEF/SHIELD",
	)


static func run_hook_vulnerable_upgrade(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(10, 6))
	var cfg: Dictionary = with_upgraded_ability({}, &"knight_chain_hook")
	place_knight(board, 1, Vector2i(1, 3), cfg)
	place_dummy(board, 2, Vector2i(4, 3))
	var knight: UnitState = unit_on_board(board, 1)
	var hook: AbilityData = ability_on_unit(knight, &"knight_chain_hook")
	assert_true(
		failures, "chain_hook/upgrade/effect",
		ability_has_effect(hook, GameEnums.EffectType.PULL_VULNERABLE_ON_ADJACENT, true),
	)
	var plan := Timeline.new()
	plan.add(plan_ability(1, hook, Vector2i(4, 3), 2))
	var result: SimResult = simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "chain_hook/upgrade/vulnerable",
		enemy != null and has_status(enemy, GameEnums.StatusType.VULNERABLE),
		"pulled adjacent enemy gains VULNERABLE when upgraded",
	)


static func run_collision_retaliator(failures: Array[String]) -> void:
	var walls: Array[Vector2i] = [Vector2i(5, 2)]
	var board: BoardState = make_plain_board(Vector2i(8, 5), walls)
	var cfg: Dictionary = with_single_passive(&"collision_retaliator", false)
	place_knight(board, 1, Vector2i(3, 2), cfg)
	place_dummy(board, 2, Vector2i(4, 2))
	var bash: AbilityData = factory_ability(&"knight_shield_bash")
	var plan := Timeline.new()
	plan.add(plan_ability(1, bash, Vector2i(4, 2), 2))
	var hp_before: int = unit_on_board(board, 2).health.current_hp
	var result: SimResult = simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "collision_retaliator/damage",
		enemy != null and enemy.health.current_hp < hp_before,
		"collision into knight must damage enemy via retaliator",
	)
