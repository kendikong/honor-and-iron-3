extends RefCounted

func variable_lookup(ability: AbilityData, expected_id: StringName) -> bool:
	return ability.id == expected_id


func shared_category_predicate(ability: AbilityData) -> bool:
	return DataLibrary.is_basic_ability(ability.id)


func serialization_and_factory_assignment(ability: AbilityData) -> Dictionary:
	return {"ability_id": ability.id, "ability": ability}
