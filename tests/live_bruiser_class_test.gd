## Tier 2 live Bruiser acceptance.
##
## Each movement skill and active uses its own actor cell per batch, commits through
## preview slots, and resolves via Simulator. Shaped skills assert overlay red tiles
## match AbilitySystem blast footprint (exact set + count) via AoeFootprintQaHarness.
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _SETTLE_FRAMES: int = 8
const _DELTA_MS: int = 16
const _OVERLAY_QA := preload("res://tests/live_overlay_qa_mixin.gd")
const _LIVE_EVENT_BARS: Dictionary = {
	&"bruiser_push_through": {"damage": 0, "moves": 1, "pushes": 1, "self_damage": 0},
	&"bruiser_charge_strike": {"damage": 1, "moves": 1, "pushes": 1, "self_damage": 0},
	&"bruiser_concussion_blow": {"damage": 1, "moves": 0, "pushes": 1, "self_damage": 0},
	&"bruiser_cleave": {"damage": 1, "moves": 0, "pushes": 0, "self_damage": 0},
	&"bruiser_suplex": {"damage": 1, "moves": 0, "pushes": 0, "self_damage": 0},
	&"bruiser_adrenaline_surge": {"damage": 0, "moves": 0, "pushes": 0, "self_damage": 1},
	&"bruiser_earthshatter": {"damage": 1, "moves": 0, "pushes": 0, "self_damage": 0},
	&"bruiser_meat_shield": {"damage": 0, "moves": 0, "pushes": 2, "self_damage": 0},
	&"bruiser_frenzy": {"damage": 3, "moves": 0, "pushes": 0, "self_damage": 0},
	&"bruiser_guttural_roar": {"damage": 0, "moves": 0, "pushes": 1, "self_damage": 0},
	&"bruiser_headbutt": {"damage": 1, "moves": 0, "pushes": 0, "self_damage": 1},
	&"bruiser_blood_boil": {"damage": 0, "moves": 0, "pushes": 0, "self_damage": 1},
	&"bruiser_violent_collision": {"damage": 0, "moves": 1, "pushes": 0, "self_damage": 0},
	&"bruiser_crimson_whirlwind": {"damage": 1, "moves": 0, "pushes": 0, "self_damage": 0},
	&"bruiser_belly_flop": {"damage": 1, "moves": 1, "pushes": 0, "self_damage": 0},
	&"bruiser_breaching_dash": {"damage": 0, "moves": 1, "pushes": 0, "self_damage": 0},
}

const _CASES: Array[Dictionary] = [
	{"id": &"bruiser_push_through", "observation": &"displacement", "upgrade_keys": [&"buff_on_push"]},
	{"id": &"bruiser_charge_strike", "observation": &"movement_damage", "upgrade_keys": [&"ghost_move", &"bonus_dmg_from_terrain"]},
	{"id": &"bruiser_concussion_blow", "observation": &"damage_displacement", "upgrade_keys": [&"enemy_collision_stagger_both"]},
	{"id": &"bruiser_cleave", "observation": &"damage", "upgrade_keys": [&"weapon_scaled"]},
	{"id": &"bruiser_suplex", "observation": &"damage_displacement", "upgrade_keys": [&"bonus_dmg_per_10_hp"]},
	{"id": &"bruiser_adrenaline_surge", "observation": &"self_buff", "upgrade_keys": [&"on_kill_heal_shield"]},
	{"id": &"bruiser_earthshatter", "observation": &"damage", "upgrade_keys": [&"buff_per_destroyed_object"]},
	{"id": &"bruiser_meat_shield", "observation": &"swap", "upgrade_keys": [&"intercept_grant_str"]},
	{"id": &"bruiser_frenzy", "observation": &"damage", "upgrade_keys": [&"frenzy_on_kill_ap"]},
	{"id": &"bruiser_guttural_roar", "observation": &"aoe_displacement", "upgrade_keys": [&"push_board_items", &"item_collision_damage"]},
	{"id": &"bruiser_headbutt", "observation": &"damage_status", "upgrade_keys": [&"bonus_dmg_pct_max_hp"]},
	{"id": &"bruiser_blood_boil", "observation": &"self_buff", "upgrade_keys": []},
	{"id": &"bruiser_violent_collision", "observation": &"movement", "upgrade_keys": [&"stagger_on_collision"]},
	{"id": &"bruiser_crimson_whirlwind", "observation": &"aoe_damage", "upgrade_keys": [&"heal_per_target_hit"]},
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


func test_live_bruiser_multi_skill_session(timeout := 300000) -> void:
	_cache_factory_abilities()
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	runner.move_window_to_foreground()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_scene = runner.scene() as TestBattleMapView
	assert_object(_scene).is_not_null()
	if _scene == null:
		return
	await _journey_bruiser_push_through(runner)
	await _journey_bruiser_charge_strike(runner)
	await _journey_bruiser_concussion_blow(runner)
	await _journey_bruiser_cleave(runner)
	await _journey_bruiser_suplex(runner)
	await _journey_bruiser_adrenaline_surge(runner)
	await _journey_bruiser_earthshatter(runner)
	await _journey_bruiser_meat_shield(runner)
	await _journey_bruiser_frenzy(runner)
	await _journey_bruiser_guttural_roar(runner)
	await _journey_bruiser_headbutt(runner)
	await _journey_bruiser_blood_boil(runner)
	await _journey_bruiser_violent_collision(runner)
	await _journey_bruiser_crimson_whirlwind(runner)
	await _journey_bruiser_belly_flop(runner)
	await _journey_bruiser_breaching_dash(runner)
	await _run_cleave_tile_aim_scenario(runner)
	await _run_cleave_premove_overlay_scenario(runner)


func _journey_bruiser_push_through(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_push_through")


func _journey_bruiser_charge_strike(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_charge_strike")


func _journey_bruiser_concussion_blow(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_concussion_blow")


func _journey_bruiser_cleave(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_cleave")


func _journey_bruiser_suplex(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_suplex")


func _journey_bruiser_adrenaline_surge(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_adrenaline_surge")


func _journey_bruiser_earthshatter(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_earthshatter")


func _journey_bruiser_meat_shield(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_meat_shield")


func _journey_bruiser_frenzy(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_frenzy")


func _journey_bruiser_guttural_roar(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_guttural_roar")


func _journey_bruiser_headbutt(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_headbutt")


func _journey_bruiser_blood_boil(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_blood_boil")


func _journey_bruiser_violent_collision(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_violent_collision")


func _journey_bruiser_crimson_whirlwind(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_crimson_whirlwind")


func _journey_bruiser_belly_flop(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_belly_flop")


func _journey_bruiser_breaching_dash(runner: GdUnitSceneRunner) -> void:
	await _run_skill_journey(runner, &"bruiser_breaching_dash")


func _run_skill_journey(runner: GdUnitSceneRunner, skill_id: StringName) -> void:
	var case: Dictionary = _case_by_id(skill_id)
	var source_batch: Dictionary = _batch_for_skill(skill_id)
	assert_bool(not source_batch.is_empty()).override_failure_message(
		"%s: no dedicated fixture batch exists" % skill_id,
	).is_true()
	if source_batch.is_empty():
		return
	await _run_live_batch(runner, {
		"extra_players": source_batch.extra_players,
		"dummies": source_batch.dummies,
		"skills": [skill_id],
	})
	var factory_ability: AbilityData = _factory_ability(case.id)
	if factory_ability != null and factory_ability.range_tiles > 0:
		await _run_live_batch(runner, {
			"extra_players": source_batch.extra_players,
			"dummies": source_batch.dummies,
			"skills": [skill_id],
			"drag_mode": true,
		})


func _run_cleave_premove_overlay_scenario(runner: GdUnitSceneRunner) -> void:
	## Regression: premove + ARC must show blast tiles only (never range bubble + blast = 4 reds).
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"bruiser"
	session.player_level = TestBattleSession.TRAINING_LEVEL
	session.set_all_passives_enabled(&"bruiser", false)
	session.set_all_skills_enabled(&"bruiser", false)
	session.skill_enabled[&"bruiser_cleave"] = true
	session.extra_player_coords = []
	session.dummy_coords = [Vector2i(7, 5)]
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
	var actor_id := _unit_id_at(_director.base_board, Vector2i(4, 5))
	assert_int(actor_id).is_greater(0)
	var actor := _director.board.get_unit_by_id(actor_id)
	var run_ab: AbilityData = null
	for ab: AbilityData in actor.active_abilities:
		if ab != null and ab.id == &"universal_run":
			run_ab = ab
			break
	if run_ab == null:
		run_ab = DataLibrary.get_universal_run()
	assert_object(run_ab).is_not_null()
	_director.select_unit(actor_id)
	_director.select_ability(_ability_index(actor, run_ab))
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var move_slots := await _commit_live_click(runner, actor_id, Vector2i(6, 5))
	assert_bool(_slots_invalid(move_slots)).override_failure_message(
		"cleave_premove: Run premove invalid=%s slots=%s plan=%s"
		% [str(move_slots.get("invalid", false)), _slots_debug(move_slots), _plan_debug()],
	).is_false()
	assert_that(_pre_move_target(move_slots)).override_failure_message(
		"cleave_premove: Run premove target drifted; slots=%s" % _slots_debug(move_slots),
	).is_equal(Vector2i(6, 5))
	var cleave: AbilityData = _ability_by_id(actor, &"bruiser_cleave")
	assert_object(cleave).is_not_null()
	_director.select_unit(actor_id)
	_director.select_ability(_ability_index(actor, cleave))
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	var arm_slots: Dictionary = await _commit_live_click(runner, actor_id, Vector2i(6, 5))
	assert_bool(_slots_invalid(arm_slots)).override_failure_message(
		"cleave_premove: self arm invalid=%s slots=%s plan=%s"
		% [str(arm_slots.get("invalid", false)), _slots_debug(arm_slots), _plan_debug()],
	).is_false()
	assert_bool(_plan_has_awaiting(actor_id)).override_failure_message(
		"cleave_premove: self click must arm Cleave after premove; plan=%s slots=%s"
		% [
			_plan_debug(),
			_slots_debug(arm_slots),
		],
	).is_true()
	await _OVERLAY_QA.assert_live_overlay_parity(
		self, runner, _overlay, _input, _director, actor_id, cleave, Vector2i(7, 5), &"cleave_premove",
	)
	var target_slots: Dictionary = _input._build_commit_slots_at_cell(
		actor_id, Vector2i(7, 5),
	)
	assert_bool(_slots_invalid(target_slots)).override_failure_message(
		"cleave_premove: armed target hover invalid=%s slots=%s plan=%s"
		% [str(target_slots.get("invalid", false)), _slots_debug(target_slots), _plan_debug()],
	).is_false()
	var final_slots: Dictionary = await _commit_live_click(runner, actor_id, Vector2i(7, 5))
	assert_bool(_slots_invalid(final_slots)).override_failure_message(
		"cleave_premove: final target invalid=%s slots=%s plan=%s"
		% [str(final_slots.get("invalid", false)), _slots_debug(final_slots), _plan_debug()],
	).is_false()
	assert_bool(not _plan_has_awaiting(actor_id)).override_failure_message(
		"cleave_premove: final target must clear awaiting; plan=%s target_slots=%s final_slots=%s"
		% [_plan_debug(), _slots_debug(target_slots), _slots_debug(final_slots)],
	).is_true()


func _run_cleave_tile_aim_scenario(runner: GdUnitSceneRunner) -> void:
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.player_class_id = &"bruiser"
	session.skill_enabled.clear()
	session.set_all_skills_enabled(&"bruiser", false)
	session.skill_enabled[&"bruiser_cleave"] = true
	session.extra_player_coords = []
	session.dummy_coords = [Vector2i(5, 4), Vector2i(5, 6)]
	session.unkillable_dummies = true
	session.infinite_player_ap = true
	_scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_director = _scene.get_node("CombatDirector") as CombatDirector
	var shell := _scene.get_node("CombatShell") as TacticalCombatShell
	_input = shell.planning_input
	_overlay = _scene.get_node("WorldModulate/MapRoot/PlanningOverlay") as TacticalPlanningOverlay
	_director.auto_run = false
	var actor_id := _unit_id_at(_director.base_board, Vector2i(4, 5))
	var actor := _director.board.get_unit_by_id(actor_id)
	var cleave: AbilityData = _ability_by_id(actor, &"bruiser_cleave")
	assert_object(cleave).is_not_null()
	assert_int(cleave.targeting_flags).is_equal(
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
	)
	_director.select_unit(actor_id)
	_director.select_ability(_ability_index(actor, cleave))
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	await _OVERLAY_QA.assert_live_overlay_parity(
		self, runner, _overlay, _input, _director, actor_id, cleave, Vector2i(5, 5), &"cleave_tile_aim",
	)
	var slots := await _commit_live_click(runner, actor_id, Vector2i(5, 5))
	assert_bool(_slots_invalid(slots)).override_failure_message(
		"cleave_tile_aim: first target invalid=%s slots=%s plan=%s"
		% [str(slots.get("invalid", false)), _slots_debug(slots), _plan_debug()],
	).is_false()
	assert_bool(_plan_has_awaiting(actor_id)).override_failure_message(
		"cleave_tile_aim: first target must arm awaiting; plan=%s slots=%s"
		% [_plan_debug(), _slots_debug(slots)],
	).is_true()
	slots = await _commit_live_click(runner, actor_id, Vector2i(5, 5))
	assert_bool(_slots_invalid(slots)).override_failure_message(
		"cleave_tile_aim: final target invalid=%s slots=%s plan=%s"
		% [str(slots.get("invalid", false)), _slots_debug(slots), _plan_debug()],
	).is_false()
	assert_bool(not _plan_has_awaiting(actor_id)).override_failure_message(
		"cleave_tile_aim: final target must clear awaiting; plan=%s" % _plan_debug(),
	).is_true()
	var result: SimResult = Simulator.simulate(_director.base_board, _director.get_player_plan())
	var hit_north := false
	var hit_south := false
	for event: SimEvent in result.events:
		if event.type != GameEnums.SimEventType.UNIT_DAMAGED:
			continue
		var victim: int = int(event.data.get("unit", -1))
		if victim == _unit_id_at(_director.base_board, Vector2i(5, 4)):
			hit_north = true
		if victim == _unit_id_at(_director.base_board, Vector2i(5, 6)):
			hit_south = true
	assert_bool(hit_north and hit_south).override_failure_message(
		"Cleave tile-aim must damage both ARC neighbors when center tile is empty",
	).is_true()


func _batch_for_skill(skill_id: StringName) -> Dictionary:
	for batch: Dictionary in _BATCHES:
		for listed_skill: StringName in batch.skills:
			if listed_skill == skill_id:
				return batch
	return {}


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
	var drag_mode: bool = bool(batch.get("drag_mode", false))
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
		assert_object(actor).override_failure_message(
			"%s: Bruiser actor missing from live board" % _scenario_diagnostic(skill_id),
		).is_not_null()
		if actor == null:
			continue
		assert_that(actor.position).override_failure_message(
			"%s: actor spawned at the wrong fixture cell" % _scenario_diagnostic(skill_id),
		).is_equal(actor_cell)
		var ability := _ability_by_id(actor, skill_id)
		_assert_contract(ability, case)
		if ability == null:
			continue
		_director.select_unit(actor_id)
		_director.select_ability(_ability_index(actor, ability))
		await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
		assert_int(_director.selected_unit_id).override_failure_message(
			"%s: selected unit changed before preview" % _scenario_diagnostic(skill_id),
		).is_equal(actor_id)
		assert_int(_director.selected_ability_index).override_failure_message(
			"%s: selected ability index drifted" % _scenario_diagnostic(skill_id),
		).is_equal(_ability_index(actor, ability))
		var target_cell: Vector2i = _case_target_cell(skill_id)
		if ability.range_tiles <= 0:
			target_cell = actor.position
		await _OVERLAY_QA.assert_live_overlay_parity(
			self, runner, _overlay, _input, _director, actor_id, ability, target_cell, skill_id,
		)
		var is_target_pick: bool = (
			ability.has_targeting(GameEnums.TargetingFlags.TILE)
			and not AbilitySystem.ability_has_movement_effect(ability)
		)
		var is_awaiting_skill: bool = (
			AbilitySystem.planning_commit_flow(actor, ability)
			== GameEnums.PlanningCommitFlow.AWAITING_TARGET
		)
		var arm_cell: Vector2i = actor.position if is_awaiting_skill else _case_target_cell(skill_id)
		var preview_slots: Dictionary = _input._final_commit_slots_for_click_at_cell(
			actor_id, arm_cell, Vector2.ZERO,
		)
		assert_bool(_slots_invalid(preview_slots)).override_failure_message(
			"%s: hover slots invalid=%s slots=%s plan=%s"
			% [_scenario_diagnostic(skill_id), str(preview_slots.get("invalid", false)),
				_slots_debug(preview_slots), _plan_debug()],
		).is_false()
		var preview_action: TimelineAction = _first_slot_action(preview_slots)
		assert_object(preview_action).override_failure_message(
			"%s: hover slots must contain an action; slots=%s"
			% [_scenario_diagnostic(skill_id), _slots_debug(preview_slots)],
		).is_not_null()
		if preview_action != null:
			if preview_action.ability != null:
				assert_that(preview_action.ability.id).override_failure_message(
					"%s: hover action ability drifted; action=%s"
					% [_scenario_diagnostic(skill_id), _action_debug(preview_action)],
				).is_equal(skill_id)
			else:
				assert_that(preview_action.type).override_failure_message(
					"%s: hover action must be a move or selected ability; action=%s"
					% [_scenario_diagnostic(skill_id), _action_debug(preview_action)],
				).is_equal(GameEnums.ActionType.MOVE)
			if preview_action.ability != null:
				assert_that(preview_action.target_coord).override_failure_message(
					"%s: hover ability target drifted; action=%s"
					% [_scenario_diagnostic(skill_id), _action_debug(preview_action)],
				).is_equal(arm_cell)
		var preview_icon: String = _input._cursor_icon_from_commit_slots(preview_slots, actor)
		assert_bool(preview_icon != PlanningIcons.GLYPH_NULL).override_failure_message(
			"%s: hover cursor must not be null; icon=%s slots=%s"
			% [_scenario_diagnostic(skill_id), preview_icon, _slots_debug(preview_slots)],
		).is_true()
		var preview_path: Array = _input.preview_state.preview_paths.get(actor_id, [])
		var has_pre_move: bool = not (preview_slots.get("pre", []) as Array).is_empty()
		if has_pre_move:
			assert_bool(preview_path.size() >= 2).override_failure_message(
				"%s: paired skill preview must expose a walk path; path=%s slots=%s"
				% [_scenario_diagnostic(skill_id), str(preview_path), _slots_debug(preview_slots)],
			).is_true()
			assert_bool(preview_icon.contains(PlanningIcons.GLYPH_WALK)).override_failure_message(
				"%s: paired skill cursor must expose WALK; icon=%s"
				% [_scenario_diagnostic(skill_id), preview_icon],
			).is_true()
		if is_target_pick:
			assert_int(AbilitySystem.planning_awaiting_phase(ability)).override_failure_message(
				"%s: non-movement TILE skill must use TARGET_PICK"
				% _scenario_diagnostic(skill_id),
			).is_equal(GameEnums.PlanningAwaitingPhase.TARGET_PICK)
			assert_bool(preview_action.awaiting_target).override_failure_message(
				"%s: first hover/click must arm awaiting target; action=%s slots=%s"
				% [_scenario_diagnostic(skill_id), _action_debug(preview_action), _slots_debug(preview_slots)],
			).is_true()
		elif is_awaiting_skill:
			assert_int(AbilitySystem.planning_awaiting_phase(ability)).override_failure_message(
				"%s: movement skill must use MOVEMENT_ENDPOINT"
				% _scenario_diagnostic(skill_id),
			).is_equal(GameEnums.PlanningAwaitingPhase.MOVEMENT_ENDPOINT)
			assert_bool(preview_action.awaiting_target).override_failure_message(
				"%s: movement skill must arm an awaiting endpoint; action=%s"
				% [_scenario_diagnostic(skill_id), _action_debug(preview_action)],
			).is_true()
		var slots: Dictionary
		var drag_finalized: bool = false
		if drag_mode:
			if is_awaiting_skill:
				slots = await _commit_live_click(
					runner, actor_id, arm_cell,
				)
				assert_bool(_plan_has_awaiting(actor_id)).override_failure_message(
					"%s: drag journey must arm awaiting before drag finalize; plan=%s"
					% [_scenario_diagnostic(skill_id), _plan_debug()],
				).is_true()
				slots = await _commit_live_drag(
					runner, actor_id, _case_target_cell(skill_id),
				)
			else:
				slots = await _commit_live_drag(
					runner, actor_id, _case_target_cell(skill_id),
				)
			drag_finalized = true
		else:
			slots = await _commit_live_click(
				runner, actor_id, arm_cell if is_awaiting_skill else _case_target_cell(skill_id),
			)
		if is_awaiting_skill:
			if not drag_finalized:
				assert_bool(_plan_has_awaiting(actor_id)).override_failure_message(
					"%s: first click must leave an awaiting action; plan=%s slots=%s"
					% [_scenario_diagnostic(skill_id), _plan_debug(), _slots_debug(slots)],
				).is_true()
				slots = await _commit_live_click(runner, actor_id, _case_target_cell(skill_id))
			var committed: TimelineAction = _committed_action_for_ability(actor_id, skill_id)
			assert_object(committed).override_failure_message(
				"%s: second click must finalize ability; plan=%s"
				% [_scenario_diagnostic(skill_id), _plan_debug()],
			).is_not_null()
			if committed != null:
				assert_bool(not committed.awaiting_target).override_failure_message(
					"%s: finalized action remains awaiting; action=%s"
					% [_scenario_diagnostic(skill_id), _action_debug(committed)],
				).is_true()
				assert_that(committed.target_coord).override_failure_message(
					"%s: committed target differs from hover; action=%s"
					% [_scenario_diagnostic(skill_id), _action_debug(committed)],
				).is_equal(_case_target_cell(skill_id))
		elif _slots_debug(slots).contains(":awaiting") or _plan_has_awaiting(actor_id):
			slots = await _commit_live_click(runner, actor_id, _case_target_cell(skill_id))
		assert_bool(_slots_invalid(slots)).override_failure_message(
			"%s: live preview/commit slots rejected a Bible-valid target: %s"
			% [_scenario_diagnostic(skill_id), _slots_debug(slots)],
		).is_false()
		assert_bool(_plan_has_committed_skill(skill_id, actor_id)).override_failure_message(
			"%s: live commit did not write the selected skill; plan=%s"
			% [skill_id, _plan_debug()],
		).is_true()
		if not drag_mode:
			await _undo_and_recommit_skill(
				runner, actor_id, skill_id, is_awaiting_skill, arm_cell,
			)

	var result: SimResult = Simulator.simulate(_director.base_board, _director.get_player_plan())
	for skill_id: StringName in batch.skills:
		var case := _case_by_id(skill_id)
		var actor_id := _unit_id_at(_director.base_board, _case_actor_cell(skill_id))
		if not drag_mode:
			_assert_no_actor_failure(result.events, actor_id, skill_id)
			_assert_live_observation(result, case, actor_id)
			_assert_skill_event_bar(result, skill_id, actor_id)
			_assert_skill_specific_outcome(result, skill_id, actor_id)


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


func _assert_skill_event_bar(result: SimResult, skill_id: StringName, actor_id: int) -> void:
	var bar: Dictionary = _LIVE_EVENT_BARS.get(skill_id, {})
	var events: Array[SimEvent] = result.events
	var damage_events: int = 0
	var move_events: int = 0
	var push_events: int = 0
	var self_damage_events: int = 0
	var event_trace: Array[String] = []
	for event: SimEvent in events:
		if event.type in [
			GameEnums.SimEventType.UNIT_DAMAGED,
			GameEnums.SimEventType.MATH_TELEMETRY,
			GameEnums.SimEventType.UNIT_MOVED,
			GameEnums.SimEventType.UNIT_PUSHED,
		]:
			event_trace.append("%s:%s" % [str(event.type), str(event.data)])
		if (
			event.type == GameEnums.SimEventType.MATH_TELEMETRY
			and event.data.get("type", "") == "damage"
			and int(event.data.get("actor_id", -1)) == actor_id
		):
			damage_events += 1
		elif event.type == GameEnums.SimEventType.UNIT_DAMAGED:
			var source_id: int = int(event.data.get("source", event.data.get("actor", -1)))
			var target_id: int = int(event.data.get("target", event.data.get("unit", -1)))
			if source_id == actor_id and target_id != actor_id:
				damage_events += 1
			if target_id == actor_id:
				self_damage_events += 1
		elif event.type == GameEnums.SimEventType.UNIT_MOVED:
			var moved_unit_id: int = int(event.data.get("actor", event.data.get("unit", -1)))
			if moved_unit_id == actor_id:
				move_events += 1
			elif int(event.data.get("pusher", event.data.get("source", -1))) == actor_id:
				push_events += 1
		elif event.type == GameEnums.SimEventType.UNIT_PUSHED:
			if int(event.data.get("source", event.data.get("pusher", actor_id))) == actor_id:
				push_events += 1
			elif bool(event.data.get("swap_displacement", false)):
				push_events += 1
			elif int(event.data.get("unit", -1)) == actor_id and bar.get("pushes", 0) >= 2:
				push_events += 1
	assert_int(damage_events).override_failure_message(
		"%s: expected at least %d skill damage events, got %d trace=%s" % [
			skill_id, int(bar.get("damage", 0)), damage_events, " | ".join(event_trace),
		],
	).is_greater_equal(int(bar.get("damage", 0)))
	assert_int(move_events).override_failure_message(
		"%s: expected at least %d actor movement events, got %d" % [
			skill_id, int(bar.get("moves", 0)), move_events,
		],
	).is_greater_equal(int(bar.get("moves", 0)))
	assert_int(push_events).override_failure_message(
		"%s: expected at least %d displacement events, got %d" % [
			skill_id, int(bar.get("pushes", 0)), push_events,
		],
	).is_greater_equal(int(bar.get("pushes", 0)))
	assert_int(self_damage_events).override_failure_message(
		"%s: expected at least %d self-damage events, got %d" % [
			skill_id, int(bar.get("self_damage", 0)), self_damage_events,
		],
	).is_greater_equal(int(bar.get("self_damage", 0)))


func _assert_skill_specific_outcome(result: SimResult, skill_id: StringName, actor_id: int) -> void:
	var final_state: BoardState = result.final_state
	var final_actor: UnitState = final_state.get_unit_by_id(actor_id)
	assert_object(final_actor).override_failure_message(
		"%s: final actor missing from Simulator result" % skill_id,
	).is_not_null()
	if final_actor == null:
		return
	match skill_id:
		&"bruiser_suplex":
			var target_id: int = int(_batch_target_ids.get(skill_id, -1))
			var target: UnitState = final_state.get_unit_by_id(target_id)
			assert_object(target).is_not_null()
			if target != null:
				assert_that(target.position).override_failure_message(
					"suplex: target must land behind caster, not merely be displaced",
				).is_equal(Vector2i(3, 5))
		&"bruiser_violent_collision":
			var collision_id: int = _unit_id_at(_director.base_board, Vector2i(4, 3))
			var collision_target: UnitState = final_state.get_unit_by_id(collision_id)
			assert_object(collision_target).is_not_null()
			if collision_target != null:
				assert_bool(collision_target.position != Vector2i(4, 3)).override_failure_message(
					"violent_collision: bulldoze must move the dummy in the dash corridor",
				).is_true()
		&"bruiser_belly_flop":
			assert_that(final_actor.position).override_failure_message(
				"belly_flop: final actor position must be the TELEPORT landing tile",
			).is_equal(_case_target_cell(skill_id))
			var landing_target_id: int = _unit_id_at(_director.base_board, Vector2i(5, 4))
			var landing_target: UnitState = final_state.get_unit_by_id(landing_target_id)
			assert_object(landing_target).is_not_null()
			if landing_target != null:
				assert_bool(landing_target.health.current_hp < 10000).override_failure_message(
					"belly_flop: adjacent dummy must take landing damage",
				).is_true()
		&"bruiser_meat_shield":
			var ally_id: int = _unit_id_at(_director.base_board, Vector2i(7, 8))
			var ally: UnitState = final_state.get_unit_by_id(ally_id)
			assert_object(ally).is_not_null()
			if ally != null:
				assert_that(ally.position).override_failure_message(
					"meat_shield: ally must swap with the Bruiser",
				).is_equal(_case_actor_cell(skill_id))


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


func _undo_and_recommit_skill(
	runner: GdUnitSceneRunner,
	actor_id: int,
	skill_id: StringName,
	is_target_pick: bool,
	arm_cell: Vector2i,
) -> void:
	_director.rpc_remove_last_for_unit(actor_id)
	_director.flush_plan_refresh_signals_if_pending()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	assert_bool(not _plan_has_committed_skill(skill_id, actor_id)).override_failure_message(
		"%s: undo must remove the committed skill; plan=%s"
		% [_scenario_diagnostic(skill_id), _plan_debug()],
	).is_true()
	var slots: Dictionary = await _commit_live_click(runner, actor_id, arm_cell)
	if is_target_pick:
		assert_bool(_plan_has_awaiting(actor_id)).override_failure_message(
			"%s: recommit must re-arm target selection; plan=%s slots=%s"
			% [_scenario_diagnostic(skill_id), _plan_debug(), _slots_debug(slots)],
		).is_true()
		slots = await _commit_live_click(runner, actor_id, _case_target_cell(skill_id))
	assert_bool(_slots_invalid(slots)).override_failure_message(
		"%s: recommit slots invalid=%s slots=%s"
		% [_scenario_diagnostic(skill_id), str(slots.get("invalid", false)), _slots_debug(slots)],
	).is_false()
	assert_bool(_plan_has_committed_skill(skill_id, actor_id)).override_failure_message(
		"%s: recommit must restore the selected skill; plan=%s"
		% [_scenario_diagnostic(skill_id), _plan_debug()],
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
	var local: Vector2 = _scene.grid_to_local(cell)
	var slots: Dictionary
	if _plan_has_awaiting(unit_id):
		slots = _input._build_commit_slots_at_cell(unit_id, cell)
	else:
		slots = _input._final_commit_slots_for_click_at_cell(unit_id, cell, Vector2.ZERO)
	if _slots_invalid(slots):
		return slots
	_input.on_left_press(local)
	await runner.simulate_frames(2, _DELTA_MS)
	_input.on_left_release(local)
	_director.flush_plan_refresh_signals_if_pending()
	_input.clear_qa_pointer_override()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_assert_committed_slots_match_preview(unit_id, slots)
	return slots


func _commit_live_drag(
	runner: GdUnitSceneRunner,
	unit_id: int,
	cell: Vector2i,
) -> Dictionary:
	_director.select_unit(unit_id)
	var actor: UnitState = _director.board.get_unit_by_id(unit_id)
	assert_object(actor).is_not_null()
	if actor == null:
		return {"invalid": "actor_missing"}
	_input.clear_qa_pointer_override()
	_input.set_qa_pointer_grid_cell(actor.position)
	_input.on_hover_moved(actor.position)
	var local: Vector2 = _scene.grid_to_local(actor.position)
	_input.on_left_press(local)
	await runner.simulate_frames(3, _DELTA_MS)
	_input.set_qa_pointer_grid_cell(cell)
	_input.try_activate_drag(_scene.grid_to_local(cell))
	await runner.simulate_frames(2, _DELTA_MS)
	local = _scene.grid_to_local(cell)
	_input.update_drag(local)
	await runner.simulate_frames(2, _DELTA_MS)
	var slots: Dictionary = _input._final_commit_slots_for_drop_at_cell(
		unit_id, cell, Vector2.ZERO, _input._snapshot_drag_legal_move_tiles(),
	)
	if _slots_invalid(slots):
		_input.on_left_release(local)
		_input.clear_qa_pointer_override()
		return slots
	_input.on_left_release(local)
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)
	_director.flush_plan_refresh_signals_if_pending()
	_input.clear_qa_pointer_override()
	_assert_committed_slots_match_preview(unit_id, slots)
	return slots


func _assert_committed_slots_match_preview(unit_id: int, slots: Dictionary) -> void:
	var plan: Timeline = _director.get_player_plan()
	for column: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(column, []):
			if not raw is TimelineAction:
				continue
			var expected: TimelineAction = raw as TimelineAction
			var matched := false
			for actual: TimelineAction in plan.entries:
				if actual.actor_id != unit_id or actual.type != expected.type:
					continue
				if actual.target_coord != expected.target_coord:
					continue
				if actual.ability != null or expected.ability != null:
					if actual.ability == null or expected.ability == null:
						continue
					if actual.ability.id != expected.ability.id:
						continue
					if actual.awaiting_target != expected.awaiting_target:
						continue
				if actual.target_unit_id != expected.target_unit_id:
					continue
				matched = true
				break
			assert_bool(matched).override_failure_message(
				"preview/commit mismatch: column=%s expected=%s slots=%s plan=%s"
				% [column, _action_debug(expected), _slots_debug(slots), _plan_debug()],
			).is_true()


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


func _first_slot_action(slots: Dictionary) -> TimelineAction:
	for column: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(column, []):
			if raw is TimelineAction:
				return raw as TimelineAction
	return null


func _pre_move_target(slots: Dictionary) -> Vector2i:
	for raw: Variant in slots.get("pre", []):
		if raw is TimelineAction:
			var action: TimelineAction = raw as TimelineAction
			if action.type == GameEnums.ActionType.MOVE:
				return action.target_coord
	return Vector2i(-999999, -999999)


func _committed_action_for_ability(actor_id: int, ability_id: StringName) -> TimelineAction:
	for action: TimelineAction in _director.get_player_plan().entries:
		if (
			action.actor_id == actor_id
			and action.type == GameEnums.ActionType.ABILITY
			and action.ability != null
			and action.ability.id == ability_id
			and not action.awaiting_target
		):
			return action
	return null


func _action_debug(action: TimelineAction) -> String:
	if action == null:
		return "<null>"
	return "type=%s ability=%s target=%s unit=%d awaiting=%s waypoints=%s" % [
		str(action.type),
		str(action.ability.id) if action.ability != null else "<none>",
		str(action.target_coord),
		action.target_unit_id,
		str(action.awaiting_target),
		str(action.waypoints),
	]


func _scenario_diagnostic(skill_id: StringName) -> String:
	var actor_id: int = _unit_id_at(_director.board, _case_actor_cell(skill_id))
	var actor: UnitState = _director.board.get_unit_by_id(actor_id)
	return "%s actor=%d pos=%s target=%s plan=%s" % [
		str(skill_id),
		actor_id,
		str(actor.position) if actor != null else "<missing>",
		str(_case_target_cell(skill_id)),
		_plan_debug(),
	]


func _ability_by_id(unit: UnitState, skill_id: StringName) -> AbilityData:
	if unit == null:
		return null
	for ability: AbilityData in unit.active_abilities:
		if ability != null and ability.id == skill_id:
			return ability
	return null


func _ability_index(unit: UnitState, ability: AbilityData) -> int:
	for index: int in range(unit.active_abilities.size()):
		var candidate: AbilityData = unit.active_abilities[index]
		if candidate == ability or (
			candidate != null and ability != null and candidate.id == ability.id
		):
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
