extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"


const _SETTLE_FRAMES: int = 8
const _DELTA_MS: int = 16
const _ACTOR_CELL := Vector2i(4, 5)
const _ALLY_CELL := Vector2i(3, 5)
const _ENEMY_CELL := Vector2i(6, 5)
const _TILE_CELL := Vector2i(4, 4)
const _OVERLAY_QA := preload("res://tests/live_overlay_qa_mixin.gd")
const _MOVEMENT_QA := preload("res://tests/live_movement_timeline_qa_mixin.gd")

const _CASES: Array[Dictionary] = [
	{"id": &"mage_blink", "target": _TILE_CELL, "kind": &"movement", "effect": GameEnums.EffectType.TELEPORT_CASTER},
	{"id": &"mage_fireball", "target": _ENEMY_CELL, "kind": &"damage_terrain", "effect": GameEnums.EffectType.DAMAGE},
	{"id": &"mage_ice_shard", "target": _ENEMY_CELL, "kind": &"damage_status", "effect": GameEnums.EffectType.DAMAGE},
	{"id": &"mage_chain_lightning", "target": _ENEMY_CELL, "kind": &"damage", "effect": GameEnums.EffectType.DAMAGE},
	{"id": &"mage_arcane_push", "target": _ENEMY_CELL, "kind": &"damage_displacement", "effect": GameEnums.EffectType.DAMAGE},
	{"id": &"mage_teleport", "target": Vector2i(4, 3), "kind": &"movement", "effect": GameEnums.EffectType.TELEPORT_CASTER},
	{"id": &"mage_meteor", "target": _ENEMY_CELL, "kind": &"delayed_damage", "effect": GameEnums.EffectType.DAMAGE},
	{"id": &"mage_black_hole", "target": _ENEMY_CELL, "kind": &"displacement", "effect": GameEnums.EffectType.PULL},
	{"id": &"mage_time_warp", "target": _ALLY_CELL, "kind": &"ally_status", "effect": GameEnums.EffectType.DAMAGE_SELF},
	{"id": &"mage_mana_shield", "target": _ACTOR_CELL, "kind": &"self_status", "effect": GameEnums.EffectType.ARMOR_UP},
	{"id": &"mage_disintegrate", "target": _ENEMY_CELL, "kind": &"damage", "effect": GameEnums.EffectType.DAMAGE},
	{"id": &"mage_gravity_well", "target": _ENEMY_CELL, "kind": &"status", "effect": GameEnums.EffectType.ADD_STATUS},
	{"id": &"mage_elemental_surge", "target": _ACTOR_CELL, "kind": &"self_status", "effect": GameEnums.EffectType.ADD_STATUS_SELF},
	{"id": &"mage_earth_spike", "target": _TILE_CELL, "kind": &"spawn", "effect": GameEnums.EffectType.SPAWN},
	{"id": &"mage_density_shift", "target": _ENEMY_CELL, "kind": &"status", "effect": GameEnums.EffectType.ADD_STATUS},
	{"id": &"mage_arcane_barrage", "target": _ENEMY_CELL, "kind": &"damage", "effect": GameEnums.EffectType.DAMAGE},
]

var _scene: TestBattleMapView
var _director: CombatDirector
var _input: CombatPlanningInput
var _overlay: TacticalPlanningOverlay


func test_live_mage_every_skill(timeout := 300000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_scene = runner.scene() as TestBattleMapView
	assert_object(_scene).is_not_null()
	if _scene == null:
		return
	for case: Dictionary in _CASES:
		await _run_case(runner, case)
		await _run_upgrade_case(runner, case)


func _run_case(runner: GdUnitSceneRunner, case: Dictionary) -> void:
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"mage"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.passive_enabled.clear()
	session.skill_enabled.clear()
	session.set_all_passives_enabled(&"mage", true)
	session.set_all_skills_enabled(&"mage", true)
	session.extra_player_coords = [_ALLY_CELL]
	session.dummy_coords = [_ENEMY_CELL, Vector2i(7, 5)]
	session.unkillable_dummies = true
	_scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_director = _scene.get_node("CombatDirector") as CombatDirector
	var shell := _scene.get_node("CombatShell") as TacticalCombatShell
	_input = shell.planning_input
	_overlay = _scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	_director.auto_run = String(case.get("kind", "")) == "movement"
	var actor_id := _unit_id_at(_director.base_board, _ACTOR_CELL)
	assert_int(actor_id).override_failure_message(
		"%s: Mage actor missing from TestBattle" % case.id,
	).is_greater(-1)
	if actor_id < 0:
		return
	var actor := _director.board.get_unit_by_id(actor_id)
	actor.ability.points_left = maxi(actor.ability.points_left, 1)
	actor.movement.points_left = maxi(actor.movement.points_left, 3)
	var ability := _ability_by_id(actor, case.id)
	_assert_contract(ability, case)
	if ability == null:
		return
	_director.select_unit(actor_id)
	await _MOVEMENT_QA.commit_premove_run_if_needed(
		self,
		runner,
		_director,
		_input,
		actor_id,
		ability,
		_MOVEMENT_QA.default_premove_run_cell(_ACTOR_CELL, case.target),
		_overlay,
	)
	_director.select_ability(_ability_index(actor, ability))
	await runner.simulate_frames(3, _DELTA_MS)
	var target_cell: Vector2i = case.target
	if ability.range_tiles <= 0:
		target_cell = actor.position
	await _OVERLAY_QA.assert_live_overlay_parity(
		self, runner, _overlay, _input, _director, actor_id, ability, target_cell, case.id,
	)
	_assert_teleport_direct_hop(actor, ability, target_cell, case.id)
	var slots := await _commit_click(runner, actor_id, case.target)
	assert_bool(_slots_invalid(slots)).override_failure_message(
		"%s: valid live target rejected by commit slots: %s" % [case.id, slots],
	).is_false()
	assert_bool(_plan_has_ability(case.id)).override_failure_message(
		"%s: commit did not ratify the preview intent" % case.id,
	).is_true()
	await _MOVEMENT_QA.commit_premove_run_if_needed(
		self,
		runner,
		_director,
		_input,
		actor_id,
		ability,
		Vector2i(-999999, -999999),
		_overlay,
	)
	await _MOVEMENT_QA.assert_committed(
		self, case.id, _director, actor_id, ability, slots, _input, _overlay, runner,
	)
	var result: SimResult = Simulator.simulate(
		_director.base_board,
		_director.get_player_plan(),
	)
	_assert_no_action_failure(result.events, actor_id, case.id)
	_assert_observation(result, case, actor_id)


func _run_upgrade_case(runner: GdUnitSceneRunner, case: Dictionary) -> void:
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"mage"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.passive_enabled.clear()
	session.skill_enabled.clear()
	session.set_all_passives_enabled(&"mage", true)
	session.set_all_skills_enabled(&"mage", true)
	session.extra_player_coords = [_ALLY_CELL]
	session.dummy_coords = [_ENEMY_CELL, Vector2i(7, 5)]
	session.unkillable_dummies = true
	_scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_director = _scene.get_node("CombatDirector") as CombatDirector
	var shell := _scene.get_node("CombatShell") as TacticalCombatShell
	_input = shell.planning_input
	_overlay = _scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	_director.auto_run = String(case.get("kind", "")) == "movement"
	var actor_id := _unit_id_at(_director.base_board, _ACTOR_CELL)
	assert_int(actor_id).override_failure_message(
		"%s [+]: Mage actor missing from TestBattle" % case.id,
	).is_greater(-1)
	if actor_id < 0:
		return
	var base_actor: UnitState = _director.base_board.get_unit_by_id(actor_id)
	base_actor.upgraded_abilities.append(case.id)
	_director.call("_refresh_plan")
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var actor := _director.board.get_unit_by_id(actor_id)
	actor.ability.points_left = maxi(actor.ability.points_left, 1)
	actor.movement.points_left = maxi(actor.movement.points_left, 3)
	var ability := _ability_by_id(actor, case.id)
	_assert_contract(ability, case)
	if ability == null:
		return
	_director.select_unit(actor_id)
	await _MOVEMENT_QA.commit_premove_run_if_needed(
		self,
		runner,
		_director,
		_input,
		actor_id,
		ability,
		_MOVEMENT_QA.default_premove_run_cell(_ACTOR_CELL, case.target),
		_overlay,
	)
	_director.select_ability(_ability_index(actor, ability))
	await runner.simulate_frames(3, _DELTA_MS)
	var target_cell: Vector2i = case.target
	if ability.range_tiles <= 0:
		target_cell = actor.position
	await _OVERLAY_QA.assert_live_overlay_parity(
		self, runner, _overlay, _input, _director, actor_id, ability, target_cell, case.id,
	)
	_assert_teleport_direct_hop(actor, ability, target_cell, str(case.id) + " [+]")
	var slots := await _commit_click(runner, actor_id, case.target)
	assert_bool(_slots_invalid(slots)).override_failure_message(
		"%s [+]: valid live target rejected by commit slots: %s" % [case.id, slots],
	).is_false()
	assert_bool(_plan_has_ability(case.id)).override_failure_message(
		"%s [+]: commit did not ratify the preview intent" % case.id,
	).is_true()
	await _MOVEMENT_QA.commit_premove_run_if_needed(
		self,
		runner,
		_director,
		_input,
		actor_id,
		ability,
		Vector2i(-999999, -999999),
		_overlay,
	)
	await _MOVEMENT_QA.assert_committed(
		self, case.id, _director, actor_id, ability, slots, _input, _overlay, runner,
	)
	var result: SimResult = Simulator.simulate(
		_director.base_board,
		_director.get_player_plan(),
	)
	_assert_no_action_failure(result.events, actor_id, case.id)
	_assert_observation(result, case, actor_id)


func _assert_contract(ability: AbilityData, case: Dictionary) -> void:
	assert_object(ability).override_failure_message(
		"%s: missing authored Mage ability" % case.id,
	).is_not_null()
	if ability == null:
		return
	assert_bool(ability.effects.size() > 0).override_failure_message(
		"%s: base effect list is empty" % case.id,
	).is_true()
	assert_bool(ability.upgraded_effects.size() > 0).override_failure_message(
		"%s: [+] effect list is empty" % case.id,
	).is_true()
	assert_bool(ability.upgrade_description.length() > 0).override_failure_message(
		"%s: [+] description is empty" % case.id,
	).is_true()
	assert_that(ability.effects[0].type).override_failure_message(
		"%s: primary effect type mismatch" % case.id,
	).is_equal(case.effect)


func _assert_teleport_direct_hop(
	actor: UnitState,
	ability: AbilityData,
	target_cell: Vector2i,
	label: String,
) -> void:
	if not AbilitySystem.ability_uses_caster_teleport(ability, actor):
		return
	if (
		_director.find_awaiting_action(actor.id) == null
		and not _input.awaiting_targeting_active()
	):
		return
	var hop: Array[Vector2i] = _overlay.awaiting_movement_hover_route_cells()
	assert_int(hop.size()).override_failure_message(
		"%s: teleport hover must be a direct hop; route=%s" % [label, str(hop)],
	).is_equal(2)
	if hop.size() < 2:
		return
	assert_that(hop[1]).override_failure_message(
		"%s: teleport hop dest must be the aimed tile; route=%s" % [label, str(hop)],
	).is_equal(target_cell)
	if GridSystem.manhattan(hop[0], hop[1]) <= 1:
		return
	assert_int(hop.size()).override_failure_message(
		"%s: teleport must not insert cardinal walk tiles; route=%s" % [label, str(hop)],
	).is_equal(2)


func _assert_observation(result: SimResult, case: Dictionary, actor_id: int) -> void:
	var used := false
	var damaged := false
	var moved := false
	var terrain := false
	var spawned := false
	for event: SimEvent in result.events:
		if event.type == GameEnums.SimEventType.ABILITY_USED \
				and event.data.get("ability") == case.id \
				and int(event.data.get("actor", -1)) == actor_id:
			used = true
		if event.type == GameEnums.SimEventType.UNIT_DAMAGED:
			damaged = true
		if event.type == GameEnums.SimEventType.UNIT_MOVED \
				and int(event.data.get("actor", event.data.get("unit", -1))) == actor_id:
			moved = true
		if event.type == GameEnums.SimEventType.TERRAIN_CHANGED:
			terrain = true
		if event.type == GameEnums.SimEventType.UNIT_SPAWNED:
			spawned = true
	assert_bool(used).override_failure_message(
		"%s: Simulator did not resolve committed ability" % case.id,
	).is_true()
	match case.kind:
		&"movement":
			assert_bool(moved).override_failure_message(
				"%s: expected movement observation" % case.id,
			).is_true()
		&"damage", &"damage_status", &"damage_displacement":
			assert_bool(damaged).override_failure_message(
				"%s: expected damage observation" % case.id,
			).is_true()
		&"damage_terrain":
			assert_bool(damaged and terrain).override_failure_message(
				"%s: expected damage and terrain observations" % case.id,
			).is_true()
		&"delayed_damage":
			assert_bool(damaged or not result.final_state.delayed_effects.is_empty()).override_failure_message(
				"%s: expected immediate queue or delayed impact" % case.id,
			).is_true()
		&"spawn":
			assert_bool(spawned).override_failure_message(
				"%s: expected construct spawn observation" % case.id,
			).is_true()
		_:
			assert_bool(
				damaged or not result.final_state.get_unit_by_id(actor_id).active_statuses.is_empty()
				or not result.final_state.get_unit_by_id(actor_id).passive_flags.is_empty(),
			).override_failure_message(
				"%s: expected status, displacement, or resource observation" % case.id,
			).is_true()


func _commit_click(runner: GdUnitSceneRunner, actor_id: int, cell: Vector2i) -> Dictionary:
	_input.set_qa_pointer_grid_cell(cell)
	if _input._intent_state != null:
		_input._intent_state.set_hover_coord(cell)
	var actor: UnitState = _director.board.get_unit_by_id(actor_id)
	var ability: AbilityData = CombatDirector.resolve_selected_ability(
		actor, _director.selected_ability_index,
	)
	var should_arm: bool = (
		_director.find_awaiting_action(actor_id) == null
		and actor != null
		and ability != null
		and AbilitySystem.planning_commit_flow(actor, ability)
			== GameEnums.PlanningCommitFlow.AWAITING_TARGET
	)
	var stand_cell: Vector2i = CombatPlanningPreview.planning_latest_stand_cell(
		_director, _director.board, actor_id,
	)
	var first_cell: Vector2i = stand_cell if should_arm else cell
	var slots: Dictionary = _input._final_commit_slots_for_click_at_cell(
		actor_id, first_cell, Vector2.ZERO,
	)
	if _slots_invalid(slots):
		return slots
	_input.call("_paint_intent_slots_before_commit", actor_id, slots)
	assert_bool(_director.commit_from_slots(actor_id, slots)).is_true()
	if _director.find_awaiting_action(actor_id) != null:
		_input.on_hover_moved(cell)
		_input._flush_hover_heavy_sync()
		slots = _input._build_commit_slots_at_cell(actor_id, cell)
		if _slots_invalid(slots):
			return slots
		_input.call("_paint_intent_slots_before_commit", actor_id, slots)
		assert_bool(_director.commit_from_slots(actor_id, slots)).is_true()
	_input.call("_promote_intent_preview_after_commit")
	_director.flush_plan_refresh_signals_if_pending()
	_input.clear_qa_pointer_override()
	await runner.simulate_frames(3, _DELTA_MS)
	return slots


func _slots_invalid(slots: Dictionary) -> bool:
	var invalid: Variant = slots.get("invalid", false)
	return invalid is String or invalid == true


func _plan_has_ability(ability_id: StringName) -> bool:
	for action: TimelineAction in _director.get_player_plan().entries:
		if action.ability != null and action.ability.id == ability_id and not action.awaiting_target:
			return true
	return false


func _assert_no_action_failure(events: Array[SimEvent], actor_id: int, ability_id: StringName) -> void:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ACTION_FAILED \
				and int(event.data.get("actor", -1)) == actor_id:
			assert_that("").override_failure_message(
				"%s: committed intent failed: %s" % [ability_id, event.data],
			).is_equal("never")


func _unit_id_at(board: BoardState, cell: Vector2i) -> int:
	var unit := board.get_unit_at(cell)
	return unit.id if unit != null else -1


func _ability_by_id(unit: UnitState, ability_id: StringName) -> AbilityData:
	for ability: AbilityData in unit.active_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


func _ability_index(unit: UnitState, ability: AbilityData) -> int:
	for index: int in range(unit.active_abilities.size()):
		if unit.active_abilities[index] == ability:
			return index
	return -1
