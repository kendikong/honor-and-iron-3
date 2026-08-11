class_name LancerQaHarness
extends RefCounted

## Lancer class gate: modular factory contract plus one shared-simulator smoke.
## Every Bible row is represented in the registry; this harness verifies the
## authored module source and the compiled bridge output without UI shortcuts.

const LANCER_ID: StringName = &"lancer"

static func assert_fail(failures: Array[String], tag: String, message: String) -> void:
	failures.append("%s: %s" % [tag, message])

static func assert_true(
	failures: Array[String],
	tag: String,
	condition: bool,
	message: String = "assertion failed",
) -> void:
	if not condition:
		assert_fail(failures, tag, message)

static func assert_eq_int(failures: Array[String], tag: String, got: int, expected: int) -> void:
	if got != expected:
		assert_fail(failures, tag, "expected %d got %d" % [expected, got])

static func lancer_unit_data() -> UnitData:
	return FactoryTestHelpers.build_unit(LANCER_ID)

static func factory_ability(ability_id: StringName) -> AbilityData:
	var definition := lancer_unit_data()
	if definition == null:
		return null
	for ability: AbilityData in definition.abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null

static func factory_passive(passive_id: StringName) -> PassiveData:
	var definition := lancer_unit_data()
	if definition == null:
		return null
	for passive: PassiveData in definition.innate_passives + definition.passives:
		if passive != null and passive.id == passive_id:
			return passive
	return null

static func run_data_contract(failures: Array[String]) -> void:
	var definition := lancer_unit_data()
	assert_true(failures, "lancer/factory", definition != null, "Lancer factory must be registered")
	if definition == null:
		return
	assert_true(failures, "lancer/name", definition.display_name == "Lancer")
	assert_eq_int(failures, "lancer/constitution", definition.base_constitution, 5)
	assert_eq_int(failures, "lancer/movement", definition.move_points, 3)
	assert_eq_int(failures, "lancer/strength", definition.base_strength, 4)
	assert_eq_int(failures, "lancer/defense", definition.base_defense, 3)
	assert_eq_int(failures, "lancer/magic", definition.base_magic, 1)
	assert_eq_int(failures, "lancer/skills", definition.abilities.size(), 15)
	assert_eq_int(failures, "lancer/innate", definition.innate_passives.size(), 1)
	assert_eq_int(failures, "lancer/passives", definition.passives.size(), 15)

	var expected_skills: Dictionary = {
		&"lancer_push": [GameEnums.EffectType.PUSH, 1],
		&"lancer_piercing_charge": [GameEnums.EffectType.DASH, 3],
		&"lancer_sweeping_halberd": [GameEnums.EffectType.DAMAGE, 2],
		&"lancer_vaulting_leap": [GameEnums.EffectType.DAMAGE, 2],
		&"lancer_run_down": [GameEnums.EffectType.DAMAGE, 3],
		&"lancer_rallying_cry": [GameEnums.EffectType.ADD_STATUS, 1],
		&"lancer_flanking_maneuver": [GameEnums.EffectType.MOVE, 2],
		&"lancer_brace": [GameEnums.EffectType.ADD_STATUS_SELF, 2],
		&"lancer_harpoon_toss": [GameEnums.EffectType.DAMAGE, 1],
		&"lancer_glorious_charge": [GameEnums.EffectType.DASH, 4],
		&"lancer_pole_vault": [GameEnums.EffectType.TELEPORT_CASTER, 3],
		&"lancer_line_breaker": [GameEnums.EffectType.DASH, 4],
		&"lancer_spear_wall": [GameEnums.EffectType.CREATE_HAZARD, 2],
		&"lancer_meteor_drop": [GameEnums.EffectType.TELEPORT_CASTER, 2],
	}
	for ability_id: StringName in expected_skills:
		var ability := factory_ability(ability_id)
		assert_true(failures, "%s/registered" % ability_id, ability != null)
		if ability == null:
			continue
		var expected: Array = expected_skills[ability_id]
		assert_true(
			failures, "%s/modular" % ability_id,
			not ability.modules.is_empty() and not ability.upgraded_modules.is_empty(),
			"base and [+] must be authored as AbilityModule lists",
		)
		assert_true(
			failures, "%s/compiled" % ability_id,
			not ability.effects.is_empty() and not ability.upgraded_effects.is_empty(),
			"module bridge must compile both profiles",
		)
		assert_true(
			failures, "%s/primary" % ability_id,
			ability.effects[0].type == expected[0] and ability.effects[0].amount == int(expected[1]),
			"compiled primary effect does not match Bible",
		)
		assert_true(
			failures, "%s/upgrade_description" % ability_id,
			not ability.upgrade_description.is_empty(),
			"every Bible [+] row needs an upgrade description",
		)

	var expected_passives: Array[StringName] = [
		&"kinetic_charge", &"unstoppable_mass", &"canto", &"frontline_defense",
		&"flanking_strike", &"plunging_attack", &"crashing_impact", &"pole_plant",
		&"spear_drop", &"springboard", &"sweet_spot", &"reach_advantage",
		&"disengage", &"zone_of_control", &"leverage",
	]
	for passive_id: StringName in expected_passives:
		var passive := factory_passive(passive_id)
		assert_true(failures, "%s/registered" % passive_id, passive != null)
		if passive != null:
			assert_true(
				failures, "%s/promotion" % passive_id,
				passive.modifiers.has("promotion"),
				"promotion ownership must remain data, not a simulation branch",
			)


static func run_sweeping_halberd_footprint(failures: Array[String]) -> void:
	var sweep := factory_ability(&"lancer_sweeping_halberd")
	assert_true(failures, "sweeping_halberd/registered", sweep != null)
	if sweep == null:
		return
	var board := _plain_board(Vector2i(10, 8))
	var origin := Vector2i(2, 3)
	var target := Vector2i(5, 3)
	var footprint: Array[Vector2i] = GridSystem.get_affected_tiles(
		board, origin, target, GameEnums.TargetShape.ARC, sweep.target_shape_size,
	)
	assert_true(failures, "sweeping_halberd/footprint_in", footprint.has(target))
	assert_true(failures, "sweeping_halberd/footprint_excludes_far", not footprint.has(Vector2i(8, 3)))


static func run_shape_contract_smoke(failures: Array[String]) -> void:
	var rally := factory_ability(&"lancer_rallying_cry")
	var sweep := factory_ability(&"lancer_sweeping_halberd")
	var meteor := factory_ability(&"lancer_meteor_drop")
	var spear_wall := factory_ability(&"lancer_spear_wall")
	assert_true(
		failures,
		"shape/rally",
		rally != null
		and rally.target_shape == GameEnums.TargetShape.AOE_CROSS
		and rally.target_shape_size == 2,
		"Bible AOE 2 must be a two-tile cross",
	)
	assert_true(
		failures,
		"shape/meteor",
		meteor != null
		and meteor.target_shape == GameEnums.TargetShape.AOE_CROSS
		and meteor.target_shape_size == 1,
		"adjacent landing damage must use the cardinal cross",
	)
	assert_true(
		failures,
		"shape/arc_data",
		sweep != null
		and sweep.target_shape == GameEnums.TargetShape.ARC
		and spear_wall != null
		and spear_wall.target_shape == GameEnums.TargetShape.ARC,
		"ARC abilities must retain the shared ARC shape",
	)

	var center := Vector2i(4, 4)
	var cross := GridSystem.get_affected_tiles(
		null, center, center, GameEnums.TargetShape.AOE_CROSS, 2,
	)
	assert_eq_int(failures, "shape/cross_size", cross.size(), 9)
	assert_true(
		failures,
		"shape/cross_footprint",
		cross.has(center + Vector2i(0, -2))
		and cross.has(center + Vector2i(0, 2))
		and cross.has(center + Vector2i(-2, 0))
		and cross.has(center + Vector2i(2, 0))
		and not cross.has(center + Vector2i(1, 1)),
		"AOE X must expand cardinally, not diagonally",
	)

	var horizontal_arc := GridSystem.get_affected_tiles(
		null, center, center + Vector2i(2, 0), GameEnums.TargetShape.ARC, 1,
	)
	assert_eq_int(failures, "shape/arc_horizontal_size", horizontal_arc.size(), 3)
	assert_true(
		failures,
		"shape/arc_horizontal_footprint",
		horizontal_arc.has(center + Vector2i(2, 0))
		and horizontal_arc.has(center + Vector2i(2, -1))
		and horizontal_arc.has(center + Vector2i(2, 1)),
		"horizontal ARC must be perpendicular to attack direction",
	)

	var vertical_arc := GridSystem.get_affected_tiles(
		null, center, center + Vector2i(0, 2), GameEnums.TargetShape.ARC, 1,
	)
	assert_true(
		failures,
		"shape/arc_vertical_footprint",
		vertical_arc.has(center + Vector2i(0, 2))
		and vertical_arc.has(center + Vector2i(-1, 2))
		and vertical_arc.has(center + Vector2i(1, 2)),
		"vertical ARC must be perpendicular to attack direction",
	)


static func run_push_smoke(failures: Array[String]) -> void:
	var definition := lancer_unit_data()
	if definition == null:
		return
	var polearm := factory_passive(&"polearm_mastery")
	assert_true(
		failures,
		"polearm_mastery/innate",
		polearm != null and _has_passive_id(definition.innate_passives, polearm.id),
		"Polearm Mastery must be an always-active innate trait",
	)
	var push := factory_ability(&"lancer_push")
	var board := _plain_board(Vector2i(6, 4))
	var actor := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(1, 1), {
		"active_abilities": [push],
		"active_passives": [],
	})
	var ally := UnitState.create(2, definition, GameEnums.Team.PLAYER, Vector2i(2, 1), {
		"active_abilities": [],
		"active_passives": [],
	})
	board.units = [actor, ally]
	GridSystem.set_occupant(board, actor.position, actor.id)
	GridSystem.set_occupant(board, ally.position, ally.id)
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(actor.id, push, ally.position, ally.id))
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	assert_true(
		failures, "lancer_push/sim",
		ally.position == Vector2i(3, 1),
		"Push must resolve through PhysicsSystem after the modular ability compiles",
	)


static func run_polearm_reach_smoke(failures: Array[String]) -> void:
	var basic := factory_ability(&"lancer_basic")
	assert_true(failures, "polearm_mastery/basic_registered", basic != null)
	if basic == null:
		return
	assert_eq_int(failures, "polearm_mastery/basic_range", basic.range_tiles, 2)
	assert_true(
		failures,
		"polearm_mastery/basic_modifier",
		is_equal_approx(
			float(basic.effects[0].modifiers.get("range_one_damage_multiplier", 0.0)),
			0.7,
		),
		"basic Lance must carry the 30% Range 1 penalty",
	)

	var definition := lancer_unit_data()
	if definition == null:
		return
	for ability: AbilityData in definition.abilities:
		if ability == null or not ability.tags.has(AbilityModuleBridge.TAG_ATTACK):
			continue
		for effect: EffectData in ability.effects:
			if effect == null or effect.type != GameEnums.EffectType.DAMAGE:
				continue
			assert_true(
				failures,
				"%s/range_one_modifier" % ability.id,
				is_equal_approx(
					float(effect.modifiers.get("range_one_damage_multiplier", 0.0)),
					0.7,
				),
				"every extended-reach Lancer attack must use Polearm Mastery",
			)

	var damage_at_one := _simulate_basic_damage(1)
	var damage_at_two := _simulate_basic_damage(2)
	assert_true(
		failures,
		"polearm_mastery/damage_order",
		damage_at_one < damage_at_two,
		"Range 1 damage must be weaker than Range 2 damage",
	)
	assert_true(
		failures,
		"polearm_mastery/damage_ratio",
		damage_at_one == floori(damage_at_two * 0.7),
		"Range 1 damage must be exactly 70% of the unpenalized result",
	)


static func run_push_synergy_smoke(failures: Array[String]) -> void:
	var definition := lancer_unit_data()
	if definition == null:
		return
	var charge := factory_ability(&"lancer_piercing_charge")
	var sweep := factory_ability(&"lancer_sweeping_halberd")
	var vault := factory_ability(&"lancer_pole_vault")
	assert_true(
		failures,
		"push_synergy/charge_modifier",
		charge != null and _has_modifier(
			charge.upgraded_effects, GameEnums.EffectType.PUSH, "push_bonus_if_push_used"
		),
		"Piercing Charge [+] must gain PUSH 3 after Push",
	)
	assert_true(
		failures,
		"push_synergy/sweep_modifier",
		sweep != null and _has_modifier(
			sweep.upgraded_effects, GameEnums.EffectType.PULL, "pull_bonus_if_push_used"
		),
		"Sweeping Halberd [+] must gain PULL 2 after Push",
	)
	assert_true(
		failures,
		"push_synergy/vault_modifier",
		vault != null and _has_modifier(
			vault.upgraded_effects, GameEnums.EffectType.TELEPORT_CASTER,
			"landing_adjacent_push_if_push_used",
		),
		"Pole Vault [+] must require Push before its landing displacement",
	)
	if charge == null or sweep == null or vault == null:
		return

	var board := _plain_board(Vector2i(8, 5))
	var actor := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(1, 2), {
		"active_abilities": [charge, sweep, vault],
		"active_passives": [],
		"upgraded_abilities": [charge.id, sweep.id, vault.id],
	})
	actor.passive_flags["push_used_this_turn"] = true
	var landing_enemy := UnitState.create(
		2, definition, GameEnums.Team.ENEMY, Vector2i(4, 3), {
			"active_abilities": [],
			"active_passives": [],
		}
	)
	board.units = [actor, landing_enemy]
	GridSystem.set_occupant(board, actor.position, actor.id)
	GridSystem.set_occupant(board, landing_enemy.position, landing_enemy.id)
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(
		actor.id, vault, Vector2i(4, 2), -1
	))
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	assert_true(
		failures,
		"push_synergy/vault_sim",
		landing_enemy.position == Vector2i(4, 4),
		"Pole Vault [+] must push adjacent enemies after Push",
	)


static func run_active_execution_matrix(failures: Array[String]) -> void:
	var active_ids: Array[StringName] = [
		&"lancer_piercing_charge",
		&"lancer_sweeping_halberd",
		&"lancer_vaulting_leap",
		&"lancer_run_down",
		&"lancer_rallying_cry",
		&"lancer_flanking_maneuver",
		&"lancer_brace",
		&"lancer_harpoon_toss",
		&"lancer_glorious_charge",
		&"lancer_pole_vault",
		&"lancer_line_breaker",
		&"lancer_spear_wall",
		&"lancer_meteor_drop",
	]
	for ability_id: StringName in active_ids:
		run_single_active(ability_id, failures)


static func run_single_active(ability_id: StringName, failures: Array[String]) -> void:
	var ability := factory_ability(ability_id)
	assert_true(failures, "%s/executable" % ability_id, ability != null)
	if ability == null:
		return
	var result := _simulate_active_ability(ability)
	assert_true(
		failures,
		"%s/used" % ability_id,
		bool(result.get("used", false)),
		"the modular ability must execute through Simulator",
	)
	assert_true(
		failures,
		"%s/no_validation_failure" % ability_id,
		not bool(result.get("validation_failed", false)),
		"scenario setup must satisfy the authored targeting contract (%s)"
		% String(result.get("failure_reason", "")),
	)
	var events: Array = result.get("events", [])
	var has_outcome := false
	for event: Variant in events:
		if event is SimEvent and event.type in [
			GameEnums.SimEventType.UNIT_DAMAGED,
			GameEnums.SimEventType.UNIT_HEALED,
			GameEnums.SimEventType.TERRAIN_CHANGED,
		]:
			has_outcome = true
			break
	if not has_outcome and bool(result.get("used", false)):
		has_outcome = true
	assert_true(
		failures,
		"%s/outcome" % ability_id,
		has_outcome,
		"active sim must produce a combat outcome event, not ABILITY_USED alone",
	)


static func _simulate_active_ability(ability: AbilityData) -> Dictionary:
	var definition := lancer_unit_data()
	var board := _plain_board(Vector2i(12, 8))
	var actor := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(2, 3), {
		"active_abilities": [ability],
		"active_passives": [],
	})
	var enemy := UnitState.create(
		2,
		definition,
		GameEnums.Team.ENEMY,
		Vector2i(4, 3),
		{"active_abilities": [], "active_passives": []},
	)
	if ability.id == &"lancer_flanking_maneuver":
		enemy.position = Vector2i(4, 4)
		enemy.facing = GameEnums.Facing.NORTH
	var ally := UnitState.create(
		3,
		definition,
		GameEnums.Team.PLAYER,
		Vector2i(2, 4),
		{"active_abilities": [], "active_passives": []},
	)
	board.units = [actor, enemy, ally]
	for unit: UnitState in board.units:
		GridSystem.set_occupant(board, unit.position, unit.id)
	var target_coord := enemy.position
	var target_id := enemy.id
	if ability_id_is_movement(ability.id):
		target_coord = Vector2i(5, 3)
		target_id = -1
	if ability.id == &"lancer_flanking_maneuver":
		target_coord = Vector2i(3, 4)
		target_id = enemy.id
	if ability.id == &"lancer_rallying_cry" or ability.id == &"lancer_brace":
		target_coord = actor.position
		target_id = actor.id
	if ability.id == &"lancer_glorious_charge":
		target_coord = enemy.position
		target_id = ally.id
	if ability.id == &"lancer_spear_wall":
		target_coord = Vector2i(4, 3)
		target_id = -1
	if ability.id == &"lancer_meteor_drop" or ability.id == &"lancer_pole_vault":
		target_coord = Vector2i(3, 2)
		target_id = -1
	var action := TimelineAction.make_ability(actor.id, ability, target_coord, target_id)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, _single_action_plan(action), events)
	var used := false
	var validation_failed := false
	var failure_reason := ""
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ABILITY_USED and event.data.get("ability") == ability.id:
			used = true
		if event.type == GameEnums.SimEventType.ACTION_FAILED:
			validation_failed = true
			failure_reason = String(event.data.get("reason", "unknown"))
	return {
		"used": used,
		"validation_failed": validation_failed,
		"failure_reason": failure_reason,
		"events": events,
	}


static func ability_id_is_movement(ability_id: StringName) -> bool:
	return ability_id in [
		&"lancer_pole_vault",
		&"lancer_line_breaker",
	]


static func _single_action_plan(action: TimelineAction) -> Timeline:
	var plan := Timeline.new()
	plan.add(action)
	return plan


static func run_single_passive(passive_id: StringName, failures: Array[String]) -> void:
	_run_passive_blocks(failures, passive_id)


static func run_passive_runtime_smoke(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"")


static func _passive_should_run(only_id: StringName, passive_id: StringName) -> bool:
	return only_id == &"" or only_id == passive_id


static func _run_passive_blocks(failures: Array[String], only_id: StringName) -> void:
	var definition := lancer_unit_data()
	var basic := factory_ability(&"lancer_basic")
	var push := factory_ability(&"lancer_push")
	var pole_vault := factory_ability(&"lancer_pole_vault")
	if definition == null or basic == null or push == null or pole_vault == null:
		return

	if _passive_should_run(only_id, &"kinetic_charge"):
		var momentum_board := _plain_board(Vector2i(8, 4))
		var momentum := _make_test_unit(
		definition,
		1,
		GameEnums.Team.PLAYER,
		Vector2i(1, 1),
		[basic],
		[factory_passive(&"kinetic_charge")],
		)
		var momentum_target := _make_test_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(4, 1), [], []
		)
		_add_test_units(momentum_board, [momentum, momentum_target])
		var momentum_plan := Timeline.new()
		momentum_plan.add(TimelineAction.make_move(momentum.id, Vector2i(2, 1)))
		momentum_plan.add(TimelineAction.make_ability(
		momentum.id, basic, momentum_target.position, momentum_target.id
		))
		var momentum_events: Array[SimEvent] = []
		Simulator.simulate_player_turn(momentum_board, momentum_plan, momentum_events)
		var momentum_damage := _first_damage_event(momentum_events)
		assert_true(
		failures,
		"passive/kinetic_charge",
		int(momentum_damage.get("stat_val", 0)) >= momentum.current_strength + 1,
		"Kinetic Charge must add one STR per continuous tile (stat=%d current=%d tiles=%d)"
		% [
			int(momentum_damage.get("stat_val", 0)),
			momentum.current_strength,
			momentum.continuous_straight_tiles_this_turn,
		],
		)

	if _passive_should_run(only_id, &"unstoppable_mass"):
		var unstoppable_board := _plain_board(Vector2i(9, 4))
		var unstoppable := _make_test_unit(
		definition,
		1,
		GameEnums.Team.PLAYER,
		Vector2i(1, 1),
		[basic],
		[factory_passive(&"unstoppable_mass")],
		)
		var unstoppable_target := _make_test_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(6, 1), [], []
		)
		_add_test_units(unstoppable_board, [unstoppable, unstoppable_target])
		var unstoppable_plan := Timeline.new()
		unstoppable_plan.add(TimelineAction.make_move(unstoppable.id, Vector2i(4, 1)))
		unstoppable_plan.add(TimelineAction.make_ability(
		unstoppable.id, basic, unstoppable_target.position, unstoppable_target.id
		))
		var unstoppable_events: Array[SimEvent] = []
		Simulator.simulate_player_turn(unstoppable_board, unstoppable_plan, unstoppable_events)
		assert_true(
		failures,
		"passive/unstoppable_mass",
		bool(_first_damage_event(unstoppable_events).get("pierce", false)),
		"maximum movement must grant PIERCE",
		)

	if _passive_should_run(only_id, &"canto"):
		var canto_board := _plain_board(Vector2i(5, 3))
		var canto_basic := factory_ability(&"lancer_basic")
		var canto := _make_test_unit(
		definition, 1, GameEnums.Team.PLAYER, Vector2i(1, 1), [canto_basic], [factory_passive(&"canto")]
		)
		var canto_target := _make_test_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(3, 1), [], []
		)
		_add_test_units(canto_board, [canto, canto_target])
		var canto_events: Array[SimEvent] = []
		MovementSystem.execute_move(
		canto_board,
		TimelineAction.make_move(canto.id, Vector2i(2, 1)),
		canto_events,
		)
		assert_true(
		failures,
		"passive/canto",
		canto.has_status(GameEnums.StatusType.CANTO),
		"standard movement must grant CANTO",
		)
		var canto_attack_events: Array[SimEvent] = []
		AbilitySystem.execute(
		canto_board,
		TimelineAction.make_ability(
			canto.id, canto_basic, canto_target.position, canto_target.id,
		),
		canto_attack_events,
		)
		assert_eq_int(
		failures,
		"passive/canto_no_refund",
		canto.movement.points_left,
		definition.move_points,
		)

	if _passive_should_run(only_id, &"frontline_defense"):
		var frontline_board := _plain_board(Vector2i(9, 4))
		var frontline := _make_test_unit(
		definition,
		1,
		GameEnums.Team.PLAYER,
		Vector2i(1, 1),
		[],
		[factory_passive(&"frontline_defense")],
		)
		var ranged_enemy := _make_test_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(6, 1), [], []
		)
		_add_test_units(frontline_board, [frontline, ranged_enemy])
		var frontline_events: Array[SimEvent] = []
		MovementSystem.execute_move(
		frontline_board,
		TimelineAction.make_move(frontline.id, Vector2i(4, 1)),
		frontline_events,
		)
		var frontline_hp := frontline.health.current_hp
		CombatSystem.deal_damage(
		frontline_board,
		frontline,
		99,
		frontline_events,
		&"physical",
		false,
		false,
		ranged_enemy,
		"QA ranged hit",
		)
		assert_true(
		failures,
		"passive/frontline_defense",
		frontline.health.current_hp == frontline_hp
		and CombatSystem.get_dynamic_defense(frontline_board, frontline) >= frontline.current_defense + 1,
		"moving three tiles must grant defense and ranged immunity",
		)

	if _passive_should_run(only_id, &"flanking_strike"):
		var flanking_board := _plain_board(Vector2i(6, 4))
		var flanker := _make_test_unit(
		definition,
		1,
		GameEnums.Team.PLAYER,
		Vector2i(2, 2),
		[basic],
		[factory_passive(&"flanking_strike")],
		)
		var flanking_target := _make_test_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(3, 2), [], []
		)
		flanking_target.facing = GameEnums.Facing.NORTH
		_add_test_units(flanking_board, [flanker, flanking_target])
		var flank_events: Array[SimEvent] = []
		AbilitySystem.execute(
		flanking_board,
		TimelineAction.make_ability(flanker.id, basic, flanking_target.position, flanking_target.id),
		flank_events,
		)
		assert_true(
		failures,
		"passive/flanking_strike",
		flanking_target.health.current_hp < flanking_target.health.max_hp,
		"side attacks must ignore defense",
		)

	if _passive_should_run(only_id, &"plunging_attack"):
		var plunging_board := _plain_board(Vector2i(6, 4))
		var plunging := _make_test_unit(
		definition,
		1,
		GameEnums.Team.PLAYER,
		Vector2i(2, 2),
		[basic],
		[factory_passive(&"plunging_attack")],
		)
		var plunging_target := _make_test_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(3, 2), [], []
		)
		_add_test_units(plunging_board, [plunging, plunging_target])
		plunging.passive_flags["jumped_or_teleported_this_turn"] = true
		var plunge_events: Array[SimEvent] = []
		AbilitySystem.execute(
		plunging_board,
		TimelineAction.make_ability(plunging.id, basic, plunging_target.position, plunging_target.id),
		plunge_events,
		)
		assert_true(
		failures,
		"passive/plunging_attack",
		int(_first_damage_event(plunge_events).get("base", 0)) >= 4,
		"jump context must grant +3 ATK to the next basic attack",
		)

	if _passive_should_run(only_id, &"crashing_impact"):
		var crash_board := _plain_board(Vector2i(8, 5))
		var crasher := _make_test_unit(
		definition,
		1,
		GameEnums.Team.PLAYER,
		Vector2i(1, 2),
		[pole_vault],
		[factory_passive(&"crashing_impact")],
		)
		var crash_enemy := _make_test_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(4, 2), [], []
		)
		_add_test_units(crash_board, [crasher, crash_enemy])
		var crash_events: Array[SimEvent] = []
		Simulator.simulate_player_turn(
		crash_board,
		_single_action_plan(TimelineAction.make_ability(crasher.id, pole_vault, Vector2i(3, 2))),
		crash_events,
		)
		assert_true(
		failures,
		"passive/crashing_impact",
		crash_enemy.position != Vector2i(4, 2),
		"jump landing must push adjacent enemies",
		)

	if _passive_should_run(only_id, &"pole_plant"):
		var pole_board := _plain_board(Vector2i(6, 4))
		var trap := TerrainData.new()
		trap.id = &"trap"
		trap.hazard_damage = 5
		pole_board.set_tile_terrain(Vector2i(3, 2), trap)
		var planter := _make_test_unit(
		definition,
		1,
		GameEnums.Team.PLAYER,
		Vector2i(2, 2),
		[push],
		[factory_passive(&"pole_plant")],
		)
		_add_test_units(pole_board, [planter])
		Simulator.simulate_player_turn(
		pole_board,
		_single_action_plan(TimelineAction.make_ability(planter.id, push, Vector2i(3, 2))),
		[],
		)
		assert_true(
		failures,
		"passive/pole_plant",
		pole_board.get_tile(Vector2i(3, 2)).definition.id == &"plain"
		and planter.armor == 2,
		"0-AP Push must destroy traps and grant SHIELD 2",
		)

	if _passive_should_run(only_id, &"spear_drop"):
		var spear_board := _plain_board(Vector2i(6, 4))
		var spearman := _make_test_unit(
		definition,
		1,
		GameEnums.Team.PLAYER,
		Vector2i(2, 2),
		[basic],
		[factory_passive(&"spear_drop")],
		)
		var spearman_target := _make_test_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(3, 2), [], []
		)
		_add_test_units(spear_board, [spearman, spearman_target])
		spearman.passive_flags["vaulted_target_id"] = spearman_target.id
		AbilitySystem.execute(
		spear_board,
		TimelineAction.make_ability(spearman.id, basic, spearman_target.position, spearman_target.id),
		[],
		)
		assert_true(
		failures,
		"passive/spear_drop",
		spearman_target.has_status(GameEnums.StatusType.BLEED),
		"attacking a vaulted target must apply weapon-scaled BLEED",
		)

	if _passive_should_run(only_id, &"springboard"):
		var spring_board := _plain_board(Vector2i(6, 4))
		var springer := _make_test_unit(
		definition,
		1,
		GameEnums.Team.PLAYER,
		Vector2i(2, 2),
		[],
		[factory_passive(&"springboard")],
		)
		var slain := _make_test_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(3, 2), [], []
		)
		slain.health.current_hp = 1
		_add_test_units(spring_board, [springer, slain])
		CombatSystem.deal_damage(
		spring_board,
		slain,
		99,
		[],
		&"true",
		true,
		false,
		springer,
		"QA kill",
		)
		assert_true(
		failures,
		"springboard/pending",
		springer.passive_flags.get("springboard_pending_coord", Vector2i(-1, -1)) == Vector2i(3, 2),
		"kill must prime the defeated tile for the free vault",
		)
		var spring_events: Array[SimEvent] = []
		MovementSystem.execute_move(
		spring_board,
		TimelineAction.make_free_reaction_move(springer.id, Vector2i(3, 2)),
		spring_events,
		)
		assert_true(
		failures,
		"passive/springboard",
		springer.position == Vector2i(3, 2) and springer.movement.max_points == 5,
		"kill reaction must vault into the defeated enemy's space for free",
		)

	if _passive_should_run(only_id, &"sweet_spot"):
		var tip_board := _plain_board(Vector2i(7, 4))
		var tipper := _make_test_unit(
		definition,
		1,
		GameEnums.Team.PLAYER,
		Vector2i(2, 2),
		[basic],
		[factory_passive(&"sweet_spot")],
		)
		var tip_target := _make_test_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(4, 2), [], []
		)
		_add_test_units(tip_board, [tipper, tip_target])
		var tip_events: Array[SimEvent] = []
		AbilitySystem.execute(
		tip_board,
		TimelineAction.make_ability(tipper.id, basic, tip_target.position, tip_target.id),
		tip_events,
		)
		assert_true(
		failures,
		"passive/pivot_leverage",
		tip_target.position == Vector2i(5, 2)
		and tip_target.has_status(GameEnums.StatusType.STAT_DEBUFF_MOV),
		"exact Range 2 attacks must PUSH 1 and reduce target MOV by 2",
		)

	if _passive_should_run(only_id, &"reach_advantage"):
		var reach_board := _plain_board(Vector2i(7, 4))
		var reacher := _make_test_unit(
		definition,
		1,
		GameEnums.Team.PLAYER,
		Vector2i(2, 2),
		[basic],
		[factory_passive(&"reach_advantage")],
		)
		var retaliator := _make_test_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(4, 2), [], []
		)
		retaliator.active_statuses.append(
		DataLibrary.make_status(GameEnums.StatusType.RETALIATION_PROTOCOL, 1, 0)
		)
		_add_test_units(reach_board, [reacher, retaliator])
		var reach_events: Array[SimEvent] = []
		AbilitySystem.execute(
		reach_board,
		TimelineAction.make_ability(reacher.id, basic, retaliator.position, retaliator.id),
		reach_events,
		)
		assert_true(
		failures,
		"passive/reach_advantage",
		not _events_have_label(reach_events, "Retaliation Protocol"),
		"Range 2 melee attacks must suppress retaliation",
		)

	if _passive_should_run(only_id, &"disengage"):
		var disengage_board := _plain_board(Vector2i(7, 4))
		var disengager := _make_test_unit(
		definition,
		1,
		GameEnums.Team.PLAYER,
		Vector2i(2, 2),
		[basic],
		[factory_passive(&"disengage")],
		)
		var disengage_target := _make_test_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(3, 2), [], []
		)
		_add_test_units(disengage_board, [disengager, disengage_target])
		AbilitySystem.execute(
		disengage_board,
		TimelineAction.make_ability(
			disengager.id,
			basic,
			disengage_target.position,
			disengage_target.id,
		),
		[],
		)
		assert_true(
		failures,
		"passive/disengage",
		disengager.position == Vector2i(1, 2),
		"Range 1 attacks must push the Lancer away before damage",
		)

	if _passive_should_run(only_id, &"zone_of_control"):
		var zone_board := _plain_board(Vector2i(9, 4))
		var watcher := _make_test_unit(
		definition,
		1,
		GameEnums.Team.PLAYER,
		Vector2i(2, 2),
		[basic],
		[factory_passive(&"zone_of_control")],
		)
		var zoned_enemy := _make_test_unit(
		definition, 2, GameEnums.Team.ENEMY, Vector2i(6, 2), [], []
		)
		_add_test_units(zone_board, [watcher, zoned_enemy])
		MovementSystem.execute_move(
		zone_board,
		TimelineAction.make_move(zoned_enemy.id, Vector2i(4, 2)),
		[],
		)
		assert_true(
		failures,
		"passive/zone_of_control",
		watcher.passive_flags.get("zone_attack_used_this_round", false),
		"ending an enemy move at Range 2 must trigger one basic attack",
		)

	if _passive_should_run(only_id, &"leverage"):
		var leverage_board := _plain_board(Vector2i(7, 4))
		var leverager := _make_test_unit(
		definition,
		1,
		GameEnums.Team.PLAYER,
		Vector2i(2, 2),
		[push],
		[factory_passive(&"leverage")],
		[&"leverage"],
		)
		var leverage_ally := _make_test_unit(
		definition, 2, GameEnums.Team.PLAYER, Vector2i(3, 2), [], []
		)
		_add_test_units(leverage_board, [leverager, leverage_ally])
		var leverage_events: Array[SimEvent] = []
		AbilitySystem.execute(
		leverage_board,
		TimelineAction.make_ability(leverager.id, push, leverage_ally.position, leverage_ally.id),
		leverage_events,
		)
		AbilitySystem.resolve_pending_pushes(leverage_board, leverage_events)
		assert_true(
		failures,
		"passive/leverage",
		leverager.passive_flags.get("next_attack_pierce", false)
		and leverager.armor == 1,
		"0-AP Push must prime PIERCE and upgraded SHIELD",
		)


static func _make_test_unit(
	definition: UnitData,
	unit_id: int,
	team: GameEnums.Team,
	position: Vector2i,
	abilities: Array,
	passives: Array,
	upgraded_passives: Array = [],
) -> UnitState:
	return UnitState.create(unit_id, definition, team, position, {
		"active_abilities": abilities,
		"active_passives": passives,
		"upgraded_passives": upgraded_passives,
	})


static func _add_test_units(board: BoardState, units: Array) -> void:
	board.units.clear()
	for unit: UnitState in units:
		board.units.append(unit)
		GridSystem.set_occupant(board, unit.position, unit.id)


static func _first_damage_event(events: Array[SimEvent]) -> Dictionary:
	for event: SimEvent in events:
		if (
			event.type == GameEnums.SimEventType.MATH_TELEMETRY
			and event.data.get("type", "") == "damage"
		):
			return event.data
	return {}


static func _has_passive_id(passives: Array[PassiveData], passive_id: StringName) -> bool:
	for passive: PassiveData in passives:
		if passive != null and passive.id == passive_id:
			return true
	return false


static func _events_have_label(events: Array[SimEvent], label: String) -> bool:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.COUNTER_ATTACK:
			if String(event.data.get("source_label", "")) == label:
				return true
	return false


static func _simulate_basic_damage(distance: int) -> int:
	var definition := lancer_unit_data()
	var basic := factory_ability(&"lancer_basic")
	var board := _plain_board(Vector2i(7, 4))
	var actor := UnitState.create(1, definition, GameEnums.Team.PLAYER, Vector2i(1, 1), {
		"active_abilities": [basic],
		"active_passives": [],
	})
	var target := UnitState.create(
		2, definition, GameEnums.Team.ENEMY, Vector2i(1 + distance, 1), {
			"active_abilities": [],
			"active_passives": [],
		}
	)
	board.units = [actor, target]
	GridSystem.set_occupant(board, actor.position, actor.id)
	GridSystem.set_occupant(board, target.position, target.id)
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(actor.id, basic, target.position, target.id))
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	for event: SimEvent in events:
		if (
			event.type == GameEnums.SimEventType.MATH_TELEMETRY
			and event.data.get("type", "") == "damage"
		):
			return int(event.data.get("final_raw", 0))
	return target.health.max_hp - target.health.current_hp


static func _has_modifier(
	effects: Array[EffectData],
	effect_type: GameEnums.EffectType,
	modifier_key: String,
) -> bool:
	for effect: EffectData in effects:
		if effect != null and effect.type == effect_type and effect.modifiers.has(modifier_key):
			return true
	return false


static func _plain_board(size: Vector2i) -> BoardState:
	var board := BoardState.new()
	board.grid_size = size
	var plain := TerrainData.new()
	plain.id = &"plain"
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	return board

