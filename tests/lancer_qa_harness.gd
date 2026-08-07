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
	return DataLibrary.get_unit(LANCER_ID)

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
	for passive: PassiveData in definition.passives:
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

static func run_push_smoke(failures: Array[String]) -> void:
	var definition := lancer_unit_data()
	if definition == null:
		return
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

