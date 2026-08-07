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

