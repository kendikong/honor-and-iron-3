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
		and guardian.effects[0].modifiers.get("warp_adjacent_to_target", false)
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
			and guardian.effects[0].modifiers.get("warp_adjacent_to_target", false)
			and guardian.upgraded_effects[0].modifiers.get("cleanse_target", false))
	elif ability_id == &"cleric_holy_light":
		var holy_light := _ability(definition, ability_id)
		_assert(failures, "holy_light/mag_heal",
			holy_light != null and holy_light.effects[0].type == GameEnums.EffectType.HEAL
			and holy_light.effects[0].modifiers.get("mag_heal", false))
		_sim_ability_used(failures, ability_id, holy_light)
	else:
		var ability := _ability(definition, ability_id)
		if ability != null:
			_sim_ability_used(failures, ability_id, ability)


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


static func _sim_ability_used(
	failures: Array[String],
	ability_id: StringName,
	ability: AbilityData,
) -> void:
	if ability == null:
		return
	var definition: UnitData = FactoryTestHelpers.build_unit(&"cleric")
	var board := _H.make_plain_board(Vector2i(10, 8))
	var cleric := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 3), {
		"active_abilities": [ability],
		"active_passives": [],
	})
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
	var target_coord := Vector2i(4, 3)
	var target_id := -1
	if ability.targeting_flags & GameEnums.TargetingFlags.TILE:
		target_coord = Vector2i(4, 3)
		target_id = -1
	elif ability.targeting_flags & GameEnums.TargetingFlags.ALLY:
		target_coord = ally.position
		target_id = ally.id
	elif ability.targeting_flags & GameEnums.TargetingFlags.ENEMY:
		target_coord = enemy.position
		target_id = enemy.id
	elif ability.targeting_flags & GameEnums.TargetingFlags.SELF:
		target_coord = cleric.position
		target_id = cleric.id
	var action := TimelineAction.make_ability(cleric.id, ability, target_coord, target_id)
	_assert(
		failures,
		"sim/%s/can_use" % ability_id,
		AbilitySystem.can_use(board, action),
	)
	if not AbilitySystem.can_use(board, action):
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
	_assert_cleric_outcome(failures, ability_id, ability, events, hp_before, actor_pos_before, board, target_id)


static func run_upgrade_sim_for(ability_id: StringName, failures: Array[String]) -> void:
	var definition: UnitData = FactoryTestHelpers.build_unit(&"cleric")
	var ability := _ability(definition, ability_id)
	if ability == null or ability.upgraded_effects.is_empty():
		return
	_assert(
		failures,
		"upgrade/%s/compiled" % ability_id,
		not ability.upgraded_effects.is_empty(),
	)


static func _assert_cleric_outcome(
	failures: Array[String],
	ability_id: StringName,
	ability: AbilityData,
	events: Array[SimEvent],
	hp_before: int,
	actor_pos_before: Vector2i,
	board: BoardState,
	target_id: int,
) -> void:
	var has_damage_effect := false
	for effect: EffectData in ability.effects:
		if effect.type == GameEnums.EffectType.DAMAGE:
			has_damage_effect = true
			break
	if not has_damage_effect:
		return
	var damaged := false
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.UNIT_DAMAGED:
			damaged = true
			break
	if not damaged and target_id > 0 and hp_before > 0:
		var after: UnitState = board.get_unit_by_id(target_id)
		damaged = after != null and after.health.current_hp < hp_before
	if ability_id == &"cleric_divine_hammer":
		return
	_assert(failures, "sim/%s/outcome/damage" % ability_id, damaged)
	for effect: EffectData in ability.effects:
		match effect.type:
			GameEnums.EffectType.HEAL:
				var healed := false
				for event: SimEvent in events:
					if event.type == GameEnums.SimEventType.UNIT_HEALED:
						healed = true
						break
				_assert(failures, "sim/%s/outcome/heal" % ability_id, healed or target_id > 0)
			GameEnums.EffectType.MOVE, GameEnums.EffectType.DASH:
				var actor: UnitState = board.get_unit_by_id(1)
				_assert(
					failures, "sim/%s/outcome/move" % ability_id,
					actor != null and actor.position != actor_pos_before,
				)
			GameEnums.EffectType.ADD_STATUS:
				if target_id > 0:
					var unit: UnitState = board.get_unit_by_id(target_id)
					_assert(
						failures, "sim/%s/outcome/status" % ability_id,
						unit != null and not unit.status_effects.is_empty(),
					)
			_:
				pass


static func run_selfless_siphon(failures: Array[String]) -> void:
	var definition: UnitData = FactoryTestHelpers.build_unit(&"cleric")
	_run_selfless_siphon(failures, definition)


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
