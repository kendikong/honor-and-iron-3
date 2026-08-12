class_name EngineerQaHarness
extends RefCounted

## Layer A/B Engineer proof. Every factory row delegates through the shared
## AbilitySystem, Simulator, GridSystem, CombatSystem, or EngineerSystems path.

const EngineerSystems := preload("res://core/systems/engineer_systems.gd")

const ABILITY_IDS: Array[StringName] = [
	&"engineer_recall",
	&"engineer_dismantle",
	&"engineer_sludge_bomb",
	&"engineer_construct_turret",
	&"engineer_frag_bomb",
	&"engineer_magnetic_mine",
	&"engineer_tesla_barricade",
	&"engineer_flak_cannon",
	&"engineer_wrench_smack",
	&"engineer_emp_grenade",
	&"engineer_rocket_launcher",
	&"engineer_scrap_shield",
	&"engineer_manual_detonation",
	&"engineer_overdrive_injection",
	&"engineer_barbed_wire",
]

const PASSIVE_ROWS: Array[Dictionary] = [
	{"id": &"turret_syndrome", "keys": [&"stationary_mini_turret", &"mini_turret_hp_pct"]},
	{"id": &"automation", "keys": [&"turret_attack_bonus", &"turret_range_bonus"]},
	{"id": &"master_builder", "keys": [&"active_construct_limit"]},
	{"id": &"reinforced_constructs", "keys": [&"construct_hp_bonus_pct", &"construct_def_inherit_pct"]},
	{"id": &"shield_generator", "keys": [&"turret_adjacent_defense"]},
	{"id": &"blast_shielding", "keys": [&"own_explosion_immunity"]},
	{"id": &"explosive_expert", "keys": [&"explosive_mechanical_bonus", &"explosive_ignore_def"]},
	{"id": &"chain_reaction", "keys": [&"chain_reaction_range"]},
	{"id": &"shrapnel", "keys": [&"detonation_bleed_weapon", &"detonation_push"]},
	{"id": &"expanded_blast", "keys": [&"explosion_aoe_bonus"]},
	{"id": &"scrap_mechanic", "keys": [&"enemy_death_scrap_range"]},
	{"id": &"recycling_protocol", "keys": [&"construct_destroyed_scrap", &"construct_destroyed_ap"]},
	{"id": &"overclock", "keys": [&"construct_overclock", &"overclock_turn_damage"]},
	{"id": &"overclocked_maintenance", "keys": [&"maintenance_repair", &"maintenance_cost"]},
	{"id": &"field_technician", "keys": [&"repair_range", &"repair_next_attack_strength"]},
]


static func run_factory_matrix(failures: Array[String]) -> void:
	var engineer := FactoryTestHelpers.build_unit(&"engineer")
	_assert(failures, "factory/engineer_registered", engineer != null)
	if engineer == null:
		return
	_assert(failures, "factory/base_constitution", engineer.base_constitution == 4)
	_assert(failures, "factory/base_movement", engineer.move_points == 4)
	_assert(failures, "factory/base_strength", engineer.base_strength == 3)
	_assert(failures, "factory/base_defense", engineer.base_defense == 3)
	_assert(failures, "factory/innate_count", engineer.innate_passives.size() == 1)
	_assert(failures, "factory/active_count", engineer.abilities.size() == 16)
	_assert(failures, "factory/promotion_passive_count", engineer.passives.size() == 15)
	for ability_id: StringName in ABILITY_IDS:
		var ability := _ability(engineer, ability_id)
		_assert(failures, "factory/ability/%s" % ability_id, ability != null)
		if ability == null:
			continue
		_assert(failures, "factory/modules/%s" % ability_id, not ability.modules.is_empty())
		_assert(
			failures,
			"factory/upgrade/%s" % ability_id,
			not ability.upgraded_modules.is_empty() and not ability.upgrade_description.is_empty(),
		)
	for row: Dictionary in PASSIVE_ROWS:
		var passive := _passive(engineer, row.id)
		_assert(failures, "factory/passive/%s" % row.id, passive != null)
		if passive == null:
			continue
		for key: StringName in row.keys:
			_assert(failures, "factory/passive/%s/%s" % [row.id, key], passive.modifiers.has(key))
	_assert(
		failures,
		"factory/innate/blueprint_tread",
		_passive(engineer, &"blueprint_tread").modifiers.has(&"construct_passable"),
	)


static func run_single_ability(ability_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"engineer")
	var ability := _ability(definition, ability_id)
	_assert(failures, "%s/data" % ability_id, ability != null)
	if ability == null:
		return
	_data_contract(failures, ability_id, ability)
	var board := _plain_board(Vector2i(10, 8))
	var actor := _place_engineer(board, 1, Vector2i(2, 3), ability)
	if ability_id == &"engineer_scrap_shield":
		actor.scrap = 2
	var target_coord := _target_coord(ability_id)
	var target_id := -1
	if ability_id == &"engineer_recall":
		_place_construct(board, 8, Vector2i(3, 3), &"construct_turret", actor.id)
	elif ability_id in [
		&"engineer_wrench_smack", &"engineer_manual_detonation",
		&"engineer_overdrive_injection",
	]:
		target_id = _place_construct(board, 7, target_coord, &"construct_turret", actor.id).id
		if ability_id == &"engineer_wrench_smack":
			var wrench_target := board.get_unit_by_id(target_id)
			wrench_target.health.current_hp = maxi(1, wrench_target.health.max_hp - 1)
	elif ability_id not in [
		&"engineer_construct_turret", &"engineer_magnetic_mine",
		&"engineer_tesla_barricade", &"engineer_scrap_shield",
		&"engineer_barbed_wire", &"engineer_recall",
	]:
		target_id = _place_dummy(board, 7, target_coord).id
	elif ability_id == &"engineer_scrap_shield":
		target_id = _place_ally(board, 7, target_coord).id
	var action := TimelineAction.make_ability(1, ability, target_coord, target_id)
	_assert(failures, "%s/can_use" % ability_id, AbilitySystem.can_use(board, action))
	if not AbilitySystem.can_use(board, action):
		return
	var before := board.clone()
	var plan := Timeline.new()
	plan.add(action)
	var result := Simulator.simulate(board, plan)
	_assert(
		failures,
		"%s/action_not_failed" % ability_id,
		not _has_action_failure(result.events, 1),
	)
	if ability_id == &"engineer_wrench_smack":
		var repaired := result.final_state.get_unit_by_id(target_id)
		_assert(
			failures,
			"engineer_wrench_smack/outcome/construct_repair",
			repaired != null and repaired.health.current_hp > before.get_unit_by_id(target_id).health.current_hp,
		)
	else:
		ClassScenarioSimOutcome.assert_from_events(
			failures, String(ability_id), ability, result.events, before, result.final_state, target_id,
		)
	if ability_id in [
		&"engineer_construct_turret", &"engineer_magnetic_mine",
		&"engineer_tesla_barricade",
	]:
		_assert(failures, "%s/spawned_construct" % ability_id, _has_spawn(result.events))
	if ability.target_shape != GameEnums.TargetShape.SINGLE:
		_assert(
			failures,
			"%s/shape_tiles" % ability_id,
			GridSystem.get_affected_tiles(
				before, actor.position, Vector2i(4, 3),
				ability.target_shape, ability.target_shape_size,
			).size() > 1,
		)


static func run_upgrade_for(ability_id: StringName, failures: Array[String]) -> void:
	var ability := _ability(FactoryTestHelpers.build_unit(&"engineer"), ability_id)
	_assert(failures, "%s/upgrade_description" % ability_id, ability != null and not ability.upgrade_description.is_empty())
	if ability == null:
		return
	_assert(failures, "%s/upgrade_modules" % ability_id, not ability.upgraded_modules.is_empty())
	var base_keys := ability.modules[0].legacy_modifiers.keys()
	var upgrade_keys := ability.upgraded_modules[0].legacy_modifiers.keys()
	_assert(
		failures,
		"%s/upgrade_delta" % ability_id,
		base_keys != upgrade_keys or ability.modules[0].amount != ability.upgraded_modules[0].amount,
	)


static func run_passive_factory(passive_id: StringName, failures: Array[String]) -> void:
	var engineer := FactoryTestHelpers.build_unit(&"engineer")
	var passive := _passive(engineer, passive_id)
	_assert(failures, "passive/%s/data" % passive_id, passive != null)
	if passive == null:
		return
	for row: Dictionary in PASSIVE_ROWS:
		if row.id != passive_id:
			continue
		for key: StringName in row.keys:
			_assert(failures, "passive/%s/modifier/%s" % [passive_id, key], passive.modifiers.has(key))
		break
	if passive_id == &"overclock":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_construct_turret"))
		actor.active_passives.append(passive)
		var construct := _place_construct(board, 4, Vector2i(3, 2), &"construct_turret", actor.id)
		var before := construct.health.current_hp
		EngineerSystems.player_phase_end(board, [])
		_assert(failures, "passive/overclock/turn_damage", construct.health.current_hp < before)


static func _plain_board(size: Vector2i) -> BoardState:
	var board := BoardState.new()
	board.grid_size = size
	var plain := DataLibrary.get_terrain(&"plain")
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	return board


static func _place_engineer(
	board: BoardState,
	unit_id: int,
	coord: Vector2i,
	ability: AbilityData,
) -> UnitState:
	var unit := UnitState.create(
		unit_id, FactoryTestHelpers.build_unit(&"engineer"),
		GameEnums.Team.PLAYER,
		coord,
		{"active_abilities": [DataLibrary.get_universal_run(), ability]},
	)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	unit.ability.points_left = unit.ability.max_points
	unit.movement.points_left = unit.movement.max_points
	return unit


static func _place_construct(
	board: BoardState,
	unit_id: int,
	coord: Vector2i,
	definition_id: StringName,
	owner_id: int,
) -> UnitState:
	var unit := UnitState.create(
		unit_id, DataLibrary.get_unit(definition_id), GameEnums.Team.PLAYER, coord,
	)
	unit.passive_flags["engineer_owner_id"] = owner_id
	unit.passive_flags["engineer_construct_kind"] = definition_id
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit


static func _place_ally(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var unit := UnitState.create(
		unit_id, FactoryTestHelpers.build_unit(&"engineer"),
		GameEnums.Team.PLAYER, coord,
	)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit


static func _place_dummy(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var unit := UnitState.create(
		unit_id, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, coord,
	)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit


static func _target_coord(ability_id: StringName) -> Vector2i:
	if ability_id in [
		&"engineer_dismantle", &"engineer_flak_cannon",
		&"engineer_wrench_smack", &"engineer_overdrive_injection",
		&"engineer_construct_turret", &"engineer_magnetic_mine",
		&"engineer_tesla_barricade", &"engineer_scrap_shield",
	]:
		return Vector2i(3, 3)
	return Vector2i(4, 3)


static func _data_contract(
	failures: Array[String],
	ability_id: StringName,
	ability: AbilityData,
) -> void:
	var modules := ability.modules
	_assert(failures, "%s/data/module_count" % ability_id, modules.size() == 1)
	if modules.is_empty():
		return
	var module := modules[0]
	match ability_id:
		&"engineer_recall":
			_assert(failures, "%s/data/mp_cost" % ability_id, ability.movement_point_cost == 3)
			_assert(failures, "%s/data/teleport" % ability_id, module.primary_type == GameEnums.EffectType.TELEPORT_CASTER)
			_assert(failures, "%s/data/recall_modifier" % ability_id, module.legacy_modifiers.has(&"recall_adjacent_construct"))
		&"engineer_dismantle":
			_assert(failures, "%s/data/amount" % ability_id, module.amount == 3)
			_assert(failures, "%s/data/range" % ability_id, module.min_range == 1 and module.max_range == 1)
			_assert(failures, "%s/data/def_loss" % ability_id, module.legacy_modifiers.get("target_def_pct_loss", 0.0) == 0.25)
		&"engineer_sludge_bomb", &"engineer_frag_bomb":
			_assert(failures, "%s/data/aoe" % ability_id, module.target_shape == GameEnums.TargetShape.AOE_SQUARE and module.target_shape_size == 3)
			_assert(failures, "%s/data/range" % ability_id, module.max_range == 3)
			_assert(failures, "%s/data/hazard_layer" % ability_id, not module.layers.is_empty())
		&"engineer_construct_turret":
			_assert(failures, "%s/data/spawn" % ability_id, module.spawn_unit_id == &"construct_turret")
		&"engineer_magnetic_mine":
			_assert(failures, "%s/data/spawn" % ability_id, module.spawn_unit_id == &"magnetic_mine")
			_assert(failures, "%s/data/pull" % ability_id, module.legacy_modifiers.get("mine_pull", 0) == 2)
		&"engineer_tesla_barricade":
			_assert(failures, "%s/data/spawn" % ability_id, module.spawn_unit_id == &"tesla_barricade")
		&"engineer_flak_cannon":
			_assert(failures, "%s/data/arc" % ability_id, module.target_shape == GameEnums.TargetShape.ARC)
			_assert(failures, "%s/data/push_layer" % ability_id, not module.layers.is_empty())
		&"engineer_wrench_smack":
			_assert(failures, "%s/data/dual_target" % ability_id, module.targeting_flags == (GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY))
			_assert(failures, "%s/data/wrench_modifier" % ability_id, module.legacy_modifiers.has(&"wrench_smack"))
		&"engineer_emp_grenade":
			_assert(failures, "%s/data/purge" % ability_id, module.primary_type == GameEnums.EffectType.PURGE)
			_assert(failures, "%s/data/aoe" % ability_id, module.target_shape == GameEnums.TargetShape.AOE_SQUARE and module.target_shape_size == 2)
		&"engineer_rocket_launcher":
			_assert(failures, "%s/data/global_range" % ability_id, module.max_range == 99)
			_assert(failures, "%s/data/aoe" % ability_id, module.target_shape == GameEnums.TargetShape.AOE_SQUARE and module.target_shape_size == 3)
		&"engineer_scrap_shield":
			_assert(failures, "%s/data/armor" % ability_id, module.primary_type == GameEnums.EffectType.ARMOR_UP)
			_assert(failures, "%s/data/scrap_modifier" % ability_id, module.legacy_modifiers.get("scrap_multiplier", 0) == 2)
		&"engineer_manual_detonation":
			_assert(failures, "%s/data/free_ap" % ability_id, ability.action_point_cost == 0)
			_assert(failures, "%s/data/explosion" % ability_id, module.primary_type == GameEnums.EffectType.RANGED_EXPLODE)
		&"engineer_overdrive_injection":
			_assert(failures, "%s/data/strength" % ability_id, module.primary_type == GameEnums.EffectType.ADD_STATUS and module.amount == 2)
			_assert(failures, "%s/data/self_damage" % ability_id, module.legacy_modifiers.get("self_unmitigated_damage", 0) == 2)
		&"engineer_barbed_wire":
			_assert(failures, "%s/data/arc" % ability_id, module.target_shape == GameEnums.TargetShape.ARC and module.target_shape_size == 3)
			_assert(failures, "%s/data/terrain" % ability_id, module.legacy_modifiers.get("terrain_id", &"") == &"barbed_wire")


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


static func _has_spawn(events: Array[SimEvent]) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.UNIT_SPAWNED:
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
