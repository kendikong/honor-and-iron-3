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
	{"id": &"elementalist", "keys": [&"elementalist", &"elementalist_lightning_all_surface"]},
	{"id": &"feedback", "keys": [&"feedback_magic", &"feedback_shield"]},
	{"id": &"elemental_master", "keys": [&"elemental_master_magic"]},
	{"id": &"lasting_terrain", "keys": [&"lasting_terrain_duration", &"lasting_terrain_damage"]},
	{"id": &"surface_syphoner", "keys": [&"surface_syphoner"]},
	{"id": &"mana_leak", "keys": [&"mana_leak"]},
	{"id": &"arcane_overdrive", "keys": [&"arcane_overdrive_magic", &"arcane_overdrive_hp_pct"]},
	{"id": &"mana_well", "keys": [&"mana_well"]},
	{"id": &"mana_siphon", "keys": [&"mana_siphon"]},
	{"id": &"overload", "keys": [&"overload_magic", &"overload_no_shield"]},
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


static func run_density_shift_bible(failures: Array[String]) -> void:
	var ability := _ability(FactoryTestHelpers.build_unit(&"mage"), &"mage_density_shift")
	if ability == null:
		_assert(failures, "density_shift/ability", false)
		return
	var ally_board := _plain_board(Vector2i(8, 8))
	var mage_ally := _place_mage(ally_board, 1, Vector2i(2, 3), &"mage_density_shift")
	_place_mage_ally(ally_board, 2, Vector2i(4, 3))
	var ally := ally_board.get_unit_by_id(2)
	var ally_action := TimelineAction.make_ability(1, ability, ally.position, 2)
	AbilitySystem.execute(ally_board, ally_action, [])
	_assert(
		failures,
		"density_shift/ally_sturdy",
		ally != null and ally.has_status(GameEnums.StatusType.STURDY),
	)
	_assert(
		failures,
		"density_shift/ally_no_push_mitigation",
		int(ally.passive_flags.get("push_mitigation_tiles", 0)) == 0,
	)
	var enemy_board := _plain_board(Vector2i(8, 8))
	_place_mage(enemy_board, 10, Vector2i(2, 3), &"mage_density_shift")
	_place_dummy(enemy_board, 11, Vector2i(4, 3))
	var enemy := enemy_board.get_unit_by_id(11)
	var enemy_action := TimelineAction.make_ability(10, ability, enemy.position, 11)
	AbilitySystem.execute(enemy_board, enemy_action, [])
	_assert(
		failures,
		"density_shift/enemy_push_mitigation",
		enemy != null and int(enemy.passive_flags.get("push_mitigation_tiles", 0)) == 2,
	)
	_assert(
		failures,
		"density_shift/enemy_no_sturdy",
		enemy != null and not enemy.has_status(GameEnums.StatusType.STURDY),
	)


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
	var board := _plain_board(Vector2i(8, 6))
	var mage_unit := _place_mage(board, 1, Vector2i(2, 2), &"mage_elemental_surge")
	var surge := _ability(mage, &"mage_elemental_surge")
	for _i: int in range(3):
		mage_unit.reset_for_turn()
		var surge_plan := Timeline.new()
		surge_plan.add(TimelineAction.make_ability(1, surge, mage_unit.position, mage_unit.id))
		_player_turn(board, surge_plan)
	_assert(
		failures, "arcane_overchannel/stacks",
		int(mage_unit.passive_flags.get("arcane_overchannel_stacks", 0)) == 3,
	)
	_assert(
		failures, "arcane_overchannel/base_no_refund",
		mage_unit.ability.points_left == 0,
	)
	_assert(
		failures, "arcane_overchannel/base_no_shield",
		mage_unit.armor == 0,
	)
	var upgraded_board := _plain_board(Vector2i(8, 6))
	var upgraded_mage := _place_mage(upgraded_board, 1, Vector2i(2, 2), &"mage_elemental_surge")
	upgraded_mage.upgraded_passives.append(&"arcane_overchannel")
	for _j: int in range(3):
		upgraded_mage.reset_for_turn()
		var upgraded_plan := Timeline.new()
		upgraded_plan.add(TimelineAction.make_ability(1, surge, upgraded_mage.position, upgraded_mage.id))
		_player_turn(upgraded_board, upgraded_plan)
	_assert(
		failures, "arcane_overchannel/upgrade_refund",
		upgraded_mage.ability.points_left >= 1,
	)
	_assert(
		failures, "arcane_overchannel/upgrade_shield",
		upgraded_mage.armor > 0,
	)


static func run_bible_parity_cluster(failures: Array[String]) -> void:
	run_arcane_overchannel(failures)
	_bible_elementalist_lightning(failures)
	_bible_fireball_steam(failures)
	_bible_arcane_trail_mag(failures)
	_bible_meteor_delay(failures)
	_bible_black_hole_center(failures)
	_bible_mana_shield_formula(failures)
	_bible_gravity_well_enemies(failures)


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
		run_single_passive(passive_id, failures)
		return
	failures.append("factory/passive/%s/missing_row" % passive_id)


static func run_single_passive(passive_id: StringName, failures: Array[String]) -> void:
	_run_passive_blocks(failures, passive_id)


static func _passive_should_run(only_id: StringName, passive_id: StringName) -> bool:
	return only_id == &"" or only_id == passive_id


static func _run_passive_blocks(failures: Array[String], only_id: StringName) -> void:
	var mage_def: UnitData = FactoryTestHelpers.build_unit(&"mage")
	var fireball := _ability(mage_def, &"mage_fireball")
	if fireball == null:
		return

	if _passive_should_run(only_id, &"feedback"):
		var board := _plain_board(Vector2i(8, 6))
		var mage := _place_mage(board, 1, Vector2i(2, 2), &"mage_fireball")
		mage.active_passives.append(_passive(mage_def, &"feedback"))
		mage._recalculate_stats(board)
		_place_dummy(board, 3, Vector2i(4, 2))
		var plan_fb := Timeline.new()
		plan_fb.add(TimelineAction.make_ability(1, fireball, Vector2i(4, 2), 3))
		var result := _player_turn(board, plan_fb)
		var after := result.final_state.get_unit_by_id(1)
		_assert(failures, "passive/feedback_shield", after != null and after.armor > 0)

	if _passive_should_run(only_id, &"elemental_master"):
		var board := _plain_board(Vector2i(8, 6))
		var mage := _place_mage(board, 1, Vector2i(2, 2), &"mage_fireball")
		mage.active_passives.append(_passive(mage_def, &"elemental_master"))
		mage._recalculate_stats(board)
		var magic_before := mage.current_magic
		_place_dummy(board, 3, Vector2i(4, 2))
		_player_turn(board, _fireball_plan(fireball, Vector2i(4, 2), 3))
		var after := board.get_unit_by_id(1)
		_assert(
			failures, "passive/elemental_master_magic",
			after != null and after.current_magic > magic_before,
		)

	if _passive_should_run(only_id, &"lasting_terrain"):
		var board := _plain_board(Vector2i(8, 6))
		var mage := _place_mage(board, 1, Vector2i(2, 2), &"mage_fireball")
		mage.active_passives.append(_passive(mage_def, &"lasting_terrain"))
		mage._recalculate_stats(board)
		_place_dummy(board, 3, Vector2i(4, 2))
		_player_turn(board, _fireball_plan(fireball, Vector2i(4, 2), 3))
		_assert(
			failures, "passive/terrain_created",
			board.get_tile(Vector2i(4, 2)).definition.id == &"fire",
		)

	if _passive_should_run(only_id, &"arcane_tether"):
		var tether_board := _plain_board(Vector2i(8, 6))
		var tether_mage := _place_mage(tether_board, 1, Vector2i(2, 2), &"mage_fireball")
		tether_mage.active_passives.append(_passive(mage_def, &"arcane_tether"))
		tether_mage._recalculate_stats(tether_board)
		var enemy := _place_enemy_mage(tether_board, 3, Vector2i(4, 2))
		var move := Timeline.new()
		move.add(TimelineAction.make_move(3, Vector2i(3, 2), -1, [], GameEnums.MoveTiming.PRE_ACTION))
		var move_result := _player_turn(tether_board, move)
		var moved_enemy := move_result.final_state.get_unit_by_id(enemy.id)
		_assert(
			failures, "passive/arcane_tether_root",
			moved_enemy != null and moved_enemy.has_status(GameEnums.StatusType.ROOT),
		)

	if _passive_should_run(only_id, &"surface_syphoner"):
		var board := _plain_board(Vector2i(8, 6))
		var fire_tile := DataLibrary.get_terrain(&"fire")
		var coord := Vector2i(2, 2)
		board.tiles[coord] = TileState.create(coord, fire_tile)
		board.terrain_payloads[coord] = {"terrain_owner_id": 1}
		var mage := _place_mage(board, 1, coord, &"mage_fireball")
		mage.active_passives.append(_passive(mage_def, &"surface_syphoner"))
		mage.health.current_hp = maxi(1, mage.health.max_hp - 2)
		mage._recalculate_stats(board)
		var hp_before := mage.health.current_hp
		var syphon_result := Simulator.simulate(board, Timeline.new())
		var mage_after: UnitState = syphon_result.final_state.get_unit_by_id(1)
		_assert(
			failures, "passive/surface_syphoner/heal",
			mage_after != null and mage_after.health.current_hp > hp_before,
		)

	if _passive_should_run(only_id, &"mana_well"):
		var board := _plain_board(Vector2i(8, 6))
		var coord := Vector2i(2, 2)
		board.tiles[coord] = TileState.create(coord, DataLibrary.get_terrain(&"fire"))
		var mage := _place_mage(board, 1, coord, &"mage_fireball")
		mage.active_passives.append(_passive(mage_def, &"mana_well"))
		mage._recalculate_stats(board)
		var well_result := Simulator.simulate(board, Timeline.new())
		var mage_after: UnitState = well_result.final_state.get_unit_by_id(1)
		_assert(
			failures, "passive/mana_well/flag",
			mage_after != null and mage_after.passive_flags.get("mana_well_next_spell", false),
		)

	if _passive_should_run(only_id, &"overload"):
		var board := _plain_board(Vector2i(8, 6))
		var mage := _place_mage(board, 1, Vector2i(2, 2), &"mage_fireball")
		var mag_before := mage.current_magic
		mage.active_passives.append(_passive(mage_def, &"overload"))
		mage._recalculate_stats(board)
		_assert(
			failures, "passive/overload/magic",
			mage.current_magic == mag_before + 2,
		)
		var shield_events: Array[SimEvent] = []
		var armor_before := mage.armor
		CombatSystem.add_armor(board, mage, 4, shield_events)
		_assert(
			failures, "passive/overload/no_shield",
			mage.armor == armor_before,
		)
		mage.upgraded_passives.append(&"overload")
		mage._recalculate_stats(board)
		_assert(
			failures, "passive/overload/upgraded_magic",
			mage.current_magic == mag_before + 3,
		)

	if _passive_should_run(only_id, &"arcane_overdrive"):
		var board := _plain_board(Vector2i(8, 6))
		var mage := _place_mage(board, 1, Vector2i(2, 2), &"mage_fireball")
		mage.active_passives.append(_passive(mage_def, &"arcane_overdrive"))
		mage.health.current_hp = maxi(1, int(float(mage.health.max_hp) * 0.5))
		mage._recalculate_stats(board)
		_assert(
			failures, "passive/arcane_overdrive/magic",
			mage.current_magic > mage_def.base_magic,
		)

	if _passive_should_run(only_id, &"arcane_mastery"):
		var board := _plain_board(Vector2i(8, 6))
		var mastery_mage := _place_mage(board, 1, Vector2i(2, 2), &"mage_fireball")
		mastery_mage.active_passives.append(_passive(mage_def, &"arcane_mastery"))
		mastery_mage._recalculate_stats(board)
		_place_dummy(board, 3, Vector2i(4, 2))
		var result := _player_turn(board, _fireball_plan(fireball, Vector2i(4, 2), 3))
		var damaged := false
		for event: SimEvent in result.events:
			if event.type == GameEnums.SimEventType.UNIT_DAMAGED:
				damaged = true
				break
		_assert(failures, "passive/arcane_mastery/spell", damaged)

	if _passive_should_run(only_id, &"wild_magic"):
		var board := _plain_board(Vector2i(8, 6))
		var mage := _place_mage(board, 1, Vector2i(2, 2), &"mage_fireball")
		mage.active_passives.append(_passive(mage_def, &"wild_magic"))
		mage._recalculate_stats(board)
		_place_dummy(board, 3, Vector2i(4, 2))
		var result := _player_turn(board, _fireball_plan(fireball, Vector2i(4, 2), 3))
		_assert(
			failures, "passive/wild_magic/pending",
			mage.passive_flags.get("__mage_wild_magic_pending", false)
			or mage.passive_flags.get("__mage_wild_magic_repeat", false)
			or _events_have_ability(result.events, &"mage_fireball"),
		)

	if _passive_should_run(only_id, &"mana_leak"):
		var board := _plain_board(Vector2i(8, 6))
		var mage := _place_mage(board, 1, Vector2i(2, 2), &"mage_fireball")
		mage.active_passives.append(_passive(mage_def, &"mana_leak"))
		mage._recalculate_stats(board)
		var enemy := _place_dummy(board, 3, Vector2i(3, 2))
		var events: Array[SimEvent] = []
		CombatSystem.deal_damage(
			board, mage, 3, events, &"true", true, false, enemy, "hit", 3,
		)
		var pulse_hit := false
		for event: SimEvent in events:
			if event.type == GameEnums.SimEventType.UNIT_DAMAGED \
					and int(event.data.get("unit", -1)) == enemy.id:
				pulse_hit = true
				break
		_assert(failures, "passive/mana_leak/pulse", pulse_hit)

	if _passive_should_run(only_id, &"mana_siphon"):
		var board := _plain_board(Vector2i(8, 6))
		var mage := _place_mage(board, 1, Vector2i(2, 2), &"mage_fireball")
		mage.active_passives.append(_passive(mage_def, &"mana_siphon"))
		mage._recalculate_stats(board)
		var dummy := _place_dummy(board, 3, Vector2i(4, 2))
		dummy.health.current_hp = 1
		var hp_before := mage.health.current_hp
		_player_turn(board, _fireball_plan(fireball, Vector2i(4, 2), 3))
		_assert(
			failures, "passive/mana_siphon/heal",
			mage.health.current_hp > hp_before or mage.ability.points_left > 0,
		)

	if _passive_should_run(only_id, &"arcane_attunement"):
		var board := _plain_board(Vector2i(8, 6))
		var mage := _place_mage(board, 1, Vector2i(2, 2), &"mage_fireball")
		mage.active_passives.append(_passive(mage_def, &"arcane_attunement"))
		mage._recalculate_stats(board)
		_place_dummy(board, 3, Vector2i(4, 2))
		var attune_result := _player_turn(board, _fireball_plan(fireball, Vector2i(4, 2), 3))
		_assert(
			failures, "passive/arcane_attunement/buff",
			mage.has_status(GameEnums.StatusType.STAT_BUFF_DEF)
			or mage.has_status(GameEnums.StatusType.STAT_BUFF_STR)
			or _events_have_ability(attune_result.events, &"mage_fireball"),
		)

	if _passive_should_run(only_id, &"elementalist"):
		var board := _plain_board(Vector2i(8, 6))
		var mage := _place_mage(board, 1, Vector2i(2, 2), &"mage_fireball")
		mage.active_passives.append(_passive(mage_def, &"elementalist"))
		mage._recalculate_stats(board)
		_place_dummy(board, 3, Vector2i(4, 2))
		_player_turn(board, _fireball_plan(fireball, Vector2i(4, 2), 3))
		_assert(
			failures, "passive/elementalist/terrain",
			board.get_tile(Vector2i(4, 2)).definition.id == &"fire",
		)
		_bible_elementalist_lightning(failures)

	if _passive_should_run(only_id, &"gravity_anchor"):
		var board := _plain_board(Vector2i(8, 6))
		var mage := _place_mage(board, 1, Vector2i(2, 2), &"mage_arcane_push")
		mage.active_passives.append(_passive(mage_def, &"gravity_anchor"))
		mage._recalculate_stats(board)
		var enemy := _place_dummy(board, 3, Vector2i(4, 2))
		var push := _ability(mage_def, &"mage_arcane_push")
		var hp_before := enemy.health.current_hp
		var plan_push := Timeline.new()
		plan_push.add(TimelineAction.make_ability(1, push, enemy.position, enemy.id))
		_player_turn(board, plan_push)
		_assert(
			failures, "passive/gravity_anchor/damage",
			enemy.health.current_hp < hp_before or enemy.position != Vector2i(4, 2),
		)


static func run_core_passive_triggers(failures: Array[String]) -> void:
	for row: Dictionary in PASSIVE_ROWS:
		run_single_passive(row.id, failures)

static func _check_upgrade_contract(failures: Array[String], ability: AbilityData) -> void:
	var effects := ability.upgraded_effects
	match ability.id:
		&"mage_blink":
			_assert(failures, "upgrade/mage_blink/surface", effects[0].modifiers.get("leave_elemental_surface", false))
		&"mage_fireball":
			_assert(
				failures,
				"upgrade/mage_fireball/steam_splash",
				_has_reaction_steam_splash(ability.upgraded_effects),
			)
			_assert(
				failures,
				"upgrade/mage_fireball/no_base_steam",
				not _has_reaction_steam_splash(ability.effects),
			)
		&"mage_ice_shard":
			_assert(failures, "upgrade/mage_ice_shard/steam", effects[0].modifiers.get("reaction_terrain", &"") == &"fire")
			_assert(failures, "upgrade/mage_ice_shard/aoe", ability.upgraded_modules[0].target_shape_size == 1)
			_assert(
				failures,
				"upgrade/mage_ice_shard/steam_splash",
				_has_reaction_steam_splash(ability.upgraded_effects),
			)
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

static func _bible_elementalist_lightning(failures: Array[String]) -> void:
	var mage_def: UnitData = FactoryTestHelpers.build_unit(&"mage")
	var board := _plain_board(Vector2i(10, 8))
	var mage := _place_mage(board, 1, Vector2i(2, 3), &"mage_chain_lightning")
	mage.active_passives.append(_passive(mage_def, &"elementalist"))
	var primary := _place_dummy(board, 3, Vector2i(4, 3))
	var water_coord := Vector2i(7, 3)
	board.tiles[water_coord] = TileState.create(water_coord, DataLibrary.get_terrain(&"water"))
	var soaked := _place_dummy(board, 4, water_coord)
	var hp_before := soaked.health.current_hp
	var lightning := _ability(mage_def, &"mage_chain_lightning")
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, lightning, primary.position, primary.id))
	_player_turn(board, plan)
	_assert(
		failures,
		"passive/elementalist/lightning_all",
		soaked.health.current_hp < hp_before,
	)


static func _bible_fireball_steam(failures: Array[String]) -> void:
	var mage_def: UnitData = FactoryTestHelpers.build_unit(&"mage")
	var board := _plain_board(Vector2i(10, 8))
	var mage := _place_mage(board, 1, Vector2i(2, 3), &"mage_fireball")
	mage.upgraded_abilities.append(&"mage_fireball")
	var frozen := Vector2i(4, 3)
	board.tiles[frozen] = TileState.create(frozen, DataLibrary.get_terrain(&"frozen"))
	_place_dummy(board, 3, frozen)
	var splash := _place_dummy(board, 4, Vector2i(5, 4))
	var splash_hp := splash.health.current_hp
	var fireball := _ability(mage_def, &"mage_fireball")
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, fireball, frozen, 3))
	_player_turn(board, plan)
	_assert(
		failures,
		"bible/fireball/steam",
		board.get_tile(frozen).definition.id == &"steam",
	)
	_assert(
		failures,
		"bible/fireball/steam_splash",
		splash.health.current_hp < splash_hp,
	)


static func _bible_arcane_trail_mag(failures: Array[String]) -> void:
	var mage_def: UnitData = FactoryTestHelpers.build_unit(&"mage")
	var board := _plain_board(Vector2i(10, 8))
	var mage := _place_mage(board, 1, Vector2i(2, 3), &"mage_arcane_push")
	mage.upgraded_abilities.append(&"mage_arcane_push")
	var dummy := _place_dummy(board, 3, Vector2i(4, 3))
	var push := _ability(mage_def, &"mage_arcane_push")
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, push, dummy.position, dummy.id))
	_player_turn(board, plan)
	var trail_coord := Vector2i(4, 3)
	_assert(
		failures,
		"bible/arcane_push/trail_tile",
		board.get_tile(trail_coord).definition.id == &"arcane_trail",
	)
	var walker := _place_dummy(board, 5, Vector2i(4, 4))
	var hp_before := walker.health.current_hp
	walker.position = trail_coord
	TerrainSystem.apply_landing(board, walker, [])
	_assert(
		failures,
		"bible/arcane_push/trail_mag_atk",
		walker.health.current_hp < hp_before,
	)


static func _bible_meteor_delay(failures: Array[String]) -> void:
	var mage_def: UnitData = FactoryTestHelpers.build_unit(&"mage")
	var board := _plain_board(Vector2i(10, 8))
	_place_mage(board, 1, Vector2i(2, 3), &"mage_meteor")
	var dummy := _place_dummy(board, 3, Vector2i(4, 3))
	var hp_before := dummy.health.current_hp
	var meteor := _ability(mage_def, &"mage_meteor")
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, meteor, dummy.position, dummy.id))
	_player_turn(board, plan)
	_assert(
		failures,
		"bible/meteor/queued",
		not board.delayed_effects.is_empty() and dummy.health.current_hp == hp_before,
	)
	_player_turn(board, Timeline.new())
	_assert(
		failures,
		"bible/meteor/impact",
		dummy.health.current_hp < hp_before,
	)
	var crater_board := _plain_board(Vector2i(10, 8))
	var crater_mage := _place_mage(crater_board, 1, Vector2i(2, 3), &"mage_meteor")
	crater_mage.upgraded_abilities.append(&"mage_meteor")
	_place_dummy(crater_board, 3, Vector2i(4, 3))
	var crater_plan := Timeline.new()
	crater_plan.add(TimelineAction.make_ability(1, meteor, Vector2i(4, 3), 3))
	_player_turn(crater_board, crater_plan)
	_player_turn(crater_board, Timeline.new())
	_assert(
		failures,
		"bible/meteor/crater",
		crater_board.get_tile(Vector2i(4, 3)).definition.id == &"crater",
	)


static func _bible_black_hole_center(failures: Array[String]) -> void:
	var mage_def: UnitData = FactoryTestHelpers.build_unit(&"mage")
	var board := _plain_board(Vector2i(10, 8))
	_place_mage(board, 1, Vector2i(2, 3), &"mage_black_hole")
	var dummy := _place_dummy(board, 3, Vector2i(5, 5))
	var hole := _ability(mage_def, &"mage_black_hole")
	var center := Vector2i(5, 3)
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, hole, center, -1))
	_player_turn(board, plan)
	_assert(
		failures,
		"bible/black_hole/pull_to_center",
		dummy.position.x == 5 and dummy.position.y < 5,
	)


static func _bible_mana_shield_formula(failures: Array[String]) -> void:
	var mage_def: UnitData = FactoryTestHelpers.build_unit(&"mage")
	var board := _plain_board(Vector2i(8, 6))
	var mage := _place_mage(board, 1, Vector2i(2, 3), &"mage_mana_shield")
	var mag_at_cast := mage.current_magic
	var max_hp := mage.health.max_hp
	var shield := _ability(mage_def, &"mage_mana_shield")
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, shield, mage.position, mage.id))
	_player_turn(board, plan)
	var expected := floori(float(mag_at_cast) * 0.1 * float(max_hp))
	_assert(
		failures,
		"bible/mana_shield/shield_x",
		mage.armor == expected and expected != mag_at_cast,
	)


static func _bible_gravity_well_enemies(failures: Array[String]) -> void:
	var mage_def: UnitData = FactoryTestHelpers.build_unit(&"mage")
	var board := _plain_board(Vector2i(10, 8))
	_place_mage(board, 1, Vector2i(2, 3), &"mage_gravity_well")
	var ally := _place_mage_ally(board, 2, Vector2i(3, 3))
	var enemy := _place_dummy(board, 3, Vector2i(5, 3))
	var well := _ability(mage_def, &"mage_gravity_well")
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, well, Vector2i(4, 3), -1))
	_player_turn(board, plan)
	_assert(
		failures,
		"bible/gravity_well/enemy_root",
		enemy.has_status(GameEnums.StatusType.ROOT),
	)
	_assert(
		failures,
		"bible/gravity_well/ally_untouched",
		not ally.has_status(GameEnums.StatusType.ROOT),
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


static func _fireball_plan(fireball: AbilityData, target: Vector2i, target_id: int) -> Timeline:
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, fireball, target, target_id))
	return plan

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

static func _has_reaction_steam_splash(effects: Array) -> bool:
	for effect in effects:
		if effect is EffectData and effect.modifiers.get("reaction_steam_splash", false):
			return true
	return false


static func _assert(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)

