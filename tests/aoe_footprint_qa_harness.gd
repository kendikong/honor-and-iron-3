class_name AoeFootprintQaHarness
extends RefCounted

## Shared AOE / shaped-skill QA — sim footprint, overlay parity, geometry contracts.
## Tier-1 scenarios and Tier-2 live class tests must use this instead of metadata-only asserts.

const _FOOTPRINT_MARKERS: Array[String] = [
	"AoeFootprintQaHarness",
	"assert_grid_footprint",
	"assert_footprint_excludes",
	"assert_sim_footprint",
	"get_affected_tiles",
]

const _LIVE_OVERLAY_MARKERS: Array[String] = [
	"AoeFootprintQaHarness",
	"assert_live_overlay_parity",
	"assert_overlay_exact",
	"assert_arc_overlay",
	"assert_self_aoe_overlay",
]

const _SCENARIO_REGISTRIES: Array[GDScript] = [
	preload("res://tests/bruiser_scenario_registry.gd"),
	preload("res://tests/knight_scenario_registry.gd"),
	preload("res://tests/archer_scenario_registry.gd"),
	preload("res://tests/lancer_scenario_registry.gd"),
	preload("res://tests/monk_scenario_registry.gd"),
]

const _LIVE_CLASS_TESTS: Array[String] = [
	"res://tests/live_bruiser_class_test.gd",
	"res://tests/live_archer_class_test.gd",
	"res://tests/live_lancer_class_test.gd",
	"res://tests/live_cleric_class_test.gd",
	"res://tests/live_mage_class_test.gd",
]


static func ability_requires_footprint_qa(ability: AbilityData) -> bool:
	if ability == null:
		return false
	if ability.target_shape != GameEnums.TargetShape.SINGLE:
		return true
	if ability.upgraded_target_shape != GameEnums.TargetShape.SINGLE:
		return true
	return false


static func find_ability_by_id(ability_id: StringName) -> AbilityData:
	if DataLibrary.is_universal_run(ability_id):
		return DataLibrary.get_universal_run()
	if DataLibrary.is_universal_wait(ability_id):
		return DataLibrary.get_universal_wait()
	for class_id: StringName in [
		&"bruiser", &"knight", &"archer", &"lancer", &"cleric", &"mage", &"mercenary", &"monk",
	]:
		var unit: UnitData = _build_class_unit(class_id)
		if unit == null:
			continue
		for ab: AbilityData in unit.abilities:
			if ab != null and ab.id == ability_id:
				return ab
	return null


static func expected_blast_tiles(
	board: BoardState,
	unit: UnitState,
	ability: AbilityData,
	origin: Vector2i,
	target: Vector2i,
) -> Array[Vector2i]:
	return AbilitySystem.planning_blast_tiles_at_target(board, unit, ability, origin, target)


static func expected_self_aoe_tiles(
	board: BoardState,
	unit: UnitState,
	ability: AbilityData,
	origin: Vector2i,
) -> Array[Vector2i]:
	return AbilitySystem.planning_action_range_tiles(board, unit, ability, origin, [])


static func assert_footprint_excludes(
	failures: Array[String],
	tag: String,
	board: BoardState,
	origin: Vector2i,
	target: Vector2i,
	shape: GameEnums.TargetShape,
	size: int,
	outside: Vector2i,
) -> void:
	var tiles: Array[Vector2i] = GridSystem.get_affected_tiles(board, origin, target, shape, size)
	_assert_true(
		failures, "%s/inside" % tag,
		tiles.has(target),
		"GridSystem footprint must include target cell %s" % target,
	)
	_assert_true(
		failures, "%s/outside" % tag,
		not tiles.has(outside),
		"GridSystem footprint must exclude outside cell %s (got %s)" % [outside, tiles],
	)
	_assert_true(
		failures, "%s/count" % tag,
		tiles.size() >= 1,
		"GridSystem footprint must not be empty",
	)


static func overlay_parity_error(
	overlay: Variant,
	expected: Array[Vector2i],
	label: String,
) -> String:
	if overlay == null or not overlay.has_method("get_hover_action_range_tiles"):
		return "%s: missing planning overlay with get_hover_action_range_tiles()" % label
	var overlay_tiles: Array[Vector2i] = overlay.get_hover_action_range_tiles()
	for tile: Vector2i in expected:
		if not overlay.is_hover_action_range_tile(tile):
			return "%s: overlay missing blast tile %s (expected %s)" % [label, tile, expected]
	for tile: Vector2i in overlay_tiles:
		if not expected.has(tile):
			return "%s: overlay red tile %s outside blast footprint %s" % [label, tile, expected]
	if overlay_tiles.size() != expected.size():
		return "%s: overlay must be exactly %d red tiles, got %d (%s)" % [
			label, expected.size(), overlay_tiles.size(), overlay_tiles,
		]
	return ""


static func run_geometry_contracts(failures: Array[String]) -> void:
	var center := Vector2i(4, 4)
	var horizontal_arc := GridSystem.get_affected_tiles(
		null, center, center + Vector2i(2, 0), GameEnums.TargetShape.ARC, 1,
	)
	_assert_eq_int(failures, "geometry/arc_size", horizontal_arc.size(), 3)
	_assert_true(
		failures, "geometry/arc_footprint",
		horizontal_arc.has(center + Vector2i(2, 0))
		and horizontal_arc.has(center + Vector2i(2, -1))
		and horizontal_arc.has(center + Vector2i(2, 1)),
		"ARC size 1 must be target + 2 perpendicular neighbors",
	)
	var square := GridSystem.get_affected_tiles(
		null, center, center, GameEnums.TargetShape.AOE_SQUARE, 1,
	)
	_assert_eq_int(failures, "geometry/aoe_square_1", square.size(), 9)
	var cross := GridSystem.get_affected_tiles(
		null, center, center, GameEnums.TargetShape.AOE_CROSS, 1,
	)
	_assert_eq_int(failures, "geometry/aoe_cross_1", cross.size(), 5)


static func audit_scenario_registries(failures: Array[String]) -> void:
	for registry_script: GDScript in _SCENARIO_REGISTRIES:
		var entries: Array = registry_script.call("all_entries") as Array
		for entry: Variant in entries:
			if entry is not Dictionary:
				continue
			var factory_id: StringName = entry.get("factory_id", &"") as StringName
			var script_path: String = String(entry.get("script_path", ""))
			if script_path.is_empty():
				continue
			var ability: AbilityData = find_ability_by_id(factory_id)
			if ability == null or not ability_requires_footprint_qa(ability):
				continue
			if not ResourceLoader.exists(script_path):
				continue
			if not _scenario_chain_has_footprint_proof(script_path):
				_assert_fail(
					failures,
					"audit/scenario/%s" % factory_id,
					"shaped ability %s must prove sim footprint (AoeFootprintQaHarness / get_affected_tiles + in/out) in scenario chain %s"
					% [factory_id, script_path],
				)


static func audit_live_class_tests(failures: Array[String]) -> void:
	for path: String in _LIVE_CLASS_TESTS:
		if not ResourceLoader.exists(path):
			continue
		var source: String = FileAccess.get_file_as_string(path)
		var shaped_ids: Array[StringName] = _shaped_skill_ids_from_live_source(source)
		if shaped_ids.is_empty():
			continue
		var has_harness: bool = false
		for marker: String in _LIVE_OVERLAY_MARKERS:
			if source.contains(marker):
				has_harness = true
				break
		if not has_harness:
			_assert_fail(
				failures,
				"audit/live/%s" % path.get_file(),
				"live class test covers shaped skills %s but lacks overlay footprint asserts (%s)"
				% [shaped_ids, _LIVE_OVERLAY_MARKERS],
			)


static func audit_premove_arc_regression(failures: Array[String]) -> void:
	const BRUISER_LIVE := "res://tests/live_bruiser_class_test.gd"
	if not ResourceLoader.exists(BRUISER_LIVE):
		_assert_fail(failures, "audit/premove", "missing live Bruiser test for premove ARC regression")
		return
	var source: String = FileAccess.get_file_as_string(BRUISER_LIVE)
	if not source.contains("_run_cleave_premove_overlay_scenario"):
		_assert_fail(
			failures,
			"audit/premove",
			"live Bruiser must include _run_cleave_premove_overlay_scenario (range+blast stack guard)",
		)


static func _build_class_unit(class_id: StringName) -> UnitData:
	var template: UnitData = DataLibrary.get_unit(class_id)
	if template == null:
		return null
	var weapon: WeaponData = template.equipped_weapon
	match class_id:
		&"bruiser":
			return BruiserFactory.build(weapon)
		&"knight":
			return KnightFactory.build(weapon)
		&"archer":
			return ArcherFactory.build(weapon)
		&"lancer":
			return LancerFactory.build(weapon)
		&"cleric":
			return ClericFactory.build(weapon)
		&"mage":
			return MageFactory.build(weapon)
		&"mercenary":
			return MercenaryFactory.build(weapon)
		&"monk":
			return MonkFactory.build(weapon)
		_:
			return template


static func _scenario_chain_has_footprint_proof(script_path: String, visited: Dictionary = {}) -> bool:
	if visited.has(script_path):
		return false
	visited[script_path] = true
	if not ResourceLoader.exists(script_path):
		return false
	var source: String = FileAccess.get_file_as_string(script_path)
	if _source_has_footprint_proof(source):
		return true
	var regex := RegEx.new()
	regex.compile("preload\\(\"(res://[^\"]+)\"\\)")
	for result: RegExMatch in regex.search_all(source):
		var dep: String = result.get_string(1)
		if _scenario_chain_has_footprint_proof(dep, visited):
			return true
	return false


static func _source_has_footprint_proof(source: String) -> bool:
	if source.contains("AoeFootprintQaHarness"):
		return true
	if source.contains("assert_grid_footprint") or source.contains("assert_footprint_excludes"):
		return true
	if source.contains("get_affected_tiles"):
		if (
			source.contains("outside")
			or source.contains("arc_outside")
			or source.contains("footprint")
			or source.contains("/inside")
		):
			return true
	return false


static func _shaped_skill_ids_from_live_source(source: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var regex := RegEx.new()
	regex.compile("\"id\":\\s*&\"([^\"]+)\"")
	for result: RegExMatch in regex.search_all(source):
		var ability_id: StringName = StringName(result.get_string(1))
		var ability: AbilityData = find_ability_by_id(ability_id)
		if ability != null and ability_requires_footprint_qa(ability):
			out.append(ability_id)
	return out


static func _assert_fail(failures: Array[String], tag: String, message: String) -> void:
	failures.append("%s: %s" % [tag, message])


static func _assert_true(
	failures: Array[String],
	tag: String,
	condition: bool,
	message: String = "",
) -> void:
	if not condition:
		_assert_fail(failures, tag, message if not message.is_empty() else "assertion failed")


static func _assert_eq_int(failures: Array[String], tag: String, got: int, expected: int) -> void:
	if got != expected:
		_assert_fail(failures, tag, "expected %d got %d" % [expected, got])
