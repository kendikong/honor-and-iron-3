class_name ShamanQaHarness
extends RefCounted


const ABILITY_IDS: Array[StringName] = [
	&"shaman_usher",
	&"shaman_curse_of_weakness",
	&"shaman_healing_totem",
	&"shaman_flame_totem",
	&"shaman_bloodlust",
	&"shaman_hex",
	&"shaman_voodoo_link",
	&"shaman_terrify",
	&"shaman_miasma",
	&"shaman_bone_spear",
	&"shaman_ancestral_spirit",
	&"shaman_totem_guard",
	&"shaman_sympathetic_bond",
	&"shaman_earthbind_totem",
	&"shaman_soul_siphon",
	&"shaman_pain_spike",
]

const PASSIVE_ROWS: Array[Dictionary] = [
	{"id": &"hexing_presence", "keys": [&"hexing_presence", &"hexing_presence_range"]},
	{"id": &"echoing_spirits", "keys": [&"echoing_spirits", &"totem_pulse_count"]},
	{"id": &"spiritual_offering", "keys": [&"spiritual_offering", &"offering_shield"]},
	{"id": &"spiritual_guardian", "keys": [&"spiritual_guardian", &"guardian_aura_def"]},
	{"id": &"miasma_resonance", "keys": [&"miasma_resonance", &"miasma_dot_bonus"]},
	{"id": &"voodoo_conduit", "keys": [&"voodoo_conduit", &"conduit_range_bonus"]},
	{"id": &"voodoo_doll", "keys": [&"voodoo_doll", &"voodoo_doll_wpn_multiplier"]},
	{"id": &"spirit_link", "keys": [&"spirit_link", &"spirit_link_wpn_multiplier"]},
	{"id": &"pain_sharing", "keys": [&"pain_sharing", &"linked_damage_bonus"]},
	{"id": &"sympathetic_magic", "keys": [&"sympathetic_magic", &"linked_ally_heal"]},
	{"id": &"chain_reaction", "keys": [&"chain_reaction", &"linked_push"]},
	{"id": &"soul_collector", "keys": [&"soul_collector", &"soul_orb_cap"]},
	{"id": &"hexing_touch", "keys": [&"hexing_touch", &"hexing_touch_str"]},
	{"id": &"ritual_sacrifice", "keys": [&"ritual_sacrifice", &"ritual_hp_cost"]},
	{"id": &"soul_burn", "keys": [&"soul_burn", &"soul_burn_damage"]},
	{"id": &"soul_weaver", "keys": [&"soul_weaver", &"soul_weaver_transfer_count"]},
]


static func run_factory_matrix(failures: Array[String]) -> void:
	var shaman := FactoryTestHelpers.build_unit(&"shaman")
	_assert(failures, "factory/shaman_registered", shaman != null)
	if shaman == null:
		return
	_assert(failures, "factory/base_constitution", shaman.base_constitution == 3)
	_assert(failures, "factory/base_movement", shaman.move_points == 4)
	_assert(failures, "factory/base_magic", shaman.base_magic == 4)
	_assert(failures, "factory/innate_count", shaman.innate_passives.size() == 1)
	_assert(failures, "factory/active_count", shaman.abilities.size() == 17)
	_assert(failures, "factory/promotion_passive_count", shaman.passives.size() == 15)
	for ability_id: StringName in ABILITY_IDS:
		var ability := _ability(shaman, ability_id)
		_assert(failures, "factory/ability/%s" % ability_id, ability != null)
		if ability == null:
			continue
		_assert(failures, "factory/modules/%s" % ability_id, not ability.modules.is_empty())
		_assert(failures, "factory/upgraded_modules/%s" % ability_id, not ability.upgraded_modules.is_empty())
		_assert(failures, "factory/upgrade/%s" % ability_id, not ability.upgrade_description.is_empty())
	for row: Dictionary in PASSIVE_ROWS:
		var passive := _passive(shaman, row.id)
		_assert(failures, "factory/passive/%s" % row.id, passive != null)
		if passive == null:
			continue
		for key: StringName in row.keys:
			_assert(failures, "factory/passive/%s/%s" % [row.id, key], passive.modifiers.has(key))


static func run_single_ability(ability_id: StringName, failures: Array[String]) -> void:
	var board := _plain_board(Vector2i(10, 8))
	var shaman := _place_shaman(board, 1, Vector2i(2, 3), ability_id)
	var ability := _ability(shaman.definition, ability_id)
	_assert(failures, "resolve/%s/factory" % ability_id, ability != null)
	if ability == null:
		return
	var target := Vector2i(4, 3)
	var target_id := -1
	if ability_id == &"shaman_usher":
		_place_ally(board, 2, Vector2i(3, 3))
		target = Vector2i(4, 3)
		target_id = 2
	elif ability_id == &"shaman_bloodlust":
		_place_ally(board, 2, Vector2i(3, 3))
		target = Vector2i(3, 3)
		target_id = 2
	elif ability_id == &"shaman_sympathetic_bond":
		_place_dummy(board, 3, target)
		target_id = 3
	elif ability_id == &"shaman_voodoo_link":
		_place_dummy(board, 3, target)
		_place_dummy(board, 4, Vector2i(3, 2))
		target_id = 3
	elif ability_id == &"shaman_pain_spike":
		_place_dummy(board, 3, target)
		target_id = 3
	elif ability_id == &"shaman_hex":
		var hex_target := _place_dummy(board, 3, target)
		hex_target.health.current_hp = maxi(1, hex_target.health.max_hp - 1)
		target_id = 3
	elif ability_id == &"shaman_terrify":
		var terrify_target := _place_dummy(board, 3, target)
		terrify_target.active_statuses.append(DataLibrary.make_status(
			GameEnums.StatusType.WEAKEN, 1,
		))
		target_id = 3
	elif ability_id in [
		&"shaman_healing_totem", &"shaman_flame_totem", &"shaman_bone_spear",
		&"shaman_totem_guard", &"shaman_earthbind_totem",
	]:
		pass
	elif ability_id == &"shaman_ancestral_spirit":
		var corpse := _place_ally(board, 2, Vector2i(3, 3))
		corpse.health.current_hp = 0
		GridSystem.set_occupant(board, corpse.position, -1)
		target = corpse.position
		target_id = 2
	else:
		_place_dummy(board, 3, target)
		target_id = 3
	var action := TimelineAction.make_ability(1, ability, target, target_id)
	_assert(failures, "resolve/%s/can_use" % ability_id, AbilitySystem.can_use(board, action))
	if not AbilitySystem.can_use(board, action):
		return
	var plan := Timeline.new()
	plan.add(action)
	var result := _player_turn(board, plan)
	_assert(failures, "resolve/%s/ability_used" % ability_id, _events_have_ability(result.events, ability_id))
	_assert(
		failures,
		"resolve/%s/no_action_failure" % ability_id,
		not _has_action_failure(result.events, 1),
	)
	if ability_id == &"shaman_bone_spear":
		var line := GridSystem.get_affected_tiles(
			board, Vector2i(2, 3), target, GameEnums.TargetShape.LINE, 4,
		)
		_assert(failures, "resolve/%s/line_footprint" % ability_id, line.size() == 4)
	if ability_id in [
		&"shaman_healing_totem", &"shaman_flame_totem", &"shaman_totem_guard",
		&"shaman_earthbind_totem", &"shaman_ancestral_spirit",
	]:
		_assert(
			failures,
			"resolve/%s/spawn" % ability_id,
			_has_event(result.events, GameEnums.SimEventType.UNIT_SPAWNED),
		)


static func run_passive_factory(passive_id: StringName, failures: Array[String]) -> void:
	var shaman := FactoryTestHelpers.build_unit(&"shaman")
	var passive := _passive(shaman, passive_id)
	_assert(failures, "passive/%s/factory" % passive_id, passive != null)
	if passive == null:
		return
	for row: Dictionary in PASSIVE_ROWS:
		if row.id != passive_id:
			continue
		for key: StringName in row.keys:
			_assert(failures, "passive/%s/%s" % [passive_id, key], passive.modifiers.has(key))
		_assert(
			failures,
			"passive/%s/upgrade_description" % passive_id,
			not passive.upgraded_description.is_empty(),
		)
		return
	failures.append("passive/%s/registry_row" % passive_id)


static func _plain_board(size: Vector2i) -> BoardState:
	var board := BoardState.new()
	board.grid_size = size
	var plain := DataLibrary.get_terrain(&"plain")
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	return board


static func _place_shaman(board: BoardState, unit_id: int, coord: Vector2i, ability_id: StringName) -> UnitState:
	var definition := FactoryTestHelpers.build_unit(&"shaman")
	var ability := _ability(definition, ability_id)
	var config := {
		"active_abilities": [DataLibrary.get_universal_run(), ability],
		"active_passives": [],
	}
	var unit := UnitState.create(unit_id, definition, GameEnums.Team.PLAYER, coord, config)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	unit.ability.points_left = unit.ability.max_points
	unit.movement.points_left = unit.movement.max_points
	return unit


static func _place_ally(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var unit := UnitState.create(
		unit_id, FactoryTestHelpers.build_unit(&"shaman"),
		GameEnums.Team.PLAYER, coord,
	)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit


static func _place_dummy(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var unit := UnitState.create(unit_id, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, coord)
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


static func _ability(definition: UnitData, ability_id: StringName) -> AbilityData:
	for ability: AbilityData in definition.abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


static func _passive(definition: UnitData, passive_id: StringName) -> PassiveData:
	for passive: PassiveData in definition.passives + definition.innate_passives:
		if passive != null and passive.id == passive_id:
			return passive
	return null


static func _events_have_ability(events: Array[SimEvent], ability_id: StringName) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ABILITY_USED and event.data.get("ability") == ability_id:
			return true
	return false


static func _has_event(events: Array[SimEvent], event_type: GameEnums.SimEventType) -> bool:
	for event: SimEvent in events:
		if event != null and event.type == event_type:
			return true
	return false


static func _has_action_failure(events: Array[SimEvent], actor_id: int) -> bool:
	for event: SimEvent in events:
		if event != null and event.type == GameEnums.SimEventType.ACTION_FAILED \
				and int(event.data.get("actor", -1)) == actor_id:
			return true
	return false


static func _assert(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
