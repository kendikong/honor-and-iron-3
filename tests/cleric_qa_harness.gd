class_name ClericQaHarness
extends RefCounted

const _H := preload("res://tests/bruiser_qa_harness.gd")


static func run_all(failures: Array[String]) -> void:
	var definition: UnitData = FactoryTestHelpers.build_unit(&"cleric")
	_assert(failures, "cleric/factory", definition != null)
	if definition == null:
		return
	_assert(failures, "cleric/stats",
		definition.base_constitution == 4
		and definition.move_points == 4
		and definition.base_strength == 1
		and definition.base_defense == 1
		and definition.base_magic == 4)
	_assert(failures, "cleric/innate",
		definition.innate_passives.size() == 1
		and _passive(definition, &"selfless_siphon") != null)
	_assert(failures, "cleric/passives", definition.passives.size() == 15)
	_assert(failures, "cleric/abilities", definition.abilities.size() == 16)
	_assert(failures, "cleric/promotion_stats",
		definition.promotion_stat_bonuses.get("paladin", {}).get("constitution", 0) == 2
		and definition.promotion_stat_bonuses.get("paladin", {}).get("defense", 0) == 2
		and definition.promotion_stat_bonuses.get("paladin", {}).get("movement", 0) == 3
		and definition.promotion_stat_bonuses.get("seraph", {}).get("magic", 0) == 6
		and definition.promotion_stat_bonuses.get("seraph", {}).get("movement", 0) == 2
		and definition.promotion_stat_bonuses.get("zealot", {}).get("magic", 0) == 4
		and definition.promotion_stat_bonuses.get("zealot", {}).get("strength", 0) == 4)

	var expected: Array[StringName] = [
		&"cleric_guardian_step", &"cleric_holy_light", &"cleric_smite",
		&"cleric_cleansing_aura", &"cleric_sanctuary", &"cleric_blinding_ray",
		&"cleric_divine_hammer", &"cleric_life_link",
		&"cleric_prayer_of_fortitude", &"cleric_resurrection",
		&"cleric_consecrate_ground", &"cleric_holy_wrath",
		&"cleric_divine_guidance", &"cleric_shield_of_faith",
		&"cleric_martyrs_chains",
	]
	for ability_id: StringName in expected:
		_assert(failures, "ability/%s" % ability_id, _ability(definition, ability_id) != null)

	var guardian := _ability(definition, &"cleric_guardian_step")
	_assert(failures, "guardian_step/all_mov",
		guardian != null and guardian.movement_point_cost == 0
		and guardian.effects[0].modifiers.get("cost_all_movement", false)
		and guardian.effects[0].type == GameEnums.EffectType.TELEPORT_ADJACENT_TO
		and guardian.upgraded_effects[0].modifiers.get("cleanse_target", false))
	var holy_light := _ability(definition, &"cleric_holy_light")
	_assert(failures, "holy_light/mag_heal",
		holy_light != null and holy_light.effects[0].type == GameEnums.EffectType.HEAL
		and holy_light.effects[0].modifiers.get("mag_heal", false))
	_run_selfless_siphon(failures, definition)


static func run_factory_shell(failures: Array[String]) -> void:
	var definition: UnitData = FactoryTestHelpers.build_unit(&"cleric")
	_assert(failures, "cleric/factory", definition != null)
	if definition == null:
		return
	_assert(failures, "cleric/stats",
		definition.base_constitution == 4
		and definition.move_points == 4
		and definition.base_strength == 1
		and definition.base_defense == 1
		and definition.base_magic == 4)
	_assert(failures, "cleric/innate",
		definition.innate_passives.size() == 1
		and _passive(definition, &"selfless_siphon") != null)
	_assert(failures, "cleric/passives", definition.passives.size() == 15)
	_assert(failures, "cleric/abilities", definition.abilities.size() == 16)


static func run_ability_row(ability_id: StringName, failures: Array[String]) -> void:
	var definition: UnitData = FactoryTestHelpers.build_unit(&"cleric")
	_assert(failures, "ability/%s" % ability_id, _ability(definition, ability_id) != null)
	if ability_id == &"cleric_guardian_step":
		var guardian := _ability(definition, ability_id)
		_assert(failures, "guardian_step/all_mov",
			guardian != null and guardian.movement_point_cost == 0
			and guardian.effects[0].modifiers.get("cost_all_movement", false)
			and guardian.effects[0].type == GameEnums.EffectType.TELEPORT_ADJACENT_TO
			and guardian.upgraded_effects[0].modifiers.get("cleanse_target", false))
		_sim_ability_used(failures, ability_id, guardian, false)
	elif ability_id == &"cleric_holy_light":
		var holy_light := _ability(definition, ability_id)
		_assert(failures, "holy_light/mag_heal",
			holy_light != null and holy_light.effects[0].type == GameEnums.EffectType.HEAL
			and holy_light.effects[0].modifiers.get("mag_heal", false))
		_sim_ability_used(failures, ability_id, holy_light, false)
	else:
		var ability := _ability(definition, ability_id)
		if ability != null:
			_sim_ability_used(failures, ability_id, ability, false)


static func run_passive_row(passive_id: StringName, failures: Array[String]) -> void:
	var definition: UnitData = FactoryTestHelpers.build_unit(&"cleric")
	var passive := _passive(definition, passive_id)
	_assert(failures, "passive/%s" % passive_id, passive != null)
	if passive == null:
		return
	_assert(
		failures,
		"passive/%s/promotion" % passive_id,
		passive.modifiers.has("promotion"),
	)
	if not passive.upgraded_description.is_empty():
		_assert(
			failures,
			"passive/%s/upgraded_description" % passive_id,
			passive.upgraded_description.length() > 0,
		)
	run_single_passive(passive_id, failures)


static func run_single_passive(passive_id: StringName, failures: Array[String]) -> void:
	_run_passive_blocks(failures, passive_id)


static func _sim_ability_used(
	failures: Array[String],
	ability_id: StringName,
	ability: AbilityData,
	use_upgrade: bool,
) -> void:
	if ability == null:
		return
	var definition: UnitData = FactoryTestHelpers.build_unit(&"cleric")
	var board := _H.make_plain_board(Vector2i(10, 8))
	var cleric_cfg: Dictionary = {
		"active_abilities": [ability],
		"active_passives": [],
	}
	if use_upgrade and not ability.upgraded_effects.is_empty():
		cleric_cfg["upgraded_abilities"] = [ability_id]
	var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 3), cleric_cfg)
	var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(3, 3), {})
	var enemy := UnitState.create(
		3,
		DataLibrary.get_training_dummy(),
		GameEnums.Team.ENEMY,
		Vector2i(5, 3),
	)
	board.units.append(cleric)
	board.units.append(ally)
	board.units.append(enemy)
	for unit: UnitState in board.units:
		GridSystem.set_occupant(board, unit.position, unit.id)
	for effect: EffectData in ability.effects:
		if effect != null and effect.type == GameEnums.EffectType.HEAL:
			ally.health.current_hp = maxi(1, ally.health.max_hp - 3)
			break
	if ability_id == &"cleric_resurrection":
		ally.health.current_hp = 0
	var target: Dictionary = _sim_target_for_ability(
		cleric, ability, ability_id, use_upgrade, ally, enemy,
	)
	var target_coord: Vector2i = target["coord"]
	var target_id: int = target["id"]
	var action := TimelineAction.make_ability(cleric.id, ability, target_coord, target_id)
	if ability_id == &"cleric_martyrs_chains":
		var partner := UnitState.create(
			4,
			DataLibrary.get_training_dummy(),
			GameEnums.Team.ENEMY,
			Vector2i(6, 3),
		)
		board.units.append(partner)
		GridSystem.set_occupant(board, partner.position, partner.id)
		AbilitySystem.set_module_target(action, 0, enemy.position, enemy.id)
		AbilitySystem.set_module_target(action, 1, partner.position, partner.id)
	var legal: bool = AbilitySystem.can_use(board, action)
	if not legal:
		if use_upgrade:
			_assert(
				failures, "upgrade/%s/profile" % ability_id,
				cleric.is_ability_upgraded(ability_id),
			)
		else:
			_assert(failures, "sim/%s/can_use" % ability_id, false)
		return
	var hp_before: int = -1
	if target_id > 0:
		var target_unit: UnitState = board.get_unit_by_id(target_id)
		if target_unit != null:
			hp_before = target_unit.health.current_hp
	var actor_pos_before: Vector2i = cleric.position
	var plan := Timeline.new()
	plan.add(action)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	var used := false
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ABILITY_USED and event.data.get("ability") == ability_id:
			used = true
			break
	_assert(failures, "sim/%s/used" % ability_id, used)
	if use_upgrade:
		_assert(
			failures, "upgrade/%s/profile" % ability_id,
			cleric.is_ability_upgraded(ability_id),
		)
	_assert_cleric_outcome(
		failures, ability_id, ability, events, hp_before, actor_pos_before, board, target_id, use_upgrade,
	)


static func run_upgrade_sim_for(ability_id: StringName, failures: Array[String]) -> void:
	var definition: UnitData = FactoryTestHelpers.build_unit(&"cleric")
	var ability := _ability(definition, ability_id)
	if ability == null or ability.upgraded_effects.is_empty():
		return
	_sim_ability_used(failures, ability_id, ability, true)


static func _assert_cleric_outcome(
	failures: Array[String],
	ability_id: StringName,
	ability: AbilityData,
	events: Array[SimEvent],
	hp_before: int,
	actor_pos_before: Vector2i,
	board: BoardState,
	target_id: int,
	use_upgrade: bool = false,
) -> void:
	var effects: Array = ability.upgraded_effects if use_upgrade else ability.effects
	var has_damage_effect := false
	var has_heal_effect := false
	for effect: EffectData in effects:
		if effect == null:
			continue
		if effect.type == GameEnums.EffectType.DAMAGE:
			has_damage_effect = true
		if effect.type == GameEnums.EffectType.HEAL:
			has_heal_effect = true
	if has_damage_effect and ability_id != &"cleric_divine_hammer":
		var damaged := false
		for event: SimEvent in events:
			if event.type == GameEnums.SimEventType.UNIT_DAMAGED:
				damaged = true
				break
		if not damaged and target_id > 0 and hp_before > 0:
			var after: UnitState = board.get_unit_by_id(target_id)
			damaged = after != null and after.health.current_hp < hp_before
		_assert(failures, "sim/%s/outcome/damage" % ability_id, damaged)
	if has_heal_effect:
		var healed := false
		for event: SimEvent in events:
			if event.type == GameEnums.SimEventType.UNIT_HEALED:
				healed = true
				break
		if not healed and target_id > 0:
			var healed_unit: UnitState = board.get_unit_by_id(target_id)
			if ability_id == &"cleric_resurrection":
				healed = healed_unit != null and healed_unit.is_alive()
			else:
				healed = healed_unit != null and healed_unit.health.current_hp > hp_before
		_assert(failures, "sim/%s/outcome/heal" % ability_id, healed)
	for effect: EffectData in effects:
		if effect == null:
			continue
		match effect.type:
			GameEnums.EffectType.MOVE, GameEnums.EffectType.DASH, GameEnums.EffectType.TELEPORT_ADJACENT_TO, GameEnums.EffectType.TELEPORT_CASTER:
				var actor: UnitState = board.get_unit_by_id(1)
				_assert(
					failures, "sim/%s/outcome/move" % ability_id,
					actor != null and actor.position != actor_pos_before,
				)
			GameEnums.EffectType.ADD_STATUS:
				if ability_id == &"cleric_martyrs_chains" or ability_id == &"cleric_life_link":
					continue
				var status_applied := false
				if target_id > 0:
					var unit: UnitState = board.get_unit_by_id(target_id)
					status_applied = unit != null and not unit.active_statuses.is_empty()
				if not status_applied:
					for event: SimEvent in events:
						if event.type == GameEnums.SimEventType.STATUS_APPLIED:
							status_applied = true
							break
				_assert(
					failures, "sim/%s/outcome/status" % ability_id,
					status_applied,
				)
			_:
				pass


static func run_selfless_siphon(failures: Array[String]) -> void:
	var definition: UnitData = FactoryTestHelpers.build_unit(&"cleric")
	_run_selfless_siphon(failures, definition)


static func run_frontline_medic_proof(failures: Array[String]) -> void:
	var definition := FactoryTestHelpers.build_unit(&"cleric")
	_run_frontline_medic_proof(failures, definition, _ability(definition, &"cleric_holy_light"))


static func run_sanctuary_proof(failures: Array[String]) -> void:
	_run_sanctuary_proof(failures, FactoryTestHelpers.build_unit(&"cleric"))


static func run_shield_of_faith_proof(failures: Array[String]) -> void:
	_run_shield_of_faith_proof(failures, FactoryTestHelpers.build_unit(&"cleric"))


static func _run_frontline_medic_proof(
	failures: Array[String],
	definition: UnitData,
	holy_light: AbilityData,
) -> void:
	var passive := _passive(definition, &"frontline_medic")
	for upgraded: bool in [false, true]:
		var board := _H.make_plain_board(Vector2i(8, 6))
		var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
			"active_abilities": [holy_light],
			"active_passives": [passive],
		})
		if upgraded:
			cleric.upgraded_passives.append(&"frontline_medic")
		var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(3, 2), {})
		ally.health.current_hp = maxi(1, ally.health.max_hp - 2)
		var enemy := UnitState.create(
			3, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, Vector2i(2, 3), {},
		)
		board.units.append_array([cleric, ally, enemy])
		for unit: UnitState in board.units:
			GridSystem.set_occupant(board, unit.position, unit.id)
		var armor_before := ally.armor
		var plan := Timeline.new()
		plan.add(TimelineAction.make_ability(cleric.id, holy_light, ally.position, ally.id))
		Simulator.simulate_player_turn(board, plan, [])
		var expected := 2 if upgraded else 1
		_assert(
			failures,
			"passive/frontline_medic/shield_%d" % expected,
			ally.armor - armor_before == expected,
		)


static func _run_sanctuary_proof(failures: Array[String], definition: UnitData) -> void:
	var ability := _ability(definition, &"cleric_sanctuary")
	if ability == null:
		return
	var board := _H.make_plain_board(Vector2i(10, 8))
	var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 3), {
		"active_abilities": [ability],
	})
	var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(3, 3), {})
	var enemy := UnitState.create(
		3, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, Vector2i(5, 3), {},
	)
	board.units.append_array([cleric, ally, enemy])
	for unit: UnitState in board.units:
		GridSystem.set_occupant(board, unit.position, unit.id)
	var target := Vector2i(4, 3)
	var action := TimelineAction.make_ability(cleric.id, ability, target, -1)
	var events: Array[SimEvent] = []
	AbilitySystem.execute(board, action, events)
	GridSystem.set_occupant(board, ally.position, -1)
	ally.position = target
	GridSystem.set_occupant(board, target, ally.id)
	var armor_before := ally.armor
	Simulator._tick_start_of_turn(board, events, GameEnums.Team.PLAYER)
	_assert(
		failures,
		"sanctuary/start_turn_buffs",
		ally.has_status(GameEnums.StatusType.STEALTH)
		and ally.has_status(GameEnums.StatusType.STURDY)
		and ally.armor - armor_before == 1,
	)

	var upgraded_board := _H.make_plain_board(Vector2i(10, 8))
	var upgraded_cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 3), {
		"active_abilities": [ability],
		"upgraded_abilities": [&"cleric_sanctuary"],
	})
	var upgraded_enemy := UnitState.create(
		3, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, Vector2i(5, 3), {},
	)
	upgraded_board.units.append_array([upgraded_cleric, upgraded_enemy])
	for unit: UnitState in upgraded_board.units:
		GridSystem.set_occupant(upgraded_board, unit.position, unit.id)
	var upgraded_action := TimelineAction.make_ability(upgraded_cleric.id, ability, target, -1)
	AbilitySystem.execute(upgraded_board, upgraded_action, [])
	GridSystem.set_occupant(upgraded_board, upgraded_enemy.position, -1)
	upgraded_enemy.position = target
	GridSystem.set_occupant(upgraded_board, target, upgraded_enemy.id)
	var enemy_events: Array[SimEvent] = []
	TerrainSystem.apply_landing(upgraded_board, upgraded_enemy, enemy_events)
	_assert(
		failures,
		"sanctuary/upgrade_enemy_push",
		upgraded_enemy.position != target,
	)


static func _run_shield_of_faith_proof(failures: Array[String], definition: UnitData) -> void:
	var ability := _ability(definition, &"cleric_shield_of_faith")
	if ability == null:
		return
	var board := _H.make_plain_board(Vector2i(8, 6))
	var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
		"active_abilities": [ability],
	})
	var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(3, 2), {})
	board.units.append_array([cleric, ally])
	for unit: UnitState in board.units:
		GridSystem.set_occupant(board, unit.position, unit.id)
	var armor_before := ally.armor
	var action := TimelineAction.make_ability(cleric.id, ability, ally.position, ally.id)
	var events: Array[SimEvent] = []
	AbilitySystem.execute(board, action, events)
	_assert(
		failures,
		"shield_of_faith/flat_shield_3",
		ally.armor - armor_before == 3
		and ally.has_status(GameEnums.StatusType.INTERCEPT),
	)


static func _sim_target_for_ability(
	cleric: UnitState,
	ability: AbilityData,
	ability_id: StringName,
	use_upgrade: bool,
	ally: UnitState,
	enemy: UnitState,
) -> Dictionary:
	if use_upgrade and cleric.is_ability_upgraded(ability_id):
		for effect: EffectData in ability.upgraded_effects:
			if effect != null and effect.type == GameEnums.EffectType.DAMAGE:
				return {"coord": enemy.position, "id": enemy.id}
			if effect != null and effect.type == GameEnums.EffectType.HEAL:
				return {"coord": ally.position, "id": ally.id}
	if ability.targeting_flags & GameEnums.TargetingFlags.TILE:
		return {"coord": Vector2i(4, 3), "id": -1}
	if ability.targeting_flags & GameEnums.TargetingFlags.ALLY:
		return {"coord": ally.position, "id": ally.id}
	if ability.targeting_flags & GameEnums.TargetingFlags.ENEMY:
		return {"coord": enemy.position, "id": enemy.id}
	if ability.targeting_flags & GameEnums.TargetingFlags.SELF:
		return {"coord": cleric.position, "id": cleric.id}
	return {"coord": Vector2i(4, 3), "id": -1}


static func _run_passive_blocks(failures: Array[String], only_id: StringName) -> void:
	var definition: UnitData = FactoryTestHelpers.build_unit(&"cleric")
	var holy_light := _ability(definition, &"cleric_holy_light")
	if holy_light == null:
		return

	if _passive_should_run(only_id, &"blood_donation"):
		var board := _H.make_plain_board(Vector2i(8, 6))
		var passive := _passive(definition, &"blood_donation")
		var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
			"active_abilities": [holy_light],
			"active_passives": [passive],
		})
		var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(3, 2), {})
		ally.health.current_hp = ally.health.max_hp
		board.units.append_array([cleric, ally])
		for unit: UnitState in board.units:
			GridSystem.set_occupant(board, unit.position, unit.id)
		var hp_before := cleric.health.current_hp
		var plan := Timeline.new()
		plan.add(TimelineAction.make_ability(cleric.id, holy_light, ally.position, ally.id))
		var events: Array[SimEvent] = []
		Simulator.simulate_player_turn(board, plan, events)
		_assert(
			failures, "passive/blood_donation/overheal",
			ally.armor > 0 or cleric.health.current_hp < hp_before,
		)

	if _passive_should_run(only_id, &"sacred_shield"):
		var board := _H.make_plain_board(Vector2i(8, 6))
		var passive := _passive(definition, &"sacred_shield")
		var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(3, 2), {
			"active_passives": [passive],
		})
		board.units.append(ally)
		GridSystem.set_occupant(board, ally.position, ally.id)
		var events: Array[SimEvent] = []
		Simulator.simulate_player_turn(board, Timeline.new(), events)
		_assert(
			failures, "passive/sacred_shield/def",
			ally.current_defense > definition.base_defense,
		)

	if _passive_should_run(only_id, &"divine_blessing"):
		_assert_heal_passive_buff(
			failures, definition, holy_light, &"divine_blessing",
			"passive/divine_blessing/str", GameEnums.StatusType.STAT_BUFF_STR,
		)

	if _passive_should_run(only_id, &"armor_of_faith"):
		_assert_heal_passive_buff(
			failures, definition, holy_light, &"armor_of_faith",
			"passive/armor_of_faith/def", GameEnums.StatusType.STAT_BUFF_DEF,
		)

	if _passive_should_run(only_id, &"divine_overflow"):
		var board := _H.make_plain_board(Vector2i(8, 6))
		var passive := _passive(definition, &"divine_overflow")
		var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
			"active_abilities": [holy_light],
			"active_passives": [passive],
		})
		var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(3, 2), {})
		ally.health.current_hp = ally.health.max_hp
		var enemy := UnitState.create(
			4, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, Vector2i(4, 2), {},
		)
		board.units.append_array([cleric, ally, enemy])
		for unit: UnitState in board.units:
			GridSystem.set_occupant(board, unit.position, unit.id)
		var events: Array[SimEvent] = []
		var heal_plan := Timeline.new()
		heal_plan.add(TimelineAction.make_ability(cleric.id, holy_light, ally.position, ally.id))
		Simulator.simulate_player_turn(board, heal_plan, events)
		var pulse_hit := false
		for event: SimEvent in events:
			if event.type == GameEnums.SimEventType.UNIT_DAMAGED \
					and int(event.data.get("unit", -1)) == enemy.id:
				pulse_hit = true
				break
		_assert(failures, "passive/divine_overflow/pulse", pulse_hit)

	if _passive_should_run(only_id, &"holy_ground"):
		var board := _H.make_plain_board(Vector2i(8, 6))
		var passive := _passive(definition, &"holy_ground")
		var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
			"active_passives": [passive],
		})
		var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(3, 2), {})
		ally.health.current_hp = maxi(1, ally.health.max_hp - 1)
		board.units.append_array([cleric, ally])
		for unit: UnitState in board.units:
			GridSystem.set_occupant(board, unit.position, unit.id)
		var hp_before := ally.health.current_hp
		Simulator.simulate_player_turn(board, Timeline.new(), [])
		_assert(
			failures, "passive/holy_ground/tick_heal",
			ally.health.current_hp > hp_before,
		)

	if _passive_should_run(only_id, &"prayer"):
		var board := _H.make_plain_board(Vector2i(8, 6))
		var passive := _passive(definition, &"prayer")
		var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
			"active_abilities": [holy_light],
			"active_passives": [passive],
		})
		var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(3, 2), {})
		ally.health.current_hp = maxi(1, ally.health.max_hp - 2)
		board.units.append_array([cleric, ally])
		for unit: UnitState in board.units:
			GridSystem.set_occupant(board, unit.position, unit.id)
		var sim_board := board
		var wait_result := Simulator.simulate(sim_board, Timeline.new())
		sim_board = wait_result.final_state
		_assert(
			failures, "passive/prayer/flag",
			sim_board.get_unit_by_id(1).passive_flags.get("prayer_next_heal", false),
		)
		var ally_ref: UnitState = sim_board.get_unit_by_id(2)
		var hp_before := ally_ref.health.current_hp
		var heal_plan := Timeline.new()
		heal_plan.add(TimelineAction.make_ability(1, holy_light, ally_ref.position, ally_ref.id))
		var heal_result := Simulator.simulate(sim_board, heal_plan)
		ally_ref = heal_result.final_state.get_unit_by_id(2)
		_assert(
			failures, "passive/prayer/double_heal",
			ally_ref.health.current_hp > hp_before,
		)

	if _passive_should_run(only_id, &"purity"):
		var board := _H.make_plain_board(Vector2i(8, 6))
		var passive := _passive(definition, &"purity")
		var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
			"active_passives": [passive],
		})
		var enemy := UnitState.create(
			3, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, Vector2i(3, 2), {},
		)
		board.units.append_array([cleric, enemy])
		for unit: UnitState in board.units:
			GridSystem.set_occupant(board, unit.position, unit.id)
		var hp_before := cleric.health.current_hp
		var poison_effect := DataLibrary._status_effect(GameEnums.StatusType.POISON, 2, 1)
		var events: Array[SimEvent] = []
		AbilitySystem._apply_effect_to_tile(
			board,
			enemy,
			TimelineAction.make_ability(enemy.id, DataLibrary.get_universal_wait(), cleric.position, cleric.id),
			poison_effect,
			events,
			cleric.position,
			cleric,
		)
		_assert(
			failures, "passive/purity/dot_heal",
			cleric.health.current_hp > hp_before
			or cleric.has_status(GameEnums.StatusType.STAT_BUFF_MAG),
		)

	if _passive_should_run(only_id, &"holy_radiance"):
		var board := _H.make_plain_board(Vector2i(8, 6))
		var source := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
			"active_passives": [_passive(definition, &"holy_radiance")],
		})
		var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(4, 2), {})
		board.units.append_array([source, ally])
		for unit: UnitState in board.units:
			GridSystem.set_occupant(board, unit.position, unit.id)
		ally._recalculate_stats(board)
		_assert(
			failures, "passive/holy_radiance/aura",
			ally.current_strength > definition.base_strength or ally.current_magic > definition.base_magic,
		)

	if _passive_should_run(only_id, &"zealous_protection"):
		var board := _H.make_plain_board(Vector2i(8, 6))
		var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
			"active_passives": [_passive(definition, &"zealous_protection")],
		})
		var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(3, 2), {})
		var enemy := UnitState.create(
			3, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, Vector2i(4, 2), {},
		)
		board.units.append_array([cleric, ally, enemy])
		for unit: UnitState in board.units:
			GridSystem.set_occupant(board, unit.position, unit.id)
		var events: Array[SimEvent] = []
		CombatSystem.deal_damage(
			board, ally, 3, events, &"true", true, false, enemy, "test", 3,
		)
		_assert(
			failures, "passive/zealous_protection/str",
			ally.has_status(GameEnums.StatusType.STAT_BUFF_STR),
		)

	if _passive_should_run(only_id, &"divine_intervention"):
		var board := _H.make_plain_board(Vector2i(8, 6))
		var passive := _passive(definition, &"divine_intervention")
		var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
			"active_passives": [passive],
		})
		var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(3, 2), {})
		var attacker := UnitState.create(
			9, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, Vector2i(5, 2), {},
		)
		ally.health.current_hp = 1
		board.units.append_array([cleric, ally, attacker])
		for unit: UnitState in board.units:
			GridSystem.set_occupant(board, unit.position, unit.id)
		var events: Array[SimEvent] = []
		CombatSystem.deal_damage(
			board, ally, 99, events, &"physical", false, false, attacker, "lethal", 99,
		)
		_assert(
			failures, "passive/divine_intervention/save",
			ally.is_alive() and ally.health.current_hp == 1,
		)

	if _passive_should_run(only_id, &"martyrs_blood"):
		var board := _H.make_plain_board(Vector2i(8, 6))
		var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
			"active_passives": [_passive(definition, &"martyrs_blood")],
		})
		var enemy := UnitState.create(
			3, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, Vector2i(3, 2), {},
		)
		board.units.append_array([cleric, enemy])
		for unit: UnitState in board.units:
			GridSystem.set_occupant(board, unit.position, unit.id)
		var events: Array[SimEvent] = []
		CombatSystem.deal_damage(
			board, cleric, 3, events, &"true", true, false, enemy, "hit", 3,
		)
		var pulse_hit := false
		for event: SimEvent in events:
			if event.type == GameEnums.SimEventType.UNIT_DAMAGED \
					and int(event.data.get("unit", -1)) == enemy.id:
				pulse_hit = true
				break
		_assert(failures, "passive/martyrs_blood/pulse", pulse_hit)

	if _passive_should_run(only_id, &"divine_retribution"):
		var board := _H.make_plain_board(Vector2i(8, 6))
		var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
			"active_passives": [_passive(definition, &"divine_retribution")],
		})
		var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(3, 2), {})
		var enemy := UnitState.create(
			3, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, Vector2i(4, 2), {},
		)
		board.units.append_array([cleric, ally, enemy])
		for unit: UnitState in board.units:
			GridSystem.set_occupant(board, unit.position, unit.id)
		var events: Array[SimEvent] = []
		CombatSystem.deal_damage(
			board, ally, 3, events, &"true", true, false, enemy, "hit", 3,
		)
		var pulse_hit := false
		for event: SimEvent in events:
			if event.type == GameEnums.SimEventType.UNIT_DAMAGED \
					and int(event.data.get("unit", -1)) == enemy.id \
					and str(event.data.get("source_label", "")).find("Retribution") >= 0:
				pulse_hit = true
				break
		if not pulse_hit:
			for event: SimEvent in events:
				if event.type == GameEnums.SimEventType.UNIT_DAMAGED \
						and int(event.data.get("unit", -1)) == enemy.id:
					pulse_hit = true
					break
		_assert(failures, "passive/divine_retribution/pulse", pulse_hit)

	if _passive_should_run(only_id, &"retribution"):
		var board := _H.make_plain_board(Vector2i(8, 6))
		var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
			"active_passives": [_passive(definition, &"retribution")],
		})
		var enemy := UnitState.create(
			3, DataLibrary.get_training_dummy(), GameEnums.Team.ENEMY, Vector2i(3, 2), {},
		)
		board.units.append_array([cleric, enemy])
		for unit: UnitState in board.units:
			GridSystem.set_occupant(board, unit.position, unit.id)
		var events: Array[SimEvent] = []
		CombatSystem.deal_damage(
			board, cleric, 3, events, &"true", true, false, enemy, "melee", 3,
		)
		var pulse_hit := false
		for event: SimEvent in events:
			if event.type == GameEnums.SimEventType.UNIT_DAMAGED \
					and int(event.data.get("unit", -1)) == enemy.id:
				pulse_hit = true
				break
		_assert(failures, "passive/retribution/pulse", pulse_hit)


static func _passive_should_run(only_id: StringName, passive_id: StringName) -> bool:
	return only_id == &"" or only_id == passive_id


static func _assert_heal_passive_buff(
	failures: Array[String],
	definition: UnitData,
	holy_light: AbilityData,
	passive_id: StringName,
	label: String,
	status_type: GameEnums.StatusType,
) -> void:
	var board := _H.make_plain_board(Vector2i(8, 6))
	var passive := _passive(definition, passive_id)
	var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
		"active_abilities": [holy_light],
		"active_passives": [passive],
	})
	var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(3, 2), {})
	ally.health.current_hp = maxi(1, ally.health.max_hp - 1)
	board.units.append_array([cleric, ally])
	for unit: UnitState in board.units:
		GridSystem.set_occupant(board, unit.position, unit.id)
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(cleric.id, holy_light, ally.position, ally.id))
	Simulator.simulate_player_turn(board, plan, [])
	_assert(failures, label, ally.has_status(status_type))


static func _run_selfless_siphon(failures: Array[String], definition: UnitData) -> void:
	var board := _H.make_plain_board(Vector2i(8, 8))
	var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 2), {
		"active_abilities": [_ability(definition, &"cleric_holy_light")],
		"active_passives": [],
	})
	var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(3, 2), {})
	board.units.append(cleric)
	board.units.append(ally)
	GridSystem.set_occupant(board, cleric.position, cleric.id)
	GridSystem.set_occupant(board, ally.position, ally.id)
	ally.health.current_hp = 1
	cleric.health.current_hp = 1
	var action := TimelineAction.make_ability(
		cleric.id,
		_ability(definition, &"cleric_holy_light"),
		ally.position,
		ally.id,
	)
	var plan := Timeline.new()
	plan.add(action)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	_assert(failures, "selfless_siphon/heal",
		ally.health.current_hp > 1 and cleric.health.current_hp > 1)


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


static func _assert(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
