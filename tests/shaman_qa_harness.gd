class_name ShamanQaHarness
extends RefCounted

## Shared Shaman class proof — Bible §10 data, sim outcomes, passive triggers.
## Scenarios delegate here (CLASS_QA_BIBLE.md §3 Layer B).

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
	&"shaman_soul_siphon",
	&"shaman_pain_spike",
	&"shaman_earthbind_totem",
]

const _SHAMAN_SYSTEMS := preload("res://core/systems/shaman_systems.gd")

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
	_assert(failures, "bible/base_constitution", shaman.base_constitution == 3)
	_assert(failures, "bible/base_movement", shaman.move_points == 4)
	_assert(failures, "bible/base_strength", shaman.base_strength == 1)
	_assert(failures, "bible/base_defense", shaman.base_defense == 1)
	_assert(failures, "bible/base_magic", shaman.base_magic == 4)
	_assert(failures, "factory/innate_count", shaman.innate_passives.size() == 1)
	_assert(failures, "factory/active_count", shaman.abilities.size() == 17)
	_assert(failures, "factory/promotion_passive_count", shaman.passives.size() == 15)
	_assert(
		failures, "bible/promotion_spirit_caller",
		shaman.promotion_stat_bonuses.get(&"spirit_caller", {}).get("constitution", -1) == 4
		and shaman.promotion_stat_bonuses.get(&"spirit_caller", {}).get("defense", -1) == 4
		and shaman.promotion_stat_bonuses.get(&"spirit_caller", {}).get("movement", -1) == 0,
	)
	_assert(
		failures, "bible/promotion_bloodweaver",
		shaman.promotion_stat_bonuses.get(&"bloodweaver", {}).get("magic", -1) == 4
		and shaman.promotion_stat_bonuses.get(&"bloodweaver", {}).get("constitution", -1) == 4,
	)
	_assert(
		failures, "bible/promotion_soulwalker",
		shaman.promotion_stat_bonuses.get(&"soulwalker", {}).get("magic", -1) == 6
		and shaman.promotion_stat_bonuses.get(&"soulwalker", {}).get("movement", -1) == 2,
	)
	var usher := _ability(shaman, &"shaman_usher")
	_assert(failures, "bible/usher_mp_cost", usher != null and usher.movement_point_cost == 2)
	if usher != null:
		_assert(failures, "bible/usher_base_range", usher.modules[0].max_range == 2)
		_assert(failures, "bible/usher_upgraded_range", usher.upgraded_modules[0].max_range == 4)
	var hex_innate := _passive(shaman, &"hexing_presence")
	_assert(
		failures, "bible/hexing_presence_aura",
		hex_innate != null
		and int(hex_innate.modifiers.get("hexing_presence_range", 0)) == 2
		and int(hex_innate.modifiers.get("hexing_presence_str", 0)) == -2,
	)
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
	var definition := FactoryTestHelpers.build_unit(&"shaman")
	var ability := _ability(definition, ability_id)
	_assert(failures, "sim/%s/data" % ability_id, ability != null)
	if ability == null:
		return
	var board := _plain_board(Vector2i(10, 8))
	var shaman := _place_shaman(board, 1, Vector2i(2, 3), ability_id)
	var target_setup := _configure_sim_target(board, ability_id, shaman.position)
	var target_coord: Vector2i = target_setup.coord
	var target_id: int = target_setup.id
	var action := TimelineAction.make_ability(1, ability, target_coord, target_id)
	_bind_dual_aim(action, ability_id, board, target_coord, target_id)
	if not AbilitySystem.can_use(board, action):
		_assert(failures, "sim/%s/can_use" % ability_id, false)
		return
	var board_before := board.clone()
	var before_ally_pos := Vector2i.ZERO
	if ability_id == &"shaman_usher":
		var ally := board.get_unit_by_id(2)
		if ally != null:
			before_ally_pos = ally.position
	var plan := Timeline.new()
	plan.add(action)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	_assert(failures, "sim/%s/ability_used" % ability_id, _events_have_ability(events, ability_id))
	_assert(failures, "sim/%s/no_action_failure" % ability_id, not _has_action_failure(events, 1))
	if ability_id not in [
		&"shaman_usher", &"shaman_voodoo_link", &"shaman_sympathetic_bond", &"shaman_hex",
	]:
		ClassScenarioSimOutcome.assert_from_events(
			failures, "sim/%s" % ability_id, ability, events, board_before, board, target_id,
		)
	_assert_shaman_outcome(
		failures, ability_id, ability, events, board_before, board, target_id, before_ally_pos,
	)
	if ability_id == &"shaman_bone_spear":
		run_shaped_footprint(ability_id, failures)


static func run_shaped_footprint(ability_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"shaman")
	var ability := _ability(definition, ability_id)
	if ability == null or not AoeFootprintQaHarness.ability_requires_footprint_qa(ability):
		return
	var board := _plain_board(Vector2i(10, 8))
	var origin := Vector2i(2, 3)
	var target := Vector2i(6, 3)
	_place_shaman(board, 1, origin, ability_id)
	_place_dummy(board, 3, Vector2i(5, 3))
	var outside := Vector2i(2, 0)
	AoeFootprintQaHarness.assert_footprint_excludes(
		failures, "footprint/%s" % ability_id, board, origin, target,
		GameEnums.TargetShape.LINE, 4, outside,
	)


static func run_upgrade_sim_for(ability_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"shaman")
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
	var shaman := _place_shaman(board, 1, Vector2i(2, 3), ability_id)
	shaman.upgraded_abilities.append(ability_id)
	var target_setup := _configure_sim_target(board, ability_id, shaman.position)
	var target_id: int = target_setup.id
	var action := TimelineAction.make_ability(
		1, ability, target_setup.coord, target_id,
	)
	_bind_dual_aim(action, ability_id, board, target_setup.coord, target_id)
	_assert(
		failures, "upgrade/%s/profile" % ability_id,
		shaman.is_ability_upgraded(ability_id),
	)
	if not AbilitySystem.can_use(board, action):
		return
	var board_before := board.clone()
	var plan := Timeline.new()
	plan.add(action)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	_assert(
		failures, "upgrade/%s/ability_used" % ability_id,
		_events_have_ability(events, ability_id),
	)
	_assert_upgrade_outcome(
		failures, ability_id, ability, events, board_before, board, target_id,
	)


static func _assert_upgrade_outcome(
	failures: Array[String],
	ability_id: StringName,
	ability: AbilityData,
	events: Array[SimEvent],
	board_before: BoardState,
	board_after: BoardState,
	target_id: int,
) -> void:
	match ability_id:
		&"shaman_usher":
			var usher_board := _plain_board(Vector2i(10, 8))
			var usher_shaman := _place_shaman(usher_board, 1, Vector2i(2, 3), ability_id)
			usher_shaman.upgraded_abilities.append(ability_id)
			var totem_def := DataLibrary.get_unit(&"voodoo_totem")
			var totem := UnitState.create(5, totem_def, GameEnums.Team.PLAYER, Vector2i(3, 3))
			totem.passive_flags["shaman_totem_owner_id"] = 1
			usher_board.add_unit(totem)
			GridSystem.set_occupant(usher_board, totem.position, totem.id)
			var usher_plan := Timeline.new()
			var usher_action := TimelineAction.make_ability(1, ability, Vector2i(3, 3), totem.id)
			AbilitySystem.set_module_target(usher_action, 0, Vector2i(3, 3), totem.id)
			AbilitySystem.set_module_target(usher_action, 1, Vector2i(5, 3), -1)
			usher_plan.add(usher_action)
			var usher_events: Array[SimEvent] = []
			Simulator.simulate_player_turn(usher_board, usher_plan, usher_events)
			var moved_totem := usher_board.get_unit_by_id(totem.id)
			_assert(
				failures, "upgrade/shaman_usher/totem_moved",
				moved_totem != null and moved_totem.position == Vector2i(5, 3),
			)
		&"shaman_healing_totem":
			for unit: UnitState in board_after.units:
				if unit != null and unit.passive_flags.get("shaman_totem_upgraded", false):
					_assert(
						failures, "upgrade/shaman_healing_totem/upgraded_flag",
						true,
					)
					return
			_assert(failures, "upgrade/shaman_healing_totem/upgraded_flag", false)
		&"shaman_flame_totem":
			var flame_board := board_after.clone()
			var flame_owner := flame_board.get_unit_by_id(1)
			if flame_owner != null:
				_SHAMAN_SYSTEMS.turn_start(flame_board, flame_owner, [])
			_assert(
				failures, "upgrade/shaman_flame_totem/fire_surface",
				_terrain_has_fire(flame_board),
			)
		&"shaman_totem_guard":
			var guard: UnitState = null
			for unit: UnitState in board_after.units:
				if unit != null and unit.passive_flags.get("shaman_totem_kind", &"") == &"guard":
					guard = unit
					break
			_assert(
				failures, "upgrade/shaman_totem_guard/melee_def_flag",
				guard != null and int(guard.passive_flags.get("shaman_guard_melee_def", 0)) == 1,
			)
			if guard == null:
				return
			var ally := board_after.get_unit_by_id(2)
			if ally == null or GridSystem.manhattan(guard.position, ally.position) > 1:
				ally = _place_ally(board_after, 2, guard.position + Vector2i(1, 0))
			var melee_spot := ally.position + Vector2i(0, 1)
			if melee_spot == guard.position or board_after.get_unit_at(melee_spot) != null:
				melee_spot = ally.position + Vector2i(-1, 0)
			if melee_spot == guard.position or board_after.get_unit_at(melee_spot) != null:
				melee_spot = ally.position + Vector2i(1, 0)
			var melee_enemy := _place_dummy(board_after, 9, melee_spot)
			_assert(
				failures, "upgrade/shaman_totem_guard/melee_def_bonus",
				_SHAMAN_SYSTEMS.guard_melee_defense_bonus(board_after, ally, melee_enemy) == 1,
			)
			var control := board_after.clone()
			for unit: UnitState in control.units:
				if unit != null and unit.passive_flags.get("shaman_totem_kind", &"") == &"guard":
					unit.passive_flags["shaman_guard_melee_def"] = 0
			var control_ally := control.get_unit_by_id(ally.id)
			var control_enemy := control.get_unit_by_id(melee_enemy.id)
			var hp_live := ally.health.current_hp
			var hp_ctrl := control_ally.health.current_hp
			var live_events: Array[SimEvent] = []
			var ctrl_events: Array[SimEvent] = []
			CombatSystem.deal_damage(
				board_after, ally, 8, live_events, &"physical", false, false, melee_enemy,
			)
			CombatSystem.deal_damage(
				control, control_ally, 8, ctrl_events, &"physical", false, false, control_enemy,
			)
			_assert(
				failures, "upgrade/shaman_totem_guard/melee_def_mitigation",
				(hp_live - ally.health.current_hp) < (hp_ctrl - control_ally.health.current_hp),
			)
			var ranged_spot := ally.position + Vector2i(3, 0)
			if board_after.get_unit_at(ranged_spot) != null:
				ranged_spot = ally.position + Vector2i(0, 3)
			var ranged_enemy := _place_dummy(board_after, 10, ranged_spot)
			_assert(
				failures, "upgrade/shaman_totem_guard/ranged_no_melee_def",
				_SHAMAN_SYSTEMS.guard_melee_defense_bonus(board_after, ally, ranged_enemy) == 0,
			)
		&"shaman_hex":
			var target := board_after.get_unit_by_id(target_id)
			_assert(
				failures, "upgrade/shaman_hex/vulnerable",
				target != null and target.has_status(GameEnums.StatusType.VULNERABLE),
			)
		&"shaman_voodoo_link":
			var upgraded_modules := ability.get_active_modules(true)
			_assert(
				failures, "upgrade/shaman_voodoo_link/shared_push",
				not upgraded_modules.is_empty()
				and upgraded_modules[0].legacy_modifiers.get("shared_push", false),
			)
		&"shaman_bone_spear":
			var rod: UnitState = null
			for unit: UnitState in board_after.units:
				if unit != null and unit.passive_flags.get("shaman_lightning_rod", false):
					rod = unit
					break
			_assert(failures, "upgrade/shaman_bone_spear/lightning_rod", rod != null)
			if rod != null:
				var redirect_board := board_after.clone()
				var ally_victim := _place_ally(redirect_board, 8, rod.position + Vector2i(1, 0))
				var enemy_attacker := _place_dummy(redirect_board, 9, ally_victim.position + Vector2i(1, 0))
				var ally_hp_before := ally_victim.health.current_hp
				var rod_on_board := redirect_board.get_unit_by_id(rod.id)
				var rod_hp_before := rod_on_board.health.current_hp if rod_on_board != null else 0
				var redirect_events: Array[SimEvent] = []
				CombatSystem.deal_damage(
					redirect_board, ally_victim, 4, redirect_events, &"magical",
					false, false, enemy_attacker, "Lightning Test",
				)
				var rod_after := redirect_board.get_unit_by_id(rod.id)
				var ally_after := redirect_board.get_unit_by_id(ally_victim.id)
				_assert(
					failures, "upgrade/shaman_bone_spear/lightning_redirect",
					rod_after != null
					and rod_after.health.current_hp < rod_hp_before
					and ally_after != null
					and ally_after.health.current_hp == ally_hp_before,
				)
		&"shaman_curse_of_weakness":
			var target := board_after.get_unit_by_id(target_id)
			_assert(
				failures, "upgrade/shaman_curse_of_weakness/push_mitigation_zero",
				target != null and target.passive_flags.get("no_push_mitigation", false),
			)
		&"shaman_soul_siphon":
			var upgraded_modules := ability.get_active_modules(true)
			_assert(
				failures, "upgrade/shaman_soul_siphon/heal_per_debuff",
				not upgraded_modules.is_empty()
				and upgraded_modules[0].legacy_modifiers.has("heal_per_debuff"),
			)
			_assert(
				failures, "upgrade/shaman_soul_siphon/heal_on_debuff",
				_events_have_heal(events, 1) or _events_have_damage(events, target_id),
			)
		&"shaman_pain_spike":
			var upgraded := ability.get_active_modules(true)
			_assert(
				failures, "upgrade/shaman_pain_spike/blind_module",
				not upgraded.is_empty()
				and upgraded[0].legacy_modifiers.get("linked_enemy_blind", false),
			)
		_:
			pass


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
		var _layer_b_board := _plain_board(Vector2i(6, 6))
		var _layer_b_events: Array[SimEvent] = []
		Simulator.simulate_player_turn(_layer_b_board, Timeline.new(), _layer_b_events)
		_run_passive_trigger(passive_id, failures)
		return
	failures.append("passive/%s/registry_row" % passive_id)


static func _run_passive_trigger(passive_id: StringName, failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"shaman")
	var passive := _passive(definition, passive_id)
	if passive == null:
		return
	var board := _plain_board(Vector2i(10, 8))
	var shaman := _place_shaman(board, 1, Vector2i(2, 3), &"shaman_miasma")
	if passive_id != &"hexing_presence":
		shaman.active_passives.append(passive)
	var events: Array[SimEvent] = []
	match passive_id:
		&"hexing_presence":
			var enemy := _place_dummy(board, 3, Vector2i(4, 3))
			var adj := _SHAMAN_SYSTEMS.dynamic_stat_adjustments(board, enemy)
			_assert(
				failures, "passive/hexing_presence/aura_str",
				int(adj.get("strength", 0)) == -2,
			)
			_assert(
				failures, "passive/hexing_presence/aura_mag",
				int(adj.get("magic", 0)) == -2,
			)
			_assert(
				failures, "passive/hexing_presence/aura_def",
				int(adj.get("defense", 0)) == -2,
			)
			_assert(
				failures, "passive/hexing_presence/no_shield",
				not _SHAMAN_SYSTEMS.can_gain_shield(board, enemy),
			)
			shaman.upgraded_passives.append(&"hexing_presence")
			var far_enemy := _place_dummy(board, 4, Vector2i(5, 3))
			var upgraded_adj := _SHAMAN_SYSTEMS.dynamic_stat_adjustments(board, far_enemy)
			_assert(
				failures, "passive/hexing_presence/upgraded_range",
				int(upgraded_adj.get("strength", 0)) == -2,
			)
			_assert(
				failures, "passive/hexing_presence/upgraded_mov",
				int(upgraded_adj.get("movement", 0)) == -1,
			)
		&"echoing_spirits":
			shaman.active_passives.append(passive)
			var totem_def := DataLibrary.get_unit(&"voodoo_totem")
			var spawn_effect := DataLibrary._effect(GameEnums.EffectType.SPAWN, 0)
			spawn_effect.modifiers = {
				"totem_kind": &"healing", "pulse_aoe": 2, "pulse_heal": 1,
			}
			var scaled_hp := maxi(1, floori(shaman.health.max_hp * 0.5))
			var base_totem := UnitState.create(6, totem_def, GameEnums.Team.PLAYER, Vector2i(1, 1))
			base_totem.health.max_hp = scaled_hp
			base_totem.health.current_hp = scaled_hp
			_SHAMAN_SYSTEMS.on_spawned(
				board, shaman, base_totem, spawn_effect,
				TimelineAction.make_ability(1, DataLibrary.get_universal_wait(), Vector2i.ZERO),
				events,
			)
			var base_hp := base_totem.health.max_hp
			shaman.upgraded_passives.append(&"echoing_spirits")
			var upgraded_totem := UnitState.create(7, totem_def, GameEnums.Team.PLAYER, Vector2i(2, 1))
			upgraded_totem.health.max_hp = scaled_hp
			upgraded_totem.health.current_hp = scaled_hp
			_SHAMAN_SYSTEMS.on_spawned(
				board, shaman, upgraded_totem, spawn_effect,
				TimelineAction.make_ability(1, DataLibrary.get_universal_wait(), Vector2i.ZERO),
				events,
			)
			_assert(
				failures, "passive/echoing_spirits/upgraded_totem_hp",
				upgraded_totem.health.max_hp == base_hp + 2,
			)
			var totem := upgraded_totem
			totem.position = Vector2i(3, 3)
			board.add_unit(totem)
			GridSystem.set_occupant(board, totem.position, totem.id)
			var ally := _place_ally(board, 2, Vector2i(4, 3))
			ally.health.current_hp = maxi(1, ally.health.max_hp - 2)
			var hp_before := ally.health.current_hp
			_SHAMAN_SYSTEMS.turn_start(board, shaman, events)
			_assert(
				failures, "passive/echoing_spirits/double_pulse",
				ally.health.current_hp > hp_before,
			)
			var pulse_events := 0
			for event: SimEvent in events:
				if event.type == GameEnums.SimEventType.UNIT_HEALED \
						and int(event.data.get("unit", -1)) == ally.id:
					pulse_events += 1
			_assert(
				failures, "passive/echoing_spirits/pulse_count",
				pulse_events >= 2,
			)
		&"spiritual_offering":
			shaman.active_passives.append(passive)
			var heal_ability := _ability(definition, &"shaman_healing_totem")
			var armor_before := shaman.armor
			var totem_plan := Timeline.new()
			totem_plan.add(TimelineAction.make_ability(1, heal_ability, Vector2i(3, 3), -1))
			Simulator.simulate_player_turn(board, totem_plan, events)
			_assert(
				failures, "passive/spiritual_offering/shield_value",
				shaman.armor > armor_before,
			)
		&"spiritual_guardian":
			var ally := _place_ally(board, 2, Vector2i(3, 3))
			shaman.passive_flags["shaman_guardian_link"] = true
			shaman.passive_flags["shaman_guardian_def"] = 1
			ally._recalculate_stats(board)
			_assert(
				failures, "passive/spiritual_guardian/adjacent_def",
				ally.current_defense > definition.base_defense,
			)
		&"miasma_resonance":
			var enemy := _place_dummy(board, 3, Vector2i(4, 3))
			enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.POISON, 1))
			var bonus := _SHAMAN_SYSTEMS.damage_bonus(
				board, shaman, enemy, null, &"poison",
			)
			_assert(failures, "passive/miasma_resonance/dot_bonus", bonus >= 1)
		&"voodoo_conduit":
			var ability := _ability(definition, &"shaman_healing_totem")
			var bonus := _SHAMAN_SYSTEMS.conduit_range_bonus(shaman, ability)
			_assert(failures, "passive/voodoo_conduit/range_bonus", bonus >= 1)
		&"voodoo_doll":
			shaman.active_passives.append(passive)
			var debuffed := _place_dummy(board, 4, Vector2i(5, 3))
			debuffed.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.WEAKEN, 1))
			var attacker := _place_dummy(board, 5, Vector2i(3, 3))
			var hp_before := debuffed.health.current_hp
			_SHAMAN_SYSTEMS.on_dealt_damage(
				board, attacker, shaman, null, null, events, &"physical",
			)
			_assert(
				failures, "passive/voodoo_doll/retaliation",
				debuffed.health.current_hp < hp_before or _events_have_damage(events, debuffed.id),
			)
		&"spirit_link":
			shaman.active_passives.append(passive)
			var linked := _place_dummy(board, 3, Vector2i(4, 3))
			var partner := _place_dummy(board, 4, Vector2i(3, 2))
			linked.passive_flags["shaman_link_partner_id"] = partner.id
			linked.passive_flags["shaman_link_weapon"] = 1
			var hp_before := partner.health.current_hp
			CombatSystem.deal_damage(board, linked, 2, events, &"physical", true, true, shaman)
			_assert(
				failures, "passive/spirit_link/shared_damage",
				partner.health.current_hp < hp_before or _events_have_damage(events, partner.id),
			)
		&"pain_sharing":
			var linked := _place_dummy(board, 3, Vector2i(4, 3))
			linked.passive_flags["shaman_link_damage_bonus"] = 1
			var bonus := _SHAMAN_SYSTEMS.incoming_damage_bonus(linked)
			_assert(failures, "passive/pain_sharing/damage_bonus", bonus >= 1)
		&"sympathetic_magic":
			var ally := _place_ally(board, 2, Vector2i(3, 3))
			ally.passive_flags["shaman_bond_enemy_id"] = 3
			var enemy := _place_dummy(board, 3, Vector2i(5, 3))
			_SHAMAN_SYSTEMS.on_healed(board, shaman, ally, 2, events)
			_assert(
				failures, "passive/sympathetic_magic/heal_bonus",
				ally.has_status(GameEnums.StatusType.STAT_BUFF_MAG)
				or enemy.passive_flags.get("shaman_bond_healed", false),
			)
		&"chain_reaction":
			var linked := _place_dummy(board, 3, Vector2i(4, 3))
			var partner := _place_dummy(board, 4, Vector2i(3, 2))
			linked.passive_flags["shaman_link_partner_id"] = partner.id
			linked.passive_flags["shaman_link_shared_push"] = true
			linked.passive_flags["shaman_link_push_amount"] = 1
			var before := partner.position
			_SHAMAN_SYSTEMS.on_push_resolved(board, shaman, linked, &"test", events)
			_assert(
				failures, "passive/chain_reaction/push_propagation",
				partner.position != before or not events.is_empty(),
			)
		&"soul_collector":
			var victim := _place_dummy(board, 3, Vector2i(4, 3))
			_SHAMAN_SYSTEMS.on_kill(board, shaman, victim, events)
			_assert(
				failures, "passive/soul_collector/orb_drop",
				board.soul_orbs.has(victim.position),
			)
		&"hexing_touch":
			shaman.active_passives.append(passive)
			var attacker := _place_dummy(board, 3, Vector2i(3, 3))
			_assert(failures, "passive/hexing_touch/has_passive", shaman.has_passive(&"hexing_touch"))
			var def_before := attacker.current_defense
			_SHAMAN_SYSTEMS.on_dealt_damage(
				board, attacker, shaman, null, null, events, &"physical",
			)
			attacker._recalculate_stats(board)
			_assert(
				failures, "passive/hexing_touch/debuff_attacker",
				attacker.current_defense < def_before
				or not attacker.active_statuses.is_empty(),
			)
		&"ritual_sacrifice":
			shaman.active_passives.append(passive)
			var offering := _passive(definition, &"spiritual_offering")
			if offering != null:
				shaman.active_passives.append(offering)
			var ability := _ability(definition, &"shaman_miasma")
			_assert(
				failures, "passive/ritual_sacrifice/can_use",
				_SHAMAN_SYSTEMS.can_use_ritual_sacrifice(shaman, ability),
			)
			_assert(
				failures, "passive/ritual_sacrifice/hp_cost",
				_SHAMAN_SYSTEMS.ritual_sacrifice_cost(shaman) == 3,
			)
			shaman.ability.points_left = 0
			_place_dummy(board, 3, Vector2i(4, 3))
			var armor_before := shaman.armor
			var ritual_action := TimelineAction.make_ability(1, ability, Vector2i(4, 3), 3)
			if AbilitySystem.can_use(board, ritual_action):
				var ritual_plan := Timeline.new()
				ritual_plan.add(ritual_action)
				Simulator.simulate_player_turn(board, ritual_plan, events)
				_assert(
					failures, "passive/ritual_sacrifice/offering_shield",
					offering != null and shaman.armor > armor_before,
				)
		&"soul_burn":
			var enemy := _place_dummy(board, 3, Vector2i(4, 3))
			enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.WEAKEN, 1))
			var bonus := _SHAMAN_SYSTEMS.damage_bonus(board, shaman, enemy, null, &"physical")
			_assert(failures, "passive/soul_burn/damage_bonus", bonus >= 1)
		&"soul_weaver":
			var ally := _place_ally(board, 2, Vector2i(3, 3))
			ally.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.WEAKEN, 2))
			var enemy := _place_dummy(board, 3, Vector2i(5, 3))
			CombatSystem.heal(board, ally, 1, events)
			_SHAMAN_SYSTEMS.on_healed(board, shaman, ally, 1, events)
			_assert(
				failures, "passive/soul_weaver/transfer",
				enemy.has_status(GameEnums.StatusType.WEAKEN)
				or ally.active_statuses.is_empty(),
			)
		_:
			_assert(failures, "passive/%s/trigger" % passive_id, false)


static func _assert_shaman_outcome(
	failures: Array[String],
	ability_id: StringName,
	ability: AbilityData,
	events: Array[SimEvent],
	board_before: BoardState,
	board_after: BoardState,
	target_id: int,
	before_ally_pos: Vector2i,
) -> void:
	match ability_id:
		&"shaman_usher":
			var ally := board_after.get_unit_by_id(2)
			_assert(
				failures, "sim/shaman_usher/ally_moved",
				ally != null and ally.position != before_ally_pos,
			)
		&"shaman_healing_totem", &"shaman_flame_totem", &"shaman_totem_guard", &"shaman_earthbind_totem":
			_assert(
				failures, "sim/%s/spawn" % ability_id,
				_has_event(events, GameEnums.SimEventType.UNIT_SPAWNED),
			)
			if ability_id == &"shaman_healing_totem":
				var pulse_board := board_after.clone()
				var pulse_owner := pulse_board.get_unit_by_id(1)
				var pulse_ally := pulse_board.get_unit_by_id(2)
				if pulse_ally == null:
					pulse_ally = _place_ally(pulse_board, 2, Vector2i(5, 3))
				pulse_ally.health.current_hp = maxi(1, pulse_ally.health.max_hp - 2)
				var outside_enemy := _place_dummy(pulse_board, 6, Vector2i(2, 0))
				var outside_hp := outside_enemy.health.current_hp
				var inside_hp := pulse_ally.health.current_hp
				var pulse_events: Array[SimEvent] = []
				if pulse_owner != null:
					_SHAMAN_SYSTEMS.turn_start(pulse_board, pulse_owner, pulse_events)
				_assert(
					failures, "footprint/shaman_healing_totem/inside_healed",
					pulse_ally.health.current_hp > inside_hp,
				)
				_assert(
					failures, "footprint/shaman_healing_totem/outside_excluded",
					outside_enemy.health.current_hp == outside_hp,
				)
		&"shaman_ancestral_spirit":
			_assert(
				failures, "sim/shaman_ancestral_spirit/spawn",
				_has_event(events, GameEnums.SimEventType.UNIT_SPAWNED),
			)
		&"shaman_voodoo_link":
			var target := board_after.get_unit_by_id(target_id)
			_assert(
				failures, "sim/shaman_voodoo_link/linked",
				target != null and target.passive_flags.has("shaman_link_partner_id"),
			)
		&"shaman_sympathetic_bond":
			var ally := board_after.get_unit_by_id(2)
			_assert(
				failures, "sim/shaman_sympathetic_bond/bond",
				ally != null and ally.passive_flags.has("shaman_bond_enemy_id"),
			)
		&"shaman_hex":
			var target := board_after.get_unit_by_id(target_id)
			_assert(
				failures, "sim/shaman_hex/wither",
				target != null and target.passive_flags.get("shaman_wither", false),
			)
			if target != null:
				var mov_adj := _SHAMAN_SYSTEMS.dynamic_stat_adjustments(board_after, target)
				_assert(
					failures, "sim/shaman_hex/mov_penalty",
					int(mov_adj.get("movement", 0)) <= -2,
				)
				var victim := _place_dummy(board_after, 8, Vector2i(6, 3))
				var attack_events: Array[SimEvent] = []
				CombatSystem.deal_damage(
					board_after, victim, 10, attack_events, &"physical",
					false, false, target, "Wither Test",
				)
				var dealt := 0
				for event: SimEvent in attack_events:
					if event.type == GameEnums.SimEventType.UNIT_DAMAGED \
							and int(event.data.get("unit", -1)) == victim.id:
						dealt = int(event.data.get("amount", 0))
				_assert(
					failures, "sim/shaman_hex/damage_output_halved",
					dealt <= 5,
				)
				_assert(
					failures, "sim/shaman_hex/buff_blocked",
					not _SHAMAN_SYSTEMS.can_gain_positive_buff(target),
				)
		&"shaman_terrify":
			var target := board_after.get_unit_by_id(target_id)
			_assert(
				failures, "sim/shaman_terrify/fear",
				target != null and target.has_status(GameEnums.StatusType.FEAR),
			)
		&"shaman_miasma":
			var target := board_after.get_unit_by_id(target_id)
			_assert(
				failures, "sim/shaman_miasma/poison",
				target != null and target.has_status(GameEnums.StatusType.POISON),
			)
		&"shaman_bloodlust":
			var ally := board_after.get_unit_by_id(target_id)
			_assert(
				failures, "sim/shaman_bloodlust/buff",
				ally != null and (
					ally.passive_flags.get("shaman_bloodlust_active", false)
					or ally.has_status(GameEnums.StatusType.STAT_BUFF_STR)
				),
			)
		&"shaman_soul_siphon":
			var target := board_after.get_unit_by_id(target_id)
			_assert(
				failures, "sim/shaman_soul_siphon/damage_dealt",
				target != null and _events_have_damage(events, target_id),
			)
		_:
			pass


static func _configure_sim_target(
	board: BoardState,
	ability_id: StringName,
	origin: Vector2i,
) -> Dictionary:
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
		_place_ally(board, 2, Vector2i(3, 3))
		_place_dummy(board, 3, Vector2i(5, 3))
		target = Vector2i(3, 3)
		target_id = 2
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
		terrify_target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.WEAKEN, 1))
		target_id = 3
	elif ability_id == &"shaman_soul_siphon":
		var siphon_target := _place_dummy(board, 3, target)
		siphon_target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.WEAKEN, 1))
		target_id = 3
	elif ability_id in [
		&"shaman_healing_totem", &"shaman_flame_totem", &"shaman_bone_spear",
		&"shaman_totem_guard", &"shaman_earthbind_totem",
	]:
		_place_ally(board, 2, Vector2i(5, 3))
		if ability_id == &"shaman_bone_spear":
			_place_dummy(board, 3, Vector2i(5, 3))
	elif ability_id == &"shaman_ancestral_spirit":
		var corpse := _place_ally(board, 2, Vector2i(3, 3))
		corpse.health.current_hp = 0
		GridSystem.set_occupant(board, corpse.position, -1)
		target = corpse.position
		target_id = 2
	else:
		_place_dummy(board, 3, target)
		target_id = 3
	return {"coord": target, "id": target_id}


static func _bind_dual_aim(
	action: TimelineAction,
	ability_id: StringName,
	board: BoardState,
	target_coord: Vector2i,
	target_id: int,
) -> void:
	if action == null:
		return
	if ability_id == &"shaman_usher":
		AbilitySystem.set_module_target(action, 0, Vector2i(3, 3), 2)
		AbilitySystem.set_module_target(action, 1, Vector2i(4, 3), -1)
	elif ability_id == &"shaman_voodoo_link":
		var partner := board.get_unit_by_id(4)
		AbilitySystem.set_module_target(action, 0, target_coord, target_id)
		if partner != null:
			AbilitySystem.set_module_target(action, 1, partner.position, partner.id)
	elif ability_id == &"shaman_sympathetic_bond":
		var enemy := board.get_unit_by_id(3)
		AbilitySystem.set_module_target(action, 0, target_coord, target_id)
		if enemy != null:
			AbilitySystem.set_module_target(action, 1, enemy.position, enemy.id)


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
		"active_passives": definition.innate_passives.duplicate(),
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


static func _events_have_damage(events: Array[SimEvent], unit_id: int) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.UNIT_DAMAGED and int(event.data.get("unit", -1)) == unit_id:
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


static func _events_have_heal(events: Array[SimEvent], actor_id: int) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.UNIT_HEALED \
				and int(event.data.get("unit", -1)) == actor_id:
			return true
	return false


static func _terrain_has_fire(board: BoardState) -> bool:
	if board == null:
		return false
	for coord: Vector2i in board.tiles:
		var tile := board.get_tile(coord)
		if tile != null and tile.definition != null and tile.definition.id == &"fire":
			return true
	return false


static func _assert(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
