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
	{"id": &"panic_cascade", "keys": [&"panic_on_debuff"]},
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
	match ability_id:
		&"rogue_slip_past":
			var slipped := result.final_state.get_unit_by_id(1)
			var blocker := result.final_state.get_unit_by_id(3)
			_assert(
				failures,
				"rogue_slip_past/land_opposite",
				slipped != null and blocker != null
					and slipped.position == blocker.position + Vector2i(1, 0)
					and blocker.position == rogue_pos + Vector2i(1, 0),
			)
		&"rogue_amnesia_dust":
			var dusted := result.final_state.get_unit_by_id(target_id)
			_assert(
				failures,
				"rogue_amnesia_dust/blind_now",
				dusted != null and dusted.has_status(GameEnums.StatusType.BLIND),
			)
			_assert(
				failures,
				"rogue_amnesia_dust/confusion_deferred",
				dusted != null
					and not dusted.has_status(GameEnums.StatusType.CONFUSION)
					and bool(dusted.passive_flags.get("confusion_next_turn", false)),
			)
		&"rogue_kidnap":
			var kidnapper := result.final_state.get_unit_by_id(1)
			var victim := result.final_state.get_unit_by_id(target_id)
			_assert(
				failures,
				"rogue_kidnap/push_away_from_caster",
				kidnapper != null and victim != null and kidnapper.id != victim.id
					and kidnapper.position != victim.position
					and GridSystem.manhattan(kidnapper.position, victim.position) >= 2,
			)
		&"rogue_grappling_hook":
			var hook_user := result.final_state.get_unit_by_id(1)
			var hooked := result.final_state.get_unit_by_id(target_id)
			_assert(
				failures,
				"rogue_grappling_hook/adjacent",
				hook_user != null and hooked != null
					and GridSystem.manhattan(hook_user.position, hooked.position) == 1,
			)
	if ability.target_shape != GameEnums.TargetShape.SINGLE:
		run_shaped_footprint(ability_id, failures)


static func run_passive_trigger_proof(passive_id: StringName, failures: Array[String]) -> void:
	_run_passive_trigger(passive_id, failures)


static func run_passive_upgrade_for(passive_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"rogue")
	var passive := _passive(definition, passive_id)
	if passive == null or passive.upgraded_description.is_empty():
		return
	var board := _plain_board(Vector2i(8, 6))
	var rogue := _place_rogue(board, 1, Vector2i(2, 2), &"rogue_kidney_strike")
	rogue.active_passives.append(passive)
	rogue.upgraded_passives.append(passive_id)
	rogue._recalculate_stats(board)
	match passive_id:
		&"blink_mastery":
			rogue.passive_flags["jumped_or_teleported_this_turn"] = true
			_ROGUE_SYSTEMS.after_teleport(board, rogue, null, _ability(definition, &"rogue_shadow_step"), [])
			_assert(
				failures,
				"passive/blink_mastery/upgraded_bonus",
				int(rogue.passive_flags.get("rogue_after_teleport_attack_bonus", 0)) >= 4,
			)
		&"debuff_overload":
			var enemy := _place_dummy(board, 7, Vector2i(4, 2))
			enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.POISON, 1))
			enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLIND, 1))
			var events: Array[SimEvent] = []
			_ROGUE_SYSTEMS.turn_start(board, rogue, events)
			var total := 0
			for event: SimEvent in events:
				if event.type == GameEnums.SimEventType.UNIT_DAMAGED \
						and int(event.data.get("unit", -1)) == enemy.id:
					total += int(event.data.get("amount", 0))
			_assert(failures, "passive/debuff_overload/upgraded_tick", total >= 4)
		&"mind_static":
			var knight_def := FactoryTestHelpers.build_unit(&"knight")
			var def_target := UnitState.create(
				11, knight_def, GameEnums.Team.ENEMY, Vector2i(5, 2),
			)
			board.add_unit(def_target)
			GridSystem.set_occupant(board, Vector2i(5, 2), 11)
			var adjustments := _ROGUE_SYSTEMS.dynamic_stat_adjustments(board, def_target)
			_assert(
				failures,
				"passive/mind_static/upgraded_def_down",
				int(adjustments.get("defense", 0)) <= -2,
			)
		&"blink_strike":
			_assert(
				failures,
				"passive/blink_strike/upgraded_range",
				_ROGUE_SYSTEMS.basic_attack_range_bonus(rogue) >= 3,
			)
		&"shadow_meld":
			board.set_tile_terrain(rogue.position, DataLibrary.get_terrain(&"smoke"))
			_ROGUE_SYSTEMS.apply_smoke_spell_bonus(board, rogue, _ability(definition, &"rogue_smoke_bomb"))
			_assert(
				failures,
				"passive/shadow_meld/upgraded_magic",
				int(rogue.passive_flags.get("mage_spell_magic_bonus", 0)) >= 3,
			)
		&"killing_intent":
			var mid_hp := _place_dummy(board, 6, Vector2i(3, 2))
			mid_hp.health.current_hp = int(mid_hp.health.max_hp * 0.6)
			rogue.position = Vector2i(2, 2)
			_ROGUE_SYSTEMS.turn_end(board, rogue, [])
			_assert(
				failures,
				"passive/killing_intent/upgraded_threshold",
				int(rogue.passive_flags.get("rogue_bonus_ap_next_turn", 0)) >= 1,
			)
		&"miasma_spreader":
			_assert(
				failures,
				"passive/miasma_spreader/upgraded_range",
				int(_ROGUE_SYSTEMS.passive_value(rogue, &"miasma_spreader_range", &"upgraded_miasma_spreader_range", 1)) >= 2,
			)
		&"shadow_strike":
			var strike_target := _place_dummy(board, 4, Vector2i(3, 2))
			rogue.position = Vector2i(2, 2)
			_ROGUE_SYSTEMS.after_teleport(
				board, rogue, strike_target, _ability(definition, &"rogue_shadow_step"), [],
			)
			_assert(
				failures,
				"passive/shadow_strike/upgraded_silence",
				strike_target.has_status(GameEnums.StatusType.SILENCE),
			)
		&"shadow_slip":
			var slip_enemy := _place_dummy(board, 3, Vector2i(3, 2))
			_ROGUE_SYSTEMS.on_moved_through_enemy(board, rogue, [slip_enemy.id], [])
			_assert(
				failures,
				"passive/shadow_slip/upgraded_poison",
				slip_enemy.has_status(GameEnums.StatusType.POISON),
			)
		&"lethal_position":
			rogue.passive_flags["rogue_tiles_moved"] = 2
			rogue._recalculate_stats(board)
			_assert(
				failures,
				"passive/lethal_position/upgraded_move_scaling",
				rogue.current_defense >= 4
					and _ROGUE_SYSTEMS.moved_tiles_range_bonus(rogue) >= 2,
			)
		&"board_scrambler":
			var scrambler_target := _place_dummy(board, 12, Vector2i(4, 2))
			_place_dummy(board, 13, Vector2i(5, 2))
			_ROGUE_SYSTEMS.on_dealt_damage(board, rogue, scrambler_target, [])
			_assert(
				failures,
				"passive/board_scrambler/upgraded_root",
				scrambler_target.has_status(GameEnums.StatusType.ROOT),
			)
		&"shadow_clone":
			var corpse := UnitState.create(
				99, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, Vector2i(6, 2),
			)
			corpse.health.current_hp = 0
			var blast_dummy := _place_dummy(board, 20, Vector2i(6, 3))
			var blast_hp := blast_dummy.health.current_hp
			var clone_events: Array[SimEvent] = []
			_ROGUE_SYSTEMS.on_kill(board, rogue, corpse, clone_events)
			var decoy: UnitState = null
			for unit: UnitState in board.units:
				if unit != null and unit.passive_flags.get("rogue_decoy", false):
					decoy = unit
					break
			if decoy != null:
				decoy.health.current_hp = 0
				_ROGUE_SYSTEMS.on_unit_died(board, decoy, clone_events)
			_assert(
				failures,
				"passive/shadow_clone/upgraded_explode",
				blast_dummy.health.current_hp < blast_hp or _events_have_damage_to(clone_events, blast_dummy.id),
			)
		&"phase_shift":
			_ROGUE_SYSTEMS.after_teleport(board, rogue, null, _ability(definition, &"rogue_shadow_step"), [])
			var stealth_target := _place_dummy(board, 5, Vector2i(3, 2))
			_ROGUE_SYSTEMS.apply_attack_ignore_def(board, rogue, stealth_target)
			_assert(
				failures,
				"passive/phase_shift/upgraded_ignore_def",
				int(rogue.passive_flags.get("attack_ignore_def", 0)) > 0,
			)
		&"panic_cascade":
			var confused := _place_dummy(board, 10, Vector2i(4, 2))
			confused.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.CONFUSION, 1))
			confused.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.POISON, 1))
			var panic_events: Array[SimEvent] = []
			_ROGUE_SYSTEMS.on_debuff_applied(board, rogue, confused, panic_events)
			_assert(
				failures,
				"passive/panic_cascade/upgraded_bonus",
				_events_have_damage_to(panic_events, confused.id),
			)
		&"backstab":
			var bleed_board := _plain_board(Vector2i(8, 6))
			var bleed_rogue := _place_rogue(bleed_board, 1, Vector2i(2, 2), &"rogue_kidney_strike")
			bleed_rogue.active_passives.append(passive)
			bleed_rogue.upgraded_passives.append(passive_id)
			var bleed_target := _place_dummy(bleed_board, 3, Vector2i(2, 3))
			bleed_target.facing = GameEnums.Facing.SOUTH
			bleed_rogue.position = Vector2i(2, 2)
			_ROGUE_SYSTEMS.apply_attack_ignore_def(bleed_board, bleed_rogue, bleed_target)
			_assert(
				failures,
				"passive/backstab/upgraded_bleed",
				bleed_target.has_status(GameEnums.StatusType.BLEED),
			)
		&"pass":
			var pierce_board := _plain_board(Vector2i(8, 6))
			var pierce_rogue := _place_rogue(pierce_board, 1, Vector2i(2, 2), &"rogue_slip_past")
			pierce_rogue.active_passives.append(passive)
			pierce_rogue.upgraded_passives.append(passive_id)
			var pierce_enemy := _place_dummy(pierce_board, 3, Vector2i(3, 2))
			_ROGUE_SYSTEMS.on_moved_through_enemy(pierce_board, pierce_rogue, [pierce_enemy.id], [])
			_assert(
				failures,
				"passive/pass/upgraded_pierce",
				int(pierce_rogue.passive_flags.get("rogue_pierce_target_id", -1)) == pierce_enemy.id,
			)


static func run_shaped_footprint(ability_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"rogue")
	var ability := _ability(definition, ability_id)
	if ability == null or not AoeFootprintQaHarness.ability_requires_footprint_qa(ability):
		return
	match ability_id:
		&"rogue_shuriken_volley":
			_run_shuriken_volley_footprint(failures, ability)
		&"rogue_smoke_bomb":
			_run_smoke_bomb_footprint(failures, ability)
		&"rogue_poison_flask":
			_run_poison_flask_footprint(failures, ability)
		_:
			failures.append("footprint/%s/unhandled_shaped_skill" % ability_id)


static func assert_grid_footprint_excludes(
	failures: Array[String],
	tag: String,
	board: BoardState,
	origin: Vector2i,
	target: Vector2i,
	shape: GameEnums.TargetShape,
	size: int,
	outside: Vector2i,
) -> void:
	AoeFootprintQaHarness.assert_footprint_excludes(
		failures, tag, board, origin, target, shape, size, outside,
	)


static func _run_shuriken_volley_footprint(failures: Array[String], ability: AbilityData) -> void:
	var board := _plain_board(Vector2i(10, 8))
	var origin := Vector2i(3, 4)
	var target := Vector2i(5, 3)
	var rogue := _place_rogue(board, 1, origin, &"rogue_shuriken_volley")
	var inside := _place_dummy(board, 2, Vector2i(5, 4))
	var outside := _place_dummy(board, 3, Vector2i(8, 8))
	var inside_hp := inside.health.current_hp
	var outside_hp := outside.health.current_hp
	assert_grid_footprint_excludes(
		failures, "shuriken/footprint/grid", board, origin, target,
		ability.target_shape, ability.target_shape_size, Vector2i(8, 8),
	)
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, ability, target, 2))
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	var inside_after := board.get_unit_by_id(2)
	var outside_after := board.get_unit_by_id(3)
	_assert(
		failures,
		"shuriken/footprint/inside_damaged",
		inside_after != null and inside_after.health.current_hp < inside_hp,
	)
	_assert(
		failures,
		"shuriken/footprint/outside_untouched",
		outside_after != null and outside_after.health.current_hp == outside_hp,
	)


static func _run_smoke_bomb_footprint(failures: Array[String], ability: AbilityData) -> void:
	var board := _plain_board(Vector2i(10, 8))
	var origin := Vector2i(4, 4)
	var rogue := _place_rogue(board, 1, origin, &"rogue_smoke_bomb")
	var footprint: Array[Vector2i] = GridSystem.get_affected_tiles(
		board, origin, origin, ability.target_shape, ability.target_shape_size,
	)
	var inside_coord := origin
	for tile: Vector2i in footprint:
		if tile != origin:
			inside_coord = tile
			break
	_place_ally(board, 2, inside_coord)
	_place_dummy(board, 3, Vector2i(8, 8))
	assert_grid_footprint_excludes(
		failures, "smoke/footprint/grid", board, origin, origin,
		ability.target_shape, ability.target_shape_size, Vector2i(8, 8),
	)
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, ability, origin, -1))
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	_assert(
		failures,
		"smoke/footprint/ability_used",
		_events_have_ability(events, &"rogue_smoke_bomb"),
	)
	var smoke_ally := board.get_unit_by_id(2)
	_assert(
		failures,
		"smoke/footprint/no_cast_stealth",
		smoke_ally == null or not smoke_ally.has_status(GameEnums.StatusType.STEALTH),
	)


static func _run_poison_flask_footprint(failures: Array[String], ability: AbilityData) -> void:
	var board := _plain_board(Vector2i(10, 8))
	var origin := Vector2i(3, 4)
	var target := Vector2i(5, 4)
	var rogue := _place_rogue(board, 1, origin, &"rogue_poison_flask")
	var inside := _place_dummy(board, 2, target)
	var outside := _place_dummy(board, 3, Vector2i(8, 8))
	var inside_hp := inside.health.current_hp
	var outside_hp := outside.health.current_hp
	assert_grid_footprint_excludes(
		failures, "flask/footprint/grid", board, origin, target,
		ability.target_shape, ability.target_shape_size, Vector2i(8, 8),
	)
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, ability, target, 2))
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	var inside_after := board.get_unit_by_id(2)
	var outside_after := board.get_unit_by_id(3)
	_assert(
		failures,
		"flask/footprint/inside_damaged",
		inside_after != null and inside_after.health.current_hp < inside_hp,
	)
	_assert(
		failures,
		"flask/footprint/outside_untouched",
		outside_after != null and outside_after.health.current_hp == outside_hp,
	)
	var hazard_tile := board.get_tile(target)
	_assert(
		failures,
		"flask/footprint/poison_hazard",
		hazard_tile != null and hazard_tile.definition != null and hazard_tile.definition.id == &"poison",
	)


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
	_run_conditional_upgrade(ability_id, failures)
	_assert_upgraded_bible_marker(ability_id, failures)


static func _assert_upgraded_bible_marker(ability_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"rogue")
	var ability := _ability(definition, ability_id)
	if ability == null or ability.upgraded_modules.is_empty():
		failures.append("upgrade/%s/missing_upgraded_modules" % ability_id)
		return
	var upgraded: Array[AbilityModule] = ability.get_active_modules(true)
	var base: Array[AbilityModule] = ability.modules
	if upgraded.is_empty() or base.is_empty():
		failures.append("upgrade/%s/empty_runtime_modules" % ability_id)
		return
	match ability_id:
		&"rogue_slip_past":
			_assert(
				failures,
				"upgrade/rogue_slip_past/def_debuff",
				upgraded[0].legacy_modifiers.has("target_def_debuff"),
			)
		&"rogue_shadow_step":
			_assert(
				failures,
				"upgrade/rogue_shadow_step/behind_motion",
				upgraded[0].motion_mode == GameEnums.MotionMode.BEHIND_TARGET
					and int(upgraded[0].legacy_modifiers.get("behind_target_strength", 0)) >= 1,
			)
		&"rogue_smoke_bomb":
			_assert(
				failures,
				"upgrade/rogue_smoke_bomb/ally_heal",
				int(upgraded[0].legacy_modifiers.get("smoke_ally_heal_per_turn", 0)) >= 1,
			)
		&"rogue_evasive_strike":
			_assert(
				failures,
				"upgrade/rogue_evasive_strike/move_and_strike",
				upgraded[0].amount >= 3 and upgraded[1].amount >= 2,
			)
		&"rogue_grappling_hook":
			_assert(
				failures,
				"upgrade/rogue_grappling_hook/trap_multiplier",
				int(upgraded[0].legacy_modifiers.get("trap_collision_damage_multiplier", 0)) >= 2,
			)
		&"rogue_switcheroo":
			_assert(
				failures,
				"upgrade/rogue_switcheroo/inherit_attacks",
				bool(upgraded[0].legacy_modifiers.get("inherit_incoming_attacks", false)),
			)
		&"rogue_blindside":
			_assert(
				failures,
				"upgrade/rogue_blindside/stagger_bonus",
				int(upgraded[0].legacy_modifiers.get("if_target_staggered_bonus", 0)) >= 2,
			)
		&"rogue_amnesia_dust":
			_assert(
				failures,
				"upgrade/rogue_amnesia_dust/poison_layer",
				upgraded[0].layers.size() > base[0].layers.size(),
			)
		&"rogue_death_mark":
			_assert(
				failures,
				"upgrade/rogue_death_mark/refresh_mark",
				bool(upgraded[0].legacy_modifiers.get("on_kill_refresh_mark_zero_ap", false)),
			)
		&"rogue_shadow_swap":
			_assert(
				failures,
				"upgrade/rogue_shadow_swap/def_layer",
				not upgraded[0].layers.is_empty(),
			)
		&"rogue_kidnap":
			_assert(
				failures,
				"upgrade/rogue_kidnap/stagger_both",
				bool(upgraded[0].legacy_modifiers.get("swap_collision_stagger_both", false)),
			)
		&"rogue_shuriken_volley":
			_assert(
				failures,
				"upgrade/rogue_shuriken_volley/pierce_blind",
				bool(upgraded[0].legacy_modifiers.get("pierce_vs_blind", false)),
			)
		&"rogue_poison_flask":
			_assert(
				failures,
				"upgrade/rogue_poison_flask/hazard_blind",
				bool(upgraded[0].legacy_modifiers.get("hazard_blind_on_entry", false)),
			)
		&"rogue_kidney_strike", &"rogue_throat_slit", &"rogue_lethal_flourish":
			pass
		_:
			failures.append("upgrade/%s/unmapped_bible_marker" % ability_id)


static func _run_conditional_upgrade(ability_id: StringName, failures: Array[String]) -> void:
	match ability_id:
		&"rogue_kidney_strike":
			var board := _plain_board(Vector2i(8, 6))
			var target := _place_dummy(board, 3, Vector2i(3, 3))
			target.facing = GameEnums.Facing.SOUTH
			var rogue := _place_rogue(board, 1, Vector2i(3, 2), ability_id)
			rogue.upgraded_abilities.append(ability_id)
			rogue.facing = GameEnums.Facing.SOUTH
			var ability := _ability(FactoryTestHelpers.build_unit(&"rogue"), ability_id)
			var plan := Timeline.new()
			plan.add(TimelineAction.make_ability(1, ability, target.position, target.id))
			var events: Array[SimEvent] = []
			Simulator.simulate_player_turn(board, plan, events)
			_assert(
				failures,
				"upgrade/rogue_kidney_strike/behind_root",
				target.has_status(GameEnums.StatusType.ROOT),
			)
		&"rogue_throat_slit":
			var board := _plain_board(Vector2i(8, 6))
			var rogue := _place_rogue(board, 1, Vector2i(2, 3), ability_id)
			rogue.upgraded_abilities.append(ability_id)
			var victim := _place_dummy(board, 3, Vector2i(3, 3))
			victim.health.current_hp = 1
			var neighbor := _place_dummy(board, 4, Vector2i(4, 3))
			var ability := _ability(FactoryTestHelpers.build_unit(&"rogue"), ability_id)
			var plan := Timeline.new()
			plan.add(TimelineAction.make_ability(1, ability, victim.position, victim.id))
			Simulator.simulate_player_turn(board, plan, [])
			_assert(
				failures,
				"upgrade/rogue_throat_slit/spread_silence",
				neighbor.has_status(GameEnums.StatusType.SILENCE),
			)
		&"rogue_lethal_flourish":
			var board := _plain_board(Vector2i(8, 6))
			var rogue := _place_rogue(board, 1, Vector2i(2, 3), ability_id)
			rogue.upgraded_abilities.append(ability_id)
			var ability := _ability(FactoryTestHelpers.build_unit(&"rogue"), ability_id)
			var victim := _place_dummy(board, 3, Vector2i(3, 3))
			victim.health.current_hp = 1
			rogue.ability.points_left = 0
			rogue.passive_flags["__current_ability"] = ability
			var kill_events: Array[SimEvent] = []
			_ROGUE_SYSTEMS.on_kill(board, rogue, victim, kill_events)
			_assert(
				failures,
				"upgrade/rogue_lethal_flourish/kill_ap",
				rogue.ability.points_left >= 1,
			)
		_:
			pass


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
		var trigger_board := _plain_board(Vector2i(8, 6))
		var trigger_events: Array[SimEvent] = []
		Simulator.simulate_player_turn(trigger_board, Timeline.new(), trigger_events)
		_run_passive_trigger(passive_id, failures)
		run_passive_upgrade_for(passive_id, failures)
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
			rogue.movement.points_left = 0
			_ROGUE_SYSTEMS.on_attack_hit(board, rogue, enemy, [])
			_assert(
				failures,
				"passive/shadow_slip/mov_refund_on_attack",
				rogue.movement.points_left >= 1,
			)
		&"blink_strike":
			_assert(
				failures,
				"passive/blink_strike/range",
				_ROGUE_SYSTEMS.basic_attack_range_bonus(rogue) >= 2,
			)
			var blink_dummy := _place_dummy(board, 22, Vector2i(4, 2))
			var basic: AbilityData = null
			for ability: AbilityData in definition.abilities:
				if ability != null and DataLibrary.is_basic_ability(ability.id):
					basic = ability
					break
			_ROGUE_SYSTEMS.try_blink_strike(board, rogue, blink_dummy, [], basic)
			_assert(
				failures,
				"passive/blink_strike/teleport",
				GridSystem.manhattan(rogue.position, blink_dummy.position) == 1,
			)
		&"pass":
			_assert(
				failures,
				"passive/pass/trap_skip",
				_ROGUE_SYSTEMS.should_skip_trap_entry(rogue),
			)
			var pass_enemy := _place_dummy(board, 23, Vector2i(3, 2))
			_ROGUE_SYSTEMS.on_moved_through_enemy(board, rogue, [pass_enemy.id], [])
			_assert(
				failures,
				"passive/pass/base_no_pierce",
				int(rogue.passive_flags.get("rogue_pierce_target_id", -1)) != pass_enemy.id,
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
			rogue._recalculate_stats(board)
			_assert(
				failures,
				"passive/lethal_position/str",
				rogue.current_strength >= 7 and _ROGUE_SYSTEMS.moved_tiles_range_bonus(rogue) == 2,
			)
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
			_assert(
				failures,
				"passive/phase_shift/stealth",
				rogue.has_status(GameEnums.StatusType.STEALTH)
					and bool(rogue.passive_flags.get("stealth_until_attack", false)),
			)
			_ROGUE_SYSTEMS.on_attack_hit(board, rogue, _place_dummy(board, 21, Vector2i(3, 2)), [])
			_assert(
				failures,
				"passive/phase_shift/consume_on_attack",
				not rogue.has_status(GameEnums.StatusType.STEALTH),
			)
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
			var panic_events: Array[SimEvent] = []
			_ROGUE_SYSTEMS.on_debuff_applied(board, rogue, debuffed, panic_events)
			_assert(
				failures,
				"passive/panic_cascade/bonus",
				_events_have_damage_to(panic_events, debuffed.id),
			)
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
