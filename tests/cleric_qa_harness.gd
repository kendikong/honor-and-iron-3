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
