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
const _OVERLAY_QA := preload("res://tests/live_overlay_qa_mixin.gd")
const _TRAMPLE_DRAG := preload("res://tests/trampling_advance_e2e_test.gd")
const _MOVEMENT_QA := preload("res://tests/live_movement_timeline_qa_mixin.gd")

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
		"range": 3,
		"flags": GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		"shape": GameEnums.TargetShape.SINGLE,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.DASH,
		"primary_amount": 3,
		"observation": &"movement_damage",
		"target_kind": &"tile",
		"target": Vector2i(6, 5),
		"dummies": [Vector2i(5, 5)],
		"upgrade_keys": [&"create_trampled_terrain"],
	},
	{
		"id": &"lancer_sweeping_halberd",
		"range": 2,
		"flags": GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.ARC,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.DAMAGE,
		"primary_amount": 2,
		"observation": &"damage_displacement",
		"target_kind": &"enemy",
		"target": Vector2i(6, 5),
		"dummies": [Vector2i(6, 5)],
		"upgrade_keys": [&"stagger_on_collision"],
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
		"upgrade_keys": [&"pull_self_if_rooted"],
	},
	{
		"id": &"lancer_glorious_charge",
		"range": 4,
		"flags": GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.SINGLE,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.DASH,
		"primary_amount": 4,
		"observation": &"movement_damage",
		"target_kind": &"enemy",
		"target": Vector2i(9, 5),
		"dummies": [Vector2i(9, 5)],
		"extra_players": _PUSH_EXTRA_PLAYERS,
		"upgrade_keys": [&"create_trampled_terrain", &"kill_grant_ap"],
	},
	{
		"id": &"lancer_pole_vault",
		"range": 3,
		"flags": GameEnums.TargetingFlags.TILE,
		"shape": GameEnums.TargetShape.SINGLE,
		"shape_size": 1,
		"primary_type": GameEnums.EffectType.JUMP_TO_BEHIND,
		"primary_amount": 3,
		"observation": &"movement",
		"target_kind": &"tile",
		"target": Vector2i(6, 4),
		"dummies": [Vector2i(8, 8)],
		"upgrade_keys": [&"vault_obstacle_or_gap_only", &"landing_adjacent_push"],
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
		"shape_size": 1,
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
		"primary_type": GameEnums.EffectType.JUMP,
		"primary_amount": 2,
		"observation": &"movement_damage",
		"target_kind": &"tile",
		"target": Vector2i(6, 5),
		"dummies": [Vector2i(6, 4)],
		"upgrade_keys": [],
	},
]

const _CASE_ACTORS: Dictionary = {
	&"lancer_basic": Vector2i(2, 8),
	&"lancer_push": Vector2i(4, 5),
	&"lancer_piercing_charge": Vector2i(8, 8),
	&"lancer_sweeping_halberd": Vector2i(8, 8),
	&"lancer_vaulting_leap": Vector2i(4, 5),
	&"lancer_run_down": Vector2i(2, 2),
	&"lancer_rallying_cry": Vector2i(2, 8),
	&"lancer_flanking_maneuver": Vector2i(2, 3),
	&"lancer_brace": Vector2i(4, 5),
	&"lancer_harpoon_toss": Vector2i(2, 2),
	&"lancer_pole_vault": Vector2i(4, 4),
	&"lancer_glorious_charge": Vector2i(5, 5),
	&"lancer_line_breaker": Vector2i(4, 5),
	&"lancer_spear_wall": Vector2i(2, 2),
	&"lancer_meteor_drop": Vector2i(2, 8),
}

const _CASE_TARGETS: Dictionary = {
	&"lancer_basic": Vector2i(2, 6),
	&"lancer_push": Vector2i(5, 5),
	&"lancer_piercing_charge": Vector2i(8, 6),
	&"lancer_sweeping_halberd": Vector2i(8, 6),
	&"lancer_vaulting_leap": Vector2i(6, 5),
	&"lancer_run_down": Vector2i(4, 2),
	&"lancer_rallying_cry": Vector2i(2, 8),
	&"lancer_flanking_maneuver": Vector2i(3, 4),
	&"lancer_brace": Vector2i(4, 5),
	&"lancer_harpoon_toss": Vector2i(6, 2),
	&"lancer_pole_vault": Vector2i(6, 4),
	&"lancer_glorious_charge": Vector2i(9, 5),
	&"lancer_line_breaker": Vector2i(8, 5),
	&"lancer_spear_wall": Vector2i(4, 2),
	&"lancer_meteor_drop": Vector2i(2, 6),
}

const _CASE_PREMOVE_RUN: Dictionary = {
	&"lancer_piercing_charge": Vector2i(8, 7),
	&"lancer_meteor_drop": Vector2i(2, 7),
	&"lancer_line_breaker": Vector2i(5, 5),
}

const _FIXTURES: Dictionary = {
	&"lancer_basic": {
		"extra_players": [Vector2i(2, 8), Vector2i(5, 5), Vector2i(8, 8)],
		"dummies": [Vector2i(2, 6), Vector2i(8, 7)],
	},
	&"lancer_push": {
		"extra_players": _PUSH_EXTRA_PLAYERS,
		"dummies": [Vector2i(2, 6), Vector2i(8, 7)],
	},
	&"lancer_piercing_charge": {
		"extra_players": [Vector2i(5, 5), Vector2i(2, 8), Vector2i(8, 8)],
		"dummies": [Vector2i(2, 6), Vector2i(8, 4)],
	},
	&"lancer_sweeping_halberd": {
		"extra_players": [Vector2i(2, 2), Vector2i(2, 8), Vector2i(8, 8)],
		"dummies": [Vector2i(8, 6), Vector2i(6, 5), Vector2i(4, 2)],
	},
	&"lancer_vaulting_leap": {
		"extra_players": [Vector2i(2, 2), Vector2i(2, 8), Vector2i(8, 8)],
		"dummies": [Vector2i(8, 6), Vector2i(6, 5), Vector2i(4, 2)],
	},
	&"lancer_run_down": {
		"extra_players": [Vector2i(2, 2), Vector2i(2, 8), Vector2i(8, 8)],
		"dummies": [Vector2i(8, 6), Vector2i(6, 5), Vector2i(4, 2)],
	},
	&"lancer_rallying_cry": {
		"extra_players": [Vector2i(2, 2), Vector2i(2, 8), Vector2i(8, 8)],
		"dummies": [Vector2i(8, 6), Vector2i(6, 5), Vector2i(4, 2)],
	},
	&"lancer_brace": {
		"extra_players": [Vector2i(2, 2), Vector2i(4, 4), Vector2i(5, 5)],
		"dummies": [Vector2i(6, 2), Vector2i(4, 3), Vector2i(9, 5)],
	},
	&"lancer_harpoon_toss": {
		"extra_players": [Vector2i(2, 2), Vector2i(4, 4), Vector2i(5, 5)],
		"dummies": [Vector2i(6, 2), Vector2i(4, 3), Vector2i(9, 5)],
	},
	&"lancer_pole_vault": {
		"extra_players": [Vector2i(2, 2), Vector2i(4, 4), Vector2i(5, 4)],
		"dummies": [Vector2i(6, 2), Vector2i(4, 3), Vector2i(8, 8)],
	},
	&"lancer_glorious_charge": {
		"extra_players": [Vector2i(2, 2), Vector2i(4, 4), Vector2i(5, 5)],
		"dummies": [Vector2i(9, 5)],
	},
	&"lancer_line_breaker": {
		"extra_players": [Vector2i(3, 5), Vector2i(2, 8), Vector2i(8, 8)],
		"dummies": [Vector2i(6, 5), Vector2i(7, 5)],
	},
	&"lancer_spear_wall": {
		"extra_players": [Vector2i(2, 2), Vector2i(2, 8), Vector2i(8, 8)],
		"dummies": [
			Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
			Vector2i(2, 5), Vector2i(7, 6),
		],
	},
	&"lancer_meteor_drop": {
		"extra_players": [Vector2i(2, 2), Vector2i(2, 8), Vector2i(8, 8)],
		"dummies": [
			Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
			Vector2i(6, 4),
		],
	},
	&"lancer_flanking_maneuver": {
		"extra_players": [Vector2i(2, 3), Vector2i(2, 8), Vector2i(8, 8)],
		"dummies": [Vector2i(4, 4)],
	},
}

const _CASE_ALLIES: Dictionary = {
	&"lancer_push": Vector2i(5, 5),
}

var _scene: TestBattleMapView
var _director: CombatDirector
var _input: CombatPlanningInput
var _overlay: TacticalPlanningOverlay
var _batch_base_board: BoardState
var _batch_actor_ids: Dictionary = {}
var _batch_target_ids: Dictionary = {}


func test_live_lancer_every_skill(timeout := 240000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_scene = runner.scene() as TestBattleMapView
	assert_object(_scene).is_not_null()
	if _scene == null:
		return

	for case: Dictionary in _CASES:
		await _run_skill_journey(runner, case.id)


func _run_skill_journey(runner: GdUnitSceneRunner, skill_id: StringName) -> void:
	var fixture: Dictionary = _FIXTURES.get(skill_id, {})
	assert_bool(not fixture.is_empty()).override_failure_message(
		"%s: missing live fixture" % skill_id,
	).is_true()
	if fixture.is_empty():
		return
	await _run_live_batch(runner, {
		"extra_players": fixture.get("extra_players", []),
		"dummies": fixture.get("dummies", []),
		"skills": [skill_id],
	})


func _run_live_batch(runner: GdUnitSceneRunner, batch: Dictionary) -> void:
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"lancer"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.passive_enabled.clear()
	session.skill_enabled.clear()
	session.set_all_passives_enabled(&"lancer", false)
	session.set_all_skills_enabled(&"lancer", true)
	session.extra_player_coords = _vector2i_array(batch.extra_players)
	session.dummy_coords = _vector2i_array(batch.dummies)
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
	var listed_case := _case_by_id(batch.skills[0] if batch.skills.size() > 0 else &"")
	if batch.skills.size() == 1:
		var only_skill: StringName = batch.skills[0]
		_director.auto_run = only_skill in [
			&"lancer_piercing_charge",
			&"lancer_meteor_drop",
		]
	else:
		for listed_skill: StringName in batch.skills:
			listed_case = _case_by_id(listed_skill)
			var obs: String = String(listed_case.get("observation", ""))
			if obs == "movement_damage":
				_director.auto_run = true
				break
	for unit: UnitState in _director.base_board.units:
		if unit.definition != null and unit.definition.id == &"training_dummy":
			unit.health.current_hp = 10000
		if unit.team == GameEnums.Team.PLAYER:
			unit.ability.points_left = maxi(unit.ability.points_left, 1)
			unit.movement.points_left = maxi(unit.movement.points_left, 3)
	_batch_base_board = _director.base_board.clone()
	var board: BoardState = _batch_base_board
	_batch_actor_ids.clear()
	_batch_target_ids.clear()
	for skill_id: StringName in batch.skills:
		var case := _case_by_id(skill_id)
		_batch_actor_ids[skill_id] = _unit_id_at(board, _case_actor_cell(skill_id))
		var fixture: Dictionary = _FIXTURES.get(skill_id, {})
		var dummies: Array = fixture.get("dummies", [])
		if dummies.size() > 0 and String(case.get("target_kind", "")) == "enemy":
			_batch_target_ids[skill_id] = _unit_id_at(board, dummies[0] as Vector2i)
		else:
			_batch_target_ids[skill_id] = _unit_id_at(board, _case_target_cell(skill_id))
	if batch.skills.has(&"lancer_flanking_maneuver"):
		_set_dummy_facing(Vector2i(4, 4), GameEnums.Facing.NORTH)
	for skill_id: StringName in batch.skills:
		var case := _case_by_id(skill_id)
		var actor_cell := _case_actor_cell(skill_id)
		var actor_id: int = int(_batch_actor_ids.get(skill_id, -1))
		assert_int(actor_id).override_failure_message(
			"%s: four-Lancer fixture missing actor at %s" % [skill_id, actor_cell],
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
			_CASE_PREMOVE_RUN.get(skill_id, Vector2i(-999999, -999999)),
			_overlay,
		)
		_director.select_ability(_ability_index(actor, ability))
		await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
		var selected_ability := CombatDirector.resolve_selected_ability(
			actor, _director.selected_ability_index,
		)
		assert_object(selected_ability).override_failure_message(
			"%s: selected ability index did not resolve" % skill_id,
		).is_not_null()
		assert_that(selected_ability.id).override_failure_message(
			"%s: selected ability mismatch (got %s)" % [skill_id, selected_ability.id],
		).is_equal(skill_id)
		var target_cell := _case_target_cell(skill_id)
		if ability.range_tiles <= 0:
			target_cell = actor.position
		var is_awaiting_skill: bool = (
			AbilitySystem.planning_commit_flow(actor, ability)
			== GameEnums.PlanningCommitFlow.AWAITING_TARGET
		)
		var stand_cell: Vector2i = CombatPlanningPreview.planning_latest_stand_cell(
			_director, _director.board, actor_id,
		)
		var arm_cell: Vector2i = stand_cell if is_awaiting_skill else target_cell
		var tile_move_commit: bool = (
			ability.has_targeting(GameEnums.TargetingFlags.TILE)
			and AbilitySystem.ability_has_movement_effect(ability)
			and AbilitySystem.planning_commit_flow(actor, ability)
			== GameEnums.PlanningCommitFlow.IMMEDIATE
		)
		var slots: Dictionary
		if skill_id == &"lancer_glorious_charge":
			slots = await _commit_glorious_charge(runner, actor_id, case)
		elif skill_id == &"lancer_piercing_charge":
			slots = await _commit_piercing_charge(runner, actor_id, ability, target_cell)
		elif tile_move_commit:
			await _OVERLAY_QA.assert_live_overlay_parity(
				self, runner, _overlay, _input, _director, actor_id, ability, target_cell, skill_id,
			)
			slots = await _commit_live_click(runner, actor_id, target_cell)
			if _plan_has_awaiting(actor_id):
				var follow_up := target_cell
				if skill_id == &"lancer_piercing_charge":
					follow_up = Vector2i(8, 4)
				slots = await _commit_live_click(runner, actor_id, follow_up)
		elif is_awaiting_skill:
			slots = await _commit_awaiting_skill(
				runner, actor_id, ability, arm_cell, target_cell, skill_id,
			)
		else:
			await _OVERLAY_QA.assert_live_overlay_parity(
				self, runner, _overlay, _input, _director, actor_id, ability, target_cell, skill_id,
			)
			slots = await _commit_live_click(runner, actor_id, target_cell)
			if _plan_has_awaiting(actor_id):
				slots = await _commit_live_click(runner, actor_id, target_cell)
			if _slots_debug(slots).contains(":awaiting") or _plan_has_awaiting(actor_id):
				slots = await _commit_live_click(runner, actor_id, target_cell)
			if _plan_has_awaiting(actor_id):
				slots = await _commit_live_click(runner, actor_id, target_cell)
		assert_bool(_slots_invalid(slots)).override_failure_message(
			"%s: live preview/commit slots rejected a Bible-valid target: %s"
			% [skill_id, slots],
		).is_false()
		assert_bool(_plan_has_committed_skill(skill_id, actor_id)).override_failure_message(
			"%s: live commit did not write the selected ability; slots=%s plan=%s"
			% [skill_id, _slots_debug(slots), _plan_debug()],
		).is_true()
		await _MOVEMENT_QA.assert_committed(
			self, skill_id, _director, actor_id, ability, slots, _input, _overlay, runner,
		)

	if batch.skills.has(&"lancer_flanking_maneuver"):
		_set_dummy_facing(Vector2i(4, 4), GameEnums.Facing.NORTH)
	var result: SimResult = Simulator.simulate(_director.base_board, _director.get_player_plan())
	for skill_id: StringName in batch.skills:
		var case := _case_by_id(skill_id)
		var actor_id := _unit_id_at(_director.base_board, _case_actor_cell(skill_id))
		_assert_no_actor_failure(result.events, actor_id, skill_id)
		_assert_live_observation(result, case, actor_id)


func _assert_contract(ability: AbilityData, case: Dictionary) -> void:
	assert_object(ability).override_failure_message(
		"%s: ability missing from live Lancer loadout" % case.id,
	).is_not_null()
	if ability == null:
		return
	assert_int(ability.range_tiles).override_failure_message(
		"%s: range expected %s got %s"
		% [case.id, case.range, ability.range_tiles],
	).is_equal(int(case.range))
	assert_int(ability.targeting_flags).override_failure_message(
		"%s: targeting flags expected %s got %s"
		% [case.id, case.flags, ability.targeting_flags],
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
	if case.upgrade_keys.size() > 0:
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
	if case.id == &"lancer_piercing_charge":
		assert_bool(ability.modules.size() >= 2).override_failure_message(
			"%s: dash prefix must keep a RANGE 2 strike module" % case.id,
		).is_true()
		if ability.modules.size() >= 2:
			assert_int(ability.modules[1].max_range).override_failure_message(
				"%s: strike range expected 2 got %s" % [case.id, ability.modules[1].max_range],
			).is_equal(2)
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
		"%s: committed skill never resolved as ABILITY_USED; plan=%s"
		% [case.id, _plan_debug()],
	).is_true()

	var observation: StringName = case.observation
	if observation in [&"damage", &"movement_damage", &"damage_status", &"damage_displacement"]:
		var target_id: int = int(_batch_target_ids.get(case.id, -1))
		assert_bool(
			_events_have_damage(events, actor_id)
			or (target_id > 0 and _events_have_damage_to_target(events, target_id)),
		).override_failure_message(
			"%s: expected damage was not observed in Simulator telemetry" % case.id,
		).is_true()
	if observation in [&"movement", &"movement_damage"]:
		assert_bool(_events_have_actor_move(events, actor_id)).override_failure_message(
			"%s: expected movement was not observed" % case.id,
		).is_true()
	if observation in [&"displacement", &"damage_displacement"]:
		var target_id: int = int(_batch_target_ids.get(case.id, -1))
		var target_after := result.final_state.get_unit_by_id(target_id)
		var target_moved := (
			target_after != null
			and target_after.position != _case_target_cell(case.id)
		)
		assert_bool(
			_events_have_displacement(events, actor_id)
			or _events_have_unit_pushed(events, target_id)
			or _events_have_unit_move(events, target_id)
			or target_moved,
		).override_failure_message(
			"%s: expected PUSH/PULL displacement was not observed" % case.id,
		).is_true()
	if observation == &"status":
		var final_actor := result.final_state.get_unit_by_id(actor_id)
		var delayed_rally_seen := (
			final_actor != null
			and final_actor.passive_flags.has("next_turn_max_move_bonus")
		)
		assert_bool(
			final_actor != null
			and (not final_actor.active_statuses.is_empty() or delayed_rally_seen),
		).override_failure_message(
			"%s: expected status effect was not observed" % case.id,
		).is_true()
	if observation == &"terrain":
		assert_bool(
			_events_have_terrain(events, &"spear_wall", _case_target_cell(case.id)),
		).override_failure_message(
			"%s: expected spear-wall terrain creation event was not observed" % case.id,
		).is_true()


func _commit_glorious_charge(
	runner: GdUnitSceneRunner,
	actor_id: int,
	case: Dictionary,
) -> Dictionary:
	var ability := _ability_by_id(
		_director.board.get_unit_by_id(actor_id), case.id,
	)
	var dash_cell := Vector2i(8, 5)
	await _OVERLAY_QA.assert_live_overlay_parity(
		self, runner, _overlay, _input, _director, actor_id, ability, dash_cell, case.id,
	)
	var dash_slots := await _commit_live_click(
		runner, actor_id, dash_cell,
	)
	assert_bool(_slots_invalid(dash_slots)).override_failure_message(
		"%s: selecting the DASH landing tile must arm the enemy target step" % case.id,
	).is_false()
	assert_bool(_director.find_awaiting_action(actor_id) != null).override_failure_message(
		"%s: DASH landing selection did not enter awaiting-target flow" % case.id,
	).is_true()
	var target_cell := _case_target_cell(case.id)
	if ability != null and _director.find_awaiting_action(actor_id) != null:
		await _OVERLAY_QA.assert_live_overlay_parity(
			self, runner, _overlay, _input, _director, actor_id, ability, target_cell, case.id,
		)
	return await _commit_live_click(runner, actor_id, target_cell)


func _commit_piercing_charge(
	runner: GdUnitSceneRunner,
	actor_id: int,
	ability: AbilityData,
	dash_cell: Vector2i,
) -> Dictionary:
	## Bible: DASH 3 to an empty tile, then ATK 2 at RANGE 2 from the landing tile.
	await _OVERLAY_QA.assert_live_overlay_parity(
		self, runner, _overlay, _input, _director, actor_id, ability, dash_cell, &"lancer_piercing_charge",
	)
	var slots := await _commit_live_click(runner, actor_id, dash_cell)
	var strike_cell := Vector2i(8, 4)
	if _plan_has_awaiting(actor_id):
		slots = await _commit_live_click(runner, actor_id, strike_cell)
	if _plan_has_awaiting(actor_id):
		slots = await _commit_live_click(runner, actor_id, strike_cell)
	return slots


func _commit_awaiting_skill(
	runner: GdUnitSceneRunner,
	actor_id: int,
	ability: AbilityData,
	arm_cell: Vector2i,
	target_cell: Vector2i,
	skill_id: StringName,
) -> Dictionary:
	_director.select_unit(actor_id)
	_director.select_ability(_ability_index(
		_director.board.get_unit_by_id(actor_id), ability,
	))
	await runner.simulate_frames(3, _DELTA_MS)
	var slots: Dictionary = await _commit_live_click(runner, actor_id, arm_cell)
	if _plan_has_awaiting(actor_id):
		if skill_id != &"lancer_glorious_charge":
			await _OVERLAY_QA.assert_live_overlay_parity(
				self, runner, _overlay, _input, _director, actor_id, ability, target_cell, skill_id,
			)
		slots = await _commit_live_click(runner, actor_id, target_cell)
		if skill_id == &"lancer_piercing_charge" and _plan_has_awaiting(actor_id):
			slots = await _commit_live_click(runner, actor_id, Vector2i(8, 4))
	return slots


func _manhattan_drag_route(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = [from_cell]
	var cursor := from_cell
	while cursor.x != to_cell.x:
		cursor.x += int(signf(float(to_cell.x - cursor.x)))
		route.append(cursor)
	while cursor.y != to_cell.y:
		cursor.y += int(signf(float(to_cell.y - cursor.y)))
		route.append(cursor)
	return route


func _commit_drag_finalize(
	runner: GdUnitSceneRunner,
	actor_id: int,
	route: Array[Vector2i],
	dest: Vector2i,
) -> Dictionary:
	var actor: UnitState = _director.board.get_unit_by_id(actor_id)
	_director.select_unit(actor_id)
	var armed_action := _director.find_awaiting_action(actor_id)
	if armed_action != null and armed_action.ability != null:
		_director.select_ability(_ability_index(actor, armed_action.ability))
	_TRAMPLE_DRAG._paint_drag_route(_input, actor, route, dest)
	await runner.simulate_frames(3, _DELTA_MS)
	_input.set_qa_pointer_grid_cell(dest)
	if _input._intent_state != null:
		_input._intent_state.set_hover_coord(dest)
	_input.on_hover_moved(dest)
	_input._flush_hover_heavy_sync()
	var params: Dictionary = _input._commit_interaction_params(dest, -1)
	var slots: Dictionary = _input._final_commit_slots_for_interaction(
		actor_id,
		params.cell,
		params.waypoints,
		params.legal_move_tiles,
		params.preferred,
		params.face_dir,
	)
	_input.dragging = false
	if _slots_invalid(slots):
		return slots
	_input.call("_paint_intent_slots_before_commit", actor_id, slots)
	assert_bool(_director.commit_from_slots(actor_id, slots)).override_failure_message(
		"live drag commit_from_slots must accept the preview slots: %s" % _slots_debug(slots),
	).is_true()
	_input.call("_promote_intent_preview_after_commit")
	_director.flush_plan_refresh_signals_if_pending()
	_input.clear_qa_pointer_override()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	return slots


func _first_slot_action(slots: Dictionary) -> TimelineAction:
	for column: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(column, []):
			if raw is TimelineAction:
				return raw as TimelineAction
	return null


func _set_dummy_facing(cell: Vector2i, facing: GameEnums.Facing) -> void:
	for board: BoardState in [
		_director.base_board, _director.board, _director.projected_state, _batch_base_board,
	]:
		if board == null:
			continue
		for unit: UnitState in board.units:
			if unit == null:
				continue
			if (
				unit.position == cell
				or (
					unit.definition != null
					and unit.definition.id == &"training_dummy"
				)
			):
				unit.facing = facing


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
	_input.on_hover_moved(cell)
	_input._flush_hover_heavy_sync()
	var slots: Dictionary
	if _plan_has_awaiting(unit_id):
		slots = _input._build_commit_slots_at_cell(unit_id, cell)
	else:
		slots = _input._final_commit_slots_for_click_at_cell(
			unit_id, cell, Vector2.ZERO,
		)
	if _slots_invalid(slots):
		return slots
	_input.call("_paint_intent_slots_before_commit", unit_id, slots)
	assert_bool(_director.commit_from_slots(unit_id, slots)).override_failure_message(
		"live commit_from_slots must accept the preview slots: %s" % _slots_debug(slots),
	).is_true()
	_input.call("_promote_intent_preview_after_commit")
	_director.flush_plan_refresh_signals_if_pending()
	_input.clear_qa_pointer_override()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	return slots


func _case_by_id(skill_id: StringName) -> Dictionary:
	for case: Dictionary in _CASES:
		if case.id == skill_id:
			return case
	return {}


func _slots_invalid(slots: Dictionary) -> bool:
	var invalid: Variant = slots.get("invalid", false)
	return invalid is String or invalid == true


func _case_actor_cell(skill_id: StringName) -> Vector2i:
	return _CASE_ACTORS.get(skill_id, _ACTOR_CELL)


func _case_target_cell(skill_id: StringName) -> Vector2i:
	return _CASE_TARGETS.get(skill_id, _ACTOR_CELL)


func _case_ally_cell(skill_id: StringName) -> Vector2i:
	return _CASE_ALLIES.get(skill_id, _ACTOR_CELL)


func _plan_has_committed_skill(skill_id: StringName, actor_id: int) -> bool:
	for action: TimelineAction in _director.get_player_plan().entries:
		if action.actor_id != actor_id or action.awaiting_target:
			continue
		if action.ability != null and action.ability.id == skill_id:
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


func _events_have_damage_to_target(events: Array[SimEvent], target_id: int) -> bool:
	for event: SimEvent in events:
		if event.type != GameEnums.SimEventType.UNIT_DAMAGED:
			continue
		if int(event.data.get("target", event.data.get("unit", -1))) == target_id:
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
			and int(event.data.get("source", -1)) == actor_id
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


func _events_have_unit_move(events: Array[SimEvent], unit_id: int) -> bool:
	for event: SimEvent in events:
		if event.type != GameEnums.SimEventType.UNIT_MOVED:
			continue
		if (
			int(event.data.get("unit", event.data.get("actor", -1))) == unit_id
			or int(event.data.get("actor", -1)) == unit_id
		):
			return true
	return false


func _events_have_unit_pushed(events: Array[SimEvent], unit_id: int) -> bool:
	for event: SimEvent in events:
		if (
			event.type == GameEnums.SimEventType.UNIT_PUSHED
			and int(event.data.get("unit", -1)) == unit_id
		):
			return true
	return false


func _events_have_terrain(
	events: Array[SimEvent],
	terrain_id: StringName,
	coord: Vector2i,
) -> bool:
	for event: SimEvent in events:
		if (
			event.type == GameEnums.SimEventType.TERRAIN_CHANGED
			and event.data.get("terrain", &"") == terrain_id
			and event.data.get("coord", Vector2i(-1, -1)) == coord
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
