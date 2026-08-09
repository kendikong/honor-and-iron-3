class_name MovementTimelineQaHarness
extends RefCounted

## Movement skills must prove PRE-MOVE or POST-MOVE timeline legs in QA (not action column only).

const _PLANNING_CHECKLIST := preload("res://tests/planning_checklist_harness.gd")

const _TIMELINE_LEG_MARKERS: Array[String] = [
	"assert_pre_or_post_leg_if_needed(",
	"assert_planning_timeline_after_commit(",
	"run_planning_commit_smoke(",
	"run_planning_ally_smoke(",
	"run_planning_premove_proof(",
	"commit_premove_run_if_needed(",
	"commit_run_premove_headless(",
]

const _PREVIEW_ORIGIN_MARKERS: Array[String] = [
	"assert_move_preview_origin(",
	"assert_move_preview_origin_live(",
	"run_planning_commit_smoke(",
	"run_planning_ally_smoke(",
	"BruiserPlanningSmokeRegistry.run_for_factory_id(",
]

const _SCENARIO_REGISTRIES: Array[GDScript] = [
	preload("res://tests/bruiser_scenario_registry.gd"),
	preload("res://tests/knight_scenario_registry.gd"),
	preload("res://tests/archer_scenario_registry.gd"),
	preload("res://tests/lancer_scenario_registry.gd"),
]

const _LIVE_CLASS_TESTS: Array[String] = [
	"res://tests/live_bruiser_class_test.gd",
	"res://tests/live_archer_class_test.gd",
	"res://tests/live_lancer_class_test.gd",
	"res://tests/live_cleric_class_test.gd",
	"res://tests/live_mage_class_test.gd",
]


static func ability_requires_movement_timeline_qa(
	ability: AbilityData, actor: UnitState = null,
) -> bool:
	if ability == null:
		return false
	if ability.is_pre_move_planner() or ability.is_movement_kind():
		return true
	return AbilitySystem.ability_has_movement_effect(ability, actor)


static func action_movement_needs_pre_or_post_leg(ability: AbilityData) -> bool:
	if ability == null:
		return false
	if ability.is_pre_move_planner():
		return false
	return AbilitySystem.ability_has_movement_effect(ability)


static func default_premove_run_cell(actor_pos: Vector2i, toward: Vector2i) -> Vector2i:
	if actor_pos == toward:
		return actor_pos + Vector2i(1, 0)
	var delta: Vector2i = toward - actor_pos
	var step := Vector2i(
		0 if delta.x == 0 else int(signf(float(delta.x))),
		0 if delta.y == 0 else int(signf(float(delta.y))),
	)
	return actor_pos + step


static func resolve_premove_run_cell(
	ability: AbilityData,
	actor_pos: Vector2i,
	commit_cell: Vector2i,
	explicit: Vector2i = Vector2i(-999999, -999999),
) -> Vector2i:
	if explicit.x > -999000:
		return explicit
	if not action_movement_needs_pre_or_post_leg(ability):
		return Vector2i(-999999, -999999)
	return default_premove_run_cell(actor_pos, commit_cell)


static func commit_run_premove_headless(
	failures: Array[String],
	fix: Dictionary,
	ability: AbilityData,
	premove_cell: Vector2i,
	tag: String,
) -> void:
	if premove_cell.x <= -999000:
		return
	if not action_movement_needs_pre_or_post_leg(ability):
		return
	var director: CombatDirector = fix.director as CombatDirector
	var unit_id: int = director.selected_unit_id
	if has_pre_or_post_leg(director, unit_id):
		return
	var unit: UnitState = fix.board.get_unit_by_id(unit_id)
	var run_idx: int = -1
	if unit != null:
		for i: int in range(unit.active_abilities.size()):
			var ab: AbilityData = unit.active_abilities[i] as AbilityData
			if ab != null and ab.is_universal_run():
				run_idx = i
				break
	_PLANNING_CHECKLIST.assert_true(
		failures,
		"%s/planning/run_select" % tag,
		run_idx >= 0,
		"universal Run must be on unit for movement timeline QA",
	)
	if run_idx < 0:
		return
	director.select_unit(unit_id)
	director.select_ability(run_idx)
	var slots: Dictionary = _PLANNING_CHECKLIST.commit_production(fix, premove_cell)
	_PLANNING_CHECKLIST.assert_true(
		failures,
		"%s/planning/premove_run" % tag,
		not _PLANNING_CHECKLIST._slots_invalid(slots),
		"movement skill QA requires a pre-move Run leg at %s" % premove_cell,
	)
	_PLANNING_CHECKLIST.flush_planning(fix)
	assert_move_preview_origin(failures, tag, fix, unit_id, ability)


static func latest_stand_cell(director: CombatDirector, unit_id: int) -> Vector2i:
	if director == null or unit_id < 0:
		return Vector2i(-999999, -999999)
	var board: BoardState = director.board if director.board != null else director.base_board
	return CombatPlanningPreview.planning_latest_stand_cell(director, board, unit_id)


static func resolve_post_commit_hover_cell(
	director: CombatDirector,
	stand: Vector2i,
	preferred: Vector2i = Vector2i(-999999, -999999),
) -> Vector2i:
	if preferred.x > -999000 and preferred != stand:
		return preferred
	var board: BoardState = director.board if director.board != null else director.base_board
	if board == null:
		return stand
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	for off: Vector2i in offsets:
		var cell: Vector2i = stand + off
		if not board.is_in_bounds(cell):
			continue
		if board.get_unit_at(cell) != null:
			continue
		return cell
	return stand


static func ensure_move_preview_hover_mode(fix: Dictionary, unit_id: int) -> void:
	var director: CombatDirector = fix.director as CombatDirector
	if director == null or unit_id < 0:
		return
	var unit: UnitState = director.board.get_unit_by_id(unit_id) if director.board != null else null
	if unit == null:
		return
	var run_idx: int = -1
	for i: int in range(unit.active_abilities.size()):
		var ab: AbilityData = unit.active_abilities[i] as AbilityData
		if ab != null and ab.is_universal_run():
			run_idx = i
			break
	director.select_unit(unit_id)
	if run_idx >= 0:
		director.select_ability(run_idx)
	_PLANNING_CHECKLIST.flush_planning(fix)


## Production-path: after a movement/premove commit, hover for the next leg and prove preview starts at latest stand.
static func assert_move_preview_origin(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	unit_id: int,
	ability: AbilityData,
	hover_cell: Vector2i = Vector2i(-999999, -999999),
) -> void:
	if ability != null and not ability_requires_movement_timeline_qa(ability):
		return
	var director: CombatDirector = fix.director as CombatDirector
	var input: CombatPlanningInput = fix.input as CombatPlanningInput
	if director == null or input == null or unit_id < 0:
		_assert_fail(failures, "%s/preview_origin/fixture" % label, "director/input missing for preview origin QA")
		return
	var stand: Vector2i = latest_stand_cell(director, unit_id)
	if stand.x <= -900000:
		_assert_fail(
			failures,
			"%s/preview_origin/stand" % label,
			"missing latest stand for unit %d" % unit_id,
		)
		return
	ensure_move_preview_hover_mode(fix, unit_id)
	var board: BoardState = director.board if director.board != null else director.base_board
	var cells_to_try: Array[Vector2i] = _hover_cells_for_move_preview(
		director, board, stand, hover_cell,
	)
	var path: Array[Vector2i] = []
	var used_cell: Vector2i = stand
	for cell: Vector2i in cells_to_try:
		_PLANNING_CHECKLIST.hover(fix, cell)
		_PLANNING_CHECKLIST.flush_planning(fix)
		path = _PLANNING_CHECKLIST.preview_path(fix, unit_id)
		if not path.is_empty():
			used_cell = cell
			break
	if path.is_empty():
		_assert_fail(
			failures,
			"%s/path" % label,
			"move preview path missing after hover candidates %s (stand %s)"
			% [cells_to_try, stand],
		)
		return
	_PLANNING_CHECKLIST.assert_eq_cell(
		failures, "%s/path_start" % label, path[0], stand,
	)
	var active_timing: int = director.get_planning_move_timing(unit_id)
	var active_origin: Vector2i = CombatPlanningPreview.planning_move_origin_cell(
		director, board, unit_id,
	)
	_PLANNING_CHECKLIST.assert_eq_cell(
		failures, "%s/active_timing" % label, active_origin, stand,
	)
	var pre_origin: Vector2i = CombatPlanningPreview.planning_move_origin_cell_for_timing(
		director, board, unit_id, GameEnums.MoveTiming.PRE_ACTION,
	)
	var post_origin: Vector2i = CombatPlanningPreview.planning_move_origin_cell_for_timing(
		director, board, unit_id, GameEnums.MoveTiming.POST_ACTION,
	)
	if active_timing == GameEnums.MoveTiming.PRE_ACTION:
		_PLANNING_CHECKLIST.assert_eq_cell(
			failures, "%s/pre_slot" % label, pre_origin, stand,
		)
	elif active_timing == GameEnums.MoveTiming.POST_ACTION:
		_PLANNING_CHECKLIST.assert_eq_cell(
			failures, "%s/post_slot" % label, post_origin, stand,
		)
	var overlay: TacticalPlanningOverlay = fix.get("overlay", null) as TacticalPlanningOverlay
	if overlay != null:
		var committed_path: Array = overlay.get_committed_preview().preview_paths.get(unit_id, [])
		if not committed_path.is_empty() and committed_path[0] is Vector2i:
			_PLANNING_CHECKLIST.assert_eq_cell(
				failures,
				"%s/committed_path" % label,
				committed_path[0] as Vector2i,
				stand,
			)
	var input_path: Array = input.preview_state.preview_paths.get(unit_id, [])
	if not input_path.is_empty() and input_path[0] is Vector2i:
		_PLANNING_CHECKLIST.assert_eq_cell(
			failures,
			"%s/input_path" % label,
			input_path[0] as Vector2i,
			stand,
		)


static func _hover_cells_for_move_preview(
	director: CombatDirector,
	board: BoardState,
	stand: Vector2i,
	preferred: Vector2i,
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen: Dictionary = {}
	var push_cell := func(cell: Vector2i) -> void:
		if cell == stand or seen.has(cell):
			return
		if board != null:
			if not board.is_in_bounds(cell):
				return
			if board.get_unit_at(cell) != null:
				return
		seen[cell] = true
		out.append(cell)
	if preferred.x > -999000:
		push_cell.call(preferred)
	for off: Vector2i in [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]:
		push_cell.call(stand + off)
	return out


static func has_pre_or_post_leg(director: CombatDirector, unit_id: int) -> bool:
	if director == null or unit_id < 0:
		return false
	return (
		not _timeline_actions_for_unit(director.plan_pre_move, unit_id).is_empty()
		or not _timeline_actions_for_unit(director.plan_post_move, unit_id).is_empty()
	)


static func skill_timeline_qa_failures(
	label: String,
	director: CombatDirector,
	unit_id: int,
	ability: AbilityData,
	slots: Dictionary = {},
	actor: UnitState = null,
) -> Array[String]:
	var failures: Array[String] = []
	if not ability_requires_movement_timeline_qa(ability, actor):
		return failures
	_PLANNING_CHECKLIST.assert_skill_timeline_columns(
		failures, label, director, unit_id, ability, slots,
	)
	assert_pre_or_post_leg_if_needed(failures, label, director, unit_id, ability)
	return failures


static func assert_movement_skill_timeline(
	failures: Array[String],
	label: String,
	director: CombatDirector,
	unit_id: int,
	ability: AbilityData,
	slots: Dictionary = {},
	actor: UnitState = null,
) -> void:
	var local: Array[String] = skill_timeline_qa_failures(
		label, director, unit_id, ability, slots, actor,
	)
	for line: String in local:
		failures.append(line)


static func assert_pre_or_post_leg_if_needed(
	failures: Array[String],
	label: String,
	director: CombatDirector,
	unit_id: int,
	ability: AbilityData,
) -> void:
	if not action_movement_needs_pre_or_post_leg(ability):
		return
	_PLANNING_CHECKLIST.assert_true(
		failures,
		"%s/movement_pre_or_post_leg" % label,
		has_pre_or_post_leg(director, unit_id),
		"ACTION movement skill QA must commit a pre-move or post-move timeline action",
	)


static func audit_scenario_registries(failures: Array[String]) -> void:
	for registry: GDScript in _SCENARIO_REGISTRIES:
		if registry == null:
			continue
		for entry: Dictionary in registry.call("all_entries"):
			var factory_id: StringName = entry.get("factory_id", &"") as StringName
			var script_path: String = String(entry.get("script_path", ""))
			var ability: AbilityData = AoeFootprintQaHarness.find_ability_by_id(factory_id)
			if ability == null or not ability_requires_movement_timeline_qa(ability):
				continue
			if _live_class_covers_movement_skill(factory_id):
				continue
			if not _registry_runner_covers_planning(registry):
				if action_movement_needs_pre_or_post_leg(ability):
					if not _scenario_chain_has_timeline_leg_proof(script_path):
						_assert_fail(
							failures,
							"audit/movement/%s/timeline_leg" % factory_id,
							"movement skill scenario %s lacks PRE/POST-MOVE Run leg QA"
							% script_path,
						)
				if not _scenario_chain_has_preview_origin_proof(script_path):
					_assert_fail(
						failures,
						"audit/movement/%s/preview_origin" % factory_id,
						"movement skill scenario %s lacks move-preview-origin QA after commit"
						% script_path,
					)


static func audit_live_class_tests(failures: Array[String]) -> void:
	for path: String in _LIVE_CLASS_TESTS:
		if not ResourceLoader.exists(path):
			continue
		var source: String = FileAccess.get_file_as_string(path)
		var movement_ids: Array[StringName] = _movement_skill_ids_from_live_source(source)
		if movement_ids.is_empty():
			continue
		if not source.contains("live_movement_timeline_qa_mixin"):
			_assert_fail(
				failures,
				"audit/live_movement/%s/mixin" % path.get_file(),
				"live class test covers movement skills %s but lacks live_movement_timeline_qa_mixin"
				% movement_ids,
			)
			continue
		if not _source_has_preview_origin_proof(source):
			if not (source.contains("assert_committed(")):
				_assert_fail(
					failures,
					"audit/live_movement/%s/preview_origin" % path.get_file(),
					"live class test %s must call assert_move_preview_origin_live after movement commits"
					% path.get_file(),
				)


static func _movement_skill_ids_from_live_source(source: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var regex := RegEx.new()
	regex.compile("\"id\":\\s*&\"([^\"]+)\"")
	for result: RegExMatch in regex.search_all(source):
		var ability_id: StringName = StringName(result.get_string(1))
		var ability: AbilityData = AoeFootprintQaHarness.find_ability_by_id(ability_id)
		if ability != null and ability_requires_movement_timeline_qa(ability):
			out.append(ability_id)
	return out


static func _scenario_chain_has_timeline_leg_proof(
	script_path: String, visited: Dictionary = {},
) -> bool:
	return _scenario_chain_has_marker(script_path, _TIMELINE_LEG_MARKERS, visited)


static func _scenario_chain_has_preview_origin_proof(
	script_path: String, visited: Dictionary = {},
) -> bool:
	return _scenario_chain_has_marker(script_path, _PREVIEW_ORIGIN_MARKERS, visited)


static func _scenario_chain_has_marker(
	script_path: String,
	markers: Array[String],
	visited: Dictionary = {},
) -> bool:
	if visited.has(script_path):
		return false
	visited[script_path] = true
	if not ResourceLoader.exists(script_path):
		return false
	var source: String = FileAccess.get_file_as_string(script_path)
	if _source_has_marker(source, markers):
		return true
	var regex := RegEx.new()
	regex.compile("preload\\(\"(res://[^\"]+)\"\\)")
	for result: RegExMatch in regex.search_all(source):
		var dep: String = result.get_string(1)
		if _scenario_chain_has_marker(dep, markers, visited):
			return true
	return false


static func _source_has_timeline_leg_proof(source: String) -> bool:
	return _source_has_marker(source, _TIMELINE_LEG_MARKERS)


static func _source_has_preview_origin_proof(source: String) -> bool:
	return _source_has_marker(source, _PREVIEW_ORIGIN_MARKERS)


static func _source_has_marker(source: String, markers: Array[String]) -> bool:
	for marker: String in markers:
		if source.contains(marker):
			return true
	return false


static func _timeline_actions_for_unit(timeline: Timeline, unit_id: int) -> Array:
	var out: Array = []
	if timeline == null:
		return out
	for raw: Variant in timeline.entries:
		var action: TimelineAction = raw as TimelineAction
		if action != null and action.actor_id == unit_id:
			out.append(action)
	return out


static func _live_class_covers_movement_skill(factory_id: StringName) -> bool:
	for path: String in _LIVE_CLASS_TESTS:
		if not ResourceLoader.exists(path):
			continue
		var source: String = FileAccess.get_file_as_string(path)
		if not source.contains("live_movement_timeline_qa_mixin"):
			continue
		if source.contains(String(factory_id)):
			return true
	return false


static func _registry_runner_covers_planning(registry: GDScript) -> bool:
	return registry == preload("res://tests/bruiser_scenario_registry.gd")


static func _assert_fail(failures: Array[String], label: String, detail: String) -> void:
	failures.append("%s: %s" % [label, detail])
