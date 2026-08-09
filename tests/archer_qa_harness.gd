class_name ArcherQaHarness
extends RefCounted

## Archer gate: every Bible skill resolves through Simulator and every passive
## has a data contract plus a shared-system smoke.

const ARCHER_ID: StringName = &"archer"

static func assert_true(
	failures: Array[String],
	tag: String,
	condition: bool,
	message: String = "assertion failed",
) -> void:
	if not condition:
		failures.append("%s: %s" % [tag, message])


static func archer_unit_data() -> UnitData:
	return FactoryTestHelpers.build_unit(ARCHER_ID)


static func factory_ability(ability_id: StringName) -> AbilityData:
	var definition := archer_unit_data()
	if definition == null:
		return null
	for ability: AbilityData in definition.abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


static func factory_passive(passive_id: StringName) -> PassiveData:
	var definition := archer_unit_data()
	if definition == null:
		return null
	for passive: PassiveData in definition.innate_passives + definition.passives:
		if passive != null and passive.id == passive_id:
			return passive
	return null


static func run_data_contract(failures: Array[String]) -> void:
	var definition := archer_unit_data()
	assert_true(failures, "archer/factory", definition != null, "Archer factory must be registered")
	if definition == null:
		return
	assert_true(failures, "archer/name", definition.display_name == "Archer")
	assert_true(failures, "archer/stats", definition.base_constitution == 3
		and definition.move_points == 4
		and definition.base_strength == 4
		and definition.base_defense == 1
		and definition.base_magic == 1)
	assert_true(failures, "archer/skills", definition.abilities.size() == 16)
	assert_true(failures, "archer/innate", definition.innate_passives.size() == 1)
	assert_true(failures, "archer/passives", definition.passives.size() == 15)

	var expected_skills: Dictionary = {
		&"archer_power_shot": [GameEnums.EffectType.DAMAGE, 3, 5, GameEnums.TargetShape.SINGLE],
		&"archer_volley": [GameEnums.EffectType.DAMAGE, 1, 4, GameEnums.TargetShape.AOE_SQUARE],
		&"archer_pinning_arrow": [GameEnums.EffectType.DAMAGE, 1, 4, GameEnums.TargetShape.SINGLE],
		&"archer_piercing_shot": [GameEnums.EffectType.DAMAGE, 2, 4, GameEnums.TargetShape.LINE],
		&"archer_toxic_spore_arrow": [GameEnums.EffectType.DAMAGE, 1, 5, GameEnums.TargetShape.SINGLE],
		&"archer_grapple_arrow": [GameEnums.EffectType.PULL, 1, 4, GameEnums.TargetShape.SINGLE],
		&"archer_explosive_arrow": [GameEnums.EffectType.DAMAGE, 2, 4, GameEnums.TargetShape.AOE_CROSS],
		&"archer_hunters_mark": [GameEnums.EffectType.ADD_STATUS, 1, 5, GameEnums.TargetShape.SINGLE],
		&"archer_repelling_shot": [GameEnums.EffectType.DAMAGE, 1, 2, GameEnums.TargetShape.SINGLE],
		&"archer_bear_trap": [GameEnums.EffectType.CREATE_HAZARD, 3, 3, GameEnums.TargetShape.SINGLE],
		&"archer_suppressing_fire": [GameEnums.EffectType.CREATE_HAZARD, 1, 5, GameEnums.TargetShape.ARC],
		&"archer_caltrop_trap": [GameEnums.EffectType.CREATE_HAZARD, 1, 3, GameEnums.TargetShape.SINGLE],
		&"archer_parting_shot": [GameEnums.EffectType.DAMAGE, 2, 3, GameEnums.TargetShape.SINGLE],
		&"archer_scouts_eye": [GameEnums.EffectType.PURGE, 0, 5, GameEnums.TargetShape.SINGLE],
	}
	for ability_id: StringName in expected_skills:
		var ability := factory_ability(ability_id)
		var expected: Array = expected_skills[ability_id]
		assert_true(failures, "%s/registered" % ability_id, ability != null)
		if ability == null:
			continue
		assert_true(
			failures,
			"%s/modular" % ability_id,
			not ability.modules.is_empty() and not ability.upgraded_modules.is_empty(),
			"both Bible profiles must be modular",
		)
		assert_true(
			failures,
			"%s/compiled" % ability_id,
			not ability.effects.is_empty() and not ability.upgraded_effects.is_empty(),
			"both profiles must compile through AbilityModuleBridge",
		)
		assert_true(
			failures,
			"%s/primary" % ability_id,
			ability.effects[0].type == expected[0]
			and ability.effects[0].amount == int(expected[1])
			and ability.range_tiles == int(expected[2])
			and ability.target_shape == expected[3],
		)
		assert_true(
			failures,
			"%s/upgrade" % ability_id,
			not ability.upgrade_description.is_empty(),
			"every Bible [+] row needs an upgrade contract",
		)

	var expected_passives: Array[StringName] = [
		&"lightfoot", &"overwatch", &"high_ground", &"patient_hunter", &"true_sight",
		&"piercing_momentum", &"camouflage", &"area_denial", &"caltrop_expert",
		&"zone_control", &"sticky_mud", &"fletching_hoarder", &"prey_sighted",
		&"barrage", &"target_painter", &"rapid_fire",
	]
	for passive_id: StringName in expected_passives:
		var passive := factory_passive(passive_id)
		assert_true(failures, "%s/registered" % passive_id, passive != null)
		if passive != null:
			assert_true(
				failures,
				"%s/descriptions" % passive_id,
				not passive.description.is_empty() and not passive.upgraded_description.is_empty(),
			)
			assert_true(
				failures,
				"%s/modifiers" % passive_id,
				not passive.modifiers.is_empty(),
				"passive behavior must be data-authored",
			)


static func run_shape_contract_smoke(failures: Array[String]) -> void:
	var volley := factory_ability(&"archer_volley")
	var explosive := factory_ability(&"archer_explosive_arrow")
	var suppressing := factory_ability(&"archer_suppressing_fire")
	assert_true(
		failures,
		"shape/volley",
		volley != null
		and volley.target_shape == GameEnums.TargetShape.AOE_SQUARE
		and volley.target_shape_size == 1,
		"Volley must be the authored 3x3 square",
	)
	assert_true(
		failures,
		"shape/explosive",
		explosive != null
		and explosive.target_shape == GameEnums.TargetShape.AOE_CROSS
		and explosive.target_shape_size == 1,
		"AOE 1 must be the shared cardinal cross",
	)
	assert_true(
		failures,
		"shape/suppressing",
		suppressing != null
		and suppressing.target_shape == GameEnums.TargetShape.ARC,
		"Suppressing Fire must use the shared ARC geometry",
	)
	var center := Vector2i(4, 4)
	var square := GridSystem.get_affected_tiles(
		null, center, center, GameEnums.TargetShape.AOE_SQUARE, 1,
	)
	assert_true(failures, "shape/square_footprint", square.size() == 9)
	var cross := GridSystem.get_affected_tiles(
		null, center, center, GameEnums.TargetShape.AOE_CROSS, 1,
	)
	assert_true(
		failures,
		"shape/cross_footprint",
		cross.size() == 5
		and cross.has(center + Vector2i(0, -1))
		and not cross.has(center + Vector2i(1, 1)),
	)
	var arc := GridSystem.get_affected_tiles(
		null, center, center + Vector2i(2, 0), GameEnums.TargetShape.ARC, 1,
	)
	assert_true(
		failures,
		"shape/arc_footprint",
		arc.size() == 3
		and arc.has(center + Vector2i(2, -1))
		and arc.has(center + Vector2i(2, 1)),
	)


static func run_active_execution_matrix(failures: Array[String]) -> void:
	var skill_ids: Array[StringName] = [
		&"archer_power_shot", &"archer_volley", &"archer_pinning_arrow",
		&"archer_piercing_shot", &"archer_toxic_spore_arrow", &"archer_grapple_arrow",
		&"archer_explosive_arrow", &"archer_hunters_mark", &"archer_repelling_shot",
		&"archer_bear_trap", &"archer_suppressing_fire", &"archer_caltrop_trap",
		&"archer_parting_shot", &"archer_scouts_eye",
	]
	for skill_id: StringName in skill_ids:
		var result := _simulate_active_skill(skill_id)
		assert_true(
			failures,
			"%s/ability_used" % skill_id,
			bool(result.get("used", false)),
			"skill must resolve through Simulator",
		)
		assert_true(
			failures,
			"%s/no_action_failure" % skill_id,
			not bool(result.get("failed", false)),
			"Bible-valid target must not fail (%s)" % result.get("reason", ""),
		)


static func _simulate_active_skill(skill_id: StringName) -> Dictionary:
	var definition := archer_unit_data()
	var ability := factory_ability(skill_id)
	var board := _plain_board(Vector2i(12, 8))
	var actor := _make_unit(definition, 1, GameEnums.Team.PLAYER, Vector2i(2, 3), [ability], [])
	var enemy := _make_unit(definition, 2, GameEnums.Team.ENEMY, Vector2i(5, 3), [], [])
	var ally := _make_unit(definition, 3, GameEnums.Team.PLAYER, Vector2i(4, 4), [], [])
	var target_coord := enemy.position
	var target_id := enemy.id
	if skill_id in [
		&"archer_volley", &"archer_explosive_arrow", &"archer_bear_trap",
		&"archer_suppressing_fire", &"archer_caltrop_trap",
	]:
		target_coord = Vector2i(4, 3)
		target_id = -1
	if skill_id == &"archer_grapple_arrow":
		board.set_tile_terrain(Vector2i(5, 3), DataLibrary.get_terrain(&"wall"))
		target_coord = Vector2i(5, 3)
		target_id = -1
	if skill_id == &"archer_repelling_shot":
		target_coord = ally.position
		target_id = ally.id
		actor.position = Vector2i(2, 4)
		enemy.position = Vector2i(5, 4)
	if skill_id == &"archer_piercing_shot":
		enemy.position = Vector2i(5, 3)
	if skill_id == &"archer_suppressing_fire":
		target_coord = Vector2i(5, 3)
	_add_units(board, [actor, enemy, ally])
	var action := TimelineAction.make_ability(actor.id, ability, target_coord, target_id)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, _single_action_plan(action), events)
	var used := false
	var failed := false
	var reason := ""
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ABILITY_USED and event.data.get("ability") == skill_id:
			used = true
		if event.type == GameEnums.SimEventType.ACTION_FAILED:
			failed = true
			reason = String(event.data.get("reason", "unknown"))
	return {"used": used, "failed": failed, "reason": reason}


static func run_passive_runtime_smoke(failures: Array[String]) -> void:
	var definition := archer_unit_data()
	var basic := DataLibrary._make_class_basic_attack(&"archer")
	var board := _plain_board(Vector2i(10, 6))
	board.set_tile_terrain(Vector2i(2, 2), DataLibrary.get_terrain(&"trampled"))
	var steady_aim := _make_unit(
		definition, 1, GameEnums.Team.PLAYER, Vector2i(1, 2), [basic],
		[factory_passive(&"lightfoot")],
	)
	assert_true(
		failures,
		"passive/steady_aim",
		steady_aim.get_ability_range(basic) == 2,
		"Steady Aim must extend attacks while no movement is spent",
	)

	var patient_board := _plain_board(Vector2i(8, 4))
	var patient := _make_unit(
		definition, 1, GameEnums.Team.PLAYER, Vector2i(1, 1), [basic],
		[factory_passive(&"patient_hunter")],
	)
	var patient_target := _make_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(3, 1), [], [],
	)
	_add_units(patient_board, [patient, patient_target])
	var patient_events: Array[SimEvent] = []
	AbilitySystem.execute(
		patient_board,
		TimelineAction.make_ability(patient.id, basic, patient_target.position, patient_target.id),
		patient_events,
	)
	assert_true(
		failures,
		"passive/vantage_anchor",
		patient.has_status(GameEnums.StatusType.STURDY)
		and patient.has_status(GameEnums.StatusType.STEALTH),
		"Vantage Anchor must grant STURDY and STEALTH after Steady Aim triggers",
	)

	var zone_board := _plain_board(Vector2i(8, 4))
	var zone := _make_unit(
		definition, 1, GameEnums.Team.PLAYER, Vector2i(2, 1), [basic],
		[factory_passive(&"zone_control")],
	)
	var zone_enemy := _make_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(6, 1), [], [],
	)
	_add_units(zone_board, [zone, zone_enemy])
	var zone_plan := Timeline.new()
	zone_plan.add(TimelineAction.make_move(zone_enemy.id, Vector2i(4, 1)))
	var zone_events: Array[SimEvent] = []
	Simulator.simulate_player_turn(zone_board, zone_plan, zone_events)
	assert_true(
		failures,
		"passive/zone_control",
		_events_have_unit_damage(zone_events, zone_enemy.id),
		"enemy entering RANGE 3 must trigger unmitigated damage",
	)


static func _first_telemetry(events: Array[SimEvent]) -> Dictionary:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.MATH_TELEMETRY:
			return event.data
	return {}


static func _events_have_unit_damage(events: Array[SimEvent], unit_id: int) -> bool:
	for event: SimEvent in events:
		if (
			event.type == GameEnums.SimEventType.UNIT_DAMAGED
			and int(event.data.get("unit", -1)) == unit_id
			and int(event.data.get("amount", 0)) > 0
		):
			return true
	return false


static func _make_unit(
	definition: UnitData,
	unit_id: int,
	team: GameEnums.Team,
	position: Vector2i,
	abilities: Array,
	passives: Array,
) -> UnitState:
	return UnitState.create(unit_id, definition, team, position, {
		"active_abilities": abilities,
		"active_passives": passives,
	})


static func _add_units(board: BoardState, units: Array) -> void:
	board.units = []
	for unit: UnitState in units:
		board.units.append(unit)
		GridSystem.set_occupant(board, unit.position, unit.id)


static func _single_action_plan(action: TimelineAction) -> Timeline:
	var plan := Timeline.new()
	plan.add(action)
	return plan


static func _plain_board(size: Vector2i) -> BoardState:
	var board := BoardState.new()
	board.grid_size = size
	var plain := DataLibrary.get_terrain(&"plain")
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	return board
