class_name ClericFactory
extends RefCounted

## Builds the revised Bible's complete Cleric promotion pool.
## Cleric mechanics are authored as data and interpreted by shared systems.


static func build(basic_staff: WeaponData) -> UnitData:
	var def := UnitData.new()
	def.id = &"cleric"
	def.display_name = "Cleric"
	def.base_constitution = 4
	def.move_points = 4
	def.action_points = 1
	def.base_strength = 1
	def.base_defense = 1
	def.base_magic = 4
	def.preferred_stat = GameEnums.StatType.MAGICAL
	def.equipped_weapon = basic_staff
	def.promotion_stat_bonuses = {
		&"paladin": {"constitution": 2, "defense": 2, "movement": 3},
		&"seraph": {"magic": 6, "movement": 2},
		&"zealot": {"magic": 4, "strength": 4, "movement": 0},
	}

	def.innate_passives.append(_passive(
		&"selfless_siphon",
		"Selfless Siphon",
		"Whenever you apply HEAL or MAG HEAL to an ally, restore 25% of total healing to self.",
		"Self-healing increases to 50%; overheal becomes SHIELD.",
		{"selfless_siphon": true, "self_heal_pct": 0.25,
		"upgraded_self_heal_pct": 0.5, "self_heal_overheal_shield": true},
	))

	var guardian_module := DataLibrary._module(
		GameEnums.EffectType.TELEPORT_CASTER, 0, 1, 5, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.ADJACENT_TO_TARGET,
	)
	guardian_module.legacy_modifiers["cost_all_movement"] = true
	guardian_module.legacy_modifiers["warp_adjacent_to_target"] = true
	var guardian_upgraded := DataLibrary._duplicate_modules([guardian_module])
	guardian_upgraded[0].max_range = 999
	guardian_upgraded[0].legacy_modifiers["cleanse_target"] = true
	var guardian_step := DataLibrary._make_modular_ability(
		&"cleric_guardian_step", "Guardian Step", [guardian_module],
		guardian_upgraded, 0, GameEnums.PlannerGroup.PRE_MOVE,
		GameEnums.CostResource.MP, [AbilityModuleBridge.TAG_POSITIONING],
		"GLOBAL range; cleanse the target ally.", GameEnums.TargetingFlags.ALLY,
	)
	def.abilities.append(guardian_step)

	# Paladin passives.
	def.passives.append(_passive(&"blood_donation", "Blood Donation",
		"Overheal grants SHIELD and drains the same HP from self.",
		"Excess SHIELD grants +1 STR.", {"overheal_shield": true, "overheal_self_cost": true,
		"upgraded_overheal_str": 1, "promotion": &"paladin"}))
	def.passives.append(_passive(&"sacred_shield", "Sacred Shield",
		"Allies at full health gain +2 DEF and debuff immunity.",
		"Also gain +1 MAG.", {"full_health_def": 2, "full_health_debuff_immunity": true,
		"upgraded_full_health_mag": 1, "promotion": &"paladin"}))
	def.passives.append(_passive(&"divine_blessing", "Divine Blessing",
		"Healing an ally grants +1 STR for 1 turn, or +2 STR if they are at Max HP.",
		"Grant +2 STR for 2 turns.", {"heal_ally_str": 1, "heal_full_str": 2,
		"upgraded_heal_ally_str": 2, "upgraded_heal_ally_duration": 2,
		"promotion": &"paladin"}))
	def.passives.append(_passive(&"frontline_medic", "Frontline Medic",
		"Healing skills restore +1 HP if adjacent to an enemy.",
		"Restore +2 HP instead.", {"adjacent_enemy_heal": 1,
		"upgraded_adjacent_enemy_heal": 2, "promotion": &"paladin"}))
	def.passives.append(_passive(&"armor_of_faith", "Armor of Faith",
		"Healing an ally grants both units +1 DEF for 1 turn.",
		"Both gain +2 DEF.", {"heal_def": 1, "upgraded_heal_def": 2,
		"promotion": &"paladin"}))

	# Seraph passives.
	def.passives.append(_passive(&"divine_overflow", "Divine Overflow",
		"HEAL on an ally at Max HP triggers MAG ATK 1 to adjacent enemies.",
		"Pulse MAG ATK increases to 2.", {"full_health_heal_pulse": 1,
		"upgraded_full_health_heal_pulse": 2, "promotion": &"seraph"}))
	def.passives.append(_passive(&"divine_intervention", "Divine Intervention",
		"Once per combat, an ally taking lethal damage survives at 1 HP and teleports to you.",
		"That ally also gains SHIELD 2.", {"lethal_ally_save": true,
		"upgraded_lethal_ally_shield": 2, "promotion": &"seraph"}))
	def.passives.append(_passive(&"holy_ground", "Holy Ground",
		"Every turn, HEAL 1 adjacent allies and PURGE adjacent enemies.",
		"Also apply BLIND to enemies.", {"holy_ground_tick": true,
		"upgraded_holy_ground_blind": true, "promotion": &"seraph"}))
	def.passives.append(_passive(&"prayer", "Prayer",
		"Not attacking this turn doubles your next heal.",
		"Your next heal also grants CLEANSE.", {"prayer_next_heal_multiplier": 2,
		"upgraded_prayer_cleanse": true, "promotion": &"seraph"}))
	def.passives.append(_passive(&"purity", "Purity",
		"Being afflicted by POISON or BLEED instead triggers HEAL 2 and +1 MAG.",
		"Also CLEANSE.", {"dot_heal": 2, "dot_mag": 1, "upgraded_dot_cleanse": true,
		"promotion": &"seraph"}))

	# Zealot passives.
	def.passives.append(_passive(&"martyrs_blood", "Martyr's Blood",
		"When hit, deal MAG ATK 1 to adjacent enemies.",
		"Pulse MAG ATK increases to 2.", {"hit_adjacent_pulse": 1,
		"upgraded_hit_adjacent_pulse": 2, "promotion": &"zealot"}))
	def.passives.append(_passive(&"divine_retribution", "Divine Retribution",
		"An enemy damaging an ally in RANGE 3 suffers MAG ATK 1.",
		"Damage increases to 2.", {"ally_hit_retribution_range": 3,
		"ally_hit_retribution_damage": 1, "upgraded_ally_hit_retribution_damage": 2,
		"promotion": &"zealot"}))
	def.passives.append(_passive(&"holy_radiance", "Holy Radiance",
		"Allies in RANGE 2 gain +1 MAG and +1 STR.",
		"Also gain +1 DEF.", {"aura_range": 2, "aura_mag": 1, "aura_str": 1,
		"upgraded_aura_def": 1, "promotion": &"zealot"}))
	def.passives.append(_passive(&"retribution", "Retribution",
		"Melee attackers suffer MAG ATK 1 and PUSH 1.",
		"PUSH 2 instead.", {"melee_attacker_pulse": 1,
		"melee_attacker_push": 1, "upgraded_melee_attacker_push": 2,
		"promotion": &"zealot"}))
	def.passives.append(_passive(&"zealous_protection", "Zealous Protection",
		"Allies damaged by an enemy gain +1 STR for 1 turn.",
		"Also gain +1 DEF.", {"ally_damaged_str": 1, "upgraded_ally_damaged_def": 1,
		"promotion": &"zealot"}))

	def.abilities.append(_holy_light())
	def.abilities.append(_smite())
	def.abilities.append(_cleansing_aura())
	def.abilities.append(_sanctuary())
	def.abilities.append(_blinding_ray())
	def.abilities.append(_divine_hammer())
	def.abilities.append(_life_link())
	def.abilities.append(_prayer_of_fortitude())
	def.abilities.append(_resurrection())
	def.abilities.append(_consecrate_ground())
	def.abilities.append(_holy_wrath())
	def.abilities.append(_divine_guidance())
	def.abilities.append(_shield_of_faith())
	def.abilities.append(_martyrs_chains())

	DataLibrary.finalize_unit_abilities(def)
	return def


static func _passive(
	id: StringName,
	name: String,
	description: String,
	upgrade_description: String,
	modifiers: Dictionary,
) -> PassiveData:
	return DataLibrary._make_passive(id, name, description, upgrade_description, modifiers)


static func _layer(
	effect: EffectData,
	condition: GameEnums.LayerCondition = GameEnums.LayerCondition.AT_RESOLUTION,
) -> AbilityLayer:
	var layer := AbilityLayer.new()
	layer.effect = effect
	layer.condition = condition
	return layer


static func _ability(
	id: StringName,
	name: String,
	modules: Array[AbilityModule],
	upgraded_modules: Array[AbilityModule],
	targeting_flags: int,
	description: String,
) -> AbilityData:
	return DataLibrary._make_modular_ability(
		id, name, modules, upgraded_modules, 1,
		GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP, [],
		description, targeting_flags,
	)


static func _holy_light() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.HEAL, 3, 1, 3,
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	base.legacy_modifiers["mag_heal"] = true
	base.legacy_modifiers["enemy_mag_atk"] = 2
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.HEAL, 3, 1, 3,
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	upgraded.legacy_modifiers["mag_heal"] = true
	upgraded.legacy_modifiers["enemy_mag_atk"] = 4
	return _ability(
		&"cleric_holy_light", "Holy Light", [base], [upgraded],
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
		"Enemy MAG ATK 4. Ally MAG HEAL 3 unchanged.",
	)


static func _smite() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 2, 1, 3, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 2, 1, 3, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	upgraded.legacy_modifiers["shield_closest_ally_pct_damage"] = 0.5
	return _ability(
		&"cleric_smite", "Smite", [base], [upgraded],
		GameEnums.TargetingFlags.ENEMY,
		"Closest ally to target gains SHIELD equal to 50% of damage dealt.",
	)


static func _cleansing_aura() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.CLEANSE, 0, 0, 0, GameEnums.TargetingFlags.SELF,
		GameEnums.TargetShape.AOE_CROSS, 2,
	)
	base.layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.PURGE, 0)))
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.CLEANSE, 0, 0, 0, GameEnums.TargetingFlags.SELF,
		GameEnums.TargetShape.AOE_CROSS, 2,
	)
	upgraded.legacy_modifiers["ally_str_per_debuff"] = 1
	upgraded.layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.PURGE, 0)))
	return _ability(
		&"cleric_cleansing_aura", "Cleansing Aura", [base], [upgraded],
		GameEnums.TargetingFlags.SELF,
		"Allies gain +1 STR per debuff cleansed.",
	)


static func _sanctuary() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.CREATE_HAZARD, 1, 1, 2, GameEnums.TargetingFlags.TILE,
	)
	base.legacy_modifiers["terrain_id"] = &"sanctuary"
	base.legacy_modifiers["hazard_duration"] = 2
	base.legacy_modifiers["sanctuary"] = true
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.CREATE_HAZARD, 1, 1, 2, GameEnums.TargetingFlags.TILE,
	)
	upgraded.legacy_modifiers = base.legacy_modifiers.duplicate(true)
	upgraded.legacy_modifiers["sanctuary_enemy_push"] = 1
	return _ability(
		&"cleric_sanctuary", "Sanctuary", [base], [upgraded],
		GameEnums.TargetingFlags.TILE,
		"Enemies entering PUSH 1.",
	)


static func _blinding_ray() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 1, 1, 4, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.LINE, 4, GameEnums.StatType.MAGICAL,
	)
	base.layers.append(_layer(DataLibrary._status_effect(GameEnums.StatusType.BLIND, 1)))
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 1, 1, 4, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.LINE, 4, GameEnums.StatType.MAGICAL,
	)
	upgraded.layers.append(_layer(DataLibrary._status_effect(GameEnums.StatusType.BLIND, 1)))
	upgraded.layers.append(_layer(DataLibrary._status_effect(GameEnums.StatusType.CONFUSION, 1)))
	return _ability(
		&"cleric_blinding_ray", "Blinding Ray", [base], [upgraded],
		GameEnums.TargetingFlags.TILE,
		"Target also gains CONFUSION.",
	)


static func _divine_hammer() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.SPAWN, 0, 1, 2, GameEnums.TargetingFlags.TILE,
	)
	base.spawn_unit_id = &"cleric_holy_hammer"
	base.legacy_modifiers["construct_hp_pct"] = 0.25
	base.legacy_modifiers["creation_adjacent_damage"] = 2
	base.legacy_modifiers["creation_adjacent_push"] = 1
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.SPAWN, 0, 1, 2, GameEnums.TargetingFlags.TILE,
	)
	upgraded.spawn_unit_id = &"cleric_holy_hammer"
	upgraded.legacy_modifiers["construct_hp_pct"] = 0.25
	upgraded.legacy_modifiers["creation_adjacent_damage"] = 2
	upgraded.legacy_modifiers["creation_adjacent_push"] = 1
	upgraded.legacy_modifiers["holy_aura"] = true
	return _ability(
		&"cleric_divine_hammer", "Divine Hammer", [base], [upgraded],
		GameEnums.TargetingFlags.TILE,
		"The summoned obstacle projects HOLY AURA.",
	)


static func _life_link() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 0, 1, 3, GameEnums.TargetingFlags.ALLY,
	)
	base.legacy_modifiers["life_link"] = true
	base.legacy_modifiers["life_link_reduction"] = 3
	base.layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.DAMAGE_SELF, 2)))
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 0, 1, 3, GameEnums.TargetingFlags.ALLY,
	)
	upgraded.legacy_modifiers["life_link"] = true
	upgraded.legacy_modifiers["life_link_reduction"] = 3
	return _ability(
		&"cleric_life_link", "Life Link", [base], [upgraded],
		GameEnums.TargetingFlags.ALLY,
		"Linked ally takes no self-damage.",
	)


static func _prayer_of_fortitude() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 3, 1, 3, GameEnums.TargetingFlags.ALLY,
	)
	base.status_type = GameEnums.StatusType.STAT_BUFF_DEF
	base.status_duration = 1
	base.layers.append(_layer(DataLibrary._status_effect(GameEnums.StatusType.STURDY, 1)))
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 3, 1, 3, GameEnums.TargetingFlags.ALLY,
	)
	upgraded.status_type = GameEnums.StatusType.STAT_BUFF_DEF
	upgraded.status_duration = 1
	var sturdy := DataLibrary._status_effect(GameEnums.StatusType.STURDY, 1)
	sturdy.modifiers["counterattack_melee"] = true
	upgraded.layers.append(_layer(sturdy))
	return _ability(
		&"cleric_prayer_of_fortitude", "Prayer of Fortitude", [base], [upgraded],
		GameEnums.TargetingFlags.ALLY,
		"Ally counterattacks in melee.",
	)


static func _resurrection() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.HEAL, 10, 1, 1, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	base.legacy_modifiers["revive_percent_max_hp"] = 0.10
	base.legacy_modifiers["spend_self_hp"] = 10
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.HEAL, 10, 1, 1, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	upgraded.legacy_modifiers = base.legacy_modifiers.duplicate(true)
	upgraded.legacy_modifiers["revive_shield"] = 2
	return _ability(
		&"cleric_resurrection", "Resurrection", [base], [upgraded],
		GameEnums.TargetingFlags.ALLY,
		"Revived ally gains SHIELD 2.",
	)


static func _consecrate_ground() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.CREATE_HAZARD, 1, 0, 0, GameEnums.TargetingFlags.SELF,
		GameEnums.TargetShape.AOE_CROSS, 2,
	)
	base.legacy_modifiers["terrain_id"] = &"holy_ground"
	base.legacy_modifiers["hazard_duration"] = 2
	base.legacy_modifiers["holy_ground"] = true
	base.legacy_modifiers["holy_ground_zone"] = true
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.CREATE_HAZARD, 1, 0, 0, GameEnums.TargetingFlags.SELF,
		GameEnums.TargetShape.AOE_CROSS, 2,
	)
	upgraded.legacy_modifiers = base.legacy_modifiers.duplicate(true)
	upgraded.legacy_modifiers["holy_ground_def_down"] = 1
	return _ability(
		&"cleric_consecrate_ground", "Consecrate Ground", [base], [upgraded],
		GameEnums.TargetingFlags.SELF,
		"Enemies lose 1 DEF.",
	)


static func _holy_wrath() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 3, 1, 3, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	base.legacy_modifiers["stagger_if_debuffed"] = true
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 3, 1, 3, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	upgraded.legacy_modifiers["stagger_if_debuffed"] = true
	upgraded.legacy_modifiers["push"] = 2
	return _ability(
		&"cleric_holy_wrath", "Holy Wrath", [base], [upgraded],
		GameEnums.TargetingFlags.ENEMY,
		"If target is debuffed, apply STAGGER and PUSH 2.",
	)


static func _divine_guidance() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 1, 1, 3, GameEnums.TargetingFlags.ALLY,
	)
	base.legacy_modifiers["grant_ap"] = 1
	base.legacy_modifiers["self_move_zero_next_turn"] = true
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 1, 1, 3, GameEnums.TargetingFlags.ALLY,
	)
	upgraded.legacy_modifiers["grant_ap"] = 1
	return _ability(
		&"cleric_divine_guidance", "Divine Guidance", [base], [upgraded],
		GameEnums.TargetingFlags.ALLY,
		"Self is not ROOTED next turn.",
	)


static func _shield_of_faith() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.ARMOR_UP, 3, 1, 2, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAX_HP,
	)
	base.layers.append(_layer(DataLibrary._status_effect(GameEnums.StatusType.INTERCEPT, 1)))
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.ARMOR_UP, 3, 1, 2, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAX_HP,
	)
	var intercept := DataLibrary._status_effect(GameEnums.StatusType.INTERCEPT, 1)
	intercept.modifiers["counterattack_on_intercept"] = true
	upgraded.layers.append(_layer(intercept))
	return _ability(
		&"cleric_shield_of_faith", "Shield of Faith", [base], [upgraded],
		GameEnums.TargetingFlags.ALLY,
		"Counter-attack ATK 1 on intercept.",
	)


static func _martyrs_chains() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 1, 1, 3, GameEnums.TargetingFlags.ENEMY,
	)
	base.legacy_modifiers["link_two_enemies"] = true
	base.legacy_modifiers["magic_link_damage"] = 1
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 1, 1, 3, GameEnums.TargetingFlags.ENEMY,
	)
	upgraded.legacy_modifiers = base.legacy_modifiers.duplicate(true)
	upgraded.legacy_modifiers["link_blind"] = true
	return _ability(
		&"cleric_martyrs_chains", "Martyr's Chains", [base], [upgraded],
		GameEnums.TargetingFlags.ENEMY,
		"Linked enemies also suffer BLIND when the link triggers.",
	)
