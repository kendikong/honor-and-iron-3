class_name MercenaryQaHarness
extends RefCounted


const ABILITY_IDS: Array[StringName] = [
	&"mercenary_pullback",
	&"mercenary_swift_strike",
	&"mercenary_defense_strike",
	&"mercenary_blade_storm",
	&"mercenary_caltrop_toss",
	&"mercenary_feint",
	&"mercenary_riposte_strike",
	&"mercenary_sever",
	&"mercenary_second_wind",
	&"mercenary_tactical_retreat",
	&"mercenary_executioners_blade",
	&"mercenary_precision_strike",
	&"mercenary_flank_and_run",
	&"mercenary_hamstring",
	&"mercenary_acrobatic_vault",
	&"mercenary_duelists_challenge",
]

const PASSIVE_ROWS: Array[Dictionary] = [
	{"id": &"predatory_momentum", "keys": [&"predatory_momentum", &"predatory_threshold"]},
	{"id": &"calculated_strike", "keys": [&"movement_before_attack_strength"]},
	{"id": &"weapon_master", "keys": [&"strength_over_def_ignore_pct"]},
	{"id": &"dual_wield_momentum", "keys": [&"active_skill_bonus_basic_attack"]},
	{"id": &"precision_edge", "keys": [&"full_hp_attack_bonus"]},
	{"id": &"duelists_focus", "keys": [&"unacted_attack_bonus"]},
	{"id": &"tactical_versatility", "keys": [&"active_next_basic_bonus"]},
	{"id": &"swift_feet", "keys": [&"adjacent_enemy_move"]},
	{"id": &"hit_and_run", "keys": [&"after_damage_move"]},
	{"id": &"evasive", "keys": [&"moved_tiles_evasive_threshold"]},
	{"id": &"flanking_maneuver", "keys": [&"isolated_attack_strength"]},
	{"id": &"dirty_fighting", "keys": [&"controlled_target_attack_bonus"]},
	{"id": &"executioner", "keys": [&"executioner_threshold"]},
	{"id": &"blood_scent", "keys": [&"blood_scent_threshold"]},
	{"id": &"ruthless", "keys": [&"kill_next_attack_bonus"]},
	{"id": &"coup_de_grace", "keys": [&"basic_kill_heal"]},
]


static func run_factory_matrix(failures: Array[String]) -> void:
	var mercenary := FactoryTestHelpers.build_unit(&"mercenary")
	_assert(failures, "factory/mercenary_registered", mercenary != null)
	if mercenary == null:
		return
	_assert(failures, "factory/base_constitution", mercenary.base_constitution == 5)
	_assert(failures, "factory/base_movement", mercenary.move_points == 4)
	_assert(failures, "factory/base_strength", mercenary.base_strength == 4)
	_assert(failures, "factory/base_defense", mercenary.base_defense == 3)
	_assert(failures, "factory/innate_count", mercenary.innate_passives.size() == 1)
	_assert(failures, "factory/active_count", mercenary.abilities.size() == 17)
	_assert(failures, "factory/promotion_passive_count", mercenary.passives.size() == 15)
	_assert(
		failures,
		"factory/promotion_stats",
		mercenary.promotion_stat_bonuses.get(&"swordmaster", {}).get("strength", -1) == 4
		and mercenary.promotion_stat_bonuses.get(&"blade_dancer", {}).get("movement", -1) == 2
		and mercenary.promotion_stat_bonuses.get(&"headhunter", {}).get("defense", -1) == 2,
	)
	for ability_id: StringName in ABILITY_IDS:
		var ability := _ability(mercenary, ability_id)
		_assert(failures, "factory/ability/%s" % ability_id, ability != null)
		if ability == null:
			continue
		_assert(
			failures,
			"factory/upgrade/%s" % ability_id,
			not ability.upgraded_modules.is_empty() and not ability.upgrade_description.is_empty(),
		)
	_check_passives(mercenary, failures)


static func run_live_skill_resolution(failures: Array[String]) -> void:
	for ability_id: StringName in ABILITY_IDS:
		_run_ability(ability_id, failures, false)


static func run_upgrade_sim_for(ability_id: StringName, failures: Array[String]) -> void:
	_run_ability(ability_id, failures, true)


static func run_skill_scenario(ability_id: StringName, failures: Array[String]) -> void:
	_run_ability(ability_id, failures, false)
	_run_ability(ability_id, failures, true)


static func run_passive_scenario(passive_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"mercenary")
	var passive := _passive(definition, passive_id)
	_assert(failures, "scenario/%s/registered" % passive_id, passive != null)
	if passive == null:
		return
	_assert(
		failures,
		"scenario/%s/description" % passive_id,
		not passive.description.is_empty() and not passive.upgraded_description.is_empty(),
	)
	_assert(
		failures,
		"scenario/%s/modifiers" % passive_id,
		not passive.modifiers.is_empty(),
	)


static func run_core_passive_triggers(failures: Array[String]) -> void:
	var mercenary := FactoryTestHelpers.build_unit(&"mercenary")
	if mercenary == null:
		return
	for row: Dictionary in PASSIVE_ROWS:
		var passive := _passive(mercenary, row.id)
		_assert(failures, "passive/%s/registered" % row.id, passive != null)
		if passive == null:
			continue
		for key: StringName in row.keys:
			_assert(
				failures,
				"passive/%s/%s" % [row.id, key],
				passive.modifiers.has(key),
			)


static func _check_passives(mercenary: UnitData, failures: Array[String]) -> void:
	for row: Dictionary in PASSIVE_ROWS:
		var passive := _passive(mercenary, row.id)
		_assert(failures, "factory/passive/%s" % row.id, passive != null)
		if passive == null:
			continue
		for key: StringName in row.keys:
			_assert(
				failures,
				"factory/passive/%s/%s" % [row.id, key],
				passive.modifiers.has(key),
			)


static func _run_ability(ability_id: StringName, failures: Array[String], upgraded: bool) -> void:
	var definition := FactoryTestHelpers.build_unit(&"mercenary")
	var ability := _ability(definition, ability_id)
	_assert(failures, "resolve/%s/ability" % ability_id, ability != null)
	if ability == null:
		return
	var board := _plain_board(Vector2i(12, 10))
	var actor := UnitState.create(
		1,
		definition,
		GameEnums.Team.PLAYER,
		Vector2i(3, 4),
		{"active_abilities": [ability], "active_passives": definition.passives + definition.innate_passives},
	)
	board.add_unit(actor)
	GridSystem.set_occupant(board, actor.position, actor.id)
	if upgraded:
		actor.upgraded_abilities.append(ability_id)
	var target_coord := _target_for(ability_id)
	var target_id := -1
	if _needs_enemy(ability_id) or ability_id in [
		&"mercenary_pullback",
		&"mercenary_flank_and_run",
	]:
		var enemy_coord := target_coord
		if ability_id == &"mercenary_pullback":
			enemy_coord = Vector2i(4, 4)
		elif ability_id == &"mercenary_flank_and_run":
			enemy_coord += Vector2i(1, 0)
		var dummy := UnitState.create(
			2,
			DataLibrary.get_training_dummy(),
			GameEnums.Team.ENEMY,
			enemy_coord,
		)
		board.add_unit(dummy)
		GridSystem.set_occupant(board, enemy_coord, dummy.id)
		target_id = dummy.id if ability_id not in [
			&"mercenary_pullback",
			&"mercenary_flank_and_run",
		] else -1
	actor.ability.points_left = maxi(actor.ability.max_points, 1)
	actor.movement.points_left = maxi(actor.movement.max_points, 8)
	var action := TimelineAction.make_ability(actor.id, ability, target_coord, target_id)
	_assert(failures, "resolve/%s/can_use" % ability_id, AbilitySystem.can_use(board, action))
	if not AbilitySystem.can_use(board, action):
		return
	var plan := Timeline.new()
	plan.add(action)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	_assert(
		failures,
		"resolve/%s/ability_used" % ability_id,
		_events_have_ability(events, ability_id),
	)
	_assert(
		failures,
		"resolve/%s/no_action_failure" % ability_id,
		not _has_action_failure(events, actor.id),
	)


static func _plain_board(size: Vector2i) -> BoardState:
	var board := BoardState.new()
	board.grid_size = size
	var plain := DataLibrary.get_terrain(&"plain")
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	return board


static func _target_for(ability_id: StringName) -> Vector2i:
	match ability_id:
		&"mercenary_pullback":
			return Vector2i(2, 4)
		&"mercenary_tactical_retreat":
			return Vector2i(1, 4)
		&"mercenary_flank_and_run":
			return Vector2i(5, 4)
		&"mercenary_second_wind", &"mercenary_feint":
			return Vector2i(3, 4)
		_:
			return Vector2i(4, 4)


static func _needs_enemy(ability_id: StringName) -> bool:
	return ability_id not in [
		&"mercenary_pullback",
		&"mercenary_tactical_retreat",
		&"mercenary_second_wind",
		&"mercenary_feint",
	]


static func _ability(definition: UnitData, ability_id: StringName) -> AbilityData:
	if definition == null:
		return null
	for ability: AbilityData in definition.abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


static func _passive(definition: UnitData, passive_id: StringName) -> PassiveData:
	if definition == null:
		return null
	for passive: PassiveData in definition.passives + definition.innate_passives:
		if passive != null and passive.id == passive_id:
			return passive
	return null


static func _events_have_ability(events: Array[SimEvent], ability_id: StringName) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ABILITY_USED \
				and event.data.get("ability") == ability_id:
			return true
	return false


static func _has_action_failure(events: Array[SimEvent], actor_id: int) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ACTION_FAILED \
				and int(event.data.get("actor", -1)) == actor_id:
			return true
	return false


static func _assert(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func assert_true(
	failures: Array[String], tag: String, condition: bool, message: String = "",
) -> void:
	if not condition:
		failures.append("%s: %s" % [tag, message if not message.is_empty() else "assertion failed"])


static func assert_eq_int(failures: Array[String], tag: String, got: int, expected: int) -> void:
	if got != expected:
		failures.append("%s: expected %d got %d" % [tag, expected, got])


static func assert_eq_cell(
	failures: Array[String], tag: String, got: Vector2i, expected: Vector2i,
) -> void:
	if got != expected:
		failures.append("%s: expected %s got %s" % [tag, expected, got])


static func mercenary_unit_data() -> UnitData:
	return FactoryTestHelpers.build_unit(&"mercenary")


static func factory_ability(ability_id: StringName) -> AbilityData:
	var def := mercenary_unit_data()
	return _ability(def, ability_id)


static func factory_passive(passive_id: StringName) -> PassiveData:
	var def := mercenary_unit_data()
	return _passive(def, passive_id)


static func mercenary_with_ability(ability_id: StringName, upgraded: bool = false) -> Dictionary:
	var def := mercenary_unit_data()
	var abilities: Array = [_basic_attack_for(def), factory_ability(ability_id)]
	var cfg: Dictionary = {
		"active_abilities": abilities,
		"active_passives": def.passives + def.innate_passives,
	}
	if upgraded:
		cfg["upgraded_abilities"] = [ability_id]
	return cfg


static func mercenary_with_passive(passive_id: StringName, upgraded: bool = false) -> Dictionary:
	var def := mercenary_unit_data()
	var passives: Array = []
	for p: PassiveData in def.innate_passives + def.passives:
		if p != null and p.id == passive_id:
			passives.append(p)
	var cfg: Dictionary = {
		"active_abilities": [_basic_attack_for(def)],
		"active_passives": passives,
	}
	if upgraded:
		cfg["upgraded_passives"] = [passive_id]
	return cfg


static func _basic_attack_for(definition: UnitData) -> AbilityData:
	if definition == null:
		return null
	for ab: AbilityData in definition.abilities:
		if ab != null and (ab.id == &"basic_attack" or String(ab.id).ends_with("_basic")):
			return ab
	return null


static func with_upgraded_passive(cfg: Dictionary, passive_id: StringName) -> Dictionary:
	var out := cfg.duplicate(true)
	var upgraded: Array = out.get("upgraded_passives", [])
	if passive_id not in upgraded:
		upgraded.append(passive_id)
	out["upgraded_passives"] = upgraded
	return out


static func hp_loss_from_plan(board: BoardState, plan: Timeline, unit_id: int) -> int:
	var before: int = unit_hp(board, unit_id)
	var result: SimResult = simulate_plan(board, plan)
	return before - unit_hp(result.final_state, unit_id)


static func events_ability_count(events: Array, ability_id: StringName) -> int:
	var count := 0
	for raw: Variant in events:
		if raw is SimEvent and raw.type == GameEnums.SimEventType.ABILITY_USED:
			if raw.data.get("ability") == ability_id:
				count += 1
	return count


static func count_event_type(events: Array, event_type: GameEnums.SimEventType) -> int:
	var count := 0
	for raw: Variant in events:
		if raw is SimEvent and raw.type == event_type:
			count += 1
	return count


static func basic_attack_for_unit(unit: UnitState) -> AbilityData:
	for ab: AbilityData in unit.active_abilities:
		if ab != null and AbilitySystem._is_basic_attack(ab):
			return ab
	return null


static func buff_dummy_defense(board: BoardState, unit_id: int, bonus: int) -> void:
	var unit := board.get_unit_by_id(unit_id)
	if unit == null:
		return
	unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, bonus))
	unit._recalculate_stats(board)


static func buff_merc_strength(board: BoardState, unit_id: int, bonus: int) -> void:
	var unit := board.get_unit_by_id(unit_id)
	if unit == null:
		return
	unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, bonus))
	unit._recalculate_stats(board)


static func with_upgraded_ability(cfg: Dictionary, ability_id: StringName) -> Dictionary:
	var out := cfg.duplicate(true)
	var upgraded: Array = out.get("upgraded_abilities", [])
	if ability_id not in upgraded:
		upgraded.append(ability_id)
	out["upgraded_abilities"] = upgraded
	return out


static func make_plain_board(size: Vector2i) -> BoardState:
	return _plain_board(size)


static func place_mercenary(
	board: BoardState, unit_id: int, pos: Vector2i, cfg: Dictionary = {},
) -> UnitState:
	var def := mercenary_unit_data()
	var unit := UnitState.create(unit_id, def, GameEnums.Team.PLAYER, pos, cfg)
	unit.ability.points_left = unit.ability.max_points
	unit.movement.points_left = unit.movement.max_points
	board.add_unit(unit)
	GridSystem.set_occupant(board, pos, unit_id)
	return unit


static func place_dummy(board: BoardState, unit_id: int, pos: Vector2i) -> UnitState:
	var dummy := UnitState.create(
		unit_id, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, pos,
	)
	board.add_unit(dummy)
	GridSystem.set_occupant(board, pos, unit_id)
	return dummy


static func unit_on_board(board: BoardState, unit_id: int) -> UnitState:
	return board.get_unit_by_id(unit_id)


static func unit_hp(board: BoardState, unit_id: int) -> int:
	var unit := board.get_unit_by_id(unit_id)
	return unit.health.current_hp if unit != null else 0


static func ability_on_unit(unit: UnitState, ability_id: StringName) -> AbilityData:
	for ab: AbilityData in unit.active_abilities:
		if ab != null and ab.id == ability_id:
			return ab
	return null


static func plan_ability(
	unit_id: int,
	ability: AbilityData,
	target: Vector2i,
	target_unit_id: int = -1,
	timing: GameEnums.MoveTiming = GameEnums.MoveTiming.PRE_ACTION,
) -> TimelineAction:
	return TimelineAction.make_ability(unit_id, ability, target, target_unit_id, timing)


static func simulate_plan(board: BoardState, plan: Timeline) -> SimResult:
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	var out := SimResult.new()
	out.final_state = board
	out.events = events
	return out


static func has_status(unit: UnitState, status_type: GameEnums.StatusType) -> bool:
	return unit != null and unit.has_status(status_type)


static func events_actor_moved(events: Array, actor_id: int) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.UNIT_MOVED:
			if int(e.data.get("unit", -1)) == actor_id:
				return true
	return false


static func has_action_failure(events: Array, actor_id: int) -> bool:
	for e: Variant in events:
		if e is SimEvent and e.type == GameEnums.SimEventType.ACTION_FAILED:
			if int(e.data.get("actor", -1)) == actor_id:
				return true
	return false
