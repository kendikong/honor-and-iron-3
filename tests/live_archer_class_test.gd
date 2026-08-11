## Tier 2 live Archer acceptance.
##
## Four Archers act in parallel batches. Each case validates the authored
## range/targeting/shape contract and commits through the real preview slots.
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _ACTOR_CELL := Vector2i(4, 5)
const _SETTLE_FRAMES := 8
const _DELTA_MS := 16
const _OVERLAY_QA := preload("res://tests/live_overlay_qa_mixin.gd")
const _MOVEMENT_QA := preload("res://tests/live_movement_timeline_qa_mixin.gd")

const _CASES: Array[Dictionary] = [
	{"id": &"archer_sidestep", "range": 1, "flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.MOVE,
		"amount": 1, "kind": &"tile", "actor": Vector2i(1, 5), "target": Vector2i(0, 5),
		"observe": &"movement"},
	{"id": &"archer_basic", "range": 1, "flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 1, "kind": &"enemy", "actor": Vector2i(4, 5), "target": Vector2i(6, 5),
		"observe": &"damage"},
	{"id": &"archer_power_shot", "range": 5, "flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 3, "kind": &"enemy", "actor": Vector2i(2, 2), "target": Vector2i(6, 2),
		"observe": &"damage"},
	{"id": &"archer_volley", "range": 4, "flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.AOE_SQUARE, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 1, "kind": &"tile", "actor": Vector2i(2, 8), "target": Vector2i(5, 8),
		"observe": &"damage"},
	{"id": &"archer_pinning_arrow", "range": 4, "flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 1, "kind": &"enemy", "actor": Vector2i(8, 8), "target": Vector2i(8, 6),
		"observe": &"status"},
	{"id": &"archer_piercing_shot", "range": 4,
		"flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.LINE, "size": 4, "type": GameEnums.EffectType.DAMAGE,
		"amount": 2, "kind": &"enemy", "actor": Vector2i(4, 5), "target": Vector2i(8, 5),
		"observe": &"damage"},
	{"id": &"archer_toxic_spore_arrow", "range": 5, "flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 1, "kind": &"enemy", "actor": Vector2i(2, 2), "target": Vector2i(6, 2),
		"observe": &"status"},
	{"id": &"archer_grapple_arrow", "range": 4,
		"flags": GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.PULL,
		"amount": 1, "kind": &"tile", "actor": Vector2i(2, 8), "target": Vector2i(6, 8),
		"observe": &"ability"},
	{"id": &"archer_explosive_arrow", "range": 4,
		"flags": GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.AOE_CROSS, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 2, "kind": &"tile", "actor": Vector2i(8, 8), "target": Vector2i(8, 6),
		"observe": &"damage"},
	{"id": &"archer_hunters_mark", "range": 5, "flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.ADD_STATUS,
		"amount": 1, "kind": &"enemy", "actor": Vector2i(4, 5), "target": Vector2i(6, 5),
		"observe": &"status"},
	{"id": &"archer_repelling_shot", "range": 2,
		"flags": GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 1, "kind": &"enemy", "actor": Vector2i(2, 4), "target": Vector2i(5, 4),
		"observe": &"damage"},
	{"id": &"archer_bear_trap", "range": 3, "flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.CREATE_HAZARD,
		"amount": 3, "kind": &"tile", "actor": Vector2i(2, 8), "target": Vector2i(5, 8),
		"observe": &"terrain"},
	{"id": &"archer_suppressing_fire", "range": 5, "flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.ARC, "size": 1, "type": GameEnums.EffectType.CREATE_HAZARD,
		"amount": 1, "kind": &"tile", "actor": Vector2i(8, 8), "target": Vector2i(8, 5),
		"observe": &"terrain"},
	{"id": &"archer_caltrop_trap", "range": 3, "flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.CREATE_HAZARD,
		"amount": 1, "kind": &"tile", "actor": Vector2i(4, 5), "target": Vector2i(5, 5),
		"observe": &"terrain"},
	{"id": &"archer_parting_shot", "range": 3, "flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.DAMAGE,
		"amount": 2, "kind": &"enemy", "actor": Vector2i(2, 2), "target": Vector2i(5, 2),
		"observe": &"damage"},
	{"id": &"archer_scouts_eye", "range": 5, "flags": GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE, "size": 1, "type": GameEnums.EffectType.PURGE,
		"amount": 0, "kind": &"enemy", "actor": Vector2i(8, 8), "target": Vector2i(8, 5),
		"observe": &"ability"},
]

const _BATCHES: Array[Array] = [
	[&"archer_basic", &"archer_power_shot", &"archer_volley", &"archer_pinning_arrow"],
	[&"archer_piercing_shot", &"archer_toxic_spore_arrow", &"archer_grapple_arrow", &"archer_explosive_arrow"],
	[&"archer_hunters_mark", &"archer_repelling_shot", &"archer_bear_trap", &"archer_suppressing_fire"],
	[&"archer_caltrop_trap", &"archer_parting_shot", &"archer_scouts_eye"],
	[&"archer_sidestep"],
]

var _scene: TestBattleMapView
var _director: CombatDirector
var _input: CombatPlanningInput
var _overlay: TacticalPlanningOverlay


func test_live_archer_every_skill(timeout := 240000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_scene = runner.scene() as TestBattleMapView
	assert_object(_scene).is_not_null()
	if _scene == null:
		return
	for batch: Array in _BATCHES:
		await _run_live_batch(runner, batch)


func _run_live_batch(runner: GdUnitSceneRunner, skill_ids: Array) -> void:
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"archer"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.passive_enabled.clear()
	session.skill_enabled.clear()
	session.set_all_passives_enabled(&"archer", false)
	session.set_all_skills_enabled(&"archer", true)
	session.extra_player_coords = _extra_players(skill_ids)
	session.dummy_coords = _dummies(skill_ids)
	session.unkillable_dummies = true
	_scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_director = _scene.get_node("CombatDirector") as CombatDirector
	var shell := _scene.get_node("CombatShell") as TacticalCombatShell
	_input = shell.planning_input
	_overlay = _scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	_director.auto_run = false
	for skill_id: StringName in skill_ids:
		var case := _case(skill_id)
		var actor_id := _unit_id_at(_director.base_board, case.actor)
		assert_int(actor_id).override_failure_message(
			"%s: missing four-Archer actor at %s" % [skill_id, case.actor],
		).is_greater(0)
		if actor_id < 0:
			continue
		var actor := _director.board.get_unit_by_id(actor_id)
		var ability := _ability_by_id(actor, skill_id)
		_assert_contract(ability, case)
		if ability == null:
			continue
		_director.select_unit(actor_id)
		await _MOVEMENT_QA.commit_premove_run_if_needed(
			self,
			runner,
			_director,
			_input,
			actor_id,
			ability,
			_MOVEMENT_QA.default_premove_run_cell(case.actor, case.target),
			_overlay,
		)
		_director.select_ability(_ability_index(actor, ability))
		await runner.simulate_frames(2, _DELTA_MS)
		await _OVERLAY_QA.assert_live_overlay_parity(
			self, runner, _overlay, _input, _director, actor_id, ability, case.target, skill_id,
		)
		var slots := await _commit_live_click(
			runner,
			actor_id,
			case.target,
		)
		if _slots_invalid(slots) or _plan_has_awaiting(actor_id):
			slots = await _commit_live_click(runner, actor_id, case.target)
		assert_bool(_slots_invalid(slots)).override_failure_message(
			"%s: preview rejected a Bible-valid target: %s" % [skill_id, _slots_debug(slots)],
		).is_false()
		assert_bool(_plan_has_ability(skill_id)).override_failure_message(
			"%s: commit did not write the ability; plan=%s" % [skill_id, _plan_debug()],
		).is_true()
		await _MOVEMENT_QA.assert_committed(
			self, skill_id, _director, actor_id, ability, slots, _input, _overlay, runner,
		)
	var result: SimResult = Simulator.simulate(_director.base_board, _director.get_player_plan())
	for skill_id: StringName in skill_ids:
		var case := _case(skill_id)
		var actor_id := _unit_id_at(_director.base_board, case.actor)
		_assert_live_result(result, case, actor_id)


func _assert_contract(ability: AbilityData, case: Dictionary) -> void:
	assert_object(ability).override_failure_message(
		"%s: ability missing from live Archer loadout" % case.id,
	).is_not_null()
	if ability == null:
		return
	var module := AbilitySystem.active_module_for_index(null, ability, 0)
	assert_object(module).override_failure_message(
		"%s: missing authored primary module" % case.id,
	).is_not_null()
	if module == null:
		return
	assert_int(module.max_range).is_equal(int(case.range))
	assert_int(AbilitySystem.active_targeting_flags(null, ability)).is_equal(int(case.flags))
	assert_that(module.target_shape).is_equal(case.shape)
	assert_int(module.target_shape_size).is_equal(int(case.size))
	assert_that(module.primary_type).is_equal(case.type)
	assert_int(module.amount).is_equal(int(case.amount))
	if case.id != &"archer_basic":
		assert_bool(not ability.upgraded_modules.is_empty()).is_true()


func _assert_live_result(result: SimResult, case: Dictionary, actor_id: int) -> void:
	var used := false
	var observed := false
	for event: SimEvent in result.events:
		if (
			event.type == GameEnums.SimEventType.ACTION_FAILED
			and int(event.data.get("actor", -1)) == actor_id
		):
			assert_that("").override_failure_message(
				"%s: Simulator rejected the committed intent: %s" % [case.id, event.data],
			).is_equal("never")
		if (
			event.type == GameEnums.SimEventType.ABILITY_USED
			and event.data.get("ability", &"") == case.id
			and int(event.data.get("actor", -1)) == actor_id
		):
			used = true
		if case.observe == &"damage" and event.type == GameEnums.SimEventType.UNIT_DAMAGED:
			observed = true
		if case.observe == &"status" and event.type == GameEnums.SimEventType.STATUS_APPLIED:
			observed = true
		if case.observe == &"terrain" and event.type == GameEnums.SimEventType.TERRAIN_CHANGED:
			observed = true
		if case.observe == &"displacement" and event.type == GameEnums.SimEventType.UNIT_PUSHED:
			observed = true
		if (
			case.observe == &"displacement"
			and event.type == GameEnums.SimEventType.UNIT_MOVED
			and int(event.data.get("unit", -1)) != actor_id
		):
			observed = true
		if (
			case.observe == &"movement"
			and event.type == GameEnums.SimEventType.UNIT_MOVED
			and int(event.data.get("unit", -1)) == actor_id
		):
			observed = true
	if case.observe == &"ability":
		observed = used
	assert_bool(used).override_failure_message(
		"%s: committed skill never resolved; plan=%s" % [case.id, _plan_debug()],
	).is_true()
	if case.observe == &"movement":
		var final_actor: UnitState = result.final_state.get_unit_by_id(actor_id)
		if final_actor != null and final_actor.position == case.target:
			observed = true
	assert_bool(observed).override_failure_message(
		"%s: authored effect was not observed in live simulation" % case.id,
	).is_true()


func _commit_live_click(
	runner: GdUnitSceneRunner,
	unit_id: int,
	cell: Vector2i,
) -> Dictionary:
	_director.select_unit(unit_id)
	var awaiting := _director.find_awaiting_action(unit_id)
	if awaiting != null and awaiting.ability != null:
		var actor := _director.board.get_unit_by_id(unit_id)
		_director.select_ability(_ability_index(actor, awaiting.ability))
	_input.set_qa_pointer_grid_cell(cell)
	_input._intent_state.set_hover_coord(cell)
	var actor := _director.board.get_unit_by_id(unit_id)
	var ability := CombatDirector.resolve_selected_ability(
		actor, _director.selected_ability_index,
	)
	var should_arm := (
		_director.find_awaiting_action(unit_id) == null
		and actor != null
		and ability != null
		and AbilitySystem.planning_commit_flow(actor, ability)
			== GameEnums.PlanningCommitFlow.AWAITING_TARGET
	)
	var slots: Dictionary
	if should_arm:
		slots = _input._final_commit_slots_for_click_at_cell(
			unit_id, actor.position, Vector2.ZERO,
		)
		if _slots_invalid(slots):
			return slots
		_input.call("_paint_intent_slots_before_commit", unit_id, slots)
		assert_bool(_director.commit_from_slots(unit_id, slots)).is_true()
		await runner.simulate_frames(2, _DELTA_MS)
	if _plan_has_awaiting(unit_id):
		slots = _input._build_commit_slots_at_cell(unit_id, cell)
	else:
		slots = _input._final_commit_slots_for_click_at_cell(unit_id, cell, Vector2.ZERO)
	if _slots_invalid(slots):
		return slots
	_input.call("_paint_intent_slots_before_commit", unit_id, slots)
	assert_bool(_director.commit_from_slots(unit_id, slots)).is_true()
	_input.call("_promote_intent_preview_after_commit")
	_director.flush_plan_refresh_signals_if_pending()
	_input.clear_qa_pointer_override()
	await runner.simulate_frames(2, _DELTA_MS)
	return slots


func _case(skill_id: StringName) -> Dictionary:
	for item: Dictionary in _CASES:
		if item.id == skill_id:
			return item
	return {}


func _extra_players(skill_ids: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for skill_id: StringName in skill_ids:
		var position: Vector2i = _case(skill_id).actor
		if position != _ACTOR_CELL:
			result.append(position)
		if skill_id == &"archer_repelling_shot":
			continue
	if result.size() < 3:
		result.append(Vector2i(2, 8))
	return result


func _dummies(skill_ids: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for skill_id: StringName in skill_ids:
		var item := _case(skill_id)
		if item.kind == &"enemy":
			result.append(item.target)
	result.append_array([Vector2i(5, 6), Vector2i(7, 7)])
	return result


func _slots_invalid(slots: Dictionary) -> bool:
	var invalid: Variant = slots.get("invalid", false)
	return invalid is String or invalid == true


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
		ids.append(
			"%s@%d%s" % [
				action.ability.id if action.ability != null else str(action.type),
				action.actor_id,
				":awaiting" if action.awaiting_target else "",
			],
		)
	return ",".join(ids)


func _slots_debug(slots: Dictionary) -> String:
	var result: Array[String] = []
	for column: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(column, []):
			if raw is TimelineAction:
				var action: TimelineAction = raw as TimelineAction
				result.append("%s=%s" % [column, action.ability.id if action.ability != null else str(action.type)])
	return ",".join(result)


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


func _unit_id_at(board: BoardState, cell: Vector2i) -> int:
	if board == null:
		return -1
	for unit: UnitState in board.units:
		if unit != null and unit.position == cell:
			return unit.id
	return -1
