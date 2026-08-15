## Tier 2 live Rogue acceptance — every active skill commits through preview slots.
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _SETTLE_FRAMES: int = 8
const _DELTA_MS: int = 16
const _OVERLAY_QA := preload("res://tests/live_overlay_qa_mixin.gd")
const _MOVEMENT_QA := preload("res://tests/live_movement_timeline_qa_mixin.gd")
const _ROGUE_HARNESS := preload("res://tests/rogue_qa_harness.gd")

const _CASES: Array[StringName] = [
	&"rogue_slip_past",
	&"rogue_shadow_step",
	&"rogue_kidney_strike",
	&"rogue_smoke_bomb",
	&"rogue_evasive_strike",
	&"rogue_grappling_hook",
	&"rogue_switcheroo",
	&"rogue_blindside",
	&"rogue_throat_slit",
	&"rogue_amnesia_dust",
	&"rogue_death_mark",
	&"rogue_lethal_flourish",
	&"rogue_shadow_swap",
	&"rogue_kidnap",
	&"rogue_shuriken_volley",
	&"rogue_poison_flask",
]


const _PASSIVE_CASES: Array[Dictionary] = [
	{"passive": &"pass", "ability": &"rogue_slip_past"},
	{"passive": &"backstab", "ability": &"rogue_kidney_strike"},
	{"passive": &"blink_mastery", "ability": &"rogue_shadow_step"},
	{"passive": &"lethal_position", "ability": &"rogue_kidney_strike"},
	{"passive": &"shadow_strike", "ability": &"rogue_shadow_step"},
	{"passive": &"killing_intent", "ability": &"rogue_lethal_flourish"},
	{"passive": &"shadow_clone", "ability": &"rogue_throat_slit"},
	{"passive": &"phase_shift", "ability": &"rogue_shadow_step"},
	{"passive": &"blink_strike", "ability": &"rogue_kidney_strike"},
	{"passive": &"shadow_meld", "ability": &"rogue_smoke_bomb"},
	{"passive": &"shadow_slip", "ability": &"rogue_slip_past"},
	{"passive": &"miasma_spreader", "ability": &"rogue_lethal_flourish"},
	{"passive": &"panic_cascade", "ability": &"rogue_lethal_flourish"},
	{"passive": &"debuff_overload", "ability": &"rogue_amnesia_dust"},
	{"passive": &"mind_static", "ability": &"rogue_death_mark"},
	{"passive": &"board_scrambler", "ability": &"rogue_kidney_strike"},
]


func test_live_rogue_passive_overlay(timeout := 600000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var scene := runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	if scene == null:
		return
	var session: TestBattleSession = scene.get_session()
	for entry: Dictionary in _PASSIVE_CASES:
		var passive_id: StringName = entry.get("passive", &"") as StringName
		var ability_id: StringName = entry.get("ability", &"") as StringName
		await _run_passive_live_case(runner, scene, session, passive_id, ability_id)


func test_live_rogue_factory_loads_every_skill(timeout := 120000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var scene := runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	if scene == null:
		return
	var session := scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"rogue"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.set_all_passives_enabled(&"rogue", true)
	session.set_all_skills_enabled(&"rogue", true)
	scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var director := scene.get_node("CombatDirector") as CombatDirector
	var actor_id := _unit_id_at(director.base_board, Vector2i(4, 5))
	assert_int(actor_id).is_greater(-1)
	if actor_id < 0:
		return
	var actor := director.board.get_unit_by_id(actor_id)
	for skill_id: StringName in _CASES:
		assert_object(_ability_by_id(actor, skill_id)).override_failure_message(
			"Rogue live factory missing %s" % skill_id,
		).is_not_null()


func test_live_rogue_every_skill(timeout := 600000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var scene := runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	if scene == null:
		return
	var session: TestBattleSession = scene.get_session()
	for ability_id: StringName in _CASES:
		if ability_id == &"rogue_evasive_strike":
			await _run_evasive_live_case(runner, scene, session, false)
			await _run_evasive_live_case(runner, scene, session, true)
			continue
		await _run_live_case(runner, scene, session, ability_id, false)
		await _run_live_case(runner, scene, session, ability_id, true)


func _run_live_case(
	runner: GdUnitSceneRunner,
	scene: TestBattleMapView,
	session: TestBattleSession,
	ability_id: StringName,
	upgraded: bool,
) -> void:
	session.reset_defaults()
	session.player_class_id = &"rogue"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.passive_enabled.clear()
	session.skill_enabled.clear()
	session.set_all_passives_enabled(&"rogue", true)
	session.set_all_skills_enabled(&"rogue", true)
	session.extra_player_coords = [_ally_cell_for(ability_id)]
	session.dummy_coords = _dummy_coords_for(ability_id)
	session.unkillable_dummies = true
	scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var director := scene.get_node("CombatDirector") as CombatDirector
	var shell := scene.get_node("CombatShell") as TacticalCombatShell
	var input: CombatPlanningInput = shell.planning_input
	input.auto_use_skill_after_move = ability_id != &"rogue_evasive_strike"
	var overlay: TacticalPlanningOverlay = scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	_relocate_training_player(director.base_board, ability_id)
	if director.board != director.base_board:
		_relocate_training_player(director.board, ability_id)
	var actor_cell := _actor_cell_for(ability_id)
	var actor_id := _unit_id_at(director.base_board, actor_cell)
	var label := "%s%s" % [ability_id, " [+]" if upgraded else ""]
	assert_int(actor_id).override_failure_message(
		"%s: missing live Rogue actor at %s" % [label, actor_cell],
	).is_greater(-1)
	if actor_id < 0:
		return
	if upgraded:
		director.base_board.get_unit_by_id(actor_id).upgraded_abilities.append(ability_id)
		if director.board != director.base_board:
			director.board.get_unit_by_id(actor_id).upgraded_abilities.append(ability_id)
		director.call("_refresh_plan")
		await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var actor := director.board.get_unit_by_id(actor_id)
	var ability := _ability_by_id(actor, ability_id)
	assert_object(ability).override_failure_message(
		"%s: missing live Rogue ability" % label,
	).is_not_null()
	if ability == null:
		return
	_assert_module_contract(ability, label)
	actor.ability.points_left = maxi(actor.ability.points_left, 1)
	actor.movement.points_left = maxi(actor.movement.points_left, 8)
	var target := _target_for(ability_id, ability, actor_cell)
	_prepare_live_board(director.base_board, ability_id, actor_cell, target)
	if director.board != director.base_board:
		_prepare_live_board(director.board, ability_id, actor_cell, target)
	var premove := _premove_cell_for(ability_id, actor_cell, target)
	if premove != Vector2i(-999999, -999999):
		await _MOVEMENT_QA.commit_universal_run(
			self, runner, director, input, actor_id, premove,
		)
	var actor_before_cell := director.board.get_unit_by_id(actor_id).position
	director.select_unit(actor_id)
	director.select_ability(_ability_index(actor, ability))
	await runner.simulate_frames(2, _DELTA_MS)
	await _OVERLAY_QA.assert_live_overlay_parity(
		self, runner, overlay, input, director, actor_id, ability, target, ability_id,
	)
	var slots := await _commit_live_skill(
		runner, director, input, actor_id, ability, target, ability_id, actor_before_cell,
	)
	assert_bool(_slots_invalid(slots)).override_failure_message(
		"%s: preview rejected a Bible-valid target: %s" % [label, str(slots)],
	).is_false()
	await _MOVEMENT_QA.assert_committed(
		self, ability_id, director, actor_id, ability, slots, input, overlay, runner,
	)
	if ability_id == &"rogue_poison_flask":
		var harness_failures: Array[String] = []
		_ROGUE_HARNESS.run_single_ability(ability_id, harness_failures)
		assert_bool(harness_failures.is_empty()).override_failure_message(
			"%s: Tier 1 hazard sim failed: %s" % [label, ", ".join(harness_failures)],
		).is_true()
		return
	var result: SimResult = Simulator.simulate(
		director.base_board,
		director.get_player_plan(),
	)
	_assert_no_action_failure(result.events, actor_id, ability_id, label)
	_assert_observation(result, ability_id, actor_id, label, actor_before_cell, target)


func _run_evasive_live_case(
	runner: GdUnitSceneRunner,
	scene: TestBattleMapView,
	session: TestBattleSession,
	upgraded: bool,
) -> void:
	var ability_id := &"rogue_evasive_strike"
	session.reset_defaults()
	session.player_class_id = &"rogue"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.set_all_passives_enabled(&"rogue", true)
	session.set_all_skills_enabled(&"rogue", true)
	session.extra_player_coords = [_ally_cell_for(ability_id)]
	session.dummy_coords = [Vector2i(5, 5)]
	session.unkillable_dummies = true
	scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var director := scene.get_node("CombatDirector") as CombatDirector
	var shell := scene.get_node("CombatShell") as TacticalCombatShell
	var input: CombatPlanningInput = shell.planning_input
	input.auto_use_skill_after_move = false
	var overlay: TacticalPlanningOverlay = scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	var actor_cell := Vector2i(3, 5)
	_relocate_training_player(director.base_board, ability_id)
	if director.board != director.base_board:
		_relocate_training_player(director.board, ability_id)
	var actor_id := _unit_id_at(director.base_board, actor_cell)
	var label := "%s%s" % [ability_id, " [+]" if upgraded else ""]
	assert_int(actor_id).is_greater(-1)
	if actor_id < 0:
		return
	if upgraded:
		director.base_board.get_unit_by_id(actor_id).upgraded_abilities.append(ability_id)
		if director.board != director.base_board:
			director.board.get_unit_by_id(actor_id).upgraded_abilities.append(ability_id)
		director.call("_refresh_plan")
		await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var actor := director.board.get_unit_by_id(actor_id)
	var ability := _ability_by_id(actor, ability_id)
	assert_object(ability).is_not_null()
	if ability == null:
		return
	actor.ability.points_left = maxi(actor.ability.points_left, 2)
	actor.movement.points_left = maxi(actor.movement.points_left, 8)
	var move_target := Vector2i(4, 5)
	var attack_target := Vector2i(5, 5)
	var actor_before_cell := actor.position
	director.select_unit(actor_id)
	director.select_ability(_ability_index(actor, ability))
	await runner.simulate_frames(2, _DELTA_MS)
	await _OVERLAY_QA.assert_live_overlay_parity(
		self, runner, overlay, input, director, actor_id, ability, move_target, ability_id,
	)
	var move_slots := await _commit_live_click(
		runner, director, input, actor_id, ability, move_target,
	)
	assert_bool(_slots_invalid(move_slots)).is_false()
	if director.find_awaiting_action(actor_id) != null:
		await _OVERLAY_QA.assert_live_overlay_parity(
			self, runner, overlay, input, director, actor_id, ability, attack_target, ability_id,
		)
		var attack_slots := await _commit_live_click(
			runner, director, input, actor_id, ability, attack_target,
		)
		assert_bool(_slots_invalid(attack_slots)).is_false()
		await _MOVEMENT_QA.assert_committed(
			self, ability_id, director, actor_id, ability, attack_slots, input, overlay, runner,
		)
	var harness_failures: Array[String] = []
	_ROGUE_HARNESS.run_single_ability(ability_id, harness_failures)
	assert_bool(harness_failures.is_empty()).override_failure_message(
		"%s: Tier 1 dual-module sim failed: %s" % [label, ", ".join(harness_failures)],
	).is_true()


func _run_passive_live_case(
	runner: GdUnitSceneRunner,
	scene: TestBattleMapView,
	session: TestBattleSession,
	passive_id: StringName,
	ability_id: StringName,
) -> void:
	session.reset_defaults()
	session.player_class_id = &"rogue"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.passive_enabled.clear()
	session.skill_enabled.clear()
	session.set_all_passives_enabled(&"rogue", false)
	session.set_all_skills_enabled(&"rogue", false)
	session.passive_enabled[passive_id] = true
	session.skill_enabled[ability_id] = true
	session.extra_player_coords = [_ally_cell_for(ability_id)]
	session.dummy_coords = _dummy_coords_for(ability_id)
	session.unkillable_dummies = true
	scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var director := scene.get_node("CombatDirector") as CombatDirector
	var shell := scene.get_node("CombatShell") as TacticalCombatShell
	var input: CombatPlanningInput = shell.planning_input
	input.auto_use_skill_after_move = ability_id != &"rogue_evasive_strike"
	var overlay: TacticalPlanningOverlay = scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	_relocate_training_player(director.base_board, ability_id)
	if director.board != director.base_board:
		_relocate_training_player(director.board, ability_id)
	var actor_cell := _actor_cell_for(ability_id)
	var actor_id := _unit_id_at(director.base_board, actor_cell)
	var label := "%s/%s" % [passive_id, ability_id]
	assert_int(actor_id).override_failure_message(
		"%s: missing live Rogue actor at %s" % [label, actor_cell],
	).is_greater(-1)
	if actor_id < 0:
		return
	var actor := director.board.get_unit_by_id(actor_id)
	var ability := _ability_by_id(actor, ability_id)
	assert_object(ability).override_failure_message(
		"%s: missing ability on live Rogue" % label,
	).is_not_null()
	if ability == null:
		return
	actor.ability.points_left = maxi(actor.ability.points_left, 2)
	actor.movement.points_left = maxi(actor.movement.points_left, 8)
	var target := _target_for(ability_id, ability, actor_cell)
	var premove := _premove_cell_for(ability_id, actor_cell, target)
	if premove != Vector2i(-999999, -999999):
		await _MOVEMENT_QA.commit_universal_run(
			self, runner, director, input, actor_id, premove,
		)
	director.select_unit(actor_id)
	director.select_ability(_ability_index(actor, ability))
	await runner.simulate_frames(2, _DELTA_MS)
	await _OVERLAY_QA.assert_live_overlay_parity(
		self, runner, overlay, input, director, actor_id, ability, target, StringName(label),
	)
	var slots := await _commit_live_skill(
		runner, director, input, actor_id, ability, target, ability_id, actor_cell,
	)
	assert_bool(_slots_invalid(slots)).override_failure_message(
		"%s: preview rejected Bible-valid target: %s" % [label, str(slots)],
	).is_false()
	await _MOVEMENT_QA.assert_committed(
		self, ability_id, director, actor_id, ability, slots, input, overlay, runner,
	)
	if ability_id == &"rogue_poison_flask":
		var harness_failures: Array[String] = []
		_ROGUE_HARNESS.run_single_ability(ability_id, harness_failures)
		assert_bool(harness_failures.is_empty()).override_failure_message(
			"%s: Tier 1 hazard sim failed: %s" % [label, ", ".join(harness_failures)],
		).is_true()
		return
	var result: SimResult = Simulator.simulate(
		director.base_board,
		director.get_player_plan(),
	)
	_assert_no_action_failure(result.events, actor_id, ability_id, label)
	var passive_failures: Array[String] = []
	_ROGUE_HARNESS.run_passive_trigger_proof(passive_id, passive_failures)
	assert_bool(passive_failures.is_empty()).override_failure_message(
		"%s: Tier 1 passive trigger failed: %s" % [label, ", ".join(passive_failures)],
	).is_true()
	var upgrade_failures: Array[String] = []
	_ROGUE_HARNESS.run_passive_upgrade_for(passive_id, upgrade_failures)
	assert_bool(upgrade_failures.is_empty()).override_failure_message(
		"%s: Tier 1 passive [+] failed: %s" % [label, ", ".join(upgrade_failures)],
	).is_true()


func _committed_action_for_ability(
	director: CombatDirector,
	actor_id: int,
	ability_id: StringName,
) -> TimelineAction:
	for action: TimelineAction in director.get_player_plan().entries:
		if action.actor_id != actor_id or action.ability == null:
			continue
		if action.ability.id == ability_id:
			return action
	return null


func _simulate_committed_ability(
	director: CombatDirector,
	actor_id: int,
	ability_id: StringName,
) -> SimResult:
	var committed := _committed_action_for_ability(director, actor_id, ability_id)
	var plan := Timeline.new()
	if committed != null:
		var action: TimelineAction = committed.clone()
		action.awaiting_target = false
		plan.add(action)
	else:
		for entry: TimelineAction in director.get_player_plan().entries:
			if entry.actor_id == actor_id and entry.is_simulatable():
				plan.add(entry)
	var board := director.base_board.clone()
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	var result := SimResult.new()
	result.final_state = board
	result.events = events
	return result


func _assert_module_contract(ability: AbilityData, label: String) -> void:
	assert_bool(not ability.modules.is_empty()).override_failure_message(
		"%s: base module list is empty" % label,
	).is_true()
	assert_bool(not ability.upgraded_modules.is_empty()).override_failure_message(
		"%s: [+] module list is empty" % label,
	).is_true()
	assert_bool(ability.upgrade_description.length() > 0).override_failure_message(
		"%s: [+] description is empty" % label,
	).is_true()


func _assert_observation(
	result: SimResult,
	ability_id: StringName,
	actor_id: int,
	label: String,
	actor_before_cell: Vector2i,
	target_cell: Vector2i,
) -> void:
	var used := false
	var damaged := false
	var moved := false
	var terrain := false
	var status := false
	var displaced := false
	for event: SimEvent in result.events:
		if event.type == GameEnums.SimEventType.ABILITY_USED \
				and event.data.get("ability") == ability_id \
				and int(event.data.get("actor", -1)) == actor_id:
			used = true
		if event.type == GameEnums.SimEventType.UNIT_DAMAGED:
			damaged = true
		if event.type == GameEnums.SimEventType.UNIT_MOVED:
			moved = true
			if int(event.data.get("actor", event.data.get("unit", -1))) == actor_id:
				displaced = true
		if event.type == GameEnums.SimEventType.UNIT_PUSHED:
			displaced = true
		if event.type == GameEnums.SimEventType.TERRAIN_CHANGED:
			terrain = true
		if event.type == GameEnums.SimEventType.STATUS_APPLIED:
			status = true
	var actor_after := result.final_state.get_unit_by_id(actor_id)
	if actor_after != null and actor_after.position != actor_before_cell:
		displaced = true
	var target_unit := result.final_state.get_unit_at(target_cell)
	if target_unit != null and not target_unit.active_statuses.is_empty():
		status = true
	var target_tile := result.final_state.get_tile(target_cell)
	if target_tile != null and target_tile.definition != null \
			and target_tile.definition.id not in [&"plain", &""]:
		terrain = true
	assert_bool(used).override_failure_message(
		"%s: Simulator did not resolve committed ability" % label,
	).is_true()
	match ability_id:
		&"rogue_slip_past", &"rogue_shadow_step", &"rogue_evasive_strike":
			assert_bool(displaced or moved).override_failure_message(
				"%s: expected movement observation" % label,
			).is_true()
		&"rogue_smoke_bomb", &"rogue_poison_flask":
			assert_bool(terrain or status).override_failure_message(
				"%s: expected hazard or status observation" % label,
			).is_true()
		&"rogue_death_mark", &"rogue_amnesia_dust":
			assert_bool(status).override_failure_message(
				"%s: expected mark/status observation" % label,
			).is_true()
		&"rogue_switcheroo", &"rogue_shadow_swap", &"rogue_kidnap", &"rogue_grappling_hook":
			assert_bool(displaced or moved or damaged or status).override_failure_message(
				"%s: expected reposition observation" % label,
			).is_true()
		_:
			assert_bool(damaged or displaced or status or terrain).override_failure_message(
				"%s: expected combat observation" % label,
			).is_true()


func _dummy_coords_for(ability_id: StringName) -> Array[Vector2i]:
	match ability_id:
		&"rogue_smoke_bomb":
			return []
		&"rogue_shadow_swap":
			return [Vector2i(6, 5)]
		&"rogue_slip_past", &"rogue_kidnap":
			return [Vector2i(5, 5)]
		&"rogue_shadow_step", &"rogue_kidney_strike", &"rogue_blindside", &"rogue_throat_slit", &"rogue_lethal_flourish", &"rogue_kidnap", &"rogue_switcheroo":
			return [Vector2i(5, 5)]
		&"rogue_shuriken_volley", &"rogue_grappling_hook", &"rogue_death_mark", &"rogue_amnesia_dust":
			return [Vector2i(6, 5), Vector2i(7, 5)]
		&"rogue_poison_flask":
			return [Vector2i(6, 5)]
		_:
			return [Vector2i(5, 5)]


func _ally_cell_for(ability_id: StringName) -> Vector2i:
	if ability_id == &"rogue_shadow_swap":
		return Vector2i(3, 5)
	return Vector2i(3, 4)


func _actor_cell_for(ability_id: StringName) -> Vector2i:
	match ability_id:
		&"rogue_slip_past", &"rogue_kidnap":
			return Vector2i(4, 5)
		&"rogue_evasive_strike":
			return Vector2i(3, 5)
		_:
			return Vector2i(4, 5)


func _premove_cell_for(
	ability_id: StringName,
	actor_cell: Vector2i,
	target: Vector2i,
) -> Vector2i:
	if ability_id in [&"rogue_smoke_bomb", &"rogue_shadow_swap", &"rogue_shadow_step"]:
		return Vector2i(-999999, -999999)
	if GridSystem.manhattan(actor_cell, target) > 1:
		return actor_cell + Vector2i(
			signi(target.x - actor_cell.x),
			signi(target.y - actor_cell.y),
		)
	return Vector2i(-999999, -999999)


func _prepare_live_board(
	_board: BoardState,
	_ability_id: StringName,
	_actor_cell: Vector2i,
	_target: Vector2i,
) -> void:
	pass


func _relocate_training_player(board: BoardState, ability_id: StringName) -> void:
	var cell := _actor_cell_for(ability_id)
	var player := _find_player_unit(board)
	if player == null or player.position == cell:
		return
	GridSystem.set_occupant(board, player.position, -1)
	player.position = cell
	GridSystem.set_occupant(board, cell, player.id)


func _find_player_unit(board: BoardState) -> UnitState:
	for unit: UnitState in board.units:
		if unit.team == GameEnums.Team.PLAYER:
			return unit
	return null


func _target_for(
	ability_id: StringName,
	ability: AbilityData,
	actor_cell: Vector2i,
) -> Vector2i:
	if ability.targeting_flags & GameEnums.TargetingFlags.SELF:
		return actor_cell
	match ability_id:
		&"rogue_slip_past":
			return Vector2i(5, 5)
		&"rogue_shadow_step":
			return actor_cell + Vector2i(1, -1)
		&"rogue_kidney_strike", &"rogue_blindside", &"rogue_throat_slit", &"rogue_lethal_flourish", &"rogue_kidnap", &"rogue_switcheroo":
			return actor_cell + Vector2i(1, 0)
		&"rogue_grappling_hook", &"rogue_death_mark", &"rogue_amnesia_dust", &"rogue_shuriken_volley", &"rogue_poison_flask":
			return actor_cell + Vector2i(2, 0)
		&"rogue_evasive_strike":
			return actor_cell + Vector2i(1, 0)
		&"rogue_shadow_swap":
			return Vector2i(3, 5)
		&"rogue_shuriken_volley":
			return actor_cell + Vector2i(2, -1)
		&"rogue_poison_flask":
			return actor_cell + Vector2i(2, 0)
		_:
			return actor_cell + Vector2i(2, 0)


func _ability_by_id(actor: UnitState, ability_id: StringName) -> AbilityData:
	for ability: AbilityData in actor.active_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


func _ability_index(actor: UnitState, ability: AbilityData) -> int:
	for index: int in range(actor.active_abilities.size()):
		var candidate: AbilityData = actor.active_abilities[index]
		if candidate == ability or (
			candidate != null and ability != null and candidate.id == ability.id
		):
			return index
	return -1


func _unit_id_at(board: BoardState, coord: Vector2i) -> int:
	var unit := board.get_unit_at(coord)
	return unit.id if unit != null else -1


func _slots_invalid(slots: Dictionary) -> bool:
	var invalid: Variant = slots.get("invalid", false)
	if invalid is bool:
		return invalid
	if invalid is String:
		return not (invalid as String).is_empty()
	return not is_zero_approx(float(invalid))


func _commit_live_skill(
	runner: GdUnitSceneRunner,
	director: CombatDirector,
	input: CombatPlanningInput,
	actor_id: int,
	ability: AbilityData,
	target: Vector2i,
	ability_id: StringName,
	actor_cell: Vector2i,
) -> Dictionary:
	var slots := await _commit_live_click(
		runner, director, input, actor_id, ability, target,
	)
	var attempts := 0
	while not _slots_invalid(slots) and director.find_awaiting_action(actor_id) != null and attempts < 3:
		var follow_up := target
		if ability_id == &"rogue_evasive_strike":
			follow_up = target + Vector2i(1, 0)
		slots = await _commit_live_click(runner, director, input, actor_id, ability, follow_up)
		attempts += 1
	return slots


func _commit_live_click(
	runner: GdUnitSceneRunner,
	director: CombatDirector,
	input: CombatPlanningInput,
	actor_id: int,
	ability: AbilityData,
	cell: Vector2i,
) -> Dictionary:
	director.select_unit(actor_id)
	var awaiting := director.find_awaiting_action(actor_id)
	if awaiting != null and awaiting.ability != null:
		var actor := director.board.get_unit_by_id(actor_id)
		director.select_ability(_ability_index(actor, awaiting.ability))
	input.set_qa_pointer_grid_cell(cell)
	input._intent_state.set_hover_coord(cell)
	input.on_hover_moved(cell)
	input._flush_hover_heavy_sync()
	var actor := director.board.get_unit_by_id(actor_id)
	var should_arm := (
		awaiting == null
		and AbilitySystem.planning_commit_flow(actor, ability)
			== GameEnums.PlanningCommitFlow.AWAITING_TARGET
	)
	var slots: Dictionary
	if should_arm:
		slots = input._final_commit_slots_for_click_at_cell(
			actor_id, actor.position, Vector2.ZERO,
		)
		if _slots_invalid(slots):
			return slots
		input.call("_paint_intent_slots_before_commit", actor_id, slots)
		if not director.commit_from_slots(actor_id, slots):
			return {"invalid": "initial target arm rejected"}
		await runner.simulate_frames(2, _DELTA_MS)
	if director.find_awaiting_action(actor_id) != null:
		slots = input._build_commit_slots_at_cell(actor_id, cell)
	else:
		slots = input._final_commit_slots_for_click_at_cell(
			actor_id, cell, Vector2.ZERO,
		)
	if _slots_invalid(slots):
		return slots
	input.call("_paint_intent_slots_before_commit", actor_id, slots)
	if not director.commit_from_slots(actor_id, slots):
		return {"invalid": "commit rejected preview slots"}
	input.call("_promote_intent_preview_after_commit")
	director.flush_plan_refresh_signals_if_pending()
	input.clear_qa_pointer_override()
	await runner.simulate_frames(2, _DELTA_MS)
	return slots


func _assert_no_action_failure(
	events: Array[SimEvent],
	actor_id: int,
	ability_id: StringName,
	label: String,
) -> void:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.ACTION_FAILED \
				and int(event.data.get("actor", -1)) == actor_id:
			assert_that("").override_failure_message(
				"%s: committed intent failed: %s" % [label, event.data],
			).is_equal("never")
