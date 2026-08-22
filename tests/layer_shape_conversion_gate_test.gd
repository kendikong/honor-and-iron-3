class_name LayerShapeConversionGateTest
extends RefCounted

const _ShapeRules := preload("res://data/definitions/layer_shape_conversion_rules.gd")

## Shape bar for ER-2 refactor — Swap-shaped authoring, not Effect Knob dumps.
## Headless CLI: godot --headless --path . --script res://tests/run_layer_shape_conversion_gate.gd


static func run_all(failures: Array[String], mode: int = -1) -> void:
	var enforce_mode: LayerShapeConversionRules.EnforceMode = (
		mode as LayerShapeConversionRules.EnforceMode
		if mode >= 0
		else LayerShapeConversionRules.EnforceMode.LAYER_MANDATE
	)
	DataLibrary.reset_cache()
	_assert_gold_standards(failures)
	failures.append_array(LayerShapeConversionRules.audit_converted_skills(enforce_mode))


static func run_audit_only(failures: Array[String]) -> void:
	DataLibrary.reset_cache()
	LayerShapeConversionRules.print_audit_report()
	## Audit mode: report shape debt but do not fail the runner (migration in progress).
	var _shape_debt: Array[String] = LayerShapeConversionRules.audit_converted_skills(
		LayerShapeConversionRules.EnforceMode.LAYER_MANDATE
	)
	for line: String in _shape_debt:
		print("[DEBT] %s" % line)


static func _assert_gold_standards(failures: Array[String]) -> void:
	for skill_id: StringName in LayerShapeConversionRules.GOLD_STANDARD_SKILL_IDS:
		var ability: AbilityData = LayerShapeConversionRules.find_factory_ability(skill_id)
		if ability == null:
			failures.append("gold_standard missing ability %s" % String(skill_id))
			continue
		failures.append_array(LayerShapeConversionRules.audit_ability_shape(ability))
