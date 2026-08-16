class_name BeastRiderQaHarness
extends RefCounted

## Layer A/B owner for every Beast Rider factory row.
## Layer C is exercised by each scenario through the shared planning contract.

const _BEAST := preload("res://core/systems/beast_rider_systems.gd")
const _PLANNING := preload("res://tests/class_scenario_planning_contract.gd")
const _MovementSystem := preload("res://core/systems/movement_system.gd")
const _TerrainSystem := preload("res://core/systems/terrain_system.gd")

const ABILITY_IDS: Array[StringName] = [
	&"beast_reposition", &"beast_pounce", &"beast_feral_drag", &"beast_maul",
	&"beast_bestial_roar", &"beast_raking_claws", &"beast_rest_recover",
	&"beast_intimidate", &"beast_fetch", &"beast_savage_bite", &"beast_run_down",
	&"beast_thrash", &"beast_defensive_posture", &"beast_airlift",
	&"beast_tail_swipe", &"beast_gore",
]

const PASSIVE_ROWS: Array[Dictionary] = [
	{"id": &"gallop", "keys": [&"gallop", &"split_movement", &"upgraded_split_attack_strength", &"upgraded_split_post_defense"]},
	{"id": &"isolation_tactics", "keys": [&"isolation_attack_strength", &"upgraded_moved_tile_attack_strength"]},
	{"id": &"terminal_velocity", "keys": [&"collision_weapon_true_damage", &"collision_vulnerable", &"upgraded_drop_stagger"]},
	{"id": &"snatch_and_grab", "keys": [&"grapple_range", &"upgraded_grapple_range"]},
	{"id": &"safe_landing", "keys": [&"safe_landing", &"landing_shockwave_push", &"upgraded_landing_shockwave_push"]},
	{"id": &"aerial_superiority", "keys": [&"grounded_melee_defense", &"upgraded_grounded_root_immunity"]},
	{"id": &"mount_resilience", "keys": [&"ranged_damage_reduction_base", &"upgraded_ranged_damage_reduction_base"]},
	{"id": &"beasts_instinct", "keys": [&"miss_zero_damage_strength", &"miss_zero_damage_ap", &"upgraded_miss_zero_damage_shield"]},
	{"id": &"territorial", "keys": [&"adjacent_entry_attack", &"upgraded_adjacent_entry_attack"]},
	{"id": &"intimidating_presence", "keys": [&"intimidating_presence_range", &"intimidating_presence_def", &"intimidating_presence_move", &"upgraded_intimidating_presence_range"]},
	{"id": &"dive_bomber", "keys": [&"dive_bomber_min_tiles", &"dive_bomber_attack_strength", &"upgraded_dive_bomber_min_tiles"]},
	{"id": &"pack_hunter", "keys": [&"pack_hunter_bite", &"pack_hunter_def_ignore_pct", &"upgraded_pack_hunter_bite"]},
	{"id": &"blood_scent", "keys": [&"blood_scent_move", &"blood_scent_pierce", &"upgraded_blood_scent_move"]},
	{"id": &"vantage_striker", "keys": [&"ignore_difficult_terrain", &"vantage_attack_strength", &"upgraded_vantage_attack_strength"]},
	{"id": &"predatory_drive", "keys": [&"predatory_bleed_weapon", &"upgraded_predatory_poison"]},
	{"id": &"furious_charge", "keys": [&"furious_charge_min_tiles", &"furious_charge_push", &"upgraded_furious_charge_push"]},
]

const ABILITY_CONTRACTS: Dictionary = {
	&"beast_reposition": {"types": [GameEnums.EffectType.TELEPORT_CASTER], "amount": 2, "max_range": 1, "keys": [&"reposition_opposite_side", &"reposition_movement_cost"]},
	&"beast_pounce": {"types": [GameEnums.EffectType.MOVE_TOWARD], "amount": 3, "max_range": 3, "keys": [&"pounce_land_adjacent", &"landing_push"]},
	&"beast_feral_drag": {"types": [GameEnums.EffectType.PULL], "amount": 0, "max_range": 1, "keys": [&"feral_drag", &"drag_remaining_movement"], "filter": GameEnums.ModuleTargetFilter.STAT, "filter_stat": GameEnums.ModuleTargetFilterStat.CON_LEQ_CASTER_STR},
	&"beast_maul": {"types": [GameEnums.EffectType.DAMAGE], "amount": 2, "max_range": 1, "keys": [&"drop_adjacent", &"drop_trap_damage_multiplier"], "filter": GameEnums.ModuleTargetFilter.OCCUPANT, "filter_occupant": GameEnums.ModuleTargetFilterOccupant.DRAGGED_ENEMY},
	&"beast_bestial_roar": {"types": [GameEnums.EffectType.PUSH], "amount": 2, "max_range": 3, "shape": GameEnums.TargetShape.CONE, "shape_size": 3, "keys": [&"status_requires_debuff", &"cone_all_targets"]},
	&"beast_raking_claws": {"types": [GameEnums.EffectType.DAMAGE], "amount": 2, "max_range": 1, "shape": GameEnums.TargetShape.ARC, "keys": [&"bleed_weapon", &"pull_before_attack"]},
	&"beast_rest_recover": {"types": [GameEnums.EffectType.HEAL], "amount": 1, "keys": [&"cost_all_movement"]},
	&"beast_intimidate": {"types": [GameEnums.EffectType.ADD_STATUS], "amount": 1, "shape": GameEnums.TargetShape.AOE_CROSS, "shape_size": 2, "keys": [&"purge_buffs"], "filter": GameEnums.ModuleTargetFilter.HP, "filter_hp": GameEnums.ModuleTargetFilterHp.BELOW_CASTER_HP},
	&"beast_fetch": {"types": [GameEnums.EffectType.PULL], "amount": 1, "max_range": 4, "keys": [&"pull_light_ally"], "filter": GameEnums.ModuleTargetFilter.OCCUPANT, "filter_occupant": GameEnums.ModuleTargetFilterOccupant.ITEM_OR_CORPSE},
	&"beast_savage_bite": {"types": [GameEnums.EffectType.DAMAGE], "amount": 4, "max_range": 1, "keys": [&"on_kill_shield"], "filter": GameEnums.ModuleTargetFilter.STATUS, "filter_status_mode": GameEnums.ModuleTargetFilterStatus.SPECIFIC},
	&"beast_run_down": {"types": [GameEnums.EffectType.DASH], "amount": 3, "max_range": 3, "keys": [&"run_down_pass_adjacent_push", &"run_down_push_bleed_weapon", &"trample_atk"]},
	&"beast_thrash": {"types": [GameEnums.EffectType.DAMAGE], "amount": 1, "max_range": 1, "hit_count": 3, "keys": [&"bleed_weapon"]},
	&"beast_defensive_posture": {"types": [GameEnums.EffectType.ADD_STATUS_SELF], "amount": 1, "keys": [&"intercept_push_attacker"]},
	&"beast_airlift": {"types": [GameEnums.EffectType.TELEPORT_CASTER], "amount": 1, "max_range": 1, "keys": [&"airlift_pickup_step", &"airlift_drop_step", &"airlift_keep_caster", &"airlift_ally_attack_strength"]},
	&"beast_tail_swipe": {"types": [GameEnums.EffectType.DAMAGE], "amount": 1, "shape": GameEnums.TargetShape.AOE_SQUARE, "shape_size": 1, "keys": [&"wall_collision_stagger"]},
	&"beast_gore": {"types": [GameEnums.EffectType.DAMAGE], "amount": 2, "max_range": 1, "keys": [&"bleed_bonus_damage"]},
}


static func run_factory_matrix(failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"beast_rider")
	_assert(failures, "factory/registered", definition != null)
	if definition == null:
		return
	_assert(failures, "factory/base_constitution", definition.base_constitution == 5)
	_assert(failures, "factory/base_movement", definition.move_points == 5)
	_assert(failures, "factory/base_strength", definition.base_strength == 3)
	_assert(failures, "factory/base_defense", definition.base_defense == 2)
	_assert(failures, "factory/base_magic", definition.base_magic == 2)
	_assert(failures, "factory/innate_count", definition.innate_passives.size() == 1)
	_assert(failures, "factory/ability_count", definition.abilities.size() == ABILITY_IDS.size() + 1)
	_assert(failures, "factory/passive_count", definition.passives.size() == 15)
	for ability_id: StringName in ABILITY_IDS:
		var ability := _ability(definition, ability_id)
		_assert(failures, "factory/ability/%s" % ability_id, ability != null)
		if ability == null:
			continue
		_assert(failures, "factory/modules/%s" % ability_id, not ability.modules.is_empty())
		_assert(
			failures,
			"factory/upgrade/%s" % ability_id,
			not ability.upgraded_modules.is_empty()
				and not ability.upgrade_description.is_empty(),
		)
		_run_ability_contract(ability, failures)
	for row: Dictionary in PASSIVE_ROWS:
		var passive := _passive(definition, row.id)
		_assert(failures, "factory/passive/%s" % row.id, passive != null)
		if passive == null:
			continue
		for key: StringName in row.keys:
			_assert(failures, "factory/passive/%s/%s" % [row.id, key], passive.modifiers.has(key))


static func _run_ability_contract(ability: AbilityData, failures: Array[String]) -> void:
	var contract: Dictionary = ABILITY_CONTRACTS.get(ability.id, {})
	var modules: Array[AbilityModule] = ability.modules
	var expected_types: Array = contract.get("types", [])
	_assert(failures, "factory/contract/%s/module_count" % ability.id, modules.size() == expected_types.size())
	for index: int in range(mini(modules.size(), expected_types.size())):
		var module := modules[index]
		_assert(failures, "factory/contract/%s/type_%d" % [ability.id, index], module.primary_type == expected_types[index])
	if modules.is_empty():
		return
	var primary := modules[0]
	for field: StringName in [&"amount", &"max_range", &"shape_size", &"hit_count"]:
		if contract.has(field):
			_assert(
				failures,
				"factory/contract/%s/%s" % [ability.id, field],
				_read_module_int(primary, field) == int(contract[field]),
			)
	if contract.has("shape"):
		_assert(failures, "factory/contract/%s/shape" % ability.id, primary.target_shape == contract.shape)
	for key: StringName in contract.get("keys", []):
		_assert(
			failures,
			"factory/contract/%s/%s" % [ability.id, key],
			_module_has_key(ability.modules, key) or _module_has_key(ability.upgraded_modules, key),
		)
	if contract.has("filter"):
		_assert(
			failures,
			"factory/contract/%s/filter" % ability.id,
			primary.target_filter == int(contract["filter"]),
		)
	if contract.has("filter_hp"):
		_assert(
			failures,
			"factory/contract/%s/filter_hp" % ability.id,
			primary.target_filter_hp == int(contract["filter_hp"]),
		)
	if contract.has("filter_stat"):
		_assert(
			failures,
			"factory/contract/%s/filter_stat" % ability.id,
			primary.target_filter_stat == int(contract["filter_stat"]),
		)
	if contract.has("filter_occupant"):
		_assert(
			failures,
			"factory/contract/%s/filter_occupant" % ability.id,
			primary.target_filter_occupant == int(contract["filter_occupant"]),
		)
	if contract.has("filter_status_mode"):
		_assert(
			failures,
			"factory/contract/%s/filter_status_mode" % ability.id,
			primary.target_filter_status_mode == int(contract["filter_status_mode"]),
		)


static func _module_has_key(modules: Array[AbilityModule], key: StringName) -> bool:
	for module: AbilityModule in modules:
		if module == null:
			continue
		if module.legacy_modifiers.has(key):
			return true
		for layer: AbilityLayer in module.layers:
			if layer != null and layer.effect != null and layer.effect.modifiers.has(key):
				return true
	return false


static func run_ability_row(ability_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"beast_rider")
	var ability := _ability(definition, ability_id)
	_assert(failures, "%s/data" % ability_id, ability != null)
	if ability == null:
		return
	var board := _plain_board(Vector2i(10, 8))
	var actor_pos := Vector2i(2, 3)
	var actor := _place_actor(board, 1, actor_pos, ability)
	var target_setup := _configure_sim_target(board, ability_id, ability, actor_pos)
	var target_coord: Vector2i = target_setup.coord
	var target_id: int = target_setup.id
	var action := TimelineAction.make_ability(actor.id, ability, target_coord, target_id)
	_apply_sim_action_overrides(action, ability_id, ability, actor, board, target_setup)
	actor.passive_flags["training_unlimited_actions"] = true
	actor.turn_action_used = false
	actor.ability.points_left = actor.ability.max_points
	actor.movement.points_left = actor.movement.max_points
	if ability_id == &"beast_feral_drag" and target_setup.get("unit") != null:
		var drag_target: UnitState = target_setup.get("unit")
		drag_target.health.max_hp = 5
		drag_target.health.current_hp = 5
	if ability_id == &"beast_maul" and target_setup.get("unit") != null:
		var maul_target: UnitState = target_setup.get("unit")
		actor.passive_flags["beast_drag_target_id"] = maul_target.id
		action.target_unit_id = maul_target.id
		action.target_coord = maul_target.position
	if ability_id == &"beast_fetch":
		board.items.append(target_coord)
		action.target_coord = target_coord
		action.target_unit_id = -1
	var board_before := board.clone()
	var plan := Timeline.new()
	plan.add(action)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	if ability_id not in [&"beast_feral_drag"]:
		_assert(
			failures,
			"%s/ability_used" % ability_id,
			_events_have_ability(events, ability_id),
		)
	_assert_ability_sim_outcome(
		failures,
		ability_id,
		ability,
		events,
		board_before,
		board,
		target_setup,
	)
	if AoeFootprintQaHarness.ability_requires_footprint_qa(ability):
		run_shaped_footprint(ability_id, failures)


static func run_passive_row(passive_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"beast_rider")
	var passive := _passive(definition, passive_id)
	_assert(failures, "passive/%s/data" % passive_id, passive != null)
	if passive == null:
		return
	var board := _plain_board(Vector2i(10, 8))
	var actor := _place_actor(board, 1, Vector2i(2, 3), _ability(definition, &"beast_thrash"))
	actor.active_passives.append(passive)
	actor.upgraded_passives.append(passive_id)
	actor._recalculate_stats(board)
	var events: Array[SimEvent] = []
	match passive_id:
		&"gallop":
			_assert(failures, "passive/gallop/post_move", _BEAST.can_post_move(actor))
			actor.passive_flags["beast_split_attack_ready"] = true
			var gallop_target := _place_enemy(board, 2, Vector2i(4, 3))
			var gallop_bonus := _BEAST.attack_strength_bonus(board, actor, gallop_target)
			_assert(failures, "passive/gallop/split_attack_bonus", gallop_bonus >= 1)
			var promo_board := _plain_board(Vector2i(10, 8))
			var promo_actor := UnitState.create(
				9,
				definition,
				GameEnums.Team.PLAYER,
				Vector2i(2, 3),
				{
					"promotion_id": &"griffin_rider",
					"active_abilities": [_ability(definition, &"beast_thrash")],
					"active_passives": [],
				},
			)
			promo_board.add_unit(promo_actor)
			_assert(
				failures,
				"passive/gallop/promotion_airborne",
				promo_actor.has_status(GameEnums.StatusType.AIRBORNE),
			)
		&"isolation_tactics":
			var isolated := _place_enemy(board, 2, Vector2i(5, 5))
			var isolated_bonus := _BEAST.attack_strength_bonus(board, actor, isolated)
			_assert(failures, "passive/isolation_tactics/isolated_bonus", isolated_bonus >= 2)
			actor.passive_flags["beast_tiles_moved"] = 2
			var moved_bonus := _BEAST.damage_bonus(board, actor, isolated, null)
			_assert(failures, "passive/isolation_tactics/moved_tile_bonus", moved_bonus >= 2)
		&"terminal_velocity":
			_assert(
				failures,
				"passive/terminal_velocity/collision_damage",
				_BEAST.has_passive_modifier(actor, &"collision_weapon_true_damage"),
			)
			_assert(
				failures,
				"passive/terminal_velocity/vulnerable",
				_BEAST.has_passive_modifier(actor, &"collision_vulnerable"),
			)
		&"snatch_and_grab":
			var drag_ability := _ability(definition, &"beast_feral_drag")
			var drag_target := _place_enemy(board, 2, Vector2i(4, 3))
			drag_target.health.max_hp = 5
			drag_target.health.current_hp = 5
			var in_range := TimelineAction.make_ability(
				actor.id, drag_ability, drag_target.position, drag_target.id,
			)
			_assert(
				failures,
				"passive/snatch_and_grab/grapple_range",
				_BEAST.can_use_extra(board, actor, drag_ability, in_range),
			)
			var out_of_range := TimelineAction.make_ability(
				actor.id, drag_ability, Vector2i(6, 3), drag_target.id,
			)
			_assert(
				failures,
				"passive/snatch_and_grab/out_of_range",
				not _BEAST.can_use_extra(board, actor, drag_ability, out_of_range),
			)
		&"safe_landing":
			_BEAST.turn_start(board, actor, events)
			_assert(failures, "passive/safe_landing/airborne", actor.has_status(GameEnums.StatusType.AIRBORNE))
			var hazard_coord := Vector2i(4, 3)
			_set_hazard_tile(board, hazard_coord)
			var shock_target := _place_enemy(board, 3, Vector2i(5, 3))
			var hp_before := actor.health.current_hp
			var shock_pos_before := shock_target.position
			GridSystem.set_occupant(board, actor.position, -1)
			actor.position = hazard_coord
			GridSystem.set_occupant(board, hazard_coord, actor.id)
			_BEAST.on_landing(board, actor, events)
			_TerrainSystem.apply_landing(board, actor, events)
			_assert(
				failures,
				"passive/safe_landing/hazard_zero",
				actor.health.current_hp == hp_before,
			)
			_assert(
				failures,
				"passive/safe_landing/shockwave_push",
				shock_target.position != shock_pos_before,
			)
			_assert(
				failures,
				"passive/safe_landing/upgraded_push",
				int(_BEAST.passive_value(
					actor, &"landing_shockwave_push", &"upgraded_landing_shockwave_push", 0,
				)) >= 2,
			)
			var pounce_board := _plain_board(Vector2i(10, 8))
			var pounce := _ability(definition, &"beast_pounce")
			var pounce_actor := _place_actor(pounce_board, 1, Vector2i(2, 3), pounce)
			pounce_actor.active_passives.append(passive)
			pounce_actor.upgraded_passives.append(passive_id)
			pounce_actor._recalculate_stats(pounce_board)
			_BEAST.turn_start(pounce_board, pounce_actor, events)
			_place_enemy(pounce_board, 2, Vector2i(4, 3))
			var wave_victim := _place_enemy(pounce_board, 3, Vector2i(3, 4))
			var wave_pos_before := wave_victim.position
			var pounce_setup := _configure_sim_target(
				pounce_board, &"beast_pounce", pounce, Vector2i(2, 3),
			)
			var pounce_action := TimelineAction.make_ability(
				pounce_actor.id, pounce, pounce_setup.coord, pounce_setup.id,
			)
			_apply_sim_action_overrides(
				pounce_action, &"beast_pounce", pounce, pounce_actor, pounce_board, pounce_setup,
			)
			pounce_actor.passive_flags["training_unlimited_actions"] = true
			pounce_actor.turn_action_used = false
			pounce_actor.ability.points_left = pounce_actor.ability.max_points
			var pounce_events: Array[SimEvent] = []
			Simulator.simulate_player_turn(pounce_board, _timeline(pounce_action), pounce_events)
			_assert(
				failures,
				"passive/safe_landing/pounce_integration",
				_events_have_ability(pounce_events, &"beast_pounce"),
			)
			_assert(
				failures,
				"passive/safe_landing/pounce_shockwave",
				wave_victim.position != wave_pos_before
					or _event_unit_moved(pounce_events, wave_victim.id),
			)
		&"aerial_superiority":
			var grounded_def := int(_BEAST.passive_value(actor, &"grounded_melee_defense", &"", 0))
			_assert(failures, "passive/aerial_superiority/defense", grounded_def >= 2)
			_assert(
				failures,
				"passive/aerial_superiority/root_immunity",
				bool(_BEAST.passive_value(actor, &"upgraded_grounded_root_immunity", &"", false)),
			)
		&"mount_resilience":
			var ranged_attacker := _place_enemy(board, 2, Vector2i(5, 3))
			var reduction := _BEAST.incoming_damage_reduction(
				board, actor, &"physical", ranged_attacker,
			)
			_assert(failures, "passive/mount_resilience/reduction", reduction >= 2)
		&"beasts_instinct":
			_assert(
				failures,
				"passive/beasts_instinct/strength",
				int(_BEAST.passive_value(actor, &"miss_zero_damage_strength", &"", 0)) >= 1,
			)
			_assert(
				failures,
				"passive/beasts_instinct/ap",
				int(_BEAST.passive_value(actor, &"miss_zero_damage_ap", &"", 0)) >= 1,
			)
			_assert(
				failures,
				"passive/beasts_instinct/shield",
				int(_BEAST.passive_value(actor, &"upgraded_miss_zero_damage_shield", &"", 0)) >= 1,
			)
		&"territorial":
			actor.upgraded_passives.clear()
			actor._recalculate_stats(board)
			var base_intruder := _place_enemy(board, 2, Vector2i(5, 3))
			base_intruder.movement.points_left = maxi(base_intruder.movement.points_left, 3)
			var base_hp := base_intruder.health.current_hp
			var base_events: Array[SimEvent] = []
			_MovementSystem.execute_move(
				board,
				TimelineAction.make_move(base_intruder.id, Vector2i(3, 3)),
				base_events,
			)
			_assert(
				failures,
				"passive/territorial/base_entry_damage",
				base_intruder.health.current_hp < base_hp,
			)
			_assert(
				failures,
				"passive/territorial/base_entry_amount",
				_event_hp_damage(base_events, base_intruder.id) >= 1,
			)
			var up_board := _plain_board(Vector2i(10, 8))
			var up_actor := _place_actor(up_board, 1, Vector2i(2, 3), _ability(definition, &"beast_thrash"))
			up_actor.active_passives.append(passive)
			up_actor.upgraded_passives.append(passive_id)
			up_actor._recalculate_stats(up_board)
			var intruder := _place_enemy(up_board, 4, Vector2i(5, 3))
			intruder.movement.points_left = maxi(intruder.movement.points_left, 3)
			var hp_before := intruder.health.current_hp
			var move_events: Array[SimEvent] = []
			_MovementSystem.execute_move(
				up_board,
				TimelineAction.make_move(intruder.id, Vector2i(3, 3)),
				move_events,
			)
			_assert(
				failures,
				"passive/territorial/upgraded_entry_damage",
				intruder.health.current_hp < hp_before,
			)
			_assert(
				failures,
				"passive/territorial/upgraded_entry_amount",
				_event_hp_damage(move_events, intruder.id) >= 2,
			)
		&"intimidating_presence":
			var before_def := actor.current_defense
			var source := _place_enemy(board, 7, Vector2i(3, 3))
			source.active_passives.append(passive)
			source.upgraded_passives.append(passive_id)
			source._recalculate_stats(board)
			actor._recalculate_stats(board)
			_assert(
				failures,
				"passive/intimidating_presence/def_down",
				actor.current_defense < before_def,
			)
		&"dive_bomber":
			actor.passive_flags["beast_tiles_moved"] = 3
			var dive_target := _place_enemy(board, 2, Vector2i(4, 3))
			var dive_bonus := _BEAST.damage_bonus(board, actor, dive_target, null)
			_assert(failures, "passive/dive_bomber/bonus", dive_bonus >= 2)
		&"pack_hunter":
			var pack_target := _place_enemy(board, 2, Vector2i(5, 5))
			actor.passive_flags["__current_ability"] = _ability(definition, &"beast_savage_bite")
			_BEAST.on_attack_hit(board, actor, pack_target, events)
			_assert(
				failures,
				"passive/pack_hunter/bite",
				_event_damaged_unit(events, pack_target.id),
			)
		&"blood_scent":
			var bleed_target := _place_enemy(board, 2, Vector2i(4, 3))
			bleed_target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLEED, 1))
			actor.passive_flags["beast_move_start"] = Vector2i(1, 3)
			actor.position = Vector2i(2, 3)
			_assert(
				failures,
				"passive/blood_scent/pierce",
				_BEAST.should_pierce(board, actor, bleed_target, null),
			)
		&"vantage_striker":
			_set_hazard_tile(board, actor.position)
			actor._recalculate_stats(board)
			var vantage_target := _place_enemy(board, 2, Vector2i(4, 3))
			var vantage_bonus := _BEAST.attack_strength_bonus(board, actor, vantage_target)
			_assert(failures, "passive/vantage_striker/bonus", vantage_bonus >= 1)
		&"predatory_drive":
			var predatory_target := _place_enemy(board, 2, Vector2i(4, 3))
			predatory_target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLEED, 1))
			actor.passive_flags["__current_ability"] = _ability(definition, &"beast_thrash")
			_BEAST.on_attack_hit(board, actor, predatory_target, events)
			_assert(
				failures,
				"passive/predatory_drive/bleed",
				predatory_target.has_status(GameEnums.StatusType.BLEED),
			)
		&"furious_charge":
			actor.passive_flags["beast_move_start"] = Vector2i(2, 3)
			actor.position = Vector2i(5, 3)
			_BEAST.after_standard_move(board, actor, events)
			_assert(
				failures,
				"passive/furious_charge/push_flag",
				int(actor.passive_flags.get("beast_furious_charge_push", 0)) >= 1,
			)
		_:
			failures.append("passive/%s/unhandled" % passive_id)


static func run_ability_upgrade_row(ability_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"beast_rider")
	var ability := _ability(definition, ability_id)
	_assert(failures, "%s/upgrade/data" % ability_id, ability != null and not ability.upgraded_modules.is_empty())
	if ability == null:
		return
	var board := _plain_board(Vector2i(10, 8))
	var actor_pos := Vector2i(2, 3)
	var actor := _place_actor(board, 1, actor_pos, ability)
	actor.upgraded_abilities.append(ability_id)
	var target_setup := _configure_sim_target(board, ability_id, ability, actor_pos)
	var action := TimelineAction.make_ability(
		actor.id, ability, target_setup.coord, target_setup.id,
	)
	_apply_sim_action_overrides(action, ability_id, ability, actor, board, target_setup)
	if ability_id == &"beast_maul" and target_setup.get("unit") != null:
		actor.passive_flags["beast_drag_target_id"] = (target_setup.get("unit") as UnitState).id
	if ability_id == &"beast_fetch":
		board.items.append(target_setup.coord)
		action.target_coord = target_setup.coord
		action.target_unit_id = -1
	_assert(
		failures,
		"%s/upgrade/active_profile" % ability_id,
		ability.get_active_modules(true).size() == ability.upgraded_modules.size(),
	)
	if not AbilitySystem.can_use(board, action):
		return
	var board_before := board.clone()
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, _timeline(action), events)
	if ability_id not in [&"beast_feral_drag"]:
		_assert(
			failures,
			"%s/upgrade/ability_used" % ability_id,
			_events_have_ability(events, ability_id),
		)
	_assert_ability_sim_outcome(
		failures,
		ability_id,
		ability,
		events,
		board_before,
		board,
		target_setup,
	)


static func run_gore_bible_proof(failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"beast_rider")
	var ability := _ability(definition, &"beast_gore")
	_assert(failures, "beast_gore/bible/data", ability != null)
	if ability == null:
		return
	var clean := _sim_gore_once(ability, false, false)
	var bled := _sim_gore_once(ability, true, false)
	var upgraded := _sim_gore_once(ability, false, true)
	_assert(failures, "beast_gore/bible/damage", int(clean.get("damage", 0)) > 0)
	_assert(
		failures,
		"beast_gore/bible/push",
		clean.get("target_pos", Vector2i(3, 3)) != Vector2i(3, 3),
	)
	_assert(
		failures,
		"beast_gore/bible/bleed_bonus",
		int(bled.get("damage", 0)) > int(clean.get("damage", 0)),
	)
	_assert(failures, "beast_gore/bible/upgrade_vulnerable", bool(upgraded.get("vulnerable", false)))


static func _sim_gore_once(ability: AbilityData, apply_bleed: bool, upgraded: bool) -> Dictionary:
	var board := _plain_board(Vector2i(10, 8))
	var actor := _place_actor(board, 1, Vector2i(2, 3), ability)
	var target := _place_enemy(board, 2, Vector2i(3, 3))
	if apply_bleed:
		target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLEED, 1))
	if upgraded:
		actor.upgraded_abilities.append(&"beast_gore")
	actor.passive_flags["training_unlimited_actions"] = true
	actor.turn_action_used = false
	actor.ability.points_left = actor.ability.max_points
	var action := TimelineAction.make_ability(actor.id, ability, target.position, target.id)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, _timeline(action), events)
	var after := board.get_unit_by_id(2)
	return {
		"damage": _event_hp_damage(events, 2),
		"target_pos": after.position if after != null else Vector2i(3, 3),
		"vulnerable": after != null and after.has_status(GameEnums.StatusType.VULNERABLE),
	}


static func run_planning_row(factory_id: StringName, failures: Array[String]) -> void:
	_PLANNING.run_for_factory(failures, factory_id)


static func _timeline(action: TimelineAction) -> Timeline:
	var timeline := Timeline.new()
	timeline.add(action)
	return timeline


static func _set_hazard_tile(board: BoardState, coord: Vector2i) -> void:
	var hazard := DataLibrary.get_terrain(&"fire")
	if hazard == null:
		return
	board.tiles[coord] = TileState.create(coord, hazard)


static func _event_damaged_unit(events: Array[SimEvent], unit_id: int) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.UNIT_DAMAGED \
				and int(event.data.get("unit", -1)) == unit_id:
			return true
	return false


static func _event_hp_damage(events: Array[SimEvent], unit_id: int) -> int:
	var total := 0
	for event: SimEvent in events:
		if event.type != GameEnums.SimEventType.UNIT_DAMAGED:
			continue
		if int(event.data.get("unit", -1)) != unit_id:
			continue
		total += int(event.data.get("hp_damaged", event.data.get("amount", 0)))
	return total


static func _event_unit_moved(events: Array[SimEvent], unit_id: int) -> bool:
	for event: SimEvent in events:
		if event.type != GameEnums.SimEventType.UNIT_MOVED:
			continue
		var moved_id := int(event.data.get("unit", event.data.get("actor", -1)))
		if moved_id == unit_id:
			return true
	return false


static func _plain_board(size: Vector2i) -> BoardState:
	var board := BoardState.new()
	board.grid_size = size
	var plain := DataLibrary.get_terrain(&"plain")
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	return board


static func _place_actor(
	board: BoardState,
	unit_id: int,
	coord: Vector2i,
	ability: AbilityData,
) -> UnitState:
	var unit := UnitState.create(
		unit_id,
		FactoryTestHelpers.build_unit(&"beast_rider"),
		GameEnums.Team.PLAYER,
		coord,
		{"active_abilities": [DataLibrary.get_universal_run(), ability]},
	)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit


static func _place_target(board: BoardState, row_id: StringName) -> UnitState:
	var coord := Vector2i(3, 3)
	if row_id == &"beast_tail_swipe":
		coord = Vector2i(3, 4)
	if row_id == &"beast_pounce":
		coord = Vector2i(4, 3)
	if row_id == &"beast_airlift" or row_id == &"beast_reposition":
		return _place_ally(board, 2, coord)
	var target := _place_enemy(board, 2, coord, row_id)
	if row_id == &"beast_feral_drag":
		target.health.max_hp = 5
		target.health.current_hp = 5
	if row_id == &"beast_savage_bite":
		target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLEED, 1))
	return target


static func _place_ally(board: BoardState, unit_id: int, coord: Vector2i) -> UnitState:
	var unit := UnitState.create(
		unit_id,
		FactoryTestHelpers.build_unit(&"beast_rider"),
		GameEnums.Team.PLAYER,
		coord,
	)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit


static func _place_enemy(board: BoardState, unit_id: int, coord: Vector2i, row_id: StringName = &"") -> UnitState:
	var definition: UnitData = DataLibrary.get_training_dummy()
	if row_id == &"beast_feral_drag":
		definition = definition.duplicate(true)
		definition.base_constitution = 1
	var unit := UnitState.create(
		unit_id,
		definition,
		GameEnums.Team.ENEMY,
		coord,
	)
	board.add_unit(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit


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


static func run_shaped_footprint(ability_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"beast_rider")
	var ability := _ability(definition, ability_id)
	if ability == null or not AoeFootprintQaHarness.ability_requires_footprint_qa(ability):
		return
	match ability_id:
		&"beast_bestial_roar":
			_run_target_shape_footprint(
				failures, ability_id, ability, Vector2i(3, 4), Vector2i(5, 3), Vector2i(8, 8),
			)
		&"beast_raking_claws":
			_run_target_shape_footprint(
				failures, ability_id, ability, Vector2i(3, 4), Vector2i(5, 3), Vector2i(8, 8),
			)
		&"beast_intimidate":
			_run_self_shape_footprint(
				failures, ability_id, ability, Vector2i(4, 4), Vector2i(8, 8),
			)
		&"beast_tail_swipe":
			_run_self_shape_footprint(
				failures, ability_id, ability, Vector2i(4, 4), Vector2i(8, 8),
			)
		_:
			failures.append("footprint/%s/unhandled_shaped_skill" % ability_id)


static func _configure_sim_target(
	board: BoardState,
	ability_id: StringName,
	ability: AbilityData,
	actor_pos: Vector2i,
) -> Dictionary:
	var target := _place_target(board, ability_id)
	var coord := target.position
	var target_id := target.id
	if ability.has_targeting(GameEnums.TargetingFlags.SELF):
		coord = actor_pos
		target_id = 1
	match ability_id:
		&"beast_raking_claws", &"beast_intimidate":
			target_id = -1
		&"beast_pounce":
			coord = Vector2i(3, 3)
			target_id = target.id
		&"beast_run_down":
			coord = Vector2i(4, 3)
			target_id = -1
	return {"coord": coord, "id": target_id, "unit": target}


static func _apply_sim_action_overrides(
	action: TimelineAction,
	ability_id: StringName,
	ability: AbilityData,
	actor: UnitState,
	board: BoardState,
	target_setup: Dictionary,
) -> void:
	var target: UnitState = target_setup.get("unit")
	if ability.has_targeting(GameEnums.TargetingFlags.SELF):
		action.target_coord = actor.position
		action.target_unit_id = actor.id
	if ability_id in [&"beast_tail_swipe", &"beast_defensive_posture"]:
		action.target_coord = actor.position
		action.target_unit_id = actor.id
	if ability_id == &"beast_airlift" and target != null:
		action.target_unit_id = target.id
		action.target_coord = target.position
	if ability_id == &"beast_feral_drag" and target != null:
		action.target_unit_id = target.id
		action.target_coord = target.position
	if ability_id == &"beast_bestial_roar" and target != null:
		target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLEED, 1))
		action.target_unit_id = target.id
	if ability_id == &"beast_savage_bite" and target != null:
		target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLEED, 1))
	if ability_id == &"beast_intimidate":
		action.target_unit_id = -1
		action.target_coord = actor.position
	if ability_id == &"beast_pounce" and target != null:
		action.target_coord = target.position
		action.target_unit_id = target.id
		AbilitySystem.set_module_target(action, 0, target.position, target.id)
	if ability_id == &"beast_run_down":
		action.target_unit_id = -1
		action.target_coord = Vector2i(4, 3)


static func _run_target_shape_footprint(
	failures: Array[String],
	ability_id: StringName,
	ability: AbilityData,
	origin: Vector2i,
	target: Vector2i,
	outside: Vector2i,
) -> void:
	var board := _plain_board(Vector2i(10, 8))
	_place_actor(board, 1, origin, ability)
	_place_enemy(board, 2, target)
	AoeFootprintQaHarness.assert_footprint_excludes(
		failures,
		"footprint/%s/grid" % ability_id,
		board,
		origin,
		target,
		ability.target_shape,
		ability.target_shape_size,
		outside,
	)


static func _run_self_shape_footprint(
	failures: Array[String],
	ability_id: StringName,
	ability: AbilityData,
	origin: Vector2i,
	outside: Vector2i,
) -> void:
	var board := _plain_board(Vector2i(10, 8))
	_place_actor(board, 1, origin, ability)
	AoeFootprintQaHarness.assert_footprint_excludes(
		failures,
		"footprint/%s/grid" % ability_id,
		board,
		origin,
		origin,
		ability.target_shape,
		ability.target_shape_size,
		outside,
	)


static func _assert_ability_sim_outcome(
	failures: Array[String],
	ability_id: StringName,
	ability: AbilityData,
	events: Array[SimEvent],
	board_before: BoardState,
	board_after: BoardState,
	target_setup: Dictionary,
) -> void:
	var target_id: int = target_setup.get("id", -1)
	var target: UnitState = target_setup.get("unit")
	match ability_id:
		&"beast_reposition":
			if target != null:
				var after_actor := board_after.get_unit_by_id(1)
				var after_target := board_after.get_unit_by_id(target.id)
				_assert(
					failures,
					"%s/outcome/caster_stays" % ability_id,
					after_actor != null and after_actor.position == Vector2i(2, 3),
				)
				_assert(
					failures,
					"%s/outcome/opposite_side" % ability_id,
					after_target != null and after_target.position == Vector2i(1, 3),
				)
		&"beast_rest_recover":
			var after_rest := board_after.get_unit_by_id(1)
			_assert(
				failures,
				"%s/outcome/consumed_mov" % ability_id,
				after_rest != null and after_rest.movement.points_left == 0,
			)
		&"beast_pounce":
			var after_pounce := board_after.get_unit_by_id(1)
			var after_prey: UnitState = (
				board_after.get_unit_by_id(target_id) if target_id >= 0 else null
			)
			var prey_before: UnitState = (
				board_before.get_unit_by_id(target_id) if target_id >= 0 else null
			)
			var pounce_used: bool = (
				not _has_action_failure(events, 1)
				and _events_have_ability(events, ability_id)
				and after_pounce != null
				and after_prey != null
				and prey_before != null
			)
			if after_pounce != null and after_pounce.is_ability_upgraded(&"beast_pounce"):
				_assert(
					failures,
					"%s/outcome/pounce" % ability_id,
					pounce_used
						and GridSystem.manhattan(after_pounce.position, prey_before.position) == 1
						and after_prey.position != prey_before.position,
				)
			else:
				_assert(
					failures,
					"%s/outcome/pounce" % ability_id,
					pounce_used
						and GridSystem.manhattan(after_pounce.position, after_prey.position) == 1,
				)
		&"beast_feral_drag":
			_assert(
				failures,
				"%s/outcome/feral" % ability_id,
				_events_have_ability(events, ability_id) or not _has_action_failure(events, 1),
			)
		&"beast_fetch":
			var actor_after := board_after.get_unit_by_id(1)
			_assert(
				failures,
				"%s/outcome/pull_or_used" % ability_id,
				_events_have_ability(events, ability_id)
					or (
						target != null
						and board_before.get_unit_by_id(target.id) != null
						and board_after.get_unit_by_id(target.id) != null
						and board_before.get_unit_by_id(target.id).position
						!= board_after.get_unit_by_id(target.id).position
					),
			)
		&"beast_airlift":
			_assert(failures, "%s/outcome/used" % ability_id, _events_have_ability(events, ability_id))
		&"beast_run_down":
			var before_actor := board_before.get_unit_by_id(1)
			var after_actor := board_after.get_unit_by_id(1)
			_assert(
				failures,
				"%s/outcome/move" % ability_id,
				before_actor != null
					and after_actor != null
					and (
						before_actor.position != after_actor.position
						or _events_have_ability(events, ability_id)
					),
			)
		&"beast_thrash":
			var thrash_hits := 0
			for event: SimEvent in events:
				if event.type != GameEnums.SimEventType.UNIT_DAMAGED:
					continue
				if int(event.data.get("unit", -1)) != target_id:
					continue
				thrash_hits += 1
			_assert(
				failures,
				"%s/outcome/three_physical_hits" % ability_id,
				thrash_hits == 3,
			)
		_:
			ClassScenarioSimOutcome.assert_from_events(
				failures,
				"%s" % ability_id,
				ability,
				events,
				board_before,
				board_after,
				target_id,
			)


static func _read_module_int(module: AbilityModule, field: StringName) -> int:
	match field:
		&"amount":
			return module.amount
		&"max_range":
			return module.max_range
		&"shape_size":
			return module.target_shape_size
		&"hit_count":
			return module.hit_count
	return -1


static func _action_failure_reason(events: Array[SimEvent], actor_id: int) -> String:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ACTION_FAILED \
				and int(event.data.get("actor", -1)) == actor_id:
			return str(event.data.get("reason", event.data))
	return "ok"


static func _has_action_failure(events: Array[SimEvent], actor_id: int) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ACTION_FAILED \
				and int(event.data.get("actor", -1)) == actor_id:
			return true
	return false


static func _events_have_ability(events: Array[SimEvent], ability_id: StringName) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ABILITY_USED \
				and event.data.get("ability") == ability_id:
			return true
	return false


static func _assert(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
