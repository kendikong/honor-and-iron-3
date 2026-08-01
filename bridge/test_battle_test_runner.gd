class_name TestBattleTestRunner
extends RefCounted

## Headless tests for the skill test arena bridge layer.


static func run_all() -> Dictionary:
	var failures: Array[String] = []
	_test_build_board_unit_counts(failures)
	_test_encounter_matches_board_spawns(failures)
	_test_maintain_training_dummies(failures)
	_test_spawn_validation(failures)
	_test_class_visual_seed_differs(failures)
	_test_unlimited_actions_flag(failures)
	_test_player_loadout_matches_normal_rules(failures)
	_test_extra_players_get_distinct_timeline_slots(failures)
	return {"passed": failures.is_empty(), "failures": failures}


static func _test_build_board_unit_counts(failures: Array[String]) -> void:
	var session := TestBattleSession.new()
	var board: BoardState = TestBattleEncounterBuilder.build_board(session)
	if board.width != TestBattleSession.MAP_SIZE.x or board.height != TestBattleSession.MAP_SIZE.y:
		failures.append("Training board size mismatch")
	var players: int = 0
	var enemies: int = 0
	for unit: UnitState in board.units:
		if unit.team == GameEnums.Team.PLAYER:
			players += 1
		else:
			enemies += 1
	if players != 1 or enemies != 1:
		failures.append("Default training board should have 1 player and 1 dummy")


static func _test_encounter_matches_board_spawns(failures: Array[String]) -> void:
	var session := TestBattleSession.new()
	session.try_add_dummy_at(null, Vector2i(3, 2))
	session.try_add_player_at(null, Vector2i(1, 2))
	var encounter: EncounterData = TestBattleEncounterBuilder.build_encounter(session)
	var board: BoardState = TestBattleEncounterBuilder.build_board(session)
	var encounter_units: int = encounter.player_spawns.size() + encounter.enemy_spawns.size()
	if encounter_units != board.units.size():
		failures.append("Encounter spawn count should match board unit count")


static func _test_maintain_training_dummies(failures: Array[String]) -> void:
	var session := TestBattleSession.new()
	var board: BoardState = TestBattleEncounterBuilder.build_board(session)
	for unit: UnitState in board.units:
		if unit.definition != null and unit.definition.id == &"training_dummy":
			unit.health.current_hp = 0
			break
	TestBattleEncounterBuilder.maintain_training_dummies(board, session)
	if not board.has_living_team(GameEnums.Team.ENEMY):
		failures.append("maintain_training_dummies should revive dead dummies")


static func _test_spawn_validation(failures: Array[String]) -> void:
	var session := TestBattleSession.new()
	var board: BoardState = TestBattleEncounterBuilder.build_board(session)
	var blocked: Dictionary = session.try_add_dummy_at(board, TestBattleSession.DEFAULT_PLAYER_CELL)
	if bool(blocked.get("ok", true)):
		failures.append("Should reject dummy spawn on player cell")
	var free: Dictionary = session.try_add_dummy_at(board, Vector2i(3, 4))
	if not bool(free.get("ok", false)):
		failures.append("Should find free dummy spawn near open cell")


static func _test_class_visual_seed_differs(failures: Array[String]) -> void:
	var knight := UnitState.create(1, DataLibrary.get_unit(&"knight"), GameEnums.Team.PLAYER, Vector2i.ZERO)
	var mage := UnitState.create(2, DataLibrary.get_unit(&"mage"), GameEnums.Team.PLAYER, Vector2i.ZERO)
	var knight_seed: int = UnitVisualFactory.recipe_seed_for_unit_state(knight)
	var mage_seed: int = UnitVisualFactory.recipe_seed_for_unit_state(mage)
	if knight_seed == mage_seed:
		failures.append("Different classes should produce different visual seeds")


static func _test_unlimited_actions_flag(failures: Array[String]) -> void:
	var session := TestBattleSession.new()
	session.infinite_player_ap = true
	var board: BoardState = TestBattleEncounterBuilder.build_board(session)
	var player: UnitState = board.units[0]
	if not player.has_unlimited_training_actions():
		failures.append("Infinite AP toggle should set training_unlimited_actions")
	player.turn_action_used = true
	if not player.can_use_action_slot():
		failures.append("Unlimited training actions should bypass turn_action_used gate")


static func _test_player_loadout_matches_normal_rules(failures: Array[String]) -> void:
	var def: UnitData = DataLibrary.get_unit(&"knight")
	var abilities: Array[AbilityData] = DataLibrary.build_player_active_abilities(def, TestBattleSession.TRAINING_LEVEL)
	if abilities.is_empty():
		failures.append("Training loadout should include abilities")
	var has_run: bool = false
	var has_movement_skill: bool = false
	for ability: AbilityData in abilities:
		if DataLibrary.is_universal_run(ability.id):
			has_run = true
		if ability.is_movement_kind():
			has_movement_skill = true
	if not has_run:
		failures.append("Training loadout should include universal Run")
	if not has_movement_skill:
		failures.append("Knight training loadout should include a movement skill")


static func _test_extra_players_get_distinct_timeline_slots(failures: Array[String]) -> void:
	var session := TestBattleSession.new()
	session.try_add_player_at(null, Vector2i(1, 5))
	session.try_add_player_at(null, Vector2i(2, 5))
	var board: BoardState = TestBattleEncounterBuilder.build_board(session)
	var player_ids: Array[int] = []
	for unit: UnitState in board.units:
		if unit.team != GameEnums.Team.PLAYER:
			continue
		player_ids.append(unit.controlling_player_id)
	player_ids.sort()
	if player_ids != [1, 2, 3]:
		failures.append(
			"Extra allies need distinct controlling_player_id slots (expected [1,2,3], got %s)"
			% str(player_ids),
		)
