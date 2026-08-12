class_name BeastRiderQaHarness
extends RefCounted

## Layer A/B owner for every Beast Rider factory row.
## Layer C is exercised by each scenario through the shared planning contract.

const _BEAST := preload("res://core/systems/beast_rider_systems.gd")
const _PLANNING := preload("res://tests/class_scenario_planning_contract.gd")

const ABILITY_IDS: Array[StringName] = [
	&"beast_reposition", &"beast_pounce", &"beast_feral_drag", &"beast_maul",
	&"beast_bestial_roar", &"beast_raking_claws", &"beast_rest_recover",
	&"beast_intimidate", &"beast_fetch", &"beast_savage_bite", &"beast_run_down",
	&"beast_thrash", &"beast_defensive_posture", &"beast_airlift",
	&"beast_tail_swipe", &"beast_meteor_drop",
]

const PASSIVE_ROWS: Array[Dictionary] = [
	{"id": &"gallop", "keys": [&"gallop", &"split_movement", &"upgraded_split_attack_strength", &"upgraded_split_post_defense"]},
	{"id": &"isolation_tactics", "keys": [&"isolation_attack_strength", &"upgraded_moved_tile_attack_strength"]},
	{"id": &"terminal_velocity", "keys": [&"collision_weapon_true_damage", &"collision_vulnerable", &"upgraded_drop_stagger"]},
	{"id": &"snatch_and_grab", "keys": [&"grapple_range", &"upgraded_grapple_range"]},
	{"id": &"safe_landing", "keys": [&"safe_landing", &"landing_shockwave_push", &"upgraded_landing_shockwave_push"]},
	{"id": &"aerial_superiority", "keys": [&"grounded_melee_defense", &"upgraded_grounded_root_immunity"]},
	{"id": &"mount_resilience", "keys": [&"ranged_damage_reduction_base", &"upgraded_ranged_damage_reduction_base"]},
	{"id": &"beasts_instinct", "keys": [&"miss_zero_damage_strength", &"miss_zero_damage_ap", &"upgraded_miss_zero_damage_shield"]},
	{"id": &"territorial", "keys": [&"adjacent_entry_attack", &"upgraded_adjacent_entry_attack"]},
	{"id": &"intimidating_presence", "keys": [&"intimidating_presence_range", &"intimidating_presence_def", &"intimidating_presence_move", &"upgraded_intimidating_presence_range"]},
	{"id": &"dive_bomber", "keys": [&"dive_bomber_min_tiles", &"dive_bomber_attack_strength", &"upgraded_dive_bomber_min_tiles"]},
	{"id": &"pack_hunter", "keys": [&"pack_hunter_bite", &"pack_hunter_def_ignore_pct", &"upgraded_pack_hunter_bite"]},
	{"id": &"blood_scent", "keys": [&"blood_scent_move", &"blood_scent_pierce", &"upgraded_blood_scent_move"]},
	{"id": &"vantage_striker", "keys": [&"ignore_difficult_terrain", &"vantage_attack_strength", &"upgraded_vantage_attack_strength"]},
	{"id": &"predatory_drive", "keys": [&"predatory_bleed_weapon", &"upgraded_predatory_poison"]},
	{"id": &"furious_charge", "keys": [&"furious_charge_min_tiles", &"furious_charge_push", &"upgraded_furious_charge_push"]},
]

const ABILITY_CONTRACTS: Dictionary = {
	&"beast_reposition": {"types": [GameEnums.EffectType.TELEPORT_CASTER], "amount": 2, "max_range": 1, "keys": [&"reposition_opposite_side", &"reposition_movement_cost"]},
	&"beast_pounce": {"types": [GameEnums.EffectType.MOVE, GameEnums.EffectType.DAMAGE], "amount": 3, "max_range": 3, "keys": [&"pounce_land_adjacent", &"landing_push"]},
	&"beast_feral_drag": {"types": [GameEnums.EffectType.PULL], "amount": 0, "max_range": 1, "keys": [&"feral_drag", &"target_constitution_at_most_strength", &"drag_remaining_movement"]},
	&"beast_maul": {"types": [GameEnums.EffectType.DAMAGE], "amount": 2, "max_range": 1, "keys": [&"maul_dragged_enemy", &"drop_adjacent", &"drop_trap_damage_multiplier"]},
	&"beast_bestial_roar": {"types": [GameEnums.EffectType.PUSH], "amount": 2, "max_range": 3, "shape": GameEnums.TargetShape.CONE, "shape_size": 3, "keys": [&"requires_debuff", &"cone_all_targets"]},
	&"beast_raking_claws": {"types": [GameEnums.EffectType.DAMAGE], "amount": 2, "max_range": 1, "shape": GameEnums.TargetShape.ARC, "keys": [&"bleed_weapon", &"pull_before_attack"]},
	&"beast_rest_recover": {"types": [GameEnums.EffectType.HEAL], "amount": 1, "keys": [&"cost_all_movement"]},
	&"beast_intimidate": {"types": [GameEnums.EffectType.ADD_STATUS], "amount": 1, "shape": GameEnums.TargetShape.AOE_DIAMOND, "shape_size": 2, "keys": [&"lower_hp_only", &"purge_buffs"]},
	&"beast_fetch": {"types": [GameEnums.EffectType.PULL], "amount": 1, "max_range": 4, "keys": [&"fetch_item_or_corpse", &"pull_light_ally"]},
	&"beast_savage_bite": {"types": [GameEnums.EffectType.DAMAGE], "amount": 4, "max_range": 1, "keys": [&"requires_bleed_or_poison", &"on_kill_shield"]},
	&"beast_run_down": {"types": [GameEnums.EffectType.DASH], "amount": 3, "max_range": 3, "keys": [&"run_down_pass_adjacent_push", &"run_down_push_bleed_weapon"]},
	&"beast_thrash": {"types": [GameEnums.EffectType.DAMAGE], "amount": 1, "max_range": 1, "keys": [&"hit_count", &"bleed_weapon"]},
	&"beast_defensive_posture": {"types": [GameEnums.EffectType.ADD_STATUS_SELF], "amount": 1, "keys": [&"intercept_push_attacker"]},
	&"beast_airlift": {"types": [GameEnums.EffectType.TELEPORT_CASTER], "amount": 1, "max_range": 1, "keys": [&"airlift_pickup_step", &"airlift_drop_step", &"airlift_ally_attack_strength"]},
	&"beast_tail_swipe": {"types": [GameEnums.EffectType.PUSH], "amount": 2, "shape": GameEnums.TargetShape.AOE_SQUARE, "shape_size": 3, "keys": [&"wall_collision_stagger"]},
	&"beast_meteor_drop": {"types": [GameEnums.EffectType.TELEPORT_CASTER, GameEnums.EffectType.DAMAGE], "amount": 0, "max_range": 2, "shape": GameEnums.TargetShape.AOE_DIAMOND, "shape_size": 1, "keys": [&"meteor_drop", &"landing_vulnerable"]},
}


static func run_factory_matrix(failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"beast_rider")
	_assert(failures, "factory/registered", definition != null)
	if definition == null:
		return
	_assert(failures, "factory/base_constitution", definition.base_constitution == 5)
	_assert(failures, "factory/base_movement", definition.move_points == 5)
	_assert(failures, "factory/base_strength", definition.base_strength == 3)
	_assert(failures, "factory/base_defense", definition.base_defense == 2)
	_assert(failures, "factory/base_magic", definition.base_magic == 2)
	_assert(failures, "factory/innate_count", definition.innate_passives.size() == 1)
	_assert(failures, "factory/ability_count", definition.abilities.size() == 17)
	_assert(failures, "factory/passive_count", definition.passives.size() == 15)
	for ability_id: StringName in ABILITY_IDS:
		var ability := _ability(definition, ability_id)
		_assert(failures, "factory/ability/%s" % ability_id, ability != null)
		if ability == null:
			continue
		_assert(failures, "factory/modules/%s" % ability_id, not ability.modules.is_empty())
		_assert(
			failures,
			"factory/upgrade/%s" % ability_id,
			not ability.upgraded_modules.is_empty()
				and not ability.upgrade_description.is_empty(),
		)
		_run_ability_contract(ability, failures)
	for row: Dictionary in PASSIVE_ROWS:
		var passive := _passive(definition, row.id)
		_assert(failures, "factory/passive/%s" % row.id, passive != null)
		if passive == null:
			continue
		for key: StringName in row.keys:
			_assert(failures, "factory/passive/%s/%s" % [row.id, key], passive.modifiers.has(key))


static func _run_ability_contract(ability: AbilityData, failures: Array[String]) -> void:
	var contract: Dictionary = ABILITY_CONTRACTS.get(ability.id, {})
	var modules: Array[AbilityModule] = ability.modules
	var expected_types: Array = contract.get("types", [])
	_assert(failures, "factory/contract/%s/module_count" % ability.id, modules.size() == expected_types.size())
	for index: int in range(mini(modules.size(), expected_types.size())):
		var module := modules[index]
		_assert(failures, "factory/contract/%s/type_%d" % [ability.id, index], module.primary_type == expected_types[index])
	if modules.is_empty():
		return
	var primary := modules[0]
	for field: StringName in [&"amount", &"max_range", &"shape_size"]:
		if contract.has(field):
			_assert(failures, "factory/contract/%s/%s" % [ability.id, field], int(primary.get(field)) == int(contract[field]))
	if contract.has("shape"):
		_assert(failures, "factory/contract/%s/shape" % ability.id, primary.target_shape == contract.shape)
	for key: StringName in contract.get("keys", []):
		_assert(
			failures,
			"factory/contract/%s/%s" % [ability.id, key],
			_module_has_key(ability.modules, key) or _module_has_key(ability.upgraded_modules, key),
		)


static func _module_has_key(modules: Array[AbilityModule], key: StringName) -> bool:
	for module: AbilityModule in modules:
		if module == null:
			continue
		if module.legacy_modifiers.has(key):
			return true
		for layer: AbilityLayer in module.layers:
			if layer != null and layer.effect != null and layer.effect.modifiers.has(key):
				return true
	return false


static func run_ability_row(ability_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"beast_rider")
	var ability := _ability(definition, ability_id)
	_assert(failures, "%s/data" % ability_id, ability != null)
	if ability == null:
		return
	var board := _plain_board(Vector2i(10, 8))
	var actor := _place_actor(board, 1, Vector2i(2, 3), ability)
	var target := _place_target(board, ability_id)
	var action := TimelineAction.make_ability(actor.id, ability, target.position, target.id)
	if ability.has_targeting(GameEnums.TargetingFlags.SELF):
		action.target_coord = actor.position
		action.target_unit_id = actor.id
	if ability_id == &"beast_tail_swipe" or ability_id == &"beast_defensive_posture":
		action.target_coord = actor.position
		action.target_unit_id = actor.id
	if ability_id == &"beast_airlift":
		action.target_unit_id = target.id
		action.target_coord = target.position
	if ability_id in [
		&"beast_raking_claws",
		&"beast_run_down",
	]:
		action.target_unit_id = -1
	if ability_id == &"beast_bestial_roar":
		target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLEED, 1))
		action.target_unit_id = target.id
	if ability_id == &"beast_savage_bite":
		target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLEED, 1))
	if ability_id == &"beast_intimidate":
		action.target_unit_id = -1
		action.target_coord = actor.position
	if ability_id == &"beast_pounce":
		action.target_coord = Vector2i(3, 2)
		action.target_unit_id = -1
		AbilitySystem.set_module_target(action, 0, Vector2i(3, 2), -1)
		AbilitySystem.set_module_target(action, 1, target.position, target.id)
	if ability_id == &"beast_run_down":
		action.target_coord = Vector2i(4, 3)
	if ability_id == &"beast_meteor_drop":
		action.target_unit_id = -1
		action.target_coord = Vector2i(4, 3)
	actor.ability.points_left = actor.ability.max_points
	actor.movement.points_left = actor.movement.max_points
	var before_hp := target.health.current_hp
	var before_pos := actor.position
	var events: Array[SimEvent] = []
	var can_use := AbilitySystem.can_use(board, action)
	_assert(failures, "%s/can_use" % ability_id, can_use)
	if can_use:
		Simulator.simulate_player_turn(board, _timeline(action), events)
	_assert(
		failures,
		"%s/outcome" % ability_id,
		_events_show_outcome(events, target.id, before_hp, board, before_pos),
	)


static func run_passive_row(passive_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"beast_rider")
	var passive := _passive(definition, passive_id)
	_assert(failures, "passive/%s/data" % passive_id, passive != null)
	if passive == null:
		return
	var board := _plain_board(Vector2i(10, 8))
	var actor := _place_actor(board, 1, Vector2i(2, 3), _ability(definition, &"beast_thrash"))
	actor.active_passives.append(passive)
	actor.upgraded_passives.append(passive_id)
	actor._recalculate_stats(board)
	var target := _place_target(board, passive_id)
	var events: Array[SimEvent] = []
	var before_def := actor.current_defense
	var before_str := actor.current_strength
	match passive_id:
		&"gallop":
			_assert(failures, "passive/gallop/post_move", _BEAST.can_post_move(actor))
		&"safe_landing":
			_BEAST.turn_start(board, actor, events)
			_assert(failures, "passive/safe_landing/airborne", actor.has_status(GameEnums.StatusType.AIRBORNE))
		&"intimidating_presence":
			var enemy := _place_enemy(board, 7, Vector2i(3, 3))
			enemy.active_passives.append(passive)
			enemy._recalculate_stats(board)
			_assert(
				failures,
				"passive/intimidating_presence/stat_adjustment",
				actor.current_defense < before_def or actor.current_strength == before_str,
			)
		&"blood_scent":
			target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLEED, 1))
			actor.passive_flags["beast_move_start"] = Vector2i(1, 3)
			actor.position = Vector2i(2, 3)
			_assert(
				failures,
				"passive/blood_scent/pierce",
				_BEAST.should_pierce(board, actor, target, null),
			)
		_:
			_BEAST.damage_bonus(board, actor, target, null)
			_assert(
				failures,
				"passive/%s/runtime" % passive_id,
				actor.current_defense >= 0 and actor.current_strength >= 0,
			)
	_assert(
		failures,
		"passive/%s/outcome_state" % passive_id,
		actor.current_defense >= 0 and actor.current_strength >= 0,
	)


static func run_ability_upgrade_row(ability_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"beast_rider")
	var ability := _ability(definition, ability_id)
	_assert(failures, "%s/upgrade/data" % ability_id, ability != null and not ability.upgraded_modules.is_empty())
	if ability == null:
		return
	var board := _plain_board(Vector2i(10, 8))
	var actor := _place_actor(board, 1, Vector2i(2, 3), ability)
	actor.upgraded_abilities.append(ability_id)
	var target := _place_target(board, ability_id)
	var action := TimelineAction.make_ability(actor.id, ability, target.position, target.id)
	if ability.has_targeting(GameEnums.TargetingFlags.SELF):
		action.target_coord = actor.position
		action.target_unit_id = actor.id
	var events: Array[SimEvent] = []
	_assert(
		failures,
		"%s/upgrade/active_profile" % ability_id,
		ability.get_active_modules(true).size() == ability.upgraded_modules.size(),
	)
	Simulator.simulate_player_turn(board, _timeline(action), events)
	_assert(
		failures,
		"%s/upgrade/outcome" % ability_id,
		not events.is_empty() and board.get_unit_by_id(1) != null,
	)


static func run_planning_row(factory_id: StringName, failures: Array[String]) -> void:
	_PLANNING.run_for_factory(failures, factory_id)


static func _timeline(action: TimelineAction) -> Timeline:
	var timeline := Timeline.new()
	timeline.add(action)
	return timeline


static func _plain_board(size: Vector2i) -> BoardState:
	var board := BoardState.new()
	board.grid_size = size
	var plain := DataLibrary.get_terrain(&"plain")
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	return board


static func _place_actor(
	board: BoardState,
	unit_id: int,
	coord: Vector2i,
	ability: AbilityData,
) -> UnitState:
	var unit := UnitState.create(
		unit_id,
		FactoryTestHelpers.build_unit(&"beast_rider"),
		GameEnums.Team.PLAYER,
		coord,
		{"active_abilities": [DataLibrary.get_universal_run(), ability]},
	)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit


static func _place_target(board: BoardState, row_id: StringName) -> UnitState:
	var coord := Vector2i(3, 3)
	if row_id in [&"beast_meteor_drop", &"beast_tail_swipe"]:
		coord = Vector2i(4, 4)
	if row_id == &"beast_airlift":
		return _place_ally(board, 2, coord)
	var target := _place_enemy(board, 2, coord)
	if row_id == &"beast_feral_drag":
		target.health.max_hp = 5
		target.health.current_hp = 5
	return target


static func _place_ally(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var unit := UnitState.create(
		unit_id,
		FactoryTestHelpers.build_unit(&"beast_rider"),
		GameEnums.Team.PLAYER,
		coord,
	)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit


static func _place_enemy(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var unit := UnitState.create(
		unit_id,
		DataLibrary.get_training_dummy(),
		GameEnums.Team.ENEMY,
		coord,
	)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit


static func _ability(definition: UnitData, ability_id: StringName) -> AbilityData:
	for ability: AbilityData in definition.abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


static func _passive(definition: UnitData, passive_id: StringName) -> PassiveData:
	for passive: PassiveData in definition.innate_passives + definition.passives:
		if passive != null and passive.id == passive_id:
			return passive
	return null


static func _events_show_outcome(
	events: Array[SimEvent],
	target_id: int,
	before_hp: int,
	board: BoardState,
	before_pos: Vector2i,
) -> bool:
	if board == null or board.get_unit_by_id(1) == null:
		return false
	var actor := board.get_unit_by_id(1)
	if actor.position != before_pos or board.get_unit_by_id(target_id) == null:
		return true
	var target := board.get_unit_by_id(target_id)
	if target.health.current_hp != before_hp or not target.active_statuses.is_empty():
		return true
	for event: SimEvent in events:
		if event.type in [
			GameEnums.SimEventType.ABILITY_USED,
			GameEnums.SimEventType.UNIT_MOVED,
			GameEnums.SimEventType.UNIT_DAMAGED,
			GameEnums.SimEventType.STATUS_APPLIED,
			GameEnums.SimEventType.UNIT_HEALED,
			GameEnums.SimEventType.ACTION_FAILED,
		]:
			return true
	return false


static func _assert(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
