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
	{"id": &"overclocked_maintenance", "keys": [&"maintenance_repair", &"maintenance_shield"]},
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


static func run_single_ability(
	ability_id: StringName,
	failures: Array[String],
	upgraded: bool = false,
) -> void:
	run_ability_row(ability_id, failures, upgraded)


static func run_ability_row(
	ability_id: StringName,
	failures: Array[String],
	upgraded: bool = false,
) -> void:
	var definition := FactoryTestHelpers.build_unit(&"engineer")
	var ability := _ability(definition, ability_id)
	_assert(failures, "%s/data" % ability_id, ability != null)
	if ability == null:
		return
	_data_contract(failures, ability_id, ability)
	var board := _plain_board(Vector2i(10, 8))
	var actor := _place_engineer(board, 1, Vector2i(2, 3), ability)
	if upgraded:
		actor.upgraded_abilities.append(ability_id)
	if ability_id == &"engineer_scrap_shield" or (
		ability_id == &"engineer_flak_cannon" and upgraded
	):
		actor.scrap = 2
	var target_coord := _target_coord(ability_id)
	var target_id := -1
	var sacrifice_id := -1
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
	elif ability_id == &"engineer_rocket_launcher" and not upgraded:
		target_id = _place_dummy(board, 7, target_coord).id
	elif ability_id not in [
		&"engineer_construct_turret", &"engineer_magnetic_mine",
		&"engineer_tesla_barricade", &"engineer_scrap_shield",
		&"engineer_barbed_wire", &"engineer_recall",
		&"engineer_rocket_launcher",
	]:
		target_id = _place_dummy(board, 7, target_coord).id
	elif ability_id == &"engineer_scrap_shield":
		target_id = _place_ally(board, 7, target_coord).id
	elif ability_id == &"engineer_rocket_launcher" and upgraded:
		target_id = _place_dummy(board, 7, target_coord).id
		sacrifice_id = _place_construct(board, 8, Vector2i(3, 3), &"construct_turret", actor.id).id
	var action := TimelineAction.make_ability(1, ability, target_coord, target_id)
	if sacrifice_id >= 0:
		AbilitySystem.set_module_target(
			action, 1, Vector2i(3, 3), sacrifice_id,
		)
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
	elif ability_id == &"engineer_rocket_launcher" and not upgraded:
		_assert(
			failures,
			"engineer_rocket_launcher/outcome/delayed",
			not result.final_state.delayed_effects.is_empty(),
		)
	elif ability_id == &"engineer_rocket_launcher" and upgraded:
		var damaged := false
		for event: SimEvent in result.events:
			if event.type == GameEnums.SimEventType.UNIT_DAMAGED:
				damaged = true
				break
		_assert(failures, "engineer_rocket_launcher/outcome/damage", damaged)
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
	run_ability_upgrade_row(ability_id, failures)


static func run_ability_upgrade_row(ability_id: StringName, failures: Array[String]) -> void:
	var ability := _ability(FactoryTestHelpers.build_unit(&"engineer"), ability_id)
	_assert(failures, "%s/upgrade_description" % ability_id, ability != null and not ability.upgrade_description.is_empty())
	if ability == null:
		return
	_assert(failures, "%s/upgrade_modules" % ability_id, not ability.upgraded_modules.is_empty())
	var base_keys := ability.modules[0].compile_runtime_modifiers().keys()
	var upgrade_keys := ability.upgraded_modules[0].compile_runtime_modifiers().keys()
	_assert(
		failures,
		"%s/upgrade_delta" % ability_id,
		base_keys != upgrade_keys or ability.modules[0].amount != ability.upgraded_modules[0].amount,
	)
	run_single_ability(ability_id, failures, true)
	if ability_id == &"engineer_magnetic_mine":
		_assert_magnetic_mine_scrap_absorb(failures)


static func _assert_magnetic_mine_scrap_absorb(failures: Array[String]) -> void:
	var engineer := FactoryTestHelpers.build_unit(&"engineer")
	var board := _plain_board(Vector2i(8, 6))
	var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_magnetic_mine"))
	var mine := _place_construct(board, 4, Vector2i(3, 2), &"magnetic_mine", actor.id)
	mine.passive_flags["engineer_spawn_modifiers"] = {
		"absorbs_items_scrap": true, "mine_explode": true, "mine_pull": 2, "mine_damage": 2,
	}
	var enemy := _place_dummy(board, 7, Vector2i(4, 2))
	enemy.scrap = 2
	var events: Array[SimEvent] = []
	EngineerSystems.on_construct_entered(board, enemy, mine, events)
	_assert(failures, "engineer_magnetic_mine/upgrade/scrap_absorb", actor.scrap == 2)


static func run_passive_factory(passive_id: StringName, failures: Array[String]) -> void:
	run_passive_row(passive_id, failures)


static func run_passive_row(passive_id: StringName, failures: Array[String]) -> void:
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
	elif passive_id == &"turret_syndrome":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_construct_turret"))
		actor.active_passives.append(passive)
		EngineerSystems.player_phase_end(board, [])
		var spawned: UnitState = null
		for candidate: UnitState in board.units:
			if (
				candidate != null
				and candidate != actor
				and candidate.is_alive()
				and candidate.definition != null
				and candidate.definition.is_construct
				and int(candidate.passive_flags.get("engineer_owner_id", -1)) == actor.id
			):
				spawned = candidate
				break
		_assert(
			failures,
			"passive/turret_syndrome/spawn",
			spawned != null and spawned.definition != null and spawned.definition.is_construct,
		)
	elif passive_id == &"shield_generator":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_construct_turret"))
		actor.active_passives.append(passive)
		actor.upgraded_passives.append(passive_id)
		_place_construct(board, 4, Vector2i(3, 2), &"construct_turret", actor.id)
		var ally := _place_ally(board, 5, Vector2i(3, 3))
		var base_def := ally.current_defense
		_assert(
			failures,
			"passive/shield_generator/defense",
			CombatSystem.get_dynamic_defense(board, ally) == base_def + 1,
		)
		_assert(
			failures,
			"passive/shield_generator/pull_immunity",
			EngineerSystems.is_pull_immune(board, ally),
		)
	elif passive_id == &"chain_reaction":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_construct_turret"))
		actor.active_passives.append(passive)
		var first := _place_construct(board, 4, Vector2i(3, 2), &"magnetic_mine", actor.id)
		var second := _place_construct(board, 5, Vector2i(4, 2), &"magnetic_mine", actor.id)
		first.passive_flags["engineer_spawn_modifiers"] = {"mine_explode": true}
		second.passive_flags["engineer_spawn_modifiers"] = {"mine_explode": true}
		first.health.current_hp = 0
		var events: Array[SimEvent] = []
		EngineerSystems.on_construct_destroyed(board, first, events)
		_assert(failures, "passive/chain_reaction/detonates_neighbor", not second.is_alive())
	elif passive_id == &"scrap_mechanic":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_construct_turret"))
		actor.active_passives.append(passive)
		var target := _place_dummy(board, 7, Vector2i(3, 2))
		target.health.current_hp = 0
		EngineerSystems.on_kill(board, actor, target, [])
		_assert(failures, "passive/scrap_mechanic/scrap_drop", actor.scrap == 1)
	elif passive_id == &"recycling_protocol":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_construct_turret"))
		actor.active_passives.append(passive)
		var construct := _place_construct(board, 4, Vector2i(3, 2), &"construct_turret", actor.id)
		construct.health.current_hp = 0
		actor.ability.points_left = 0
		actor.ability.max_points = 2
		EngineerSystems.on_construct_destroyed(board, construct, [])
		_assert(failures, "passive/recycling_protocol/scrap", actor.scrap == 2)
		_assert(failures, "passive/recycling_protocol/ap", actor.ability.points_left == 1)
	elif passive_id == &"overclocked_maintenance":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_construct_turret"))
		actor.active_passives.append(passive)
		var construct := _place_construct(board, 4, Vector2i(3, 2), &"construct_turret", actor.id)
		construct.health.current_hp = maxi(1, construct.health.max_hp - 4)
		actor.movement_points_spent_this_turn = 1
		var before := construct.health.current_hp
		EngineerSystems.after_movement(board, actor, [])
		_assert(
			failures,
			"passive/overclocked_maintenance/repair",
			construct.health.current_hp > before,
		)
	elif passive_id == &"field_technician":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_construct_turret"))
		actor.active_passives.append(passive)
		actor.active_passives.append(_passive(engineer, &"blueprint_tread"))
		var construct := _place_construct(board, 4, Vector2i(4, 2), &"construct_turret", actor.id)
		construct.health.current_hp = maxi(1, construct.health.max_hp - 4)
		var before := construct.health.current_hp
		EngineerSystems.player_phase_end(board, [])
		_assert(
			failures,
			"passive/field_technician/repair",
			construct.health.current_hp > before,
		)
		_assert(
			failures,
			"passive/field_technician/next_attack_str",
			int(actor.passive_flags.get("next_attack_strength_bonus", 0)) == 1,
		)
	elif passive_id == &"blueprint_tread":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_construct_turret"))
		actor.upgraded_passives.append(passive_id)
		var construct := _place_construct(board, 4, Vector2i(3, 2), &"construct_turret", actor.id)
		EngineerSystems.on_construct_passed(board, actor, construct, [])
		_assert(
			failures,
			"passive/blueprint_tread/pass_through_shield",
			actor.armor > 0 and construct.armor > 0,
		)
	elif passive_id == &"automation":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_construct_turret"))
		actor.active_passives.append(passive)
		_place_construct(board, 4, Vector2i(3, 2), &"construct_turret", actor.id)
		var enemy := _place_dummy(board, 7, Vector2i(3, 3))
		var events: Array[SimEvent] = []
		EngineerSystems.player_phase_end(board, events)
		var damaged := false
		for event: SimEvent in events:
			if (
				event.type == GameEnums.SimEventType.UNIT_DAMAGED
				and int(event.data.get("unit", -1)) == enemy.id
			):
				damaged = true
				break
		_assert(failures, "passive/automation/turret_damage", damaged)
	elif passive_id == &"master_builder":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_construct_turret"))
		actor.active_passives.append(passive)
		_assert(
			failures,
			"passive/master_builder/limit",
			int(EngineerSystems.passive_value(actor, &"active_construct_limit", &"", 0)) == 1,
		)
	elif passive_id == &"reinforced_constructs":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_construct_turret"))
		actor.active_passives.append(passive)
		actor._recalculate_stats(board)
		var construct := _place_construct(board, 4, Vector2i(3, 2), &"construct_turret", actor.id)
		var before_hp := construct.health.max_hp
		EngineerSystems.on_spawned(board, actor, construct, null, null, [])
		var has_def_buff := false
		for status in construct.active_statuses:
			if status.type == GameEnums.StatusType.STAT_BUFF_DEF:
				has_def_buff = true
				break
		_assert(
			failures,
			"passive/reinforced_constructs/hp_bonus",
			construct.health.max_hp > before_hp or has_def_buff,
		)
	elif passive_id == &"blast_shielding":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_frag_bomb"))
		actor.active_passives.append(passive)
		_assert(
			failures,
			"passive/blast_shielding/immunity_flag",
			EngineerSystems.has_passive_modifier(actor, &"own_explosion_immunity"),
		)
	elif passive_id == &"explosive_expert":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_frag_bomb"))
		actor.active_passives.append(passive)
		var target := _place_construct(board, 7, Vector2i(3, 2), &"construct_turret", -1)
		target.team = GameEnums.Team.ENEMY
		var effect := DataLibrary._effect(GameEnums.EffectType.EXPLODE, 2)
		actor.passive_flags["__current_ability"] = _ability(engineer, &"engineer_frag_bomb")
		var adjustment := EngineerSystems.damage_adjustment(board, actor, target, effect)
		_assert(
			failures,
			"passive/explosive_expert/mechanical_bonus",
			int(adjustment.get("amount", 0)) >= 1,
		)
	elif passive_id == &"shrapnel":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_manual_detonation"))
		actor.active_passives.append(passive)
		var device := _place_construct(board, 4, Vector2i(3, 2), &"magnetic_mine", actor.id)
		_place_dummy(board, 7, Vector2i(4, 2))
		var ability := _ability(engineer, &"engineer_manual_detonation")
		var action := TimelineAction.make_ability(1, ability, device.position, device.id)
		var plan := Timeline.new()
		plan.add(action)
		var result := Simulator.simulate(board, plan)
		var enemy := result.final_state.get_unit_by_id(7)
		var has_bleed := false
		if enemy != null:
			for status in enemy.active_statuses:
				if status.type == GameEnums.StatusType.BLEED:
					has_bleed = true
					break
		_assert(failures, "passive/shrapnel/bleed", has_bleed)
	elif passive_id == &"expanded_blast":
		var board := _plain_board(Vector2i(8, 6))
		var actor := _place_engineer(board, 1, Vector2i(2, 2), _ability(engineer, &"engineer_manual_detonation"))
		actor.active_passives.append(passive)
		var center := Vector2i(3, 2)
		var size := 3 + int(EngineerSystems.passive_value(actor, &"explosion_aoe_bonus", &"", 0))
		var tiles := GridSystem.get_affected_tiles(
			board, center, center, GameEnums.TargetShape.AOE_SQUARE, size,
		)
		_assert(failures, "passive/expanded_blast/aoe", tiles.size() > 9)


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
			_assert(failures, "%s/data/teleport" % ability_id, module.primary_type == GameEnums.EffectType.TELEPORT_ADJACENT_TO)
			_assert(failures, "%s/data/recall_modifier" % ability_id, module.target_filter == GameEnums.ModuleTargetFilter.OCCUPANT and module.target_filter_occupant == GameEnums.ModuleTargetFilterOccupant.ADJACENT_CONSTRUCT)
		&"engineer_dismantle":
			_assert(failures, "%s/data/amount" % ability_id, module.amount == 3)
			_assert(failures, "%s/data/range" % ability_id, module.min_range == 1 and module.max_range == 1)
			_assert(failures, "%s/data/def_loss" % ability_id, module.runtime_value("target_def_pct_loss", 0.0) == 0.25)
		&"engineer_sludge_bomb":
			_assert(failures, "%s/data/aoe" % ability_id, module.target_shape == GameEnums.TargetShape.AOE_SQUARE and module.target_shape_size == 1)
			_assert(failures, "%s/data/range" % ability_id, module.max_range == 3)
			_assert(failures, "%s/data/hazard_layer" % ability_id, not module.layers.is_empty())
		&"engineer_frag_bomb":
			_assert(failures, "%s/data/aoe" % ability_id, module.target_shape == GameEnums.TargetShape.AOE_SQUARE and module.target_shape_size == 1)
			_assert(failures, "%s/data/range" % ability_id, module.max_range == 3)
			_assert(failures, "%s/data/ignite_oil" % ability_id, module.runtime_value("ignite_oil", false))
		&"engineer_construct_turret":
			_assert(failures, "%s/data/spawn" % ability_id, module.spawn_unit_id == &"construct_turret")
		&"engineer_magnetic_mine":
			_assert(failures, "%s/data/spawn" % ability_id, module.spawn_unit_id == &"magnetic_mine")
			_assert(failures, "%s/data/pull" % ability_id, module.runtime_value("mine_pull", 0) == 2)
		&"engineer_tesla_barricade":
			_assert(failures, "%s/data/spawn" % ability_id, module.spawn_unit_id == &"tesla_barricade")
		&"engineer_flak_cannon":
			_assert(failures, "%s/data/arc" % ability_id, module.target_shape == GameEnums.TargetShape.ARC)
			_assert(failures, "%s/data/push_layer" % ability_id, not module.layers.is_empty())
		&"engineer_wrench_smack":
			_assert(failures, "%s/data/dual_target" % ability_id, module.targeting_flags == (GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY))
			_assert(failures, "%s/data/wrench_modifier" % ability_id, module.runtime_has(&"wrench_smack"))
		&"engineer_emp_grenade":
			_assert(failures, "%s/data/purge" % ability_id, module.primary_type == GameEnums.EffectType.PURGE)
			_assert(failures, "%s/data/aoe" % ability_id, module.target_shape == GameEnums.TargetShape.AOE_CROSS and module.target_shape_size == 2)
		&"engineer_rocket_launcher":
			_assert(failures, "%s/data/global_range" % ability_id, module.max_range == 99)
			_assert(failures, "%s/data/aoe" % ability_id, module.target_shape == GameEnums.TargetShape.AOE_SQUARE and module.target_shape_size == 1)
		&"engineer_scrap_shield":
			_assert(failures, "%s/data/armor" % ability_id, module.primary_type == GameEnums.EffectType.ARMOR_UP)
			_assert(failures, "%s/data/scrap_modifier" % ability_id, module.runtime_value("scrap_multiplier", 0) == 2)
		&"engineer_manual_detonation":
			_assert(failures, "%s/data/free_ap" % ability_id, ability.action_point_cost == 0)
			_assert(failures, "%s/data/explosion" % ability_id, module.primary_type == GameEnums.EffectType.RANGED_EXPLODE)
		&"engineer_overdrive_injection":
			_assert(failures, "%s/data/strength" % ability_id, module.primary_type == GameEnums.EffectType.ADD_STATUS and module.amount == 2)
			_assert(failures, "%s/data/construct_damage" % ability_id, module.runtime_value("construct_unmitigated_damage", 0) == 2)
		&"engineer_barbed_wire":
			_assert(failures, "%s/data/arc" % ability_id, module.target_shape == GameEnums.TargetShape.ARC and module.target_shape_size == 3)
			_assert(failures, "%s/data/terrain" % ability_id, module.runtime_value("terrain_id", &"") == &"barbed_wire")


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
