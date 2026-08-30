class_name MovementModuleQaHarness
extends RefCounted

## Enforces modular movement QA: no post_attack_move layers; position proof on MOVE skills.

const _AoeHarness := preload("res://tests/aoe_footprint_qa_harness.gd")
const _MovementTimeline := preload("res://tests/movement_timeline_qa_harness.gd")

const _POSITION_PROOF_MARKERS: Array[String] = [
	".position",
	"assert_eq_cell",
	"events_actor_moved",
	"set_module_target",
	"before_position",
	"postmove_cell",
	"commit_run_postmove",
	"outcome/move",
	"_assert_move",
	"UNIT_MOVED",
	"ClassScenarioSimOutcome",
]

const _SCENARIO_REGISTRIES: Array[GDScript] = [
	preload("res://tests/bruiser_scenario_registry.gd"),
	preload("res://tests/knight_scenario_registry.gd"),
	preload("res://tests/archer_scenario_registry.gd"),
	preload("res://tests/lancer_scenario_registry.gd"),
	preload("res://tests/monk_scenario_registry.gd"),
	preload("res://tests/mercenary_scenario_registry.gd"),
	preload("res://tests/rogue_scenario_registry.gd"),
	preload("res://tests/mage_scenario_registry.gd"),
	preload("res://tests/cleric_scenario_registry.gd"),
	preload("res://tests/shaman_scenario_registry.gd"),
]

const _FACTORY_CLASS_IDS: Array[StringName] = [
	&"bruiser", &"knight", &"archer", &"lancer", &"cleric", &"mage",
	&"mercenary", &"monk", &"shaman", &"rogue",
]


static func audit_all(failures: Array[String]) -> void:
	audit_forbidden_post_attack_layers(failures)
	audit_movement_position_proof(failures)


static func audit_forbidden_post_attack_layers(failures: Array[String]) -> void:
	for class_id: StringName in _FACTORY_CLASS_IDS:
		var path := "res://core/factory/classes/%s_factory.gd" % class_id
		if not FileAccess.file_exists(path):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		if text.contains("post_attack_move"):
			failures.append(
				"factory/%s: forbidden post_attack_move layer — use a separate MOVE module with NEW_AIM"
				% class_id,
			)


static func ability_requires_position_proof(ability: AbilityData) -> bool:
	if ability == null:
		return false
	if _MovementTimeline.ability_requires_movement_timeline_qa(ability):
		return true
	if ability_requires_modular_aim_proof(ability):
		return true
	return false


static func ability_requires_modular_aim_proof(ability: AbilityData) -> bool:
	if ability == null:
		return false
	var modules: Array[AbilityModule] = AbilitySystem.active_modules_for(null, ability)
	if modules.size() < 2:
		return false
	return not AbilitySystem.planning_new_aim_indices(null, ability).is_empty()


static func audit_movement_position_proof(failures: Array[String]) -> void:
	for registry: GDScript in _SCENARIO_REGISTRIES:
		if registry == null:
			continue
		for entry: Dictionary in registry.call("all_entries"):
			var factory_id: StringName = entry.get("factory_id", &"") as StringName
			var script_path: String = String(entry.get("script_path", ""))
			var ability: AbilityData = _AoeHarness.find_ability_by_id(factory_id)
			if ability == null or not ability_requires_position_proof(ability):
				continue
			if not _scenario_chain_has_position_proof(script_path):
				failures.append(
					"audit/movement/%s/position: scenario %s lacks actor position / module-target proof"
					% [factory_id, script_path],
				)


static func _scenario_chain_has_position_proof(
	script_path: String,
	visited: Dictionary = {},
) -> bool:
	if script_path.is_empty() or visited.has(script_path):
		return false
	visited[script_path] = true
	if not ResourceLoader.exists(script_path):
		return false
	var text: String = FileAccess.get_file_as_string(script_path)
	for marker: String in _POSITION_PROOF_MARKERS:
		if text.contains(marker):
			return true
	var preload_map := _preload_map(text)
	for alias: String in preload_map:
		var dep_path: String = preload_map[alias]
		if dep_path.ends_with("_qa_harness.gd") or dep_path.ends_with("_harness_scenarios.gd"):
			if _harness_has_position_proof_for_script(dep_path, text):
				return true
		if _scenario_chain_has_position_proof(dep_path, visited):
			return true
	return false


static func _harness_has_position_proof_for_script(
	harness_path: String,
	scenario_text: String,
) -> bool:
	if not FileAccess.file_exists(harness_path):
		return false
	var harness_text: String = FileAccess.get_file_as_string(harness_path)
	for call: RegExMatch in RegEx.create_from_string(
		"run_([A-Za-z0-9_]+)\\s*\\(",
	).search_all(scenario_text):
		var fn: String = "run_%s" % call.get_string(1)
		if not harness_text.contains("func %s" % fn):
			continue
		var body := _function_body(harness_text, fn)
		for marker: String in _POSITION_PROOF_MARKERS:
			if body.contains(marker):
				return true
	return false


static func _function_body(source: String, func_name: String) -> String:
	var pattern := "func %s" % func_name
	var start := source.find(pattern)
	if start < 0:
		return ""
	var slice := source.substr(start)
	var end := slice.find("\nfunc ")
	if end < 0:
		return slice
	return slice.substr(0, end)


static func _preload_map(scenario_text: String) -> Dictionary:
	var out: Dictionary = {}
	var regex := RegEx.new()
	regex.compile("const\\s+(\\w+)\\s*:=\\s*preload\\(\"([^\"]+)\"\\)")
	for result: RegExMatch in regex.search_all(scenario_text):
		out[result.get_string(1)] = result.get_string(2)
	return out


static func build_modular_action(
	actor_id: int,
	ability: AbilityData,
	module_targets: Array,
	default_coord: Vector2i,
	default_unit_id: int = -1,
) -> TimelineAction:
	var action := TimelineAction.make_ability(actor_id, ability, default_coord, default_unit_id)
	for i: int in range(module_targets.size()):
		var entry: Variant = module_targets[i]
		var coord: Vector2i = default_coord
		var unit_id: int = default_unit_id
		if entry is Vector2i:
			coord = entry
			unit_id = -1
		elif entry is Dictionary:
			coord = entry.get("coord", default_coord)
			unit_id = int(entry.get("unit_id", -1))
		AbilitySystem.set_module_target(action, i, coord, unit_id)
	action.awaiting_target = false
	action.awaiting_module_index = -1
	return action
