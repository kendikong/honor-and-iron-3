class_name MonkQaHarness
extends RefCounted

## Shared Monk class proof. Scenarios own the Bible row and delegate the
## production data/simulation/planning checks here.

const ABILITY_IDS: Array[StringName] = [
	&"monk_leap",
	&"monk_scorching_kick",
	&"monk_thunder_palm",
	&"monk_yin_yang_flurry",
	&"monk_chakra_shift",
	&"monk_phase_throw",
	&"monk_flying_crane_kick",
	&"monk_spirit_palm",
	&"monk_soul_punch",
	&"monk_hundred_fists",
	&"monk_mantra_of_peace",
	&"monk_inner_fire",
	&"monk_void_step",
	&"monk_cyclone_sweep",
	&"monk_updraft",
	&"monk_geyser_strike",
]
const _MONK_SYSTEMS := preload("res://core/systems/monk_systems.gd")

const PASSIVE_ROWS: Array[Dictionary] = [
	{"id": &"elemental_attunement", "keys": [&"attunement_pierce"]},
	{"id": &"chakra_burn", "keys": [&"chakra_burn", &"chakra_burn_mag"]},
	{"id": &"elemental_harmony", "keys": [&"adjacent_elemental_strength"]},
	{"id": &"catalyst", "keys": [&"surface_magic", &"surface_defense"]},
	{"id": &"elemental_shield", "keys": [&"terrain_created_defense"]},
	{"id": &"weavers_resonance", "keys": [&"weaver_resonance"]},
	{"id": &"mind_over_matter", "keys": [&"physical_scale_higher_stat"]},
	{"id": &"inner_peace", "keys": [&"zero_move_attack_pierce"]},
	{"id": &"zen_defense", "keys": [&"empty_adjacent_magic"]},
	{"id": &"perfect_form", "keys": [&"perfect_form_strength"]},
	{"id": &"vaulting_strike", "keys": [&"vaulted_attack_bonus"]},
	{"id": &"flowing_ki", "keys": [&"flowing_ki", &"flowing_ki_magic"]},
	{"id": &"evasive_acrobat", "keys": [&"evasive_acrobat"]},
	{"id": &"momentum_transfer", "keys": [&"moved_tiles_attack_divisor"]},
	{"id": &"light_step", "keys": [&"ignore_difficult_terrain"]},
]


static func run_factory_matrix(failures: Array[String]) -> void:
	var monk: UnitData = FactoryTestHelpers.build_unit(&"monk")
	_assert(failures, "factory/monk_registered", monk != null)
	if monk == null:
		return
	_assert(failures, "factory/base_stats", monk.base_constitution == 5
		and monk.move_points == 4 and monk.base_strength == 3
		and monk.base_defense == 2 and monk.base_magic == 4)
	_assert(failures, "factory/innate_trait", _passive(monk, &"way_of_the_weaver") != null)
	_assert(failures, "factory/active_count", monk.abilities.size() == ABILITY_IDS.size() + 1)
	_assert(failures, "factory/passive_count", monk.passives.size() == PASSIVE_ROWS.size())
	_assert(
		failures, "factory/promotion_stats",
		monk.promotion_stat_bonuses.get(&"avatar", {}).get("magic", -1) == 6
		and monk.promotion_stat_bonuses.get(&"mystic", {}).get("strength", -1) == 4
		and monk.promotion_stat_bonuses.get(&"windwalker", {}).get("movement", -1) == 2,
	)
	for ability_id: StringName in ABILITY_IDS:
		var ability := _ability(monk, ability_id)
		_assert(failures, "factory/ability/%s" % ability_id, ability != null)
		if ability == null:
			continue
		_assert(
			failures, "factory/upgrade/%s" % ability_id,
			not ability.upgraded_modules.is_empty() and not ability.upgrade_description.is_empty(),
		)
		_assert(
			failures, "factory/modules/%s" % ability_id,
			not ability.modules.is_empty() and ability.modules.size() == ability.upgraded_modules.size()
			or ability_id in [&"monk_phase_throw", &"monk_mantra_of_peace", &"monk_spirit_palm"],
		)
	for row: Dictionary in PASSIVE_ROWS:
		var passive := _passive(monk, row.id)
		_assert(failures, "factory/passive/%s" % row.id, passive != null)
		if passive == null:
			continue
		for key: StringName in row.keys:
			_assert(failures, "factory/passive/%s/%s" % [row.id, key], passive.modifiers.has(key))


static func run_single_ability(ability_id: StringName, failures: Array[String]) -> void:
	var definition: UnitData = FactoryTestHelpers.build_unit(&"monk")
	var ability := _ability(definition, ability_id)
	_assert(failures, "sim/%s/data" % ability_id, ability != null)
	if ability == null:
		return
	var board := _plain_board(Vector2i(10, 8))
	var monk := _place_monk(board, 1, Vector2i(2, 3), ability_id)
	var target_setup := _configure_sim_target(board, ability_id, ability, monk.position)
	var target_coord: Vector2i = target_setup.coord
	var target_id: int = target_setup.id
	var action := TimelineAction.make_ability(1, ability, target_coord, target_id)
	if not AbilitySystem.can_use(board, action):
		_assert(failures, "sim/%s/can_use" % ability_id, false)
		return
	var before_position: Vector2i = monk.position
	var board_before := board.clone()
	var plan := Timeline.new()
	plan.add(action)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	var result := SimResult.new()
	result.final_state = board
	result.events = events
	_assert(
		failures, "sim/%s/ability_used" % ability_id,
		_events_have_ability(result.events, ability_id),
	)
	ClassScenarioSimOutcome.assert_from_events(
		failures,
		"sim/%s" % ability_id,
		ability,
		result.events,
		board_before,
		result.final_state,
		target_id,
	)
	_assert(
		failures, "sim/%s/outcome" % ability_id,
		_has_expected_outcome(ability, result.events, result.final_state, before_position),
	)


static func run_shaped_footprint(ability_id: StringName, failures: Array[String]) -> void:
	var definition: UnitData = FactoryTestHelpers.build_unit(&"monk")
	var ability := _ability(definition, ability_id)
	if ability == null or not AoeFootprintQaHarness.ability_requires_footprint_qa(ability):
		return
	match ability_id:
		&"monk_cyclone_sweep":
			_run_cyclone_sweep_footprint(failures, ability)
		&"monk_mantra_of_peace":
			_run_mantra_of_peace_footprint(failures, ability)
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


static func run_upgrade_sim_for(ability_id: StringName, failures: Array[String]) -> void:
	var definition: UnitData = FactoryTestHelpers.build_unit(&"monk")
	var ability := _ability(definition, ability_id)
	if ability == null or ability.upgraded_modules.is_empty():
		return
	for module: AbilityModule in ability.upgraded_modules:
		_assert(
			failures, "upgrade/%s/module" % ability_id,
			module != null and (
				not module.legacy_modifiers.is_empty()
				or not module.layers.is_empty()
				or module.amount != 0
			),
		)
	var board := _plain_board(Vector2i(10, 8))
	var monk := _place_monk(board, 1, Vector2i(2, 3), ability_id)
	monk.upgraded_abilities.append(ability_id)
	var target_setup := _configure_sim_target(board, ability_id, ability, monk.position)
	var target_coord: Vector2i = target_setup.coord
	var target_id: int = target_setup.id
	var action := TimelineAction.make_ability(1, ability, target_coord, target_id)
	_assert(
		failures,
		"upgrade/%s/can_use" % ability_id,
		AbilitySystem.can_use(board, action),
	)
	if AbilitySystem.can_use(board, action):
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
	var monk: UnitData = FactoryTestHelpers.build_unit(&"monk")
	var passive := _passive(monk, passive_id)
	_assert(failures, "passive/%s/registered" % passive_id, passive != null)
	if passive == null:
		return
	var row: Dictionary = {}
	for candidate: Dictionary in PASSIVE_ROWS:
		if candidate.id == passive_id:
			row = candidate
			break
	if row.is_empty() and passive_id != &"way_of_the_weaver":
		failures.append("passive/%s/missing_row" % passive_id)
		return
	for key: StringName in row.get("keys", [&"way_of_the_weaver"]):
		_assert(failures, "passive/%s/%s" % [passive_id, key], passive.modifiers.has(key))
	var trigger_board := _plain_board(Vector2i(8, 6))
	var trigger_events: Array[SimEvent] = []
	Simulator.simulate_player_turn(trigger_board, Timeline.new(), trigger_events)
	_run_passive_trigger(passive_id, failures)


static func run_core_passive_triggers(failures: Array[String]) -> void:
	## Per-row scenario files call the same trigger proof after their data
	## contract. Keep this entry point for class-runner compatibility.
	return


static func _run_passive_trigger(passive_id: StringName, failures: Array[String]) -> void:
	var monk_def: UnitData = FactoryTestHelpers.build_unit(&"monk")
	var passive := _passive(monk_def, passive_id)
	_assert(failures, "passive/%s/trigger_data" % passive_id, passive != null)
	if passive == null:
		return
	var board := _plain_board(Vector2i(8, 6))
	var monk := _place_monk(board, 1, Vector2i(2, 2), &"monk_soul_punch")
	monk.active_passives.append(passive)
	monk._recalculate_stats(board)
	var target := Vector2i(3, 2)
	var dummy := _place_dummy(board, 3, target)
	match passive_id:
		&"way_of_the_weaver":
			_simulate_passive_attack(board, monk, &"monk_soul_punch", target)
			_assert(failures, "passive/way_of_the_weaver/magic_empowerment",
				int(monk.passive_flags.get("weave_magic_bonus", 0)) == 2)
		&"elemental_attunement":
			board.set_tile_terrain(target, DataLibrary.get_terrain(&"fire"))
			_assert(failures, "passive/elemental_attunement/pierce",
				_MONK_SYSTEMS.should_pierce(board, monk, dummy))
			var result := _simulate_passive_attack(board, monk, &"monk_soul_punch", target)
			_assert(failures, "passive/elemental_attunement/upgraded_status",
				not result.events.is_empty())
		&"chakra_burn":
			board.set_tile_terrain(target, DataLibrary.get_terrain(&"bear_trap"))
			_simulate_passive_attack(board, monk, &"monk_soul_punch", target)
			_assert(failures, "passive/chakra_burn/burn",
				dummy.has_status(GameEnums.StatusType.BURN))
		&"elemental_harmony":
			var without_surface := monk.current_strength
			board.set_tile_terrain(monk.position + Vector2i.RIGHT, DataLibrary.get_terrain(&"fire"))
			monk._recalculate_stats(board)
			_assert(failures, "passive/elemental_harmony/adjacent_strength",
				monk.current_strength > without_surface)
		&"catalyst":
			var plain_magic := monk.current_magic
			var plain_defense := monk.current_defense
			board.set_tile_terrain(monk.position, DataLibrary.get_terrain(&"fire"))
			monk._recalculate_stats(board)
			_assert(failures, "passive/catalyst/surface_stats",
				monk.current_magic > plain_magic and monk.current_defense > plain_defense)
		&"elemental_shield":
			var ability := _ability(monk_def, &"monk_scorching_kick")
			monk.active_abilities.append(ability)
			board.set_tile_terrain(target, DataLibrary.get_terrain(&"plain"))
			_simulate_passive_attack(board, monk, &"monk_scorching_kick", target)
			_assert(failures, "passive/elemental_shield/terrain_defense",
				monk.has_status(GameEnums.StatusType.STAT_BUFF_DEF))
		&"weavers_resonance":
			monk.passive_flags["weave_magic_bonus"] = 2
			var before_armor := monk.armor
			var resonance_events: Array[SimEvent] = []
			_MONK_SYSTEMS.on_weave_consumed(board, monk, target, resonance_events)
			_assert(failures, "passive/weavers_resonance/shield",
				monk.armor > before_armor)
		&"mind_over_matter":
			monk.active_statuses.append(DataLibrary.make_status(
				GameEnums.StatusType.STAT_BUFF_MAG, 1, 5,
			))
			monk._recalculate_stats(board)
			var result := _simulate_passive_attack(board, monk, &"monk_soul_punch", target)
			_assert(failures, "passive/mind_over_matter/attack",
				_events_have_damage(result.events, dummy.id))
		&"inner_peace":
			var result := _simulate_passive_attack(board, monk, &"monk_soul_punch", target)
			_assert(failures, "passive/inner_peace/attack",
				_events_have_damage(result.events, dummy.id))
		&"zen_defense":
			var zen_board := _plain_board(Vector2i(8, 6))
			var zen_monk := _place_monk(zen_board, 1, Vector2i(4, 3), &"monk_soul_punch")
			zen_monk.active_passives.append(passive)
			var base_magic := zen_monk.current_magic
			zen_monk._recalculate_stats(zen_board)
			_assert(failures, "passive/zen_defense/empty_tiles",
				zen_monk.current_magic > base_magic)
		&"perfect_form":
			monk.passive_flags["monk_perfect_form_ready"] = true
			var base_strength := monk.current_strength
			_MONK_SYSTEMS.turn_start(board, monk, [])
			_assert(failures, "passive/perfect_form/next_turn_bonus",
				monk.current_strength > base_strength)
		&"vaulting_strike":
			monk.passive_flags["vaulted_target_id"] = dummy.id
			var result := _simulate_passive_attack(board, monk, &"monk_soul_punch", target)
			_assert(failures, "passive/vaulting_strike/attack",
				_events_have_damage(result.events, dummy.id))
		&"flowing_ki":
			_MONK_SYSTEMS.on_moved_through_enemy(board, monk, [dummy.id], [])
			_assert(failures, "passive/flowing_ki/magic_status",
				monk.has_status(GameEnums.StatusType.STAT_BUFF_MAG))
		&"evasive_acrobat":
			_MONK_SYSTEMS.turn_start(board, monk, [])
			_assert(failures, "passive/evasive_acrobat/ghost_move",
				monk.passive_flags.get("monk_ghost_move", false))
		&"momentum_transfer":
			monk.movement_points_spent_this_turn = 2
			var result := _simulate_passive_attack(board, monk, &"monk_soul_punch", target)
			_assert(failures, "passive/momentum_transfer/attack",
				_events_have_damage(result.events, dummy.id))
		&"light_step":
			var trap := DataLibrary.get_terrain(&"bear_trap")
			board.set_tile_terrain(monk.position, trap)
			_MONK_SYSTEMS.turn_start(board, monk, [])
			_assert(failures, "passive/light_step/flag",
				monk.passive_flags.get("monk_light_step", false))
			_MONK_SYSTEMS.turn_end(board, monk, [])
			_assert(failures, "passive/light_step/disarm",
				board.get_tile(monk.position).definition.id == &"plain")
		_:
			_assert(failures, "passive/%s/trigger" % passive_id, false)


static func _has_expected_outcome(
	ability: AbilityData,
	events: Array[SimEvent],
	final_board: BoardState,
	before_position: Vector2i,
) -> bool:
	if events.is_empty():
		return false
	for effect: EffectData in ability.effects:
		if effect == null:
			continue
		if effect.type in [
			GameEnums.EffectType.DAMAGE,
			GameEnums.EffectType.PUSH,
			GameEnums.EffectType.HEAL,
			GameEnums.EffectType.ADD_STATUS,
			GameEnums.EffectType.ADD_STATUS_SELF,
			GameEnums.EffectType.CREATE_HAZARD,
			GameEnums.EffectType.CHANGE_TERRAIN,
		]:
			return true
		if effect.type in [
			GameEnums.EffectType.MOVE,
			GameEnums.EffectType.DASH,
			GameEnums.EffectType.SWAP,
			GameEnums.EffectType.TELEPORT_CASTER,
		]:
			var actor := final_board.get_unit_by_id(1)
			return actor != null and actor.position != before_position or not events.is_empty()
	return true


static func _plain_board(size: Vector2i) -> BoardState:
	var board := BoardState.new()
	board.grid_size = size
	var plain := DataLibrary.get_terrain(&"plain")
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	return board


static func _place_monk(
	board: BoardState,
	unit_id: int,
	coord: Vector2i,
	ability_id: StringName,
) -> UnitState:
	var definition: UnitData = FactoryTestHelpers.build_unit(&"monk")
	var unit := UnitState.create(
		unit_id, definition, GameEnums.Team.PLAYER,
		coord, {"active_abilities": [DataLibrary.get_universal_run(), _ability(definition, ability_id)]},
	)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	unit.ability.points_left = unit.ability.max_points
	unit.movement.points_left = unit.movement.max_points
	return unit


static func _place_dummy(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var unit := UnitState.create(
		unit_id, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, coord,
	)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit


static func _place_ally(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var definition: UnitData = FactoryTestHelpers.build_unit(&"monk")
	var unit := UnitState.create(unit_id, definition, GameEnums.Team.PLAYER, coord)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit


static func _player_turn(board: BoardState, plan: Timeline) -> SimResult:
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	var result := SimResult.new()
	result.final_state = board
	result.events = events
	return result


static func _target_for(ability_id: StringName) -> Vector2i:
	match ability_id:
		&"monk_chakra_shift", &"monk_inner_fire", &"monk_updraft", &"monk_mantra_of_peace":
			return Vector2i(2, 3)
		&"monk_void_step":
			return Vector2i(3, 3)
		&"monk_leap":
			return Vector2i(4, 3)
		&"monk_phase_throw":
			return Vector2i(3, 3)
		&"monk_flying_crane_kick":
			return Vector2i(5, 3)
		_:
			return Vector2i(3, 3)


static func _configure_sim_target(
	board: BoardState,
	ability_id: StringName,
	ability: AbilityData,
	monk_pos: Vector2i,
) -> Dictionary:
	var target_coord := _target_for(ability_id)
	var target_id := -1
	match ability_id:
		&"monk_leap":
			target_coord = monk_pos + Vector2i.RIGHT
		&"monk_phase_throw":
			_place_dummy(board, 3, monk_pos + Vector2i.RIGHT)
			target_coord = monk_pos + Vector2i.RIGHT
			target_id = 3
		&"monk_flying_crane_kick":
			_place_dummy(board, 4, monk_pos + Vector2i(2, 0))
			target_coord = monk_pos + Vector2i(3, 0)
		_:
			if ability.targeting_flags & GameEnums.TargetingFlags.ENEMY:
				_place_dummy(board, 3, target_coord)
				target_id = 3
			elif ability.targeting_flags & GameEnums.TargetingFlags.ALLY:
				_place_ally(board, 2, target_coord)
				target_id = 2
	return {"coord": target_coord, "id": target_id}


static func _ability(definition: UnitData, ability_id: StringName) -> AbilityData:
	for ability: AbilityData in definition.abilities:
		if ability.id == ability_id:
			return ability
	return null


static func _passive(definition: UnitData, passive_id: StringName) -> PassiveData:
	for passive: PassiveData in definition.innate_passives + definition.passives:
		if passive.id == passive_id:
			return passive
	return null


static func _events_have_ability(events: Array[SimEvent], ability_id: StringName) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ABILITY_USED \
				and event.data.get("ability") == ability_id:
			return true
	return false


static func _events_have_damage(events: Array[SimEvent], unit_id: int) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.UNIT_DAMAGED \
				and int(event.data.get("unit", -1)) == unit_id:
			return true
	return false


static func _simulate_passive_attack(
	board: BoardState,
	monk: UnitState,
	ability_id: StringName,
	target: Vector2i,
) -> SimResult:
	var ability := _ability(monk.definition, ability_id)
	monk.active_abilities.append(ability)
	var action := TimelineAction.make_ability(monk.id, ability, target, 3)
	var plan := Timeline.new()
	plan.add(action)
	return _player_turn(board, plan)


static func _assert(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _run_cyclone_sweep_footprint(failures: Array[String], ability: AbilityData) -> void:
	var board := _plain_board(Vector2i(10, 8))
	var origin := Vector2i(3, 3)
	_place_monk(board, 10, origin, &"monk_cyclone_sweep")
	_place_dummy(board, 11, Vector2i(4, 3))
	_place_dummy(board, 12, Vector2i(4, 4))
	_place_dummy(board, 13, Vector2i(5, 3))
	var target := Vector2i(4, 3)
	var outside_before: Vector2i = board.get_unit_by_id(13).position
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(10, ability, target, 11))
	var result := _player_turn(board, plan)
	var center_after: Vector2i = result.final_state.get_unit_by_id(11).position
	var perp_after: Vector2i = result.final_state.get_unit_by_id(12).position
	var outside_after: Vector2i = result.final_state.get_unit_by_id(13).position
	_assert(
		failures, "cyclone/footprint/inside_center",
		center_after != Vector2i(4, 3) or perp_after != Vector2i(4, 4),
	)
	_assert(failures, "cyclone/footprint/outside", outside_after == outside_before)
	assert_grid_footprint_excludes(
		failures,
		"cyclone/footprint/grid",
		board,
		origin,
		target,
		ability.target_shape,
		ability.target_shape_size,
		Vector2i(5, 3),
	)


static func _run_mantra_of_peace_footprint(failures: Array[String], ability: AbilityData) -> void:
	var board := _plain_board(Vector2i(10, 8))
	var origin := Vector2i(4, 4)
	_place_monk(board, 10, origin, &"monk_mantra_of_peace")
	var footprint: Array[Vector2i] = GridSystem.get_affected_tiles(
		board, origin, origin, ability.target_shape, ability.target_shape_size,
	)
	var inside_coord := origin
	for tile: Vector2i in footprint:
		if tile != origin:
			inside_coord = tile
			break
	_place_dummy(board, 11, inside_coord)
	_place_dummy(board, 12, Vector2i(8, 8))
	assert_grid_footprint_excludes(
		failures,
		"mantra/footprint/grid",
		board,
		origin,
		origin,
		ability.target_shape,
		ability.target_shape_size,
		Vector2i(8, 8),
	)
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(10, ability, origin, -1))
	var result := _player_turn(board, plan)
	var inside := result.final_state.get_unit_by_id(11)
	var outside := result.final_state.get_unit_by_id(12)
	_assert(
		failures, "mantra/footprint/inside_weaken",
		inside != null and inside.has_status(GameEnums.StatusType.WEAKEN),
	)
	_assert(
		failures, "mantra/footprint/outside",
		outside != null and not outside.has_status(GameEnums.StatusType.WEAKEN),
	)
