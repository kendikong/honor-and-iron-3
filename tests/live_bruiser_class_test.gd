## Tier 2 live Bruiser acceptance.
##
## Each movement skill and active uses its own actor cell per batch, commits through
## preview slots, and resolves via Simulator. Self AOE skills assert overlay red tiles
## match AbilitySystem.planning_action_range_tiles (Bible blast footprint at stand).
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _SETTLE_FRAMES: int = 8
const _DELTA_MS: int = 16

const _CASES: Array[Dictionary] = [
	{"id": &"bruiser_push_through", "observation": &"displacement", "upgrade_keys": [&"buff_on_push"]},
	{"id": &"bruiser_charge_strike", "observation": &"movement_damage", "upgrade_keys": [&"ghost_move", &"bonus_dmg_from_terrain"]},
	{"id": &"bruiser_concussion_blow", "observation": &"damage_displacement", "upgrade_keys": [&"enemy_collision_stagger_both"]},
	{"id": &"bruiser_cleave", "observation": &"damage", "upgrade_keys": [&"weapon_scaled"], "assert_arc_overlay": true},
	{"id": &"bruiser_suplex", "observation": &"damage_displacement", "upgrade_keys": [&"bonus_dmg_per_10_hp"]},
	{"id": &"bruiser_adrenaline_surge", "observation": &"self_buff", "upgrade_keys": [&"on_kill_heal_shield"]},
	{"id": &"bruiser_earthshatter", "observation": &"damage", "upgrade_keys": [&"buff_per_destroyed_object"], "assert_arc_overlay": true},
	{"id": &"bruiser_meat_shield", "observation": &"swap", "upgrade_keys": [&"intercept_grant_str"]},
	{"id": &"bruiser_frenzy", "observation": &"damage", "upgrade_keys": [&"frenzy_on_kill_ap"]},
	{"id": &"bruiser_guttural_roar", "observation": &"aoe_displacement", "upgrade_keys": [&"push_board_items", &"item_collision_damage"], "assert_self_aoe_overlay": true},
	{"id": &"bruiser_headbutt", "observation": &"damage_status", "upgrade_keys": [&"bonus_dmg_pct_max_hp"]},
	{"id": &"bruiser_blood_boil", "observation": &"self_buff", "upgrade_keys": []},
	{"id": &"bruiser_violent_collision", "observation": &"movement", "upgrade_keys": [&"stagger_on_collision"]},
	{"id": &"bruiser_crimson_whirlwind", "observation": &"aoe_damage", "upgrade_keys": [&"heal_per_target_hit"], "assert_self_aoe_overlay": true},
	{"id": &"bruiser_belly_flop", "observation": &"movement", "upgrade_keys": [&"belly_flop_push"]},
	{"id": &"bruiser_breaching_dash", "observation": &"movement", "upgrade_keys": [&"next_attack_pierce"]},
]

const _BATCHES: Array[Dictionary] = [
	{
		"extra_players": [Vector2i(2, 2), Vector2i(2, 8), Vector2i(8, 8)],
		"dummies": [Vector2i(5, 5), Vector2i(3, 2), Vector2i(4, 8), Vector2i(7, 8)],
		"skills": [&"bruiser_push_through", &"bruiser_charge_strike", &"bruiser_concussion_blow", &"bruiser_cleave"],
	},
	{
		"extra_players": [Vector2i(2, 2), Vector2i(2, 8), Vector2i(7, 8), Vector2i(8, 8)],
		"dummies": [Vector2i(5, 5), Vector2i(4, 2), Vector2i(4, 8), Vector2i(3, 8)],
		"skills": [&"bruiser_suplex", &"bruiser_adrenaline_surge", &"bruiser_earthshatter", &"bruiser_meat_shield"],
	},
	{
		"extra_players": [Vector2i(2, 2), Vector2i(2, 8), Vector2i(8, 8)],
		"dummies": [Vector2i(5, 5), Vector2i(3, 2), Vector2i(3, 8), Vector2i(2, 3)],
		"skills": [&"bruiser_frenzy", &"bruiser_guttural_roar", &"bruiser_headbutt", &"bruiser_blood_boil"],
	},
	{
		"extra_players": [],
		"dummies": [Vector2i(5, 5), Vector2i(4, 6), Vector2i(5, 4)],
		"skills": [&"bruiser_crimson_whirlwind"],
	},
	{
		"extra_players": [Vector2i(2, 3)],
		"dummies": [Vector2i(4, 3)],
		"skills": [&"bruiser_violent_collision"],
	},
	{
		"extra_players": [Vector2i(3, 3)],
		"dummies": [Vector2i(5, 4)],
		"skills": [&"bruiser_belly_flop"],
	},
	{
		"extra_players": [Vector2i(4, 3)],
		"dummies": [],
		"skills": [&"bruiser_breaching_dash"],
	},
]

const _CASE_ACTORS: Dictionary = {
	&"bruiser_push_through": Vector2i(4, 5),
	&"bruiser_charge_strike": Vector2i(2, 2),
	&"bruiser_concussion_blow": Vector2i(2, 8),
	&"bruiser_cleave": Vector2i(8, 8),
	&"bruiser_suplex": Vector2i(4, 5),
	&"bruiser_adrenaline_surge": Vector2i(2, 2),
	&"bruiser_earthshatter": Vector2i(2, 8),
	&"bruiser_meat_shield": Vector2i(8, 8),
	&"bruiser_frenzy": Vector2i(4, 5),
	&"bruiser_guttural_roar": Vector2i(2, 2),
	&"bruiser_headbutt": Vector2i(2, 8),
	&"bruiser_blood_boil": Vector2i(8, 8),
	&"bruiser_violent_collision": Vector2i(2, 3),
	&"bruiser_crimson_whirlwind": Vector2i(4, 5),
	&"bruiser_belly_flop": Vector2i(3, 3),
	&"bruiser_breaching_dash": Vector2i(4, 3),
}

const _CASE_TARGETS: Dictionary = {
	&"bruiser_push_through": Vector2i(5, 5),
	&"bruiser_charge_strike": Vector2i(3, 2),
	&"bruiser_concussion_blow": Vector2i(4, 8),
	&"bruiser_cleave": Vector2i(7, 8),
	&"bruiser_suplex": Vector2i(5, 5),
	&"bruiser_adrenaline_surge": Vector2i(2, 2),
	&"bruiser_earthshatter": Vector2i(3, 8),
	&"bruiser_meat_shield": Vector2i(7, 8),
	&"bruiser_frenzy": Vector2i(5, 5),
	&"bruiser_guttural_roar": Vector2i(2, 2),
	&"bruiser_headbutt": Vector2i(3, 8),
	&"bruiser_blood_boil": Vector2i(8, 8),
	&"bruiser_violent_collision": Vector2i(5, 3),
	&"bruiser_crimson_whirlwind": Vector2i(4, 5),
	&"bruiser_belly_flop": Vector2i(5, 3),
	&"bruiser_breaching_dash": Vector2i(5, 3),
}

var _scene: TestBattleMapView
var _director: CombatDirector
var _input: CombatPlanningInput
var _overlay: TacticalPlanningOverlay
var _batch_target_ids: Dictionary = {}
var _factory_abilities: Dictionary = {}


func test_live_bruiser_every_skill(timeout := 300000) -> void:
	_cache_factory_abilities()
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_scene = runner.scene() as TestBattleMapView
	assert_object(_scene).is_not_null()
	if _scene == null:
		return
	for batch: Dictionary in _BATCHES:
		await _run_live_batch(runner, batch)


func _cache_factory_abilities() -> void:
	_factory_abilities.clear()
	var def: UnitData = DataLibrary.get_unit(&"bruiser")
	if def == null:
		return
	for ability: AbilityData in def.abilities:
		if ability != null:
			_factory_abilities[ability.id] = ability


func _factory_ability(skill_id: StringName) -> AbilityData:
	return _factory_abilities.get(skill_id) as AbilityData


func _run_live_batch(runner: GdUnitSceneRunner, batch: Dictionary) -> void:
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"bruiser"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.passive_enabled.clear()
	session.skill_enabled.clear()
	session.set_all_passives_enabled(&"bruiser", false)
	session.set_all_skills_enabled(&"bruiser", true)
	session.extra_player_coords = _vector2i_array(batch.extra_players)
	session.dummy_coords = _vector2i_array(batch.dummies)
	session.unkillable_dummies = true
	session.infinite_player_ap = true
	_scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)

	_director = _scene.get_node("CombatDirector") as CombatDirector
	var shell := _scene.get_node("CombatShell") as TacticalCombatShell
	_input = shell.planning_input
	_overlay = _scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	_director.auto_run = false
	for unit: UnitState in _director.base_board.units:
		if unit.definition != null and unit.definition.id == &"training_dummy":
			unit.health.current_hp = 10000
		if unit.team == GameEnums.Team.PLAYER:
			unit.ability.points_left = maxi(unit.ability.points_left, 2)
			unit.movement.points_left = maxi(unit.movement.points_left, 3)
	_batch_target_ids.clear()
	var board: BoardState = _director.base_board
	for skill_id: StringName in batch.skills:
		_batch_target_ids[skill_id] = _unit_id_at(board, _case_target_cell(skill_id))

	for skill_id: StringName in batch.skills:
		var case := _case_by_id(skill_id)
		var actor_cell := _case_actor_cell(skill_id)
		var actor_id: int = _unit_id_at(board, actor_cell)
		assert_int(actor_id).override_failure_message(
			"%s: Bruiser fixture missing actor at %s" % [skill_id, actor_cell],
		).is_greater(0)
		if actor_id < 0:
			continue
		var actor := _director.board.get_unit_by_id(actor_id)
		var ability := _ability_by_id(actor, skill_id)
		_assert_contract(ability, case)
		if ability == null:
			continue
		_director.select_unit(actor_id)
		_director.select_ability(_ability_index(actor, ability))
		await runner.simulate_frames(3, _DELTA_MS)
		if bool(case.get("assert_self_aoe_overlay", false)):
			await _assert_self_aoe_overlay_matches(
				runner, actor_id, ability, skill_id,
			)
		if bool(case.get("assert_arc_overlay", false)):
			await _assert_arc_overlay_matches(
				runner, actor_id, ability, skill_id, _case_target_cell(skill_id),
			)
		var slots: Dictionary = await _commit_live_click(
			runner, actor_id, _case_target_cell(skill_id),
		)
		if _slots_debug(slots).contains(":awaiting") or _plan_has_awaiting(actor_id):
			slots = await _commit_live_click(runner, actor_id, _case_target_cell(skill_id))
		assert_bool(_slots_invalid(slots)).override_failure_message(
			"%s: live preview/commit slots rejected a Bible-valid target: %s"
			% [skill_id, _slots_debug(slots)],
		).is_false()
		assert_bool(_plan_has_committed_skill(skill_id, actor_id)).override_failure_message(
			"%s: live commit did not write the selected skill; plan=%s"
			% [skill_id, _plan_debug()],
		).is_true()

	var result: SimResult = Simulator.simulate(_director.base_board, _director.get_player_plan())
	for skill_id: StringName in batch.skills:
		var case := _case_by_id(skill_id)
		var actor_id := _unit_id_at(_director.base_board, _case_actor_cell(skill_id))
		_assert_no_actor_failure(result.events, actor_id, skill_id)
		_assert_live_observation(result, case, actor_id)


func _assert_self_aoe_overlay_matches(
	runner: GdUnitSceneRunner,
	actor_id: int,
	ability: AbilityData,
	label: StringName,
) -> void:
	_director.select_unit(actor_id)
	var actor := _director.board.get_unit_by_id(actor_id)
	if actor == null:
		return
	var stand: Vector2i = actor.position
	_input.set_qa_pointer_grid_cell(stand)
	if _input._intent_state != null:
		_input._intent_state.set_hover_coord(stand)
	_overlay.recompute_hover_ranges(false, _director.selected_ability_index, false, -1)
	_director.flush_plan_refresh_signals_if_pending()
	await runner.simulate_frames(3, _DELTA_MS)
	var plan_board: BoardState = _director.board
	if _director.projected_state != null:
		plan_board = _director.projected_state
	var expected: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		plan_board, actor, ability, stand, [],
	)
	var overlay_tiles: Array[Vector2i] = _overlay.get_hover_action_range_tiles()
	for tile: Vector2i in expected:
		assert_bool(_overlay.is_hover_action_range_tile(tile)).override_failure_message(
			"%s: overlay missing self-AOE tile %s" % [label, tile],
		).is_true()
	for tile: Vector2i in overlay_tiles:
		assert_bool(expected.has(tile)).override_failure_message(
			"%s: overlay red tile %s outside self-AOE footprint %s" % [label, tile, expected],
		).is_true()


func _attack_hover_sync(runner: GdUnitSceneRunner, cell: Vector2i) -> void:
	_input.set_qa_pointer_grid_cell(cell)
	if _input._intent_state != null:
		_input._intent_state.set_hover_coord(cell)
	_overlay.set_hover_coord(cell, false)
	_input.on_hover_moved(cell)
	_input._flush_hover_heavy_sync()
	_input.call("_refresh_selected_interaction_preview")
	_overlay._recompute_hover_ranges_from_inputs()
	_director.flush_plan_refresh_signals_if_pending()
	await runner.simulate_frames(3, _DELTA_MS)


func _assert_arc_overlay_matches(
	runner: GdUnitSceneRunner,
	actor_id: int,
	ability: AbilityData,
	label: StringName,
	target_cell: Vector2i,
) -> void:
	_director.select_unit(actor_id)
	var actor := _director.board.get_unit_by_id(actor_id)
	if actor == null:
		return
	var stand: Vector2i = actor.position
	await _attack_hover_sync(runner, target_cell)
	var plan_board: BoardState = _director.board
	if _director.projected_state != null:
		plan_board = _director.projected_state
	var proj_actor := plan_board.get_unit_by_id(actor_id)
	if proj_actor == null:
		proj_actor = actor
	stand = proj_actor.position
	var expected: Array[Vector2i] = AbilitySystem.planning_blast_tiles_at_target(
		plan_board, proj_actor, ability, stand, target_cell,
	)
	assert_bool(not expected.is_empty()).override_failure_message(
		"%s: ARC blast footprint empty at hover %s from stand %s" % [label, target_cell, stand],
	).is_true()
	var overlay_tiles: Array[Vector2i] = _overlay.get_hover_action_range_tiles()
	for tile: Vector2i in expected:
		assert_bool(_overlay.is_hover_action_range_tile(tile)).override_failure_message(
			"%s: overlay missing ARC blast tile %s" % [label, tile],
		).is_true()
	for tile: Vector2i in overlay_tiles:
		assert_bool(expected.has(tile)).override_failure_message(
			"%s: overlay red tile %s outside ARC blast %s" % [label, tile, expected],
		).is_true()


func _assert_contract(ability: AbilityData, case: Dictionary) -> void:
	var expected: AbilityData = _factory_ability(case.id)
	assert_object(ability).override_failure_message(
		"%s: ability missing from live Bruiser loadout" % case.id,
	).is_not_null()
	assert_object(expected).override_failure_message(
		"%s: ability missing from factory template" % case.id,
	).is_not_null()
	if ability == null or expected == null:
		return
	assert_int(ability.range_tiles).override_failure_message(
		"%s: range drift live=%s factory=%s" % [case.id, ability.range_tiles, expected.range_tiles],
	).is_equal(expected.range_tiles)
	assert_int(ability.targeting_flags).override_failure_message(
		"%s: targeting flags drift" % case.id,
	).is_equal(expected.targeting_flags)
	assert_that(ability.target_shape).override_failure_message(
		"%s: target shape drift" % case.id,
	).is_equal(expected.target_shape)
	assert_int(ability.target_shape_size).override_failure_message(
		"%s: target shape size drift" % case.id,
	).is_equal(expected.target_shape_size)
	assert_bool(ability.effects.size() > 0).is_true()
	if case.upgrade_keys.size() > 0:
		assert_bool(ability.upgraded_effects.size() > 0).override_failure_message(
			"%s: compiled [+] effects must not be empty" % case.id,
		).is_true()
	var primary: EffectData = expected.effects[0]
	assert_that(ability.effects[0].type).override_failure_message(
		"%s: primary effect type drift" % case.id,
	).is_equal(primary.type)
	assert_int(ability.effects[0].amount).override_failure_message(
		"%s: primary effect amount drift" % case.id,
	).is_equal(primary.amount)
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
	if not used:
		var actor_after := result.final_state.get_unit_by_id(actor_id)
		used = (
			actor_after != null
			and actor_after.position == _case_target_cell(case.id)
			and case.observation in [&"movement", &"movement_damage"]
		)
	assert_bool(used).override_failure_message(
		"%s: committed skill never resolved; plan=%s" % [case.id, _plan_debug()],
	).is_true()

	var observation: StringName = case.observation
	if observation in [&"damage", &"movement_damage", &"damage_status", &"damage_displacement", &"aoe_damage"]:
		assert_bool(_events_have_damage(events, actor_id)).override_failure_message(
			"%s: expected damage was not observed in Simulator telemetry" % case.id,
		).is_true()
	if observation in [&"movement", &"movement_damage"]:
		assert_bool(_events_have_actor_move(events, actor_id)).override_failure_message(
			"%s: expected movement was not observed" % case.id,
		).is_true()
	if observation in [&"displacement", &"damage_displacement", &"aoe_displacement"]:
		var target_id: int = int(_batch_target_ids.get(case.id, -1))
		var target_after := result.final_state.get_unit_by_id(target_id)
		var target_moved := (
			target_after != null
			and target_after.position != _case_target_cell(case.id)
		)
		var pushed_any := false
		for event: SimEvent in events:
			if event.type == GameEnums.SimEventType.UNIT_PUSHED:
				if int(event.data.get("source", event.data.get("pusher", -1))) == actor_id:
					pushed_any = true
					break
		assert_bool(
			pushed_any or _events_have_displacement(events, actor_id) or target_moved,
		).override_failure_message(
			"%s: expected PUSH/displacement was not observed" % case.id,
		).is_true()
	if observation == &"self_buff":
		var final_actor := result.final_state.get_unit_by_id(actor_id)
		assert_bool(
			final_actor != null
			and (
				not final_actor.active_statuses.is_empty()
				or _events_have_self_damage(events, actor_id)
			),
		).override_failure_message(
			"%s: expected self buff or HP spend was not observed" % case.id,
		).is_true()
	if observation == &"swap":
		var actor_after := result.final_state.get_unit_by_id(actor_id)
		assert_bool(
			actor_after != null and actor_after.position != _case_actor_cell(case.id),
		).override_failure_message(
			"%s: expected SWAP reposition was not observed" % case.id,
		).is_true()
	if observation == &"damage_status":
		var has_stagger := false
		for event: SimEvent in events:
			if event.type == GameEnums.SimEventType.STATUS_APPLIED:
				has_stagger = true
				break
		assert_bool(has_stagger or _events_have_damage(events, actor_id)).override_failure_message(
			"%s: expected damage/status was not observed" % case.id,
		).is_true()


func _commit_live_click(
	runner: GdUnitSceneRunner,
	unit_id: int,
	cell: Vector2i,
) -> Dictionary:
	_director.select_unit(unit_id)
	var armed_action := _director.find_awaiting_action(unit_id)
	if armed_action != null and armed_action.ability != null:
		var armed_actor := _director.board.get_unit_by_id(unit_id)
		_director.select_ability(_ability_index(armed_actor, armed_action.ability))
	_input.set_qa_pointer_grid_cell(cell)
	if _input._intent_state != null:
		_input._intent_state.set_hover_coord(cell)
	var slots: Dictionary
	if _plan_has_awaiting(unit_id):
		slots = _input._build_commit_slots_at_cell(unit_id, cell)
	else:
		slots = _input._final_commit_slots_for_click_at_cell(unit_id, cell, Vector2.ZERO)
	if _slots_invalid(slots):
		return slots
	_input.call("_paint_intent_slots_before_commit", unit_id, slots)
	assert_bool(_director.commit_from_slots(unit_id, slots)).override_failure_message(
		"live commit_from_slots must accept preview slots: %s" % _slots_debug(slots),
	).is_true()
	_input.call("_promote_intent_preview_after_commit")
	_director.flush_plan_refresh_signals_if_pending()
	_input.clear_qa_pointer_override()
	await runner.simulate_frames(3, _DELTA_MS)
	return slots


func _case_by_id(skill_id: StringName) -> Dictionary:
	for case: Dictionary in _CASES:
		if case.id == skill_id:
			return case
	return {}


func _case_actor_cell(skill_id: StringName) -> Vector2i:
	return _CASE_ACTORS.get(skill_id, Vector2i(4, 5))


func _case_target_cell(skill_id: StringName) -> Vector2i:
	return _CASE_TARGETS.get(skill_id, _case_actor_cell(skill_id))


func _slots_invalid(slots: Dictionary) -> bool:
	var invalid: Variant = slots.get("invalid", false)
	return invalid is String or invalid == true


func _plan_has_committed_skill(skill_id: StringName, actor_id: int) -> bool:
	var target: Vector2i = _case_target_cell(skill_id)
	for action: TimelineAction in _director.get_player_plan().entries:
		if action.actor_id != actor_id or action.awaiting_target:
			continue
		if action.ability != null and action.ability.id == skill_id:
			return true
		if action.type == GameEnums.ActionType.MOVE and action.target_coord == target:
			return true
	return false


func _plan_has_ability(skill_id: StringName) -> bool:
	for action: TimelineAction in _director.get_player_plan().entries:
		if action.type == GameEnums.ActionType.ABILITY and action.ability != null:
			if action.ability.id == skill_id and not action.awaiting_target:
				return true
	return false


func _plan_has_awaiting(actor_id: int) -> bool:
	for action: TimelineAction in _director.get_player_plan().entries:
		if action.actor_id == actor_id and action.awaiting_target:
			return true
	return false


func _plan_debug() -> String:
	var ids: Array[String] = []
	for action: TimelineAction in _director.get_player_plan().entries:
		if action.ability != null:
			ids.append("%s@%s" % [action.ability.id, action.actor_id])
			if action.awaiting_target:
				ids[ids.size() - 1] += ":awaiting"
		else:
			ids.append("%s@%s" % [str(action.type), action.actor_id])
	return ",".join(ids)


func _slots_debug(slots: Dictionary) -> String:
	var ids: Array[String] = []
	for column: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(column, []):
			if not raw is TimelineAction:
				continue
			var action: TimelineAction = raw as TimelineAction
			var label := str(action.type)
			if action.ability != null:
				label = String(action.ability.id)
			if action.awaiting_target:
				label += ":awaiting"
			ids.append("%s=%s" % [column, label])
	return ",".join(ids)


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


func _events_have_self_damage(events: Array[SimEvent], actor_id: int) -> bool:
	for event: SimEvent in events:
		if (
			event.type == GameEnums.SimEventType.UNIT_DAMAGED
			and int(event.data.get("target", event.data.get("unit", -1))) == actor_id
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
	if raw is Array:
		for item: Variant in raw:
			if item is Vector2i:
				out.append(item)
	return out
