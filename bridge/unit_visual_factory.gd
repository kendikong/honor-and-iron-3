class_name UnitVisualFactory
extends RefCounted

## Creates deterministic LPC visuals for tactical units (Phase 5 implementation).

static func recipe_seed_for_unit(unit_id: int, team: int) -> int:
	return unit_id * 1009 + team * 9176


static func recipe_seed_for_unit_state(unit: UnitState) -> int:
	if unit == null:
		return 0
	if unit.definition != null:
		var class_key: int = hash(String(unit.definition.id))
		return class_key ^ (unit.id * 1009) ^ (int(unit.team) * 9176)
	return recipe_seed_for_unit(unit.id, int(unit.team))


static func roll_recipe(catalog: LpcCatalog, profile: CharacterGenProfile, unit_id: int, team: int) -> CharacterRecipe:
	return CharacterRoller.roll(catalog, profile, recipe_seed_for_unit(unit_id, team))


static func roll_recipe_for_unit(
	catalog: LpcCatalog,
	profile: CharacterGenProfile,
	unit: UnitState,
) -> CharacterRecipe:
	var class_id: String = ""
	if unit != null and unit.definition != null:
		class_id = str(unit.definition.id)
	return CharacterRoller.roll(
		catalog,
		profile,
		recipe_seed_for_unit_state(unit),
		class_id,
	)


static func display_scale_for_profile(profile: CharacterGenProfile) -> float:
	var multiplier: float = profile.display_scale if profile != null else 1.0
	return TacticalConstants.default_character_scale() * multiplier
