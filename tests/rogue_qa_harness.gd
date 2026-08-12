class_name RogueQaHarness
extends RefCounted

## Layer A/B helper for Rogue rows. Each row scenario delegates here, while
## shaped rows additionally delegate to the shared footprint contract.

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
	var actor := _place_rogue(board, 1, Vector2i(2, 3), ability_id)
	var target := _target_for(ability_id)
	var target_id := -1
	if ability.targeting_flags & GameEnums.TargetingFlags.ENEMY:
		_place_dummy(board, 3, target)
		target_id = 3
	elif ability.targeting_flags & GameEnums.TargetingFlags.ALLY:
		_place_ally(board, 2, target)
		target_id = 2
	var action := TimelineAction.make_ability(1, ability, target, target_id)
	_assert(failures, "%s/can_use" % ability_id, AbilitySystem.can_use(board, action))
	if not AbilitySystem.can_use(board, action):
		return
	var events: Array[SimEvent] = []
	AbilitySystem.execute(board, action, events)
	_assert(
		failures,
		"%s/ability_used" % ability_id,
		_events_have_ability(events, ability_id),
	)
	if ability.target_shape != GameEnums.TargetShape.SINGLE:
		var footprint := GridSystem.get_affected_tiles(
			board, actor.position, target, ability.target_shape, ability.target_shape_size,
		)
		_assert(failures, "%s/footprint" % ability_id, footprint.has(target) and not footprint.is_empty())


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
	_assert(
		failures,
		"upgrade/%s/changes" % ability_id,
		ability.modules.size() == ability.upgraded_modules.size()
			and ability.upgrade_description.length() > 0,
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
		return
	failures.append("passive/%s/row_missing" % passive_id)


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


static func _assert(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
