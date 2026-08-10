class_name MageQaHarness
extends RefCounted


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


static func run_factory_matrix(failures: Array[String]) -> void:
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
		for key: StringName in row.get("keys", []):
			_assert(
				failures,
				"factory/passive/%s/%s" % [row.id, key],
				passive.modifiers.has(key),
			)

static func run_live_skill_resolution(failures: Array[String]) -> void:
	for ability_id: StringName in ABILITY_IDS:
		run_single_ability(ability_id, failures)


static func run_single_ability(ability_id: StringName, failures: Array[String]) -> void:
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
		return
	var hp_before: int = -1
	var actor_pos_before: Vector2i = mage.position
	if target_id > 0:
		var target_unit: UnitState = board.get_unit_by_id(target_id)
		if target_unit != null:
			hp_before = target_unit.health.current_hp
	var plan := Timeline.new()
	plan.add(action)
	var result := _player_turn(board, plan)
	_assert(
		failures,
		"live/%s/used" % ability_id,
		_events_have_ability(result.events, ability_id),
	)
	_assert_live_outcome(
		failures, "live/%s" % ability_id, ability, result.events, hp_before, actor_pos_before, result.final_state, target_id,
	)
	var mage_def: UnitData = FactoryTestHelpers.build_unit(&"mage")
	var ability_data := _ability(mage_def, ability_id)
	if ability_data != null:
		_check_upgrade_contract(failures, ability_data)


static func run_upgrade_sim_for(ability_id: StringName, failures: Array[String]) -> void:
	var mage_def: UnitData = FactoryTestHelpers.build_unit(&"mage")
	var ability := _ability(mage_def, ability_id)
	if ability == null or ability.upgraded_effects.is_empty():
		return
	_check_upgrade_contract(failures, ability)
	var board := _plain_board(Vector2i(10, 8))
	var mage := _place_mage(board, 1, Vector2i(2, 3), ability_id)
	mage.upgraded_abilities.append(ability_id)
	var target_coord := _target_for(ability_id)
	var target_id := -1
	if ability_id not in [&"mage_blink", &"mage_teleport", &"mage_mana_shield", &"mage_elemental_surge", &"mage_time_warp"]:
		_place_dummy(board, 3, target_coord)
		target_id = 3
	var resolved := _ability(mage.definition, ability_id)
	var action := TimelineAction.make_ability(1, resolved, target_coord, target_id)
	if not AbilitySystem.can_use(board, action):
		return
	if ability_id in [&"mage_meteor", &"mage_black_hole", &"mage_gravity_well"]:
		return
	var hp_before: int = -1
	if target_id > 0:
		var target_unit: UnitState = board.get_unit_by_id(target_id)
		if target_unit != null:
			hp_before = target_unit.health.current_hp
	var plan := Timeline.new()
	plan.add(action)
	var result := _player_turn(board, plan)
	_assert_live_outcome(
		failures, "upgrade/%s" % ability_id, resolved, result.events, hp_before, mage.position, result.final_state, target_id,
	)


static func _assert_live_outcome(
	failures: Array[String],
	prefix: String,
	ability: AbilityData,
	events: Array[SimEvent],
	hp_before: int,
	actor_pos_before: Vector2i,
	final_board: BoardState,
	target_id: int = -1,
) -> void:
	if ability == null:
		return
	var has_damage := false
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.UNIT_DAMAGED:
			has_damage = true
			break
	var hp_after: int = hp_before
	if target_id > 0:
		var tu: UnitState = final_board.get_unit_by_id(target_id)
		if tu != null:
			hp_after = tu.health.current_hp
	for effect: EffectData in ability.effects:
		match effect.type:
			GameEnums.EffectType.DAMAGE:
				if hp_before <= 0 and not has_damage:
					continue
				_assert(
					failures, "%s/outcome/damage" % prefix,
					has_damage or (hp_before > 0 and hp_after < hp_before),
				)
			GameEnums.EffectType.HEAL, GameEnums.EffectType.ARMOR_UP:
				_assert(failures, "%s/outcome/buff" % prefix, not events.is_empty())
			GameEnums.EffectType.MOVE, GameEnums.EffectType.DASH, GameEnums.EffectType.TELEPORT_CASTER:
				if ability.id in [&"mage_blink", &"mage_teleport"]:
					continue
				var actor: UnitState = final_board.get_unit_by_id(1)
				_assert(
					failures, "%s/outcome/move" % prefix,
					actor != null and actor.position != actor_pos_before,
				)
			GameEnums.EffectType.CHANGE_TERRAIN, GameEnums.EffectType.CREATE_HAZARD:
				for event: SimEvent in events:
					if event.type == GameEnums.SimEventType.TERRAIN_CHANGED:
						return
				_assert(failures, "%s/outcome/terrain" % prefix, false)
			_:
				pass


static func run_arcane_overchannel(failures: Array[String]) -> void:
	var mage: UnitData = FactoryTestHelpers.build_unit(&"mage")
	_assert(failures, "factory/innate_count", mage != null and mage.innate_passives.size() == 1)
	if mage == null or mage.innate_passives.is_empty():
		return
	var innate: PassiveData = mage.innate_passives[0]
	_assert(failures, "arcane_overchannel/id", innate.id == &"arcane_overchannel")
	_assert(failures, "arcane_overchannel/modifier", innate.modifiers.has("arcane_overchannel"))


static func run_passive_factory(passive_id: StringName, failures: Array[String]) -> void:
	var mage: UnitData = FactoryTestHelpers.build_unit(&"mage")
	for row: Dictionary in PASSIVE_ROWS:
		if row.id != passive_id:
			continue
		var passive := _passive(mage, passive_id)
		_assert(failures, "factory/passive/%s" % passive_id, passive != null)
		if passive == null:
			return
		for key: StringName in row.get("keys", []):
			_assert(
				failures,
				"factory/passive/%s/%s" % [passive_id, key],
				passive.modifiers.has(key),
			)
		return
	failures.append("factory/passive/%s/missing_row" % passive_id)


static func run_core_passive_triggers(failures: Array[String]) -> void:
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

static func _check_upgrade_contract(failures: Array[String], ability: AbilityData) -> void:
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

static func _plain_board(size: Vector2i) -> BoardState:
	var board := BoardState.new()
	board.grid_size = size
	var plain := DataLibrary.get_terrain(&"plain")
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	return board

static func _place_mage(board: BoardState, unit_id: int, coord: Vector2i, ability_id: StringName) -> UnitState:
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

static func _place_mage_ally(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var mage: UnitData = FactoryTestHelpers.build_unit(&"mage")
	var unit := UnitState.create(unit_id, mage, GameEnums.Team.PLAYER, coord)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit

static func _place_dummy(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var dummy := UnitState.create(
		unit_id,
		DataLibrary.get_training_dummy(),
		GameEnums.Team.ENEMY,
		coord,
	)
	board.add_unit(dummy)
	GridSystem.set_occupant(board, coord, unit_id)
	return dummy

static func _place_enemy_mage(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
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

static func _player_turn(board: BoardState, plan: Timeline) -> SimResult:
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	var result := SimResult.new()
	result.final_state = board
	result.events = events
	return result

static func _target_for(ability_id: StringName) -> Vector2i:
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

static func _ability(definition: UnitData, ability_id: StringName) -> AbilityData:
	for ability: AbilityData in definition.abilities:
		if ability.id == ability_id:
			return ability
	return null

static func _passive(definition: UnitData, passive_id: StringName) -> PassiveData:
	for passive: PassiveData in definition.passives + definition.innate_passives:
		if passive.id == passive_id:
			return passive
	return null

static func _events_have_ability(events: Array[SimEvent], ability_id: StringName) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ABILITY_USED and event.data.get("ability") == ability_id:
			return true
	return false

static func _assert(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)

