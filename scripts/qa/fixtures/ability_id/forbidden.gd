extends RefCounted

func forbidden_if(ability: AbilityData) -> bool:
	if ability.id == &"fixture_skill":
		return true
	elif action.ability.id == "fixture_action_skill":
		return true
	return ability.id == &"fixture_return_skill"


func forbidden_membership(ability: AbilityData) -> bool:
	return ability.id in [&"fixture_list_skill"]


func forbidden_match(ability: AbilityData) -> bool:
	match ability.id:
		&"fixture_match_skill":
			return true
	return false
