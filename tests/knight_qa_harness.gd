class_name KnightQaHarness
extends RefCounted

## Knight class QA harness â€” separate from planning QA (`run_planning_qa_gate.ps1`).
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


static func library_ability_range_tiles(ability_id: StringName) -> int:
	var save: Dictionary = ClassLibrarySchema.read_editor_save()
	var knight: Dictionary = save.get("units", {}).get("knight", {})
	var abilities: Dictionary = knight.get("abilities", {})
	var ab_data: Dictionary = abilities.get(String(ability_id), {})
	return int(ab_data.get("range_tiles", -1))


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


static func events_have_collision_for_unit(events: Array, unit_id: int) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.COLLISION:
			if int(e.data.get("unit", -1)) == unit_id:
				return true
	return false


static func events_have_chain_collision(events: Array, pushed_id: int, against_id: int) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.COLLISION:
			var d: Dictionary = e.data
			if int(d.get("unit", -1)) == pushed_id and int(d.get("against_unit", -1)) == against_id:
				return true
	return false


static func events_have_unit_pushed(events: Array, unit_id: int) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.UNIT_PUSHED:
			if int(e.data.get("unit", -1)) == unit_id:
				return true
	return false


static func unit_hp(state: BoardState, unit_id: int) -> int:
	var unit: UnitState = state.get_unit_by_id(unit_id)
	if unit == null or unit.health == null:
		return -1
	return unit.health.current_hp


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
	var effects: Array[AbilityModule] = ability.upgraded_modules if upgraded else ability.modules
	for eff: AbilityModule in effects:
		if eff != null and eff.primary_type == effect_type:
			return true
	return false


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


## Minimal planning smoke: ability select + overlay wire on shared bash fixture.
static func wire_planning_board_with_ally(ally_pos: Vector2i) -> Dictionary:
	PlanningDragE2EHarness.cleanup_all()
	var fix: Dictionary = PlanningDragE2EHarness._planning_fixture(
		PlanningChecklistHarness.KNIGHT_START, PlanningChecklistHarness.ENEMY_POS,
	)
	var ally_def: UnitData = knight_unit_data()
	var ally: UnitState = UnitState.create(3, ally_def, GameEnums.Team.PLAYER, ally_pos)
	ally.active_abilities = [DataLibrary.get_universal_run()]
	fix.board.units.append(ally)
	GridSystem.set_occupant(fix.board, ally_pos, 3)
	fix.director.board = fix.board
	fix.director.base_board = fix.board.clone()
	fix.director.projected_state = fix.board.clone()
	fix.input.auto_use_skill_after_move = false
	fix["ally"] = ally
	return PlanningDragE2EHarness.wire_fixture(fix)


static func run_planning_select_smoke(
	failures: Array[String],
	ability_id: StringName,
	tag: String,
) -> void:
	PlanningDragE2EHarness.cleanup_all()
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	var idx: int = PlanningChecklistHarness.select_ability(fix, ability_id)
	assert_true(
		failures, "%s/planning/select" % tag,
		idx >= 0,
		"%s must be selectable on planning fixture" % ability_id,
	)
	if idx < 0:
		return
	var ability: AbilityData = fix.knight.active_abilities[idx]
	assert_true(
		failures, "%s/planning/ability_id" % tag,
		ability != null and ability.id == ability_id,
	)
	assert_true(
		failures, "%s/planning/overlay" % tag,
		fix.get("overlay") != null,
		"planning overlay must wire after ability select",
	)


## Planning commit smoke: select â†’ hover â†’ hover/click parity â†’ commit_no_jump (preview==commit).
static func run_planning_commit_smoke(
	failures: Array[String],
	ability_id: StringName,
	tag: String,
	commit_cell: Vector2i,
	use_ally_fixture: bool = false,
	ally_pos: Vector2i = Vector2i(-1, -1),
	enemy_pos: Vector2i = Vector2i(-999999, -999999),
	verify_no_jump: bool = true,
) -> void:
	PlanningDragE2EHarness.cleanup_all()
	var fix: Dictionary
	if use_ally_fixture and ally_pos.x >= 0:
		fix = wire_planning_board_with_ally(ally_pos)
	elif enemy_pos.x > -999000:
		fix = PlanningDragE2EHarness.wire_drag_fixture(
			PlanningChecklistHarness.KNIGHT_START, enemy_pos,
		)
	else:
		fix = PlanningChecklistHarness.wire_bash_board()
	fix.director.auto_run = true
	var idx: int = PlanningChecklistHarness.select_ability(fix, ability_id)
	assert_true(
		failures, "%s/planning/select" % tag,
		idx >= 0,
		"%s must be selectable on planning fixture" % ability_id,
	)
	if idx < 0:
		return
	var ability: AbilityData = fix.knight.active_abilities[idx]
	assert_true(
		failures, "%s/planning/ability_id" % tag,
		ability != null and ability.id == ability_id,
	)
	assert_true(
		failures, "%s/planning/overlay" % tag,
		fix.get("overlay") != null,
		"planning overlay must wire after ability select",
	)
	PlanningChecklistHarness.hover(fix, commit_cell)
	var hover_slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, commit_cell)
	if PlanningChecklistHarness._slots_invalid(hover_slots):
		assert_true(
			failures, "%s/planning/valid_slots" % tag,
			false,
			"invalid commit slots at %s for %s" % [commit_cell, ability_id],
		)
		return
	PlanningChecklistHarness.assert_slots_match_preview_commit(
		failures, "%s/planning/hover_click_parity" % tag, fix, commit_cell,
	)
	if verify_no_jump:
		PlanningChecklistHarness.assert_commit_no_jump(
			failures, "%s/planning/no_jump" % tag, fix, commit_cell,
		)


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
	if ability.upgraded_modules.size() > 0:
		assert_true(
			failures, "%s/upgrade_data" % ability_id,
			ability.upgrade_description.length() > 0,
			"upgraded_modules require upgrade_description",
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
	## Bible: +1 DEF per adjacent unit; [+] +1 STR per adjacent enemy.
	var cfg: Dictionary = with_single_passive(&"bulwark", false)
	var board_iso: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board_iso, 1, Vector2i(3, 3), cfg)
	var def_iso: int = CombatSystem.get_dynamic_defense(board_iso, unit_on_board(board_iso, 1))
	var board_adj: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board_adj, 10, Vector2i(3, 3), cfg)
	place_dummy(board_adj, 11, Vector2i(4, 3))
	place_knight(board_adj, 12, Vector2i(3, 4), cfg)
	var def_adj: int = CombatSystem.get_dynamic_defense(board_adj, unit_on_board(board_adj, 10))
	assert_eq_int(
		failures, "bulwark/def_per_adjacent",
		def_adj - def_iso,
		2,
	)
	var cfg_up: Dictionary = with_single_passive(&"bulwark", true)
	var board_str: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board_str, 20, Vector2i(3, 3), cfg_up)
	var str_iso: int = CombatSystem.get_dynamic_strength(board_str, unit_on_board(board_str, 20))
	place_dummy(board_str, 21, Vector2i(4, 3))
	place_dummy(board_str, 22, Vector2i(2, 3))
	var str_two_enemies: int = CombatSystem.get_dynamic_strength(
		board_str, unit_on_board(board_str, 20),
	)
	assert_eq_int(
		failures, "bulwark/upgrade/str_per_enemy",
		str_two_enemies - str_iso,
		2,
	)
	place_knight(board_str, 23, Vector2i(3, 4), cfg_up)
	var str_with_ally: int = CombatSystem.get_dynamic_strength(
		board_str, unit_on_board(board_str, 20),
	)
	assert_eq_int(
		failures, "bulwark/upgrade/ally_does_not_add_str",
		str_with_ally,
		str_two_enemies,
	)
	var loss_iso: int = damage_taken_on_unit(board_iso, 1, 12)
	var loss_adj: int = damage_taken_on_unit(board_adj, 10, 12)
	assert_true(
		failures, "bulwark/def_mitigates_damage",
		loss_adj < loss_iso,
		"bulwark DEF bonus must reduce incoming damage in CombatSystem.deal_damage",
	)
	var board_atk: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board_atk, 30, Vector2i(4, 4), cfg_up)
	place_dummy(board_atk, 31, Vector2i(3, 4))
	var bash_iso: AbilityData = ability_on_unit(unit_on_board(board_atk, 30), &"knight_shield_bash")
	var plan_iso := Timeline.new()
	plan_iso.add(plan_ability(30, bash_iso, Vector2i(3, 4), 31))
	var result_iso: SimResult = simulate_plan(board_atk, plan_iso)
	var floored_iso: int = events_max_damage_floored(result_iso.events)
	place_dummy(board_atk, 32, Vector2i(5, 4))
	place_dummy(board_atk, 33, Vector2i(4, 5))
	var bash_adj: AbilityData = ability_on_unit(unit_on_board(board_atk, 30), &"knight_shield_bash")
	var plan_adj := Timeline.new()
	plan_adj.add(plan_ability(30, bash_adj, Vector2i(3, 4), 31))
	var result_adj: SimResult = simulate_plan(board_atk, plan_adj)
	var floored_adj: int = events_max_damage_floored(result_adj.events)
	assert_true(
		failures, "bulwark/upgrade/str_increases_attack_damage",
		floored_adj > floored_iso,
		"upgraded bulwark STR from adjacent enemies must increase attack damage",
	)
	var board_base: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board_base, 40, Vector2i(4, 4), cfg)
	place_dummy(board_base, 41, Vector2i(3, 4))
	place_dummy(board_base, 42, Vector2i(5, 4))
	var bash_base: AbilityData = ability_on_unit(unit_on_board(board_base, 40), &"knight_shield_bash")
	var plan_base := Timeline.new()
	plan_base.add(plan_ability(40, bash_base, Vector2i(3, 4), 41))
	var result_base: SimResult = simulate_plan(board_base, plan_base)
	var floored_base_enemies: int = events_max_damage_floored(result_base.events)
	var board_base_iso: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board_base_iso, 50, Vector2i(4, 4), cfg)
	place_dummy(board_base_iso, 51, Vector2i(3, 4))
	var plan_base_iso := Timeline.new()
	plan_base_iso.add(
		plan_ability(50, ability_on_unit(unit_on_board(board_base_iso, 50), &"knight_shield_bash"), Vector2i(3, 4), 51),
	)
	var result_base_iso: SimResult = simulate_plan(board_base_iso, plan_base_iso)
	var floored_base_iso: int = events_max_damage_floored(result_base_iso.events)
	assert_eq_int(
		failures, "bulwark/base/no_str_from_enemies",
		floored_base_enemies,
		floored_base_iso,
	)


static func run_kinetic_armor(failures: Array[String]) -> void:
	## Bible: flat -1 damage while SHIELD active; [+] flat -2.
	var board_no: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board_no, 1, Vector2i(3, 2))
	var knight_no: UnitState = unit_on_board(board_no, 1)
	knight_no.armor = 10
	var loss_no_passive: int = damage_taken_pierce(board_no, 1, 12)
	var cfg: Dictionary = with_single_passive(&"kinetic_armor", false)
	var board: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board, 10, Vector2i(3, 2), cfg)
	var knight: UnitState = unit_on_board(board, 10)
	knight.armor = 10
	var loss_with: int = damage_taken_pierce(board, 10, 12)
	assert_eq_int(
		failures, "kinetic_armor/mitigate_one",
		loss_no_passive - loss_with,
		1,
	)
	var board_no_shield: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board_no_shield, 20, Vector2i(3, 2), cfg)
	var knight_bare: UnitState = unit_on_board(board_no_shield, 20)
	knight_bare.armor = 0
	var loss_bare: int = damage_taken_pierce(board_no_shield, 20, 12)
	var board_ref: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board_ref, 21, Vector2i(3, 2))
	var knight_ref: UnitState = unit_on_board(board_ref, 21)
	knight_ref.armor = 0
	var loss_ref: int = damage_taken_pierce(board_ref, 21, 12)
	assert_eq_int(
		failures, "kinetic_armor/no_shield_no_mitigate",
		loss_bare,
		loss_ref,
	)
	var board_hazard: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board_hazard, 30, Vector2i(3, 2), cfg)
	var knight_hz: UnitState = unit_on_board(board_hazard, 30)
	knight_hz.armor = 10
	var hp_hz_before: int = knight_hz.health.current_hp
	var hz_events: Array[SimEvent] = []
	CombatSystem.deal_damage(
		board_hazard, knight_hz, 12, hz_events, &"hazard", true, false, null, "knight_qa",
	)
	var loss_hazard: int = hp_hz_before - knight_hz.health.current_hp
	assert_eq_int(
		failures, "kinetic_armor/hazard_no_mitigate",
		loss_hazard,
		loss_no_passive,
	)
	var cfg_up: Dictionary = with_single_passive(&"kinetic_armor", true)
	var board_up: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board_up, 40, Vector2i(3, 2), cfg_up)
	var knight_up: UnitState = unit_on_board(board_up, 40)
	knight_up.armor = 10
	var loss_up: int = damage_taken_pierce(board_up, 40, 12)
	assert_eq_int(
		failures, "kinetic_armor/upgrade/mitigate_two",
		loss_no_passive - loss_up,
		2,
	)
	assert_true(
		failures, "kinetic_armor/upgrade/better_than_base",
		loss_up < loss_with,
		"upgraded kinetic armor must mitigate more than base",
	)


static func run_indestructible_bastion(failures: Array[String]) -> void:
	## Indestructible Bastion: lethal -> 1 HP + SHIELD = DEF (once).
	var board: BoardState = make_plain_board(Vector2i(8, 5))
	var cfg: Dictionary = with_single_passive(&"indestructible_bastion", false)
	place_knight(board, 1, Vector2i(3, 2), cfg)
	var knight: UnitState = unit_on_board(board, 1)
	knight.health.current_hp = 3
	soften_for_melee_hit(knight)
	var def_at_trigger: int = knight.current_defense
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
	assert_true(
		failures, "indestructible_bastion/shield_def",
		after != null and after.armor >= def_at_trigger,
		"bastion must grant SHIELD equal to DEF on lethal trigger",
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
	var trample_data: AbilityData = factory_ability(&"knight_trampling_advance")
	assert_true(
		failures, "trample/contract/move",
		ability_has_effect(trample_data, GameEnums.EffectType.MOVE, false),
	)
	assert_true(
		failures, "trample/contract/trample",
		ability_has_effect(trample_data, GameEnums.EffectType.TRAMPLE, false),
	)
	assert_true(
		failures, "trample/contract/push",
		ability_has_effect(trample_data, GameEnums.EffectType.PUSH, false),
	)
	var board: BoardState = make_plain_board(Vector2i(12, 8))
	place_knight(board, 1, Vector2i(4, 4))
	place_dummy(board, 2, Vector2i(5, 4))
	var enemy_hp_before: int = unit_hp(board, 2)
	var knight: UnitState = unit_on_board(board, 1)
	var trample: AbilityData = ability_on_unit(knight, &"knight_trampling_advance")
	var plan := Timeline.new()
	plan.add(plan_ability(1, trample, Vector2i(6, 4), -1))
	var result: SimResult = simulate_plan(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "trample/base/moved",
		after != null and after.position == Vector2i(6, 4),
		"trample must MOVE 2 tiles to target",
	)
	assert_true(
		failures, "trample/base/trample_damage",
		events_have_damage_base(result.events, 2),
		"TRAMPLE 2 must emit base-2 contact damage telemetry",
	)
	assert_true(
		failures, "trample/base/enemy_damaged",
		enemy != null and unit_hp(result.final_state, 2) < enemy_hp_before,
		"trample path must damage enemy on contact",
	)
	assert_eq_cell(
		failures, "trample/base/push",
		enemy.position if enemy != null else Vector2i(-1, -1),
		Vector2i(5, 5),
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
	## Bible: mitigated DEF/SHIELD damage stacks +1 STR (max 3); resets on attack; [+] PIERCE on next attack.
	var cfg: Dictionary = with_single_passive(&"kinetic_redirection", false)
	var board: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board, 1, Vector2i(3, 2), cfg)
	_kinetic_redirection_apply_partial_hit(board, 1)
	var knight: UnitState = unit_on_board(board, 1)
	assert_eq_int(
		failures, "kinetic_redirection/stack_after_mitigate",
		int(knight.passive_flags.get("kinetic_redirection_stacks", 0)),
		1,
	)
	assert_true(
		failures, "kinetic_redirection/str_buff_after_mitigate",
		_kinetic_redirection_has_stack_str(knight),
		"mitigation must grant duration -1 STR buff for next attack",
	)
	var board_shield: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board_shield, 5, Vector2i(3, 2), cfg)
	_kinetic_redirection_apply_shield_hit(board_shield, 5)
	assert_eq_int(
		failures, "kinetic_redirection/shield_mitigate_stack",
		int(unit_on_board(board_shield, 5).passive_flags.get("kinetic_redirection_stacks", 0)),
		1,
	)
	var board_block: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board_block, 7, Vector2i(3, 2), cfg)
	_kinetic_redirection_apply_full_block_hit(board_block, 7)
	assert_eq_int(
		failures, "kinetic_redirection/full_def_block_stack",
		int(unit_on_board(board_block, 7).passive_flags.get("kinetic_redirection_stacks", 0)),
		1,
	)
	var board_hz: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board_hz, 6, Vector2i(3, 2), cfg)
	var knight_hz: UnitState = unit_on_board(board_hz, 6)
	knight_hz.armor = 10
	var hz_events: Array[SimEvent] = []
	CombatSystem.deal_damage(
		board_hz, knight_hz, 6, hz_events, &"hazard", false, false, null, "knight_qa",
	)
	assert_eq_int(
		failures, "kinetic_redirection/hazard_no_stack",
		int(knight_hz.passive_flags.get("kinetic_redirection_stacks", 0)),
		0,
	)
	var board2: BoardState = board.clone()
	place_dummy(board2, 3, Vector2i(2, 2))
	var bash_self: AbilityData = ability_on_unit(unit_on_board(board2, 1), &"knight_shield_bash")
	var attack := Timeline.new()
	attack.add(plan_ability(1, bash_self, Vector2i(2, 2), 3))
	var attack_result: SimResult = simulate_plan(board2, attack)
	var after_attack: UnitState = attack_result.final_state.get_unit_by_id(1)
	assert_eq_int(
		failures, "kinetic_redirection/stacks_reset_on_attack",
		int(after_attack.passive_flags.get("kinetic_redirection_stacks", 0)),
		0,
	)
	var board_cap: BoardState = make_plain_board(Vector2i(8, 5))
	place_knight(board_cap, 10, Vector2i(3, 2), cfg)
	for _i: int in range(4):
		_kinetic_redirection_apply_partial_hit(board_cap, 10)
	var after_cap: UnitState = unit_on_board(board_cap, 10)
	assert_eq_int(
		failures, "kinetic_redirection/stack_cap_three",
		int(after_cap.passive_flags.get("kinetic_redirection_stacks", 0)),
		3,
	)
	var board_payoff: BoardState = make_plain_board(Vector2i(10, 5))
	place_knight(board_payoff, 15, Vector2i(3, 2), cfg)
	var knight_pay: UnitState = unit_on_board(board_payoff, 15)
	for _i: int in range(3):
		knight_pay.passive_flags["kinetic_redirection_stacks"] = _i + 1
		knight_pay.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, -1, 1))
	knight_pay._recalculate_stats()
	place_dummy(board_payoff, 16, Vector2i(2, 2))
	var bash_pay: AbilityData = ability_on_unit(knight_pay, &"knight_shield_bash")
	var atk_pay := Timeline.new()
	atk_pay.add(plan_ability(15, bash_pay, Vector2i(2, 2), 16))
	var result_pay: SimResult = simulate_plan(board_payoff, atk_pay)
	var stat_stacked: int = events_max_damage_stat_val(result_pay.events)
	var board_plain: BoardState = make_plain_board(Vector2i(10, 5))
	place_knight(board_plain, 17, Vector2i(3, 2), cfg)
	place_dummy(board_plain, 18, Vector2i(2, 2))
	var bash_plain: AbilityData = ability_on_unit(unit_on_board(board_plain, 17), &"knight_shield_bash")
	var atk_plain := Timeline.new()
	atk_plain.add(plan_ability(17, bash_plain, Vector2i(2, 2), 18))
	var result_plain: SimResult = simulate_plan(board_plain, atk_plain)
	var stat_plain: int = events_max_damage_stat_val(result_plain.events)
	assert_true(
		failures, "kinetic_redirection/stacked_attack_str_payoff",
		stat_stacked > stat_plain,
		"stacked STR buff must increase attack stat scaling vs zero stacks",
	)
	var cfg_up: Dictionary = with_single_passive(&"kinetic_redirection", true)
	var board_up: BoardState = make_plain_board(Vector2i(10, 5))
	place_knight(board_up, 20, Vector2i(3, 2), cfg_up)
	_kinetic_redirection_apply_partial_hit(board_up, 20)
	assert_eq_int(
		failures, "kinetic_redirection/upgrade/stacks_before_attack",
		int(unit_on_board(board_up, 20).passive_flags.get("kinetic_redirection_stacks", 0)),
		1,
	)
	place_dummy(board_up, 22, Vector2i(2, 2))
	var dummy_up: UnitState = unit_on_board(board_up, 22)
	dummy_up.armor = 0
	dummy_up.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, 5))
	dummy_up._recalculate_stats()
	var bash_up: AbilityData = ability_on_unit(unit_on_board(board_up, 20), &"knight_shield_bash")
	var atk_up := Timeline.new()
	atk_up.add(plan_ability(20, bash_up, Vector2i(2, 2), 22))
	var result_up: SimResult = simulate_plan(board_up, atk_up)
	var incoming_up: int = events_incoming_damage_to_unit(result_up.events, 22)
	assert_true(
		failures, "kinetic_redirection/upgrade/pierce_telemetry",
		events_have_damage_pierce(result_up.events, true),
		"upgraded kinetic redirection must set pierce on stacked attack telemetry",
	)
	var board_base: BoardState = make_plain_board(Vector2i(10, 5))
	place_knight(board_base, 30, Vector2i(3, 2), cfg)
	_kinetic_redirection_apply_partial_hit(board_base, 30)
	place_dummy(board_base, 32, Vector2i(2, 2))
	var dummy_base: UnitState = unit_on_board(board_base, 32)
	dummy_base.armor = 0
	dummy_base.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, 5))
	dummy_base._recalculate_stats()
	var bash_base: AbilityData = ability_on_unit(unit_on_board(board_base, 30), &"knight_shield_bash")
	var atk_base := Timeline.new()
	atk_base.add(plan_ability(30, bash_base, Vector2i(2, 2), 32))
	var result_base: SimResult = simulate_plan(board_base, atk_base)
	var incoming_base: int = events_incoming_damage_to_unit(result_base.events, 32)
	assert_true(
		failures, "kinetic_redirection/base/no_pierce_without_upgrade",
		not events_have_damage_pierce(result_base.events, true),
		"base kinetic redirection must not pierce even with stacks",
	)
	assert_true(
		failures, "kinetic_redirection/upgrade/pierce_extra_damage",
		incoming_up > incoming_base,
		"upgraded kinetic redirection must pierce DEF on stacked attack",
	)


static func _kinetic_redirection_has_stack_str(unit: UnitState) -> bool:
	if unit == null:
		return false
	for s: StatusData in unit.active_statuses:
		if s.type == GameEnums.StatusType.STAT_BUFF_STR and s.duration == -1:
			return true
	return false


static func _kinetic_redirection_apply_full_block_hit(board: BoardState, unit_id: int) -> void:
	## Full DEF block: incoming <= 0 with mitigated_amount > 0.
	var knight: UnitState = unit_on_board(board, unit_id)
	if knight == null:
		return
	knight.armor = 0
	var kept: Array[StatusData] = []
	for s: StatusData in knight.active_statuses:
		if s.type != GameEnums.StatusType.STAT_BUFF_DEF:
			kept.append(s)
	knight.active_statuses = kept
	knight.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, 12))
	knight._recalculate_stats()
	var events: Array[SimEvent] = []
	CombatSystem.deal_damage(
		board, knight, 3, events, &"physical", false, false, null, "knight_qa",
	)


static func _kinetic_redirection_apply_shield_hit(board: BoardState, unit_id: int) -> void:
	## SHIELD-only mitigation: armor absorbs incoming with no DEF reduction.
	var knight: UnitState = unit_on_board(board, unit_id)
	if knight == null:
		return
	knight.armor = 10
	var kept: Array[StatusData] = []
	for s: StatusData in knight.active_statuses:
		if s.type != GameEnums.StatusType.STAT_BUFF_DEF:
			kept.append(s)
	knight.active_statuses = kept
	knight._recalculate_stats()
	var events: Array[SimEvent] = []
	CombatSystem.deal_damage(
		board, knight, 4, events, &"physical", false, false, null, "knight_qa",
	)


static func _kinetic_redirection_apply_partial_hit(board: BoardState, unit_id: int) -> void:
	## Partial DEF mitigation (not full block) so kinetic_redirection_stacks increments.
	var knight: UnitState = unit_on_board(board, unit_id)
	if knight == null:
		return
	knight.armor = maxi(knight.armor, 5)
	var has_def_buff := false
	for s: StatusData in knight.active_statuses:
		if s.type == GameEnums.StatusType.STAT_BUFF_DEF:
			has_def_buff = true
			break
	if not has_def_buff:
		knight.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, 3))
		knight._recalculate_stats()
	var events: Array[SimEvent] = []
	CombatSystem.deal_damage(
		board, knight, 10, events, &"physical", false, false, null, "knight_qa",
	)


static func run_rallying_presence(failures: Array[String]) -> void:
	## Bible: adjacent allies +1 MOV at turn start; [+] +2 MOV.
	var cfg: Dictionary = with_single_passive(&"rallying_presence", false)
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board, 1, Vector2i(3, 3), cfg)
	var ally_def: UnitData = knight_unit_data()
	place_unit(board, 3, ally_def, GameEnums.Team.PLAYER, Vector2i(3, 4), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var mov_max_before: int = unit_on_board(board, 3).movement.max_points
	var plan := Timeline.new()
	var result: SimResult = simulate_player_turn(board, plan)
	var ally: UnitState = result.final_state.get_unit_by_id(3)
	assert_eq_int(
		failures, "rallying_presence/mov_buff",
		ally.movement.max_points,
		mov_max_before + 1,
	)
	var knight_after: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "rallying_presence/carrier_no_self_buff",
		knight_after != null and not has_status(knight_after, GameEnums.StatusType.STAT_BUFF_MP),
		"rallying presence must buff allies only, not the carrier knight",
	)
	var board_far: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board_far, 5, Vector2i(3, 3), cfg)
	place_unit(board_far, 6, ally_def, GameEnums.Team.PLAYER, Vector2i(6, 6), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var result_far: SimResult = simulate_player_turn(board_far, Timeline.new())
	var ally_far: UnitState = result_far.final_state.get_unit_by_id(6)
	assert_true(
		failures, "rallying_presence/non_adjacent_no_buff",
		ally_far != null and not has_status(ally_far, GameEnums.StatusType.STAT_BUFF_MP),
		"non-adjacent ally must not receive MOV buff",
	)
	var cfg_up: Dictionary = with_single_passive(&"rallying_presence", true)
	var board2: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board2, 10, Vector2i(3, 3), cfg_up)
	place_unit(board2, 11, ally_def, GameEnums.Team.PLAYER, Vector2i(3, 4), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	mov_max_before = unit_on_board(board2, 11).movement.max_points
	var result2: SimResult = simulate_player_turn(board2, Timeline.new())
	var ally2: UnitState = result2.final_state.get_unit_by_id(11)
	assert_eq_int(
		failures, "rallying_presence/upgrade/mov2",
		ally2.movement.max_points,
		mov_max_before + 2,
	)
	var board_exp: BoardState = result.final_state.clone()
	var knight_carrier: UnitState = board_exp.get_unit_by_id(1)
	if knight_carrier != null:
		GridSystem.set_occupant(board_exp, knight_carrier.position, -1)
		knight_carrier.position = Vector2i(7, 7)
		GridSystem.set_occupant(board_exp, Vector2i(7, 7), 1)
	var advanced: SimResult = Simulator.simulate(board_exp, Timeline.new())
	advanced = Simulator.simulate(advanced.final_state, Timeline.new())
	var ally_next: UnitState = advanced.final_state.get_unit_by_id(3)
	assert_true(
		failures, "rallying_presence/buff_expires_next_turn",
		ally_next != null and not has_status(ally_next, GameEnums.StatusType.STAT_BUFF_MP),
		"rallying presence MOV buff must expire after the turn",
	)


static func run_shield_wall(failures: Array[String]) -> void:
	## Bible: adjacent allies +1 DEF + PULL immune; [+] aura range 2.
	var ally_def: UnitData = knight_unit_data()
	var board_iso: BoardState = make_plain_board(Vector2i(10, 8))
	place_unit(board_iso, 30, ally_def, GameEnums.Team.PLAYER, Vector2i(4, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var def_iso: int = CombatSystem.get_dynamic_defense(board_iso, unit_on_board(board_iso, 30))
	var cfg: Dictionary = with_single_passive(&"shield_wall", false)
	var board_adj: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board_adj, 1, Vector2i(3, 3), cfg)
	var ally: UnitState = place_unit(board_adj, 2, ally_def, GameEnums.Team.PLAYER, Vector2i(4, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var def_adj: int = CombatSystem.get_dynamic_defense(board_adj, ally)
	assert_eq_int(
		failures, "shield_wall/adjacent_def",
		def_adj - def_iso,
		1,
	)
	var cfg_up: Dictionary = with_single_passive(&"shield_wall", true)
	var board_range: BoardState = make_plain_board(Vector2i(12, 8))
	place_knight(board_range, 10, Vector2i(3, 3), cfg_up)
	var ally_far: UnitState = place_unit(board_range, 11, ally_def, GameEnums.Team.PLAYER, Vector2i(5, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var def_far: int = CombatSystem.get_dynamic_defense(board_range, ally_far)
	assert_eq_int(
		failures, "shield_wall/upgrade/range_two_def",
		def_far - def_iso,
		1,
	)
	var board_pull: BoardState = make_plain_board(Vector2i(12, 8))
	place_knight(board_pull, 20, Vector2i(3, 3), cfg)
	place_unit(board_pull, 21, ally_def, GameEnums.Team.PLAYER, Vector2i(4, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	place_unit(board_pull, 22, knight_unit_data(), GameEnums.Team.ENEMY, Vector2i(6, 3), {
		"active_abilities": [factory_ability(&"knight_chain_hook")],
	})
	var ally_pull_pos: Vector2i = unit_on_board(board_pull, 21).position
	var hook: AbilityData = ability_on_unit(unit_on_board(board_pull, 22), &"knight_chain_hook")
	var plan_pull := Timeline.new()
	plan_pull.add(plan_ability(22, hook, Vector2i(4, 3), 21))
	var pull_result: SimResult = simulate_plan(board_pull, plan_pull)
	var ally_after_pull: UnitState = pull_result.final_state.get_unit_by_id(21)
	assert_eq_cell(
		failures, "shield_wall/adjacent_pull_immune",
		ally_after_pull.position if ally_after_pull else Vector2i(-1, -1),
		ally_pull_pos,
	)
	var board_pull2: BoardState = make_plain_board(Vector2i(12, 8))
	place_knight(board_pull2, 30, Vector2i(3, 3), cfg_up)
	place_unit(board_pull2, 31, ally_def, GameEnums.Team.PLAYER, Vector2i(5, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	place_unit(board_pull2, 32, knight_unit_data(), GameEnums.Team.ENEMY, Vector2i(7, 3), {
		"active_abilities": [factory_ability(&"knight_chain_hook")],
	})
	var ally_far_pos: Vector2i = unit_on_board(board_pull2, 31).position
	var hook2: AbilityData = ability_on_unit(unit_on_board(board_pull2, 32), &"knight_chain_hook")
	var plan_pull2 := Timeline.new()
	plan_pull2.add(plan_ability(32, hook2, Vector2i(5, 3), 31))
	var pull_result2: SimResult = simulate_plan(board_pull2, plan_pull2)
	var ally_after_far: UnitState = pull_result2.final_state.get_unit_by_id(31)
	assert_eq_cell(
		failures, "shield_wall/upgrade/range_two_pull_immune",
		ally_after_far.position if ally_after_far else Vector2i(-1, -1),
		ally_far_pos,
	)


static func run_redirect_strike(failures: Array[String]) -> void:
	var cfg: Dictionary = {
		"active_abilities": [
			DataLibrary.get_universal_run(),
			factory_ability(&"knight_redirect_strike"),
		],
		"active_passives": [],
	}
	var board_no: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board_no, 1, Vector2i(3, 3), cfg)
	var ally_def: UnitData = knight_unit_data()
	place_unit(board_no, 2, ally_def, GameEnums.Team.PLAYER, Vector2i(4, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var loss_without: int = damage_taken_pierce(board_no, 2, 20)
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board, 10, Vector2i(3, 3), cfg)
	place_unit(board, 11, ally_def, GameEnums.Team.PLAYER, Vector2i(4, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var knight: UnitState = unit_on_board(board, 10)
	var redirect: AbilityData = ability_on_unit(knight, &"knight_redirect_strike")
	var cast_action: TimelineAction = plan_ability(10, redirect, knight.position, knight.id)
	assert_true(
		failures, "redirect_strike/ability_system/can_use_self",
		AbilitySystem.can_use(board, cast_action),
		"AbilitySystem must allow self-cast redirect strike at RANGE 2",
	)
	var plan := Timeline.new()
	plan.add(plan_ability(10, redirect, knight.position, knight.id))
	var result: SimResult = simulate_player_turn(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(10)
	assert_true(
		failures, "redirect_strike/intercept_status",
		after != null and has_status(after, GameEnums.StatusType.INTERCEPT),
		"redirect strike must apply INTERCEPT to self",
	)
	var intercept_dur: int = 0
	for s: StatusData in after.active_statuses if after else []:
		if s.type == GameEnums.StatusType.INTERCEPT:
			intercept_dur = s.duration
	assert_eq_int(
		failures, "redirect_strike/intercept_duration",
		intercept_dur,
		1,
	)
	var advanced_intercept: SimResult = Simulator.simulate(result.final_state, Timeline.new())
	var mid_window: UnitState = advanced_intercept.final_state.get_unit_by_id(10)
	assert_true(
		failures, "redirect_strike/intercept_persists_mid_window",
		mid_window != null and has_status(mid_window, GameEnums.StatusType.INTERCEPT),
		"INTERCEPT must remain active until turn boundary",
	)
	var mid_board: BoardState = advanced_intercept.final_state.clone()
	var knight_mid_before: int = mid_board.get_unit_by_id(10).health.current_hp
	var loss_mid_ally: int = damage_taken_pierce(mid_board, 11, 20)
	var knight_mid_loss: int = knight_mid_before - mid_board.get_unit_by_id(10).health.current_hp
	assert_eq_int(
		failures, "redirect_strike/mid_window/split_active",
		knight_mid_loss,
		10,
	)
	assert_eq_int(
		failures, "redirect_strike/mid_window/ally_damage",
		loss_mid_ally,
		10,
	)
	advanced_intercept = Simulator.simulate(advanced_intercept.final_state, Timeline.new())
	var after_expire: UnitState = advanced_intercept.final_state.get_unit_by_id(10)
	assert_true(
		failures, "redirect_strike/intercept_expires",
		after_expire != null and not has_status(after_expire, GameEnums.StatusType.INTERCEPT),
		"INTERCEPT must clear after next turn",
	)
	var knight_post_before: int = after_expire.health.current_hp
	damage_taken_pierce(advanced_intercept.final_state, 11, 20)
	var knight_post_loss: int = knight_post_before - advanced_intercept.final_state.get_unit_by_id(10).health.current_hp
	assert_eq_int(
		failures, "redirect_strike/post_expiry/no_redirect",
		knight_post_loss,
		0,
	)
	assert_eq_int(
		failures, "redirect_strike/range",
		redirect.range_tiles,
		2,
	)
	var board_hit: BoardState = result.final_state.clone()
	var knight_before: int = board_hit.get_unit_by_id(10).health.current_hp
	var loss_with: int = damage_taken_pierce(board_hit, 11, 20)
	var knight_after_hit: UnitState = board_hit.get_unit_by_id(10)
	var knight_loss: int = knight_before - knight_after_hit.health.current_hp
	assert_true(
		failures, "redirect_strike/split_damage",
		loss_with < loss_without and knight_loss > 0,
		"INTERCEPT must redirect 50% damage (rounded down) to adjacent interceptor",
	)
	assert_eq_int(
		failures, "redirect_strike/ally_damage_reduced",
		loss_without - loss_with,
		knight_loss,
	)
	assert_eq_int(
		failures, "redirect_strike/intercept_amount",
		knight_loss,
		10,
	)
	assert_eq_int(
		failures, "redirect_strike/ally_damage_after_intercept",
		loss_with,
		10,
	)
	var board_odd: BoardState = result.final_state.clone()
	var knight_odd_before: int = board_odd.get_unit_by_id(10).health.current_hp
	var loss_odd_ally: int = damage_taken_pierce(board_odd, 11, 19)
	var knight_odd_loss: int = knight_odd_before - board_odd.get_unit_by_id(10).health.current_hp
	assert_eq_int(
		failures, "redirect_strike/round_down_odd",
		knight_odd_loss,
		9,
	)
	assert_eq_int(
		failures, "redirect_strike/round_down_ally_save",
		19 - loss_odd_ally,
		9,
	)
	var knight_after_base: UnitState = board_hit.get_unit_by_id(10)
	var base_def_buff: bool = false
	for s: StatusData in knight_after_base.active_statuses if knight_after_base else []:
		if s.type == GameEnums.StatusType.STAT_BUFF_DEF:
			base_def_buff = true
	assert_true(
		failures, "redirect_strike/base/no_def_on_intercept",
		not base_def_buff,
		"base redirect strike must not grant DEF buff on intercepted hit",
	)
	var board_far: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board_far, 30, Vector2i(3, 3), cfg)
	place_unit(board_far, 31, ally_def, GameEnums.Team.PLAYER, Vector2i(5, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var knight_far: UnitState = unit_on_board(board_far, 30)
	var redirect_far: AbilityData = ability_on_unit(knight_far, &"knight_redirect_strike")
	var plan_far := Timeline.new()
	plan_far.add(plan_ability(30, redirect_far, knight_far.position, knight_far.id))
	var result_far: SimResult = simulate_player_turn(board_far, plan_far)
	var board_far_hit: BoardState = result_far.final_state.clone()
	var knight_far_before: int = board_far_hit.get_unit_by_id(30).health.current_hp
	var loss_far_ally: int = damage_taken_pierce(board_far_hit, 31, 20)
	var knight_far_loss: int = knight_far_before - board_far_hit.get_unit_by_id(30).health.current_hp
	assert_eq_int(
		failures, "redirect_strike/non_adjacent/no_redirect",
		knight_far_loss,
		0,
	)
	assert_eq_int(
		failures, "redirect_strike/non_adjacent/full_ally_damage",
		loss_far_ally,
		20,
	)
	var cfg_up: Dictionary = with_upgraded_ability(cfg, &"knight_redirect_strike")
	var board_up: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board_up, 20, Vector2i(3, 3), cfg_up)
	place_unit(board_up, 21, ally_def, GameEnums.Team.PLAYER, Vector2i(4, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var knight_up: UnitState = unit_on_board(board_up, 20)
	var redirect_up: AbilityData = ability_on_unit(knight_up, &"knight_redirect_strike")
	assert_true(
		failures, "redirect_strike/upgrade/intercept_flag",
		redirect_up.upgraded_modules[0].amount == 1,
		"upgraded redirect strike must mark INTERCEPT with value 1 for [+] DEF",
	)
	var plan_up := Timeline.new()
	plan_up.add(plan_ability(20, redirect_up, knight_up.position, knight_up.id))
	var result_up: SimResult = simulate_player_turn(board_up, plan_up)
	var board_up_hit: BoardState = result_up.final_state.clone()
	damage_taken_pierce(board_up_hit, 21, 20)
	var knight_up_mid: UnitState = board_up_hit.get_unit_by_id(20)
	var def_after_one: int = 0
	for s: StatusData in knight_up_mid.active_statuses if knight_up_mid else []:
		if s.type == GameEnums.StatusType.STAT_BUFF_DEF:
			def_after_one += s.value
	assert_eq_int(
		failures, "redirect_strike/upgrade/def_first_hit",
		def_after_one,
		2,
	)
	damage_taken_pierce(board_up_hit, 21, 20)
	var knight_up_after: UnitState = board_up_hit.get_unit_by_id(20)
	var def_total: int = 0
	for s: StatusData in knight_up_after.active_statuses if knight_up_after else []:
		if s.type == GameEnums.StatusType.STAT_BUFF_DEF:
			def_total += s.value
	assert_eq_int(
		failures, "redirect_strike/upgrade/def_two_hits",
		def_total,
		4,
	)


static func run_intercept_tactics(failures: Array[String]) -> void:
	## Bible: redirect skill grants +2 DEF; [+] +3 DEF.
	var cfg: Dictionary = with_single_passive(&"intercept_tactics", false)
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board, 1, Vector2i(3, 3), cfg)
	var knight: UnitState = unit_on_board(board, 1)
	var redirect: AbilityData = ability_on_unit(knight, &"knight_redirect_strike")
	var plan := Timeline.new()
	plan.add(plan_ability(1, redirect, knight.position, knight.id))
	var result: SimResult = simulate_player_turn(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	var def_amt: int = 0
	for s: StatusData in after.active_statuses if after else []:
		if s.type == GameEnums.StatusType.STAT_BUFF_DEF:
			def_amt = s.value
	assert_eq_int(
		failures, "intercept_tactics/def_buff",
		def_amt,
		2,
	)
	var loss_with: int = damage_taken_on_unit(result.final_state, 1, 12)
	var board_no: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board_no, 2, Vector2i(3, 3))
	var loss_without_buff: int = damage_taken_on_unit(board_no, 2, 12)
	assert_true(
		failures, "intercept_tactics/def_mitigates_damage",
		loss_with < loss_without_buff,
		"intercept tactics DEF must reduce incoming damage after redirect",
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
	def_amt = 0
	for s: StatusData in after2.active_statuses if after2 else []:
		if s.type == GameEnums.StatusType.STAT_BUFF_DEF:
			def_amt = s.value
	assert_eq_int(
		failures, "intercept_tactics/upgrade/def3",
		def_amt,
		3,
	)
	var loss_up: int = damage_taken_on_unit(result2.final_state, 10, 12)
	var board_base: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board_base, 12, Vector2i(3, 3), cfg)
	var redirect_base: AbilityData = ability_on_unit(unit_on_board(board_base, 12), &"knight_redirect_strike")
	var plan_base := Timeline.new()
	plan_base.add(plan_ability(12, redirect_base, Vector2i(3, 3), 12))
	var result_base: SimResult = simulate_player_turn(board_base, plan_base)
	var loss_base_redirect: int = damage_taken_on_unit(result_base.final_state, 12, 12)
	assert_true(
		failures, "intercept_tactics/upgrade/def_mitigates_more",
		loss_up < loss_base_redirect,
		"upgraded intercept tactics must mitigate more damage than base +2 DEF",
	)


static func place_enemy_artillery(board: BoardState, unit_id: int, pos: Vector2i) -> UnitState:
	var def: UnitData = DataLibrary.get_unit(&"artillery")
	if def == null:
		def = DataLibrary.get_training_dummy()
	var abilities: Array[AbilityData] = []
	if def.behavior != null and def.behavior.attack != null:
		abilities.append(def.behavior.attack)
	return place_unit(board, unit_id, def, GameEnums.Team.ENEMY, pos, {
		"active_abilities": abilities if not abilities.is_empty() else [factory_ability(&"knight_chain_hook")],
	})


static func events_contain_reason(events: Array, reason: String) -> bool:
	for e: Variant in events:
		if e is SimEvent and str(e.data.get("reason", "")) == reason:
			return true
	return false


static func damage_taken_on_unit(board: BoardState, unit_id: int, raw_amount: int) -> int:
	var target: UnitState = board.get_unit_by_id(unit_id)
	if target == null or target.health == null:
		return 0
	var hp_before: int = target.health.current_hp
	var events: Array[SimEvent] = []
	CombatSystem.deal_damage(
		board, target, raw_amount, events, &"physical", false, false, null, "knight_qa",
	)
	return hp_before - target.health.current_hp


static func damage_taken_pierce(board: BoardState, unit_id: int, raw_amount: int) -> int:
	var target: UnitState = board.get_unit_by_id(unit_id)
	if target == null or target.health == null:
		return 0
	var hp_before: int = target.health.current_hp
	var events: Array[SimEvent] = []
	CombatSystem.deal_damage(
		board, target, raw_amount, events, &"physical", true, false, null, "knight_qa",
	)
	return hp_before - target.health.current_hp


static func events_have_damage_pierce(events: Array, pierce: bool) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.MATH_TELEMETRY:
			var d: Dictionary = e.data
			if str(d.get("type", "")) == "damage" and bool(d.get("pierce", false)) == pierce:
				return true
	return false


static func events_max_damage_floored(events: Array) -> int:
	var best: int = 0
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.MATH_TELEMETRY:
			var d: Dictionary = e.data
			if str(d.get("type", "")) == "damage":
				best = maxi(best, int(d.get("floored", 0)))
	return best


static func events_max_damage_stat_val(events: Array) -> int:
	var best: int = 0
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.MATH_TELEMETRY:
			var d: Dictionary = e.data
			if str(d.get("type", "")) == "damage":
				best = maxi(best, int(d.get("stat_val", 0)))
	return best


static func events_incoming_damage_to_unit(events: Array, unit_id: int) -> int:
	var best: int = 0
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.UNIT_DAMAGED:
			var d: Dictionary = e.data
			if int(d.get("unit", -1)) == unit_id:
				best = maxi(best, int(d.get("amount", 0)))
	return best


static func events_have_damage_base(events: Array, base_power: int) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.MATH_TELEMETRY:
			var d: Dictionary = e.data
			if str(d.get("type", "")) == "damage" and int(d.get("base", -1)) == base_power:
				return true
	return false


static func events_have_status_removed(events: Array, unit_id: int, status_type: GameEnums.StatusType) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.STATUS_REMOVED:
			var d: Dictionary = e.data
			if int(d.get("unit", -1)) == unit_id and d.get("status_type", -1) == status_type:
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
	var board0: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board0, 1, Vector2i(3, 3))
	var knight0: UnitState = unit_on_board(board0, 1)
	var ability0: AbilityData = ability_on_unit(knight0, &"knight_phalanx_stance")
	var plan0 := Timeline.new()
	plan0.add(plan_ability(1, ability0, knight0.position, knight0.id))
	var result0: SimResult = simulate_player_turn(board0, plan0)
	var after0: UnitState = result0.final_state.get_unit_by_id(1)
	assert_true(
		failures, "phalanx_stance/def_buff",
		after0 != null and has_status(after0, GameEnums.StatusType.STAT_BUFF_DEF),
		"phalanx stance must grant DEF buff",
	)
	assert_true(
		failures, "phalanx_stance/sturdy",
		after0 != null and has_status(after0, GameEnums.StatusType.STURDY),
		"phalanx stance must grant STURDY",
	)
	var def_amt: int = 0
	if after0 != null:
		for s: StatusData in after0.active_statuses:
			if s.type == GameEnums.StatusType.STAT_BUFF_DEF:
				def_amt = s.value
	assert_true(
		failures, "phalanx_stance/def_amount",
		def_amt >= 5,
		"phalanx stance must grant DEF +5",
	)
	var sturdy_before: StatusData = null
	if after0 != null:
		for s: StatusData in after0.active_statuses:
			if s.type == GameEnums.StatusType.STURDY:
				sturdy_before = s
	assert_true(
		failures, "phalanx_stance/sturdy_has_duration",
		sturdy_before != null and sturdy_before.duration > 0,
		"STURDY must have timed duration (until next turn)",
	)
	var advanced: SimResult = Simulator.simulate(board0, Timeline.new())
	advanced = Simulator.simulate(advanced.final_state, Timeline.new())
	var after_turn: UnitState = advanced.final_state.get_unit_by_id(1)
	assert_true(
		failures, "phalanx_stance/sturdy_expires",
		after_turn != null and not has_status(after_turn, GameEnums.StatusType.STURDY),
		"STURDY must clear after next turn",
	)
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
	var cfg_combo: Dictionary = with_upgraded_ability(
		with_upgraded_ability({}, &"knight_phalanx_stance"), &"knight_retaliation_protocol")
	var board_combo: BoardState = make_plain_board(Vector2i(12, 5))
	place_knight(board_combo, 1, Vector2i(2, 2), cfg_combo)
	var knight_combo: UnitState = unit_on_board(board_combo, 1)
	knight_combo.passive_flags["training_unlimited_actions"] = true
	grant_extra_ap(knight_combo, 1)
	var phalanx_ab: AbilityData = ability_on_unit(knight_combo, &"knight_phalanx_stance")
	var protocol_ab: AbilityData = ability_on_unit(knight_combo, &"knight_retaliation_protocol")
	var setup := Timeline.new()
	setup.add(plan_ability(1, phalanx_ab, knight_combo.position, knight_combo.id))
	setup.add(plan_ability(1, protocol_ab, knight_combo.position, knight_combo.id))
	simulate_player_turn(board_combo, setup)
	var armed: UnitState = unit_on_board(board_combo, 1)
	assert_true(
		failures, "phalanx_stance/upgrade/retaliation_status",
		armed != null
		and has_status(armed, GameEnums.StatusType.RETALIATION_PROTOCOL)
		and has_status(armed, GameEnums.StatusType.RETALIATION_INFINITE_RANGE),
		"phalanx [+] with retaliation protocol must arm both statuses",
	)
	soften_for_melee_hit(armed)
	place_enemy_artillery(board_combo, 2, Vector2i(4, 2))
	var artillery: UnitState = unit_on_board(board_combo, 2)
	var bolt: AbilityData = artillery.active_abilities[0]
	var hp_before: int = artillery.health.current_hp
	var attack := Timeline.new()
	attack.add(plan_ability(2, bolt, Vector2i(2, 2), 1))
	var result_combo: SimResult = simulate_player_turn(board_combo, attack)
	var enemy_after: UnitState = result_combo.final_state.get_unit_by_id(2)
	assert_true(
		failures, "phalanx_stance/upgrade/retaliation_at_range",
		enemy_after != null and enemy_after.health.current_hp < hp_before,
		"phalanx [+] must enable retaliation counter beyond melee range",
	)
	var board_wide: BoardState = make_plain_board(Vector2i(12, 5))
	place_knight(board_wide, 30, Vector2i(2, 2), cfg_combo)
	var k_wide: UnitState = unit_on_board(board_wide, 30)
	k_wide.passive_flags["training_unlimited_actions"] = true
	grant_extra_ap(k_wide, 1)
	var ph_wide: AbilityData = ability_on_unit(k_wide, &"knight_phalanx_stance")
	var pr_wide: AbilityData = ability_on_unit(k_wide, &"knight_retaliation_protocol")
	var setup_w := Timeline.new()
	setup_w.add(plan_ability(30, ph_wide, k_wide.position, 30))
	setup_w.add(plan_ability(30, pr_wide, k_wide.position, 30))
	simulate_player_turn(board_wide, setup_w)
	soften_for_melee_hit(unit_on_board(board_wide, 30))
	place_enemy_artillery(board_wide, 31, Vector2i(9, 2))
	var bolt_w: AbilityData = unit_on_board(board_wide, 31).active_abilities[0]
	bolt_w.range_tiles = 10
	var hp_wide: int = unit_on_board(board_wide, 31).health.current_hp
	var atk_w := Timeline.new()
	atk_w.add(plan_ability(31, bolt_w, Vector2i(2, 2), 30))
	var res_w: SimResult = simulate_player_turn(board_wide, atk_w)
	var en_wide: UnitState = res_w.final_state.get_unit_by_id(31)
	assert_true(
		failures, "phalanx_stance/upgrade/retaliation_map_wide",
		en_wide != null and en_wide.health.current_hp < hp_wide,
		"phalanx [+] must counter at map-wide range (Manhattan 7)",
	)
	var expire_inf: SimResult = Simulator.simulate(board_wide, Timeline.new())
	expire_inf = Simulator.simulate(expire_inf.final_state, Timeline.new())
	var k_exp: UnitState = expire_inf.final_state.get_unit_by_id(30)
	assert_true(
		failures, "phalanx_stance/upgrade/infinite_range_expires",
		k_exp != null and not has_status(k_exp, GameEnums.StatusType.RETALIATION_INFINITE_RANGE),
		"RETALIATION_INFINITE_RANGE must clear after turn boundary (this turn only)",
	)
	var cfg_proto: Dictionary = with_upgraded_ability({}, &"knight_retaliation_protocol")
	var board_neg: BoardState = make_plain_board(Vector2i(12, 5))
	place_knight(board_neg, 40, Vector2i(2, 2), cfg_proto)
	var k_neg: UnitState = unit_on_board(board_neg, 40)
	var pr_neg: AbilityData = ability_on_unit(k_neg, &"knight_retaliation_protocol")
	var setup_n := Timeline.new()
	setup_n.add(plan_ability(40, pr_neg, k_neg.position, 40))
	simulate_player_turn(board_neg, setup_n)
	soften_for_melee_hit(unit_on_board(board_neg, 40))
	place_enemy_artillery(board_neg, 41, Vector2i(4, 2))
	var hp_neg: int = unit_on_board(board_neg, 41).health.current_hp
	var bolt_n: AbilityData = unit_on_board(board_neg, 41).active_abilities[0]
	var atk_n := Timeline.new()
	atk_n.add(plan_ability(41, bolt_n, Vector2i(2, 2), 40))
	var res_n: SimResult = simulate_player_turn(board_neg, atk_n)
	var en_neg: UnitState = res_n.final_state.get_unit_by_id(41)
	assert_true(
		failures, "phalanx_stance/upgrade/no_infinite_without_phalanx",
		en_neg != null and en_neg.health.current_hp == hp_neg,
		"without phalanx [+] infinite range, counter must not hit beyond melee 1",
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
		failures, "taunting_strike/damage_atk1",
		events_have_damage_base(result.events, 1),
		"taunting strike must resolve DAMAGE at base power ATK 1",
	)
	assert_true(
		failures, "taunting_strike/taunt",
		enemy != null and has_status(enemy, GameEnums.StatusType.TAUNT),
		"taunting strike must apply TAUNT",
	)
	assert_eq_cell(failures, "taunting_strike/pull", enemy.position, Vector2i(4, 3))
	assert_eq_int(failures, "taunting_strike/range", strike.range_tiles, 2)
	var cfg_up: Dictionary = with_upgraded_ability({}, &"knight_taunting_strike")
	var board2: BoardState = make_plain_board(Vector2i(12, 10))
	place_knight(board2, 10, Vector2i(5, 5), cfg_up)
	place_dummy(board2, 11, Vector2i(7, 5))
	place_dummy(board2, 12, Vector2i(6, 6))
	var strike_up: AbilityData = ability_on_unit(unit_on_board(board2, 10), &"knight_taunting_strike")
	assert_true(
		failures, "taunting_strike/upgrade/pull2",
		ability_has_effect(strike_up, GameEnums.EffectType.PULL, true)
		and strike_up.upgraded_modules[1].amount == 2,
		"upgraded taunting strike must PULL 2",
	)
	assert_eq_int(failures, "taunting_strike/upgrade/range", strike_up.upgraded_range_tiles, 3)
	assert_true(
		failures, "taunting_strike/upgrade/aoe_shape",
		strike_up.upgraded_target_shape == GameEnums.TargetShape.AOE_SQUARE
		and strike_up.upgraded_target_shape_size == 1,
		"upgraded taunting strike must be AOE 3x3",
	)
	var plan2 := Timeline.new()
	plan2.add(plan_ability(10, strike_up, Vector2i(7, 5), 11))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var e1: UnitState = result2.final_state.get_unit_by_id(11)
	var e2: UnitState = result2.final_state.get_unit_by_id(12)
	assert_eq_cell(failures, "taunting_strike/upgrade/aoe_pull_e1", e1.position, Vector2i(6, 5))
	assert_eq_cell(failures, "taunting_strike/upgrade/aoe_pull_e2", e2.position, Vector2i(4, 6))
	assert_true(
		failures, "taunting_strike/upgrade/aoe_taunt_all",
		e1 != null and e2 != null
		and has_status(e1, GameEnums.StatusType.TAUNT)
		and has_status(e2, GameEnums.StatusType.TAUNT),
		"upgraded taunting strike AOE must TAUNT all enemies hit",
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
	assert_true(
		failures, "seismic_stomp/damage_atk2",
		events_have_damage_base(result.events, 2),
		"seismic stomp must resolve DAMAGE at base power ATK 2 (MATH_TELEMETRY)",
	)
	var board_purge: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board_purge, 20, Vector2i(4, 4))
	place_dummy(board_purge, 21, Vector2i(5, 4))
	var stomp2: AbilityData = ability_on_unit(unit_on_board(board_purge, 20), &"knight_seismic_stomp")
	unit_on_board(board_purge, 21).active_statuses.append(
		DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, 3),
	)
	var plan_purge := Timeline.new()
	plan_purge.add(plan_ability(20, stomp2, Vector2i(4, 4), 20))
	var result_purge: SimResult = simulate_player_turn(board_purge, plan_purge)
	var enemy_purged: UnitState = result_purge.final_state.get_unit_by_id(21)
	assert_true(
		failures, "seismic_stomp/purge",
		enemy_purged != null and not has_status(enemy_purged, GameEnums.StatusType.STAT_BUFF_STR),
		"seismic stomp must PURGE enemy buffs",
	)
	assert_true(
		failures, "seismic_stomp/purge_event",
		events_have_status_removed(
			result_purge.events, 21, GameEnums.StatusType.STAT_BUFF_STR,
		),
		"seismic stomp PURGE must emit STATUS_REMOVED for stripped buff",
	)
	var board_purge2: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board_purge2, 22, Vector2i(4, 4))
	place_dummy(board_purge2, 23, Vector2i(5, 4))
	place_dummy(board_purge2, 24, Vector2i(4, 5))
	unit_on_board(board_purge2, 23).active_statuses.append(
		DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, 3),
	)
	unit_on_board(board_purge2, 24).active_statuses.append(
		DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, 2),
	)
	var stomp_p2: AbilityData = ability_on_unit(unit_on_board(board_purge2, 22), &"knight_seismic_stomp")
	var plan_p2 := Timeline.new()
	plan_p2.add(plan_ability(22, stomp_p2, Vector2i(4, 4), 22))
	var result_p2: SimResult = simulate_player_turn(board_purge2, plan_p2)
	var e_a: UnitState = result_p2.final_state.get_unit_by_id(23)
	var e_b: UnitState = result_p2.final_state.get_unit_by_id(24)
	assert_true(
		failures, "seismic_stomp/purge_all_enemies",
		e_a != null and e_b != null
		and not has_status(e_a, GameEnums.StatusType.STAT_BUFF_STR)
		and not has_status(e_b, GameEnums.StatusType.STAT_BUFF_DEF),
		"seismic stomp AOE PURGE must strip buffs from all enemies in AOE",
	)
	assert_true(
		failures, "seismic_stomp/purge_all_events",
		events_have_status_removed(result_p2.events, 23, GameEnums.StatusType.STAT_BUFF_STR)
		and events_have_status_removed(result_p2.events, 24, GameEnums.StatusType.STAT_BUFF_DEF),
		"seismic stomp AOE PURGE must emit STATUS_REMOVED per enemy buff",
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
	var cracked_tile: TileState = result2.final_state.get_tile(Vector2i(5, 4))
	assert_true(
		failures, "seismic_stomp/upgrade/cracked_tile",
		cracked_tile != null and cracked_tile.definition != null and cracked_tile.definition.id == &"cracked",
		"upgraded seismic stomp must set cracked terrain id on AOE cell",
	)
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var cracked_coord: Vector2i = Vector2i(4 + dx, 4 + dy)
			var tile_up: TileState = result2.final_state.get_tile(cracked_coord)
			assert_true(
				failures, "seismic_stomp/upgrade/cracked_aoe_%d_%d" % [cracked_coord.x, cracked_coord.y],
				tile_up != null and tile_up.definition != null and tile_up.definition.id == &"cracked",
				"upgraded seismic stomp must crack full AOE 1 (3x3) footprint",
			)
	var board_base: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board_base, 50, Vector2i(4, 4))
	place_dummy(board_base, 51, Vector2i(5, 4))
	var stomp_base: AbilityData = ability_on_unit(unit_on_board(board_base, 50), &"knight_seismic_stomp")
	var plan_base := Timeline.new()
	plan_base.add(plan_ability(50, stomp_base, Vector2i(4, 4), 50))
	var result_base: SimResult = simulate_player_turn(board_base, plan_base)
	var plain_tile: TileState = result_base.final_state.get_tile(Vector2i(5, 4))
	assert_true(
		failures, "seismic_stomp/base/no_cracked",
		plain_tile != null and plain_tile.definition != null and plain_tile.definition.id == &"plain",
		"base seismic stomp must not change terrain to cracked",
	)
	var board_multi: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board_multi, 1, Vector2i(4, 4))
	place_dummy(board_multi, 2, Vector2i(5, 4))
	place_dummy(board_multi, 3, Vector2i(4, 5))
	var stomp_m: AbilityData = ability_on_unit(unit_on_board(board_multi, 1), &"knight_seismic_stomp")
	var hp_e2: int = unit_on_board(board_multi, 3).health.current_hp
	var plan_multi := Timeline.new()
	plan_multi.add(plan_ability(1, stomp_m, Vector2i(4, 4), 1))
	var result_multi: SimResult = simulate_player_turn(board_multi, plan_multi)
	var e2: UnitState = result_multi.final_state.get_unit_by_id(3)
	assert_true(
		failures, "seismic_stomp/aoe_second_target",
		e2 != null and e2.health.current_hp < hp_e2,
		"seismic stomp AOE must damage second adjacent enemy",
	)
	var cracked_def: TerrainData = DataLibrary.get_terrain(&"cracked")
	assert_eq_int(
		failures, "seismic_stomp/cracked/mp_cost_data",
		cracked_def.mp_cost_per_tile if cracked_def != null else 0,
		2,
	)
	var board_move: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board_move, 30, Vector2i(5, 3))
	var mover: UnitState = unit_on_board(board_move, 30)
	mover.movement.points_left = 3
	board_move.set_tile_terrain(Vector2i(5, 4), DataLibrary.get_terrain(&"cracked"))
	var plan_move := Timeline.new()
	plan_move.add(TimelineAction.make_move(30, Vector2i(5, 4)))
	var result_move: SimResult = simulate_player_turn(board_move, plan_move)
	var mover_after: UnitState = result_move.final_state.get_unit_by_id(30)
	assert_eq_int(
		failures, "seismic_stomp/cracked/move_cost",
		mover_after.movement.points_left if mover_after != null else -1,
		1,
	)
	var board_e2e: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board_e2e, 40, Vector2i(4, 4), cfg_up)
	place_dummy(board_e2e, 41, Vector2i(6, 4))
	var stomp_e2e: AbilityData = ability_on_unit(unit_on_board(board_e2e, 40), &"knight_seismic_stomp")
	var knight_e2e: UnitState = unit_on_board(board_e2e, 40)
	knight_e2e.movement.points_left = 4
	var plan_e2e := Timeline.new()
	plan_e2e.add(plan_ability(40, stomp_e2e, Vector2i(4, 4), 40))
	plan_e2e.add(
		TimelineAction.make_move(40, Vector2i(5, 4), -1, [], GameEnums.MoveTiming.POST_ACTION),
	)
	var result_e2e: SimResult = simulate_player_turn(board_e2e, plan_e2e)
	var knight_e2e_after: UnitState = result_e2e.final_state.get_unit_by_id(40)
	var cracked_e2e: TileState = result_e2e.final_state.get_tile(Vector2i(5, 4))
	assert_true(
		failures, "seismic_stomp/e2e/cracked_from_stomp",
		cracked_e2e != null and cracked_e2e.definition != null and cracked_e2e.definition.id == &"cracked",
		"stomp-created cracked tile must exist before move onto it",
	)
	assert_eq_int(
		failures, "seismic_stomp/e2e/move_onto_stomp_cracked",
		knight_e2e_after.movement.points_left if knight_e2e_after != null else -1,
		2,
	)
	assert_eq_int(
		failures, "seismic_stomp/range",
		stomp.range_tiles,
		0,
	)
	var board_path: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board_path, 60, Vector2i(4, 3))
	var path_unit: UnitState = unit_on_board(board_path, 60)
	board_path.set_tile_terrain(Vector2i(5, 3), DataLibrary.get_terrain(&"cracked"))
	var reachable: Array[Vector2i] = MovementSystem.get_reachable_tiles(
		board_path, Vector2i(4, 3), 2,
	)
	var can_reach_cracked: bool = false
	var cannot_reach_past: bool = true
	for coord: Vector2i in reachable:
		if coord == Vector2i(5, 3):
			can_reach_cracked = true
		if coord == Vector2i(6, 3):
			cannot_reach_past = false
	assert_true(
		failures, "seismic_stomp/cracked/reachable",
		can_reach_cracked and cannot_reach_past,
		"cracked tile must cost 2 MP â€” budget 2 reaches cracked only, not tile beyond",
	)
	var path_cracked: Array[Vector2i] = MovementSystem.find_path(
		board_path, Vector2i(4, 3), Vector2i(5, 3), 2,
	)
	assert_true(
		failures, "seismic_stomp/cracked/find_path",
		path_cracked.size() == 1 and path_cracked[0] == Vector2i(5, 3),
		"find_path must reach cracked tile within 2 MP budget",
	)
	var path_blocked: Array[Vector2i] = MovementSystem.find_path(
		board_path, Vector2i(4, 3), Vector2i(6, 3), 2,
	)
	assert_true(
		failures, "seismic_stomp/cracked/find_path_blocked",
		path_blocked.is_empty(),
		"find_path must not reach goal beyond cracked terrain MP budget",
	)
	var corridor: Array[Vector2i] = MovementSystem.drag_corridor_path(
		board_path, Vector2i(4, 3), Vector2i(6, 3), 2, GameEnums.MovementType.WALK, 1, path_unit,
	)
	assert_true(
		failures, "seismic_stomp/cracked/drag_corridor",
		corridor.size() == 1 and corridor[0] == Vector2i(5, 3),
		"drag_corridor_path must respect cracked terrain MP budget",
	)
	var waypoints: Array[Vector2i] = [Vector2i(5, 3), Vector2i(6, 3)]
	var resolved: Array[Vector2i] = MovementSystem.resolve_move_path(
		board_path, path_unit, Vector2i(6, 3), waypoints, 2,
	)
	assert_true(
		failures, "seismic_stomp/cracked/waypoint_budget",
		resolved.is_empty(),
		"committed waypoints exceeding cracked terrain MP budget must be rejected",
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
	var charge_data: AbilityData = factory_ability(&"knight_bowling_charge")
	assert_true(
		failures, "bowling_charge/contract/dash",
		ability_has_effect(charge_data, GameEnums.EffectType.DASH, false),
	)
	assert_true(
		failures, "bowling_charge/contract/bulldoze",
		ability_has_effect(charge_data, GameEnums.EffectType.BULLDOZE, false),
	)
	assert_eq_int(
		failures,
		"bowling_charge/contract/dash_steps",
		AbilitySystem.effect_amount(charge_data, GameEnums.EffectType.DASH),
		3,
	)
	var board: BoardState = make_plain_board(Vector2i(12, 6))
	place_knight(board, 1, Vector2i(2, 3))
	place_dummy(board, 2, Vector2i(3, 3))
	var victim_hp_before: int = unit_hp(board, 2)
	var charge: AbilityData = ability_on_unit(unit_on_board(board, 1), &"knight_bowling_charge")
	var plan := Timeline.new()
	plan.add(plan_ability(1, charge, Vector2i(5, 3), -1))
	var result: SimResult = simulate_player_turn(board, plan)
	var knight: UnitState = result.final_state.get_unit_by_id(1)
	var victim: UnitState = result.final_state.get_unit_by_id(2)
	assert_true(
		failures, "bowling_charge/dash",
		knight != null and knight.position == Vector2i(5, 3),
		"bowling charge must DASH to target tile",
	)
	assert_true(
		failures, "bowling_charge/collision",
		events_have_collision_for_unit(result.events, 2),
		"BULLDOZE must emit collision on victim",
	)
	assert_true(
		failures, "bowling_charge/damage",
		victim != null and unit_hp(result.final_state, 2) < victim_hp_before,
		"bulldoze collision must damage victim",
	)
	assert_eq_cell(
		failures, "bowling_charge/push",
		victim.position if victim != null else Vector2i(-1, -1),
		Vector2i(3, 4),
	)
	var cfg_up: Dictionary = with_upgraded_ability({}, &"knight_bowling_charge")
	var board2: BoardState = make_plain_board(Vector2i(12, 6))
	place_knight(board2, 10, Vector2i(2, 3), cfg_up)
	place_dummy(board2, 11, Vector2i(4, 3))
	place_dummy(board2, 12, Vector2i(5, 3))
	var e1_hp: int = unit_hp(board2, 11)
	var e2_hp: int = unit_hp(board2, 12)
	var charge_up: AbilityData = ability_on_unit(unit_on_board(board2, 10), &"knight_bowling_charge")
	assert_true(
		failures, "bowling_charge/upgrade/effect",
		ability_has_effect(charge_up, GameEnums.EffectType.PUSH_CHAIN_COLLISION, true),
		"upgraded bowling charge must include PUSH_CHAIN_COLLISION",
	)
	var plan2 := Timeline.new()
	plan2.add(plan_ability(10, charge_up, Vector2i(4, 3), -1))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	assert_true(
		failures, "bowling_charge/upgrade/chain_collision",
		events_have_chain_collision(result2.events, 11, 12),
		"[+] must chain-push front enemy into rear enemy",
	)
	assert_true(
		failures, "bowling_charge/upgrade/chain_damage_front",
		unit_hp(result2.final_state, 11) < e1_hp,
		"[+] chain collision must damage pushed enemy",
	)
	assert_true(
		failures, "bowling_charge/upgrade/chain_damage_rear",
		unit_hp(result2.final_state, 12) < e2_hp,
		"[+] chain collision must damage blocking enemy",
	)
	var knight_up: UnitState = result2.final_state.get_unit_by_id(10)
	assert_eq_cell(
		failures, "bowling_charge/upgrade/knight_stop",
		knight_up.position if knight_up != null else Vector2i(-1, -1),
		Vector2i(3, 3),
	)
	var e1_after: UnitState = result2.final_state.get_unit_by_id(11)
	assert_eq_cell(
		failures, "bowling_charge/upgrade/front_pos",
		e1_after.position if e1_after != null else Vector2i(-1, -1),
		Vector2i(4, 3),
	)


static func run_iron_grip(failures: Array[String]) -> void:
	var board: BoardState = make_plain_board(Vector2i(10, 6))
	place_knight(board, 1, Vector2i(3, 3))
	place_dummy(board, 2, Vector2i(4, 3))
	var enemy_before: UnitState = unit_on_board(board, 2)
	var def_before: int = CombatSystem.get_dynamic_defense(board, enemy_before)
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
	assert_true(
		failures, "iron_grip/debuff",
		enemy != null and has_status(enemy, GameEnums.StatusType.IRON_GRIP_DEBUFF),
		"iron grip must apply IRON_GRIP_DEBUFF",
	)
	var def_after: int = CombatSystem.get_dynamic_defense(result.final_state, enemy)
	assert_eq_int(
		failures, "iron_grip/def_not_same_turn",
		def_after,
		def_before,
	)
	var advanced: SimResult = simulate_plan(result.final_state, Timeline.new())
	var enemy_next: UnitState = advanced.final_state.get_unit_by_id(2)
	var def_next_turn: int = CombatSystem.get_dynamic_defense(advanced.final_state, enemy_next)
	assert_eq_int(
		failures, "iron_grip/def_halved_next_turn",
		def_next_turn,
		int(ceil(def_before / 2.0)),
	)
	assert_eq_int(
		failures, "iron_grip/range",
		grip.range_tiles,
		1,
	)
	var board_mit: BoardState = result.final_state.clone()
	var loss_same_turn: int = damage_taken_on_unit(board_mit, 2, 30)
	var board_mit_next: BoardState = result.final_state.clone()
	var advanced_mit: SimResult = simulate_plan(board_mit_next, Timeline.new())
	var loss_next_turn: int = damage_taken_on_unit(advanced_mit.final_state, 2, 30)
	assert_true(
		failures, "iron_grip/mitigation_next_turn",
		loss_next_turn > loss_same_turn,
		"iron grip must increase damage taken after DEF halves on target next turn",
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
		failures, "iron_grip/upgrade/ap_refund_root",
		knight_after != null and knight_after.ability.points_left == ap_before,
		"upgraded iron grip must refund 1 AP when target already has ROOT",
	)
	var board_stag: BoardState = make_plain_board(Vector2i(10, 6))
	place_knight(board_stag, 12, Vector2i(3, 3), cfg_up)
	place_dummy(board_stag, 13, Vector2i(4, 3))
	var enemy_stag: UnitState = unit_on_board(board_stag, 13)
	enemy_stag.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAGGER, 1, 0))
	enemy_stag._recalculate_stats()
	var grip_stag: AbilityData = ability_on_unit(unit_on_board(board_stag, 12), &"knight_iron_grip")
	var knight_stag_before: UnitState = unit_on_board(board_stag, 12)
	var ap_stag_before: int = knight_stag_before.ability.points_left
	var plan_stag := Timeline.new()
	plan_stag.add(plan_ability(12, grip_stag, Vector2i(4, 3), 13))
	var result_stag: SimResult = simulate_player_turn(board_stag, plan_stag)
	var knight_stag_after: UnitState = result_stag.final_state.get_unit_by_id(12)
	assert_true(
		failures, "iron_grip/upgrade/ap_refund_stagger",
		knight_stag_after != null and knight_stag_after.ability.points_left == ap_stag_before,
		"upgraded iron grip must refund 1 AP when target already has STAGGER",
	)
	var board_no_cc: BoardState = make_plain_board(Vector2i(10, 6))
	place_knight(board_no_cc, 14, Vector2i(3, 3), cfg_up)
	place_dummy(board_no_cc, 15, Vector2i(4, 3))
	var grip_no_cc: AbilityData = ability_on_unit(unit_on_board(board_no_cc, 14), &"knight_iron_grip")
	var knight_no_cc_before: UnitState = unit_on_board(board_no_cc, 14)
	var ap_no_cc_before: int = knight_no_cc_before.ability.points_left
	var plan_no_cc := Timeline.new()
	plan_no_cc.add(plan_ability(14, grip_no_cc, Vector2i(4, 3), 15))
	var result_no_cc: SimResult = simulate_player_turn(board_no_cc, plan_no_cc)
	var knight_no_cc_after: UnitState = result_no_cc.final_state.get_unit_by_id(14)
	assert_eq_int(
		failures, "iron_grip/upgrade/no_refund_without_cc",
		knight_no_cc_after.ability.points_left,
		ap_no_cc_before - 1,
	)
	var board_base_ref: BoardState = make_plain_board(Vector2i(10, 6))
	place_knight(board_base_ref, 16, Vector2i(3, 3))
	place_dummy(board_base_ref, 17, Vector2i(4, 3))
	var enemy_base_pre: UnitState = unit_on_board(board_base_ref, 17)
	enemy_base_pre.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.ROOT, 1, 0))
	enemy_base_pre._recalculate_stats()
	var grip_base: AbilityData = ability_on_unit(unit_on_board(board_base_ref, 16), &"knight_iron_grip")
	var knight_base_before: UnitState = unit_on_board(board_base_ref, 16)
	var ap_base_before: int = knight_base_before.ability.points_left
	var plan_base := Timeline.new()
	plan_base.add(plan_ability(16, grip_base, Vector2i(4, 3), 17))
	var result_base: SimResult = simulate_player_turn(board_base_ref, plan_base)
	var knight_base_after: UnitState = result_base.final_state.get_unit_by_id(16)
	assert_eq_int(
		failures, "iron_grip/base/no_refund_on_cc",
		knight_base_after.ability.points_left,
		ap_base_before - 1,
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
	var board: BoardState = make_plain_board(Vector2i(12, 8))
	place_knight(board, 1, Vector2i(4, 4))
	var ally_def: UnitData = knight_unit_data()
	place_unit(board, 3, ally_def, GameEnums.Team.PLAYER, Vector2i(5, 4), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	place_enemy_basher(board, 5, Vector2i(3, 4))
	place_unit(board, 4, ally_def, GameEnums.Team.PLAYER, Vector2i(8, 4), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var knight: UnitState = unit_on_board(board, 1)
	var form: AbilityData = ability_on_unit(knight, &"knight_defensive_formation")
	var cast_action: TimelineAction = plan_ability(1, form, knight.position, knight.id)
	assert_true(
		failures, "defensive_formation/ability_system/can_use",
		AbilitySystem.can_use(board, cast_action),
		"AbilitySystem must allow defensive formation self-centered AOE cast",
	)
	var plan := Timeline.new()
	plan.add(plan_ability(1, form, Vector2i(4, 4), 1))
	var result: SimResult = simulate_player_turn(board, plan)
	var ally: UnitState = result.final_state.get_unit_by_id(3)
	var caster_after: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "defensive_formation/caster_no_sturdy",
		caster_after != null and not has_status(caster_after, GameEnums.StatusType.STURDY),
		"defensive formation must not grant STURDY to caster (allies only)",
	)
	assert_true(
		failures, "defensive_formation/caster_no_def",
		caster_after != null and not has_status(caster_after, GameEnums.StatusType.STAT_BUFF_DEF),
		"defensive formation must not grant DEF buff to caster (allies only)",
	)
	assert_true(
		failures, "defensive_formation/ally_sturdy",
		ally != null and has_status(ally, GameEnums.StatusType.STURDY),
		"defensive formation AOE must grant STURDY to nearby ally",
	)
	assert_true(
		failures, "defensive_formation/ally_def",
		ally != null and has_status(ally, GameEnums.StatusType.STAT_BUFF_DEF),
		"defensive formation AOE must grant DEF buff to nearby ally",
	)
	var def_amt: int = 0
	var sturdy_dur: int = 0
	for s: StatusData in ally.active_statuses if ally else []:
		if s.type == GameEnums.StatusType.STAT_BUFF_DEF:
			def_amt = s.value
		if s.type == GameEnums.StatusType.STURDY:
			sturdy_dur = s.duration
	assert_eq_int(
		failures, "defensive_formation/def_amount",
		def_amt,
		2,
	)
	assert_eq_int(
		failures, "defensive_formation/sturdy_duration",
		sturdy_dur,
		1,
	)
	var far_ally: UnitState = result.final_state.get_unit_by_id(4)
	assert_true(
		failures, "defensive_formation/out_of_aoe/no_sturdy",
		far_ally != null and not has_status(far_ally, GameEnums.StatusType.STURDY),
		"ally outside AOE must not gain STURDY",
	)
	assert_true(
		failures, "defensive_formation/out_of_aoe/no_def",
		far_ally != null and not has_status(far_ally, GameEnums.StatusType.STAT_BUFF_DEF),
		"ally outside AOE must not gain DEF buff",
	)
	var enemy_in_aoe: UnitState = result.final_state.get_unit_by_id(5)
	assert_true(
		failures, "defensive_formation/enemy_in_aoe/no_sturdy",
		enemy_in_aoe != null and not has_status(enemy_in_aoe, GameEnums.StatusType.STURDY),
		"enemy inside AOE must not gain STURDY (allies only)",
	)
	assert_true(
		failures, "defensive_formation/enemy_in_aoe/no_def",
		enemy_in_aoe != null and not has_status(enemy_in_aoe, GameEnums.StatusType.STAT_BUFF_DEF),
		"enemy inside AOE must not gain DEF buff (allies only)",
	)
	var board_push: BoardState = result.final_state.clone()
	place_enemy_basher(board_push, 99, Vector2i(6, 4))
	var bash: AbilityData = ability_on_unit(unit_on_board(board_push, 99), &"knight_shield_bash")
	var ally_pos_before: Vector2i = board_push.get_unit_by_id(3).position
	var plan_bash := Timeline.new()
	plan_bash.add(plan_ability(99, bash, Vector2i(5, 4), 3))
	var push_result: SimResult = simulate_plan(board_push, plan_bash)
	var ally_after_bash: UnitState = push_result.final_state.get_unit_by_id(3)
	assert_eq_cell(
		failures, "defensive_formation/sturdy_blocks_push",
		ally_after_bash.position if ally_after_bash else Vector2i(-1, -1),
		ally_pos_before,
	)
	var board_pull: BoardState = result.final_state.clone()
	place_unit(board_pull, 98, knight_unit_data(), GameEnums.Team.ENEMY, Vector2i(7, 4), {
		"active_abilities": [factory_ability(&"knight_chain_hook")],
	})
	var hook: AbilityData = ability_on_unit(unit_on_board(board_pull, 98), &"knight_chain_hook")
	var ally_pull_pos: Vector2i = board_pull.get_unit_by_id(3).position
	var plan_pull := Timeline.new()
	plan_pull.add(plan_ability(98, hook, Vector2i(5, 4), 3))
	var pull_result: SimResult = simulate_plan(board_pull, plan_pull)
	var ally_after_pull: UnitState = pull_result.final_state.get_unit_by_id(3)
	assert_eq_cell(
		failures, "defensive_formation/sturdy_blocks_pull",
		ally_after_pull.position if ally_after_pull else Vector2i(-1, -1),
		ally_pull_pos,
	)
	var advanced: SimResult = Simulator.simulate(result.final_state, Timeline.new())
	advanced = Simulator.simulate(advanced.final_state, Timeline.new())
	var ally_expired: UnitState = advanced.final_state.get_unit_by_id(3)
	assert_true(
		failures, "defensive_formation/sturdy_expires",
		ally_expired != null and not has_status(ally_expired, GameEnums.StatusType.STURDY),
		"STURDY must clear after 1 turn",
	)
	assert_true(
		failures, "defensive_formation/def_expires",
		ally_expired != null and not has_status(ally_expired, GameEnums.StatusType.STAT_BUFF_DEF),
		"DEF buff must clear after 1 turn",
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
	var caster_armor_before: int = unit_on_board(board2, 10).armor
	var plan2 := Timeline.new()
	plan2.add(plan_ability(10, form_up, Vector2i(4, 4), 10))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var ally2: UnitState = result2.final_state.get_unit_by_id(11)
	var caster_up: UnitState = result2.final_state.get_unit_by_id(10)
	assert_eq_int(
		failures, "defensive_formation/upgrade/caster_no_shield",
		caster_up.armor if caster_up else caster_armor_before,
		caster_armor_before,
	)
	assert_true(
		failures, "defensive_formation/upgrade/caster_no_sturdy",
		caster_up != null and not has_status(caster_up, GameEnums.StatusType.STURDY),
		"upgraded defensive formation must not grant STURDY to caster",
	)
	assert_true(
		failures, "defensive_formation/upgrade/caster_no_def",
		caster_up != null and not has_status(caster_up, GameEnums.StatusType.STAT_BUFF_DEF),
		"upgraded defensive formation must not grant DEF buff to caster",
	)
	assert_true(
		failures, "defensive_formation/upgrade/armor_up",
		ally2 != null and ally2.armor > ally_armor_before,
		"upgraded defensive formation must grant ARMOR_UP shield to ally",
	)
	assert_eq_int(
		failures, "defensive_formation/upgrade/shield_amount",
		ally2.armor - ally_armor_before,
		2,
	)
	assert_true(
		failures, "defensive_formation/upgrade/keeps_base_buffs",
		ally2 != null
		and has_status(ally2, GameEnums.StatusType.STURDY)
		and has_status(ally2, GameEnums.StatusType.STAT_BUFF_DEF),
		"upgraded defensive formation must still grant base DEF and STURDY",
	)


static func run_indomitable_will(failures: Array[String]) -> void:
	const MISSING_HP: int = 5
	var board: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board, 1, Vector2i(3, 3))
	var knight: UnitState = unit_on_board(board, 1)
	knight.health.current_hp = knight.health.max_hp - MISSING_HP
	var armor_before: int = knight.armor
	var ability: AbilityData = ability_on_unit(knight, &"knight_indomitable_will")
	var cast_action: TimelineAction = plan_ability(1, ability, knight.position, knight.id)
	assert_true(
		failures, "indomitable_will/ability_system/can_use_self",
		AbilitySystem.can_use(board, cast_action),
		"AbilitySystem must allow self-cast indomitable will",
	)
	var plan := Timeline.new()
	plan.add(plan_ability(1, ability, knight.position, knight.id))
	var result: SimResult = simulate_player_turn(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	assert_true(
		failures, "indomitable_will/shield",
		after != null and after.armor > armor_before,
		"indomitable will must convert missing HP into SHIELD",
	)
	assert_eq_int(
		failures, "indomitable_will/shield_amount",
		after.armor - armor_before,
		MISSING_HP,
	)
	assert_true(
		failures, "indomitable_will/self_status",
		after != null and has_status(after, GameEnums.StatusType.INDOMITABLE_WILL),
		"indomitable will must apply INDOMITABLE_WILL status",
	)
	var indo_duration: int = 0
	for s: StatusData in after.active_statuses if after else []:
		if s.type == GameEnums.StatusType.INDOMITABLE_WILL:
			indo_duration = s.duration
	assert_eq_int(
		failures, "indomitable_will/duration",
		indo_duration,
		2,
	)
	var advanced: SimResult = Simulator.simulate(result.final_state, Timeline.new())
	advanced = Simulator.simulate(advanced.final_state, Timeline.new())
	advanced = Simulator.simulate(advanced.final_state, Timeline.new())
	var expired: UnitState = advanced.final_state.get_unit_by_id(1)
	assert_true(
		failures, "indomitable_will/status_expires",
		expired != null and not has_status(expired, GameEnums.StatusType.INDOMITABLE_WILL),
		"INDOMITABLE_WILL must expire after 2 turns",
	)
	assert_eq_int(
		failures, "indomitable_will/shield_cleared_on_expire",
		expired.armor,
		0,
	)
	var base_str: int = 0
	for s: StatusData in expired.active_statuses if expired else []:
		if s.type == GameEnums.StatusType.STAT_BUFF_STR:
			base_str += s.value
	assert_eq_int(
		failures, "indomitable_will/base/no_str_on_expire",
		base_str,
		0,
	)
	var board_base_break: BoardState = result.final_state.clone()
	damage_taken_pierce(board_base_break, 1, MISSING_HP)
	var broken_base: UnitState = board_base_break.get_unit_by_id(1)
	assert_eq_int(
		failures, "indomitable_will/base/shield_break_clears_armor",
		broken_base.armor,
		0,
	)
	assert_true(
		failures, "indomitable_will/base/shield_break_clears_status",
		broken_base != null and not has_status(broken_base, GameEnums.StatusType.INDOMITABLE_WILL),
		"breaking base indomitable shield must remove INDOMITABLE_WILL status",
	)
	var base_break_str: int = 0
	for s: StatusData in broken_base.active_statuses if broken_base else []:
		if s.type == GameEnums.StatusType.STAT_BUFF_STR:
			base_break_str += s.value
	assert_eq_int(
		failures, "indomitable_will/base/no_str_on_shield_break",
		base_break_str,
		0,
	)
	var cfg: Dictionary = with_upgraded_ability({}, &"knight_indomitable_will")
	var board2: BoardState = make_plain_board(Vector2i(8, 8))
	place_knight(board2, 10, Vector2i(3, 3), cfg)
	var knight2: UnitState = unit_on_board(board2, 10)
	knight2.health.current_hp = knight2.health.max_hp - MISSING_HP
	var ability2: AbilityData = ability_on_unit(knight2, &"knight_indomitable_will")
	var plan2 := Timeline.new()
	plan2.add(plan_ability(10, ability2, knight2.position, knight2.id))
	var result2: SimResult = simulate_player_turn(board2, plan2)
	var after2: UnitState = result2.final_state.get_unit_by_id(10)
	assert_true(
		failures, "indomitable_will/upgrade/status",
		after2 != null and has_status(after2, GameEnums.StatusType.INDOMITABLE_WILL_UPGRADED),
		"upgraded indomitable will must apply INDOMITABLE_WILL_UPGRADED",
	)
	assert_eq_int(
		failures, "indomitable_will/upgrade/shield_amount",
		after2.armor,
		MISSING_HP,
	)
	var advanced_up: SimResult = Simulator.simulate(result2.final_state, Timeline.new())
	advanced_up = Simulator.simulate(advanced_up.final_state, Timeline.new())
	advanced_up = Simulator.simulate(advanced_up.final_state, Timeline.new())
	var expired_up: UnitState = advanced_up.final_state.get_unit_by_id(10)
	assert_true(
		failures, "indomitable_will/upgrade/status_expires",
		expired_up != null and not has_status(expired_up, GameEnums.StatusType.INDOMITABLE_WILL_UPGRADED),
		"upgraded INDOMITABLE_WILL must expire after 2 turns",
	)
	assert_eq_int(
		failures, "indomitable_will/upgrade/shield_cleared_on_expire",
		expired_up.armor,
		0,
	)
	var up_str: int = 0
	for s: StatusData in expired_up.active_statuses if expired_up else []:
		if s.type == GameEnums.StatusType.STAT_BUFF_STR:
			up_str += s.value
	assert_eq_int(
		failures, "indomitable_will/upgrade/str_on_expire",
		up_str,
		2,
	)
	var board_break: BoardState = result2.final_state.clone()
	damage_taken_pierce(board_break, 10, MISSING_HP)
	var broken: UnitState = board_break.get_unit_by_id(10)
	assert_eq_int(
		failures, "indomitable_will/upgrade/shield_break_clears_armor",
		broken.armor,
		0,
	)
	assert_true(
		failures, "indomitable_will/upgrade/shield_break_clears_status",
		broken != null and not has_status(broken, GameEnums.StatusType.INDOMITABLE_WILL_UPGRADED),
		"breaking upgraded indomitable shield must remove INDOMITABLE_WILL_UPGRADED status",
	)
	var break_str: int = 0
	for s: StatusData in broken.active_statuses if broken else []:
		if s.type == GameEnums.StatusType.STAT_BUFF_STR:
			break_str += s.value
	assert_eq_int(
		failures, "indomitable_will/upgrade/shield_break_grants_str",
		break_str,
		2,
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
	## Bible: allies behind immune to ranged; [+] allies behind +1 DEF.
	var board: BoardState = make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = with_single_passive(&"living_barricade", false)
	place_knight(board, 1, Vector2i(4, 3), cfg)
	unit_on_board(board, 1).facing = GameEnums.Facing.EAST
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
	var cfg_up: Dictionary = with_single_passive(&"living_barricade", true)
	var board_def: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board_def, 10, Vector2i(4, 3), cfg_up)
	unit_on_board(board_def, 10).facing = GameEnums.Facing.EAST
	place_unit(board_def, 11, ally_def, GameEnums.Team.PLAYER, Vector2i(3, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var board_iso: BoardState = make_plain_board(Vector2i(10, 8))
	place_unit(board_iso, 20, ally_def, GameEnums.Team.PLAYER, Vector2i(3, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	var def_iso: int = CombatSystem.get_dynamic_defense(board_iso, unit_on_board(board_iso, 20))
	var def_behind: int = CombatSystem.get_dynamic_defense(
		board_def, unit_on_board(board_def, 11),
	)
	assert_eq_int(
		failures, "living_barricade/upgrade/ally_def_behind",
		def_behind - def_iso,
		1,
	)
	var loss_behind: int = damage_taken_on_unit(board_def, 11, 12)
	assert_true(
		failures, "living_barricade/upgrade/def_reduces_damage",
		loss_behind < damage_taken_on_unit(board_iso, 20, 12),
		"upgraded living barricade ally behind must take less damage via +1 DEF",
	)
	var board_exposed: BoardState = make_plain_board(Vector2i(10, 8))
	place_knight(board_exposed, 30, Vector2i(4, 3), cfg)
	unit_on_board(board_exposed, 30).facing = GameEnums.Facing.WEST
	place_unit(board_exposed, 31, ally_def, GameEnums.Team.PLAYER, Vector2i(5, 3), {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	place_enemy_artillery(board_exposed, 32, Vector2i(7, 3))
	var hp_exposed_before: int = unit_on_board(board_exposed, 31).health.current_hp
	var bolt_exposed: AbilityData = unit_on_board(board_exposed, 32).active_abilities[0]
	var plan_exposed := Timeline.new()
	plan_exposed.add(plan_ability(32, bolt_exposed, Vector2i(5, 3), 31))
	var result_exposed: SimResult = simulate_player_turn(board_exposed, plan_exposed)
	var ally_exposed: UnitState = result_exposed.final_state.get_unit_by_id(31)
	assert_true(
		failures, "living_barricade/no_block_wrong_facing",
		ally_exposed != null and ally_exposed.health.current_hp < hp_exposed_before,
		"ally not behind knight facing must not be protected from ranged fire",
	)

