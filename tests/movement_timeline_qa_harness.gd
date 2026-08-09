class_name MovementTimelineQaHarness
extends RefCounted

## Movement skills must prove PRE-MOVE or POST-MOVE timeline legs in QA (not action column only).

const _PLANNING_CHECKLIST := preload("res://tests/planning_checklist_harness.gd")

const _TIMELINE_PROOF_MARKERS: Array[String] = [
	"MovementTimelineQaHarness",
	"assert_skill_timeline_columns",
	"assert_movement_skill_timeline",
	"assert_planning_timeline_after_commit",
	"assert_commit_no_jump",
	"run_planning_commit_smoke",
	"run_planning_ally_smoke",
	"run_planning_awaiting_smoke",
	"PlanningSmokeRegistry.run_for_factory_id",
	"plan_pre_move",
	"plan_post_move",
	"assert_move_preview_origin",
	"_phase7_premove",
	"premove_then",
	"skill_timeline_column",
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
			if not _scenario_chain_has_timeline_proof(script_path):
				if _registry_runner_covers_planning(registry):
					continue
				_assert_fail(
					failures,
					"audit/movement/%s" % factory_id,
					"movement skill scenario %s lacks PRE/POST-MOVE timeline QA proof (%s)"
					% [script_path, _TIMELINE_PROOF_MARKERS],
				)


static func audit_live_class_tests(failures: Array[String]) -> void:
	for path: String in _LIVE_CLASS_TESTS:
		if not ResourceLoader.exists(path):
			continue
		var source: String = FileAccess.get_file_as_string(path)
		var movement_ids: Array[StringName] = _movement_skill_ids_from_live_source(source)
		if movement_ids.is_empty():
			continue
		if source.contains("live_movement_timeline_qa_mixin"):
			continue
		var has_harness: bool = false
		for marker: String in _TIMELINE_PROOF_MARKERS:
			if source.contains(marker):
				has_harness = true
				break
		if not has_harness:
			_assert_fail(
				failures,
				"audit/live_movement/%s" % path.get_file(),
				"live class test covers movement skills %s but lacks movement timeline mixin (%s)"
				% [movement_ids, _TIMELINE_PROOF_MARKERS],
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


static func _scenario_chain_has_timeline_proof(
	script_path: String, visited: Dictionary = {},
) -> bool:
	if visited.has(script_path):
		return false
	visited[script_path] = true
	if not ResourceLoader.exists(script_path):
		return false
	var source: String = FileAccess.get_file_as_string(script_path)
	if _source_has_timeline_proof(source):
		return true
	var regex := RegEx.new()
	regex.compile("preload\\(\"(res://[^\"]+)\"\\)")
	for result: RegExMatch in regex.search_all(source):
		var dep: String = result.get_string(1)
		if _scenario_chain_has_timeline_proof(dep, visited):
			return true
	return false


static func _source_has_timeline_proof(source: String) -> bool:
	for marker: String in _TIMELINE_PROOF_MARKERS:
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
