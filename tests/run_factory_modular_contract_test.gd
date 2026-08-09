extends Node

## Cross-factory authoring contract for the AbilityData modular cutover.

const CLASS_IDS: Array[StringName] = [
	&"knight",
	&"bruiser",
	&"archer",
	&"lancer",
	&"mage",
	&"cleric",
]

const FACTORY_PATHS: Array[String] = [
	"res://core/factory/classes/knight_factory.gd",
	"res://core/factory/classes/bruiser_factory.gd",
	"res://core/factory/classes/archer_factory.gd",
	"res://core/factory/classes/lancer_factory.gd",
	"res://core/factory/classes/mage_factory.gd",
	"res://core/factory/classes/cleric_factory.gd",
]

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	DataLibrary.reset_cache()
	_check_factory_sources(failures)
	for class_id: StringName in CLASS_IDS:
		_check_unit(class_id, failures)
	if failures.is_empty():
		print("FACTORY_MODULAR_CONTRACT_TEST: PASS")
		get_tree().quit(0)
		return
	print("FACTORY_MODULAR_CONTRACT_TEST: FAIL")
	for failure: String in failures:
		printerr("  [FAIL] %s" % failure)
	get_tree().quit(1)


func _check_unit(class_id: StringName, failures: Array[String]) -> void:
	var unit: UnitData = _build_factory(class_id)
	if unit == null:
		failures.append("%s missing from DataLibrary" % String(class_id))
		return
	for ability: AbilityData in unit.abilities:
		if ability == null:
			continue
		var label := "%s/%s" % [String(class_id), String(ability.id)]
		if ability.modules.is_empty():
			failures.append("%s has no authored modules" % label)
		if not ability.upgrade_description.is_empty() and ability.upgraded_modules.is_empty():
			failures.append("%s describes an upgrade without upgraded_modules" % label)
		_check_header(ability, label, failures)
		_check_module_ranges(ability.modules, label, failures)
		_check_module_ranges(ability.upgraded_modules, "%s/upgrade" % label, failures)


func _check_header(ability: AbilityData, label: String, failures: Array[String]) -> void:
	if ability.planner_group == GameEnums.PlannerGroup.PRE_MOVE:
		if ability.primary_resource != GameEnums.CostResource.MP:
			failures.append("%s PRE_MOVE primary resource is not MP" % label)
		if ability.action_point_cost != 0 or ability.consumes_action_slot():
			failures.append("%s PRE_MOVE consumes an action slot/AP" % label)
		if not ability.has_tag(AbilityModuleBridge.TAG_POSITIONING):
			failures.append("%s PRE_MOVE is missing positioning tag" % label)
	elif ability.kind == GameEnums.AbilityKind.CLASS_SKILL:
		if ability.primary_resource != GameEnums.CostResource.AP:
			failures.append("%s ACTION primary resource is not AP" % label)
	if ability.id == &"knight_trampling_advance" and ability.movement_point_cost != 0:
		failures.append("%s must be AP-only with zero movement cost" % label)
	if ability.id in [&"bruiser_adrenaline_surge", &"bruiser_blood_boil"]:
		if ability.secondary_resource != GameEnums.CostResource.HP:
			failures.append("%s HP spend is not in the header" % label)
		for module: AbilityModule in ability.modules:
			for effect: EffectData in AbilityModuleBridge.compile_module_to_effects(module):
				if effect.type == GameEnums.EffectType.DAMAGE_SELF:
					failures.append("%s still authors HP spend as DAMAGE_SELF" % label)


func _check_module_ranges(
	modules: Array[AbilityModule],
	label: String,
	failures: Array[String],
) -> void:
	for index: int in range(modules.size()):
		var module: AbilityModule = modules[index]
		if module == null:
			failures.append("%s module[%d] is null" % [label, index])
			continue
		if module.primary_type in [
			GameEnums.EffectType.MOVE,
			GameEnums.EffectType.DASH,
			GameEnums.EffectType.MOVE_INTO_AND_PUSH,
			GameEnums.EffectType.TELEPORT_CASTER,
		]:
			if module.min_range < 1 or module.max_range < module.min_range:
				failures.append("%s module[%d] has invalid motion range" % [label, index])


func _build_factory(class_id: StringName) -> UnitData:
	var weapon := WeaponData.new()
	weapon.id = &"contract_weapon"
	weapon.display_name = "Contract Weapon"
	weapon.might = 4
	match class_id:
		&"knight":
			return KnightFactory.build(weapon)
		&"bruiser":
			return BruiserFactory.build(weapon)
		&"archer":
			return ArcherFactory.build(weapon)
		&"lancer":
			return LancerFactory.build(weapon)
		&"mage":
			return MageFactory.build(weapon)
		&"cleric":
			return ClericFactory.build(weapon)
	return null


func _check_factory_sources(failures: Array[String]) -> void:
	for path: String in FACTORY_PATHS:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			failures.append("cannot read factory source %s" % path)
			continue
		var source := file.get_as_text()
		for forbidden: String in [
			"upgraded_effects =",
			"upgraded_range_tiles =",
			"upgraded_target_shape =",
			"upgraded_target_shape_size =",
			"upgraded_movement_point_cost =",
		]:
			if source.find(forbidden) >= 0:
				failures.append("%s still authors %s" % [path, forbidden.trim_suffix(" =")])
