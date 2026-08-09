## Tier 2 live Cleric acceptance.
## Every revised Cleric ability is selected and committed through the live
## TacticalCombat preview/slot pipeline.
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _OVERLAY_QA := preload("res://tests/live_overlay_qa_mixin.gd")
const _MOVEMENT_QA := preload("res://tests/live_movement_timeline_qa_mixin.gd")

const _CASES: Array[Dictionary] = [
	{"id": &"cleric_guardian_step", "actor": Vector2i(2, 2), "target": Vector2i(3, 2)},
	{"id": &"cleric_holy_light", "actor": Vector2i(4, 2), "target": Vector2i(3, 2)},
	{"id": &"cleric_smite", "actor": Vector2i(2, 5), "target": Vector2i(4, 5)},
	{"id": &"cleric_cleansing_aura", "actor": Vector2i(5, 5), "target": Vector2i(5, 5)},
	{"id": &"cleric_sanctuary", "actor": Vector2i(8, 2), "target": Vector2i(7, 2)},
	{"id": &"cleric_blinding_ray", "actor": Vector2i(2, 8), "target": Vector2i(4, 8)},
	{"id": &"cleric_divine_hammer", "actor": Vector2i(5, 8), "target": Vector2i(6, 8)},
	{"id": &"cleric_life_link", "actor": Vector2i(8, 8), "target": Vector2i(7, 8)},
	{"id": &"cleric_prayer_of_fortitude", "actor": Vector2i(4, 5), "target": Vector2i(4, 4)},
	{"id": &"cleric_resurrection", "actor": Vector2i(6, 6), "target": Vector2i(6, 5)},
	{"id": &"cleric_consecrate_ground", "actor": Vector2i(7, 7), "target": Vector2i(7, 7)},
	{"id": &"cleric_holy_wrath", "actor": Vector2i(8, 5), "target": Vector2i(7, 5)},
	{"id": &"cleric_divine_guidance", "actor": Vector2i(3, 7), "target": Vector2i(3, 6)},
	{"id": &"cleric_shield_of_faith", "actor": Vector2i(5, 3), "target": Vector2i(5, 2)},
	{"id": &"cleric_martyrs_chains", "actor": Vector2i(7, 3), "target": Vector2i(7, 5)},
]


func test_live_cleric_every_skill(timeout := 240000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(8, 16)
	var scene := runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	if scene == null:
		return
	var session: TestBattleSession = scene.get_session()
	for item: Dictionary in _CASES:
		session.reset_defaults()
		session.player_class_id = &"cleric"
		session.player_level = TestBattleSession.TRAINING_LEVEL
		session.passive_enabled.clear()
		session.skill_enabled.clear()
		session.set_all_passives_enabled(&"cleric", true)
		session.set_all_skills_enabled(&"cleric", true)
		session.extra_player_coords = _player_coords(item)
		session.dummy_coords = _enemy_target(item)
		session.unkillable_dummies = true
		scene.apply_training_board()
		await runner.simulate_frames(8, 16)
		var director := scene.get_node("CombatDirector") as CombatDirector
		var shell := scene.get_node("CombatShell") as TacticalCombatShell
		var input: CombatPlanningInput = shell.planning_input
		var overlay: TacticalPlanningOverlay = scene.get_node(
			"WorldModulate/MapRoot/PlanningOverlay",
		) as TacticalPlanningOverlay
		var actor_id := _unit_id_at(director.base_board, item.actor)
		assert_int(actor_id).override_failure_message(
			"%s: missing live Cleric actor" % item.id
		).is_greater(0)
		if actor_id < 0:
			continue
		var actor := director.board.get_unit_by_id(actor_id)
		var ability := _ability_by_id(actor, item.id)
		assert_object(ability).override_failure_message(
			"%s: missing live Cleric ability" % item.id
		).is_not_null()
		if ability == null:
			continue
		director.select_unit(actor_id)
		await _MOVEMENT_QA.commit_premove_run_if_needed(
			self,
			runner,
			director,
			input,
			actor_id,
			ability,
			_MOVEMENT_QA.default_postmove_cell(item.actor, item.target),
		)
		director.select_ability(_ability_index(actor, ability))
		await runner.simulate_frames(2, 16)
		var target_cell: Vector2i = item.target
		if ability.range_tiles <= 0:
			target_cell = actor.position
		await _OVERLAY_QA.assert_live_overlay_parity(
			self, runner, overlay, input, director, actor_id, ability, target_cell, item.id,
		)
		input._intent_state.set_hover_coord(item.target)
		var slots: Dictionary = input._build_commit_slots_at_cell(actor_id, item.target)
		var first_action: TimelineAction = _first_slot_action(slots)
		if first_action != null and first_action.awaiting_target:
			slots = input._final_commit_slots_for_click_at_cell(
				actor_id, actor.position, Vector2.ZERO,
			)
		assert_bool(_slots_invalid(slots)).override_failure_message(
			"%s: live preview rejected target %s" % [item.id, item.target]
		).is_false()
		if _slots_invalid(slots):
			continue
		input.call("_paint_intent_slots_before_commit", actor_id, slots)
		assert_bool(director.commit_from_slots(actor_id, slots)).override_failure_message(
			"%s: live commit rejected slots" % item.id
		).is_true()
		if director.find_awaiting_action(actor_id) != null:
			slots = input._final_commit_slots_for_click_at_cell(
				actor_id, item.target, Vector2.ZERO,
			)
			assert_bool(_slots_invalid(slots)).override_failure_message(
				"%s: live target-finalization rejected target %s" % [item.id, item.target]
			).is_false()
			if _slots_invalid(slots):
				continue
			input.call("_paint_intent_slots_before_commit", actor_id, slots)
			assert_bool(director.commit_from_slots(actor_id, slots)).override_failure_message(
				"%s: live target-finalization rejected slots" % item.id
			).is_true()
		_MOVEMENT_QA.assert_committed(
			self, item.id, director, actor_id, ability, slots,
		)
		director.flush_plan_refresh_signals_if_pending()
		await runner.simulate_frames(2, 16)
		var result := Simulator.simulate(director.base_board, director.get_player_plan())
		var used := false
		for event: SimEvent in result.events:
			if (
				event.type == GameEnums.SimEventType.ACTION_FAILED
				and int(event.data.get("actor", -1)) == actor_id
			):
				assert_that("").override_failure_message(
					"%s: execution rejected committed intent: %s" % [item.id, event.data]
				).is_equal("never")
			if (
				event.type == GameEnums.SimEventType.ABILITY_USED
				and event.data.get("ability", &"") == item.id
			):
				used = true
		assert_bool(used).override_failure_message(
			"%s: committed ability did not resolve" % item.id
		).is_true()


func _player_coords(item: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if item.actor != Vector2i(4, 5):
		result.append(item.actor)
	if item.id in [
		&"cleric_guardian_step", &"cleric_holy_light", &"cleric_life_link",
		&"cleric_prayer_of_fortitude", &"cleric_resurrection",
		&"cleric_divine_guidance", &"cleric_shield_of_faith",
	] and item.target not in result:
		result.append(item.target)
	return result


func _enemy_target(item: Dictionary) -> Array[Vector2i]:
	if item.id in [
		&"cleric_smite", &"cleric_blinding_ray", &"cleric_holy_wrath",
		&"cleric_martyrs_chains",
	]:
		var result: Array[Vector2i] = [item.target]
		if item.id == &"cleric_martyrs_chains":
			result.append(item.target + Vector2i(0, 1))
		return result
	return []


func _ability_by_id(unit: UnitState, ability_id: StringName) -> AbilityData:
	if unit == null:
		return null
	for ability: AbilityData in unit.active_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


func _ability_index(unit: UnitState, ability: AbilityData) -> int:
	for index: int in range(unit.active_abilities.size()):
		if unit.active_abilities[index] == ability:
			return index
	return -1


func _unit_id_at(board: BoardState, cell: Vector2i) -> int:
	for unit: UnitState in board.units:
		if unit != null and unit.position == cell:
			return unit.id
	return -1


func _slots_invalid(slots: Dictionary) -> bool:
	var invalid: Variant = slots.get("invalid", false)
	return invalid is String or invalid == true


func _first_slot_action(slots: Dictionary) -> TimelineAction:
	for column: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(column, []):
			if raw is TimelineAction:
				return raw as TimelineAction
	return null
