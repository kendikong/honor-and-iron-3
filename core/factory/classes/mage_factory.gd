class_name MageFactory
extends RefCounted

## Builds the complete Mage moveset from class_abilities.txt.
## All Mage behavior is authored as data and consumed by shared simulation systems.


static func build(basic_staff: WeaponData) -> UnitData:
	var definition := UnitData.new()
	definition.id = &"mage"
	definition.display_name = "Mage"
	definition.base_constitution = 3
	definition.move_points = 3
	definition.action_points = 1
	definition.base_strength = 1
	definition.base_defense = 1
	definition.base_magic = 5
	definition.preferred_stat = GameEnums.StatType.MAGICAL
	definition.equipped_weapon = basic_staff
	definition.promotion_stat_bonuses = {
		&"geomancer": {"magic": 4, "constitution": 4, "movement": 0},
		&"archmage": {"magic": 8, "movement": 0},
		&"graviturge": {"magic": 4, "defense": 2, "movement": 2},
	}

	definition.innate_passives.append(_passive(
		&"arcane_overchannel",
		"Arcane Overchannel",
		"Spells grant Arcane Overchannel stacks, up to 3; each stack grants +1 MAG ATK.",
		"At 3 stacks, refund 1 AP once per turn and gain SHIELD 2.",
		{"arcane_overchannel": true, "arcane_overchannel_max": 3,
		"arcane_overchannel_magic": 1, "arcane_overchannel_refund_ap": 1,
		"arcane_overchannel_shield": 2, "promotion": &"core"},
	))

	var blink_module := DataLibrary._module(
		GameEnums.EffectType.TELEPORT_CASTER, 0, 1, 2, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	blink_module.legacy_modifiers["blink"] = true
	var blink_upgraded := DataLibrary._duplicate_modules([blink_module])
	blink_upgraded[0].max_range = 3
	blink_upgraded[0].legacy_modifiers["leave_elemental_surface"] = true
	var blink := DataLibrary._make_modular_ability(
		&"mage_blink", "Blink", [blink_module], blink_upgraded, 3,
		GameEnums.PlannerGroup.PRE_MOVE, GameEnums.CostResource.MP,
		[AbilityModuleBridge.TAG_POSITIONING],
		"Range becomes 3; leave an elemental surface on departure.",
		GameEnums.TargetingFlags.TILE,
	)
	definition.abilities.append(blink)

	# Geomancer passives.
	definition.passives.append(_passive(&"elementalist", "Elementalist",
		"Fire leaves FIRE; Ice leaves FROZEN; Lightning hits all on WATER/FROZEN.",
		"Enemies on new terrain take WPN unmitigated damage.",
		{"promotion": &"geomancer", "elementalist": true,
		"elementalist_terrain_damage_weapon": true}))
	definition.passives.append(_passive(&"feedback", "Feedback",
		"Creating terrain grants +1 MAG and SHIELD 1 for 1 turn.",
		"Gain SHIELD 2 instead.",
		{"promotion": &"geomancer", "feedback_magic": 1, "feedback_shield": 1,
		"upgraded_feedback_shield": 2}))
	definition.passives.append(_passive(&"elemental_master", "Elemental Master",
		"Gain +1 MAG per elemental tile on the map.",
		"Gain +1 DEF if 3 or more elemental tiles exist.",
		{"promotion": &"geomancer", "elemental_master_magic": 1,
		"upgraded_elemental_master_def_threshold": 3,
		"upgraded_elemental_master_def": 1}))
	definition.passives.append(_passive(&"lasting_terrain", "Lasting Terrain",
		"Surfaces last 1 extra turn and deal +1 hazard damage.",
		"Deal +2 hazard damage instead.",
		{"promotion": &"geomancer", "lasting_terrain_duration": 1,
		"lasting_terrain_damage": 1, "upgraded_lasting_terrain_damage": 2}))
	definition.passives.append(_passive(&"surface_syphoner", "Surface Syphoner",
		"Ending your turn on a created surface HEALs 1 and CLEANSEs you.",
		"HEAL 1 and gain SHIELD 1 instead of CLEANSE.",
		{"promotion": &"geomancer", "surface_syphoner": true,
		"surface_syphoner_heal": 1, "surface_syphoner_shield": 1}))

	# Archmage passives.
	definition.passives.append(_passive(&"mana_leak", "Mana Leak",
		"When damaged, deal MAG ATK 1 to adjacent tiles.",
		"Deal MAG ATK 2 instead.",
		{"promotion": &"archmage", "mana_leak": 1,
		"upgraded_mana_leak": 2}))
	definition.passives.append(_passive(&"arcane_overdrive", "Arcane Overdrive",
		"Gain +3 MAG; every spell consumes 5% current HP. Physical damage bypasses 50% SHIELD.",
		"Gain +4 MAG; spell HP cost remains 5%.",
		{"promotion": &"archmage", "arcane_overdrive_magic": 3,
		"upgraded_arcane_overdrive_magic": 4,
		"arcane_overdrive_hp_pct": 0.05, "arcane_overdrive_shield_bypass": 0.5}))
	definition.passives.append(_passive(&"mana_well", "Mana Well",
		"Ending on an elemental surface makes your next spell cost 0 AP.",
		"Also gain +1 MAG next turn.",
		{"promotion": &"archmage", "mana_well": true,
		"mana_well_magic": 1}))
	definition.passives.append(_passive(&"mana_siphon", "Mana Siphon",
		"Spell kills refund 1 AP once per turn; if capped, heal MAG and gain Overchannel.",
		"Also HEAL 1 on kill.",
		{"promotion": &"archmage", "mana_siphon": true,
		"mana_siphon_heal": 1}))
	definition.passives.append(_passive(&"overload", "Overload",
		"Gain +2 MAG and take 1 damage per turn, never below 1 HP.",
		"Gain +3 MAG instead.",
		{"promotion": &"archmage", "overload_magic": 2,
		"upgraded_overload_magic": 3, "overload_tick_damage": 1}))

	# Graviturge passives.
	definition.passives.append(_passive(&"wild_magic", "Wild Magic",
		"Targeting an enemy on a hazard casts the spell twice; the second cast costs 0 AP.",
		"Second cast gains +1 MAG.",
		{"promotion": &"graviturge", "wild_magic": true,
		"upgraded_wild_magic_magic": 1}))
	definition.passives.append(_passive(&"arcane_tether", "Arcane Tether",
		"An enemy moving adjacent suffers MAG ATK 1 and ROOT.",
		"MAG ATK increases to 2.",
		{"promotion": &"graviturge", "arcane_tether": 1,
		"upgraded_arcane_tether": 2}))
	definition.passives.append(_passive(&"arcane_mastery", "Arcane Mastery",
		"AOE spells gain +1 radius.",
		"AOE spells gain PIERCE.",
		{"promotion": &"graviturge", "arcane_mastery_radius": 1,
		"arcane_mastery_pierce": true}))
	definition.passives.append(_passive(&"arcane_attunement", "Arcane Attunement",
		"Casting a spell on an ally grants +1 DEF and +1 STR for 1 turn.",
		"The ally also gains +1 MOV.",
		{"promotion": &"graviturge", "arcane_attunement": true,
		"arcane_attunement_def": 1, "arcane_attunement_str": 1,
		"upgraded_arcane_attunement_mov": 1}))
	definition.passives.append(_passive(&"gravity_anchor", "Gravity Anchor",
		"Enemies suffering ROOT take +1 damage from spells.",
		"They take +2 damage instead.",
		{"promotion": &"graviturge", "gravity_anchor": 1,
		"upgraded_gravity_anchor": 2}))

	definition.abilities.append(_fireball())
	definition.abilities.append(_ice_shard())
	definition.abilities.append(_chain_lightning())
	definition.abilities.append(_arcane_push())
	definition.abilities.append(_teleport())
	definition.abilities.append(_meteor())
	definition.abilities.append(_black_hole())
	definition.abilities.append(_time_warp())
	definition.abilities.append(_mana_shield())
	definition.abilities.append(_disintegrate())
	definition.abilities.append(_gravity_well())
	definition.abilities.append(_elemental_surge())
	definition.abilities.append(_earth_spike())
	definition.abilities.append(_density_shift())
	definition.abilities.append(_arcane_barrage())

	DataLibrary.finalize_unit_abilities(definition)
	return definition


static func _passive(
	id: StringName,
	name: String,
	description: String,
	upgrade_description: String,
	modifiers: Dictionary,
) -> PassiveData:
	return DataLibrary._make_passive(id, name, description, upgrade_description, modifiers)


static func _spell(
	id: StringName,
	name: String,
	modules: Array[AbilityModule],
	upgraded_modules: Array[AbilityModule],
	targeting_flags: int,
	description: String,
) -> AbilityData:
	var ability := DataLibrary._make_modular_ability(
		id, name, modules, upgraded_modules, 1,
		GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP,
		[AbilityModuleBridge.TAG_SPELL], description, targeting_flags,
	)
	ability.presentation_anim = GameEnums.PresentationAnim.SPELL
	return ability


static func _terrain(id: StringName, duration: int = 1) -> EffectData:
	var effect := DataLibrary._effect(GameEnums.EffectType.CREATE_HAZARD, 0)
	effect.modifiers["terrain_id"] = id
	effect.modifiers["hazard_duration"] = duration
	effect.modifiers["elemental_surface"] = true
	return effect


static func _spawn_effect(spawn_id: StringName) -> EffectData:
	var effect := DataLibrary._effect(GameEnums.EffectType.SPAWN, 0)
	effect.spawn_unit_id = spawn_id
	return effect


static func _layer(
	effect: EffectData,
	condition: GameEnums.LayerCondition = GameEnums.LayerCondition.AT_RESOLUTION,
) -> AbilityLayer:
	var layer := AbilityLayer.new()
	layer.effect = effect
	layer.condition = condition
	return layer


static func _fireball() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 3, 1, 4,
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_SQUARE, 1, GameEnums.StatType.MAGICAL,
	)
	base.legacy_modifiers["reaction_frozen_to_steam"] = true
	base.legacy_modifiers["reaction_terrain"] = &"frozen"
	base.legacy_modifiers["reaction_damage"] = 2
	base.layers.append(_layer(_terrain(&"fire")))
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 3, 1, 4,
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_SQUARE, 3, GameEnums.StatType.MAGICAL,
	)
	upgraded.legacy_modifiers = base.legacy_modifiers.duplicate(true)
	var steam := _terrain(&"steam")
	steam.modifiers["reaction_frozen_to_steam"] = true
	steam.modifiers["reaction_terrain"] = &"frozen"
	upgraded.layers.append(_layer(steam))
	return _spell(
		&"mage_fireball", "Fireball", [base], [upgraded],
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		"On FROZEN, create STEAM (AOE 3x3) with MAG ATK 2 splash.",
	)


static func _ice_shard() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 2, 1, 4, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	base.legacy_modifiers["reaction_terrain"] = &"fire"
	base.legacy_modifiers["reaction_damage"] = 2
	var slow := DataLibrary._status_effect(GameEnums.StatusType.STAT_DEBUFF_MOV, 1, 1)
	slow.modifiers["set_max_move"] = 1
	base.layers.append(_layer(slow))
	base.layers.append(_layer(_terrain(&"frozen")))
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 2, 1, 4,
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_SQUARE, 3, GameEnums.StatType.MAGICAL,
	)
	upgraded.legacy_modifiers = base.legacy_modifiers.duplicate(true)
	var upgraded_slow := DataLibrary._status_effect(GameEnums.StatusType.STAT_DEBUFF_MOV, 1, 1)
	upgraded_slow.modifiers["set_max_move"] = 1
	upgraded.layers.append(_layer(upgraded_slow))
	var steam := _terrain(&"steam")
	steam.modifiers["reaction_fire_to_steam"] = true
	steam.modifiers["reaction_terrain"] = &"fire"
	upgraded.layers.append(_layer(steam))
	return _spell(
		&"mage_ice_shard", "Ice Shard", [base], [upgraded],
		GameEnums.TargetingFlags.ENEMY,
		"On FIRE, create STEAM (AOE 3x3) with MAG ATK 2 splash.",
	)


static func _chain_lightning() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 2, 1, 4, GameEnums.TargetingFlags.ENEMY,
		 GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	base.legacy_modifiers["bounce_count"] = 2
	base.legacy_modifiers["bounce_range"] = 2
	base.legacy_modifiers["surface_chain"] = true
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 2, 1, 4, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	upgraded.legacy_modifiers = base.legacy_modifiers.duplicate(true)
	upgraded.legacy_modifiers["strike_all_surface"] = true
	return _spell(
		&"mage_chain_lightning", "Chain Lightning", [base], [upgraded],
		GameEnums.TargetingFlags.ENEMY,
		"On WATER/FROZEN, strike all units on that surface.",
	)


static func _arcane_push() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 1, 1, 3, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	base.layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.PUSH, 3)))
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 1, 1, 3, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	upgraded.layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.PUSH, 3)))
	var trail := _terrain(&"arcane_trail")
	trail.modifiers["arcane_trail"] = true
	upgraded.layers.append(_layer(trail))
	return _spell(
		&"mage_arcane_push", "Arcane Push", [base], [upgraded],
		GameEnums.TargetingFlags.ENEMY,
		"Leaves an Arcane Trail dealing MAG ATK 1 to crossing units.",
	)


static func _teleport() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.TELEPORT_CASTER, 0, 1, 4,
		GameEnums.TargetingFlags.TILE, GameEnums.TargetShape.SINGLE, 1,
		GameEnums.StatType.NONE, GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	base.legacy_modifiers["teleport_visible"] = true
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.TELEPORT_CASTER, 0, 1, 4,
		GameEnums.TargetingFlags.TILE, GameEnums.TargetShape.SINGLE, 1,
		GameEnums.StatType.NONE, GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	upgraded.legacy_modifiers["teleport_visible"] = true
	upgraded.layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.ARMOR_UP, 1), GameEnums.LayerCondition.ON_LAND))
	return _spell(
		&"mage_teleport", "Teleport", [base], [upgraded],
		GameEnums.TargetingFlags.TILE,
		"Gain SHIELD 1 upon landing.",
	)


static func _meteor() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 5, 1, 5, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_DIAMOND, 2, GameEnums.StatType.MAGICAL,
	)
	base.legacy_modifiers["delayed_next_turn"] = true
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 5, 1, 5, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_DIAMOND, 2, GameEnums.StatType.MAGICAL,
	)
	upgraded.legacy_modifiers = base.legacy_modifiers.duplicate(true)
	upgraded.legacy_modifiers["create_crater"] = true
	return _spell(
		&"mage_meteor", "Meteor", [base], [upgraded],
		GameEnums.TargetingFlags.TILE,
		"Impact creates CRATER terrain applying BURN.",
	)


static func _black_hole() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.PULL, 2, 1, 4, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_DIAMOND, 2, GameEnums.StatType.NONE,
	)
	base.legacy_modifiers["pull_to_center"] = true
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.PULL, 2, 1, 4, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_DIAMOND, 2, GameEnums.StatType.NONE,
	)
	upgraded.legacy_modifiers["pull_to_center"] = true
	upgraded.legacy_modifiers["pull_surfaces"] = true
	return _spell(
		&"mage_black_hole", "Black Hole", [base], [upgraded],
		GameEnums.TargetingFlags.TILE,
		"Pull hazards and surfaces to the center.",
	)


static func _time_warp() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.DAMAGE_SELF, 4, 0, 3, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
	)
	var grant := DataLibrary._effect(GameEnums.EffectType.ADD_STATUS, 1)
	grant.modifiers["utility_only"] = true
	grant.modifiers["grant_ap"] = 1
	base.layers.append(_layer(grant))
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.DAMAGE_SELF, 4, 0, 3, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
	)
	var upgraded_grant := DataLibrary._effect(GameEnums.EffectType.ADD_STATUS, 1)
	upgraded_grant.modifiers = grant.modifiers.duplicate(true)
	upgraded_grant.modifiers["cooldown_reduction"] = 1
	upgraded.layers.append(_layer(upgraded_grant))
	return _spell(
		&"mage_time_warp", "Time Warp", [base], [upgraded],
		GameEnums.TargetingFlags.ALLY,
		"Target ally cooldowns -1.",
	)


static func _mana_shield() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.ARMOR_UP, 0, 0, 0, GameEnums.TargetingFlags.SELF,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	base.legacy_modifiers["mana_shield"] = true
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.ARMOR_UP, 0, 0, 0, GameEnums.TargetingFlags.SELF,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	upgraded.legacy_modifiers["mana_shield"] = true
	upgraded.legacy_modifiers["mana_shield_casting"] = true
	return _spell(
		&"mage_mana_shield", "Mana Shield", [base], [upgraded],
		GameEnums.TargetingFlags.SELF,
		"May cast spells by paying 1 SHIELD per spell.",
	)


static func _disintegrate() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 6, 1, 3, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	base.legacy_modifiers["destroy_corpse_on_kill"] = true
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 6, 1, 3, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	upgraded.legacy_modifiers = base.legacy_modifiers.duplicate(true)
	upgraded.legacy_modifiers["kill_grant_ap"] = 1
	return _spell(
		&"mage_disintegrate", "Disintegrate", [base], [upgraded],
		GameEnums.TargetingFlags.ENEMY,
		"On Kill, gain 1 AP.",
	)


static func _gravity_well() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 1, 1, 4,
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_DIAMOND, 2,
	)
	base.status_type = GameEnums.StatusType.ROOT
	base.status_duration = 1
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 1, 1, 4,
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_DIAMOND, 2,
	)
	upgraded.status_type = GameEnums.StatusType.ROOT
	upgraded.status_duration = 1
	upgraded.layers.append(_layer(DataLibrary._status_effect(GameEnums.StatusType.BLIND, 1)))
	return _spell(
		&"mage_gravity_well", "Gravity Well", [base], [upgraded],
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		"Also applies BLIND.",
	)


static func _elemental_surge() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS_SELF, 1, 0, 0, GameEnums.TargetingFlags.SELF,
	)
	base.legacy_modifiers["utility_only"] = true
	base.legacy_modifiers["elemental_surge"] = true
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS_SELF, 1, 0, 0, GameEnums.TargetingFlags.SELF,
	)
	upgraded.legacy_modifiers = base.legacy_modifiers.duplicate(true)
	upgraded.legacy_modifiers["elemental_surge_ap"] = 1
	return _spell(
		&"mage_elemental_surge", "Elemental Surge", [base], [upgraded],
		GameEnums.TargetingFlags.SELF,
		"Also grants +1 AP.",
	)


static func _earth_spike() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.SPAWN, 0, 1, 4, GameEnums.TargetingFlags.TILE,
	)
	base.spawn_unit_id = &"obsidian_wall"
	base.legacy_modifiers["construct_hp_pct"] = 0.50
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.SPAWN, 0, 1, 4, GameEnums.TargetingFlags.TILE,
	)
	upgraded.spawn_unit_id = &"obsidian_wall"
	upgraded.legacy_modifiers["construct_hp_pct"] = 0.50
	upgraded.legacy_modifiers["creation_adjacent_damage"] = 1
	var creation_damage := DataLibrary._effect(GameEnums.EffectType.DAMAGE, 1)
	creation_damage.scaling_stat = GameEnums.StatType.MAGICAL
	creation_damage.modifiers["creation_adjacent_damage"] = 1
	upgraded.layers.append(_layer(creation_damage))
	return _spell(
		&"mage_earth_spike", "Earth Spike", [base], [upgraded],
		GameEnums.TargetingFlags.TILE,
		"The obstacle deals MAG ATK 1 to adjacent units on creation.",
	)


static func _density_shift() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 2, 1, 3,
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
	)
	base.status_type = GameEnums.StatusType.STURDY
	base.status_duration = 2
	base.legacy_modifiers["density_shift"] = true
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 2, 1, 3,
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
	)
	upgraded.status_type = GameEnums.StatusType.STURDY
	upgraded.status_duration = 2
	upgraded.legacy_modifiers = base.legacy_modifiers.duplicate(true)
	upgraded.legacy_modifiers["apply_weaken_enemy"] = true
	return _spell(
		&"mage_density_shift", "Density Shift", [base], [upgraded],
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
		"Enemies also gain WEAKEN.",
	)


static func _arcane_barrage() -> AbilityData:
	var base := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 1, 1, 4, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	base.legacy_modifiers["repeat_hits"] = 3
	var upgraded := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 1, 1, 4, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	upgraded.legacy_modifiers = base.legacy_modifiers.duplicate(true)
	upgraded.legacy_modifiers["ignore_target_magic_pct"] = 0.25
	return _spell(
		&"mage_arcane_barrage", "Arcane Barrage", [base], [upgraded],
		GameEnums.TargetingFlags.ENEMY,
		"Each hit ignores 25% of target MAG.",
	)
