## Tier 2 live Bruiser acceptance.
##
## Each movement skill and active uses its own actor cell per batch, commits through
## preview slots, and resolves via Simulator. Shaped skills assert overlay red tiles
## match AbilitySystem blast footprint (exact set + count) via AoeFootprintQaHarness.
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _SETTLE_FRAMES: int = 8
const _DELTA_MS: int = 16
const _OVERLAY_QA := preload("res://tests/live_overlay_qa_mixin.gd")
const _MOVEMENT_QA := preload("res://tests/live_movement_timeline_qa_mixin.gd")
const _LIVE_EVENT_BARS: Dictionary = {
	&"bruiser_push_through": {"damage": 0, "moves": 1, "pushes": 1, "self_damage": 0},
	&"bruiser_charge_strike": {"damage": 1, "moves": 1, "pushes": 1, "self_damage": 0},
	&"bruiser_concussion_blow": {"damage": 1, "moves": 0, "pushes": 1, "self_damage": 0},
	&"bruiser_cleave": {"damage": 1, "moves": 0, "pushes": 0, "self_damage": 0},
	&"bruiser_suplex": {"damage": 1, "moves": 0, "pushes": 0, "self_damage": 0},
	&"bruiser_adrenaline_surge": {"damage": 0, "moves": 0, "pushes": 0, "self_damage": 1},
	&"bruiser_earthshatter": {"damage": 1, "moves": 0, "pushes": 0, "self_damage": 0},
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
	{"id": &"bruiser_charge_strike", "observation": &"movement_damage", "upgrade_keys": [&"ghost_move", &"bonus_dmg_from_occupied"]},
	{"id": &"bruiser_concussion_blow", "observation": &"damage_displacement", "upgrade_keys": [&"enemy_collision_stagger_both"]},
	{"id": &"bruiser_cleave", "observation": &"damage", "upgrade_keys": [&"weapon_scaled"]},
	{"id": &"bruiser_suplex", "observation": &"damage_displacement", "upgrade_keys": [&"bonus_dmg_per_10_hp"]},
	{"id": &"bruiser_adrenaline_surge", "observation": &"self_buff", "upgrade_keys": [&"pre_move_timing"]},
	{"id": &"bruiser_earthshatter", "observation": &"damage", "upgrade_keys": [&"buff_per_destroyed_object"]},
	{"id": &"bruiser_meat_shield", "observation": &"swap", "upgrade_keys": [&"intercept_grant_str"]},
	{"id": &"bruiser_frenzy", "observation": &"damage", "upgrade_keys": [&"frenzy_on_kill_ap"]},
	{"id": &"bruiser_guttural_roar", "observation": &"aoe_displacement", "upgrade_keys": [&"push_board_items", &"item_collision_damage"]},
	{"id": &"bruiser_headbutt", "observation": &"damage_status", "upgrade_keys": [&"bonus_dmg_pct_max_hp"]},
	{"id": &"bruiser_blood_boil", "observation": &"self_buff", "upgrade_keys": [&"next_attack_strength"]},
	{"id": &"bruiser_violent_collision", "observation": &"movement", "upgrade_keys": [&"stagger_on_collision"]},
	{"id": &"bruiser_crimson_whirlwind", "observation": &"aoe_damage", "upgrade_keys": [&"heal_if_targets_gte"]},
	{"id": &"bruiser_belly_flop", "observation": &"movement", "upgrade_keys": [&"landing_push"]},
	{"id": &"bruiser_breaching_dash", "observation": &"movement", "upgrade_keys": [&"next_attack_pierce"]},
]

const _BATCHES: Array[Dictionary] = [
	{
		"extra_players": [Vector2i(1, 3), Vector2i(2, 8), Vector2i(8, 8), Vector2i(5, 5)],
		"dummies": [Vector2i(3, 3), Vector2i(4, 8), Vector2i(7, 8)],
		"skills": [&"bruiser_push_through", &"bruiser_charge_strike", &"bruiser_concussion_blow", &"bruiser_cleave"],
	},
	{
		"extra_players": [Vector2i(2, 2), Vector2i(2, 8), Vector2i(7, 8), Vector2i(8, 8)],
		"dummies": [Vector2i(5, 5), Vector2i(4, 2), Vector2i(4, 8), Vector2i(3, 8)],
		"skills": [&"bruiser_suplex", &"bruiser_adrenaline_surge", &"bruiser_earthshatter"],
	},
	{
		"extra_players": [Vector2i(2, 2), Vector2i(3, 2)],
		"dummies": [],
		"skills": [&"bruiser_meat_shield"],
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
		"extra_players": [Vector2i(1, 3)],
		"dummies": [Vector2i(3, 3)],
		"skills": [&"bruiser_violent_collision"],
	},
	{
		"extra_players": [Vector2i(4, 3)],
		"dummies": [Vector2i(5, 4)],
		"skills": [&"bruiser_belly_flop"],
	},
	{
		"extra_players": [Vector2i(3, 3)],
		"dummies": [],
		"skills": [&"bruiser_breaching_dash"],
	},
]

const _CASE_ACTORS: Dictionary = {
	&"bruiser_push_through": Vector2i(4, 5),
	&"bruiser_charge_strike": Vector2i(1, 3),
	&"bruiser_concussion_blow": Vector2i(2, 8),
	&"bruiser_cleave": Vector2i(8, 8),
	&"bruiser_suplex": Vector2i(4, 5),
	&"bruiser_adrenaline_surge": Vector2i(2, 2),
	&"bruiser_earthshatter": Vector2i(2, 8),
	&"bruiser_meat_shield": Vector2i(2, 2),
	&"bruiser_frenzy": Vector2i(4, 5),
	&"bruiser_guttural_roar": Vector2i(2, 2),
	&"bruiser_headbutt": Vector2i(2, 8),
	&"bruiser_blood_boil": Vector2i(8, 8),
	&"bruiser_violent_collision": Vector2i(1, 3),
	&"bruiser_crimson_whirlwind": Vector2i(4, 5),
	&"bruiser_belly_flop": Vector2i(4, 3),
	&"bruiser_breaching_dash": Vector2i(3, 3),
}

const _CASE_PREMOVE_RUN: Dictionary = {
	&"bruiser_violent_collision": Vector2i(2, 3),
	&"bruiser_breaching_dash": Vector2i(4, 3),
}

const _CASE_ARM: Dictionary = {
	&"bruiser_charge_strike": Vector2i(2, 3),
}

const _CASE_TARGETS: Dictionary = {
	&"bruiser_push_through": Vector2i(5, 5),
	&"bruiser_charge_strike": Vector2i(3, 3),
	&"bruiser_concussion_blow": Vector2i(4, 8),
	&"bruiser_cleave": Vector2i(7, 8),
	&"bruiser_suplex": Vector2i(5, 5),
	&"bruiser_adrenaline_surge": Vector2i(2, 2),
	&"bruiser_earthshatter": Vector2i(3, 8),
	&"bruiser_meat_shield": Vector2i(3, 2),
	&"bruiser_frenzy": Vector2i(5, 5),
	&"bruiser_guttural_roar": Vector2i(2, 2),
	&"bruiser_headbutt": Vector2i(3, 8),
	&"bruiser_blood_boil": Vector2i(8, 8),
	&"bruiser_violent_collision": Vector2i(4, 3),
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
	session.dummy_coords = [Vector2i(5, 4), Vector2i(5, 6), Vector2i(6, 5)]
	session.unkillable_dummies = true
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
	var hit_outside := false
	for event: SimEvent in result.events:
		if event.type != GameEnums.SimEventType.UNIT_DAMAGED:
			continue
		var victim: int = int(event.data.get("unit", -1))
		if victim == _unit_id_at(_director.base_board, Vector2i(5, 4)):
			hit_north = true
		if victim == _unit_id_at(_director.base_board, Vector2i(5, 6)):
			hit_south = true
		if victim == _unit_id_at(_director.base_board, Vector2i(6, 5)):
			hit_outside = true
	assert_bool(hit_north and hit_south).override_failure_message(
		"Cleave tile-aim must damage both ARC neighbors when center tile is empty",
	).is_true()
	assert_bool(not hit_outside).override_failure_message(
		"Cleave tile-aim must not damage the diagonal/outside dummy",
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
	_scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _DELTA_MS)

	_director = _scene.get_node("CombatDirector") as CombatDirector
	var shell := _scene.get_node("CombatShell") as TacticalCombatShell
	_input = shell.planning_input
	_overlay = _scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	_director.auto_run = false
	for listed_skill: StringName in batch.skills:
		var listed_case := _case_by_id(listed_skill)
		if String(listed_case.get("observation", "")) == "movement_damage":
			_director.auto_run = true
			break
	if batch.skills.has(&"bruiser_violent_collision"):
		var wall: TerrainData = DataLibrary.get_terrain(&"wall")
		assert_object(wall).override_failure_message(
			"violent_collision: live recast fixture requires a wall terrain",
		).is_not_null()
		if wall != null:
			_director.base_board.set_tile_terrain(Vector2i(5, 3), wall)
			_director.board.set_tile_terrain(Vector2i(5, 3), wall)
			_director.base_board.set_tile_terrain(Vector2i(4, 4), wall)
			_director.board.set_tile_terrain(Vector2i(4, 4), wall)
	for unit: UnitState in _director.base_board.units:
		if unit.definition != null and unit.definition.id == &"training_dummy":
			unit.health.current_hp = 10000
		if unit.team == GameEnums.Team.PLAYER:
			unit.ability.points_left = maxi(unit.ability.points_left, 1)
			unit.movement.points_left = maxi(unit.movement.points_left, unit.movement.max_points)
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
		assert_int(_director.selected_unit_id).override_failure_message(
			"%s: selected unit changed before preview" % _scenario_diagnostic(skill_id),
		).is_equal(actor_id)
		assert_int(_director.selected_ability_index).override_failure_message(
			"%s: selected ability index drifted" % _scenario_diagnostic(skill_id),
		).is_equal(_ability_index(actor, ability))
		var target_cell: Vector2i = _case_first_aim_cell(skill_id)
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
		var stand_cell: Vector2i = CombatPlanningPreview.planning_latest_stand_cell(
			_director, _director.board, actor_id,
		)
		var arm_cell: Vector2i = stand_cell if is_awaiting_skill else _case_target_cell(skill_id)
		var preview_slots: Dictionary = _input._final_commit_slots_for_click_at_cell(
			actor_id, arm_cell, Vector2.ZERO,
		)
		assert_bool(_slots_invalid(preview_slots)).override_failure_message(
			"%s: hover slots invalid=%s slots=%s plan=%s"
			% [_scenario_diagnostic(skill_id), str(preview_slots.get("invalid", false)),
				_slots_debug(preview_slots), _plan_debug()],
		).is_false()
		var preview_action: TimelineAction = _first_slot_action(preview_slots)
		if preview_action != null and preview_action.awaiting_target:
			is_awaiting_skill = true
			arm_cell = stand_cell
			preview_slots = _input._final_commit_slots_for_click_at_cell(
				actor_id, arm_cell, Vector2.ZERO,
			)
			preview_action = _first_slot_action(preview_slots)
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
		var case_observation: String = String(_case_by_id(skill_id).get("observation", ""))
		var expects_move_preview: bool = (
			has_pre_move and case_observation == "movement_damage"
		)
		if expects_move_preview:
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
		var tile_move_commit: bool = (
			ability != null
			and ability.has_targeting(GameEnums.TargetingFlags.TILE)
			and AbilitySystem.ability_has_movement_effect(ability)
			and AbilitySystem.planning_commit_flow(actor, ability)
			== GameEnums.PlanningCommitFlow.IMMEDIATE
		)
		if tile_move_commit:
			slots = await _commit_live_click(
				runner, actor_id, _case_target_cell(skill_id),
			)
		elif is_awaiting_skill:
			slots = await _commit_live_click(
				runner, actor_id, arm_cell,
			)
		else:
			slots = await _commit_live_click(
				runner, actor_id, _case_target_cell(skill_id),
			)
		if is_awaiting_skill and not tile_move_commit:
			assert_bool(_plan_has_awaiting(actor_id)).override_failure_message(
				"%s: first click must leave an awaiting action; plan=%s slots=%s"
				% [_scenario_diagnostic(skill_id), _plan_debug(), _slots_debug(slots)],
			).is_true()
			if _CASE_ARM.has(skill_id):
				var awaiting_move := _director.find_awaiting_action(actor_id)
				assert_object(awaiting_move).override_failure_message(
					"%s: self-arm must leave MOVE module awaiting; plan=%s"
					% [_scenario_diagnostic(skill_id), _plan_debug()],
				).is_not_null()
				if awaiting_move != null:
					assert_int(awaiting_move.awaiting_module_index).override_failure_message(
						"%s: first arm must await the MOVE module; action=%s"
						% [_scenario_diagnostic(skill_id), _action_debug(awaiting_move)],
					).is_equal(0)
					assert_bool(
						_input._is_awaiting_movement_endpoint(actor, ability)
					).override_failure_message(
						"%s: MOVE module must use the movement endpoint preview"
						% _scenario_diagnostic(skill_id),
					).is_true()
				var landing: Vector2i = _CASE_ARM[skill_id]
				slots = await _commit_live_click(runner, actor_id, landing)
				var awaiting_strike := _director.find_awaiting_action(actor_id)
				assert_object(awaiting_strike).override_failure_message(
					"%s: MOVE commit must leave a later NEW_AIM armed; plan=%s"
					% [_scenario_diagnostic(skill_id), _plan_debug()],
				).is_not_null()
				if awaiting_strike != null:
					assert_int(awaiting_strike.awaiting_module_index).override_failure_message(
						"%s: strike aim must be the later NEW_AIM module; action=%s"
						% [_scenario_diagnostic(skill_id), _action_debug(awaiting_strike)],
					).is_equal(1)
					assert_bool(
						not _input._is_awaiting_movement_endpoint(actor, ability)
					).override_failure_message(
						"%s: strike aim must not reuse the walk destination preview"
						% _scenario_diagnostic(skill_id),
					).is_true()
					assert_object(_input._route_pathfinding_ability(actor)).override_failure_message(
						"%s: strike aim must not paint a walk path"
						% _scenario_diagnostic(skill_id),
					).is_null()
				var strike_cell: Vector2i = _case_target_cell(skill_id)
				await _OVERLAY_QA.sync_attack_hover(
					runner, _input, _overlay, _director, strike_cell, _DELTA_MS,
				)
				var action_tiles: Array[Vector2i] = _overlay.get_hover_action_range_tiles()
				assert_bool(action_tiles.has(strike_cell)).override_failure_message(
					"%s: strike aim range must include the enemy; tiles=%s"
					% [_scenario_diagnostic(skill_id), str(action_tiles)],
				).is_true()
				assert_bool(not action_tiles.has(landing + Vector2i(2, 0))).override_failure_message(
					"%s: strike aim must not show the walk destination bubble; tiles=%s"
					% [_scenario_diagnostic(skill_id), str(action_tiles)],
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
				).is_equal(_case_first_aim_cell(skill_id))
				if _CASE_ARM.has(skill_id):
					assert_that(AbilitySystem.module_target_coord(committed, 1)).override_failure_message(
						"%s: second aim must be the enemy cell; action=%s"
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
		var committed_ability: AbilityData = _factory_ability(skill_id)
		if committed_ability != null:
			await _MOVEMENT_QA.assert_committed(
				self,
				skill_id,
				_director,
				actor_id,
				committed_ability,
				slots,
				_input,
				_overlay,
				runner,
			)
	var result: SimResult = Simulator.simulate(_director.base_board, _director.get_player_plan())
	for skill_id: StringName in batch.skills:
		var case := _case_by_id(skill_id)
		var actor_id := _unit_id_at(_director.base_board, _case_actor_cell(skill_id))
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
	assert_bool(ability.modules.size() > 0).override_failure_message(
		"%s: authored modules must not be empty" % case.id,
	).is_true()
	if case.upgrade_keys.size() > 0:
		assert_bool(ability.upgraded_modules.size() > 0).override_failure_message(
			"%s: authored [+] modules must not be empty" % case.id,
		).is_true()
	var primary: AbilityModule = expected.modules[0]
	assert_that(ability.modules[0].primary_type).override_failure_message(
		"%s: primary effect type drift" % case.id,
	).is_equal(primary.primary_type)
	assert_int(ability.modules[0].amount).override_failure_message(
		"%s: primary effect amount drift" % case.id,
	).is_equal(primary.amount)
	for key: StringName in case.upgrade_keys:
		assert_bool(_modules_have_key(ability, key)).override_failure_message(
			"%s: missing [+] typed module field or keyword %s" % [case.id, key],
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
	var base_actor: UnitState = _director.base_board.get_unit_by_id(actor_id)
	var ability: AbilityData = _ability_by_id(base_actor, skill_id)
	if ability != null and ability.target_shape != GameEnums.TargetShape.SINGLE:
		_assert_live_shaped_targets(result, skill_id, actor_id, ability)
	match skill_id:
		&"bruiser_push_through", &"bruiser_charge_strike", &"bruiser_concussion_blow":
			var pushed_id: int = int(_batch_target_ids.get(skill_id, -1))
			var pushed_before: UnitState = _director.base_board.get_unit_by_id(pushed_id)
			var pushed_after: UnitState = final_state.get_unit_by_id(pushed_id)
			assert_object(pushed_before).is_not_null()
			assert_object(pushed_after).is_not_null()
			if pushed_before != null and pushed_after != null:
				var push_delta: Vector2i = pushed_after.position - pushed_before.position
				assert_int(absi(push_delta.x) + absi(push_delta.y)).override_failure_message(
					"%s: pushed target must move exactly one cardinal tile; before=%s after=%s delta=%s"
					% [skill_id, pushed_before.position, pushed_after.position, push_delta],
				).is_equal(1)
		&"bruiser_suplex":
			var target_id: int = int(_batch_target_ids.get(skill_id, -1))
			var target: UnitState = final_state.get_unit_by_id(target_id)
			assert_object(target).is_not_null()
			if target != null:
				assert_that(target.position).override_failure_message(
					"suplex: target must land behind caster, not merely be displaced",
				).is_equal(Vector2i(3, 5))
		&"bruiser_violent_collision":
			var collision_id: int = _unit_id_at(_director.base_board, Vector2i(3, 3))
			var collision_target: UnitState = final_state.get_unit_by_id(collision_id)
			assert_object(collision_target).is_not_null()
			var collision_seen: bool = false
			for event: SimEvent in result.events:
				if (
					event.type == GameEnums.SimEventType.COLLISION
					and int(event.data.get("unit", -1)) == collision_id
				):
					collision_seen = true
					break
			assert_bool(collision_seen).override_failure_message(
				"violent_collision: live dash must resolve a collision against the corridor dummy",
			).is_true()
			assert_bool(
				ability != null
				and not ability.modules.is_empty()
				and ability.modules[0].violent_collision_recast > 0,
			).override_failure_message(
				"violent_collision: live selected module must carry the recast collision rule",
			).is_true()
			var projection_board: BoardState = _director.base_board.clone()
			var projection_events: Array[SimEvent] = []
			Simulator.simulate_player_turn(
				projection_board, _director.get_player_plan(), projection_events,
			)
			var projected_actor: UnitState = projection_board.get_unit_by_id(actor_id)
			assert_bool(
				projected_actor != null
				and projected_actor.passive_flags.get("violent_collision_recast_used", false),
			).override_failure_message(
				"violent_collision: player-phase simulation must expose the recast before turn reset",
			).is_true()
		&"bruiser_belly_flop":
			assert_that(final_actor.position).override_failure_message(
				"belly_flop: final actor position must be the JUMP landing tile",
			).is_equal(_case_target_cell(skill_id))
			var landing_target_id: int = _unit_id_at(_director.base_board, Vector2i(5, 4))
			var landing_target: UnitState = final_state.get_unit_by_id(landing_target_id)
			assert_object(landing_target).is_not_null()
			if landing_target != null:
				assert_bool(landing_target.health.current_hp < 10000).override_failure_message(
					"belly_flop: adjacent dummy must take landing damage",
				).is_true()
		&"bruiser_frenzy":
			var frenzy_target_id: int = int(_batch_target_ids.get(skill_id, -1))
			assert_int(_count_damage_events(result.events, actor_id, frenzy_target_id)).override_failure_message(
				"frenzy: exactly three hits must land on the selected target",
			).is_equal(3)
		&"bruiser_adrenaline_surge":
			assert_int(_self_damage_total(result.events, actor_id)).override_failure_message(
				"adrenaline_surge: self-cost must be exactly 5 HP",
			).is_equal(5)
			assert_int(_status_value(final_actor, GameEnums.StatusType.STAT_BUFF_STR)).override_failure_message(
				"adrenaline_surge: STR must be deferred to next turn",
			).is_equal(0)
			assert_int(_status_value(final_actor, GameEnums.StatusType.STAT_BUFF_MOV)).override_failure_message(
				"adrenaline_surge: MOV must be deferred to next turn",
			).is_equal(0)
			assert_int(int(final_actor.passive_flags.get("next_turn_str_bonus", 0))).override_failure_message(
				"adrenaline_surge: next-turn STR bonus must be pending",
			).is_equal(1)
			assert_int(int(final_actor.passive_flags.get("next_turn_max_move_bonus", 0))).override_failure_message(
				"adrenaline_surge: next-turn MOV bonus must be pending",
			).is_equal(1)
		&"bruiser_blood_boil":
			assert_int(_self_damage_total(result.events, actor_id)).override_failure_message(
				"blood_boil: self-cost must be exactly 5 HP",
			).is_equal(5)
			assert_int(_status_value(final_actor, GameEnums.StatusType.STAT_BUFF_STR)).override_failure_message(
				"blood_boil: no same-turn STR status; effect is deferred to next turn",
			).is_equal(0)
			assert_int(
				int(final_actor.passive_flags.get("next_turn_attack_strength_bonus", 0))
			).override_failure_message(
				"blood_boil: next-turn ATK bonus must be pending after commit",
			).is_equal(2)
			assert_bool(
				final_actor.passive_flags.get("next_turn_attack_bleed_weapon", false)
			).override_failure_message(
				"blood_boil: next-turn BLEED WPN flag must be pending after commit",
			).is_true()
		&"bruiser_headbutt":
			var headbutt_target_id: int = int(_batch_target_ids.get(skill_id, -1))
			var headbutt_target: UnitState = final_state.get_unit_by_id(headbutt_target_id)
			assert_object(headbutt_target).is_not_null()
			if headbutt_target != null:
				assert_bool(final_actor.has_status(GameEnums.StatusType.STAGGER)).override_failure_message(
					"headbutt: caster must receive mutual STAGGER",
				).is_true()
				assert_bool(headbutt_target.has_status(GameEnums.StatusType.STAGGER)).override_failure_message(
					"headbutt: selected target must receive mutual STAGGER",
				).is_true()
		&"bruiser_breaching_dash":
			assert_bool(final_actor.position == _case_target_cell(skill_id)).override_failure_message(
				"breaching_dash: actor must land on the committed dash endpoint",
			).is_true()


func _assert_live_shaped_targets(
	result: SimResult,
	skill_id: StringName,
	actor_id: int,
	ability: AbilityData,
) -> void:
	var base_actor: UnitState = _director.base_board.get_unit_by_id(actor_id)
	if base_actor == null:
		return
	var target_cell: Vector2i = _case_target_cell(skill_id)
	var footprint: Array = []
	if ability.range_tiles <= 0:
		footprint = GridSystem.get_affected_tiles(
			_director.base_board, base_actor.position, base_actor.position,
			ability.target_shape, ability.target_shape_size,
		)
	else:
		footprint = AbilitySystem.planning_blast_tiles_at_target(
			_director.base_board, base_actor, ability, base_actor.position, target_cell,
		)
	assert_bool(not footprint.is_empty()).override_failure_message(
		"%s: live exact footprint must not be empty" % skill_id,
	).is_true()
	var expected_ids: Array[int] = []
	for unit: UnitState in _director.base_board.units:
		if unit.team == GameEnums.Team.ENEMY and footprint.has(unit.position):
			expected_ids.append(unit.id)
	var expects_damage: bool = false
	for effect: EffectData in AbilitySystem.active_effects_for(base_actor, ability):
		if effect != null and effect.type == GameEnums.EffectType.DAMAGE:
			expects_damage = true
			break
	var actual_ids: Dictionary = {}
	if expects_damage:
		for unit: UnitState in _director.base_board.units:
			if unit.team != GameEnums.Team.ENEMY:
				continue
			var after: UnitState = result.final_state.get_unit_by_id(unit.id)
			if after != null and after.health.current_hp < unit.health.current_hp:
				actual_ids[unit.id] = true
		for expected_id: int in expected_ids:
			assert_bool(actual_ids.has(expected_id)).override_failure_message(
				"%s: expected footprint victim %d was not damaged; expected=%s actual=%s"
				% [skill_id, expected_id, str(expected_ids), str(actual_ids.keys())],
			).is_true()
	else:
		for expected_id: int in expected_ids:
			var affected: UnitState = result.final_state.get_unit_by_id(expected_id)
			assert_bool(
				affected != null
				and _status_value(affected, GameEnums.StatusType.STAT_DEBUFF_DEF) == 2,
			).override_failure_message(
				"%s: expected footprint victim %d lacks DEF -2; expected=%s"
				% [skill_id, expected_id, str(expected_ids)],
			).is_true()
	for unit: UnitState in _director.base_board.units:
		if unit.team != GameEnums.Team.ENEMY or expected_ids.has(unit.id):
			continue
		var outside_after: UnitState = result.final_state.get_unit_by_id(unit.id)
		assert_object(outside_after).is_not_null()
		if outside_after != null:
			assert_int(outside_after.health.current_hp).override_failure_message(
				"%s: outside-footprint unit %d was damaged" % [skill_id, unit.id],
			).is_equal(unit.health.current_hp)


func _count_damage_events(events: Array[SimEvent], actor_id: int, target_id: int) -> int:
	var count: int = 0
	for event: SimEvent in events:
		if (
			event.type == GameEnums.SimEventType.UNIT_DAMAGED
			and int(event.data.get("source", event.data.get("actor", -1))) == actor_id
			and int(event.data.get("unit", event.data.get("target", -1))) == target_id
		):
			count += 1
		elif (
			event.type == GameEnums.SimEventType.MATH_TELEMETRY
			and event.data.get("type", "") == "damage"
			and int(event.data.get("actor_id", -1)) == actor_id
		):
			count += 1
	return count


func _self_damage_total(events: Array[SimEvent], actor_id: int) -> int:
	var total: int = 0
	for event: SimEvent in events:
		if (
			event.type == GameEnums.SimEventType.UNIT_DAMAGED
			and int(event.data.get("target", event.data.get("unit", -1))) == actor_id
		):
			total += int(event.data.get("amount", 0))
	return total


func _status_value(unit: UnitState, status_type: GameEnums.StatusType) -> int:
	if unit == null:
		return 0
	for status: StatusData in unit.active_statuses:
		if status.type == status_type:
			return status.value
	return 0


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
		"%s: committed skill never emitted ABILITY_USED; plan=%s events=%s"
		% [case.id, _plan_debug(), str(events)],
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
	_input.on_hover_moved(cell)
	_input._flush_hover_heavy_sync()
	var slots: Dictionary
	if _plan_has_awaiting(unit_id):
		slots = _input._build_commit_slots_at_cell(unit_id, cell)
	else:
		slots = _input._final_commit_slots_for_click_at_cell(unit_id, cell, Vector2.ZERO)
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


func _case_first_aim_cell(skill_id: StringName) -> Vector2i:
	return _CASE_ARM.get(skill_id, _case_target_cell(skill_id))


func _slots_invalid(slots: Dictionary) -> bool:
	var invalid: Variant = slots.get("invalid", false)
	if invalid is bool:
		return invalid
	if invalid is String:
		return not (invalid as String).is_empty()
	return bool(invalid)


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


func _modules_have_key(ability: AbilityData, key: StringName) -> bool:
	if key == &"pre_move_timing":
		return ability.upgraded_planner_group == GameEnums.PlannerGroup.PRE_MOVE
	var modules: Array[AbilityModule] = ability.upgraded_modules
	for module: AbilityModule in modules:
		if module == null:
			continue
		match key:
			&"bonus_dmg_from_occupied":
				if module.bonus_dmg_from_occupied > 0:
					return true
			&"bonus_dmg_per_10_hp":
				if module.bonus_dmg_per_10_hp > 0:
					return true
			&"bonus_dmg_pct_max_hp":
				if module.bonus_dmg_pct_max_hp > 0.0:
					return true
			&"buff_on_push":
				if module.buff_on_push > 0:
					return true
			&"frenzy_on_kill_ap":
				if module.frenzy_on_kill_ap > 0:
					return true
			&"next_attack_strength":
				if module.next_attack_strength > 0:
					return true
			&"landing_push":
				for layer: AbilityLayer in module.layers:
					if (
						layer != null
						and layer.effect != null
						and layer.effect.type == GameEnums.EffectType.PUSH
					):
						return true
			&"heal_if_targets_gte":
				if module.heal_if_targets_gte > 0:
					return true
			&"push_board_items":
				if module.push_board_items > 0:
					return true
			&"item_collision_damage":
				if module.item_collision_damage > 0:
					return true
			&"intercept_grant_str":
				for layer: AbilityLayer in module.layers:
					if layer != null and layer.intercept_grant_str > 0:
						return true
			&"stagger_on_collision":
				for layer: AbilityLayer in module.layers:
					if layer != null and layer.stagger_on_collision:
						return true
			&"buff_per_destroyed_object":
				for layer: AbilityLayer in module.layers:
					if layer != null and layer.buff_per_destroyed_object > 0:
						return true
			&"enemy_collision_stagger_both":
				for layer: AbilityLayer in module.layers:
					if layer != null and layer.enemy_collision_stagger_both:
						return true
			&"weapon_scaled":
				for layer: AbilityLayer in module.layers:
					if layer != null and layer.weapon_scaled:
						return true
			&"ghost_move":
				for keyword: AbilityKeyword in module.keywords:
					if keyword != null and keyword.keyword_id == GameEnums.AbilityKeywordId.GHOST:
						return true
			&"next_attack_pierce":
				for keyword: AbilityKeyword in module.keywords:
					if keyword != null and keyword.keyword_id == GameEnums.AbilityKeywordId.PIERCE:
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
