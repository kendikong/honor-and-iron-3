extends Node


const ABILITY_IDS: Array[StringName] = [
	&"mage_blink",
	&"mage_fireball",
	&"mage_ice_shard",
	&"mage_chain_lightning",
	&"mage_arcane_push",
	&"mage_teleport",
	&"mage_meteor",
	&"mage_black_hole",
	&"mage_time_warp",
	&"mage_mana_shield",
	&"mage_disintegrate",
	&"mage_gravity_well",
	&"mage_elemental_surge",
	&"mage_earth_spike",
	&"mage_density_shift",
	&"mage_arcane_barrage",
]

const PASSIVE_ROWS: Array[Dictionary] = [
	{"id": &"elementalist", "keys": [&"elementalist"]},
	{"id": &"feedback", "keys": [&"feedback_magic", &"feedback_shield"]},
	{"id": &"elemental_master", "keys": [&"elemental_master_magic"]},
	{"id": &"lasting_terrain", "keys": [&"lasting_terrain_duration", &"lasting_terrain_damage"]},
	{"id": &"surface_syphoner", "keys": [&"surface_syphoner"]},
	{"id": &"mana_leak", "keys": [&"mana_leak"]},
	{"id": &"arcane_overdrive", "keys": [&"arcane_overdrive_magic", &"arcane_overdrive_hp_pct"]},
	{"id": &"mana_well", "keys": [&"mana_well"]},
	{"id": &"mana_siphon", "keys": [&"mana_siphon"]},
	{"id": &"overload", "keys": [&"overload_magic", &"overload_tick_damage"]},
	{"id": &"wild_magic", "keys": [&"wild_magic"]},
	{"id": &"arcane_tether", "keys": [&"arcane_tether"]},
	{"id": &"arcane_mastery", "keys": [&"arcane_mastery_radius"]},
	{"id": &"arcane_attunement", "keys": [&"arcane_attunement"]},
	{"id": &"gravity_anchor", "keys": [&"gravity_anchor"]},
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_check_factory_matrix(failures)
	_check_live_skill_resolution(failures)
	_check_core_passive_triggers(failures)
	for failure: String in failures:
		print("[FAIL] %s" % failure)
	if failures.is_empty():
		print("[PASS] Mage QA gate: factory matrix, all active skills, and passive triggers")
		get_tree().quit(0)
	else:
		print("[FAIL] Mage QA gate: %d failure(s)" % failures.size())
		get_tree().quit(1)


func _check_factory_matrix(failures: Array[String]) -> void:
	var mage: UnitData = FactoryTestHelpers.build_unit(&"mage")
	_assert(failures, "factory/mage_registered", mage != null)
	if mage == null:
		return
	_assert(failures, "factory/base_constitution", mage.base_constitution == 3)
	_assert(failures, "factory/base_movement", mage.move_points == 4)
	_assert(failures, "factory/base_magic", mage.base_magic == 5)
	_assert(failures, "factory/innate_count", mage.innate_passives.size() == 1)
	_assert(failures, "factory/active_count", mage.abilities.size() == 17)
	_assert(failures, "factory/promotion_passive_count", mage.passives.size() == 15)
	_assert(
		failures,
		"factory/promotion_stats",
		mage.promotion_stat_bonuses.get(&"geomancer", {}).get("magic", -1) == 4
		and mage.promotion_stat_bonuses.get(&"geomancer", {}).get("constitution", -1) == 4
		and mage.promotion_stat_bonuses.get(&"archmage", {}).get("magic", -1) == 8
		and mage.promotion_stat_bonuses.get(&"graviturge", {}).get("movement", -1) == 2,
	)
	for ability_id: StringName in ABILITY_IDS:
		var ability := _ability(mage, ability_id)
		_assert(failures, "factory/ability/%s" % ability_id, ability != null)
		if ability == null:
			continue
		_assert(
			failures,
			"factory/upgrade/%s" % ability_id,
			not ability.upgraded_effects.is_empty() and not ability.upgrade_description.is_empty(),
		)
		_check_upgrade_contract(failures, ability)
	for row: Dictionary in PASSIVE_ROWS:
		var passive := _passive(mage, row.id)
		_assert(failures, "factory/passive/%s" % row.id, passive != null)
		if passive == null:
			continue
		for key: StringName in row.keys:
			_assert(
				failures,
				"factory/passive/%s/%s" % [row.id, key],
				passive.modifiers.has(key),
			)


func _check_live_skill_resolution(failures: Array[String]) -> void:
	for ability_id: StringName in ABILITY_IDS:
		var board := _plain_board(Vector2i(10, 8))
		var mage := _place_mage(board, 1, Vector2i(2, 3), ability_id)
		var target_coord := _target_for(ability_id)
		var target_id := -1
		if ability_id == &"mage_time_warp":
			_place_mage_ally(board, 2, Vector2i(3, 3))
			target_id = 2
		elif ability_id in [&"mage_mana_shield", &"mage_elemental_surge"]:
			target_coord = mage.position
		elif ability_id != &"mage_blink" and ability_id != &"mage_teleport" \
				and ability_id != &"mage_meteor" and ability_id != &"mage_black_hole" \
				and ability_id != &"mage_gravity_well" and ability_id != &"mage_earth_spike":
			_place_dummy(board, 3, target_coord)
			target_id = 3
		elif ability_id in [&"mage_black_hole", &"mage_gravity_well"]:
			_place_dummy(board, 3, target_coord)
		var ability := _ability(mage.definition, ability_id)
		var action := TimelineAction.make_ability(1, ability, target_coord, target_id)
		_assert(
			failures,
			"live/%s/can_use" % ability_id,
			ability != null and AbilitySystem.can_use(board, action),
		)
		if ability == null or not AbilitySystem.can_use(board, action):
			continue
		var plan := Timeline.new()
		plan.add(action)
		var result := _player_turn(board, plan)
		_assert(
			failures,
			"live/%s/used" % ability_id,
			_events_have_ability(result.events, ability_id),
		)


func _check_core_passive_triggers(failures: Array[String]) -> void:
	var board := _plain_board(Vector2i(8, 6))
	var mage := _place_mage(board, 1, Vector2i(2, 2), &"mage_fireball")
	mage.active_passives.append(_passive(mage.definition, &"feedback"))
	mage.active_passives.append(_passive(mage.definition, &"elemental_master"))
	mage.active_passives.append(_passive(mage.definition, &"lasting_terrain"))
	mage._recalculate_stats(board)
	var magic_before := mage.current_magic
	var fireball := _ability(mage.definition, &"mage_fireball")
	_place_dummy(board, 3, Vector2i(4, 2))
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, fireball, Vector2i(4, 2), 3))
	var result := _player_turn(board, plan)
	var after := result.final_state.get_unit_by_id(1)
	_assert(failures, "passive/feedback_shield", after.armor > 0)
	_assert(failures, "passive/terrain_created", result.final_state.get_tile(Vector2i(4, 2)).definition.id == &"fire")
	_assert(
		failures,
		"passive/elemental_master_magic",
		after.current_magic > magic_before,
	)

	var tether_board := _plain_board(Vector2i(8, 6))
	var tether_mage := _place_mage(tether_board, 1, Vector2i(2, 2), &"mage_fireball")
	tether_mage.active_passives.append(_passive(tether_mage.definition, &"arcane_tether"))
	tether_mage._recalculate_stats(tether_board)
	var enemy := _place_enemy_mage(tether_board, 3, Vector2i(4, 2))
	var move := Timeline.new()
	move.add(TimelineAction.make_move(3, Vector2i(3, 2), -1, [], GameEnums.MoveTiming.PRE_ACTION))
	var move_result := _player_turn(tether_board, move)
	var moved_enemy := move_result.final_state.get_unit_by_id(enemy.id)
	_assert(failures, "passive/arcane_tether_root", moved_enemy.has_status(GameEnums.StatusType.ROOT))


func _check_upgrade_contract(failures: Array[String], ability: AbilityData) -> void:
	var effects := ability.upgraded_effects
	match ability.id:
		&"mage_blink":
			_assert(failures, "upgrade/mage_blink/surface", effects[0].modifiers.get("leave_elemental_surface", false))
		&"mage_fireball":
			_assert(failures, "upgrade/mage_fireball/steam", effects[0].modifiers.get("reaction_terrain", &"") == &"frozen")
			_assert(failures, "upgrade/mage_fireball/aoe", ability.upgraded_modules[0].target_shape_size == 3)
		&"mage_ice_shard":
			_assert(failures, "upgrade/mage_ice_shard/steam", effects[0].modifiers.get("reaction_terrain", &"") == &"fire")
			_assert(failures, "upgrade/mage_ice_shard/aoe", ability.upgraded_modules[0].target_shape_size == 3)
		&"mage_chain_lightning":
			_assert(failures, "upgrade/mage_chain_lightning/surface", effects[0].modifiers.get("strike_all_surface", false))
		&"mage_arcane_push":
			_assert(failures, "upgrade/mage_arcane_push/trail", effects[2].modifiers.get("arcane_trail", false))
		&"mage_teleport":
			_assert(failures, "upgrade/mage_teleport/shield", effects[1].type == GameEnums.EffectType.ARMOR_UP)
		&"mage_meteor":
			_assert(failures, "upgrade/mage_meteor/crater", effects[0].modifiers.get("create_crater", false))
		&"mage_black_hole":
			_assert(failures, "upgrade/mage_black_hole/surfaces", effects[0].modifiers.get("pull_surfaces", false))
		&"mage_time_warp":
			_assert(failures, "upgrade/mage_time_warp/cooldown", effects[1].modifiers.get("cooldown_reduction", 0) == 1)
		&"mage_mana_shield":
			_assert(failures, "upgrade/mage_mana_shield/casting", effects[0].modifiers.get("mana_shield_casting", false))
		&"mage_disintegrate":
			_assert(failures, "upgrade/mage_disintegrate/ap", effects[0].modifiers.get("kill_grant_ap", 0) == 1)
		&"mage_gravity_well":
			_assert(failures, "upgrade/mage_gravity_well/blind", effects.size() == 2 and effects[1].status_type == GameEnums.StatusType.BLIND)
		&"mage_elemental_surge":
			_assert(failures, "upgrade/mage_elemental_surge/ap", effects[0].modifiers.get("elemental_surge_ap", 0) == 1)
		&"mage_earth_spike":
			_assert(failures, "upgrade/mage_earth_spike/adjacent_damage", effects[0].modifiers.get("creation_adjacent_damage", 0) == 1)
		&"mage_density_shift":
			_assert(failures, "upgrade/mage_density_shift/weaken", effects[0].modifiers.get("apply_weaken_enemy", false))
		&"mage_arcane_barrage":
			_assert(failures, "upgrade/mage_arcane_barrage/pierce", effects[0].modifiers.get("ignore_target_magic_pct", 0.0) == 0.25)


func _plain_board(size: Vector2i) -> BoardState:
	var board := BoardState.new()
	board.grid_size = size
	var plain := DataLibrary.get_terrain(&"plain")
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	return board


func _place_mage(board: BoardState, unit_id: int, coord: Vector2i, ability_id: StringName) -> UnitState:
	var mage: UnitData = FactoryTestHelpers.build_unit(&"mage")
	var config := {
		"active_abilities": [DataLibrary.get_universal_run(), _ability(mage, ability_id)],
		"active_passives": [],
	}
	var unit := UnitState.create(unit_id, mage, GameEnums.Team.PLAYER, coord, config)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	unit.ability.points_left = unit.ability.max_points
	unit.movement.points_left = unit.movement.max_points
	return unit


func _place_mage_ally(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var mage: UnitData = FactoryTestHelpers.build_unit(&"mage")
	var unit := UnitState.create(unit_id, mage, GameEnums.Team.PLAYER, coord)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit


func _place_dummy(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var dummy := UnitState.create(
		unit_id,
		DataLibrary.get_training_dummy(),
		GameEnums.Team.ENEMY,
		coord,
	)
	board.add_unit(dummy)
	GridSystem.set_occupant(board, coord, unit_id)
	return dummy


func _place_enemy_mage(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var enemy := UnitState.create(
		unit_id,
		FactoryTestHelpers.build_unit(&"mage"),
		GameEnums.Team.ENEMY,
		coord,
	)
	board.add_unit(enemy)
	GridSystem.set_occupant(board, coord, unit_id)
	enemy.movement.points_left = enemy.movement.max_points
	return enemy


func _player_turn(board: BoardState, plan: Timeline) -> SimResult:
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	var result := SimResult.new()
	result.final_state = board
	result.events = events
	return result


func _target_for(ability_id: StringName) -> Vector2i:
	match ability_id:
		&"mage_blink":
			return Vector2i(4, 3)
		&"mage_fireball", &"mage_ice_shard", &"mage_chain_lightning", &"mage_arcane_push":
			return Vector2i(4, 3)
		&"mage_teleport", &"mage_meteor", &"mage_black_hole":
			return Vector2i(4, 3)
		&"mage_time_warp":
			return Vector2i(3, 3)
		&"mage_disintegrate", &"mage_arcane_barrage":
			return Vector2i(4, 3)
		&"mage_gravity_well", &"mage_earth_spike", &"mage_density_shift":
			return Vector2i(4, 3)
		_:
			return Vector2i(2, 3)


func _ability(definition: UnitData, ability_id: StringName) -> AbilityData:
	for ability: AbilityData in definition.abilities:
		if ability.id == ability_id:
			return ability
	return null


func _passive(definition: UnitData, passive_id: StringName) -> PassiveData:
	for passive: PassiveData in definition.passives + definition.innate_passives:
		if passive.id == passive_id:
			return passive
	return null


func _events_have_ability(events: Array[SimEvent], ability_id: StringName) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ABILITY_USED and event.data.get("ability") == ability_id:
			return true
	return false


func _assert(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
