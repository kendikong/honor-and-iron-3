class_name RogueQaHarness
extends RefCounted

## Layer A/B helper for Rogue rows. Each row scenario delegates here, while
## shaped rows additionally delegate to the shared footprint contract.

const _ROGUE_SYSTEMS := preload("res://core/systems/rogue_systems.gd")

const ABILITY_IDS: Array[StringName] = [
	&"rogue_slip_past",
	&"rogue_shadow_step",
	&"rogue_kidney_strike",
	&"rogue_smoke_bomb",
	&"rogue_evasive_strike",
	&"rogue_grappling_hook",
	&"rogue_switcheroo",
	&"rogue_blindside",
	&"rogue_throat_slit",
	&"rogue_amnesia_dust",
	&"rogue_death_mark",
	&"rogue_lethal_flourish",
	&"rogue_shadow_swap",
	&"rogue_kidnap",
	&"rogue_shuriken_volley",
	&"rogue_poison_flask",
]

const PASSIVE_ROWS: Array[Dictionary] = [
	{"id": &"pass", "keys": [&"pass", &"ghost_move", &"pass_through_enemy"]},
	{"id": &"backstab", "keys": [&"backstab_ignore_def"]},
	{"id": &"blink_mastery", "keys": [&"after_teleport_attack_bonus"]},
	{"id": &"lethal_position", "keys": [&"moved_tiles_attack_strength", &"moved_tiles_attack_range"]},
	{"id": &"shadow_strike", "keys": [&"teleport_adjacent_mark_root"]},
	{"id": &"killing_intent", "keys": [&"end_adjacent_low_hp_ap", &"killing_intent_threshold"]},
	{"id": &"shadow_clone", "keys": [&"on_kill_decoy_taunt"]},
	{"id": &"phase_shift", "keys": [&"teleport_stealth"]},
	{"id": &"blink_strike", "keys": [&"basic_attack_range"]},
	{"id": &"shadow_meld", "keys": [&"smoke_spell_magic", &"smoke_spell_free_ap"]},
	{"id": &"shadow_slip", "keys": [&"cross_enemy_blind_mark", &"marked_attack_weapon_bonus"]},
	{"id": &"miasma_spreader", "keys": [&"spread_debuffs_on_attack", &"miasma_spreader_range"]},
	{"id": &"panic_cascade", "keys": [&"debuff_damage_per_status"]},
	{"id": &"debuff_overload", "keys": [&"turn_start_damage_per_debuff"]},
	{"id": &"mind_static", "keys": [&"mind_static_range", &"mind_static_def_pct"]},
	{"id": &"board_scrambler", "keys": [&"damage_swap_highest_hp_range"]},
]


static func run_factory_matrix(failures: Array[String]) -> void:
	var rogue := FactoryTestHelpers.build_unit(&"rogue")
	_assert(failures, "factory/rogue_registered", rogue != null)
	if rogue == null:
		return
	_assert(failures, "factory/base_constitution", rogue.base_constitution == 4)
	_assert(failures, "factory/base_movement", rogue.move_points == 5)
	_assert(failures, "factory/base_strength", rogue.base_strength == 4)
	_assert(failures, "factory/base_defense", rogue.base_defense == 2)
	_assert(failures, "factory/innate_count", rogue.innate_passives.size() == 1)
	_assert(failures, "factory/active_count", rogue.abilities.size() == 17)
	_assert(failures, "factory/promotion_passive_count", rogue.passives.size() == 15)
	for ability_id: StringName in ABILITY_IDS:
		var ability := _ability(rogue, ability_id)
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
		var passive := _passive(rogue, row.id)
		_assert(failures, "factory/passive/%s" % row.id, passive != null)
		if passive == null:
			continue
		for key: StringName in row.keys:
			_assert(
				failures,
				"factory/passive/%s/%s" % [row.id, key],
				passive.modifiers.has(key),
			)


static func run_single_ability(ability_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"rogue")
	var ability := _ability(definition, ability_id)
	_assert(failures, "%s/data" % ability_id, ability != null)
	if ability == null:
		return
	var board := _plain_board(Vector2i(10, 8))
	var rogue_pos := Vector2i(2, 3)
	var actor := _place_rogue(board, 1, rogue_pos, ability_id)
	var target_setup := _configure_sim_target(board, ability_id, ability, rogue_pos)
	var target_coord: Vector2i = target_setup.coord
	var target_id: int = target_setup.id
	var action := TimelineAction.make_ability(1, ability, target_coord, target_id)
	if ability_id == &"rogue_evasive_strike":
		var move_coord := rogue_pos + Vector2i(1, 0)
		var enemy_coord := rogue_pos + Vector2i(2, 0)
		AbilitySystem.set_module_target(action, 0, move_coord, -1)
		AbilitySystem.set_module_target(action, 1, enemy_coord, 3)
	_assert(failures, "%s/can_use" % ability_id, AbilitySystem.can_use(board, action))
	if not AbilitySystem.can_use(board, action):
		return
	var board_before := board.clone()
	var plan := Timeline.new()
	plan.add(action)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	var result := SimResult.new()
	result.final_state = board
	result.events = events
	_assert(
		failures,
		"%s/ability_used" % ability_id,
		_events_have_ability(result.events, ability_id),
	)
	ClassScenarioSimOutcome.assert_from_events(
		failures,
		"%s" % ability_id,
		ability,
		result.events,
		board_before,
		result.final_state,
		target_id,
	)
	if ability.target_shape != GameEnums.TargetShape.SINGLE:
		var footprint := GridSystem.get_affected_tiles(
			board_before, actor.position, target_coord, ability.target_shape, ability.target_shape_size,
		)
		_assert(failures, "%s/footprint" % ability_id, footprint.has(target_coord) and not footprint.is_empty())


static func _configure_sim_target(
	board: BoardState,
	ability_id: StringName,
	ability: AbilityData,
	rogue_pos: Vector2i,
) -> Dictionary:
	var target_coord := _target_for(ability_id)
	var target_id := -1
	match ability_id:
		&"rogue_slip_past":
			_place_dummy(board, 3, rogue_pos + Vector2i(1, 0))
			target_coord = rogue_pos + Vector2i(1, 0)
			target_id = 3
		&"rogue_shadow_step":
			_place_dummy(board, 3, rogue_pos + Vector2i(2, 0))
			target_coord = rogue_pos + Vector2i(2, 0)
			target_id = 3
		&"rogue_evasive_strike":
			var move_coord := rogue_pos + Vector2i(1, 0)
			var enemy_coord := rogue_pos + Vector2i(2, 0)
			_place_dummy(board, 3, enemy_coord)
			target_coord = move_coord
			target_id = 3
		&"rogue_smoke_bomb":
			target_coord = rogue_pos
		&"rogue_shadow_swap":
			_place_ally(board, 2, Vector2i(3, 3))
			target_coord = Vector2i(3, 3)
			target_id = 2
		&"rogue_shuriken_volley":
			_place_dummy(board, 3, rogue_pos + Vector2i(2, 0))
			_place_dummy(board, 4, rogue_pos + Vector2i(3, 0))
			target_coord = rogue_pos + Vector2i(2, -1)
			target_id = 3
		&"rogue_poison_flask":
			_place_dummy(board, 3, rogue_pos + Vector2i(2, 0))
			target_coord = rogue_pos + Vector2i(2, 0)
			target_id = 3
		_:
			if ability.targeting_flags & GameEnums.TargetingFlags.ENEMY:
				_place_dummy(board, 3, target_coord)
				target_id = 3
			elif ability.targeting_flags & GameEnums.TargetingFlags.ALLY:
				_place_ally(board, 2, target_coord)
				target_id = 2
	return {"coord": target_coord, "id": target_id}


static func run_upgrade_for(ability_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"rogue")
	var ability := _ability(definition, ability_id)
	_assert(failures, "upgrade/%s/exists" % ability_id, ability != null)
	if ability == null:
		return
	_assert(
		failures,
		"upgrade/%s/profile" % ability_id,
		not ability.upgraded_modules.is_empty() and not ability.upgrade_description.is_empty(),
	)
	var board := _plain_board(Vector2i(10, 8))
	var rogue := _place_rogue(board, 1, Vector2i(2, 3), ability_id)
	rogue.upgraded_abilities.append(ability_id)
	var target_setup := _configure_sim_target(board, ability_id, ability, rogue.position)
	var target_coord: Vector2i = target_setup.coord
	var target_id: int = target_setup.id
	var action := TimelineAction.make_ability(1, ability, target_coord, target_id)
	if ability_id == &"rogue_evasive_strike":
		var move_coord := rogue.position + Vector2i(1, 0)
		var enemy_coord := rogue.position + Vector2i(2, 0)
		AbilitySystem.set_module_target(action, 0, move_coord, -1)
		AbilitySystem.set_module_target(action, 1, enemy_coord, target_id)
	_assert(failures, "upgrade/%s/can_use" % ability_id, AbilitySystem.can_use(board, action))
	if not AbilitySystem.can_use(board, action):
		return
	var plan := Timeline.new()
	plan.add(action)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	_assert(
		failures,
		"upgrade/%s/ability_used" % ability_id,
		_events_have_ability(events, ability_id),
	)


static func run_passive_factory(passive_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"rogue")
	var passive := _passive(definition, passive_id)
	_assert(failures, "passive/%s/exists" % passive_id, passive != null)
	if passive == null:
		return
	for row: Dictionary in PASSIVE_ROWS:
		if row.id != passive_id:
			continue
		for key: StringName in row.keys:
			_assert(
				failures,
				"passive/%s/%s" % [passive_id, key],
				passive.modifiers.has(key),
			)
		_assert(
			failures,
			"passive/%s/upgrade_text" % passive_id,
			not passive.upgraded_description.is_empty(),
		)
		_run_passive_trigger(passive_id, failures)
		return
	failures.append("passive/%s/row_missing" % passive_id)


static func _run_passive_trigger(passive_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"rogue")
	var passive := _passive(definition, passive_id)
	if passive == null:
		return
	var board := _plain_board(Vector2i(8, 6))
	var rogue := _place_rogue(board, 1, Vector2i(2, 2), &"rogue_kidney_strike")
	rogue.active_passives.append(passive)
	rogue._recalculate_stats(board)
	match passive_id:
		&"backstab":
			var dummy := _place_dummy(board, 3, Vector2i(2, 3))
			dummy.facing = GameEnums.Facing.SOUTH
			rogue.position = Vector2i(2, 2)
			GridSystem.set_occupant(board, Vector2i(2, 3), 3)
			GridSystem.set_occupant(board, Vector2i(2, 2), 1)
			_ROGUE_SYSTEMS.apply_attack_ignore_def(board, rogue, dummy)
			_assert(
				failures,
				"passive/backstab/ignore_def",
				int(rogue.passive_flags.get("attack_ignore_def", 0)) > 0,
			)
		&"blink_mastery":
			rogue.passive_flags["jumped_or_teleported_this_turn"] = true
			var events: Array[SimEvent] = []
			_ROGUE_SYSTEMS.after_teleport(board, rogue, null, _ability(definition, &"rogue_shadow_step"), events)
			_assert(
				failures,
				"passive/blink_mastery/bonus",
				int(rogue.passive_flags.get("rogue_after_teleport_attack_bonus", 0)) >= 3,
			)
		&"debuff_overload":
			var debuffed_enemy := _place_dummy(board, 7, Vector2i(4, 2))
			debuffed_enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.POISON, 1))
			var dmg_events: Array[SimEvent] = []
			_ROGUE_SYSTEMS.turn_start(board, rogue, dmg_events)
			_assert(
				failures,
				"passive/debuff_overload/tick",
				_events_have_damage_to(dmg_events, debuffed_enemy.id),
			)
		&"shadow_slip":
			var enemy := _place_dummy(board, 3, Vector2i(3, 2))
			var slip_events: Array[SimEvent] = []
			_ROGUE_SYSTEMS.on_moved_through_enemy(board, rogue, [enemy.id], slip_events)
			_assert(
				failures,
				"passive/shadow_slip/blind_mark",
				enemy.has_status(GameEnums.StatusType.BLIND) and enemy.has_status(GameEnums.StatusType.MARK),
			)
		&"blink_strike":
			_assert(
				failures,
				"passive/blink_strike/range",
				_ROGUE_SYSTEMS.basic_attack_range_bonus(rogue) >= 2,
			)
		&"pass":
			_assert(
				failures,
				"passive/pass/trap_skip",
				_ROGUE_SYSTEMS.should_skip_trap_entry(rogue),
			)
		&"shadow_strike":
			var strike_target := _place_dummy(board, 4, Vector2i(3, 2))
			rogue.position = Vector2i(2, 2)
			var strike_events: Array[SimEvent] = []
			_ROGUE_SYSTEMS.after_teleport(
				board, rogue, strike_target, _ability(definition, &"rogue_shadow_step"), strike_events,
			)
			_assert(
				failures,
				"passive/shadow_strike/mark",
				strike_target.has_status(GameEnums.StatusType.MARK),
			)
		&"lethal_position":
			rogue.passive_flags["rogue_tiles_moved"] = 3
			var dmg_bonus := _ROGUE_SYSTEMS.damage_bonus(
				board, rogue, _place_dummy(board, 5, Vector2i(4, 2)), null,
			)
			_assert(failures, "passive/lethal_position/str", dmg_bonus >= 3)
		&"killing_intent":
			var low_hp := _place_dummy(board, 6, Vector2i(3, 2))
			low_hp.health.current_hp = 1
			rogue.position = Vector2i(2, 2)
			_ROGUE_SYSTEMS.turn_end(board, rogue, [])
			_assert(
				failures,
				"passive/killing_intent/ap_flag",
				int(rogue.passive_flags.get("rogue_bonus_ap_next_turn", 0)) >= 1,
			)
		&"shadow_clone":
			var clone_events: Array[SimEvent] = []
			var units_before := board.units.size()
			var corpse := UnitState.create(
				99,
				DataLibrary.get_training_dummy(),
				GameEnums.Team.ENEMY,
				Vector2i(6, 2),
			)
			corpse.health.current_hp = 0
			_ROGUE_SYSTEMS.on_kill(board, rogue, corpse, clone_events)
			_assert(
				failures,
				"passive/shadow_clone/decoy_spawn",
				board.units.size() > units_before or _events_have_spawn(clone_events),
			)
		&"phase_shift":
			var phase_events: Array[SimEvent] = []
			_ROGUE_SYSTEMS.after_teleport(board, rogue, null, _ability(definition, &"rogue_shadow_step"), phase_events)
			_assert(failures, "passive/phase_shift/stealth", rogue.has_status(GameEnums.StatusType.STEALTH))
		&"shadow_meld":
			board.set_tile_terrain(rogue.position, DataLibrary.get_terrain(&"smoke"))
			_ROGUE_SYSTEMS.apply_smoke_spell_bonus(board, rogue, _ability(definition, &"rogue_smoke_bomb"))
			_assert(
				failures,
				"passive/shadow_meld/magic_bonus",
				int(rogue.passive_flags.get("mage_spell_magic_bonus", 0)) >= 2,
			)
		&"miasma_spreader":
			var spread_source := _place_dummy(board, 8, Vector2i(4, 2))
			spread_source.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.POISON, 1))
			var spread_target := _place_dummy(board, 9, Vector2i(5, 2))
			_ROGUE_SYSTEMS.on_attack_hit(board, rogue, spread_source, [])
			_assert(
				failures,
				"passive/miasma_spreader/spread",
				spread_target.has_status(GameEnums.StatusType.POISON),
			)
		&"panic_cascade":
			var debuffed := _place_dummy(board, 10, Vector2i(4, 2))
			debuffed.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.POISON, 1))
			rogue.passive_flags["__current_ability"] = _ability(definition, &"rogue_lethal_flourish")
			var panic_bonus := _ROGUE_SYSTEMS.damage_bonus(board, rogue, debuffed, null)
			_assert(failures, "passive/panic_cascade/bonus", panic_bonus >= 2)
		&"mind_static":
			var knight_def := FactoryTestHelpers.build_unit(&"knight")
			var def_target := UnitState.create(
				11, knight_def, GameEnums.Team.ENEMY, Vector2i(3, 2),
			)
			board.add_unit(def_target)
			GridSystem.set_occupant(board, Vector2i(3, 2), 11)
			var adjustments := _ROGUE_SYSTEMS.dynamic_stat_adjustments(board, def_target)
			_assert(
				failures,
				"passive/mind_static/no_shield",
				not _ROGUE_SYSTEMS.can_gain_shield(board, def_target),
			)
			_assert(
				failures,
				"passive/mind_static/def_down",
				int(adjustments.get("defense", 0)) < 0,
			)
		&"board_scrambler":
			var swap_events: Array[SimEvent] = []
			var scrambler_target := _place_dummy(board, 12, Vector2i(4, 2))
			var swap_partner := _place_dummy(board, 13, Vector2i(5, 2))
			var target_pos_before := scrambler_target.position
			var partner_pos_before := swap_partner.position
			_ROGUE_SYSTEMS.on_dealt_damage(board, rogue, scrambler_target, swap_events)
			_assert(
				failures,
				"passive/board_scrambler/swap_event",
				scrambler_target.position != target_pos_before
					or swap_partner.position != partner_pos_before
					or _events_have_move(swap_events),
			)


static func run_core_passive_triggers(failures: Array[String]) -> void:
	# The shared pass-through contract is the common trigger owned by movement.
	var rogue := FactoryTestHelpers.build_unit(&"rogue")
	var passive := _passive(rogue, &"pass")
	_assert(failures, "pass/innate", passive != null and passive.modifiers.get("ghost_move", false))
	var board := _plain_board(Vector2i(8, 6))
	var unit := _place_rogue(board, 1, Vector2i(2, 2), &"rogue_slip_past")
	unit.active_passives.append(passive)
	_assert(
		failures,
		"pass/shared_movement_contract",
		MovementSystem.can_pass_through_enemy(unit, _ability(rogue, &"rogue_slip_past")),
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


static func _place_rogue(board: BoardState, unit_id: int, coord: Vector2i, ability_id: StringName) -> UnitState:
	var definition := FactoryTestHelpers.build_unit(&"rogue")
	var unit := UnitState.create(
		unit_id,
		definition,
		GameEnums.Team.PLAYER,
		coord,
		{"active_abilities": [DataLibrary.get_universal_run(), _ability(definition, ability_id)]},
	)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	unit.ability.points_left = unit.ability.max_points
	unit.movement.points_left = unit.movement.max_points
	return unit


static func _place_ally(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var unit := UnitState.create(
		unit_id, FactoryTestHelpers.build_unit(&"rogue"),
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


static func _target_for(ability_id: StringName) -> Vector2i:
	match ability_id:
		&"rogue_smoke_bomb":
			return Vector2i(2, 3)
		&"rogue_shadow_swap":
			return Vector2i(3, 3)
		&"rogue_slip_past", &"rogue_shadow_step", &"rogue_kidnap":
			return Vector2i(3, 3)
		&"rogue_kidney_strike", &"rogue_blindside", &"rogue_throat_slit", &"rogue_lethal_flourish":
			return Vector2i(3, 3)
		_:
			return Vector2i(4, 3)


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


static func _events_have_ability(events: Array[SimEvent], ability_id: StringName) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ABILITY_USED \
				and event.data.get("ability") == ability_id:
			return true
	return false


static func _events_have_damage_to(events: Array[SimEvent], unit_id: int) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.UNIT_DAMAGED \
				and int(event.data.get("unit", -1)) == unit_id:
			return true
	return false


static func _events_have_spawn(events: Array[SimEvent]) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.UNIT_SPAWNED:
			return true
	return false


static func _events_have_move(events: Array[SimEvent]) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.UNIT_MOVED:
			return true
	return false


static func _assert(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
