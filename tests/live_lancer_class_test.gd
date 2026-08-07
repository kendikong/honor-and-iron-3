## Tier 2 live Lancer acceptance.
##
## Every row proves the live TestBattle path can select the authored ability,
## build valid commit slots, and resolve the committed intent through Simulator.
## The contract also checks the Bible-facing range, targeting, shape, primary
## effect, movement effect, and upgrade metadata before the runtime assertion.
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _ACTOR_CELL := Vector2i(4, 5)
const _DEFAULT_EXTRA_PLAYERS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, 8), Vector2i(8, 8),
]
const _PUSH_EXTRA_PLAYERS: Array[Vector2i] = [
	Vector2i(5, 5), Vector2i(1, 1), Vector2i(1, 8),
]
const _SETTLE_FRAMES: int = 8
const _DELTA_MS: int = 16

const _CASES: Array[Dictionary] = [
	{
		"id": &"lancer_basic",
		"range": 2,
		"flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.DAMAGE,
		"primary_amount": 1,
		"observation": &"damage",
		"target_kind": &"enemy",
		"target": Vector2i(6, 5),
		"dummies": [Vector2i(6, 5)],
		"upgrade_keys": [],
	},
	{
		"id": &"lancer_push",
		"range": 1,
		"flags": GameEnums.TargetingFlags.ALLY,
		"shape": GameEnums.TargetShape.SINGLE,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.PUSH,
		"primary_amount": 1,
		"observation": &"displacement",
		"target_kind": &"ally",
		"target": Vector2i(5, 5),
		"dummies": [Vector2i(7, 5)],
		"extra_players": _PUSH_EXTRA_PLAYERS,
		"upgrade_keys": [&"limit_once_per_turn", &"buff_on_push"],
	},
	{
		"id": &"lancer_piercing_charge",
		"range": 2,
		"flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.SINGLE,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.DASH,
		"primary_amount": 3,
		"observation": &"movement_damage",
		"target_kind": &"tile",
		"target": Vector2i(6, 5),
		"dummies": [Vector2i(5, 5)],
		"upgrade_keys": [&"create_trampled_terrain", &"push_bonus_if_push_used"],
	},
	{
		"id": &"lancer_sweeping_halberd",
		"range": 2,
		"flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.ARC,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.DAMAGE,
		"primary_amount": 2,
		"observation": &"damage_displacement",
		"target_kind": &"enemy",
		"target": Vector2i(6, 5),
		"dummies": [Vector2i(6, 5)],
		"upgrade_keys": [&"stagger_on_collision", &"pull_bonus_if_push_used"],
	},
	{
		"id": &"lancer_vaulting_leap",
		"range": 2,
		"flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.DAMAGE,
		"primary_amount": 2,
		"observation": &"damage_status",
		"target_kind": &"enemy",
		"target": Vector2i(6, 5),
		"dummies": [Vector2i(6, 5)],
		"upgrade_keys": [&"armor_explosion_atk"],
	},
	{
		"id": &"lancer_run_down",
		"range": 2,
		"flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.DAMAGE,
		"primary_amount": 3,
		"observation": &"damage",
		"target_kind": &"enemy",
		"target": Vector2i(6, 5),
		"dummies": [Vector2i(6, 5)],
		"upgrade_keys": [&"on_kill_max_move"],
	},
	{
		"id": &"lancer_rallying_cry",
		"range": 0,
		"flags": GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.SELF,
		"shape": GameEnums.TargetShape.AOE_CROSS,
		"shape_size": 2,
		"primary_type": GameEnums.EffectType.ADD_STATUS,
		"primary_amount": 1,
		"observation": &"status",
		"target_kind": &"self",
		"target": _ACTOR_CELL,
		"dummies": [Vector2i(7, 5)],
		"upgrade_keys": [&"next_turn_max_move", &"upgraded_trample"],
	},
	{
		"id": &"lancer_flanking_maneuver",
		"range": 2,
		"flags": GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.MOVE,
		"primary_amount": 2,
		"observation": &"movement_damage",
		"target_kind": &"enemy",
		"target": Vector2i(6, 6),
		"dummies": [Vector2i(6, 6)],
		"upgrade_keys": [&"ghost_move"],
	},
	{
		"id": &"lancer_brace",
		"range": 0,
		"flags": GameEnums.TargetingFlags.SELF,
		"shape": GameEnums.TargetShape.SINGLE,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.ADD_STATUS_SELF,
		"primary_amount": 2,
		"observation": &"status",
		"target_kind": &"self",
		"target": _ACTOR_CELL,
		"dummies": [Vector2i(6, 5)],
		"upgrade_keys": [&"brace_attacker_stagger"],
	},
	{
		"id": &"lancer_harpoon_toss",
		"range": 4,
		"flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.DAMAGE,
		"primary_amount": 1,
		"observation": &"damage_displacement",
		"target_kind": &"enemy",
		"target": Vector2i(8, 5),
		"dummies": [Vector2i(8, 5)],
		"upgrade_keys": [&"pull_self_if_rooted_or_heavier"],
	},
	{
		"id": &"lancer_glorious_charge",
		"range": 4,
		"flags": GameEnums.TargetingFlags.ALLY
			| GameEnums.TargetingFlags.ENEMY
			| GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.SINGLE,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.DASH,
		"primary_amount": 4,
		"observation": &"movement_damage",
		"target_kind": &"enemy",
		"target": Vector2i(8, 5),
		"ally": Vector2i(5, 5),
		"dummies": [Vector2i(8, 5)],
		"extra_players": _PUSH_EXTRA_PLAYERS,
		"upgrade_keys": [&"paired_ally_charge", &"on_kill_both_ap"],
	},
	{
		"id": &"lancer_pole_vault",
		"range": 3,
		"flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.SINGLE,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.TELEPORT_CASTER,
		"primary_amount": 3,
		"observation": &"movement",
		"target_kind": &"tile",
		"target": Vector2i(6, 5),
		"dummies": [Vector2i(5, 5)],
		"upgrade_keys": [&"vault_over", &"landing_adjacent_push_if_push_used"],
	},
	{
		"id": &"lancer_line_breaker",
		"range": 4,
		"flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.LINE,
		"shape_size": 4,
		"primary_type": GameEnums.EffectType.DASH,
		"primary_amount": 4,
		"observation": &"movement_damage",
		"target_kind": &"tile",
		"target": Vector2i(8, 5),
		"dummies": [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)],
		"upgrade_keys": [&"line_breaker", &"bonus_per_enemy_passed"],
	},
	{
		"id": &"lancer_spear_wall",
		"range": 2,
		"flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.ARC,
		"shape_size": 2,
		"primary_type": GameEnums.EffectType.CREATE_HAZARD,
		"primary_amount": 2,
		"observation": &"terrain",
		"target_kind": &"tile",
		"target": Vector2i(6, 5),
		"dummies": [Vector2i(8, 8)],
		"upgrade_keys": [&"hazard_duration"],
	},
	{
		"id": &"lancer_meteor_drop",
		"range": 2,
		"flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.AOE_CROSS,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.TELEPORT_CASTER,
		"primary_amount": 2,
		"observation": &"movement_damage",
		"target_kind": &"tile",
		"target": Vector2i(6, 5),
		"dummies": [Vector2i(6, 4)],
		"upgrade_keys": [],
	},
]

var _scene: TestBattleMapView
var _director: CombatDirector
var _input: CombatPlanningInput


func test_live_lancer_every_skill(timeout := 240000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_scene = runner.scene() as TestBattleMapView
	assert_object(_scene).is_not_null()
	if _scene == null:
		return

	for case: Dictionary in _CASES:
		await _run_live_case(runner, case)


func _run_live_case(runner: GdUnitSceneRunner, case: Dictionary) -> void:
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"lancer"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.passive_enabled.clear()
	session.skill_enabled.clear()
	session.set_all_passives_enabled(&"lancer", false)
	session.set_all_skills_enabled(&"lancer", true)
	session.extra_player_coords = _vector2i_array(
		case.get("extra_players", _DEFAULT_EXTRA_PLAYERS),
	)
	session.dummy_coords = _vector2i_array(case.dummies)
	session.unkillable_dummies = true
	session.infinite_player_ap = true
	_scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)

	_director = _scene.get_node("CombatDirector") as CombatDirector
	var shell := _scene.get_node("CombatShell") as TacticalCombatShell
	_input = shell.planning_input
	_director.auto_run = true
	var board: BoardState = _director.board
	var actor_id := _unit_id_at(board, case.actor_cell)
	assert_int(actor_id).override_failure_message(
		"%s: four-Lancer fixture missing actor at %s" % [case.id, case.actor_cell],
	).is_greater(0)
	if actor_id < 0:
		return
	var actor := board.get_unit_by_id(actor_id)
	var ability := _ability_by_id(actor, case.id)
	_assert_contract(ability, case)
	if ability == null:
		return

	_director.select_unit(actor_id)
	_director.select_ability(_ability_index(actor, ability))
	await runner.simulate_frames(3, _DELTA_MS)

	var target_cell: Vector2i = case.target
	var slots: Dictionary
	if case.id == &"lancer_glorious_charge":
		slots = await _commit_glorious_charge(runner, actor_id, case)
	else:
		slots = await _commit_live_click(runner, actor_id, target_cell)
	assert_bool(bool(slots.get("invalid", false))).override_failure_message(
		"%s: live preview/commit slots rejected a Bible-valid target: %s"
		% [case.id, slots],
	).is_false()
	assert_bool(_plan_has_ability(case.id)).override_failure_message(
		"%s: live commit did not write the selected ability" % case.id,
	).is_true()

	var result: SimResult = Simulator.simulate(_director.base_board, _director.get_player_plan())
	_assert_no_actor_failure(result.events, actor_id, case.id)
	_assert_live_observation(result, case, actor_id)


func _assert_contract(ability: AbilityData, case: Dictionary) -> void:
	assert_object(ability).override_failure_message(
		"%s: ability missing from live Lancer loadout" % case.id,
	).is_not_null()
	if ability == null:
		return
	assert_int(ability.range_tiles).override_failure_message(
		"%s: range" % case.id,
	).is_equal(int(case.range))
	assert_int(ability.targeting_flags).override_failure_message(
		"%s: targeting flags" % case.id,
	).is_equal(int(case.flags))
	assert_that(ability.target_shape).override_failure_message(
		"%s: range shape" % case.id,
	).is_equal(case.shape)
	assert_int(ability.target_shape_size).override_failure_message(
		"%s: range shape size" % case.id,
	).is_equal(int(case.shape_size))
	assert_bool(ability.effects.size() > 0).override_failure_message(
		"%s: compiled base effects must not be empty" % case.id,
	).is_true()
	assert_bool(ability.upgraded_effects.size() > 0).override_failure_message(
		"%s: compiled [+] effects must not be empty" % case.id,
	).is_true()
	var primary: EffectData = ability.effects[0]
	assert_that(primary.type).override_failure_message(
		"%s: primary effect type" % case.id,
	).is_equal(case.primary_type)
	assert_int(primary.amount).override_failure_message(
		"%s: primary effect amount" % case.id,
	).is_equal(int(case.primary_amount))
	for key: StringName in case.upgrade_keys:
		assert_bool(_effects_have_key(ability.upgraded_effects, key)).override_failure_message(
			"%s: missing [+] effect modifier %s" % [case.id, key],
		).is_true()


func _assert_no_actor_failure(events: Array[SimEvent], actor_id: int, skill_id: StringName) -> void:
	for event: SimEvent in events:
		if (
			event.type == GameEnums.SimEventType.ACTION_FAILED
			and int(event.data.get("actor", -1)) == actor_id
		):
			assert_that("").override_failure_message(
				"%s: Simulator rejected the committed live intent: %s" % [skill_id, event.data],
			).is_equal("never")


func _assert_live_observation(result: SimResult, case: Dictionary, actor_id: int) -> void:
	var events: Array[SimEvent] = result.events
	var used := false
	for event: SimEvent in events:
		if (
			event.type == GameEnums.SimEventType.ABILITY_USED
			and event.data.get("ability", &"") == case.id
			and int(event.data.get("actor", -1)) == actor_id
		):
			used = true
			break
	assert_bool(used).override_failure_message(
		"%s: committed skill never resolved as ABILITY_USED" % case.id,
	).is_true()

	var observation: StringName = case.observation
	if observation in [&"damage", &"movement_damage", &"damage_status", &"damage_displacement"]:
		assert_bool(_events_have_damage(events, actor_id)).override_failure_message(
			"%s: expected damage was not observed in Simulator telemetry" % case.id,
		).is_true()
	if observation in [&"movement", &"movement_damage"]:
		assert_bool(_events_have_actor_move(events, actor_id)).override_failure_message(
			"%s: expected movement was not observed" % case.id,
		).is_true()
	if observation in [&"displacement", &"damage_displacement"]:
		assert_bool(_events_have_displacement(events, actor_id)).override_failure_message(
			"%s: expected PUSH/PULL displacement was not observed" % case.id,
		).is_true()
	if observation == &"status":
		var final_actor := result.final_state.get_unit_by_id(actor_id)
		assert_bool(final_actor != null and not final_actor.active_statuses.is_empty()).override_failure_message(
			"%s: expected status effect was not observed" % case.id,
		).is_true()
	if observation == &"terrain":
		var terrain := result.final_state.get_tile(case.target)
		assert_bool(
			terrain != null
			and terrain.definition != null
			and terrain.definition.id == &"spear_wall",
		).override_failure_message(
			"%s: expected spear-wall terrain was not created" % case.id,
		).is_true()


func _commit_glorious_charge(
	runner: GdUnitSceneRunner,
	actor_id: int,
	case: Dictionary,
) -> Dictionary:
	var ally_slots := await _commit_live_click(runner, actor_id, case.ally)
	assert_bool(bool(ally_slots.get("invalid", false))).override_failure_message(
		"%s: selecting the allied charger must arm the second target step" % case.id,
	).is_false()
	assert_bool(_director.find_awaiting_action(actor_id) != null).override_failure_message(
		"%s: allied charger selection did not enter awaiting-target flow" % case.id,
	).is_true()
	var final_slots := await _commit_live_click(runner, actor_id, case.target)
	return final_slots


func _commit_live_click(
	runner: GdUnitSceneRunner,
	unit_id: int,
	cell: Vector2i,
) -> Dictionary:
	_input.set_qa_pointer_grid_cell(cell)
	if _input._intent_state != null:
		_input._intent_state.set_hover_coord(cell)
	var slots: Dictionary = _input._final_commit_slots_for_click_at_cell(
		unit_id, cell, Vector2.ZERO,
	)
	if bool(slots.get("invalid", false)):
		return slots
	_input.call("_paint_intent_slots_before_commit", unit_id, slots)
	assert_bool(_director.commit_from_slots(unit_id, slots)).override_failure_message(
		"live commit_from_slots must accept the preview slots",
	).is_true()
	_input.call("_promote_intent_preview_after_commit")
	_director.flush_plan_refresh_signals_if_pending()
	await runner.simulate_frames(3, _DELTA_MS)
	return slots


func _plan_has_ability(skill_id: StringName) -> bool:
	for action: TimelineAction in _director.get_player_plan().entries:
		if action.type == GameEnums.ActionType.ABILITY and action.ability != null:
			if action.ability.id == skill_id and not action.awaiting_target:
				return true
	return false


func _ability_by_id(unit: UnitState, skill_id: StringName) -> AbilityData:
	if unit == null:
		return null
	for ability: AbilityData in unit.active_abilities:
		if ability != null and ability.id == skill_id:
			return ability
	return null


func _ability_index(unit: UnitState, ability: AbilityData) -> int:
	for index: int in range(unit.active_abilities.size()):
		if unit.active_abilities[index] == ability:
			return index
	return -1


func _effects_have_key(effects: Array[EffectData], key: StringName) -> bool:
	for effect: EffectData in effects:
		if effect != null and effect.modifiers.has(key):
			return true
	return false


func _events_have_damage(events: Array[SimEvent], actor_id: int) -> bool:
	for event: SimEvent in events:
		if (
			event.type == GameEnums.SimEventType.MATH_TELEMETRY
			and event.data.get("type", "") == "damage"
			and int(event.data.get("actor_id", actor_id)) == actor_id
		):
			return true
		if (
			event.type == GameEnums.SimEventType.UNIT_DAMAGED
			and int(event.data.get("source", actor_id)) == actor_id
		):
			return true
	return false


func _events_have_actor_move(events: Array[SimEvent], actor_id: int) -> bool:
	for event: SimEvent in events:
		if (
			event.type == GameEnums.SimEventType.UNIT_MOVED
			and int(event.data.get("actor", event.data.get("unit", -1))) == actor_id
		):
			return true
	return false


func _events_have_displacement(events: Array[SimEvent], actor_id: int) -> bool:
	for event: SimEvent in events:
		if event.type != GameEnums.SimEventType.UNIT_MOVED:
			continue
		if int(event.data.get("pusher", event.data.get("actor", -1))) == actor_id:
			return true
		if int(event.data.get("puller", -1)) == actor_id:
			return true
	return false


func _unit_id_at(board: BoardState, cell: Vector2i) -> int:
	if board == null:
		return -1
	for unit: UnitState in board.units:
		if unit != null and unit.position == cell:
			return unit.id
	return -1


func _vector2i_array(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not raw is Array:
		return out
	for value: Variant in raw:
		if value is Vector2i:
			out.append(value as Vector2i)
	return out
