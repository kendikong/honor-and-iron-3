class_name UnitVisualFactory
extends RefCounted

## Creates deterministic LPC visuals for tactical units (Phase 5 implementation).

static func recipe_seed_for_unit(unit_id: int, team: int) -> int:
	return unit_id * 1009 + team * 9176


static func roll_recipe(catalog: LpcCatalog, profile: CharacterGenProfile, unit_id: int, team: int) -> CharacterRecipe:
	return CharacterRoller.roll(catalog, profile, recipe_seed_for_unit(unit_id, team))
