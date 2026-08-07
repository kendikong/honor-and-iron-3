class_name BruiserQaHarness
extends RefCounted

## Bruiser class QA harness â€” separate from planning QA (`run_planning_qa_gate.ps1`).
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
	var template: UnitData = DataLibrary.get_unit(BRUISER_DEF_ID)
	if template == null:
		return null
	var weapon: WeaponData = template.equipped_weapon
	if weapon == null:
		return template
	return BruiserFactory.build(weapon)


static func ability_has_status_effect(
	ability: AbilityData,
	status_type: GameEnums.StatusType,
	upgraded: bool = false,
) -> bool:
	if ability == null:
		return false
	var effects: Array[AbilityModule] = ability.upgraded_modules if upgraded else ability.modules
	for eff: AbilityModule in effects:
		if eff == null:
			continue
		if eff.primary_type in [GameEnums.EffectType.ADD_STATUS, GameEnums.EffectType.ADD_STATUS_SELF]:
			if eff.status_type == status_type:
				return true
	return false


static func run_active_smoke(
	failures: Array[String],
	ability_id: StringName,
	bible_line: String,
	effect_types: Array = [],
	status_types: Array = [],
) -> void:
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
	if ability.upgraded_modules.size() > 0:
		assert_true(
			failures, "%s/upgrade_data" % ability_id,
			ability.upgrade_description.length() > 0,
			"upgraded_modules require upgrade_description",
		)


static func bruiser_with_ability(ability_id: StringName, upgraded: bool = false) -> Dictionary:
	var cfg: Dictionary = {
		"active_abilities": [
			DataLibrary.get_universal_run(),
			factory_ability(ability_id),
		],
	}
	if upgraded:
		cfg = with_upgraded_ability(cfg, ability_id)
	return cfg


static func enemy_hp_before_attack(
	board: BoardState,
	enemy_id: int,
	ability_id: StringName,
	target_cell: Vector2i,
	upgraded: bool = false,
) -> int:
	var cfg: Dictionary = bruiser_with_ability(ability_id, upgraded)
	place_bruiser(board, 1, Vector2i(2, 3), cfg)
	place_dummy(board, enemy_id, target_cell)
	return unit_hp(board, enemy_id)


static func cast_on_enemy(
	board: BoardState,
	ability_id: StringName,
	bruiser_pos: Vector2i,
	enemy_id: int,
	enemy_pos: Vector2i,
	upgraded: bool = false,
) -> SimResult:
	var cfg: Dictionary = bruiser_with_ability(ability_id, upgraded)
	place_bruiser(board, 1, bruiser_pos, cfg)
	place_dummy(board, enemy_id, enemy_pos)
	var ability: AbilityData = ability_on_unit(unit_on_board(board, 1), ability_id)
	var plan := Timeline.new()
	plan.add(plan_ability(1, ability, enemy_pos, enemy_id))
	return simulate_plan(board, plan)


static func events_have_type(events: Array, event_type: GameEnums.SimEventType) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == event_type:
			return true
	return false


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
	if config.has("passive_flags"):
		for key: Variant in config.passive_flags.keys():
			unit.passive_flags[key] = config.passive_flags[key]
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
	var effects: Array[AbilityModule] = ability.upgraded_modules if upgraded else ability.modules
	for eff: AbilityModule in effects:
		if eff != null and eff.primary_type == effect_type:
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
	module_coords: Array[Vector2i] = [],
) -> TimelineAction:
	var action: TimelineAction = TimelineAction.make_ability(
		actor_id, ability, target, target_unit_id, timing,
	)
	if not module_coords.is_empty():
		action.module_coords = module_coords.duplicate()
	elif target != Vector2i.ZERO:
		action.module_coords = [target]
	return action


static func events_have_unit_pushed(events: Array, unit_id: int) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.UNIT_PUSHED:
			if int(e.data.get("unit", -1)) == unit_id:
				return true
	return false


static func event_push_distance(events: Array, unit_id: int) -> int:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.UNIT_PUSHED:
			if int(e.data.get("unit", -1)) == unit_id:
				return int(e.data.get("distance", -1))
	return -1


static func events_have_unit_damaged_pierce(events: Array, pierce: bool) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.UNIT_DAMAGED:
			if bool(e.data.get("pierce", false)) == pierce:
				return true
	return false


static func events_have_damage_pierce(events: Array, pierce: bool) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.MATH_TELEMETRY:
			var d: Dictionary = e.data
			if str(d.get("type", "")) == "damage" and bool(d.get("pierce", false)) == pierce:
				return true
	return false


static func first_damage_math(events: Array) -> Dictionary:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.MATH_TELEMETRY:
			var d: Dictionary = e.data
			if str(d.get("type", "")) == "damage":
				return d
	return {}


static func events_have_terrain_changed(events: Array, coord: Vector2i) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.TERRAIN_CHANGED:
			if e.data.get("coord", Vector2i(-99, -99)) == coord:
				return true
	return false


static func count_unit_hp_damage_events(events: Array, unit_id: int) -> int:
	var count: int = 0
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.UNIT_DAMAGED:
			if int(e.data.get("unit", -1)) != unit_id:
				continue
			var hp_dmg: int = int(e.data.get("hp_damaged", e.data.get("amount", 0)))
			if hp_dmg > 0:
				count += 1
	return count


static func sum_unit_hp_damage_events(events: Array, unit_id: int) -> int:
	var total: int = 0
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.UNIT_DAMAGED:
			if int(e.data.get("unit", -1)) != unit_id:
				continue
			var hp_dmg: int = int(e.data.get("hp_damaged", e.data.get("amount", 0)))
			if hp_dmg > 0:
				total += hp_dmg
	return total


static func sum_unit_incoming_damage_events(events: Array, unit_id: int) -> int:
	var total: int = 0
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.UNIT_DAMAGED:
			if int(e.data.get("unit", -1)) != unit_id:
				continue
			total += int(e.data.get("amount", 0))
	return total


static func damage_dealt_to_unit(board: BoardState, unit_id: int, raw_amount: int, attacker: UnitState = null) -> int:
	var target: UnitState = board.get_unit_by_id(unit_id)
	if target == null or target.health == null:
		return 0
	var hp_before: int = target.health.current_hp
	var events: Array[SimEvent] = []
	CombatSystem.deal_damage(
		board, target, raw_amount, events, &"physical", false, false, attacker, "bruiser_qa",
	)
	return hp_before - target.health.current_hp


static func set_tile_trap(board: BoardState, coord: Vector2i) -> void:
	var trap := TerrainData.new()
	trap.id = &"trap"
	trap.display_name = "Trap"
	trap.hazard_damage = 5
	trap.blocks_movement = false
	board.tiles[coord] = TileState.create(coord, trap)


static func set_tile_terrain(board: BoardState, coord: Vector2i, terrain_id: StringName) -> void:
	var def: TerrainData = DataLibrary.get_terrain(terrain_id)
	if def == null:
		var custom := TerrainData.new()
		custom.id = terrain_id
		custom.blocks_movement = false
		custom.stops_displacement = false
		board.tiles[coord] = TileState.create(coord, custom)
	else:
		board.tiles[coord] = TileState.create(coord, def)


static func status_value(unit: UnitState, status_type: GameEnums.StatusType) -> int:
	if unit == null:
		return 0
	for status: StatusData in unit.active_statuses:
		if status.type == status_type:
			return status.value
	return 0


static func bruiser_with_abilities(ability_ids: Array, upgraded: Dictionary = {}) -> Dictionary:
	var abilities: Array = [DataLibrary.get_universal_run()]
	for id: Variant in ability_ids:
		var ab: AbilityData = factory_ability(id as StringName)
		if ab != null:
			abilities.append(ab)
	var cfg: Dictionary = {"active_abilities": abilities}
	for up_id: Variant in upgraded.keys():
		if bool(upgraded[up_id]):
			cfg = with_upgraded_ability(cfg, up_id as StringName)
	return cfg


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
	assert_true(
		failures, "push_through/not_swap",
		not ability_has_effect(push, GameEnums.EffectType.SWAP, false),
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
	for e in result.events:
		if e is SimEvent:
			print("EVENT: ", e.primary_type, " ", e.data)
	assert_true(
		failures, "push_through/pushed_event",
		events_have_unit_pushed(result.events, 2),
	)
	assert_eq_int(
		failures, "push_through/push_distance",
		event_push_distance(result.events, 2),
		1,
	)
	assert_eq_int(
		failures, "push_through/mp_spent",
		mp_before - b_after.movement.points_left,
		2,
	)
	assert_true(
		failures, "push_through/base_no_str_buff",
		not has_status(b_after, GameEnums.StatusType.STAT_BUFF_STR),
		"base tier must not grant STR buff_on_push",
	)


static func run_push_through_blocked(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(8, 8), [Vector2i(3, 5)])
	var cfg: Dictionary = with_upgraded_ability({
		"active_abilities": [
			DataLibrary.get_universal_run(),
			factory_ability(&"bruiser_push_through"),
		],
	}, &"bruiser_push_through")
	place_bruiser(board, 1, Vector2i(3, 3), cfg)
	place_dummy(board, 2, Vector2i(3, 4))
	var push: AbilityData = ability_on_unit(unit_on_board(board, 1), &"bruiser_push_through")
	var plan := Timeline.new()
	plan.add(plan_ability(1, push, Vector2i(3, 4), 2, GameEnums.MoveTiming.PRE_ACTION))
	var result: SimResult = simulate_plan(board, plan)
	var b_after: UnitState = result.final_state.get_unit_by_id(1)
	var e_after: UnitState = result.final_state.get_unit_by_id(2)
	assert_eq_cell(failures, "push_through/blocked_bruiser_pos", b_after.position, Vector2i(3, 3))
	assert_eq_cell(failures, "push_through/blocked_enemy_pos", e_after.position, Vector2i(3, 4))
	assert_true(
		failures, "push_through/blocked_no_push_event",
		not events_have_unit_pushed(result.events, 2),
		"wall-blocked push must not emit UNIT_PUSHED",
	)
	assert_true(
		failures, "push_through/blocked_no_str_buff",
		not has_status(b_after, GameEnums.StatusType.STAT_BUFF_STR),
		"blocked push must not grant buff_on_push without displacement",
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
		push.upgraded_modules[0].legacy_modifiers.has("buff_on_push"),
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
		failures, "push_through/upgrade_str_value",
		status_value(b_after, GameEnums.StatusType.STAT_BUFF_STR),
		1,
	)
	assert_eq_int(
		failures, "push_through/upgrade_mp_spent",
		mp_before - b_after.movement.points_left,
		1,
	)


static func run_push_through_non_adjacent(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	place_bruiser(board, 1, Vector2i(3, 3), {
		"active_abilities": [
			DataLibrary.get_universal_run(),
			factory_ability(&"bruiser_push_through"),
		],
	})
	place_dummy(board, 2, Vector2i(3, 5))
	var push: AbilityData = ability_on_unit(unit_on_board(board, 1), &"bruiser_push_through")
	var plan := Timeline.new()
	plan.add(plan_ability(1, push, Vector2i(3, 5), 2, GameEnums.MoveTiming.PRE_ACTION))
	var result: SimResult = simulate_plan(board, plan)
	var b_after: UnitState = result.final_state.get_unit_by_id(1)
	var e_after: UnitState = result.final_state.get_unit_by_id(2)
	assert_eq_cell(failures, "push_through/non_adjacent_bruiser", b_after.position, Vector2i(3, 3))
	assert_eq_cell(failures, "push_through/non_adjacent_enemy", e_after.position, Vector2i(3, 5))
	assert_true(
		failures, "push_through/non_adjacent_no_push",
		not events_have_unit_pushed(result.events, 2),
		"Push Through requires adjacent occupied tile",
	)


static func run_push_through_upgrade_next_attack(failures: Array[String]) -> void:
	var cleave: AbilityData = factory_ability(&"bruiser_cleave")
	var cfg: Dictionary = with_upgraded_ability({
		"active_abilities": [
			DataLibrary.get_universal_run(),
			factory_ability(&"bruiser_push_through"),
			cleave,
		],
	}, &"bruiser_push_through")
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	place_bruiser(board, 1, Vector2i(3, 3), cfg)
	place_dummy(board, 2, Vector2i(3, 4))
	var hp_enemy: int = unit_hp(board, 2)
	var push: AbilityData = ability_on_unit(unit_on_board(board, 1), &"bruiser_push_through")
	var plan := Timeline.new()
	plan.add(plan_ability(1, push, Vector2i(3, 4), 2, GameEnums.MoveTiming.PRE_ACTION))
	plan.add(plan_ability(1, cleave, Vector2i(3, 5), 2))
	var result: SimResult = simulate_plan(board, plan)
	var dmg_buffed: int = hp_enemy - unit_hp(result.final_state, 2)
	var board_base: BoardState = make_plain_board(Vector2i(8, 8))
	place_bruiser(board_base, 10, Vector2i(3, 3), {"active_abilities": [DataLibrary.get_universal_run(), cleave]})
	place_dummy(board_base, 11, Vector2i(3, 4))
	var hp_base: int = unit_hp(board_base, 11)
	var plan_base := Timeline.new()
	plan_base.add(plan_ability(10, cleave, Vector2i(3, 4), 11))
	var result_base: SimResult = simulate_plan(board_base, plan_base)
	var dmg_base: int = hp_base - unit_hp(result_base.final_state, 11)
	var bruiser_after: UnitState = result.final_state.get_unit_by_id(1)
	var base_cleave_power: int = cleave.modules[0].amount
	var expected_delta: int = (
		CombatSystem.calculate_scaled_damage(bruiser_after, base_cleave_power + 1, GameEnums.StatType.PHYSICAL, board)
		- CombatSystem.calculate_scaled_damage(bruiser_after, base_cleave_power, GameEnums.StatType.PHYSICAL, board)
	)
	assert_eq_int(
		failures, "push_through/upgrade_str_attack_delta",
		dmg_buffed - dmg_base,
		expected_delta,
	)
