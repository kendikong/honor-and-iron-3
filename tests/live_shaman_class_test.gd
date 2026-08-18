## Tier 2 live Shaman acceptance — every authored skill uses preview slots.
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _OVERLAY_QA := preload("res://tests/live_overlay_qa_mixin.gd")
const _MOVEMENT_QA := preload("res://tests/live_movement_timeline_qa_mixin.gd")
const _CASES: Array[StringName] = [
	&"shaman_usher", &"shaman_curse_of_weakness", &"shaman_healing_totem",
	&"shaman_flame_totem", &"shaman_bloodlust", &"shaman_hex",
	&"shaman_voodoo_link", &"shaman_terrify", &"shaman_miasma",
	&"shaman_bone_spear", &"shaman_ancestral_spirit", &"shaman_totem_guard",
	&"shaman_sympathetic_bond", &"shaman_earthbind_totem",
	&"shaman_soul_siphon", &"shaman_pain_spike",
]

const _ACTOR_CELL := Vector2i(4, 5)
const _ALLY_CELL := Vector2i(3, 5)
const _TARGET_CELL := Vector2i(6, 5)


func test_live_shaman_every_skill(timeout := 600000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(8, 16)
	var scene := runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	if scene == null:
		return
	var session: TestBattleSession = scene.get_session()
	for ability_id: StringName in _CASES:
		session.reset_defaults()
		session.player_class_id = &"shaman"
		session.player_level = TestBattleSession.TRAINING_LEVEL
		session.passive_enabled.clear()
		session.skill_enabled.clear()
		session.set_all_passives_enabled(&"shaman", true)
		session.set_all_skills_enabled(&"shaman", true)
		session.extra_player_coords = [_ALLY_CELL]
		session.dummy_coords = _dummy_coords_for(ability_id)
		session.unkillable_dummies = true
		scene.apply_training_board()
		await runner.simulate_frames(8, 16)
		var director := scene.get_node("CombatDirector") as CombatDirector
		var shell := scene.get_node("CombatShell") as TacticalCombatShell
		var input: CombatPlanningInput = shell.planning_input
		var overlay: TacticalPlanningOverlay = scene.get_node(
			"WorldModulate/MapRoot/PlanningOverlay",
		) as TacticalPlanningOverlay
		var actor_id := _unit_id_at(director.base_board, _ACTOR_CELL)
		assert_int(actor_id).override_failure_message(
			"%s: missing live Shaman actor" % ability_id,
		).is_greater(-1)
		if actor_id < 0:
			continue
		var actor := director.board.get_unit_by_id(actor_id)
		var ability := _ability_by_id(actor, ability_id)
		assert_object(ability).override_failure_message(
			"%s: missing live Shaman ability" % ability_id,
		).is_not_null()
		if ability == null:
			continue
		actor.ability.points_left = maxi(actor.ability.points_left, 1)
		actor.movement.points_left = maxi(actor.movement.points_left, 8)
		var target := _target_for(ability_id)
		if ability_id == &"shaman_hex":
			for hex_board: BoardState in [director.base_board, director.board]:
				var hex_target := hex_board.get_unit_at(_TARGET_CELL)
				if hex_target != null:
					hex_target.health.current_hp = maxi(
						1, hex_target.health.max_hp - 1,
					)
		elif ability_id == &"shaman_terrify":
			for terrify_board: BoardState in [director.base_board, director.board]:
				var terrify_target := terrify_board.get_unit_at(_TARGET_CELL)
				if terrify_target != null:
					terrify_target.active_statuses.append(
						DataLibrary.make_status(GameEnums.StatusType.WEAKEN, 1)
					)
		elif ability_id == &"shaman_ancestral_spirit":
			var corpse_boards: Array[BoardState] = [director.base_board, director.board]
			if director.projected_state != null:
				corpse_boards.append(director.projected_state)
			for corpse_board: BoardState in corpse_boards:
				for unit: UnitState in corpse_board.units:
					if (
						unit != null
						and unit.position == _ALLY_CELL
						and unit.team == GameEnums.Team.PLAYER
						and unit.id != actor_id
					):
						unit.health.current_hp = 0
						GridSystem.set_occupant(corpse_board, unit.position, -1)
		director.select_unit(actor_id)
		if ability_id == &"shaman_usher":
			target = _ALLY_CELL
		await _MOVEMENT_QA.commit_premove_run_if_needed(
			self, runner, director, input, actor_id, ability,
			_MOVEMENT_QA.default_premove_run_cell(_ACTOR_CELL, target), overlay,
		)
		director.select_ability(_ability_index(actor, ability))
		await runner.simulate_frames(3, 16)
		await _OVERLAY_QA.assert_live_overlay_parity(
			self, runner, overlay, input, director, actor_id, ability, target, ability_id,
		)
		var slots := await _commit_live_click(
			runner, director, input, actor_id, ability, target, _second_target_for(ability_id),
		)
		assert_bool(_slots_invalid(slots)).override_failure_message(
			"%s: valid preview target rejected: %s" % [ability_id, slots],
		).is_false()
		assert_bool(_plan_has_ability(director, ability_id)).override_failure_message(
			"%s: commit did not ratify preview intent plan=[%s]" % [ability_id, _plan_debug(director)],
		).is_true()
		if ability_id == &"shaman_totem_guard":
			var guard_result: SimResult = Simulator.simulate(
				director.base_board, director.get_player_plan(),
			)
			var simulated_caster := guard_result.final_state.get_unit_by_id(actor_id)
			assert_object(simulated_caster).override_failure_message(
				"Totem Guard simulation lost its caster",
			).is_not_null()
			var expected_reduction: int = (
				floori(simulated_caster.current_magic / 2.0)
				if simulated_caster != null else -1
			)
			var found_guard_totem := false
			for spawned: UnitState in guard_result.final_state.units:
				if (
					spawned != null
					and spawned.passive_flags.get("shaman_totem_kind", &"") == &"guard"
					and int(spawned.passive_flags.get("shaman_totem_owner_id", -1)) == actor_id
				):
					found_guard_totem = true
					assert_int(
						int(spawned.passive_flags.get("shaman_guard_ranged_reduction", -1)),
					).override_failure_message(
						"Totem Guard live plan must use Floor(MAG / 2); actual=%s expected=%s"
						% [
							int(spawned.passive_flags.get("shaman_guard_ranged_reduction", -1)),
							expected_reduction,
						],
					).is_equal(expected_reduction)
			assert_bool(found_guard_totem).override_failure_message(
				"Totem Guard live plan did not spawn its guard totem",
			).is_true()


func _dummy_coords_for(ability_id: StringName) -> Array[Vector2i]:
	if ability_id in [
		&"shaman_healing_totem", &"shaman_flame_totem", &"shaman_totem_guard",
		&"shaman_earthbind_totem",
	]:
		return [_ALLY_CELL]
	if ability_id in [&"shaman_usher", &"shaman_ancestral_spirit"]:
		return []
	return [_TARGET_CELL, Vector2i(7, 5)]


func _target_for(ability_id: StringName) -> Vector2i:
	if ability_id in [&"shaman_usher", &"shaman_ancestral_spirit", &"shaman_bloodlust", &"shaman_sympathetic_bond"]:
		return _ALLY_CELL
	return _TARGET_CELL


func _second_target_for(ability_id: StringName) -> Vector2i:
	if ability_id == &"shaman_usher":
		return Vector2i(3, 4)
	if ability_id == &"shaman_voodoo_link":
		return Vector2i(7, 5)
	if ability_id == &"shaman_sympathetic_bond":
		return _TARGET_CELL
	return Vector2i(-1, -1)


func _ability_by_id(actor: UnitState, ability_id: StringName) -> AbilityData:
	for ability: AbilityData in actor.active_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


func _ability_index(actor: UnitState, ability: AbilityData) -> int:
	for index: int in range(actor.active_abilities.size()):
		if actor.active_abilities[index] == ability:
			return index
	return -1


func _unit_id_at(board: BoardState, coord: Vector2i) -> int:
	var unit := board.get_unit_at(coord)
	return unit.id if unit != null else -1


func _slots_invalid(slots: Dictionary) -> bool:
	var invalid: Variant = slots.get("invalid", false)
	return invalid is String or invalid == true


func _plan_has_ability(director: CombatDirector, ability_id: StringName) -> bool:
	for action: TimelineAction in director.get_player_plan().entries:
		if action.ability != null and action.ability.id == ability_id and not action.awaiting_target:
			return true
	return false


func _plan_debug(director: CombatDirector) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for action: TimelineAction in director.get_player_plan().entries:
		if action.ability != null:
			parts.append("%s await=%s" % [action.ability.id, action.awaiting_target])
		elif action.type == GameEnums.ActionType.MOVE:
			parts.append("MOVE %s" % action.target_coord)
		else:
			parts.append("type=%s" % action.type)
	return ", ".join(parts)


func _commit_live_click(
	runner: GdUnitSceneRunner,
	director: CombatDirector,
	input: CombatPlanningInput,
	actor_id: int,
	ability: AbilityData,
	cell: Vector2i,
	second_cell: Vector2i = Vector2i(-1, -1),
) -> Dictionary:
	input.set_qa_pointer_grid_cell(cell)
	input._intent_state.set_hover_coord(cell)
	input.on_hover_moved(cell)
	input._flush_hover_heavy_sync()
	var actor := director.board.get_unit_by_id(actor_id)
	var selected_ability := CombatDirector.resolve_selected_ability(
		actor, director.selected_ability_index,
	)
	var needs_arm := (
		director.find_awaiting_action(actor_id) == null
		and actor != null
		and selected_ability != null
		and AbilitySystem.planning_commit_flow(actor, selected_ability)
			== GameEnums.PlanningCommitFlow.AWAITING_TARGET
		and director.board.get_unit_at(cell) == null
		and AbilitySystem.ally_corpse_at(director.board, actor, cell) == null
	)
	var slots: Dictionary = {}
	if needs_arm:
		var stand_cell := CombatPlanningPreview.planning_latest_stand_cell(
			director, director.board, actor_id,
		)
		slots = input._final_commit_slots_for_click_at_cell(actor_id, stand_cell, Vector2.ZERO)
		if _slots_invalid(slots):
			return slots
		input.call("_paint_intent_slots_before_commit", actor_id, slots)
		if not director.commit_from_slots(actor_id, slots):
			return {"invalid": "initial arm rejected"}
	slots = input._final_commit_slots_for_click_at_cell(actor_id, cell, Vector2.ZERO)
	if _slots_invalid(slots):
		return slots
	input.call("_paint_intent_slots_before_commit", actor_id, slots)
	if not director.commit_from_slots(actor_id, slots):
		return {"invalid": "preview commit rejected"}
	if director.find_awaiting_action(actor_id) != null:
		var finish_cell: Vector2i = (
			second_cell if second_cell != Vector2i(-1, -1) else cell
		)
		input.on_hover_moved(finish_cell)
		input._flush_hover_heavy_sync()
		slots = input._final_commit_slots_for_click_at_cell(actor_id, finish_cell, Vector2.ZERO)
		if _slots_invalid(slots):
			return slots
		input.call("_paint_intent_slots_before_commit", actor_id, slots)
		if not director.commit_from_slots(actor_id, slots):
			return {"invalid": "second pick rejected"}
	input.call("_promote_intent_preview_after_commit")
	director.flush_plan_refresh_signals_if_pending()
	input.clear_qa_pointer_override()
	await runner.simulate_frames(2, 16)
	return slots
