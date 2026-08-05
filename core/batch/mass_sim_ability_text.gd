class_name MassSimAbilityText
extends RefCounted


static func tooltip_for_ability_id(ability_id: String) -> String:
	if ability_id.is_empty():
		return ""
	var ab: AbilityData = _find_ability(StringName(ability_id))
	if ab == null:
		return ability_id.replace("_", " ").capitalize()
	var lines: PackedStringArray = PackedStringArray()
	lines.append(
		"%s â€” Range %d, AP %d, MOV %d"
		% [ab.display_name, ab.range_tiles, ab.action_point_cost, ab.movement_point_cost],
	)
	for eff: AbilityModule in ab.modules:
		var line: String = _effect_summary(eff)
		if not line.is_empty():
			lines.append(line)
	if not ab.upgrade_description.is_empty():
		lines.append("[+] %s" % ab.upgrade_description)
	return "\n".join(lines)


static func tooltip_for_passive_id(passive_id: String) -> String:
	if passive_id.is_empty():
		return ""
	var passive: PassiveData = _find_passive(StringName(passive_id))
	if passive == null:
		return passive_id.replace("_", " ").capitalize()
	if passive.description.is_empty():
		return passive.display_name
	return "%s\n%s" % [passive.display_name, passive.description]


static func _find_ability(ability_id: StringName) -> AbilityData:
	if DataLibrary.is_universal_run(ability_id):
		return DataLibrary.get_universal_run()
	if DataLibrary.is_universal_wait(ability_id):
		return DataLibrary.get_universal_wait()
	for unit: UnitData in DataLibrary.get_all_player_units():
		for ab: AbilityData in unit.abilities:
			if ab.id == ability_id:
				return ab
	for unit: UnitData in DataLibrary.get_all_enemy_units():
		for ab: AbilityData in unit.abilities:
			if ab.id == ability_id:
				return ab
	return null


static func _find_passive(passive_id: StringName) -> PassiveData:
	for unit: UnitData in DataLibrary.get_all_player_units():
		for passive: PassiveData in unit.passives:
			if passive.id == passive_id:
				return passive
	for unit: UnitData in DataLibrary.get_all_enemy_units():
		for passive: PassiveData in unit.passives:
			if passive.id == passive_id:
				return passive
	return null


static func _effect_summary(eff: AbilityModule) -> String:
	var amount: String = str(eff.amount) if eff.amount != 0 else ""
	match eff.primary_type:
		GameEnums.EffectType.DAMAGE:
			return "Damage %s" % amount
		GameEnums.EffectType.HEAL:
			return "Heal %s" % amount
		GameEnums.EffectType.PUSH:
			return "Push %s" % amount
		GameEnums.EffectType.PULL:
			return "Pull %s" % amount
		GameEnums.EffectType.ARMOR_UP:
			return "Shield %s" % amount
		GameEnums.EffectType.SWAP:
			return "Swap positions"
		GameEnums.EffectType.EXPLODE, GameEnums.EffectType.RANGED_EXPLODE:
			return "Explode %s" % amount
		GameEnums.EffectType.SPAWN:
			return "Spawn unit"
		GameEnums.EffectType.MOVE_INTO_AND_PUSH:
			return "Move through and push"
		GameEnums.EffectType.ADD_STATUS, GameEnums.EffectType.ADD_STATUS_SELF:
			return "Apply %s" % GameEnums.StatusType.keys()[eff.status_type]
		_:
			return ""
