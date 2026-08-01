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


static func place_dummy(board: BoardState, unit_id: int, pos: Vector2i, config: Dictionary = {}) -> UnitState:
	var def: UnitData = DataLibrary.get_training_dummy()
	if def == null:
		def = knight_unit_data()
	return place_unit(board, unit_id, def, GameEnums.Team.ENEMY, pos, config)


static func place_enemy_basher(board: BoardState, unit_id: int, pos: Vector2i) -> UnitState:
	var def: UnitData = DataLibrary.get_training_dummy()
	if def == null:
		def = knight_unit_data()
	var unit: UnitState = place_unit(board, unit_id, def, GameEnums.Team.ENEMY, pos, {
		"active_abilities": [
			DataLibrary.get_universal_run(),
			factory_ability(&"knight_shield_bash"),
		],
	})
	unit.ability.max_points = 2
	unit.ability.points_left = 2
	return unit


static func place_player_basher(board: BoardState, unit_id: int, pos: Vector2i) -> UnitState:
	return place_knight(board, unit_id, pos, {
		"active_abilities": [
			DataLibrary.get_universal_run(),
			factory_ability(&"knight_shield_bash"),
		],
	})


static func soften_for_melee_hit(unit: UnitState) -> void:
	unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.VULNERABLE, 1, 1))
	unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 5))
	unit._recalculate_stats()


static func boost_striker(unit: UnitState) -> void:
	unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, 20))
	unit._recalculate_stats()


static func events_have_retaliator_upgrade_push(events: Array, blocker_id: int) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.COLLISION:
			var d: Dictionary = e.data
			if (
				int(d.get("pusher_id", -1)) == blocker_id
				and d.get("is_collision_side_effect", false)
				and int(d.get("push_distance", 0)) == 1
			):
				return true
	return false


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
	## Collision Retaliator: victim pushed into knight takes collision damage.
	var board: BoardState = make_plain_board(Vector2i(8, 5))
	var cfg: Dictionary = with_single_passive(&"collision_retaliator", false)
	place_knight(board, 1, Vector2i(3, 2), cfg)
	place_dummy(board, 2, Vector2i(4, 2))
	place_player_basher(board, 3, Vector2i(5, 2))
	var bash: AbilityData = ability_on_unit(unit_on_board(board, 3), &"knight_shield_bash")
	var plan := Timeline.new()
	plan.add(plan_ability(3, bash, Vector2i(4, 2), 2))
	var hp_before: int = unit_on_board(board, 2).health.current_hp
	var result: SimResult = simulate_plan(board, plan)
	var victim: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "collision_retaliator/damage",
		victim != null and victim.health.current_hp < hp_before,
		"collision into knight must damage victim via retaliator",
	)


static func run_bash_base_sim(failures: Array[String]) -> void:
	## Shield Bash base: DAMAGE 1 + PUSH 2; no STAGGER without upgrade.
	var board: BoardState = make_plain_board(Vector2i(10, 5))
	place_knight(board, 1, Vector2i(4, 2))
	place_dummy(board, 2, Vector2i(6, 2))
	var knight: UnitState = unit_on_board(board, 1)
	var bash: AbilityData = ability_on_unit(knight, &"knight_shield_bash")
	var hp_before: int = unit_on_board(board, 2).health.current_hp
	var plan := Timeline.new()
	plan.add(TimelineAction.make_move(1, Vector2i(5, 2)))
	plan.add(plan_ability(1, bash, Vector2i(6, 2), 2))
	var result: SimResult = simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(failures, "bash/base/damage", enemy != null and enemy.health.current_hp < hp_before, "bash must deal damage")
	assert_eq_cell(failures, "bash/base/push", enemy.position, Vector2i(8, 2))
	assert_true(
		failures, "bash/base/no_stagger",
		enemy != null and not has_status(enemy, GameEnums.StatusType.STAGGER),
		"base bash must not apply STAGGER without upgrade",
	)


static func run_hook_base_sim(failures: Array[String]) -> void:
	## Chain Hook base: DAMAGE + PULL 2; no VULNERABLE without upgrade.
	var board: BoardState = make_plain_board(Vector2i(10, 6))
	place_knight(board, 1, Vector2i(1, 3))
	place_dummy(board, 2, Vector2i(4, 3))
	var knight: UnitState = unit_on_board(board, 1)
	var hook: AbilityData = ability_on_unit(knight, &"knight_chain_hook")
	var hp_before: int = unit_on_board(board, 2).health.current_hp
	var plan := Timeline.new()
	plan.add(plan_ability(1, hook, Vector2i(4, 3), 2))
	var result: SimResult = simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(failures, "chain_hook/base/damage", enemy != null and enemy.health.current_hp < hp_before, "hook must deal damage")
	assert_eq_cell(failures, "chain_hook/base/pull", enemy.position, Vector2i(2, 3))
	assert_true(
		failures, "chain_hook/base/no_vuln",
		enemy != null and not has_status(enemy, GameEnums.StatusType.VULNERABLE),
		"base hook must not apply VULNERABLE without upgrade",
	)


static func run_collision_retaliator_upgrade(failures: Array[String]) -> void:
	## Collision Retaliator [+]: victim also PUSHED 1 after collision.
	var board: BoardState = make_plain_board(Vector2i(10, 5))
	var cfg: Dictionary = with_single_passive(&"collision_retaliator", true)
	place_knight(board, 1, Vector2i(3, 2), cfg)
	place_dummy(board, 2, Vector2i(4, 2))
	place_player_basher(board, 3, Vector2i(6, 2))
	var bash: AbilityData = ability_on_unit(unit_on_board(board, 3), &"knight_shield_bash")
	var plan := Timeline.new()
	plan.add(TimelineAction.make_move(3, Vector2i(5, 2)))
	plan.add(plan_ability(3, bash, Vector2i(4, 2), 2))
	var result: SimResult = simulate_player_turn(board, plan)
	var victim: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "collision_retaliator/upgrade/push",
		events_have_retaliator_upgrade_push(result.events, 1),
		"upgraded retaliator must trigger bonus PUSH on collision",
	)


static func run_stand_ground(failures: Array[String]) -> void:
	## Stand Ground: immune to PUSH; attacker suffers counter ATK 1.
	var board: BoardState = make_plain_board(Vector2i(8, 5))
	var cfg: Dictionary = with_single_passive(&"stand_ground", false)
	place_knight(board, 1, Vector2i(3, 2), cfg)
	place_enemy_basher(board, 2, Vector2i(2, 2))
	var bash: AbilityData = ability_on_unit(unit_on_board(board, 2), &"knight_shield_bash")
	var hp_before: int = unit_on_board(board, 2).health.current_hp
	var plan := Timeline.new()
	plan.add(plan_ability(2, bash, Vector2i(3, 2), 1))
	var result: SimResult = simulate_plan(board, plan)
	var knight: UnitState = result.final_state.get_unit_by_id(1)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	assert_eq_cell(failures, "stand_ground/no_push", knight.position, Vector2i(3, 2))
	assert_true(
		failures, "stand_ground/counter",
		enemy != null and enemy.health.current_hp < hp_before,
		"push attempt must counter-attack attacker",
	)
	var cfg_up: Dictionary = with_single_passive(&"stand_ground", true)
	var board2: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board2, 10, Vector2i(3, 2), cfg_up)
	place_enemy_basher(board2, 11, Vector2i(2, 2))
	var bash2: AbilityData = ability_on_unit(unit_on_board(board2, 11), &"knight_shield_bash")
	var hp2: int = unit_on_board(board2, 11).health.current_hp
	var plan2 := Timeline.new()
	plan2.add(plan_ability(11, bash2, Vector2i(3, 2), 10))
	var result2: SimResult = simulate_plan(board2, plan2)
	var enemy2: UnitState = result2.final_state.get_unit_by_id(11)
	var dmg2: int = hp2 - enemy2.health.current_hp
	assert_true(
		failures, "stand_ground/upgrade/counter2",
		enemy2 != null and dmg2 >= 2,
		"upgraded stand ground must counter-attack for 2",
	)


static func run_thorny_carapace(failures: Array[String]) -> void:
	## Thorny Carapace: melee hit reflects damage and PUSH 1.
	var board: BoardState = make_plain_board(Vector2i(8, 5))
	var cfg: Dictionary = with_single_passive(&"thorny_carapace", false)
	place_knight(board, 1, Vector2i(3, 2), cfg)
	soften_for_melee_hit(unit_on_board(board, 1))
	place_enemy_basher(board, 2, Vector2i(4, 2))
	var enemy: UnitState = unit_on_board(board, 2)
	boost_striker(enemy)
	enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 10))
	enemy._recalculate_stats()
	var bash: AbilityData = ability_on_unit(enemy, &"knight_shield_bash")
	var hp_before: int = enemy.health.current_hp
	var plan := Timeline.new()
	plan.add(plan_ability(2, bash, Vector2i(3, 2), 1))
	var result: SimResult = simulate_player_turn(board, plan)
	var enemy_after: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "thorny_carapace/reflect",
		enemy_after != null and enemy_after.health.current_hp < hp_before,
		"melee hit must reflect damage to attacker",
	)
	assert_eq_cell(
		failures, "thorny_carapace/push",
		enemy_after.position,
		Vector2i(5, 2),
	)
	var cfg_up: Dictionary = with_single_passive(&"thorny_carapace", true)
	var board2: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board2, 10, Vector2i(3, 2), cfg_up)
	soften_for_melee_hit(unit_on_board(board2, 10))
	place_enemy_basher(board2, 11, Vector2i(4, 2))
	var enemy2: UnitState = unit_on_board(board2, 11)
	boost_striker(enemy2)
	enemy2.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 10))
	enemy2._recalculate_stats()
	var bash2: AbilityData = ability_on_unit(enemy2, &"knight_shield_bash")
	var hp2: int = enemy2.health.current_hp
	var plan2 := Timeline.new()
	plan2.add(plan_ability(11, bash2, Vector2i(3, 2), 10))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var after2: UnitState = result2.final_state.get_unit_by_id(11)
	var dmg2: int = hp2 - after2.health.current_hp
	assert_true(
		failures, "thorny_carapace/upgrade/full_reflect",
		after2 != null and dmg2 >= 2,
		"upgraded thorny carapace must reflect 100% damage (>= base 50%)",
	)


static func run_shield_mastery(failures: Array[String]) -> void:
	## Shield Mastery: front-arc hit grants SHIELD 2.
	var board: BoardState = make_plain_board(Vector2i(8, 5))
	var cfg: Dictionary = with_single_passive(&"shield_mastery", false)
	place_knight(board, 1, Vector2i(3, 2), cfg)
	unit_on_board(board, 1).facing = GameEnums.Facing.EAST
	place_enemy_basher(board, 2, Vector2i(4, 2))
	var bash: AbilityData = ability_on_unit(unit_on_board(board, 2), &"knight_shield_bash")
	var armor_before: int = unit_on_board(board, 1).armor
	var plan := Timeline.new()
	plan.add(plan_ability(2, bash, Vector2i(3, 2), 1))
	var result: SimResult = simulate_player_turn(board, plan)
	var knight: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "shield_mastery/shield",
		knight != null and knight.armor > armor_before,
		"front-arc hit must grant SHIELD via Shield Mastery",
	)
	var cfg_up: Dictionary = with_single_passive(&"shield_mastery", true)
	var board2: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board2, 10, Vector2i(3, 2), cfg_up)
	unit_on_board(board2, 10).facing = GameEnums.Facing.EAST
	place_enemy_basher(board2, 11, Vector2i(4, 2))
	var bash2: AbilityData = ability_on_unit(unit_on_board(board2, 11), &"knight_shield_bash")
	var armor_before2: int = unit_on_board(board2, 10).armor
	var plan2 := Timeline.new()
	plan2.add(plan_ability(11, bash2, Vector2i(3, 2), 10))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var knight2: UnitState = result2.final_state.get_unit_by_id(10)
	assert_true(
		failures, "shield_mastery/upgrade/shield3",
		knight2 != null and knight2.armor >= armor_before2 + 3,
		"upgraded shield mastery must grant SHIELD 3 on front-arc hit",
	)


static func run_bulwark(failures: Array[String]) -> void:
	## Bulwark: +1 DEF per adjacent unit.
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = with_single_passive(&"bulwark", false)
	place_knight(board, 1, Vector2i(3, 3), cfg)
	place_dummy(board, 2, Vector2i(4, 3))
	var knight: UnitState = unit_on_board(board, 1)
	var base_def: int = knight.current_defense
	var with_adj: int = CombatSystem.get_dynamic_defense(board, knight)
	assert_true(
		failures, "bulwark/def_bonus",
		with_adj > base_def,
		"adjacent unit must increase DEF via Bulwark",
	)


static func run_kinetic_armor(failures: Array[String]) -> void:
	## Kinetic Armor: flat -1 damage while SHIELD active.
	var board: BoardState = make_plain_board(Vector2i(8, 5))
	var cfg: Dictionary = with_single_passive(&"kinetic_armor", false)
	place_knight(board, 1, Vector2i(3, 2), cfg)
	var knight: UnitState = unit_on_board(board, 1)
	knight.armor = 3
	place_enemy_basher(board, 2, Vector2i(4, 2))
	var bash: AbilityData = ability_on_unit(unit_on_board(board, 2), &"knight_shield_bash")
	var plan := Timeline.new()
	plan.add(plan_ability(2, bash, Vector2i(3, 2), 1))
	var result: SimResult = simulate_player_turn(board, plan)
	var knight_after: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "kinetic_armor/mitigate",
		knight_after != null and knight_after.is_alive(),
		"knight must survive melee hit with kinetic armor",
	)
	assert_true(
		failures, "kinetic_armor/shield_retained",
		knight_after != null and (knight_after.armor > 0 or knight_after.health.current_hp == knight.health.current_hp),
		"kinetic armor must mitigate damage while shield active",
	)
	var cfg_up: Dictionary = with_single_passive(&"kinetic_armor", true)
	var board2: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board2, 10, Vector2i(3, 2), cfg_up)
	var knight2: UnitState = unit_on_board(board2, 10)
	knight2.armor = 5
	knight2.health.current_hp = 20
	place_enemy_basher(board2, 11, Vector2i(4, 2))
	var bash2: AbilityData = ability_on_unit(unit_on_board(board2, 11), &"knight_shield_bash")
	var hp_before2: int = knight2.health.current_hp
	var plan2 := Timeline.new()
	plan2.add(plan_ability(11, bash2, Vector2i(3, 2), 10))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var knight_after2: UnitState = result2.final_state.get_unit_by_id(10)
	assert_true(
		failures, "kinetic_armor/upgrade/mitigate2",
		knight_after2 != null and knight_after2.health.current_hp >= hp_before2 - 1,
		"upgraded kinetic armor must reduce incoming damage by 2 while shield active",
	)


static func run_indestructible_bastion(failures: Array[String]) -> void:
	## Indestructible Bastion: lethal -> 1 HP + SHIELD = DEF (once).
	var board: BoardState = make_plain_board(Vector2i(8, 5))
	var cfg: Dictionary = with_single_passive(&"indestructible_bastion", false)
	place_knight(board, 1, Vector2i(3, 2), cfg)
	var knight: UnitState = unit_on_board(board, 1)
	knight.health.current_hp = 3
	soften_for_melee_hit(knight)
	place_enemy_basher(board, 2, Vector2i(4, 2))
	boost_striker(unit_on_board(board, 2))
	var bash: AbilityData = ability_on_unit(unit_on_board(board, 2), &"knight_shield_bash")
	var plan := Timeline.new()
	plan.add(plan_ability(2, bash, Vector2i(3, 2), 1))
	var result: SimResult = simulate_player_turn(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "indestructible_bastion/survive",
		after != null and after.is_alive() and after.health.current_hp == 1,
		"lethal hit must survive at 1 HP via Indestructible Bastion",
	)
	assert_true(
		failures, "indestructible_bastion/used",
		after != null and after.passive_flags.get("bastion_used", false),
		"bastion trigger must fire once",
	)
	var cfg_up: Dictionary = with_single_passive(&"indestructible_bastion", true)
	var board2: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board2, 10, Vector2i(3, 2), cfg_up)
	var knight2: UnitState = unit_on_board(board2, 10)
	knight2.health.current_hp = 3
	soften_for_melee_hit(knight2)
	place_enemy_basher(board2, 11, Vector2i(4, 2))
	boost_striker(unit_on_board(board2, 11))
	var bash2: AbilityData = ability_on_unit(unit_on_board(board2, 11), &"knight_shield_bash")
	var plan2 := Timeline.new()
	plan2.add(plan_ability(11, bash2, Vector2i(3, 2), 10))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var after2: UnitState = result2.final_state.get_unit_by_id(10)
	assert_true(
		failures, "indestructible_bastion/upgrade/str",
		after2 != null and has_status(after2, GameEnums.StatusType.STAT_BUFF_STR),
		"upgraded indestructible bastion must grant +2 STR after trigger",
	)


static func run_trample_base_sim(failures: Array[String]) -> void:
	## Trampling Advance base: MOVE + TRAMPLE + PUSH on tile target.
	var board: BoardState = make_plain_board(Vector2i(12, 8))
	place_knight(board, 1, Vector2i(5, 4))
	place_dummy(board, 2, Vector2i(6, 4))
	var knight: UnitState = unit_on_board(board, 1)
	var trample: AbilityData = ability_on_unit(knight, &"knight_trampling_advance")
	var plan := Timeline.new()
	plan.add(plan_ability(1, trample, Vector2i(6, 3), -1))
	var result: SimResult = simulate_plan(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "trample/base/moved",
		after != null and after.position != Vector2i(5, 4),
		"trample must move caster along route",
	)


static func run_concussive_shatter(failures: Array[String]) -> void:
	var walls: Array[Vector2i] = [Vector2i(6, 2)]
	var board: BoardState = make_plain_board(Vector2i(10, 5), walls)
	var cfg: Dictionary = with_single_passive(&"concussive_shatter", false)
	place_knight(board, 1, Vector2i(3, 2), cfg)
	place_dummy(board, 2, Vector2i(4, 2))
	var bash: AbilityData = ability_on_unit(unit_on_board(board, 1), &"knight_shield_bash")
	var plan := Timeline.new()
	plan.add(plan_ability(1, bash, Vector2i(4, 2), 2))
	var result: SimResult = simulate_player_turn(board, plan)
	var victim: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "concussive_shatter/debuff",
		victim != null and has_status(victim, GameEnums.StatusType.STAT_DEBUFF_DEF),
		"collision must apply DEF debuff via Concussive Shatter",
	)
	var cfg_up: Dictionary = with_single_passive(&"concussive_shatter", true)
	var board2: BoardState = make_plain_board(Vector2i(10, 5), walls)
	place_knight(board2, 10, Vector2i(3, 2), cfg_up)
	place_dummy(board2, 11, Vector2i(4, 2))
	var bash2: AbilityData = ability_on_unit(unit_on_board(board2, 10), &"knight_shield_bash")
	var plan2 := Timeline.new()
	plan2.add(plan_ability(10, bash2, Vector2i(4, 2), 11))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var victim2: UnitState = result2.final_state.get_unit_by_id(11)
	assert_true(
		failures, "concussive_shatter/upgrade/vulnerable",
		victim2 != null and has_status(victim2, GameEnums.StatusType.VULNERABLE),
		"upgraded concussive shatter must apply VULNERABLE on collision victim",
	)


static func run_kinetic_momentum(failures: Array[String]) -> void:
	var walls: Array[Vector2i] = [Vector2i(6, 2)]
	var board: BoardState = make_plain_board(Vector2i(10, 5), walls)
	var cfg: Dictionary = with_single_passive(&"kinetic_momentum", false)
	place_knight(board, 1, Vector2i(3, 2), cfg)
	var armor_before: int = unit_on_board(board, 1).armor
	place_dummy(board, 2, Vector2i(4, 2))
	var bash: AbilityData = ability_on_unit(unit_on_board(board, 1), &"knight_shield_bash")
	var plan := Timeline.new()
	plan.add(plan_ability(1, bash, Vector2i(4, 2), 2))
	var result: SimResult = simulate_player_turn(board, plan)
	var knight: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "kinetic_momentum/shield",
		knight != null and knight.armor > armor_before,
		"causing collision damage must grant SHIELD via Kinetic Momentum",
	)
	var cfg_up: Dictionary = with_single_passive(&"kinetic_momentum", true)
	var board2: BoardState = make_plain_board(Vector2i(10, 5), walls)
	place_knight(board2, 10, Vector2i(3, 2), cfg_up)
	place_dummy(board2, 11, Vector2i(4, 2))
	var bash2: AbilityData = ability_on_unit(unit_on_board(board2, 10), &"knight_shield_bash")
	var mov_before: int = unit_on_board(board2, 10).movement.points_left
	var plan2 := Timeline.new()
	plan2.add(plan_ability(10, bash2, Vector2i(4, 2), 11))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var knight2: UnitState = result2.final_state.get_unit_by_id(10)
	assert_true(
		failures, "kinetic_momentum/upgrade/mov_refund",
		knight2 != null and knight2.movement.points_left > mov_before,
		"upgraded kinetic momentum must refund 1 MOV on first collision",
	)


static func run_kinetic_converter(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(8, 5))
	var cfg: Dictionary = with_single_passive(&"kinetic_converter", false)
	place_knight(board, 1, Vector2i(3, 2), cfg)
	soften_for_melee_hit(unit_on_board(board, 1))
	place_enemy_basher(board, 2, Vector2i(4, 2))
	boost_striker(unit_on_board(board, 2))
	var bash: AbilityData = ability_on_unit(unit_on_board(board, 2), &"knight_shield_bash")
	var plan := Timeline.new()
	plan.add(plan_ability(2, bash, Vector2i(3, 2), 1))
	var result: SimResult = simulate_player_turn(board, plan)
	var knight: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "kinetic_converter/str",
		knight != null and has_status(knight, GameEnums.StatusType.STAT_BUFF_STR),
		"being hit must grant STR buff via Kinetic Converter",
	)
	assert_true(
		failures, "kinetic_converter/mov",
		knight != null and has_status(knight, GameEnums.StatusType.STAT_BUFF_MOV),
		"being hit must grant MOV buff via Kinetic Converter",
	)
	var cfg_up: Dictionary = with_single_passive(&"kinetic_converter", true)
	var board2: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board2, 10, Vector2i(3, 2), cfg_up)
	soften_for_melee_hit(unit_on_board(board2, 10))
	place_enemy_basher(board2, 11, Vector2i(4, 2))
	boost_striker(unit_on_board(board2, 11))
	var bash2: AbilityData = ability_on_unit(unit_on_board(board2, 11), &"knight_shield_bash")
	var plan2 := Timeline.new()
	plan2.add(plan_ability(11, bash2, Vector2i(3, 2), 10))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var knight2: UnitState = result2.final_state.get_unit_by_id(10)
	var str_amt: int = 0
	for s: StatusData in knight2.active_statuses if knight2 else []:
		if s.type == GameEnums.StatusType.STAT_BUFF_STR:
			str_amt = s.value
	assert_true(
		failures, "kinetic_converter/upgrade/str2",
		knight2 != null and str_amt >= 2,
		"upgraded kinetic converter must grant +2 STR when hit",
	)


static func run_kinetic_redirection(failures: Array[String]) -> void:
	assert_passive_registered(failures, &"kinetic_redirection")


static func run_rallying_presence(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = with_single_passive(&"rallying_presence", false)
	place_knight(board, 1, Vector2i(3, 3), cfg)
	var ally_def: UnitData = knight_unit_data()
	place_unit(board, 3, ally_def, GameEnums.Team.PLAYER, Vector2i(3, 4), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var plan := Timeline.new()
	var result: SimResult = simulate_player_turn(board, plan)
	var ally: UnitState = result.final_state.get_unit_by_id(3)
	assert_true(
		failures, "rallying_presence/mov_buff",
		ally != null and has_status(ally, GameEnums.StatusType.STAT_BUFF_MP),
		"adjacent ally must gain MOV at turn start via Rallying Presence",
	)
	var cfg_up: Dictionary = with_single_passive(&"rallying_presence", true)
	var board2: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board2, 10, Vector2i(3, 3), cfg_up)
	var ally_def2: UnitData = knight_unit_data()
	place_unit(board2, 11, ally_def2, GameEnums.Team.PLAYER, Vector2i(3, 4), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var plan2 := Timeline.new()
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var ally2: UnitState = result2.final_state.get_unit_by_id(11)
	var mov_amt: int = 0
	for s: StatusData in ally2.active_statuses if ally2 else []:
		if s.type == GameEnums.StatusType.STAT_BUFF_MP:
			mov_amt = s.value
	assert_true(
		failures, "rallying_presence/upgrade/mov2",
		ally2 != null and mov_amt >= 2,
		"upgraded rallying presence must grant +2 MOV",
	)


static func run_shield_wall(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = with_single_passive(&"shield_wall", false)
	place_knight(board, 1, Vector2i(3, 3), cfg)
	var ally_def: UnitData = knight_unit_data()
	var ally: UnitState = place_unit(board, 3, ally_def, GameEnums.Team.PLAYER, Vector2i(4, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var base_def: int = ally.current_defense
	var with_aura: int = CombatSystem.get_dynamic_defense(board, ally)
	assert_true(
		failures, "shield_wall/ally_def",
		with_aura > base_def,
		"adjacent ally must gain DEF from Shield Wall aura",
	)


static func run_intercept_tactics(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = with_single_passive(&"intercept_tactics", false)
	place_knight(board, 1, Vector2i(3, 3), cfg)
	var knight: UnitState = unit_on_board(board, 1)
	var redirect: AbilityData = ability_on_unit(knight, &"knight_redirect_strike")
	var plan := Timeline.new()
	plan.add(plan_ability(1, redirect, knight.position, knight.id))
	var result: SimResult = simulate_player_turn(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "intercept_tactics/def_buff",
		after != null and has_status(after, GameEnums.StatusType.STAT_BUFF_DEF),
		"redirect skill must grant DEF via Intercept Tactics",
	)
	var cfg_up: Dictionary = with_single_passive(&"intercept_tactics", true)
	var board2: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board2, 10, Vector2i(3, 3), cfg_up)
	var knight2: UnitState = unit_on_board(board2, 10)
	var redirect2: AbilityData = ability_on_unit(knight2, &"knight_redirect_strike")
	var plan2 := Timeline.new()
	plan2.add(plan_ability(10, redirect2, knight2.position, knight2.id))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var after2: UnitState = result2.final_state.get_unit_by_id(10)
	var def_amt: int = 0
	for s: StatusData in after2.active_statuses if after2 else []:
		if s.type == GameEnums.StatusType.STAT_BUFF_DEF:
			def_amt = s.value
	assert_true(
		failures, "intercept_tactics/upgrade/def3",
		after2 != null and def_amt >= 3,
		"upgraded intercept tactics must grant +3 DEF on redirect",
	)


static func place_enemy_artillery(board: BoardState, unit_id: int, pos: Vector2i) -> UnitState:
	var def: UnitData = DataLibrary.get_unit(&"artillery")
	if def == null:
		def = DataLibrary.get_training_dummy()
	var abilities: Array[AbilityData] = []
	if def.behavior != null and def.behavior.default_ability != null:
		abilities.append(def.behavior.default_ability)
	return place_unit(board, unit_id, def, GameEnums.Team.ENEMY, pos, {
		"active_abilities": abilities if not abilities.is_empty() else [factory_ability(&"knight_chain_hook")],
	})


static func events_contain_reason(events: Array, reason: String) -> bool:
	for e: Variant in events:
		if e is SimEvent and str(e.data.get("reason", "")) == reason:
			return true
	return false


static func events_have_terrain_changed(events: Array, coord: Vector2i) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.TERRAIN_CHANGED:
			var c: Variant = e.data.get("coord", null)
			if c is Vector2i and c == coord:
				return true
	return false


static func events_have_status_on_unit(
	events: Array,
	unit_id: int,
	status_type: GameEnums.StatusType,
) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.STATUS_APPLIED:
			if int(e.data.get("unit", -1)) == unit_id and e.data.get("status_type") == status_type:
				return true
	return false


static func grant_extra_ap(unit: UnitState, extra: int) -> void:
	if unit == null or extra <= 0:
		return
	unit.ability.max_points += extra
	unit.ability.points_left += extra


static func run_phalanx_stance(failures: Array[String]) -> void:
	run_self_buff(failures, &"knight_phalanx_stance", GameEnums.StatusType.STURDY)
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = with_upgraded_ability({}, &"knight_phalanx_stance")
	place_knight(board, 1, Vector2i(3, 3), cfg)
	var knight: UnitState = unit_on_board(board, 1)
	var ability: AbilityData = ability_on_unit(knight, &"knight_phalanx_stance")
	var plan := Timeline.new()
	plan.add(plan_ability(1, ability, knight.position, knight.id))
	var result: SimResult = simulate_player_turn(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "phalanx_stance/upgrade/infinite_range",
		after != null and has_status(after, GameEnums.StatusType.RETALIATION_INFINITE_RANGE),
		"upgraded phalanx must grant infinite retaliation range",
	)


static func run_taunting_strike(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(10, 6))
	place_knight(board, 1, Vector2i(3, 3))
	place_dummy(board, 2, Vector2i(5, 3))
	var knight: UnitState = unit_on_board(board, 1)
	var strike: AbilityData = ability_on_unit(knight, &"knight_taunting_strike")
	var hp_before: int = unit_on_board(board, 2).health.current_hp
	var plan := Timeline.new()
	plan.add(plan_ability(1, strike, Vector2i(5, 3), 2))
	var result: SimResult = simulate_player_turn(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "taunting_strike/damage",
		enemy != null and enemy.health.current_hp < hp_before,
		"taunting strike must deal damage",
	)
	assert_true(
		failures, "taunting_strike/taunt",
		enemy != null and has_status(enemy, GameEnums.StatusType.TAUNT),
		"taunting strike must apply TAUNT",
	)
	var cfg_up: Dictionary = with_upgraded_ability({}, &"knight_taunting_strike")
	var board2: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board2, 10, Vector2i(3, 4), cfg_up)
	place_dummy(board2, 11, Vector2i(6, 4))
	var strike_up: AbilityData = ability_on_unit(unit_on_board(board2, 10), &"knight_taunting_strike")
	assert_true(
		failures, "taunting_strike/upgrade/pull2",
		ability_has_effect(strike_up, GameEnums.EffectType.PULL, true)
		and strike_up.upgraded_effects[1].amount == 2,
		"upgraded taunting strike must PULL 2",
	)


static func run_seismic_stomp(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board, 1, Vector2i(4, 4))
	place_dummy(board, 2, Vector2i(5, 4))
	var stomp: AbilityData = ability_on_unit(unit_on_board(board, 1), &"knight_seismic_stomp")
	var hp_before: int = unit_on_board(board, 2).health.current_hp
	var plan := Timeline.new()
	plan.add(plan_ability(1, stomp, Vector2i(4, 4), 1))
	var result: SimResult = simulate_player_turn(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "seismic_stomp/aoe_damage",
		enemy != null and enemy.health.current_hp < hp_before,
		"seismic stomp AOE must damage adjacent enemy",
	)
	var cfg_up: Dictionary = with_upgraded_ability({}, &"knight_seismic_stomp")
	var board2: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board2, 10, Vector2i(4, 4), cfg_up)
	place_dummy(board2, 11, Vector2i(5, 4))
	var stomp_up: AbilityData = ability_on_unit(unit_on_board(board2, 10), &"knight_seismic_stomp")
	var plan2 := Timeline.new()
	plan2.add(plan_ability(10, stomp_up, Vector2i(4, 4), 10))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	assert_true(
		failures, "seismic_stomp/upgrade/cracked",
		events_have_terrain_changed(result2.events, Vector2i(5, 4)),
		"upgraded seismic stomp must create CRACKED terrain in AOE",
	)


static func run_fortify(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board, 1, Vector2i(3, 3))
	var ally_def: UnitData = knight_unit_data()
	place_unit(board, 3, ally_def, GameEnums.Team.PLAYER, Vector2i(4, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var fortify: AbilityData = ability_on_unit(unit_on_board(board, 1), &"knight_fortify")
	var plan := Timeline.new()
	plan.add(plan_ability(1, fortify, Vector2i(4, 3), 3))
	var result: SimResult = simulate_player_turn(board, plan)
	var ally: UnitState = result.final_state.get_unit_by_id(3)
	assert_true(
		failures, "fortify/ally_def",
		ally != null and has_status(ally, GameEnums.StatusType.STAT_BUFF_DEF),
		"fortify must buff ally DEF",
	)
	var cfg_up: Dictionary = with_upgraded_ability({}, &"knight_fortify")
	var board2: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board2, 10, Vector2i(3, 3), cfg_up)
	var ally_def2: UnitData = knight_unit_data()
	place_unit(board2, 11, ally_def2, GameEnums.Team.PLAYER, Vector2i(4, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var fortify_up: AbilityData = ability_on_unit(unit_on_board(board2, 10), &"knight_fortify")
	var plan2 := Timeline.new()
	plan2.add(plan_ability(10, fortify_up, Vector2i(4, 3), 11))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var ally2: UnitState = result2.final_state.get_unit_by_id(11)
	assert_true(
		failures, "fortify/upgrade/thorns",
		ally2 != null and has_status(ally2, GameEnums.StatusType.THORNS),
		"upgraded fortify must grant THORNS to ally",
	)


static func run_bowling_charge(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(12, 6))
	place_knight(board, 1, Vector2i(2, 3))
	place_dummy(board, 2, Vector2i(3, 3))
	var charge: AbilityData = ability_on_unit(unit_on_board(board, 1), &"knight_bowling_charge")
	var plan := Timeline.new()
	plan.add(plan_ability(1, charge, Vector2i(5, 3), -1))
	var result: SimResult = simulate_player_turn(board, plan)
	var knight: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "bowling_charge/dash",
		knight != null and knight.position == Vector2i(5, 3),
		"bowling charge must DASH to target tile",
	)


static func run_iron_grip(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(10, 6))
	place_knight(board, 1, Vector2i(3, 3))
	place_dummy(board, 2, Vector2i(4, 3))
	var grip: AbilityData = ability_on_unit(unit_on_board(board, 1), &"knight_iron_grip")
	var plan := Timeline.new()
	plan.add(plan_ability(1, grip, Vector2i(4, 3), 2))
	var result: SimResult = simulate_player_turn(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "iron_grip/root",
		enemy != null and has_status(enemy, GameEnums.StatusType.ROOT),
		"iron grip must ROOT target",
	)
	var cfg_up: Dictionary = with_upgraded_ability({}, &"knight_iron_grip")
	var board2: BoardState = make_plain_board(Vector2i(10, 6))
	place_knight(board2, 10, Vector2i(3, 3), cfg_up)
	place_dummy(board2, 11, Vector2i(4, 3))
	var enemy_pre: UnitState = unit_on_board(board2, 11)
	enemy_pre.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.ROOT, 1, 0))
	enemy_pre._recalculate_stats()
	var grip_up: AbilityData = ability_on_unit(unit_on_board(board2, 10), &"knight_iron_grip")
	var knight_before: UnitState = unit_on_board(board2, 10)
	var ap_before: int = knight_before.ability.points_left
	var plan2 := Timeline.new()
	plan2.add(plan_ability(10, grip_up, Vector2i(4, 3), 11))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var knight_after: UnitState = result2.final_state.get_unit_by_id(10)
	assert_true(
		failures, "iron_grip/upgrade/ap_refund",
		knight_after != null and knight_after.ability.points_left == ap_before,
		"upgraded iron grip must refund 1 AP when target already has ROOT/STAGGER",
	)


static func run_shield_slam(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(10, 6))
	place_knight(board, 1, Vector2i(4, 3))
	place_dummy(board, 2, Vector2i(5, 3))
	var slam: AbilityData = ability_on_unit(unit_on_board(board, 1), &"knight_shield_slam")
	var hp_before: int = unit_on_board(board, 2).health.current_hp
	var plan := Timeline.new()
	plan.add(TimelineAction.make_move(1, Vector2i(4, 3)))
	plan.add(plan_ability(1, slam, Vector2i(5, 3), 2))
	var result: SimResult = simulate_player_turn(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "shield_slam/damage",
		enemy != null and enemy.health.current_hp < hp_before,
		"shield slam must deal damage",
	)
	assert_eq_cell(failures, "shield_slam/push", enemy.position, Vector2i(7, 3))
	var cfg_up: Dictionary = with_upgraded_ability({}, &"knight_shield_slam")
	var board2: BoardState = make_plain_board(Vector2i(10, 6))
	place_knight(board2, 10, Vector2i(4, 3), cfg_up)
	place_dummy(board2, 11, Vector2i(5, 3))
	var slam_up: AbilityData = ability_on_unit(unit_on_board(board2, 10), &"knight_shield_slam")
	var plan2 := Timeline.new()
	plan2.add(TimelineAction.make_move(10, Vector2i(4, 3)))
	plan2.add(plan_ability(10, slam_up, Vector2i(5, 3), 11))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	assert_true(
		failures, "shield_slam/upgrade/def_debuff",
		events_have_status_on_unit(
			result2.events, 11, GameEnums.StatusType.STAT_DEBUFF_DEF,
		),
		"upgraded shield slam must apply DEF debuff before damage",
	)


static func run_defensive_formation(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board, 1, Vector2i(4, 4))
	var ally_def: UnitData = knight_unit_data()
	place_unit(board, 3, ally_def, GameEnums.Team.PLAYER, Vector2i(5, 4), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var form: AbilityData = ability_on_unit(unit_on_board(board, 1), &"knight_defensive_formation")
	var plan := Timeline.new()
	plan.add(plan_ability(1, form, Vector2i(4, 4), 1))
	var result: SimResult = simulate_player_turn(board, plan)
	var ally: UnitState = result.final_state.get_unit_by_id(3)
	assert_true(
		failures, "defensive_formation/ally_sturdy",
		ally != null and has_status(ally, GameEnums.StatusType.STURDY),
		"defensive formation AOE must grant STURDY to nearby ally",
	)
	var cfg_up: Dictionary = with_upgraded_ability({}, &"knight_defensive_formation")
	var board2: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board2, 10, Vector2i(4, 4), cfg_up)
	var ally_def2: UnitData = knight_unit_data()
	place_unit(board2, 11, ally_def2, GameEnums.Team.PLAYER, Vector2i(5, 4), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var form_up: AbilityData = ability_on_unit(unit_on_board(board2, 10), &"knight_defensive_formation")
	var ally_armor_before: int = unit_on_board(board2, 11).armor
	var plan2 := Timeline.new()
	plan2.add(plan_ability(10, form_up, Vector2i(4, 4), 10))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var ally2: UnitState = result2.final_state.get_unit_by_id(11)
	assert_true(
		failures, "defensive_formation/upgrade/armor_up",
		ally2 != null and ally2.armor > ally_armor_before,
		"upgraded defensive formation must grant ARMOR_UP shield to ally",
	)


static func run_indomitable_will(failures: Array[String]) -> void:
	run_self_buff(failures, &"knight_indomitable_will", GameEnums.StatusType.INDOMITABLE_WILL)
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = with_upgraded_ability({}, &"knight_indomitable_will")
	place_knight(board, 1, Vector2i(3, 3), cfg)
	var knight: UnitState = unit_on_board(board, 1)
	var ability: AbilityData = ability_on_unit(knight, &"knight_indomitable_will")
	var plan := Timeline.new()
	plan.add(plan_ability(1, ability, knight.position, knight.id))
	var result: SimResult = simulate_player_turn(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "indomitable_will/upgrade/status",
		after != null and has_status(after, GameEnums.StatusType.INDOMITABLE_WILL_UPGRADED),
		"upgraded indomitable will must apply INDOMITABLE_WILL_UPGRADED",
	)


static func run_retaliation_protocol(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(8, 5))
	var cfg: Dictionary = {}
	place_knight(board, 1, Vector2i(3, 2), cfg)
	var protocol: AbilityData = ability_on_unit(unit_on_board(board, 1), &"knight_retaliation_protocol")
	var plan := Timeline.new()
	plan.add(plan_ability(1, protocol, Vector2i(3, 2), 1))
	simulate_player_turn(board, plan)
	soften_for_melee_hit(unit_on_board(board, 1))
	place_enemy_basher(board, 2, Vector2i(4, 2))
	var bash: AbilityData = ability_on_unit(unit_on_board(board, 2), &"knight_shield_bash")
	var hp_before: int = unit_on_board(board, 2).health.current_hp
	var attack := Timeline.new()
	attack.add(plan_ability(2, bash, Vector2i(3, 2), 1))
	var result: SimResult = simulate_player_turn(board, attack)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "retaliation_protocol/counter",
		enemy != null and enemy.health.current_hp < hp_before,
		"retaliation protocol must counter-attack melee attacker",
	)
	var cfg_up: Dictionary = with_upgraded_ability({}, &"knight_retaliation_protocol")
	var board2: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board2, 10, Vector2i(3, 2), cfg_up)
	var protocol_up: AbilityData = ability_on_unit(unit_on_board(board2, 10), &"knight_retaliation_protocol")
	var plan2 := Timeline.new()
	plan2.add(plan_ability(10, protocol_up, Vector2i(3, 2), 10))
	simulate_player_turn(board2, plan2)
	soften_for_melee_hit(unit_on_board(board2, 10))
	place_enemy_basher(board2, 11, Vector2i(4, 2))
	var bash2: AbilityData = ability_on_unit(unit_on_board(board2, 11), &"knight_shield_bash")
	var pos_before: Vector2i = unit_on_board(board2, 11).position
	var attack2 := Timeline.new()
	attack2.add(plan_ability(11, bash2, Vector2i(3, 2), 10))
	var result2: SimResult = simulate_player_turn(board2, attack2)
	var enemy2: UnitState = result2.final_state.get_unit_by_id(11)
	assert_true(
		failures, "retaliation_protocol/upgrade/push",
		enemy2 != null and enemy2.position != pos_before,
		"upgraded retaliation protocol must PUSH counter-attack target",
	)


static func run_living_barricade(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = with_single_passive(&"living_barricade", false)
	place_knight(board, 1, Vector2i(4, 3), cfg)
	var ally_def: UnitData = knight_unit_data()
	place_unit(board, 2, ally_def, GameEnums.Team.PLAYER, Vector2i(3, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	place_enemy_artillery(board, 3, Vector2i(6, 3))
	var artillery: UnitState = unit_on_board(board, 3)
	var bolt: AbilityData = artillery.active_abilities[0]
	var hp_before: int = unit_on_board(board, 2).health.current_hp
	var plan := Timeline.new()
	plan.add(plan_ability(3, bolt, Vector2i(3, 3), 2))
	var result: SimResult = simulate_player_turn(board, plan)
	var ally: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "living_barricade/block",
		ally != null and ally.health.current_hp == hp_before,
		"ranged shot on protected ally must be blocked",
	)
	assert_true(
		failures, "living_barricade/event",
		events_contain_reason(result.events, "blocked_by_living_barricade"),
		"living barricade must emit block event",
	)
