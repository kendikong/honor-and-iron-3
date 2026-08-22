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
	_test_debug_report_unit_serialization(failures)
	_test_debug_report_status_workflow(failures)
	_test_player_loadout_matches_normal_rules(failures)
	_test_extra_players_get_distinct_timeline_slots(failures)
	return {"passed": failures.is_empty(), "failures": failures}


static func _test_build_board_unit_counts(failures: Array[String]) -> void:
	var session := TestBattleSession.new()
	var board: BoardState = TestBattleEncounterBuilder.build_board(session)
	if board.grid_size != TestBattleSession.MAP_SIZE:
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


static func _test_debug_report_unit_serialization(failures: Array[String]) -> void:
	var session := TestBattleSession.new()
	session.infinite_player_ap = true
	var board: BoardState = TestBattleEncounterBuilder.build_board(session)
	var player: UnitState = board.units[0]
	player.turn_action_used = true
	var serialized: Dictionary = DebugReportRuntime.serialize_board(board)
	var units: Array = serialized.get("units", [])
	if units.is_empty():
		failures.append("Debug report board serialization missing units")
		return
	var unit_entry: Dictionary = units[0] as Dictionary
	for key: String in [
		"turn_action_used",
		"action_column_spent",
		"has_used_turn_action",
		"training_unlimited_actions",
		"can_use_action_slot",
	]:
		if not unit_entry.has(key):
			failures.append("Debug report unit serialization missing %s" % key)
	if not bool(unit_entry.get("turn_action_used", false)):
		failures.append("Debug report should record turn_action_used=true")
	if bool(unit_entry.get("has_used_turn_action", true)):
		failures.append("Debug report should record has_used_turn_action=false in unlimited mode")
	if not bool(unit_entry.get("training_unlimited_actions", false)):
		failures.append("Debug report should record training_unlimited_actions=true")
	var move: TimelineAction = TimelineAction.make_move(
		player.id, Vector2i(3, 5), -1, [], GameEnums.MoveTiming.POST_ACTION,
	)
	var slots: Dictionary = {
		"pre": [],
		"action": [],
		"post": [move],
		"_preview_validated": true,
	}
	var slot_dump: Dictionary = DebugReportRuntime.serialize_commit_slots(slots)
	if (slot_dump.get("post", []) as Array).size() != 1:
		failures.append("Debug report commit slot serialization missing post-move entry")
	var post_entry: Dictionary = (slot_dump.get("post", []) as Array)[0] as Dictionary
	if String(post_entry.get("move_timing_name", "")) != "POST_ACTION":
		failures.append("Debug report commit slot should preserve POST_ACTION timing name")


static func _test_debug_report_status_workflow(failures: Array[String]) -> void:
	if DebugReportRuntime.normalize_status("open") != DebugReportRuntime.STATUS_ONGOING:
		failures.append("Debug report status should normalize open -> ongoing")
	if DebugReportRuntime.normalize_status("fixed") != DebugReportRuntime.STATUS_DONE:
		failures.append("Debug report status should normalize fixed -> done")
	if DebugReportRuntime.status_display_name(DebugReportRuntime.STATUS_TRASH) != "Trash":
		failures.append("Debug report trash display name missing")
	var runtime := DebugReportRuntime.new()
	var report_id := "BUG-TEST-STATUS-%d" % (Time.get_ticks_msec() % 100000)
	var user_dir := ProjectSettings.globalize_path("user://bug_reports")
	DirAccess.make_dir_recursive_absolute(user_dir)
	var json_path := "%s/%s.json" % [user_dir, report_id]
	var seed_report := {
		"report_id": report_id,
		"status": "open",
		"created_at": "2026-08-22T00:00:00",
		"category": "Bug",
		"severity": "Low",
		"title": "status workflow probe",
	}
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		failures.append("Debug report status test could not write probe JSON")
		return
	file.store_string(JSON.stringify(seed_report, "\t"))
	file.close()
	if not runtime.set_report_status(report_id, DebugReportRuntime.STATUS_DONE):
		failures.append("Debug report set_report_status failed for probe report")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not parsed is Dictionary:
		failures.append("Debug report status test could not read probe JSON")
	else:
		var status: String = String((parsed as Dictionary).get("status", ""))
		if status != DebugReportRuntime.STATUS_DONE:
			failures.append(
				"Debug report status test expected done, got %s" % status,
			)
	var summaries: Array[Dictionary] = runtime.list_reports(true)
	var found := false
	for summary: Dictionary in summaries:
		if String(summary.get("report_id", "")) == report_id:
			found = true
			if String(summary.get("status", "")) != DebugReportRuntime.STATUS_DONE:
				failures.append("Debug report list_reports did not return normalized done status")
			break
	if not found:
		failures.append("Debug report list_reports missing probe report")
	if FileAccess.file_exists(json_path):
		DirAccess.remove_absolute(json_path)


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
